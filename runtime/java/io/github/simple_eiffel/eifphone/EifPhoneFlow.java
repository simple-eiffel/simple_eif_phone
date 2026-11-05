package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;

/**
 * Children laid out in lines that wrap. With a cell width it is a grid of as many equal
 * columns as fit; without one, each child keeps its size. Lines can run right to left.
 * Apps use PHONE_FLOW and never edit this.
 */
public class EifPhoneFlow extends ViewGroup {
	private final float density;
	private int cell;
	private int cellHeight;
	private int gap;
	private boolean rightToLeft;

	public EifPhoneFlow(Context context) {
		super(context);
		density = context.getResources().getDisplayMetrics().density;
	}

	public void setCellWidth(int dp) {
		cell = Math.round(dp * density);
		requestLayout();
	}

	public void setCellHeight(int dp) {
		cellHeight = Math.round(dp * density);
		requestLayout();
	}

	public void setGap(int dp) {
		gap = Math.round(dp * density);
		requestLayout();
	}

	public void setRightToLeft(boolean on) {
		rightToLeft = on;
		requestLayout();
	}

	private int columns(int room) {
		return Math.max(1, (room + gap) / (cell + gap));
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		int width = MeasureSpec.getSize(widthSpec);
		int room = width - getPaddingLeft() - getPaddingRight();
		int x = 0;
		int lineTall = 0;
		int tall = 0;
		int columns = cell > 0 ? columns(room) : 0;
		int fixedWidth = cell > 0 ? (room - gap * (columns - 1)) / columns : 0;
		int w = cell > 0 ? MeasureSpec.makeMeasureSpec(fixedWidth, MeasureSpec.EXACTLY) : MeasureSpec.makeMeasureSpec(room, MeasureSpec.AT_MOST);
		int h = cellHeight > 0 ? MeasureSpec.makeMeasureSpec(cellHeight, MeasureSpec.EXACTLY) : MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED);
		for (int i = 0; i < getChildCount(); i++) {
			View child = getChildAt(i);
			if (child.getVisibility() == GONE) continue;
			child.measure(w, h);
			int cw = child.getMeasuredWidth();
			if (x > 0 && x + cw > room) {
				tall += lineTall + gap;
				x = 0;
				lineTall = 0;
			}
			x += cw + gap;
			lineTall = Math.max(lineTall, child.getMeasuredHeight());
		}
		tall += lineTall + getPaddingTop() + getPaddingBottom();
		setMeasuredDimension(width, resolveSize(tall, heightSpec));
	}

	@Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
		int room = r - l - getPaddingLeft() - getPaddingRight();
		int x = 0;
		int y = getPaddingTop();
		int lineTall = 0;
		for (int i = 0; i < getChildCount(); i++) {
			View child = getChildAt(i);
			if (child.getVisibility() == GONE) continue;
			int cw = child.getMeasuredWidth();
			int ch = child.getMeasuredHeight();
			if (x > 0 && x + cw > room) {
				y += lineTall + gap;
				x = 0;
				lineTall = 0;
			}
			int left = rightToLeft ? getPaddingLeft() + room - x - cw : getPaddingLeft() + x;
			child.layout(left, y, left + cw, y + ch);
			x += cw + gap;
			lineTall = Math.max(lineTall, ch);
		}
	}
}
