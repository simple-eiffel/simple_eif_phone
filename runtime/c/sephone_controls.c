/*
 * sephone_controls.c - Android's own controls, driven from C for Eiffel.
 * Contract: sephone.h, section CONTROLS. Eiffel side: src/controls.
 *
 * Android has no C API for its controls, so this file makes and drives them
 * through JNI: FindClass, NewObject, Call...Method on android.widget.*.
 *
 * THREADS. A control may be touched only on Android's UI thread, and Eiffel
 * runs on its own. So Eiffel never calls a control directly:
 *   sephone_control (Eiffel thread) queues an order and asks for a UI turn;
 *   on_ui_turn (UI thread) carries out the orders, in order.
 * Orders never wait for an answer. Android's UI thread blocks on the Eiffel
 * thread during onResume and onPause, so an Eiffel thread that waited for the
 * UI thread would deadlock. What a control has to say comes back as an event.
 * Eiffel chooses every control's id, so no order needs a reply.
 *
 * Drawing is the exception. SurfaceHolder.lockCanvas is built to be called from
 * a drawing thread, so the sephone_canvas_* functions run on the Eiffel thread.
 */
#include <android/log.h>
#include <jni.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "sephone.h"
#include "sephone_bridge.h"

#define TAG "EifPhone"
#define LISTENER_CLASS "io/github/simple_eiffel/eifphone/EifPhoneControlsActivity$Listener"
#define ROWS_CLASS "io/github/simple_eiffel/eifphone/EifPhoneControlsActivity$Rows"
#define ROW_BLOCK 64
#define FIELD_MARK '\x1F'

typedef struct sephone_order {
	int op, id, a, b;
	char *text;
	struct sephone_order *next;
} sephone_order;

typedef struct {
	int kind, height_px, gap_px;
	jobject view, listener, adapter, holder;
	char **rows;
	int row_count;
	unsigned char *asked;
} sephone_view;

static int s_ready = 0;
static float s_density = 1.0f;
static jmethodID s_m_post = NULL;

static pthread_mutex_t s_lock = PTHREAD_MUTEX_INITIALIZER;
static sephone_order *s_first = NULL, *s_last = NULL;
static int s_turn_asked = 0;

/* s_lock also guards the table: the UI thread grows it, the Eiffel thread reads canvases. */
static sephone_view **s_views = NULL;
static int s_view_cap = 0;

/* Drawing, on the Eiffel thread. */
static jobject s_paint = NULL, s_canvas = NULL, s_holder = NULL;
static jmethodID s_m_lock, s_m_unlock, s_m_scale, s_m_draw_color, s_m_draw_rect, s_m_draw_line, s_m_draw_text;
static jmethodID s_m_set_color, s_m_set_stroke, s_m_set_size, s_m_set_bold, s_m_measure;

/* ------------------------------------------------------------- JNI helpers */

static int failed(JNIEnv *env, const char *what)
{
	if (!(*env)->ExceptionCheck(env)) return 0;
	__android_log_print(ANDROID_LOG_WARN, TAG, "controls: %s failed", what);
	(*env)->ExceptionDescribe(env);
	(*env)->ExceptionClear(env);
	return 1;
}

static void call_void(JNIEnv *env, jobject target, const char *name, const char *sig, ...)
{
	va_list args;
	jclass cls = (*env)->GetObjectClass(env, target);
	jmethodID m = (*env)->GetMethodID(env, cls, name, sig);
	if (m) {
		va_start(args, sig);
		(*env)->CallVoidMethodV(env, target, m, args);
		va_end(args);
	}
	failed(env, name);
	(*env)->DeleteLocalRef(env, cls);
}

static jobject call_object(JNIEnv *env, jobject target, const char *name, const char *sig, ...)
{
	va_list args;
	jobject result = NULL;
	jclass cls = (*env)->GetObjectClass(env, target);
	jmethodID m = (*env)->GetMethodID(env, cls, name, sig);
	if (m) {
		va_start(args, sig);
		result = (*env)->CallObjectMethodV(env, target, m, args);
		va_end(args);
	}
	failed(env, name);
	(*env)->DeleteLocalRef(env, cls);
	return result;
}

static jobject new_object(JNIEnv *env, const char *class_name, const char *sig, ...)
{
	va_list args;
	jobject result = NULL;
	jclass cls = (*env)->FindClass(env, class_name);
	if (cls) {
		jmethodID m = (*env)->GetMethodID(env, cls, "<init>", sig);
		if (m) {
			va_start(args, sig);
			result = (*env)->NewObjectV(env, cls, m, args);
			va_end(args);
		}
		(*env)->DeleteLocalRef(env, cls);
	}
	failed(env, class_name);
	return result;
}

