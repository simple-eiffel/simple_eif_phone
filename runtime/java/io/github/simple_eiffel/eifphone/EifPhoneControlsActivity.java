package io.github.simple_eiffel.eifphone;

import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.app.TimePickerDialog;
import android.graphics.Insets;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.CompoundButton;
import android.widget.DatePicker;
import android.widget.FrameLayout;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.TimePicker;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;

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
	public void onBackPressed() {
		if (backId > 0) {
			send(BACK, backId, 0, 0, null);
		} else {
			super.onBackPressed();
		}
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
		private final int id;
		private int count;

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
			TextView view = (TextView) old;
			if (view == null) {
				view = new TextView(parent.getContext());
				int pad = Math.round(14 * parent.getResources().getDisplayMetrics().density);
				view.setPadding(pad, pad, pad, pad);
				view.setTextSize(16);
			}
			byte[] text = sephoneRowText(id, position);
			view.setText(text == null ? "" : new String(text, StandardCharsets.UTF_8));
			return view;
		}
	}

	@Override
	protected void onDestroy() {
		ui.removeCallbacks(turn);
		super.onDestroy();
	}
}
