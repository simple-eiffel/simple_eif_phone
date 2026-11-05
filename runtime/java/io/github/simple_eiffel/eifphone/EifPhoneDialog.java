package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.graphics.Canvas;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;

/**
 * A dialog of the app's own over a dimmed screen: one child, centered, as wide as Material
 * allows. A tap outside it dismisses it. Apps use PHONE_DIALOG and never edit this.
 */
public class EifPhoneDialog extends ViewGroup {
	/** Told when the user taps outside. */
	public interface OnDialogListener {
		void onOutside();
	}

	private final float density;
	private OnDialogListener listener;

	public EifPhoneDialog(Context context) {
		super(context);
		density = context.getResources().getDisplayMetrics().density;
		setWillNotDraw(false);
		setClickable(true);
	}

	public void setOnDialogListener(OnDialogListener l) {
		listener = l;
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		int width = MeasureSpec.getSize(widthSpec);
		int height = MeasureSpec.getSize(heightSpec);
		setMeasuredDimension(width, height);
		// Material's limits, within what the phone allows a dialog window.
		int room = Math.min(Math.round(560 * density), width * 78 / 100);
		int tall = height - Math.round(96 * density);
		for (int i = 0; i < getChildCount(); i++) {
			getChildAt(i).measure(MeasureSpec.makeMeasureSpec(room, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(tall, MeasureSpec.AT_MOST));
		}
	}

	@Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
		for (int i = 0; i < getChildCount(); i++) {
			View child = getChildAt(i);
			int x = (r - l - child.getMeasuredWidth()) / 2;
			int y = (b - t - child.getMeasuredHeight()) / 2;
			child.layout(x, y, x + child.getMeasuredWidth(), y + child.getMeasuredHeight());
		}
	}

	@Override protected void onDraw(Canvas canvas) {
		canvas.drawColor(0x99000000);
	}

	@Override public boolean onTouchEvent(MotionEvent e) {
		if (e.getActionMasked() == MotionEvent.ACTION_UP && listener != null) {
			listener.onOutside();
		}
		return true;
	}
}