/* NewStringUTF wants Java's modified UTF-8; this takes real UTF-8, emoji included. */
static jstring java_text(JNIEnv *env, const char *text)
{
	jsize count = text ? (jsize)strlen(text) : 0;
	jbyteArray bytes = (*env)->NewByteArray(env, count);
	jstring charset = (*env)->NewStringUTF(env, "UTF-8");
	jstring result;
	if (count > 0) (*env)->SetByteArrayRegion(env, bytes, 0, count, (const jbyte *)text);
	result = (jstring)new_object(env, "java/lang/String", "([BLjava/lang/String;)V", bytes, charset);
	(*env)->DeleteLocalRef(env, bytes);
	(*env)->DeleteLocalRef(env, charset);
	return result;
}

static int px(int dp)
{
	return (int)((float)dp * s_density + 0.5f);
}

/* ------------------------------------------------------------- the table */

static sephone_view *view_of(int id)
{
	sephone_view *v = NULL;
	pthread_mutex_lock(&s_lock);
	if (id > 0 && id < s_view_cap) v = s_views[id];
	pthread_mutex_unlock(&s_lock);
	return v;
}

static sephone_view *new_view_slot(int id)
{
	sephone_view *v = (sephone_view *)calloc(1, sizeof(sephone_view));
	pthread_mutex_lock(&s_lock);
	if (id >= s_view_cap) {
		int cap = id + 64;
		sephone_view **grown = (sephone_view **)realloc(s_views, sizeof(sephone_view *) * (size_t)cap);
		if (grown) {
			memset(grown + s_view_cap, 0, sizeof(sephone_view *) * (size_t)(cap - s_view_cap));
			s_views = grown;
			s_view_cap = cap;
		}
	}
	if (v && id < s_view_cap) s_views[id] = v;
	pthread_mutex_unlock(&s_lock);
	return v;
}

static jobject global(JNIEnv *env, jobject local)
{
	jobject result = local ? (*env)->NewGlobalRef(env, local) : NULL;
	if (local) (*env)->DeleteLocalRef(env, local);
	return result;
}

/* ------------------------------------------------------------ making views */

static const char *class_of_kind(int kind)
{
	switch (kind) {
	case SEPHONE_CONTROL_LABEL: return "android/widget/TextView";
	case SEPHONE_CONTROL_BUTTON: return "android/widget/Button";
	case SEPHONE_CONTROL_TEXT_BOX: return "android/widget/EditText";
	case SEPHONE_CONTROL_COLUMN:
	case SEPHONE_CONTROL_ROW: return "android/widget/LinearLayout";
	case SEPHONE_CONTROL_LIST: return "io/github/simple_eiffel/eifphone/EifPhoneRows";
	case SEPHONE_CONTROL_CANVAS: return "android/view/SurfaceView";
	case SEPHONE_CONTROL_SCROLL: return "android/widget/ScrollView";
	case SEPHONE_CONTROL_CHECK_BOX: return "android/widget/CheckBox";
	case SEPHONE_CONTROL_SWITCH: return "android/widget/Switch";
	case SEPHONE_CONTROL_SLIDER: return "android/widget/SeekBar";
	case SEPHONE_CONTROL_CHOICE: return "android/widget/Spinner";
	case SEPHONE_CONTROL_RADIO_GROUP: return "android/widget/RadioGroup";
	case SEPHONE_CONTROL_IMAGE: return "android/widget/ImageView";
	default: return NULL;
	}
}

static void listen(JNIEnv *env, sephone_view *v, const char *setter, const char *sig)
{
	call_void(env, v->view, setter, sig, v->listener);
}

