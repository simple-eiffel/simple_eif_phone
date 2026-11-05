package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.TypedValue;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * A map of filled outlines over land and lakes, with named places, that pinches, pans and
 * says what lies under a tap. Positions come as longitude and latitude in hundred-thousandths.
 * Apps use PHONE_ATLAS and never edit this.
 */
public class EifPhoneAtlas extends View {
	/** Told the outlines under a tap, as their positions from 1, separated by commas. */
	public interface OnAtlasListener {
		void onPicked(String outlines);
	}

	private static final float COS = 0.848f;
	private static final String FIELD = "\u001D";
	private static final String BLOCK = "\u001E";

	private static final class Shape {
		String name;
		float[] ring;
		Path path;
		int color;
		float minX, maxX, minY, maxY;
	}

	private static final class Place {
		String id, name;
		int minZoom;
		float lon, lat;
	}

	private final List<Shape> land = new ArrayList<>();
	private final List<Shape> areas = new ArrayList<>();
	private final List<Place> places = new ArrayList<>();
	private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final Paint words = new Paint(Paint.ANTI_ALIAS_FLAG);
	private final ScaleGestureDetector pinch;
	private final GestureDetector taps;
	private int landColor = 0xFF2E323C;
	private int waterColor = 0xFF101C2B;
	private int labelColor = 0xFFE6E2D9;
	private int dotColor = 0xFFE2C27A;
	private String focus = "";
	private float scale;
	private float offsetX;
	private float offsetY;
	private float lastX;
	private float lastY;
	private boolean panning;
	private OnAtlasListener listener;

