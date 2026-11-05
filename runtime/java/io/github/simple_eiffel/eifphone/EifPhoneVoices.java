package io.github.simple_eiffel.eifphone;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;
import android.view.View;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * The phone's text-to-speech engines, every one of them, and their installed voices. Only
 * voices already on the phone are used, never one that needs the network. What to read
 * and in what order stays with the app: it asks for one stretch at a time and hears
 * when each is done. Apps use PHONE_VOICES and never edit this.
 */
public class EifPhoneVoices extends View {
	/** `kind' is done, missing, lost, report or ready. */
	public interface OnVoiceListener {
		void onVoice(String kind, String detail);
	}

	private static final class Engine {
		final String label;
		final TextToSpeech tts;
		boolean ok;
		List<Voice> voices = new ArrayList<>();
		Voice lastVoice;

		Engine(String label, TextToSpeech tts) {
			this.label = label;
			this.tts = tts;
		}
	}

	private static final class Target {
		final Engine engine;
		final Voice voice;
		final Locale locale;

		Target(Engine engine, Voice voice, Locale locale) {
			this.engine = engine;
			this.voice = voice;
			this.locale = locale;
		}
	}

	private final Handler main = new Handler(Looper.getMainLooper());
	private final AudioAttributes attributes = new AudioAttributes.Builder()
		.setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build();
	private final List<Engine> engines = new ArrayList<>();
	private final List<Runnable> waiting = new ArrayList<>();
	private final Map<String, Target> targets = new HashMap<>();
	private final AudioManager audio;
	private final AudioFocusRequest focus;
	private int enginesState;
	private int started;
	private int pending;
	private float rate = 1f;
	private OnVoiceListener listener;