static void make_view(JNIEnv *env, int id, int kind, const char *class_name)
{
	sephone_view *v = new_view_slot(id);
	jobject activity = sephone_activity();
	char *dotless = NULL;
	jobject view;
	if (!v) return;
	v->kind = kind;
	if (kind == SEPHONE_CONTROL_PROGRESS) {
		/* android.R.attr.progressBarStyleHorizontal */
		view = new_object(env, "android/widget/ProgressBar", "(Landroid/content/Context;Landroid/util/AttributeSet;I)V",
			activity, NULL, (jint)0x01010078);
	} else {
		const char *name = class_of_kind(kind);
		if (kind == SEPHONE_CONTROL_ANY && class_name) {
			char *p;
			dotless = strdup(class_name);
			for (p = dotless; *p; p++) if (*p == '.') *p = '/';
			name = dotless;
		}
		view = name ? new_object(env, name, "(Landroid/content/Context;)V", activity) : NULL;
	}
	free(dotless);
	if (!view) {
		sephone_mail(SEPHONE_CONTROL_FAILED, 0, id, 0, 0, strdup(class_name ? class_name : "no such control"));
		return;
	}
	v->view = global(env, view);
	v->listener = global(env, new_object(env, LISTENER_CLASS, "(I)V", (jint)id));
	switch (kind) {
	case SEPHONE_CONTROL_BUTTON:
		call_void(env, v->view, "setAllCaps", "(Z)V", (jboolean)JNI_FALSE);
		listen(env, v, "setOnClickListener", "(Landroid/view/View$OnClickListener;)V");
		break;
	case SEPHONE_CONTROL_TEXT_BOX:
		listen(env, v, "addTextChangedListener", "(Landroid/text/TextWatcher;)V");
		break;
	case SEPHONE_CONTROL_COLUMN:
		call_void(env, v->view, "setOrientation", "(I)V", (jint)1);
		break;
	case SEPHONE_CONTROL_ROW:
		call_void(env, v->view, "setOrientation", "(I)V", (jint)0);
		break;
	case SEPHONE_CONTROL_CHECK_BOX:
	case SEPHONE_CONTROL_SWITCH:
		listen(env, v, "setOnCheckedChangeListener", "(Landroid/widget/CompoundButton$OnCheckedChangeListener;)V");
		break;
	case SEPHONE_CONTROL_RADIO_GROUP:
		listen(env, v, "setOnCheckedChangeListener", "(Landroid/widget/RadioGroup$OnCheckedChangeListener;)V");
		break;
	case SEPHONE_CONTROL_SLIDER:
		listen(env, v, "setOnSeekBarChangeListener", "(Landroid/widget/SeekBar$OnSeekBarChangeListener;)V");
		break;
	case SEPHONE_CONTROL_LIST:
		v->adapter = global(env, new_object(env, ROWS_CLASS, "(I)V", (jint)id));
		call_void(env, v->view, "setAdapter", "(Landroid/widget/ListAdapter;)V", v->adapter);
		call_void(env, v->view, "setFastScrollEnabled", "(Z)V", (jboolean)JNI_TRUE);
		listen(env, v, "setOnItemClickListener", "(Landroid/widget/AdapterView$OnItemClickListener;)V");
		break;
	case SEPHONE_CONTROL_CHOICE: {
		jobject items = new_object(env, "java/util/ArrayList", "()V");
		/* android.R.layout.simple_spinner_item, simple_spinner_dropdown_item */
		v->adapter = global(env, new_object(env, "android/widget/ArrayAdapter", "(Landroid/content/Context;ILjava/util/List;)V",
			activity, (jint)0x01090008, items));
		call_void(env, v->adapter, "setDropDownViewResource", "(I)V", (jint)0x01090009);
		call_void(env, v->view, "setAdapter", "(Landroid/widget/SpinnerAdapter;)V", v->adapter);
		listen(env, v, "setOnItemSelectedListener", "(Landroid/widget/AdapterView$OnItemSelectedListener;)V");
		(*env)->DeleteLocalRef(env, items);
		break;
	}
	case SEPHONE_CONTROL_CANVAS:
		v->holder = global(env, call_object(env, v->view, "getHolder", "()Landroid/view/SurfaceHolder;"));
		call_void(env, v->holder, "addCallback", "(Landroid/view/SurfaceHolder$Callback;)V", v->listener);
		listen(env, v, "setOnTouchListener", "(Landroid/view/View$OnTouchListener;)V");
		break;
	default:
		break;
	}
}

/* -------------------------------------------------------------- the orders */

/* While Eiffel changes a control, the control's listener stays silent. */
static void set_quiet(JNIEnv *env, sephone_view *v, int on)
{
	jclass cls;
	jfieldID f;
	if (!v->listener) return;
	cls = (*env)->GetObjectClass(env, v->listener);
	f = (*env)->GetFieldID(env, cls, "quiet", "Z");
	if (f) (*env)->SetBooleanField(env, v->listener, f, on ? JNI_TRUE : JNI_FALSE);
	(*env)->DeleteLocalRef(env, cls);
}

static void add_child(JNIEnv *env, sephone_view *parent, sephone_view *child, int grow_percent)
{
	int linear = parent->kind == SEPHONE_CONTROL_COLUMN || parent->kind == SEPHONE_CONTROL_ROW;
	if (linear) {
		int column = parent->kind == SEPHONE_CONTROL_COLUMN;
		int natural = child->height_px > 0 ? child->height_px : -2;
		int width = column ? -1 : (grow_percent > 0 ? 0 : -2);
		int height = column ? (grow_percent > 0 ? 0 : natural) : natural;
		jclass cls = (*env)->GetObjectClass(env, parent->view);
		jmethodID count = (*env)->GetMethodID(env, cls, "getChildCount", "()I");
		int existing = (*env)->CallIntMethod(env, parent->view, count);
		jobject params = new_object(env, "android/widget/LinearLayout$LayoutParams", "(IIF)V",
			(jint)width, (jint)height, (jfloat)((float)grow_percent / 100.0f));
		(*env)->DeleteLocalRef(env, cls);
		if (params && existing > 0 && parent->gap_px > 0) {
			if (column) call_void(env, params, "setMargins", "(IIII)V", (jint)0, (jint)parent->gap_px, (jint)0, (jint)0);
			else call_void(env, params, "setMarginStart", "(I)V", (jint)parent->gap_px);
		}
		call_void(env, parent->view, "addView", "(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V", child->view, params);
	} else {
		call_void(env, parent->view, "addView", "(Landroid/view/View;)V", child->view);
	}
}

