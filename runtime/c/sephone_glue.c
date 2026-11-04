/*
 * sephone_glue.c - the Android side of simple_eif_phone.
 * Contract: sephone.h (read it first). Built into every app's .so by eifphone,
 * together with the NDK's android_native_app_glue.c and the gec-generated C.
 *
 * Flow: NativeActivity -> native_app_glue thread -> android_main (below)
 *       -> GE_main (the Eiffel system) -> Eiffel pulls events with sephone_wait.
 */
#include <android_native_app_glue.h>
#include <android/asset_manager.h>
#include <android/configuration.h>
#include <android/input.h>
#include <android/keycodes.h>
#include <android/log.h>
#include <android/native_window.h>
#include <android/window.h>
#include <jni.h>
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include "sephone.h"
#include "sephone_bridge.h"

extern int GE_main(int argc, char **argv);

#define SEPHONE_TAG "EifPhone"
#define SEPHONE_QUEUE_BLOCK 1024

typedef struct {
	int kind, time, id, x, y, code;
	char *text;   /* service events only; owned by the event */
} sephone_event;

/* What Java has sent and the Eiffel thread has not yet taken. See sephone.h. */
typedef struct sephone_note {
	int kind, code, id, x, y;
	char *text;
	struct sephone_note *next;
} sephone_note;

static struct android_app *s_app = NULL;
static sephone_event *s_queue = NULL;
static int s_cap = 0, s_head = 0, s_count = 0;
static sephone_event s_cur;
static int s_dropped = 0, s_delivered = 0, s_handle = 0;
static int s_back_policy = SEPHONE_BACK_SYSTEM;
static int s_destroy_queued = 0;
static ANativeWindow_Buffer s_buf;
static int s_locked = 0;
static ARect s_content;   /* snapshot of app->contentRect, copied under app->mutex */
static int s_inset_left = 0, s_inset_top = 0, s_inset_right = 0, s_inset_bottom = 0;
static JNIEnv *s_env = NULL;   /* this thread's JNI handle; attached in android_main */
static pthread_mutex_t s_mail_lock = PTHREAD_MUTEX_INITIALIZER;
static sephone_note *s_mail_first = NULL, *s_mail_last = NULL;
static int s_helper = 0;
static jmethodID s_m_speech_start = NULL, s_m_speak = NULL, s_m_speech_stop = NULL, s_m_pick = NULL, s_m_keyboard = NULL;

/* ------------------------------------------------------------------ time */

static int sephone_ms_from_ns(int64_t ns)
{
	return (int)((ns / 1000000) & 0x7FFFFFFF);
}

