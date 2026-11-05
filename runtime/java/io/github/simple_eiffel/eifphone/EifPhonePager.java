package io.github.simple_eiffel.eifphone;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.content.Context;
import android.view.MotionEvent;
import android.view.VelocityTracker;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;

/**
 * Pages swiped sideways, any number of them, on three children reused in turn: page n
 * always sits in child n % 3. Children scroll up and down for themselves; a drag that
 * is plainly sideways is taken here. Apps use PHONE_PAGER and never edit this.
 */
public class EifPhonePager extends ViewGroup {
	/** Called on the UI thread. Fill child `slot' with `page'; `page' is now the one showing. */
	public interface OnPageListener {
		void onPageWanted(int slot, int page);
		void onPageChosen(int page);
	}

	private static final int SETTLE_MS = 220;

	private final int slop;
	private final int flingSpeed;
	private final int[] shown = { -1, -1, -1 };
	private int count;
	private int page;
	private float drag;
	private float downX;
	private float downY;
	private float lastX;
	private boolean dragging;
	private VelocityTracker tracker;
	private ValueAnimator settling;
	private OnPageListener listener;

	public EifPhonePager(Context context) {
		super(context);
		ViewConfiguration c = ViewConfiguration.get(context);
		slop = c.getScaledTouchSlop();
		flingSpeed = c.getScaledMinimumFlingVelocity() * 8;
	}

	public void setOnPageListener(OnPageListener l) {
		listener = l;
	}

	public void setPageCount(int n) {
		count = n;
		shown[0] = shown[1] = shown[2] = -1;
		fill();
	}

	/** Go straight to `p', with no slide. */
	public void setPage(int p) {
		if (settling != null) settling.cancel();
		page = Math.max(0, Math.min(p, count - 1));
		drag = 0;
		fill();
		place();
		if (listener != null) listener.onPageChosen(page);
	}

	/** Slide one page, as a swipe would. `step' is 1 or -1. */
	public void slide(int step) {
		if (page + step >= 0 && page + step < count) settle(step);
	}

	public int getPage() {
		return page;
	}

	private void fill() {
		for (int p = page - 1; p <= page + 1; p++) {
			if (p >= 0 && p < count && shown[p % 3] != p) {
				shown[p % 3] = p;
				if (listener != null) listener.onPageWanted(p % 3, p);
			}
		}
	}

	private void place() {
		int width = getWidth();
		for (int slot = 0; slot < getChildCount() && slot < 3; slot++) {
			View child = getChildAt(slot);
			int p = shown[slot];
			boolean near = p >= page - 1 && p <= page + 1 && p >= 0;
			child.setVisibility(near ? VISIBLE : INVISIBLE);
			child.setTranslationX((p - page) * (float) width + drag);
		}
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		int width = MeasureSpec.getSize(widthSpec);
		int height = MeasureSpec.getSize(heightSpec);
		setMeasuredDimension(width, height);
		int w = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY);
		int h = MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY);
		for (int i = 0; i < getChildCount(); i++) {
			getChildAt(i).measure(w, h);
		}
	}

	@Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
		for (int i = 0; i < getChildCount(); i++) {
			getChildAt(i).layout(0, 0, r - l, b - t);
		}
		place();
	}

	@Override public boolean onInterceptTouchEvent(MotionEvent e) {
		switch (e.getActionMasked()) {
		case MotionEvent.ACTION_DOWN:
			downX = lastX = e.getX();
			downY = e.getY();
			dragging = false;
			if (tracker == null) tracker = VelocityTracker.obtain();
			tracker.clear();
			tracker.addMovement(e);
			if (settling != null) {
				settling.cancel();
				dragging = true;
			}
			break;
		case MotionEvent.ACTION_MOVE:
			tracker.addMovement(e);
			float dx = Math.abs(e.getX() - downX);
			float dy = Math.abs(e.getY() - downY);
			if (dx > slop && dx > dy * 1.5f) {
				dragging = true;
				lastX = e.getX();
				getParent().requestDisallowInterceptTouchEvent(true);
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
			return true;
		case MotionEvent.ACTION_MOVE:
			float next = drag + e.getX() - lastX;
			lastX = e.getX();
			if ((page == 0 && next > 0) || (page == count - 1 && next < 0)) next = 0;
			drag = Math.max(-getWidth(), Math.min(next, getWidth()));
			place();
			return true;
		case MotionEvent.ACTION_UP:
			tracker.computeCurrentVelocity(1000);
			float speed = tracker.getXVelocity();
			int step = 0;
			if (speed < -flingSpeed || drag < -getWidth() / 2f) step = 1;
			else if (speed > flingSpeed || drag > getWidth() / 2f) step = -1;
			if (page + step < 0 || page + step >= count) step = 0;
			dragging = false;
			settle(step);
			return true;
		case MotionEvent.ACTION_CANCEL:
			dragging = false;
			settle(0);
			return true;
		default:
			return true;
		}
	}

	private void settle(int step) {
		final int target = page + step;
		float end = -step * (float) getWidth();
		settling = ValueAnimator.ofFloat(drag, end);
		settling.setDuration(SETTLE_MS);
		settling.setInterpolator(new DecelerateInterpolator(1.5f));
		settling.addUpdateListener(a -> {
			drag = (float) a.getAnimatedValue();
			place();
		});
		settling.addListener(new AnimatorListenerAdapter() {
			private boolean stopped;

			@Override public void onAnimationCancel(Animator a) {
				stopped = true;
			}

			@Override public void onAnimationEnd(Animator a) {
				settling = null;
				if (!stopped) {
					boolean moved = target != page;
					page = target;
					drag = 0;
					fill();
					place();
					if (moved && listener != null) listener.onPageChosen(page);
				}
			}
		});
		settling.start();
	}
}