static void set_height(JNIEnv *env, sephone_view *v, int height_px)
{
	jobject params = call_object(env, v->view, "getLayoutParams", "()Landroid/view/ViewGroup$LayoutParams;");
	v->height_px = height_px;
	if (params) {
		jclass cls = (*env)->GetObjectClass(env, params);
		jfieldID f = (*env)->GetFieldID(env, cls, "height", "I");
		(*env)->SetIntField(env, params, f, (jint)height_px);
		(*env)->DeleteLocalRef(env, cls);
		call_void(env, v->view, "setLayoutParams", "(Landroid/view/ViewGroup$LayoutParams;)V", params);
	}
}

static void clear_rows(sephone_view *v)
{
	int i;
	for (i = 0; i < v->row_count; i++) free(v->rows[i]);
	free(v->rows);
	free(v->asked);
	v->rows = NULL;
	v->asked = NULL;
	v->row_count = 0;
}

static void set_row_count(JNIEnv *env, sephone_view *v, int count)
{
	clear_rows(v);
	if (count > 0) {
		v->rows = (char **)calloc((size_t)count, sizeof(char *));
		v->asked = (unsigned char *)calloc((size_t)(count / ROW_BLOCK + 1), 1);
		if (v->rows && v->asked) v->row_count = count;
	}
	call_void(env, v->adapter, "setCount", "(I)V", (jint)v->row_count);
}

/* Splits `text' at the next field mark, in place. */
static char *next_field(char **cursor)
{
	char *start = *cursor, *mark = start ? strchr(start, FIELD_MARK) : NULL;
	if (mark) {
		*mark = 0;
		*cursor = mark + 1;
	} else {
		*cursor = NULL;
	}
	return start ? start : (char *)"";
}

static void show_dialog(JNIEnv *env, int id, char *text)
{
	char *cursor = text;
	jstring title = java_text(env, next_field(&cursor));
	jstring message = java_text(env, next_field(&cursor));
	jstring yes = java_text(env, next_field(&cursor));
	jstring no = java_text(env, next_field(&cursor));
	call_void(env, sephone_activity(), "sephoneDialog",
		"(ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V", (jint)id, title, message, yes, no);
}

static void show_toast(JNIEnv *env, const char *text)
{
	jclass cls = (*env)->FindClass(env, "android/widget/Toast");
	jmethodID m = (*env)->GetStaticMethodID(env, cls, "makeText",
		"(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;");
	jobject toast = (*env)->CallStaticObjectMethod(env, cls, m, sephone_activity(), java_text(env, text), (jint)0);
	if (toast) call_void(env, toast, "show", "()V");
}

/* A picture packed in the app's assets. A missing one is reported, and shows nothing. */
static void show_image(JNIEnv *env, int id, sephone_view *v, const char *name)
{
	jobject assets = call_object(env, sephone_activity(), "getAssets", "()Landroid/content/res/AssetManager;");
	jobject stream = assets ? call_object(env, assets, "open", "(Ljava/lang/String;)Ljava/io/InputStream;", java_text(env, name)) : NULL;
	jobject bitmap = NULL;
	if (stream) {
		jclass factory = (*env)->FindClass(env, "android/graphics/BitmapFactory");
		jmethodID decode = (*env)->GetStaticMethodID(env, factory, "decodeStream", "(Ljava/io/InputStream;)Landroid/graphics/Bitmap;");
		bitmap = (*env)->CallStaticObjectMethod(env, factory, decode, stream);
		failed(env, "decodeStream");
		call_void(env, stream, "close", "()V");
	}
	if (bitmap) {
		call_void(env, v->view, "setAdjustViewBounds", "(Z)V", (jboolean)JNI_TRUE);
		call_void(env, v->view, "setImageBitmap", "(Landroid/graphics/Bitmap;)V", bitmap);
	} else {
		sephone_mail(SEPHONE_CONTROL_FAILED, 0, id, 0, 0, strdup(name));
	}
}

/* Android forgets the control. Eiffel has already taken it out of its parent. */
static void discard_view(JNIEnv *env, int id, sephone_view *v)
{
	pthread_mutex_lock(&s_lock);
	s_views[id] = NULL;
	pthread_mutex_unlock(&s_lock);
	clear_rows(v);
	if (v->view) (*env)->DeleteGlobalRef(env, v->view);
	if (v->listener) (*env)->DeleteGlobalRef(env, v->listener);
	if (v->adapter) (*env)->DeleteGlobalRef(env, v->adapter);
	if (v->holder) (*env)->DeleteGlobalRef(env, v->holder);
	free(v);
}