static int64_t sephone_now_ns(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* ----------------------------------------------------------------- queue */

static sephone_event *sephone_slot(int i)
{
	return &s_queue[(s_head + i) % s_cap];
}

static int sephone_grow(void)
{
	int new_cap = s_cap + SEPHONE_QUEUE_BLOCK, i;
	sephone_event *q = (sephone_event *)malloc(sizeof(sephone_event) * (size_t)new_cap);
	if (!q) return 0;
	for (i = 0; i < s_count; i++) q[i] = *sephone_slot(i);
	free(s_queue);
	s_queue = q;
	s_cap = new_cap;
	s_head = 0;
	return 1;
}

static char *s_push_text = NULL;   /* text for the next push; the event takes it over */

static void sephone_push(int kind, int time, int id, int x, int y, int code)
{
	sephone_event e;
	int i;
	e.kind = kind; e.time = time; e.id = id; e.x = x; e.y = y; e.code = code;
	e.text = s_push_text;
	s_push_text = NULL;
	if (s_count == s_cap) {
		/* 1. Coalesce a move onto the trailing run of queued moves of the same pointer. */
		if (kind == SEPHONE_TOUCH_MOVE) {
			for (i = s_count - 1; i >= 0 && sephone_slot(i)->kind == SEPHONE_TOUCH_MOVE; i--) {
				if (sephone_slot(i)->id == id) {
					*sephone_slot(i) = e;
					return;
				}
			}
		}
		/* 2. Drop the oldest queued move. */
		for (i = 0; i < s_count; i++) {
			if (sephone_slot(i)->kind == SEPHONE_TOUCH_MOVE) {
				int j;
				for (j = i; j < s_count - 1; j++) *sephone_slot(j) = *sephone_slot(j + 1);
				s_count--;
				s_dropped++;
				break;
			}
		}
		/* 3. Still full: grow; never drop a lifecycle or key event. */
		if (s_count == s_cap && !sephone_grow()) {
			__android_log_write(ANDROID_LOG_FATAL, SEPHONE_TAG, "event queue cannot grow; finishing");
			ANativeActivity_finish(s_app->activity);
			return;
		}
	}
	*sephone_slot(s_count) = e;
	s_count++;
}

static void sephone_push_lifecycle(int kind)
{
	sephone_push(kind, sephone_ms_from_ns(sephone_now_ns()), -1, 0, 0, 0);
}

/* ------------------------------------------------------- Android callbacks */

static void sephone_on_cmd(struct android_app *app, int32_t cmd)
{
	switch (cmd) {
	case APP_CMD_START: sephone_push_lifecycle(SEPHONE_STARTED); break;
	case APP_CMD_RESUME: sephone_push_lifecycle(SEPHONE_RESUMED); break;
	case APP_CMD_PAUSE: sephone_push_lifecycle(SEPHONE_PAUSED); break;
	case APP_CMD_STOP: sephone_push_lifecycle(SEPHONE_STOPPED); break;
	case APP_CMD_DESTROY:
		s_destroy_queued = 1;   /* RB-8: from now on there is no window for Eiffel */
		sephone_push_lifecycle(SEPHONE_DESTROYED);
		break;
	case APP_CMD_INIT_WINDOW:
		if (app->window) ANativeWindow_setBuffersGeometry(app->window, 0, 0, WINDOW_FORMAT_RGBX_8888);
		sephone_push_lifecycle(SEPHONE_WINDOW_READY);
		break;
	case APP_CMD_TERM_WINDOW: sephone_push_lifecycle(SEPHONE_WINDOW_LOST); break;
	case APP_CMD_WINDOW_RESIZED: sephone_push_lifecycle(SEPHONE_WINDOW_RESIZED); break;
	case APP_CMD_WINDOW_REDRAW_NEEDED: sephone_push_lifecycle(SEPHONE_REDRAW_NEEDED); break;
	case APP_CMD_GAINED_FOCUS: sephone_push_lifecycle(SEPHONE_FOCUS_GAINED); break;
	case APP_CMD_LOST_FOCUS: sephone_push_lifecycle(SEPHONE_FOCUS_LOST); break;
	case APP_CMD_CONFIG_CHANGED: sephone_push_lifecycle(SEPHONE_CONFIGURATION_CHANGED); break;
	case APP_CMD_LOW_MEMORY: sephone_push_lifecycle(SEPHONE_LOW_MEMORY); break;
	case APP_CMD_CONTENT_RECT_CHANGED:
		/* RB-3: the UI thread writes contentRect under app->mutex. */
		pthread_mutex_lock(&app->mutex);
		s_content = app->contentRect;
		pthread_mutex_unlock(&app->mutex);
		sephone_push_lifecycle(SEPHONE_CONTENT_RECT_CHANGED);
		break;
	default:
		break;
	}
}

static int32_t sephone_on_input(struct android_app *app, AInputEvent *ev)
{
	int32_t type = AInputEvent_getType(ev);
	(void)app;
	if (type == AINPUT_EVENT_TYPE_MOTION) {
		int32_t action = AMotionEvent_getAction(ev);
		int32_t masked = action & AMOTION_EVENT_ACTION_MASK;
		size_t index = (size_t)((action & AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT);
		int t = sephone_ms_from_ns(AMotionEvent_getEventTime(ev));
		size_t i, n;
		switch (masked) {
		case AMOTION_EVENT_ACTION_DOWN:
		case AMOTION_EVENT_ACTION_POINTER_DOWN:
			sephone_push(SEPHONE_TOUCH_DOWN, t, (int)AMotionEvent_getPointerId(ev, index),
				(int)lroundf(AMotionEvent_getX(ev, index)), (int)lroundf(AMotionEvent_getY(ev, index)), 0);
			break;
		case AMOTION_EVENT_ACTION_UP:
		case AMOTION_EVENT_ACTION_POINTER_UP:
			sephone_push(SEPHONE_TOUCH_UP, t, (int)AMotionEvent_getPointerId(ev, index),
				(int)lroundf(AMotionEvent_getX(ev, index)), (int)lroundf(AMotionEvent_getY(ev, index)), 0);
			break;
		case AMOTION_EVENT_ACTION_MOVE:
			n = AMotionEvent_getPointerCount(ev);
			for (i = 0; i < n; i++) {
				sephone_push(SEPHONE_TOUCH_MOVE, t, (int)AMotionEvent_getPointerId(ev, i),
					(int)lroundf(AMotionEvent_getX(ev, i)), (int)lroundf(AMotionEvent_getY(ev, i)), 0);
			}
			break;
		case AMOTION_EVENT_ACTION_CANCEL:
			sephone_push(SEPHONE_TOUCH_CANCEL, t, 0, 0, 0, 0);
			break;
		default:
			break;
		}
		return 1;
	}
	if (type == AINPUT_EVENT_TYPE_KEY) {
		int32_t code = AKeyEvent_getKeyCode(ev);
		int32_t action = AKeyEvent_getAction(ev);
		int t = sephone_ms_from_ns(AKeyEvent_getEventTime(ev));
		if (code == AKEYCODE_UNKNOWN) return 0;   /* RB-5 */
		if (action == AKEY_EVENT_ACTION_DOWN) sephone_push(SEPHONE_KEY_DOWN, t, -1, 0, 0, code);
		else if (action == AKEY_EVENT_ACTION_UP) sephone_push(SEPHONE_KEY_UP, t, -1, 0, 0, code);
		if (code == AKEYCODE_BACK) return s_back_policy == SEPHONE_BACK_APP ? 1 : 0;
		return 0;
	}
	return 0;
}

/* ----------------------------------------------------------- stdout/err */

static int s_out_pipe[2];

static void *sephone_out_reader(void *arg)
{
	char buf[1024];
	ssize_t n;
	(void)arg;
	while ((n = read(s_out_pipe[0], buf, sizeof(buf) - 1)) > 0) {
		buf[n] = '\0';
		__android_log_write(ANDROID_LOG_INFO, "EiffelOut", buf);
	}
	return NULL;
}

/* Eiffel's console output (print, exception traces) goes to logcat. */
static void sephone_redirect_output(void)
{
	pthread_t thread;
	setvbuf(stdout, NULL, _IOLBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);
	if (pipe(s_out_pipe) != 0) return;
	dup2(s_out_pipe[1], 1);
	dup2(s_out_pipe[1], 2);
	if (pthread_create(&thread, NULL, sephone_out_reader, NULL) == 0) pthread_detach(thread);
}

/* --------------------------------------------------------------- handle */

int sephone_handle_exists(void) { return s_handle; }
void sephone_handle_claim(void) { s_handle = 1; }

/* --------------------------------------------------------------- events */

/* Move Java's answers into the queue. Runs on the android_main thread. */
static void sephone_drain_mail(void)
{
	sephone_note *n;
	pthread_mutex_lock(&s_mail_lock);
	n = s_mail_first;
	s_mail_first = s_mail_last = NULL;
	pthread_mutex_unlock(&s_mail_lock);
	while (n) {
		sephone_note *next = n->next;
		s_push_text = n->text;
		sephone_push(n->kind, sephone_ms_from_ns(sephone_now_ns()), n->id, n->x, n->y, n->code);
		free(n);
		n = next;
	}
}

int sephone_wait(int timeout_ms)
{
	int64_t deadline = timeout_ms < 0 ? -1 : sephone_now_ns() + (int64_t)timeout_ms * 1000000LL;
	sephone_drain_mail();
	while (s_count == 0) {   /* G-1: poll Android only while the queue is empty */
		struct android_poll_source *src = NULL;
		int events = 0, wait_ms = -1, r;
		if (deadline >= 0) {
			int64_t left = deadline - sephone_now_ns();
			if (left <= 0) return 0;
			wait_ms = (int)((left + 999999) / 1000000);
		}
		r = ALooper_pollOnce(wait_ms, NULL, &events, (void **)&src);
		if (r >= 0 && src) src->process(s_app, src);   /* one command per call */
		sephone_drain_mail();
	}
	return 1;
}

void sephone_take(void)
{
	if (s_count == 0) return;
	free(s_cur.text);
	s_cur = *sephone_slot(0);
	s_head = (s_head + 1) % s_cap;
	s_count--;
	s_delivered++;
}

int sephone_cur_kind(void) { return s_cur.kind; }
int sephone_cur_time(void) { return s_cur.time; }
int sephone_cur_id(void) { return s_cur.id; }
int sephone_cur_x(void) { return s_cur.x; }
int sephone_cur_y(void) { return s_cur.y; }
int sephone_cur_code(void) { return s_cur.code; }
const char *sephone_cur_text(void) { return s_cur.text; }
int sephone_dropped(void) { return s_dropped; }
int sephone_delivery_count(void) { return s_delivered; }

/* ------------------------------------------------------- Java services */

/* Any thread: the mailbox is all it touches. */
void sephone_mail(int kind, int code, int id, int x, int y, char *text)
{
	sephone_note *n = (sephone_note *)calloc(1, sizeof(sephone_note));
	if (!n) {
		free(text);
		return;
	}
	n->kind = kind;
	n->code = code;
	n->id = id;
	n->x = x;
	n->y = y;
	n->text = text;
	pthread_mutex_lock(&s_mail_lock);
	if (s_mail_last) s_mail_last->next = n;
	else s_mail_first = n;
	s_mail_last = n;
	pthread_mutex_unlock(&s_mail_lock);
	if (s_app) ALooper_wake(s_app->looper);
}

jobject sephone_activity(void) { return s_app->activity->clazz; }
JNIEnv *sephone_thread_env(void) { return s_env; }

/* Registered on EifPhoneActivity. Runs on Java's threads: mailbox only. */
static void JNICALL sephone_java_event(JNIEnv *env, jclass cls, jint kind, jint code, jbyteArray text)
{
	jsize count = text ? (*env)->GetArrayLength(env, text) : 0;
	char *copy = NULL;
	(void)cls;
	if (count > 0) {
		copy = (char *)malloc((size_t)count + 1);
		if (copy) {
			(*env)->GetByteArrayRegion(env, text, 0, count, (jbyte *)copy);
			copy[count] = 0;
		}
	}
	sephone_mail((int)kind, (int)code, -1, 0, 0, copy);
}

static jmethodID sephone_helper_method(JNIEnv *env, jclass cls, const char *name, const char *sig)
{
	jmethodID m = (*env)->GetMethodID(env, cls, name, sig);
	if ((*env)->ExceptionCheck(env)) {
		(*env)->ExceptionClear(env);
		m = NULL;
	}
	return m;
}

/* Find the helper, if this app has one. A plain NativeActivity has none. */
static void sephone_java_setup(void)
{
	static JNINativeMethod native = { "sephoneEvent", "(II[B)V", (void *)sephone_java_event };
	JNIEnv *env = s_env;
	jclass cls;
	if (!env) return;
	cls = (*env)->GetObjectClass(env, s_app->activity->clazz);
	s_m_speech_start = sephone_helper_method(env, cls, "sephoneSpeechStart", "()V");
	s_m_speak = sephone_helper_method(env, cls, "sephoneSpeak", "([B[B)V");
	s_m_speech_stop = sephone_helper_method(env, cls, "sephoneSpeechStop", "()V");
	s_m_pick = sephone_helper_method(env, cls, "sephonePickFile", "([B)V");
	s_m_keyboard = sephone_helper_method(env, cls, "sephoneKeyboard", "(I)V");
	if (s_m_speech_start && s_m_speak && s_m_speech_stop && s_m_pick && s_m_keyboard) {
		if ((*env)->RegisterNatives(env, cls, &native, 1) == 0) s_helper = 1;
		else (*env)->ExceptionClear(env);
	}
	if (s_helper) sephone_controls_setup(env, cls);
	(*env)->DeleteLocalRef(env, cls);
}

static jbyteArray sephone_bytes(JNIEnv *env, const char *text)
{
	jsize count = (jsize)strlen(text);
	jbyteArray result = (*env)->NewByteArray(env, count);
	if (result) (*env)->SetByteArrayRegion(env, result, 0, count, (const jbyte *)text);
	return result;
}

static void sephone_clear_exception(JNIEnv *env)
{
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
}

int sephone_helper_present(void) { return s_helper; }

void sephone_speech_start(void)
{
	if (!s_helper) return;
	(*s_env)->CallVoidMethod(s_env, s_app->activity->clazz, s_m_speech_start);
	sephone_clear_exception(s_env);
}

void sephone_speak(const char *text, const char *language)
{
	jbyteArray a, b;
	if (!s_helper) return;
	a = sephone_bytes(s_env, text);
	b = sephone_bytes(s_env, language);
	(*s_env)->CallVoidMethod(s_env, s_app->activity->clazz, s_m_speak, a, b);
	sephone_clear_exception(s_env);
	(*s_env)->DeleteLocalRef(s_env, a);
	(*s_env)->DeleteLocalRef(s_env, b);
}

void sephone_speech_stop(void)
{
	if (!s_helper) return;
	(*s_env)->CallVoidMethod(s_env, s_app->activity->clazz, s_m_speech_stop);
	sephone_clear_exception(s_env);
}

void sephone_pick_file(const char *type)
{
	jbyteArray a;
	if (!s_helper) return;
	a = sephone_bytes(s_env, type);
	(*s_env)->CallVoidMethod(s_env, s_app->activity->clazz, s_m_pick, a);
	sephone_clear_exception(s_env);
	(*s_env)->DeleteLocalRef(s_env, a);
}

void sephone_keyboard(int show)
{
	if (!s_helper) return;
	(*s_env)->CallVoidMethod(s_env, s_app->activity->clazz, s_m_keyboard, (jint)show);
	sephone_clear_exception(s_env);
}

/* TEST ONLY (examples/phone_tests): exercise the overflow rule without a device driver. */
void sephone_test_push(int kind, int id, int x, int y, int code)
{
	sephone_push(kind, sephone_ms_from_ns(sephone_now_ns()), id, x, y, code);
}

int sephone_test_capacity(void) { return s_cap; }

/* ------------------------------------------------------------- behavior */

void sephone_set_back_policy(int policy) { s_back_policy = policy; }
int sephone_back_policy(void) { return s_back_policy; }

void sephone_keep_screen_on(int on)
{
	if (on) ANativeActivity_setWindowFlags(s_app->activity, AWINDOW_FLAG_KEEP_SCREEN_ON, 0);
	else ANativeActivity_setWindowFlags(s_app->activity, 0, AWINDOW_FLAG_KEEP_SCREEN_ON);
}

void sephone_finish(void) { ANativeActivity_finish(s_app->activity); }

/* ------------------------------------------------------- window, frame */

int sephone_window_exists(void) { return s_app->window != NULL && !s_destroy_queued; }

int sephone_window_width(void)
{
	if (s_locked) return s_buf.width;
	return sephone_window_exists() ? ANativeWindow_getWidth(s_app->window) : 0;
}

int sephone_window_height(void)
{
	if (s_locked) return s_buf.height;
	return sephone_window_exists() ? ANativeWindow_getHeight(s_app->window) : 0;
}

int sephone_frame_lock(void)
{
	if (s_locked || !sephone_window_exists()) return 0;
	if (ANativeWindow_lock(s_app->window, &s_buf, NULL) != 0) return 0;
	s_locked = 1;
	return 1;
}

void sephone_frame_unlock(void)
{
	if (!s_locked) return;
	ANativeWindow_unlockAndPost(s_app->window);
	s_locked = 0;
}

/* RGBX_8888 is R,G,B,X bytes in memory: little-endian word 0xXXBBGGRR. */
static uint32_t sephone_rgbx(uint32_t rgb)
{
	return 0xFF000000u | ((rgb & 0xFFu) << 16) | (rgb & 0xFF00u) | ((rgb >> 16) & 0xFFu);
}

void sephone_frame_fill(int x, int y, int w, int h, int rgb)
{
	int x1 = x + w, y1 = y + h, row, col;
	uint32_t px = sephone_rgbx((uint32_t)rgb), *line;
	if (!s_locked) return;
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	if (x1 > s_buf.width) x1 = s_buf.width;
	if (y1 > s_buf.height) y1 = s_buf.height;
	for (row = y; row < y1; row++) {
		line = (uint32_t *)s_buf.bits + (size_t)row * (size_t)s_buf.stride;
		for (col = x; col < x1; col++) line[col] = px;
	}
}

void sephone_frame_present_argb_at(const void *pixels, int width, int height, int stride, int x, int y)
{
	int rows, cols, r, c;
	if (!s_locked || !pixels || x < 0 || y < 0) return;
	rows = height < s_buf.height - y ? height : s_buf.height - y;
	cols = width < s_buf.width - x ? width : s_buf.width - x;
	for (r = 0; r < rows; r++) {
		const uint32_t *src = (const uint32_t *)((const char *)pixels + (size_t)r * (size_t)stride);
		uint32_t *dst = (uint32_t *)s_buf.bits + (size_t)(r + y) * (size_t)s_buf.stride + (size_t)x;
		for (c = 0; c < cols; c++) dst[c] = sephone_rgbx(src[c] & 0xFFFFFFu);   /* cairo ARGB32: 0xAARRGGBB */
	}
}

void sephone_frame_present_argb(const void *pixels, int width, int height, int stride)
{
	sephone_frame_present_argb_at(pixels, width, height, stride, 0, 0);
}

uint32_t sephone_frame_peek(int x, int y)
{
	if (!s_locked || x < 0 || y < 0 || x >= s_buf.width || y >= s_buf.height) return 0;
	return ((uint32_t *)s_buf.bits)[(size_t)y * (size_t)s_buf.stride + (size_t)x];
}

/* -------------------------------------------------------------- metrics */

int sephone_metric_density(void)
{
	int32_t d = AConfiguration_getDensity(s_app->config);
	if (d < 120 || d > 640) return 160;   /* also covers 0, 0xfffe (ANY), 0xffff (NONE) */
	return (int)d;
}

/*
 * System bars. At targetSdk 35+ Android lays the app out edge to edge, so
 * app->contentRect covers the whole window even with bars on screen (found by
 * examples/phone_tests, 2026-11-03: insets read 0,0,0,0). The bars are read here
 * through JNI: Activity.getWindow().getDecorView().getRootWindowInsets().
 * Called when PHONE_METRICS refreshes; keeps the last values if unavailable.
 */
static jobject sephone_call_object(jobject target, const char *name, const char *sig)
{
	JNIEnv *env = s_env;
	jobject result = NULL;
	jclass cls = (*env)->GetObjectClass(env, target);
	jmethodID m = (*env)->GetMethodID(env, cls, name, sig);
	if (m) result = (*env)->CallObjectMethod(env, target, m);
	(*env)->DeleteLocalRef(env, cls);
	return result;
}

static int sephone_call_int(jobject target, const char *name)
{
	JNIEnv *env = s_env;
	int result = 0;
	jclass cls = (*env)->GetObjectClass(env, target);
	jmethodID m = (*env)->GetMethodID(env, cls, name, "()I");
	if (m) result = (*env)->CallIntMethod(env, target, m);
	(*env)->DeleteLocalRef(env, cls);
	return result;
}

static void sephone_read_insets(void)
{
	JNIEnv *env = s_env;
	jobject window, decor, insets;
	if (!env) return;
	window = sephone_call_object(s_app->activity->clazz, "getWindow", "()Landroid/view/Window;");
	if (window) {
		decor = sephone_call_object(window, "getDecorView", "()Landroid/view/View;");
		if (decor) {
			insets = sephone_call_object(decor, "getRootWindowInsets", "()Landroid/view/WindowInsets;");
			if (insets) {
				s_inset_left = sephone_call_int(insets, "getSystemWindowInsetLeft");
				s_inset_top = sephone_call_int(insets, "getSystemWindowInsetTop");
				s_inset_right = sephone_call_int(insets, "getSystemWindowInsetRight");
				s_inset_bottom = sephone_call_int(insets, "getSystemWindowInsetBottom");
				(*env)->DeleteLocalRef(env, insets);
			}
			(*env)->DeleteLocalRef(env, decor);
		}
		(*env)->DeleteLocalRef(env, window);
	}
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
}

/* The content rectangle: Android's, further reduced by the system bars.
   PHONE_METRICS.refresh reads left first, so that read refreshes the bars. */
int sephone_metric_content_left(void)
{
	sephone_read_insets();
	return s_content.left > s_inset_left ? s_content.left : s_inset_left;
}

int sephone_metric_content_top(void)
{
	return s_content.top > s_inset_top ? s_content.top : s_inset_top;
}

int sephone_metric_content_right(void)
{
	int limit = sephone_window_width() - s_inset_right;
	return (s_content.right > 0 && s_content.right < limit) ? s_content.right : limit;
}

int sephone_metric_content_bottom(void)
{
	int limit = sephone_window_height() - s_inset_bottom;
	return (s_content.bottom > 0 && s_content.bottom < limit) ? s_content.bottom : limit;
}

int sephone_metric_rtl(void)
{
	return AConfiguration_getLayoutDirection(s_app->config) == ACONFIGURATION_LAYOUTDIR_RTL;
}

/* -------------------------------------------------------------- storage */

const char *sephone_path_internal(void) { return s_app->activity->internalDataPath; }
const char *sephone_path_external(void) { return s_app->activity->externalDataPath; }

/* --------------------------------------------------------------- assets */

int sephone_asset_size(const char *name)
{
	AAsset *a = AAssetManager_open(s_app->activity->assetManager, name, AASSET_MODE_BUFFER);
	int n;
	if (!a) return -1;
	n = (int)AAsset_getLength(a);
	AAsset_close(a);
	return n;
}

int sephone_asset_read(const char *name, void *buf, int n)
{
	AAsset *a = AAssetManager_open(s_app->activity->assetManager, name, AASSET_MODE_BUFFER);
	int total = 0, got;
	if (!a) return -1;
	while (total < n && (got = AAsset_read(a, (char *)buf + total, (size_t)(n - total))) > 0) total += got;
	AAsset_close(a);
	return total;
}

/* ------------------------------------------------------------------ log */

void sephone_log(int level, const char *tag, const char *text)
{
	__android_log_write(level, tag, text);
}

/* ---------------------------------------------------------- entry point */

/* One Eiffel system per process. Android can start a new activity in this
   process while the old one is still ending (Back, then a quick relaunch).
   A second GE_main would overwrite this file's state and abort in the garbage
   collector, so the later arrival waits for the first to end the process,
   then ends it itself. Android then starts the app fresh. */
static int s_main_claimed = 0;

static void sephone_end_process(void)
{
	fflush(NULL);
	_exit(0);   /* not exit(): atexit handlers race Android's own threads */
}

static void sephone_second_main(struct android_app *app)
{
	int64_t until = sephone_now_ns() + 2000000000LL;
	__android_log_write(ANDROID_LOG_WARN, SEPHONE_TAG, "android_main: a second activity arrived; ending the process for a fresh start");
	while (sephone_now_ns() < until) {
		struct android_poll_source *src = NULL;
		int events = 0;
		if (ALooper_pollOnce(100, NULL, &events, (void **)&src) >= 0 && src) src->process(app, src);
	}
	sephone_end_process();
}

void android_main(struct android_app *app)
{
	char *argv[] = { "eiffel", NULL };
	if (!__sync_bool_compare_and_swap(&s_main_claimed, 0, 1)) {
		sephone_second_main(app);
		return;
	}
	s_app = app;
	s_cap = SEPHONE_QUEUE_BLOCK;
	s_queue = (sephone_event *)malloc(sizeof(sephone_event) * (size_t)s_cap);
	s_head = s_count = 0;
	memset(&s_cur, 0, sizeof s_cur);
	memset(&s_content, 0, sizeof s_content);
	app->onAppCmd = sephone_on_cmd;
	app->onInputEvent = sephone_on_input;
	sephone_redirect_output();
	if ((*app->activity->vm)->AttachCurrentThread(app->activity->vm, &s_env, NULL) != 0) s_env = NULL;
	sephone_java_setup();
	/* Android starts an app in /, which it cannot write. Plain relative file names
	   work from the app's own folder, as they do on a PC. */
	if (app->activity->internalDataPath) {
		mkdir(app->activity->internalDataPath, 0700);
		if (chdir(app->activity->internalDataPath) != 0)
			__android_log_write(ANDROID_LOG_WARN, SEPHONE_TAG, "android_main: cannot enter the app folder");
	}
	__android_log_write(ANDROID_LOG_INFO, SEPHONE_TAG, "android_main: starting Eiffel");
	GE_main(1, argv);
	__android_log_write(ANDROID_LOG_INFO, SEPHONE_TAG, "android_main: Eiffel returned; ending the process");
	/* D-012: finish, wait for Android to destroy us, then end the process so
	   the next launch starts with fresh Eiffel once-objects and C state. */
	if (!app->destroyRequested) {
		ANativeActivity_finish(app->activity);
		while (!app->destroyRequested) {
			struct android_poll_source *src = NULL;
			int events = 0;
			if (ALooper_pollOnce(-1, NULL, &events, (void **)&src) >= 0 && src) src->process(app, src);
		}
	}
	sephone_end_process();
}
