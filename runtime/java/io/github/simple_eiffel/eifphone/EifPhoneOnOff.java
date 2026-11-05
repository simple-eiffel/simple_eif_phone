package io.github.simple_eiffel.eifphone;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.View;

/**
 * Material 3's switch: a 52 by 32 track whose thumb grows when on. It does not take taps
 * itself: the row around it does. Apps use PHONE_ON_OFF and never edit this.
 */
public class EifPhoneOnOff extends View {
	private final float density;
	private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final RectF box = new RectF();
	private boolean on;
	private float at;
	private int accent = 0xFFE2C27A;
	private int onAccent = 0xFF2A2005;
	private int outline = 0xFF5B606C;
	private int track = 0xFF36343B;

	public EifPhoneOnOff(Context context) {
		super(context);
		density = context.getResources().getDisplayMetrics().density;
	}

	public void setAccent(int c) { accent = c; invalidate(); }
	public void setOnAccent(int c) { onAccent = c; invalidate(); }
	public void setOutline(int c) { outline = c; invalidate(); }
	public void setTrack(int c) { track = c; invalidate(); }

	/** Set without moving. */
	public void setOnNow(boolean value) {
		on = value;
		at = value ? 1f : 0f;
		invalidate();
	}

	/** Move to the new state. */
	public void setOnMoving(boolean value) {
		on = value;
		ValueAnimator move = ValueAnimator.ofFloat(at, value ? 1f : 0f);
		move.setDuration(120);
		move.addUpdateListener(a -> {
			at = (float) a.getAnimatedValue();
			invalidate();
		});
		move.start();
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		setMeasuredDimension(Math.round(52 * density), Math.round(32 * density));
	}

	@Override protected void onDraw(Canvas canvas) {
		float w = getWidth();
		float h = getHeight();
		float r = h / 2;
		box.set(0, 0, w, h);
		paint.setStyle(Paint.Style.FILL);
		paint.setColor(on ? accent : track);
		canvas.drawRoundRect(box, r, r, paint);
		if (!on) {
			paint.setStyle(Paint.Style.STROKE);
			paint.setStrokeWidth(2 * density);
			paint.setColor(outline);
			box.inset(density, density);
			canvas.drawRoundRect(box, r, r, paint);
			paint.setStyle(Paint.Style.FILL);
		}
		float thumb = (8 + 4 * at) * density;
		float x = r + (w - 2 * r) * at;
		paint.setColor(on ? onAccent : outline);
		canvas.drawCircle(x, r, thumb, paint);
	}
}
