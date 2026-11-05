package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListView;
import android.widget.TextView;

/**
 * The view behind PHONE_LIST. A long press says which row, which block of a rich row, and
 * which character lay under the finger. Apps use PHONE_LIST and never edit this.
 */
public class EifPhoneRows extends ListView {
	/** Told of a long press. Rows and blocks count from 0, and `offset' is in UTF-16 units. */
	public interface OnRowPressListener {
		void onRowPress(int row, int block, int offset);
	}

	private float touchX;
	private float touchY;
	private OnRowPressListener pressed;

	public EifPhoneRows(Context context) {
		super(context);
	}

	public void setOnRowPressListener(OnRowPressListener l) {
		pressed = l;
		setOnItemLongClickListener((parent, view, position, id) -> {
			press(view, position);
			return true;
		});
	}

	@Override public boolean dispatchTouchEvent(MotionEvent e) {
		if (e.getActionMasked() == MotionEvent.ACTION_DOWN) {
			touchX = e.getX();
			touchY = e.getY();
		}
		return super.dispatchTouchEvent(e);
	}

	private void press(View row, int position) {
		int block = -1;
		int offset = -1;
		if (row instanceof ViewGroup) {
			ViewGroup group = (ViewGroup) row;
			float y = touchY - row.getTop();
			float x = touchX - row.getLeft();
			for (int i = 0; i < group.getChildCount(); i++) {
				View child = group.getChildAt(i);
				if (child instanceof TextView && y >= child.getTop() && y < child.getBottom()) {
					block = i;
					offset = ((TextView) child).getOffsetForPosition(x - child.getLeft(), y - child.getTop());
				}
			}
		}
		if (pressed != null) pressed.onRowPress(position, block, offset);
	}
}
