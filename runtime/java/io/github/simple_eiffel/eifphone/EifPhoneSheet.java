package io.github.simple_eiffel.eifphone;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.VelocityTracker;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;

/**
 * A modal sheet from the bottom of the screen, over a dimmed scrim: Material's bottom sheet.
 * It opens at half height, and goes to full height or away by dragging. A drag inside the
 * content moves the sheet first when that is the way the sheet can go, and the content
 * otherwise. Add one child, the content. Apps use PHONE_SHEET and never edit this.
 */
public class EifPhoneSheet extends ViewGroup {
	/** Called on the UI thread when the sheet has gone: by a drag, the scrim, or `dismiss'. */
	public interface OnSheetListener {
		void onSheetGone();
	}

	private static final int MOVE_MS = 240;
	private static final int HANDLE_DP = 48;

	private final float density;
	private final int slop;
	private final int flingSpeed;
	private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final Paint scrim = new Paint();
	private final Paint handle = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final RectF box = new RectF();
	private int fullFraction = 91;
	private int radius;
	private int offset = -1;
	private float downX;
	private float downY;
	private float lastY;
	private boolean dragging;
	private boolean closing;
	private VelocityTracker tracker;
	private ValueAnimator moving;
	private OnSheetListener listener;

	public EifPhoneSheet(Context context) {
		super(context);
		density = context.getResources().getDisplayMetrics().density;
		ViewConfiguration c = ViewConfiguration.get(context);
		slop = c.getScaledTouchSlop();
		flingSpeed = c.getScaledMinimumFlingVelocity() * 8;
		radius = Math.round(28 * density);
		setWillNotDraw(false);
		setClickable(true);
		scrim.setColor(0x52000000);
		paint.setColor(0xFF1D2028);
		handle.setColor(0x66FFFFFF);
	}

	public void setOnSheetListener(OnSheetListener l) {
		listener = l;
	}

	public void setSheetColor(int color) {
		paint.setColor(color);
		invalidate();
	}

	public void setHandleColor(int color) {
		handle.setColor(color);
		invalidate();
	}

	/** Slide away, then tell the listener. */
	public void dismiss() {
		moveTo(getHeight(), true);
	}

	private int fullTop() {
		return getHeight() - getHeight() * fullFraction / 100;
	}

	private int halfTop() {
		return getHeight() / 2;
	}

	private void place(int top) {
		offset = top;
		if (getChildCount() > 0) {
			getChildAt(0).setTranslationY(top + HANDLE_DP * density);
		}
		invalidate();
	}