static void carry_out(JNIEnv *env, sephone_order *o)
{
	sephone_view *v = view_of(o->id), *child;
	const char *text = o->text ? o->text : "";
	switch (o->op) {
	case SEPHONE_OP_NEW: make_view(env, o->id, o->a, o->text); return;
	case SEPHONE_OP_TOAST: show_toast(env, text); return;
	case SEPHONE_OP_DIALOG: show_dialog(env, o->id, o->text); return;
	case SEPHONE_OP_WINDOW:
		/* a = color above, b = color below, text = "1" for dark icons */
		call_void(env, sephone_activity(), "sephoneWindow", "(IILjava/lang/String;)V", (jint)o->a, (jint)o->b, java_text(env, o->text));
		return;
	case SEPHONE_OP_BARS:
		call_void(env, sephone_activity(), "sephoneBars", "(Z)V", (jboolean)(o->a != 0));
		return;
	case SEPHONE_OP_DATE: {
		/* a = year, b = month * 100 + day */
		call_void(env, sephone_activity(), "sephoneDate", "(IIII)V", (jint)o->id, (jint)o->a, (jint)(o->b / 100), (jint)(o->b % 100));
		return;
	}
	case SEPHONE_OP_TIME:
		call_void(env, sephone_activity(), "sephoneTime", "(III)V", (jint)o->id, (jint)o->a, (jint)o->b);
		return;
	case SEPHONE_OP_BACK:
		call_void(env, sephone_activity(), "sephoneBack", "(I)V", (jint)o->a);
		return;
	case SEPHONE_OP_DISCARD:
		if (v) discard_view(env, o->id, v);
		return;
	default:
		break;
	}
	if (!v || !v->view) return;
	switch (o->op) {
	case SEPHONE_OP_ADD:
		child = view_of(o->a);
		if (child && child->view) add_child(env, v, child, o->b);
		break;
	case SEPHONE_OP_REMOVE:
		child = view_of(o->a);
		if (child && child->view) call_void(env, v->view, "removeView", "(Landroid/view/View;)V", child->view);
		break;
	case SEPHONE_OP_SHOW:
		call_void(env, sephone_activity(), "sephoneShow", "(Landroid/view/View;)V", v->view);
		break;
	case SEPHONE_OP_TEXT:
		set_quiet(env, v, 1);
		call_void(env, v->view, "setText", "(Ljava/lang/CharSequence;)V", java_text(env, text));
		set_quiet(env, v, 0);
		break;
	case SEPHONE_OP_ENABLED:
		call_void(env, v->view, "setEnabled", "(Z)V", (jboolean)(o->a != 0));
		break;
	case SEPHONE_OP_VISIBLE:
		/* View.VISIBLE = 0, View.GONE = 8 */
		call_void(env, v->view, "setVisibility", "(I)V", (jint)(o->a ? 0 : 8));
		break;
	case SEPHONE_OP_TEXT_STYLE:
		/* a = size in hundredths of an sp; b = bold. COMPLEX_UNIT_SP = 2 */
		call_void(env, v->view, "setTextSize", "(IF)V", (jint)2, (jfloat)((float)o->a / 100.0f));
		call_void(env, v->view, "setTypeface", "(Landroid/graphics/Typeface;I)V", NULL, (jint)(o->b ? 1 : 0));
		break;
	case SEPHONE_OP_SPACING:
		v->gap_px = px(o->a);
		call_void(env, v->view, "setPadding", "(IIII)V", (jint)px(o->b), (jint)px(o->b), (jint)px(o->b), (jint)px(o->b));
		break;
	case SEPHONE_OP_HEIGHT:
		set_height(env, v, px(o->a));
		break;
	case SEPHONE_OP_PADDING:
		call_void(env, v->view, "setPadding", "(IIII)V", (jint)px(o->a), (jint)px(o->b), (jint)px(o->a), (jint)px(o->b));
		break;
	case SEPHONE_OP_LEAST_HEIGHT:
		call_void(env, v->view, "setMinimumHeight", "(I)V", (jint)px(o->a));
		break;
	case SEPHONE_OP_LEAST_WIDTH:
		call_void(env, v->view, "setMinimumWidth", "(I)V", (jint)px(o->a));
		break;
	case SEPHONE_OP_PADDING_EACH:
		/* a = start and end, b = top and bottom, sixteen bits each */
		call_void(env, v->view, "setPadding", "(IIII)V", (jint)px(o->a >> 16), (jint)px(o->b >> 16), (jint)px(o->a & 0xFFFF), (jint)px(o->b & 0xFFFF));
		break;
	case SEPHONE_OP_SURFACE:
		/* a = color, b = corner radius, text = border color and width */
		call_void(env, sephone_activity(), "sephoneSurface", "(Landroid/view/View;IILjava/lang/String;)V",
			v->view, (jint)o->a, (jint)o->b, java_text(env, text));
		break;
	case SEPHONE_OP_RIPPLE:
		call_void(env, sephone_activity(), "sephoneRipple", "(Landroid/view/View;Z)V", v->view, (jboolean)(o->a != 0));
		break;
	case SEPHONE_OP_DROPDOWN:
		/* id = the anchor; a = the id the answer comes under; b = the background */
		call_void(env, sephone_activity(), "sephoneDropdown", "(Landroid/view/View;IILjava/lang/String;)V",
			v->view, (jint)o->a, (jint)o->b, java_text(env, text));
		break;
	case SEPHONE_OP_RICH:
		call_void(env, sephone_activity(), "sephoneRich", "(Landroid/view/View;Ljava/lang/String;)V", v->view, java_text(env, text));
		break;
	case SEPHONE_OP_CHECKED:
		set_quiet(env, v, 1);
		call_void(env, v->view, "setChecked", "(Z)V", (jboolean)(o->a != 0));
		set_quiet(env, v, 0);
		break;
	case SEPHONE_OP_VALUE:
		set_quiet(env, v, 1);
		call_void(env, v->view, "setProgress", "(I)V", (jint)o->a);
		set_quiet(env, v, 0);
		break;
	case SEPHONE_OP_MAXIMUM:
		call_void(env, v->view, "setMax", "(I)V", (jint)o->a);
		break;
	case SEPHONE_OP_CHOICE_ADD:
		call_void(env, v->adapter, "add", "(Ljava/lang/Object;)V", java_text(env, text));
		break;
	case SEPHONE_OP_CHOICE_CLEAR:
		call_void(env, v->adapter, "clear", "()V");
		break;
	case SEPHONE_OP_SELECT:
		set_quiet(env, v, 1);
		if (v->kind == SEPHONE_CONTROL_RADIO_GROUP) call_void(env, v->view, "check", "(I)V", (jint)o->a);
		else call_void(env, v->view, "setSelection", "(I)V", (jint)(o->a - 1));
		set_quiet(env, v, 0);
		break;
	case SEPHONE_OP_RADIO_ADD: {
		jobject radio = new_object(env, "android/widget/RadioButton", "(Landroid/content/Context;)V", sephone_activity());
		if (radio) {
			call_void(env, radio, "setId", "(I)V", (jint)o->a);
			call_void(env, radio, "setText", "(Ljava/lang/CharSequence;)V", java_text(env, text));
			call_void(env, v->view, "addView", "(Landroid/view/View;)V", radio);
		}
		break;
	}
	case SEPHONE_OP_ROW_COUNT:
		set_row_count(env, v, o->a);
		break;
	case SEPHONE_OP_ROW:
		if (o->a >= 0 && o->a < v->row_count) {
			free(v->rows[o->a]);
			v->rows[o->a] = o->text;
			o->text = NULL;
		}
		break;
	case SEPHONE_OP_ROWS_DONE:
		call_void(env, v->adapter, "notifyDataSetChanged", "()V");
		break;
	case SEPHONE_OP_SINGLE_LINE:
		call_void(env, v->view, "setSingleLine", "(Z)V", (jboolean)(o->a != 0));
		break;
	case SEPHONE_OP_MASKED:
		/* TYPE_CLASS_TEXT, with TYPE_TEXT_VARIATION_PASSWORD when masked */
		call_void(env, v->view, "setInputType", "(I)V", (jint)(o->a ? 129 : 1));
		break;
	case SEPHONE_OP_HINT:
		call_void(env, v->view, "setHint", "(Ljava/lang/CharSequence;)V", java_text(env, text));
		break;
	case SEPHONE_OP_FOCUS:
		call_void(env, v->view, "requestFocus", "()Z");
		break;
	case SEPHONE_OP_CALL: {
		/* a = number, b = kind of argument, text = name, mark, text argument */
		char *cursor = o->text;
		jstring name = java_text(env, next_field(&cursor));
		jstring word = java_text(env, next_field(&cursor));
		call_void(env, sephone_activity(), "sephoneCall", "(Landroid/view/View;ILjava/lang/String;IILjava/lang/String;)V",
			v->view, (jint)o->id, name, (jint)o->b, (jint)o->a, word);
		break;
	}
	case SEPHONE_OP_ASK:
		call_void(env, sephone_activity(), "sephoneAsk", "(Landroid/view/View;IILjava/lang/String;)V",
			v->view, (jint)o->id, (jint)o->a, java_text(env, text));
		break;
	case SEPHONE_OP_IMAGE:
		show_image(env, o->id, v, text);
		break;
	case SEPHONE_OP_MENU:
		/* id = the anchor; a = the id the answer comes under */
		call_void(env, sephone_activity(), "sephoneMenu", "(Landroid/view/View;ILjava/lang/String;)V",
			v->view, (jint)o->a, java_text(env, text));
		break;
	case SEPHONE_OP_LISTEN:
		call_void(env, sephone_activity(), "sephoneListen", "(Landroid/view/View;ILjava/lang/String;)V",
			v->view, (jint)o->id, java_text(env, text));
		break;
	default:
		__android_log_print(ANDROID_LOG_WARN, TAG, "controls: unknown order %d", o->op);
		break;
	}
}

