package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.View;

/**
 * Material 3's slider: a thick track, a thin upright handle with a gap either side,
 * a dot at each step and a stop at the end. Apps use PHONE_RANGE and never edit this.
 */
public class EifPhoneRange extends View {
	/** Told the value as the user moves the handle. */
	public interface OnRangeListener {
		void onValue(int value);
	}

	private final float density;
	private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final RectF box = new RectF();
	private int maximum = 100;
	private int value;
	private boolean showSteps;
	private int active = 0xFFE2C27A;
	private int inactive = 0xFF3A3424;
	private int onActive = 0xFF2A2005;
	private OnRangeListener listener;

	public EifPhoneRange(Context context) {
		super(context);
		density = context.getResources().getDisplayMetrics().density;
	}

	public void setOnRangeListener(OnRangeListener l) { listener = l; }
	public void setActiveColor(int c) { active = c; invalidate(); }
	public void setInactiveColor(int c) { inactive = c; invalidate(); }
	public void setOnActiveColor(int c) { onActive = c; invalidate(); }
	public void setShowSteps(boolean on) { showSteps = on; invalidate(); }

	public void setMaximum(int m) {
		maximum = Math.max(1, m);
		invalidate();
	}

	public void setValue(int v) {
		value = Math.max(0, Math.min(maximum, v));
		invalidate();
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		setMeasuredDimension(MeasureSpec.getSize(widthSpec), resolveSize(Math.round(48 * density), heightSpec));
	}

	private float inset() {
		return 2 * density;
	}

	private float xOf(int v) {
		float room = getWidth() - 2 * inset();
		return inset() + room * v / maximum;
	}

	@Override protected void onDraw(Canvas canvas) {
		float middle = getHeight() / 2f;
		float half = 8 * density;
		float gap = 6 * density;
		float radius = half;
		float x = xOf(value);
		paint.setColor(active);
		if (x - gap > 0) {
			box.set(0, middle - half, x - gap, middle + half);
			canvas.drawRoundRect(box, radius, radius, paint);
		}
		paint.setColor(inactive);
		if (x + gap < getWidth()) {
			box.set(x + gap, middle - half, getWidth(), middle + half);
			canvas.drawRoundRect(box, radius, radius, paint);
		}
		float dot = 2 * density;
		if (showSteps) {
			for (int i = 0; i <= maximum; i++) {
				float at = Math.max(half, Math.min(getWidth() - half, xOf(i)));
				if (Math.abs(at - x) > gap + dot) {
					paint.setColor(at < x ? onActive : active);
					canvas.drawCircle(at, middle, dot, paint);
				}
			}
		} else if (value < maximum) {
			paint.setColor(active);
			canvas.drawCircle(getWidth() - half, middle, dot, paint);
		}
		paint.setColor(active);
		box.set(x - inset(), middle - 22 * density, x + inset(), middle + 22 * density);
		canvas.drawRoundRect(box, inset(), inset(), paint);
	}

	@Override public boolean onTouchEvent(MotionEvent e) {
		int action = e.getActionMasked();
		if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_MOVE || action == MotionEvent.ACTION_UP) {
			if (action == MotionEvent.ACTION_DOWN && getParent() != null) getParent().requestDisallowInterceptTouchEvent(true);
			float room = getWidth() - 2 * inset();
			int v = Math.round((e.getX() - inset()) / room * maximum);
			v = Math.max(0, Math.min(maximum, v));
			if (v != value) {
				value = v;
				invalidate();
				if (listener != null) listener.onValue(v);
			}
		}
		return true;
	}
}