	public EifPhoneVoices(Context context) {
		super(context);
		audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
		// Leaving the app with Back ends any reading; turning the screen off or switching apps does not.
		if (context instanceof android.app.Activity) {
			final android.app.Activity owner = (android.app.Activity) context;
			owner.getApplication().registerActivityLifecycleCallbacks(new android.app.Application.ActivityLifecycleCallbacks() {
				@Override public void onActivityCreated(android.app.Activity a, Bundle b) { }
				@Override public void onActivityStarted(android.app.Activity a) { }
				@Override public void onActivityResumed(android.app.Activity a) { }
				@Override public void onActivityPaused(android.app.Activity a) { }
				@Override public void onActivityStopped(android.app.Activity a) { }
				@Override public void onActivitySaveInstanceState(android.app.Activity a, Bundle b) { }
				@Override public void onActivityDestroyed(android.app.Activity a) {
					if (a == owner) {
						stopSpeaking();
						requestFocus(false);
						for (Engine e : engines) e.tts.shutdown();
						engines.clear();
						owner.getApplication().unregisterActivityLifecycleCallbacks(this);
					}
				}
			});
		}
		focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
			.setAudioAttributes(attributes)
			.setOnAudioFocusChangeListener(change -> {
				if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
					main.post(() -> tell("lost", ""));
				}
			}).build();
	}

	public void setOnVoiceListener(OnVoiceListener l) {
		listener = l;
	}

	private void tell(String kind, String detail) {
		if (listener != null) listener.onVoice(kind, detail);
	}

	/** Speaking rate times 100: 100 is normal. */
	public void setRate(int hundredths) {
		rate = hundredths / 100f;
	}

	public void requestFocus(boolean on) {
		try {
			if (on) audio.requestAudioFocus(focus); else audio.abandonAudioFocusRequest(focus);
		} catch (RuntimeException e) {
			// Reading goes on without audio focus.
		}
	}

	/** Start the engines, if they are not going, and say so. */
	public void prepare(String ignored) {
		withEngines(() -> tell("ready", ""));
	}

	/** id, language codes, country, fallback codes and the text, separated by U+001D. */
	public void speakStretch(String wire) {
		final String[] p = wire.split("\u001D", -1);
		withEngines(() -> {
			Target t = target(p[1], p[2], p[3]);
			if (t == null) {
				tell("missing", p[0]);
				return;
			}
			TextToSpeech tts = t.engine.tts;
			if (t.voice != null) {
				if (t.engine.lastVoice != t.voice) {
					tts.setVoice(t.voice);
					t.engine.lastVoice = t.voice;
				}
			} else {
				tts.setLanguage(t.locale);
				t.engine.lastVoice = null;
			}
			tts.setSpeechRate(rate);
			String text = p[1].startsWith("el") ? Normalizer.normalize(p[4], Normalizer.Form.NFC) : p[4];
			tts.speak(text, TextToSpeech.QUEUE_FLUSH, new Bundle(), p[0]);
		});
	}

	public void stopSpeaking() {
		for (Engine e : engines) {
			try {
				e.tts.stop();
			} catch (RuntimeException x) {
				// An engine that has gone has nothing to stop.
			}
		}
	}

	/** Each language as label, codes, country and fallback, separated by U+001D, the languages by U+001E. */
	public void askReport(String wire) {
		withEngines(() -> {
			if (engines.isEmpty()) {
				tell("report", "This phone has no text-to-speech engine turned on.");
				return;
			}
			StringBuilder out = new StringBuilder();
			for (String one : wire.split("\u001E")) {
				String[] p = one.split("\u001D", -1);
				Target t = target(p[1], p[2], p[3]);
				if (out.length() > 0) out.append('\n');
				out.append(p[0]).append(": ");
				if (t == null) out.append("no voice installed");
				else out.append(t.engine.label).append(", ").append((t.voice != null ? t.voice.getLocale() : t.locale).getDisplayName());
			}
			tell("report", out.toString());
		});
	}

	private void withEngines(Runnable then) {
		if (enginesState == 2 && !engines.isEmpty()) {
			refreshVoices();
			then.run();
			return;
		}
		if (enginesState == 2) {
			for (Engine e : engines) {
				try {
					e.tts.shutdown();
				} catch (RuntimeException x) {
					// Already gone.
				}
			}
			engines.clear();
			enginesState = 0;
		}
		waiting.add(then);
		if (enginesState == 1) return;
		enginesState = 1;
		final TextToSpeech[] first = new TextToSpeech[1];
		first[0] = new TextToSpeech(getContext(), status -> main.post(() -> firstStarted(first[0], status)));
	}

	private void firstStarted(TextToSpeech tts, int status) {
		String fallback = "";
		String preferred;
		List<TextToSpeech.EngineInfo> infos;
		try {
			preferred = tts.getDefaultEngine();
			infos = tts.getEngines();
		} catch (RuntimeException e) {
			preferred = fallback;
			infos = Collections.emptyList();
		}
		String label = preferred;
		List<TextToSpeech.EngineInfo> others = new ArrayList<>();
		for (TextToSpeech.EngineInfo info : infos) {
			if (info.name.equals(preferred)) label = info.label; else others.add(info);
		}
		Engine e = new Engine(label, tts);
		e.ok = status == TextToSpeech.SUCCESS;
		engines.add(e);
		if (others.isEmpty()) {
			ready();
			return;
		}
		pending = others.size();
		for (final TextToSpeech.EngineInfo info : others) {
			final TextToSpeech[] other = new TextToSpeech[1];
			other[0] = new TextToSpeech(getContext(), st -> main.post(() -> {
				Engine more = new Engine(info.label, other[0]);
				more.ok = st == TextToSpeech.SUCCESS;
				engines.add(more);
				if (--pending == 0) ready();
			}), info.name);
		}
	}

	private void ready() {
		List<Engine> working = new ArrayList<>();
		for (Engine e : engines) {
			if (e.ok) {
				working.add(e);
			} else {
				try {
					e.tts.shutdown();
				} catch (RuntimeException x) {
					// Already gone.
				}
			}
		}
		engines.clear();
		engines.addAll(working);
		for (Engine e : engines) {
			e.tts.setAudioAttributes(attributes);
			e.tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
				@Override public void onStart(String id) { }
				@Override public void onDone(String id) { ended(id); }
				@Override public void onError(String id) { ended(id); }
				@Override public void onError(String id, int code) { ended(id); }
			});
		}
		refreshVoices();
		enginesState = 2;
		List<Runnable> run = new ArrayList<>(waiting);
		waiting.clear();
		for (Runnable r : run) r.run();
	}

	private void ended(final String id) {
		main.post(() -> tell("done", String.valueOf(id)));
	}

	private void refreshVoices() {
		for (Engine e : engines) {
			e.voices = new ArrayList<>();
			Set<Voice> all = null;
			try {
				all = e.tts.getVoices();
			} catch (RuntimeException x) {
				// Treated as an engine that lists none.
			}
			if (all == null) continue;
			for (Voice v : all) {
				Set<String> features = v.getFeatures();
				boolean missing = features != null && features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED);
				if (!v.isNetworkConnectionRequired() && !missing) e.voices.add(v);
			}
		}
		targets.clear();
	}

	private Target target(String codes, String country, String fallback) {
		String key = codes + "/" + country + "/" + fallback;
		if (targets.containsKey(key)) return targets.get(key);
		Target found = find(codes, country);
		if (found == null && !fallback.isEmpty()) found = find(fallback, country);
		targets.put(key, found);
		return found;
	}

	private Target find(String codes, String country) {
		String[] list = codes.split(",");
		Locale device = Locale.getDefault();
		String wanted = list[0].equals("en") && device.getLanguage().equals("en") ? device.getCountry() : country;
		for (Engine e : engines) {
			Voice best = null;
			for (Voice v : e.voices) {
				if (has(list, v.getLocale().getLanguage()) && (best == null || better(v, best, wanted))) best = v;
			}
			if (best != null) return new Target(e, best, best.getLocale());
			if (e.voices.isEmpty()) {
				Locale locale = new Locale(list[0], wanted);
				int r;
				try {
					r = e.tts.isLanguageAvailable(locale);
				} catch (RuntimeException x) {
					r = TextToSpeech.LANG_NOT_SUPPORTED;
				}
				if (r >= TextToSpeech.LANG_AVAILABLE) return new Target(e, null, locale);
			}
		}
		return null;
	}

	private static boolean has(String[] list, String code) {
		for (String s : list) {
			if (s.equals(code)) return true;
		}
		return false;
	}

	/** The right country first, then quality, then speed. */
	private static boolean better(Voice a, Voice b, String country) {
		boolean ca = a.getLocale().getCountry().equals(country);
		boolean cb = b.getLocale().getCountry().equals(country);
		if (ca != cb) return ca;
		if (a.getQuality() != b.getQuality()) return a.getQuality() > b.getQuality();
		return a.getLatency() < b.getLatency();
	}
}