/* ---------------------------------------------------- Java calls these */

static void JNICALL on_ui_turn(JNIEnv *env, jclass cls)
{
	sephone_order *o;
	(void)cls;
	pthread_mutex_lock(&s_lock);
	o = s_first;
	s_first = s_last = NULL;
	s_turn_asked = 0;
	pthread_mutex_unlock(&s_lock);
	while (o) {
		sephone_order *next = o->next;
		if ((*env)->PushLocalFrame(env, 64) == 0) {
			carry_out(env, o);
			failed(env, "order");
			(*env)->PopLocalFrame(env, NULL);
		}
		free(o->text);
		free(o);
		o = next;
	}
}

static void JNICALL on_control_event(JNIEnv *env, jclass cls, jint kind, jint id, jint x, jint y, jbyteArray text)
{
	char *copy = NULL;
	(void)cls;
	if (text) {
		jsize count = (*env)->GetArrayLength(env, text);
		copy = (char *)malloc((size_t)count + 1);
		if (copy) {
			(*env)->GetByteArrayRegion(env, text, 0, count, (jbyte *)copy);
			copy[count] = 0;
		}
	}
	sephone_mail((int)kind, 0, (int)id, (int)x, (int)y, copy);
}

/* A row Eiffel has not sent yet: ask for its block, and show it blank until then. */
static jbyteArray JNICALL on_row_text(JNIEnv *env, jclass cls, jint list, jint position)
{
	sephone_view *v = view_of((int)list);
	const char *text;
	jsize count;
	jbyteArray result;
	(void)cls;
	if (!v || position < 0 || position >= v->row_count) return NULL;
	text = v->rows[position];
	if (!text) {
		int block = (int)position / ROW_BLOCK;
		if (!v->asked[block]) {
			v->asked[block] = 1;
			sephone_mail(SEPHONE_CONTROL_ROWS, 0, (int)list, block * ROW_BLOCK, 0, NULL);
		}
		return NULL;
	}
	count = (jsize)strlen(text);
	result = (*env)->NewByteArray(env, count);
	if (result) (*env)->SetByteArrayRegion(env, result, 0, count, (const jbyte *)text);
	return result;
}

