package io.github.simple_eiffel.eifphone;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.ColorDrawable;
import android.text.Editable;
import android.text.InputType;
import android.text.TextPaint;
import android.text.TextWatcher;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;

/**
 * An outlined text field: a box with a label that rests inside it while it is empty and
 * unfocused, and floats into a gap in the outline otherwise. A placeholder shows when it
 * is focused and empty. Apps use PHONE_FIELD and never edit this.
 */
public class EifPhoneField extends FrameLayout {
	/** Told of what the user does. */
	public interface OnFieldListener {
		void onChanged(String text);
		void onAction();
		void onLeft();
	}

	private static final float REST_SP = 16f;
	private static final float FLOAT_SP = 12f;

	private final float density;
	private final EditText box;
	private final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final TextPaint words = new TextPaint(Paint.ANTI_ALIAS_FLAG);
	private final RectF edge = new RectF();
	private String label = "";
	private String placeholder = "";
	private int accent = 0xFFE2C27A;
	private int outline = 0xFF5B606C;
	private int muted = 0xFFB9B4A8;
	private float floated;
	private ValueAnimator moving;
	private OnFieldListener listener;
	private boolean quiet;

	public EifPhoneField(Context context) {
		super(context);
		density = context.getResources().getDisplayMetrics().density;
		setWillNotDraw(false);
		line.setStyle(Paint.Style.STROKE);
		box = new EditText(context);
		box.setBackground(new ColorDrawable(0));
		box.setTextSize(TypedValue.COMPLEX_UNIT_SP, REST_SP);
		box.setLetterSpacing(0.5f / 16f);
		box.setIncludeFontPadding(false);
		box.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
		int sides = Math.round(16 * density);
		box.setPadding(sides, sides, sides, sides);
		box.setSingleLine(true);
		box.setMinimumHeight(Math.round(56 * density));
		addView(box, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
		setPadding(0, Math.round(8 * density), 0, 0);
		box.addTextChangedListener(new TextWatcher() {
			@Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
			@Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
			@Override public void afterTextChanged(Editable s) {
				settle();
				if (!quiet && listener != null) listener.onChanged(s.toString());
			}
		});
		box.setOnEditorActionListener((v, action, event) -> {
			if (listener != null) listener.onAction();
			return true;
		});
		box.setOnFocusChangeListener((v, focused) -> {
			settle();
			box.setHint(focused ? placeholder : "");
			invalidate();
			if (!focused && listener != null) listener.onLeft();
		});
	}

	public void setOnFieldListener(OnFieldListener l) {
		listener = l;
	}

	public void setLabel(String text) {
		label = text;
		settle();
		invalidate();
	}

	public void setPlaceholder(String text) {
		placeholder = text;
		if (box.hasFocus()) box.setHint(text);
	}

	public void setAccent(int color) {
		accent = color;
		box.setHighlightColor(color & 0x66FFFFFF);
		if (android.os.Build.VERSION.SDK_INT >= 29) {
			android.graphics.drawable.GradientDrawable cursor = new android.graphics.drawable.GradientDrawable();
			cursor.setColor(color);
			cursor.setSize(Math.round(2 * density), Math.round(20 * density));
			box.setTextCursorDrawable(cursor);
		}
		invalidate();
	}

	public void setOutline(int color) {
		outline = color;
		invalidate();
	}

	public void setMuted(int color) {
		muted = color;
		box.setHintTextColor(color);
		invalidate();
	}

	public void setWords(int color) {
		box.setTextColor(color);
	}

	public void setText(String text) {
		quiet = true;
		box.setText(text);
		box.setSelection(text.length());
		quiet = false;
		floated = floatWanted() ? 1f : 0f;
		invalidate();
	}

	public void setMultiLine(int lines) {
		box.setSingleLine(false);
		box.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
		box.setGravity(Gravity.TOP | Gravity.START);
		box.setMinLines(lines);
	}

	/** The box at least this tall, in density-independent pixels. */
	public void setBoxHeight(int dp) {
		box.setMinimumHeight(Math.round(dp * density));
	}

	public void setKeyboardAction(int action) {
		box.setImeOptions(action | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
	}

	public void setNoSuggestions(boolean on) {
		if (on) box.setInputType(box.getInputType() | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
	}

	/** Take the focus and bring up the keyboard. */
	public void enter() {
		box.requestFocus();
		((InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE)).showSoftInput(box, 0);
	}

	/** Give up the focus and put the keyboard away. */
	public void leave() {
		((InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(box.getWindowToken(), 0);
		box.clearFocus();
	}

	private boolean floatWanted() {
		return box.hasFocus() || box.length() > 0;
	}

	private void settle() {
		float target = floatWanted() ? 1f : 0f;
		if (target == floated) return;
		if (moving != null) moving.cancel();
		moving = ValueAnimator.ofFloat(floated, target);
		moving.setDuration(150);
		moving.addUpdateListener(a -> {
			floated = (float) a.getAnimatedValue();
			invalidate();
		});
		moving.start();
	}

	private float sp(float size) {
		return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size, getResources().getDisplayMetrics());
	}

	@Override protected void dispatchDraw(Canvas canvas) {
		super.dispatchDraw(canvas);
		boolean focused = box.hasFocus();
		float stroke = (focused ? 2 : 1) * density;
		float top = getPaddingTop() + stroke / 2f;
		float size = sp(REST_SP + (FLOAT_SP - REST_SP) * floated);
		words.setTextSize(size);
		float width = label.isEmpty() ? 0f : words.measureText(label);
		line.setStrokeWidth(stroke);
		line.setColor(focused ? accent : outline);
		edge.set(stroke / 2f, top, getWidth() - stroke / 2f, getHeight() - stroke / 2f);
		float radius = 4 * density;
		float x = 16 * density;
		float gap = 4 * density;
		int saved = canvas.save();
		if (floated > 0f && width > 0f) {
			float half = (width + 2 * gap) * floated / 2f;
			float middle = x - gap + (width + 2 * gap) / 2f;
			canvas.clipOutRect(middle - half, 0f, middle + half, top + stroke);
		}
		canvas.drawRoundRect(edge, radius, radius, line);
		canvas.restoreToCount(saved);
		if (width > 0f) {
			words.setColor(focused ? accent : muted);
			Paint.FontMetrics m = words.getFontMetrics();
			float restY = getPaddingTop() + 28 * density - (m.ascent + m.descent) / 2f;
			float floatY = top - (m.ascent + m.descent) / 2f;
			canvas.drawText(label, x, restY + (floatY - restY) * floated, words);
		}
	}
}