	public EifPhoneAtlas(Context context) {
		super(context);
		stroke.setStyle(Paint.Style.STROKE);
		stroke.setStrokeWidth(1.2f);
		pinch = new ScaleGestureDetector(context, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
			@Override public boolean onScale(ScaleGestureDetector d) {
				zoom(d.getScaleFactor(), d.getFocusX(), d.getFocusY());
				return true;
			}
		});
		taps = new GestureDetector(context, new GestureDetector.SimpleOnGestureListener() {
			@Override public boolean onSingleTapUp(MotionEvent e) {
				pick(e.getX(), e.getY());
				return true;
			}
		});
	}

	public void setOnAtlasListener(OnAtlasListener l) {
		listener = l;
	}

	public void setLandColor(int c) { landColor = c; invalidate(); }
	public void setWaterColor(int c) { waterColor = c; invalidate(); }
	public void setLabelColor(int c) { labelColor = c; invalidate(); }
	public void setDotColor(int c) { dotColor = c; invalidate(); }

	public void setFocusPlace(String id) {
		focus = id;
		invalidate();
	}

	/** Outlines as name, then the ring, split by U+001D; outlines by U+001E. */
	public void setLand(String wire) {
		land.clear();
		read(wire, land);
		invalidate();
	}

	public void setAreas(String wire) {
		areas.clear();
		read(wire, areas);
		for (Shape s : areas) {
			float[] hsv = { (float) ((s.name.hashCode() & 0x7fffffff) % 360), 0.55f, 0.85f };
			s.color = Color.HSVToColor(hsv);
		}
		invalidate();
	}

	/** Places as id, name, least zoom, longitude and latitude, split by U+001D; places by U+001E. */
	public void setPlaces(String wire) {
		places.clear();
		if (!wire.isEmpty()) {
			for (String one : wire.split(BLOCK, -1)) {
				String[] p = one.split(FIELD, -1);
				Place place = new Place();
				place.id = p[0];
				place.name = p[1];
				place.minZoom = Integer.parseInt(p[2]);
				place.lon = Integer.parseInt(p[3]) / 100000f;
				place.lat = Integer.parseInt(p[4]) / 100000f;
				places.add(place);
			}
		}
		invalidate();
	}

	private static void read(String wire, List<Shape> into) {
		if (wire.isEmpty()) return;
		for (String one : wire.split(BLOCK, -1)) {
			int at = one.indexOf('\u001D');
			Shape s = new Shape();
			s.name = one.substring(0, at);
			String[] numbers = one.substring(at + 1).split(",");
			int count = numbers.length / 2 * 2;
			s.ring = new float[count];
			s.path = new Path();
			s.minX = s.minY = Float.MAX_VALUE;
			s.maxX = s.maxY = -Float.MAX_VALUE;
			for (int i = 0; i + 1 < count; i += 2) {
				float lon = Integer.parseInt(numbers[i]) / 100000f;
				float lat = Integer.parseInt(numbers[i + 1]) / 100000f;
				s.ring[i] = lon;
				s.ring[i + 1] = lat;
				float x = lon * COS;
				float y = -lat;
				if (i == 0) s.path.moveTo(x, y); else s.path.lineTo(x, y);
				s.minX = Math.min(s.minX, x);
				s.maxX = Math.max(s.maxX, x);
				s.minY = Math.min(s.minY, y);
				s.maxY = Math.max(s.maxY, y);
			}
			s.path.close();
			into.add(s);
		}
	}

	private void zoom(float by, float x, float y) {
		float s = Math.max(4f, Math.min(400f, scale * by));
		float z = s / scale;
		offsetX = x - (x - offsetX) * z;
		offsetY = y - (y - offsetY) * z;
		scale = s;
		invalidate();
	}

	private static boolean inside(float[] ring, float lon, float lat) {
		boolean c = false;
		int j = ring.length - 2;
		for (int i = 0; i + 1 < ring.length; i += 2) {
			float xi = ring[i], yi = ring[i + 1], xj = ring[j], yj = ring[j + 1];
			if ((yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) c = !c;
			j = i;
		}
		return c;
	}

	private void pick(float x, float y) {
		float lon = (x - offsetX) / scale / COS;
		float lat = -(y - offsetY) / scale;
		StringBuilder found = new StringBuilder();
		for (int i = 0; i < areas.size(); i++) {
			if (inside(areas.get(i).ring, lon, lat)) {
				if (found.length() > 0) found.append(',');
				found.append(i + 1);
			}
		}
		if (listener != null) listener.onPicked(found.toString());
	}

	@Override public boolean onTouchEvent(MotionEvent e) {
		pinch.onTouchEvent(e);
		taps.onTouchEvent(e);
		switch (e.getActionMasked()) {
		case MotionEvent.ACTION_DOWN:
			lastX = e.getX();
			lastY = e.getY();
			panning = true;
			break;
		case MotionEvent.ACTION_POINTER_DOWN:
			panning = false;
			break;
		case MotionEvent.ACTION_MOVE:
			if (panning && !pinch.isInProgress() && e.getPointerCount() == 1) {
				offsetX += e.getX() - lastX;
				offsetY += e.getY() - lastY;
				invalidate();
			}
			lastX = e.getX();
			lastY = e.getY();
			break;
		case MotionEvent.ACTION_POINTER_UP:
			panning = false;
			break;
		default:
			break;
		}
		return true;
	}

	private float sp(float size) {
		return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size, getResources().getDisplayMetrics());
	}

	private void firstView() {
		Place wanted = null;
		for (Place p : places) {
			if (p.id.equals(focus)) wanted = p;
		}
		if (wanted != null) {
			scale = getWidth() / (14f * COS);
			offsetX = getWidth() / 2f - wanted.lon * COS * scale;
			offsetY = getHeight() / 2f + wanted.lat * scale;
		} else {
			scale = getWidth() / (40f * COS);
			offsetX = -20f * COS * scale;
			offsetY = 41f * scale;
		}
	}

	private boolean free(List<RectF> taken, RectF r) {
		for (RectF t : taken) {
			if (RectF.intersects(t, r)) return false;
		}
		taken.add(r);
		return true;
	}

	@Override protected void onDraw(Canvas canvas) {
		canvas.drawColor(waterColor);
		if (getWidth() == 0 || places.isEmpty() && !focus.isEmpty()) return;
		if (scale == 0f) firstView();
		int saved = canvas.save();
		canvas.translate(offsetX, offsetY);
		canvas.scale(scale, scale);
		fill.setStyle(Paint.Style.FILL);
		for (Shape s : land) {
			fill.setColor("lake".equals(s.name) ? waterColor : landColor);
			canvas.drawPath(s.path, fill);
		}
		stroke.setStrokeWidth(1.2f / scale);
		for (Shape s : areas) {
			fill.setColor(s.color & 0x00FFFFFF | 0x4D000000);
			canvas.drawPath(s.path, fill);
			stroke.setColor(s.color & 0x00FFFFFF | 0xD9000000);
			canvas.drawPath(s.path, stroke);
		}
		canvas.restoreToCount(saved);
		// Names never overlap: a label that would cover one already drawn is skipped.
		List<RectF> taken = new ArrayList<>();
		float zoom = scale / (getWidth() / (40f * COS));
		List<Place> sorted = new ArrayList<>(places);
		Collections.sort(sorted, Comparator.comparingInt(p -> p.id.equals(focus) ? 0 : p.minZoom));
		for (Place p : sorted) {
			boolean focused = p.id.equals(focus);
			if (p.minZoom > 1 && zoom < 2.5f && !focused) continue;
			float sx = p.lon * COS * scale + offsetX;
			float sy = -p.lat * scale + offsetY;
			if (sx < -20 || sy < -20 || sx > getWidth() + 20 || sy > getHeight() + 20) continue;
			fill.setColor(dotColor);
			canvas.drawCircle(sx, sy, focused ? 7f : 4f, fill);
			if (zoom >= 1.6f || focused) {
				words.setTextSize(sp(focused ? 12 : 10));
				words.setTypeface(focused ? Typeface.DEFAULT_BOLD : Typeface.DEFAULT);
				words.setColor(labelColor);
				label(canvas, taken, p.name, sx + 6, sy, false);
			}
		}
		List<String> named = new ArrayList<>();
		for (Shape a : areas) {
			if (named.contains(a.name)) continue;
			named.add(a.name);
			if ((a.maxX - a.minX) * scale > 90f) {
				float cx = (a.minX + a.maxX) / 2 * scale + offsetX;
				float cy = (a.minY + a.maxY) / 2 * scale + offsetY;
				words.setTextSize(sp(11));
				words.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
				words.setColor(labelColor & 0x00FFFFFF | 0xCC000000);
				label(canvas, taken, a.name, cx, cy, true);
			}
		}
	}

	private void label(Canvas canvas, List<RectF> taken, String text, float x, float y, boolean centered) {
		Paint.FontMetrics m = words.getFontMetrics();
		float w = words.measureText(text);
		float h = m.descent - m.ascent;
		float left = centered ? x - w / 2 : x;
		RectF r = new RectF(left, y - h / 2, left + w, y + h / 2);
		if (free(taken, r)) canvas.drawText(text, left, r.top - m.ascent, words);
	}
}