/* ----------------------------------------------------- Eiffel calls these */

int sephone_controls_present(void) { return s_ready; }

int sephone_controls_density_percent(void) { return (int)(s_density * 100.0f + 0.5f); }

void sephone_control(int op, int id, int a, int b, const char *text)
{
	sephone_order *o = (sephone_order *)calloc(1, sizeof(sephone_order));
	int ask;
	if (!o || !s_ready) {
		free(o);
		return;
	}
	o->op = op;
	o->id = id;
	o->a = a;
	o->b = b;
	o->text = text ? strdup(text) : NULL;
	pthread_mutex_lock(&s_lock);
	if (s_last) s_last->next = o;
	else s_first = o;
	s_last = o;
	ask = !s_turn_asked;
	s_turn_asked = 1;
	pthread_mutex_unlock(&s_lock);
	if (ask) {
		JNIEnv *env = sephone_thread_env();
		(*env)->CallVoidMethod(env, sephone_activity(), s_m_post);
		failed(env, "sephoneUiPost");
	}
}

/* ---------------------------------------------------------------- drawing */

int sephone_canvas_begin(int id, int background)
{
	JNIEnv *env = sephone_thread_env();
	sephone_view *v = view_of(id);
	if (!s_ready || s_canvas || !v || !v->holder) return 0;
	s_canvas = (*env)->CallObjectMethod(env, v->holder, s_m_lock);
	if (failed(env, "lockCanvas") || !s_canvas) {
		s_canvas = NULL;
		return 0;
	}
	s_holder = v->holder;
	(*env)->CallVoidMethod(env, s_canvas, s_m_draw_color, (jint)(0xFF000000u | (unsigned)background));
	(*env)->CallVoidMethod(env, s_canvas, s_m_scale, (jfloat)s_density, (jfloat)s_density);
	return 1;
}

void sephone_canvas_end(void)
{
	JNIEnv *env = sephone_thread_env();
	if (!s_canvas) return;
	(*env)->CallVoidMethod(env, s_holder, s_m_unlock, s_canvas);
	failed(env, "unlockCanvasAndPost");
	(*env)->DeleteLocalRef(env, s_canvas);
	s_canvas = NULL;
	s_holder = NULL;
}

void sephone_canvas_color(int rgb)
{
	JNIEnv *env = sephone_thread_env();
	if (s_paint) (*env)->CallVoidMethod(env, s_paint, s_m_set_color, (jint)(0xFF000000u | (unsigned)rgb));
}

void sephone_canvas_rect(double x, double y, double w, double h)
{
	JNIEnv *env = sephone_thread_env();
	if (s_canvas) (*env)->CallVoidMethod(env, s_canvas, s_m_draw_rect, (jfloat)x, (jfloat)y, (jfloat)(x + w), (jfloat)(y + h), s_paint);
}

void sephone_canvas_line(double x1, double y1, double x2, double y2, double width)
{
	JNIEnv *env = sephone_thread_env();
	if (!s_canvas) return;
	(*env)->CallVoidMethod(env, s_paint, s_m_set_stroke, (jfloat)width);
	(*env)->CallVoidMethod(env, s_canvas, s_m_draw_line, (jfloat)x1, (jfloat)y1, (jfloat)x2, (jfloat)y2, s_paint);
}