	private void moveTo(int top, final boolean thenGone) {
		if (moving != null) moving.cancel();
		closing = thenGone;
		moving = ValueAnimator.ofInt(offset, top);
		moving.setDuration(MOVE_MS);
		moving.setInterpolator(new DecelerateInterpolator(1.5f));
		moving.addUpdateListener(a -> place((int) a.getAnimatedValue()));
		moving.addListener(new android.animation.AnimatorListenerAdapter() {
			private boolean stopped;

			@Override public void onAnimationCancel(android.animation.Animator a) {
				stopped = true;
			}

			@Override public void onAnimationEnd(android.animation.Animator a) {
				if (!stopped && thenGone && listener != null) listener.onSheetGone();
			}
		});
		moving.start();
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		int width = MeasureSpec.getSize(widthSpec);
		int height = MeasureSpec.getSize(heightSpec);
		setMeasuredDimension(width, height);
		int room = height * fullFraction / 100 - Math.round(HANDLE_DP * density);
		for (int i = 0; i < getChildCount(); i++) {
			getChildAt(i).measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
				MeasureSpec.makeMeasureSpec(room, MeasureSpec.EXACTLY));
		}
	}

	@Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
		for (int i = 0; i < getChildCount(); i++) {
			View child = getChildAt(i);
			child.layout(0, 0, child.getMeasuredWidth(), child.getMeasuredHeight());
		}
		if (offset < 0) {
			offset = b - t;
			place(offset);
			moveTo(halfTop(), false);
		} else if (!closing) {
			place(Math.max(offset, fullTop()));
		}
	}

	@Override protected void onDraw(Canvas canvas) {
		canvas.drawRect(0, 0, getWidth(), getHeight(), scrim);
		box.set(0, offset, getWidth(), getHeight() + radius);
		canvas.drawRoundRect(box, radius, radius, paint);
		float w = 32 * density;
		float x = (getWidth() - w) / 2f;
		float y = offset + 24 * density;
		box.set(x, y - 2 * density, x + w, y + 2 * density);
		canvas.drawRoundRect(box, 2 * density, 2 * density, handle);
	}

	/** Can whatever lies under the touch still scroll toward the top? */
	private static boolean canScrollUp(View view, float x, float y) {
		if (view.canScrollVertically(-1)) return true;
		if (view instanceof ViewGroup) {
			ViewGroup group = (ViewGroup) view;
			for (int i = group.getChildCount() - 1; i >= 0; i--) {
				View child = group.getChildAt(i);
				if (child.getVisibility() == VISIBLE
						&& x >= child.getLeft() + child.getTranslationX() && x < child.getRight() + child.getTranslationX()
						&& y >= child.getTop() + child.getTranslationY() && y < child.getBottom() + child.getTranslationY()
						&& canScrollUp(child, x - child.getLeft() - child.getTranslationX(), y - child.getTop() - child.getTranslationY())) {
					return true;
				}
			}
		}
		return false;
	}

	@Override public boolean onInterceptTouchEvent(MotionEvent e) {
		switch (e.getActionMasked()) {
		case MotionEvent.ACTION_DOWN:
			downX = e.getX();
			downY = lastY = e.getY();
			dragging = downY < offset + HANDLE_DP * density;
			if (tracker == null) tracker = VelocityTracker.obtain();
			tracker.clear();
			tracker.addMovement(e);
			break;
		case MotionEvent.ACTION_MOVE:
			tracker.addMovement(e);
			float dy = e.getY() - downY;
			if (Math.abs(dy) > slop && Math.abs(dy) > Math.abs(e.getX() - downX)) {
				boolean up = dy < 0;
				boolean sheetCanRise = offset > fullTop();
				boolean contentAtTop = getChildCount() == 0 || !canScrollUp(getChildAt(0), downX, downY - offset - HANDLE_DP * density);
				if ((up && sheetCanRise) || (!up && contentAtTop)) {
					dragging = true;
					lastY = e.getY();
				}
			}
			break;
		default:
			break;
		}
		return dragging;
	}

	@Override public boolean onTouchEvent(MotionEvent e) {
		if (tracker == null) tracker = VelocityTracker.obtain();
		tracker.addMovement(e);
		switch (e.getActionMasked()) {
		case MotionEvent.ACTION_DOWN:
			downY = lastY = e.getY();
			return true;
		case MotionEvent.ACTION_MOVE:
			place(Math.max(fullTop(), Math.min(getHeight(), offset + Math.round(e.getY() - lastY))));
			lastY = e.getY();
			return true;
		case MotionEvent.ACTION_UP:
			boolean tap = Math.abs(e.getY() - downY) < slop;
			if (tap && e.getY() < offset) {
				dismiss();
			} else {
				tracker.computeCurrentVelocity(1000);
				settle(tracker.getYVelocity());
			}
			dragging = false;
			return true;
		case MotionEvent.ACTION_CANCEL:
			settle(0);
			dragging = false;
			return true;
		default:
			return true;
		}
	}

	private void settle(float speed) {
		int full = fullTop();
		int half = halfTop();
		if (speed > flingSpeed) {
			if (offset < half) moveTo(half, false);
			else moveTo(getHeight(), true);
		} else if (speed < -flingSpeed) {
			moveTo(full, false);
		} else if (offset < (full + half) / 2) {
			moveTo(full, false);
		} else if (offset < (half + getHeight()) / 2) {
			moveTo(half, false);
		} else {
			moveTo(getHeight(), true);
		}
	}
}
