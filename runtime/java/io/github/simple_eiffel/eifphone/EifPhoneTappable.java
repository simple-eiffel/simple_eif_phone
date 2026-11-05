package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.text.method.LinkMovementMethod;
import android.widget.TextView;

/**
 * Styled text whose marked runs can be tapped. Apps use PHONE_TAPPABLE_TEXT and never edit this.
 */
public class EifPhoneTappable extends TextView {
	/** Told which run was tapped, counting every run of the block from 0. */
	public interface OnRunListener {
		void onRun(int run);
	}

	private OnRunListener listener;

	public EifPhoneTappable(Context context) {
		super(context);
		setMovementMethod(LinkMovementMethod.getInstance());
		setHighlightColor(0);
	}

	public void setOnRunListener(OnRunListener l) {
		listener = l;
	}

	void tapped(int run) {
		if (listener != null) listener.onRun(run);
	}
}