void sephone_canvas_text(double x, double y, const char *text, double size, int bold)
{
	JNIEnv *env = sephone_thread_env();
	jstring words;
	if (!s_canvas) return;
	words = java_text(env, text);
	(*env)->CallVoidMethod(env, s_paint, s_m_set_size, (jfloat)size);
	(*env)->CallVoidMethod(env, s_paint, s_m_set_bold, (jboolean)(bold != 0));
	(*env)->CallVoidMethod(env, s_canvas, s_m_draw_text, words, (jfloat)x, (jfloat)y, s_paint);
	(*env)->DeleteLocalRef(env, words);
}

double sephone_canvas_measure(const char *text, double size, int bold)
{
	JNIEnv *env = sephone_thread_env();
	jstring words;
	double result;
	if (!s_paint) return 0.0;
	words = java_text(env, text);
	(*env)->CallVoidMethod(env, s_paint, s_m_set_size, (jfloat)size);
	(*env)->CallVoidMethod(env, s_paint, s_m_set_bold, (jboolean)(bold != 0));
	result = (double)(*env)->CallFloatMethod(env, s_paint, s_m_measure, words);
	(*env)->DeleteLocalRef(env, words);
	return result;
}

/* ------------------------------------------------------------------ setup */

static void setup_drawing(JNIEnv *env)
{
	jclass holder = (*env)->FindClass(env, "android/view/SurfaceHolder");
	jclass canvas = (*env)->FindClass(env, "android/graphics/Canvas");
	jclass paint = (*env)->FindClass(env, "android/graphics/Paint");
	jobject local;
	s_m_lock = (*env)->GetMethodID(env, holder, "lockCanvas", "()Landroid/graphics/Canvas;");
	s_m_unlock = (*env)->GetMethodID(env, holder, "unlockCanvasAndPost", "(Landroid/graphics/Canvas;)V");
	s_m_scale = (*env)->GetMethodID(env, canvas, "scale", "(FF)V");
	s_m_draw_color = (*env)->GetMethodID(env, canvas, "drawColor", "(I)V");
	s_m_draw_rect = (*env)->GetMethodID(env, canvas, "drawRect", "(FFFFLandroid/graphics/Paint;)V");
	s_m_draw_line = (*env)->GetMethodID(env, canvas, "drawLine", "(FFFFLandroid/graphics/Paint;)V");
	s_m_draw_text = (*env)->GetMethodID(env, canvas, "drawText", "(Ljava/lang/String;FFLandroid/graphics/Paint;)V");
	s_m_set_color = (*env)->GetMethodID(env, paint, "setColor", "(I)V");
	s_m_set_stroke = (*env)->GetMethodID(env, paint, "setStrokeWidth", "(F)V");
	s_m_set_size = (*env)->GetMethodID(env, paint, "setTextSize", "(F)V");
	s_m_set_bold = (*env)->GetMethodID(env, paint, "setFakeBoldText", "(Z)V");
	s_m_measure = (*env)->GetMethodID(env, paint, "measureText", "(Ljava/lang/String;)F");
	failed(env, "drawing setup");
	/* Paint.ANTI_ALIAS_FLAG = 1 */
	local = new_object(env, "android/graphics/Paint", "(I)V", (jint)1);
	s_paint = global(env, local);
	if (s_paint) {
		/* Round line ends, so that a drawn stroke has no gaps. */
		jclass cap = (*env)->FindClass(env, "android/graphics/Paint$Cap");
		jfieldID round = (*env)->GetStaticFieldID(env, cap, "ROUND", "Landroid/graphics/Paint$Cap;");
		call_void(env, s_paint, "setStrokeCap", "(Landroid/graphics/Paint$Cap;)V", (*env)->GetStaticObjectField(env, cap, round));
	}
}

static void read_density(JNIEnv *env)
{
	jobject resources = call_object(env, sephone_activity(), "getResources", "()Landroid/content/res/Resources;");
	jobject metrics = resources ? call_object(env, resources, "getDisplayMetrics", "()Landroid/util/DisplayMetrics;") : NULL;
	if (metrics) {
		jclass cls = (*env)->GetObjectClass(env, metrics);
		jfieldID f = (*env)->GetFieldID(env, cls, "density", "F");
		s_density = (*env)->GetFloatField(env, metrics, f);
		(*env)->DeleteLocalRef(env, cls);
		(*env)->DeleteLocalRef(env, metrics);
	}
	if (resources) (*env)->DeleteLocalRef(env, resources);
}

void sephone_controls_setup(JNIEnv *env, jclass cls)
{
	static JNINativeMethod natives[] = {
		{ "sephoneControlEvent", "(IIII[B)V", (void *)on_control_event },
		{ "sephoneUiTurn", "()V", (void *)on_ui_turn },
		{ "sephoneRowText", "(II)[B", (void *)on_row_text }
	};
	s_m_post = (*env)->GetMethodID(env, cls, "sephoneUiPost", "()V");
	if (!s_m_post) {
		(*env)->ExceptionClear(env);   /* not a controls app */
		return;
	}
	if ((*env)->RegisterNatives(env, cls, natives, 3) != 0) {
		failed(env, "RegisterNatives");
		return;
	}
	read_density(env);
	setup_drawing(env);
	s_ready = 1;
}
