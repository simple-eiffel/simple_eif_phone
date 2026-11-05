package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;

/**
 * A row whose first child takes what room it needs and the others always keep theirs, so a
 * long title wraps and the chip after it stays whole. Children are centered on the line.
 * Apps use PHONE_FIT_ROW and never edit this.
 */
public class EifPhoneFitRow extends ViewGroup {
	public EifPhoneFitRow(Context context) {
		super(context);
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		int width = MeasureSpec.getSize(widthSpec);
		int room = width - getPaddingLeft() - getPaddingRight();
		int tall = 0;
		int free = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED);
		for (int i = 1; i < getChildCount(); i++) {
			View child = getChildAt(i);
			if (child.getVisibility() == GONE) continue;
			child.measure(MeasureSpec.makeMeasureSpec(room, MeasureSpec.AT_MOST), free);
			room -= child.getMeasuredWidth();
			tall = Math.max(tall, child.getMeasuredHeight());
		}
		if (getChildCount() > 0) {
			View first = getChildAt(0);
			first.measure(MeasureSpec.makeMeasureSpec(Math.max(0, room), MeasureSpec.AT_MOST), free);
			tall = Math.max(tall, first.getMeasuredHeight());
		}
		setMeasuredDimension(width, resolveSize(tall + getPaddingTop() + getPaddingBottom(), heightSpec));
	}

	@Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
		int x = getPaddingLeft();
		int middle = (b - t + getPaddingTop() - getPaddingBottom()) / 2;
		for (int i = 0; i < getChildCount(); i++) {
			View child = getChildAt(i);
			if (child.getVisibility() == GONE) continue;
			int h = child.getMeasuredHeight();
			child.layout(x, middle - h / 2, x + child.getMeasuredWidth(), middle - h / 2 + h);
			x += child.getMeasuredWidth();
		}
	}
}
