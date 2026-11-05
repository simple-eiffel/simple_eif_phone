package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.view.View;

/**
 * An icon drawn from SVG path data on a 24 by 24 grid, in one color, at any size, so
 * an app needs no image files for its icons. Apps use PHONE_ICON and never edit this.
 */
public class EifPhoneIcon extends View {
	private final Path path = new Path();
	private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
	private float size;

	public EifPhoneIcon(Context context) {
		super(context);
		size = 24 * context.getResources().getDisplayMetrics().density;
		paint.setStyle(Paint.Style.FILL);
	}

	public void setPathData(String data) {
		path.reset();
		parse(data, path);
		invalidate();
	}

	public void setTint(int color) {
		paint.setColor(color);
		invalidate();
	}

	/** The drawing's size in density-independent pixels; any more room is left around it. */
	public void setIconSize(int dp) {
		size = dp * getResources().getDisplayMetrics().density;
		requestLayout();
	}

	@Override protected void onMeasure(int widthSpec, int heightSpec) {
		int natural = Math.round(size) + getPaddingLeft() + getPaddingRight();
		int tall = Math.round(size) + getPaddingTop() + getPaddingBottom();
		setMeasuredDimension(resolveSize(natural, widthSpec), resolveSize(tall, heightSpec));
	}

	@Override protected void onDraw(Canvas canvas) {
		int saved = canvas.save();
		canvas.translate((getWidth() - size) / 2f, (getHeight() - size) / 2f);
		canvas.scale(size / 24f, size / 24f);
		canvas.drawPath(path, paint);
		canvas.restoreToCount(saved);
	}

	/** The commands the Material icons use: M L H V C S Z, in both cases, with repeats. */
	static void parse(String d, Path p) {
		int i = 0;
		int n = d.length();
		char command = 'M';
		float x = 0, y = 0, startX = 0, startY = 0, lastControlX = 0, lastControlY = 0;
		boolean afterCurve = false;
		float[] a = new float[6];
		int[] at = { 0 };
		while (true) {
			at[0] = i;
			skip(d, at);
			i = at[0];
			if (i >= n) return;
			char c = d.charAt(i);
			if (Character.isLetter(c)) {
				command = c;
				i++;
				if (c == 'z' || c == 'Z') {
					p.close();
					x = startX;
					y = startY;
					afterCurve = false;
					continue;
				}
			}
			boolean relative = Character.isLowerCase(command);
			char kind = Character.toUpperCase(command);
			int count = kind == 'C' ? 6 : kind == 'S' ? 4 : kind == 'H' || kind == 'V' ? 1 : 2;
			at[0] = i;
			for (int k = 0; k < count; k++) {
				a[k] = number(d, at);
			}
			i = at[0];
			float bx = relative ? x : 0;
			float by = relative ? y : 0;
			switch (kind) {
			case 'M':
				x = a[0] + bx;
				y = a[1] + by;
				p.moveTo(x, y);
				startX = x;
				startY = y;
				command = relative ? 'l' : 'L';
				afterCurve = false;
				break;
			case 'L':
				x = a[0] + bx;
				y = a[1] + by;
				p.lineTo(x, y);
				afterCurve = false;
				break;
			case 'H':
				x = a[0] + bx;
				p.lineTo(x, y);
				afterCurve = false;
				break;
			case 'V':
				y = a[0] + by;
				p.lineTo(x, y);
				afterCurve = false;
				break;
			case 'C':
				p.cubicTo(a[0] + bx, a[1] + by, a[2] + bx, a[3] + by, a[4] + bx, a[5] + by);
				lastControlX = a[2] + bx;
				lastControlY = a[3] + by;
				x = a[4] + bx;
				y = a[5] + by;
				afterCurve = true;
				break;
			case 'S':
				float cx = afterCurve ? 2 * x - lastControlX : x;
				float cy = afterCurve ? 2 * y - lastControlY : y;
				p.cubicTo(cx, cy, a[0] + bx, a[1] + by, a[2] + bx, a[3] + by);
				lastControlX = a[0] + bx;
				lastControlY = a[1] + by;
				x = a[2] + bx;
				y = a[3] + by;
				afterCurve = true;
				break;
			default:
				return;
			}
		}
	}

	private static void skip(String d, int[] at) {
		while (at[0] < d.length() && (d.charAt(at[0]) == ' ' || d.charAt(at[0]) == ',')) at[0]++;
	}

	private static float number(String d, int[] at) {
		skip(d, at);
		int start = at[0];
		int i = start;
		int n = d.length();
		if (i < n && (d.charAt(i) == '-' || d.charAt(i) == '+')) i++;
		boolean point = false;
		while (i < n) {
			char c = d.charAt(i);
			if (c == '.' && !point) point = true;
			else if (c < '0' || c > '9') break;
			i++;
		}
		at[0] = i;
		return i > start ? Float.parseFloat(d.substring(start, i)) : 0f;
	}
}
