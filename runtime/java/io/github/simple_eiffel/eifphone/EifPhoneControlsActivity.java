package io.github.simple_eiffel.eifphone;

import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.app.TimePickerDialog;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Insets;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextWatcher;
import android.text.style.ForegroundColorSpan;
import android.text.style.LineHeightSpan;
import android.text.style.RelativeSizeSpan;
import android.text.style.StyleSpan;
import android.text.style.SuperscriptSpan;
import android.text.TextPaint;
import android.text.style.ClickableSpan;
import android.text.style.TypefaceSpan;
import android.text.style.UnderlineSpan;
import android.view.Gravity;
import android.util.TypedValue;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.CompoundButton;
import android.widget.DatePicker;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ListPopupWindow;
import android.widget.ListView;
import android.widget.PopupMenu;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.TimePicker;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;

/**
 * The window for apps that use Android's own controls (eifphone.toml: controls = true).
 * Apps never edit it.
 *
 * Android has no C API for its controls: they are Java objects. So the C side
 * (runtime/c/sephone_controls.c) makes and drives them through JNI, and this
 * class holds only what must be Java: listeners, which have to be Java objects,
 * the list's row source, and the general route to any other control.
 *
 * NativeActivity takes the window's surface and input for itself. onCreate gives
 * both back, so ordinary controls draw and receive touches, while the Eiffel
 * thread and the lifecycle events stay exactly as they are.
 *
 * Event codes must match PHONE_EVENT_KIND and sephone.h.
 */
public class EifPhoneControlsActivity extends EifPhoneActivity {
	private static final int CLICKED = 50;
	private static final int CHANGED = 51;
	private static final int SELECTED = 53;
	private static final int PRESSED = 54;
	private static final int SWEPT = 55;
	private static final int RELEASED = 56;
	private static final int CANVAS_READY = 57;
	private static final int CANVAS_LOST = 58;
	private static final int ANSWERED = 59;
	private static final int CALLED = 60;
	private static final int FAILED = 61;
	private static final int BACK = 62;

	private static final int ARG_NONE = 0;
	private static final int ARG_INT = 1;
	private static final int ARG_BOOLEAN = 2;
	private static final int ARG_TEXT = 3;

	private FrameLayout root;
	private int backId = 0;
	private OnBackInvokedCallback backCallback;
	private final Handler ui = new Handler(Looper.getMainLooper());
	private final Runnable turn = EifPhoneControlsActivity::sephoneUiTurn;

	private static native void sephoneControlEvent(int kind, int id, int x, int y, byte[] text);
	private static native void sephoneUiTurn();
	private static native byte[] sephoneRowText(int list, int position);

	private static void send(int kind, int id, int x, int y, String text) {
		sephoneControlEvent(kind, id, x, y, text == null ? null : text.getBytes(StandardCharsets.UTF_8));
	}

	@Override
	protected void onCreate(Bundle state) {
		setTheme(Build.VERSION.SDK_INT >= 29
			? android.R.style.Theme_DeviceDefault_DayNight
			: android.R.style.Theme_DeviceDefault);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		super.onCreate(state);
		getWindow().takeSurface(null);
		getWindow().takeInputQueue(null);
		getWindow().setFormat(PixelFormat.RGBA_8888);
		root = new FrameLayout(this);
		root.setOnApplyWindowInsetsListener(this::fitInsets);
		setContentView(root);
	}

	/** Keeps controls clear of the system bars and the keyboard. */
	private WindowInsets fitInsets(View view, WindowInsets insets) {
		if (Build.VERSION.SDK_INT >= 30) {
			Insets area = insets.getInsets(WindowInsets.Type.systemBars()
				| WindowInsets.Type.ime() | WindowInsets.Type.displayCutout());
			view.setPadding(area.left, area.top, area.right, area.bottom);
			return WindowInsets.CONSUMED;
		}
		view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
			insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
		return insets.consumeSystemWindowInsets();
	}

	/** Called from the Eiffel thread: run the waiting orders on the UI thread. */
	public void sephoneUiPost() {
		ui.post(turn);
	}

	/** Back goes to Eiffel under `id'; 0 gives it back to Android. */
	public void sephoneBack(int id) {
		backId = id;
		if (Build.VERSION.SDK_INT >= 33) {
			OnBackInvokedDispatcher dispatcher = getOnBackInvokedDispatcher();
			if (backCallback != null) {
				dispatcher.unregisterOnBackInvokedCallback(backCallback);
				backCallback = null;
			}
			if (id > 0) {
				backCallback = () -> send(BACK, id, 0, 0, null);
				dispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, backCallback);
			}
		}
	}

	@Override
	public void onRequestPermissionsResult(int code, String[] permissions, int[] results) {
		super.onRequestPermissionsResult(code, permissions, results);
		EifPhoneRecorder.permissionResult(code, permissions, results);
	}

	@Override
	public void onBackPressed() {
		if (backId > 0) {
			send(BACK, backId, 0, 0, null);
		} else {
			super.onBackPressed();
		}
	}

	/** Draws to the screen's edges: `top' behind the status bar, `bottom' behind the navigation bar. */
	public void sephoneWindow(int top, int bottom, String darkIcons) {
		Window w = getWindow();
		boolean dark = "1".equals(darkIcons);
		w.setStatusBarColor(0);
		w.setNavigationBarColor(0);
		if (Build.VERSION.SDK_INT >= 29) {
			w.setStatusBarContrastEnforced(false);
			w.setNavigationBarContrastEnforced(false);
		}
		if (Build.VERSION.SDK_INT >= 30) {
			w.setDecorFitsSystemWindows(false);
			int light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
			w.getInsetsController().setSystemBarsAppearance(dark ? light : 0, light);
		} else {
			int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
			if (dark) flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
			root.setSystemUiVisibility(flags);
		}
		root.setBackground(new Edges(top, bottom));
		root.requestApplyInsets();
	}

	/** Hides the phone's own bars; a swipe from the edge shows them for a moment. */
	public void sephoneBars(boolean hidden) {
		Window w = getWindow();
		if (Build.VERSION.SDK_INT >= 30) {
			WindowInsetsController bars = w.getInsetsController();
			bars.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
			if (hidden) bars.hide(WindowInsets.Type.systemBars());
			else bars.show(WindowInsets.Type.systemBars());
		} else {
			int keep = root.getSystemUiVisibility() & ~(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
			root.setSystemUiVisibility(hidden
				? keep | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
				: keep);
		}
	}

	/** A colored, rounded background, with a border if `border' reads "color width". */
	public void sephoneSurface(View view, int color, int radius, String border) {
		float density = getResources().getDisplayMetrics().density;
		GradientDrawable shape = new GradientDrawable();
		shape.setColor(color);
		shape.setCornerRadius(radius * density);
		if (!border.isEmpty()) {
			String[] parts = border.split(" ");
			shape.setStroke(Math.round(Integer.parseInt(parts[1]) * density), (int) Long.parseLong(parts[0], 16));
		}
		view.setBackground(shape);
	}

	/** Android's touch ripple over a view, kept apart from its background. */
	public void sephoneRipple(View view, boolean borderless) {
		TypedValue value = new TypedValue();
		getTheme().resolveAttribute(borderless ? android.R.attr.selectableItemBackgroundBorderless : android.R.attr.selectableItemBackground, value, true);
		view.setForeground(getDrawable(value.resourceId));
	}

	/** A drop-down of styled rows, in the form PHONE_RICH_ROW writes. Answers from 1; 0 if dismissed. */
	/** A menu row: at least Material's 48 tall, what it holds centered in that, growing with big text. */
	private View menuRow(Rows maker, String item, View old, ViewGroup parent, int position) {
		LinearLayout row = (LinearLayout) maker.richRow(item, old, parent, position);
		row.setMinimumHeight(Math.round(48 * getResources().getDisplayMetrics().density));
		row.setGravity(Gravity.CENTER_VERTICAL);
		return row;
	}

	public void sephoneDropdown(View anchor, int id, int background, String rows) {
		final String[] items = rows.split("\u001C");
		final Rows maker = new Rows(0);
		maker.gapSet = true;
		final ListPopupWindow popup = new ListPopupWindow(this);
		float density = getResources().getDisplayMetrics().density;
		GradientDrawable shape = new GradientDrawable();
		shape.setColor(background);
		shape.setCornerRadius(4 * density);
		popup.setBackgroundDrawable(shape);
		popup.setAnchorView(anchor);
		popup.setModal(true);
		// As wide as its widest row, within Material's limits; above the anchor if it fits only there.
		int wide = 0;
		int tall = Math.round(16 * density);
		FrameLayout room = new FrameLayout(this);
		int free = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
		int most = Math.round(280 * density);
		for (int i = 0; i < items.length; i++) {
			View row = menuRow(maker, items[i], null, room, i);
			row.measure(View.MeasureSpec.makeMeasureSpec(most, View.MeasureSpec.AT_MOST), free);
			wide = Math.max(wide, row.getMeasuredWidth());
			tall += row.getMeasuredHeight();
		}
		wide = Math.max(Math.round(112 * density), Math.min(most, wide));
		int[] at = new int[2];
		anchor.getLocationOnScreen(at);
		int screen = root.getHeight() - root.getPaddingBottom();
		int margin = Math.round(48 * density);
		int below = screen - margin - at[1] - anchor.getHeight();
		int above = at[1] - margin;
		popup.setWidth(wide);
		// Compose's order: from the anchor's left, to the anchor's right, else against the screen's edge.
		int left = at[0];
		if (left + wide > root.getWidth()) {
			left = at[0] + anchor.getWidth() - wide;
			if (left < 0) left = root.getWidth() - wide;
		}
		popup.setHorizontalOffset(left - at[0]);
		// Below, else above, else as much as the screen holds, up from the bottom margin.
		if (tall <= below) {
			popup.setHeight(tall);
		} else if (tall <= above) {
			popup.setHeight(tall);
			popup.setVerticalOffset(-(tall + anchor.getHeight()));
		} else {
			int shown = Math.min(tall, screen - 2 * margin);
			popup.setHeight(shown);
			popup.setVerticalOffset(screen - margin - shown - at[1] - anchor.getHeight());
		}
		popup.setAdapter(new BaseAdapter() {
			@Override public int getCount() { return items.length; }
			@Override public Object getItem(int position) { return items[position]; }
			@Override public long getItemId(int position) { return position; }
			@Override public View getView(int position, View old, ViewGroup parent) {
				return menuRow(maker, items[position], old, parent, position);
			}
		});
		final boolean[] chosen = { false };
		popup.setOnItemClickListener((a, v, position, row) -> {
			chosen[0] = true;
			send(ANSWERED, id, position + 1, 0, null);
			popup.dismiss();
		});
		popup.setOnDismissListener(() -> {
			if (!chosen[0]) send(ANSWERED, id, 0, 0, null);
		});
		popup.show();
		ListView list = popup.getListView();
		if (list != null) {
			list.setVerticalScrollBarEnabled(false);
			list.setDivider(null);
			int pad = Math.round(8 * density);
			list.setPadding(0, pad, 0, pad);
			list.setClipToPadding(false);
		}
	}

	/** Styled text in a label, in the form PHONE_RICH_ROW writes. */
	public void sephoneRich(View view, String wire) {
		String[] parts = wire.split(Rows.BLOCK, -1);
		if (parts.length > 1 && view instanceof TextView) {
			// A label keeps the padding and the placing it was given.
			TextView label = (TextView) view;
			int left = label.getPaddingLeft(), top = label.getPaddingTop();
			int right = label.getPaddingRight(), bottom = label.getPaddingBottom();
			int gravity = label.getGravity();
			Rows.fill(label, parts[1], getResources().getDisplayMetrics().density);
			label.setPadding(left, top, right, bottom);
			label.setGravity(gravity);
		}
	}

	/** The window's backdrop: one color, with another across the inset at the bottom. */
	private final class Edges extends Drawable {
		private final int top;
		private final android.graphics.Paint paint = new android.graphics.Paint();

		Edges(int top, int bottom) {
			this.top = top;
			paint.setColor(bottom);
		}

		@Override public void draw(Canvas canvas) {
			canvas.drawColor(top);
			int inset = root.getPaddingBottom();
			if (inset > 0) {
				canvas.drawRect(0, root.getHeight() - inset, root.getWidth(), root.getHeight(), paint);
			}
		}

		@Override public void setAlpha(int alpha) { }
		@Override public void setColorFilter(ColorFilter filter) { }
		@Override public int getOpacity() { return PixelFormat.OPAQUE; }
	}

	public void sephoneShow(View view) {
		root.removeAllViews();
		root.addView(view, new FrameLayout.LayoutParams(
			ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
	}

	// ---- dialogs

	public void sephoneDialog(int id, String title, String message, String yes, String no) {
		AlertDialog.Builder builder = new AlertDialog.Builder(this).setTitle(title).setMessage(message);
		builder.setPositiveButton(yes, (d, which) -> send(ANSWERED, id, 1, 0, null));
		if (!no.isEmpty()) {
			builder.setNegativeButton(no, (d, which) -> send(ANSWERED, id, 0, 0, null));
		}
		builder.setOnCancelListener(d -> send(ANSWERED, id, 0, 0, null));
		builder.show();
	}

	/** Answers with the item's number from 1; 0 if the user backs out. */
	public void sephoneMenu(View anchor, int id, String items) {
		PopupMenu menu = new PopupMenu(this, anchor);
		String[] words = items.split("\u001F");
		for (int i = 0; i < words.length; i++) {
			menu.getMenu().add(0, i + 1, i, words[i]);
		}
		menu.setOnMenuItemClickListener(item -> {
			send(ANSWERED, id, item.getItemId(), 0, null);
			return true;
		});
		menu.setOnDismissListener(m -> send(ANSWERED, id, 0, 0, null));
		menu.show();
	}

	public void sephoneDate(int id, int year, int month, int day) {
		DatePickerDialog dialog = new DatePickerDialog(this,
			(DatePicker p, int y, int m, int d) -> send(ANSWERED, id, 1, 0, y + "-" + (m + 1) + "-" + d),
			year, month - 1, day);
		dialog.setOnCancelListener(d -> send(ANSWERED, id, 0, 0, null));
		dialog.show();
	}

	public void sephoneTime(int id, int hour, int minute) {
		TimePickerDialog dialog = new TimePickerDialog(this,
			(TimePicker p, int h, int m) -> send(ANSWERED, id, 1, 0, h + ":" + m),
			hour, minute, false);
		dialog.setOnCancelListener(d -> send(ANSWERED, id, 0, 0, null));
		dialog.show();
	}

	// ---- the general route: any public method of any control

	private static Method find(Object target, String name, int kind) throws NoSuchMethodException {
		for (Method m : target.getClass().getMethods()) {
			Class<?>[] p = m.getParameterTypes();
			if (m.getName().equals(name)) {
				if (kind == ARG_NONE && p.length == 0) return m;
				if (kind == ARG_INT && p.length == 1 && p[0] == int.class) return m;
				if (kind == ARG_BOOLEAN && p.length == 1 && p[0] == boolean.class) return m;
				if (kind == ARG_TEXT && p.length == 1 && (p[0] == CharSequence.class || p[0] == String.class)) return m;
			}
		}
		throw new NoSuchMethodException(name);
	}

	public void sephoneCall(View view, int id, String name, int kind, int number, String text) {
		try {
			Method m = find(view, name, kind);
			if (kind == ARG_NONE) m.invoke(view);
			else if (kind == ARG_INT) m.invoke(view, number);
			else if (kind == ARG_BOOLEAN) m.invoke(view, number != 0);
			else m.invoke(view, text);
		} catch (Exception e) {
			send(FAILED, id, 0, 0, name + ": " + e);
		}
	}

	public void sephoneAsk(View view, int id, int token, String name) {
		try {
			Object answer = find(view, name, ARG_NONE).invoke(view);
			send(ANSWERED, id, token, 0, String.valueOf(answer));
		} catch (Exception e) {
			send(FAILED, id, 0, 0, name + ": " + e);
		}
	}

	/** Listens through any setOn...Listener, whatever its interface. */
	public void sephoneListen(View view, int id, String setter) {
		try {
			for (Method m : view.getClass().getMethods()) {
				Class<?>[] p = m.getParameterTypes();
				if (m.getName().equals(setter) && p.length == 1 && p[0].isInterface()) {
					InvocationHandler handler = (proxy, method, args) -> {
						if (method.getDeclaringClass() == Object.class) {
							return method.getName().equals("hashCode") ? Integer.valueOf(id)
								: method.getName().equals("equals") ? Boolean.valueOf(proxy == args[0])
								: "listener " + id;
						}
						StringBuilder words = new StringBuilder(method.getName());
						if (args != null) {
							for (Object a : args) {
								if (!(a instanceof View)) words.append('|').append(a);
							}
						}
						send(CALLED, id, 0, 0, words.toString());
						Class<?> r = method.getReturnType();
						if (r == boolean.class) return Boolean.FALSE;
						if (r == int.class) return Integer.valueOf(0);
						return null;
					};
					m.invoke(view, Proxy.newProxyInstance(getClassLoader(), new Class<?>[] { p[0] }, handler));
					return;
				}
			}
			send(FAILED, id, 0, 0, setter + ": no such listener");
		} catch (Exception e) {
			send(FAILED, id, 0, 0, setter + ": " + e);
		}
	}

	// ---- what must be Java objects

	/** One per control. `quiet' is set while Eiffel itself changes the control. */
	public static final class Listener implements View.OnClickListener, TextWatcher,
			CompoundButton.OnCheckedChangeListener, RadioGroup.OnCheckedChangeListener,
			SeekBar.OnSeekBarChangeListener, AdapterView.OnItemClickListener,
			AdapterView.OnItemSelectedListener, View.OnTouchListener, SurfaceHolder.Callback {
		private final int id;
		public boolean quiet;

		public Listener(int id) {
			this.id = id;
		}

		@Override public void onClick(View v) { send(CLICKED, id, 0, 0, null); }

		@Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
		@Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
		@Override public void afterTextChanged(Editable s) {
			if (!quiet) send(CHANGED, id, 0, 0, s.toString());
		}

		@Override public void onCheckedChanged(CompoundButton b, boolean on) {
			if (!quiet) send(CHANGED, id, on ? 1 : 0, 0, null);
		}

		@Override public void onCheckedChanged(RadioGroup g, int checked) {
			if (!quiet) send(CHANGED, id, checked, 0, null);
		}

		@Override public void onProgressChanged(SeekBar s, int value, boolean fromUser) {
			if (fromUser && !quiet) send(CHANGED, id, value, 0, null);
		}
		@Override public void onStartTrackingTouch(SeekBar s) { }
		@Override public void onStopTrackingTouch(SeekBar s) { }

		@Override public void onItemClick(AdapterView<?> a, View v, int position, long row) {
			send(SELECTED, id, position + 1, 0, null);
		}

		@Override public void onItemSelected(AdapterView<?> a, View v, int position, long row) {
			if (!quiet) send(CHANGED, id, position + 1, 0, null);
		}
		@Override public void onNothingSelected(AdapterView<?> a) { }

		@Override public boolean onTouch(View v, MotionEvent e) {
			int action = e.getActionMasked();
			if (action == MotionEvent.ACTION_DOWN) {
				send(PRESSED, id, Math.round(e.getX()), Math.round(e.getY()), null);
			} else if (action == MotionEvent.ACTION_MOVE) {
				for (int i = 0; i < e.getHistorySize(); i++) {
					send(SWEPT, id, Math.round(e.getHistoricalX(i)), Math.round(e.getHistoricalY(i)), null);
				}
				send(SWEPT, id, Math.round(e.getX()), Math.round(e.getY()), null);
			} else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
				send(RELEASED, id, Math.round(e.getX()), Math.round(e.getY()), null);
			}
			return true;
		}

		@Override public void surfaceCreated(SurfaceHolder h) { }
		@Override public void surfaceChanged(SurfaceHolder h, int format, int width, int height) {
			send(CANVAS_READY, id, width, height, null);
		}
		@Override public void surfaceDestroyed(SurfaceHolder h) { send(CANVAS_LOST, id, 0, 0, null); }
	}

	/** A list's rows. The text waits in the C side's table, filled by Eiffel on request. */
	public static final class Rows extends BaseAdapter {
		private static final char RICH = '\u0001';
		static final String BLOCK = "\u001E";
		private static final String RUN = "\u001D";
		private static final String FIELD = "\u001F";
		private static final HashMap<String, Typeface> FACES = new HashMap<>();

		private final int id;
		private int count;
		private boolean gapSet;

		public Rows(int id) {
			this.id = id;
		}

		public void setCount(int count) {
			this.count = count;
			notifyDataSetChanged();
		}

		@Override public int getCount() { return count; }
		@Override public Object getItem(int position) { return Integer.valueOf(position); }
		@Override public long getItemId(int position) { return position; }

		@Override public View getView(int position, View old, ViewGroup parent) {
			byte[] bytes = sephoneRowText(id, position);
			String text = bytes == null ? "" : new String(bytes, StandardCharsets.UTF_8);
			if (!text.isEmpty() && text.charAt(0) == RICH) {
				return richRow(text, old, parent, position);
			}
			TextView view = old instanceof TextView ? (TextView) old : null;
			if (view == null) {
				view = new TextView(parent.getContext());
				int pad = Math.round(14 * parent.getResources().getDisplayMetrics().density);
				view.setPadding(pad, pad, pad, pad);
				view.setTextSize(16);
			}
			view.setText(text);
			return view;
		}

		/** A row of styled text blocks. PHONE_RICH_ROW writes the form read here. */
		View richRow(String text, View old, ViewGroup parent, int position) {
			float density = parent.getResources().getDisplayMetrics().density;
			if (parent instanceof ListView && !gapSet) {
				ListView list = (ListView) parent;
				list.setDivider(new ColorDrawable(0));
				list.setDividerHeight(Math.round(2 * density));
				gapSet = true;
			}
			LinearLayout row = old instanceof LinearLayout ? (LinearLayout) old : null;
			if (row == null) {
				row = new LinearLayout(parent.getContext());
				row.setOrientation(LinearLayout.VERTICAL);
			}
			String[] parts = text.split(BLOCK, -1);
			String[] head = parts[0].substring(1).split(FIELD, -1);
			// A row that changes color in place fades to it, as Compose's animateColorAsState does.
			int wash = (int) Long.parseLong(head[0], 16);
			Object seen = row.getTag();
			if (seen instanceof int[] && ((int[]) seen)[0] == position && ((int[]) seen)[1] != wash) {
				android.animation.ValueAnimator fade = android.animation.ValueAnimator.ofArgb(((int[]) seen)[1], wash);
				fade.setDuration(400);
				final LinearLayout fading = row;
				fade.addUpdateListener(a -> fading.setBackgroundColor((int) a.getAnimatedValue()));
				fade.start();
			} else {
				row.setBackgroundColor(wash);
			}
			row.setTag(new int[] { position, wash });
			int sides = Math.round(Integer.parseInt(head[1]) * density);
			row.setPadding(sides, Math.round(Integer.parseInt(head[2]) * density), sides, Math.round(Integer.parseInt(head[3]) * density));
			int blocks = parts.length - 1;
			while (row.getChildCount() > blocks) {
				row.removeViewAt(row.getChildCount() - 1);
			}
			for (int i = 0; i < blocks; i++) {
				if (i == row.getChildCount()) {
					row.addView(new TextView(parent.getContext()), new LinearLayout.LayoutParams(
						ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
				}
				fill((TextView) row.getChildAt(i), parts[i + 1], density);
			}
			return row;
		}

		static void fill(TextView view, String block, float density) {
			String[] runs = block.split(RUN, -1);
			String[] head = runs[0].split(FIELD, -1);
			float size = Float.parseFloat(head[1]);
			view.setTypeface(typeface(view, head[0]));
			view.setTextSize(TypedValue.COMPLEX_UNIT_SP, size);
			view.setTextColor((int) Long.parseLong(head[3], 16));
			view.setIncludeFontPadding(false);
			// Large font scales are not linear: 18sp and 27sp do not grow alike. Lines keep their
			// ratio to the text, as Compose and TextView do, or big text sits too close together.
			float line = view.getTextSize() * Float.parseFloat(head[2]) / size;
			boolean rtl = head[4].equals("1");
			view.setTextDirection(rtl ? View.TEXT_DIRECTION_RTL : View.TEXT_DIRECTION_FIRST_STRONG);
			view.setTextAlignment(View.TEXT_ALIGNMENT_GRAVITY);
			view.setBreakStrategy(android.text.Layout.BREAK_STRATEGY_SIMPLE);
			view.setHyphenationFrequency(android.text.Layout.HYPHENATION_FREQUENCY_NONE);
			boolean material = head.length > 6;
			view.setLetterSpacing(material ? Float.parseFloat(head[6]) : 0f);
			boolean centered = head.length > 7;
			view.setGravity(centered ? Gravity.CENTER_HORIZONTAL : rtl ? Gravity.RIGHT : Gravity.LEFT);
			view.setPadding(0, Math.round(Integer.parseInt(head[5]) * density), 0, 0);
			SpannableStringBuilder words = new SpannableStringBuilder();
			for (int i = 1; i < runs.length; i++) {
				String[] run = runs[i].split(FIELD, 4);
				int flags = Integer.parseInt(run[0]);
				long color = Long.parseLong(run[1], 16);
				float scale = Float.parseFloat(run[2]);
				int from = words.length();
				words.append(run[3]);
				int to = words.length();
				// The rise is measured at the block's size, so it goes on before the run's own size.
				if ((flags & 4) != 0) words.setSpan(new SuperscriptSpan(), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
				if (color != 0) words.setSpan(new ForegroundColorSpan((int) color), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
				if (scale > 0f) words.setSpan(new RelativeSizeSpan(scale), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
				if ((flags & 3) != 0) words.setSpan(new StyleSpan(flags & 3), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
				if ((flags & 8) != 0) {
					if (Build.VERSION.SDK_INT >= 28) {
						words.setSpan(new TypefaceSpan(Typeface.create(view.getTypeface(), 600, (flags & 2) != 0)), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
					} else {
						words.setSpan(new StyleSpan(Typeface.BOLD), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
					}
				}
				if ((flags & 32) != 0) words.setSpan(new UnderlineSpan(), from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
				if ((flags & 16) != 0 && view instanceof EifPhoneTappable) {
					final int run_index = i - 1;
					final EifPhoneTappable tappable = (EifPhoneTappable) view;
					words.setSpan(new ClickableSpan() {
						@Override public void onClick(View v) { tappable.tapped(run_index); }
						@Override public void updateDrawState(TextPaint paint) { }
					}, from, to, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
				}
			}
			words.setSpan(new ExactLine((int) Math.ceil(line), words.length(), material), 0, words.length(), Spanned.SPAN_INCLUSIVE_INCLUSIVE);
			view.setText(words);
		}

		/**
		 * Every line exactly `height' tall, whatever it holds, with the extra shared in the
		 * font's own proportions, measured once on the first line. The block's first line keeps
		 * the font's own top and its last line the font's own bottom. This is Compose's rule.
		 * Material's text styles have another: `whole' lines, all full height, the text centered.
		 */
		private static final class ExactLine implements LineHeightSpan {
			private final int height;
			private final int length;
			private final boolean whole;
			private boolean measured;
			private int ascent, descent, firstAscent, lastDescent;

			ExactLine(int height, int length, boolean whole) {
				this.height = height;
				this.length = length;
				this.whole = whole;
			}

			@Override public void chooseHeight(CharSequence text, int start, int end, int top, int line, Paint.FontMetricsInt fm) {
				int current = fm.descent - fm.ascent;
				boolean first = start == 0;
				boolean last = end == length;
				if (whole && current > 0) {
					if (!measured) {
						descent = fm.descent + (int) Math.ceil((height - current) / 2f);
						ascent = descent - height;
						measured = true;
					}
					fm.ascent = ascent;
					fm.descent = descent;
				} else if (current > 0 && !(first && last)) {
					if (!measured) {
						float above = Math.abs(fm.ascent) / (float) current;
						int extra = height - current;
						descent = fm.descent + (int) Math.ceil(extra <= 0 ? extra * above : extra * (1f - above));
						ascent = descent - height;
						firstAscent = fm.ascent;
						lastDescent = fm.descent;
						measured = true;
					}
					fm.ascent = first ? firstAscent : ascent;
					fm.descent = last ? lastDescent : descent;
				}
			}
		}

		/** "" is the phone's own, "serif" its serif, anything else a font file among the app's assets. */
		private static Typeface typeface(View view, String name) {
			if (name.isEmpty()) return Typeface.DEFAULT;
			if (name.equals("serif")) return Typeface.SERIF;
			if (name.equals("monospace")) return Typeface.MONOSPACE;
			if (name.startsWith("sans-serif")) return Typeface.create(name, Typeface.NORMAL);
			Typeface found = FACES.get(name);
			if (found == null) {
				found = Typeface.createFromAsset(view.getContext().getAssets(), name);
				FACES.put(name, found);
			}
			return found;
		}
	}

	@Override
	protected void onDestroy() {
		ui.removeCallbacks(turn);
		super.onDestroy();
	}
}
