package io.github.simple_eiffel.eifphone;

import android.app.NativeActivity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * The fixed Java helper of simple_eif_phone (Spec D-010). Apps never edit it.
 *
 * Read-aloud and the file picker live here, because Android offers them only
 * to Java. Calls arrive from the Eiffel thread. Results go back through
 * sephoneEvent, which the C glue registers: it copies them into a locked
 * mailbox and wakes the Eiffel loop. No Java thread ever touches an Eiffel
 * object. Text crosses as UTF-8 bytes in both directions.
 *
 * Event codes must match PHONE_EVENT_KIND and sephone.h.
 */
public class EifPhoneActivity extends NativeActivity {
	private static final int SPEECH_READY = 40;
	private static final int SPEECH_FAILED = 41;
	private static final int SPEECH_DONE = 42;
	private static final int FILE_PICKED = 43;
	private static final int FILE_CANCELLED = 44;
	private static final int FILE_FAILED = 45;

	private static final int FAILED_NO_ENGINE = 1;
	private static final int FAILED_LANGUAGE = 2;
	private static final int FAILED_UTTERANCE = 3;
	private static final int DONE_FINISHED = 0;
	private static final int DONE_STOPPED = 1;

	private static final int PICK_REQUEST = 4201;

	private TextToSpeech speech;
	private int utterance = 0;

	private static native void sephoneEvent(int kind, int code, byte[] text);

	private static void send(int kind, int code, String text) {
		sephoneEvent(kind, code, text.getBytes(StandardCharsets.UTF_8));
	}

	// ---- read-aloud

	public void sephoneSpeechStart() {
		runOnUiThread(() -> {
			speech = new TextToSpeech(this, status -> {
				if (status == TextToSpeech.SUCCESS) {
					speech.setOnUtteranceProgressListener(new UtteranceProgressListener() {
						@Override public void onStart(String id) { }
						@Override public void onDone(String id) { send(SPEECH_DONE, DONE_FINISHED, ""); }
						@Override public void onError(String id) { send(SPEECH_FAILED, FAILED_UTTERANCE, ""); }
						@Override public void onStop(String id, boolean interrupted) { send(SPEECH_DONE, DONE_STOPPED, ""); }
					});
					send(SPEECH_READY, 0, "");
				} else {
					send(SPEECH_FAILED, FAILED_NO_ENGINE, "");
				}
			});
		});
	}

	public void sephoneSpeak(byte[] text, byte[] language) {
		final String words = new String(text, StandardCharsets.UTF_8);
		final String tag = new String(language, StandardCharsets.UTF_8);
		runOnUiThread(() -> {
			if (speech == null) {
				send(SPEECH_FAILED, FAILED_NO_ENGINE, "");
			} else if (speech.setLanguage(Locale.forLanguageTag(tag)) < 0) {
				send(SPEECH_FAILED, FAILED_LANGUAGE, tag);
			} else {
				utterance = utterance + 1;
				if (speech.speak(words, TextToSpeech.QUEUE_FLUSH, null, "eifphone" + utterance) != TextToSpeech.SUCCESS) {
					send(SPEECH_FAILED, FAILED_UTTERANCE, "");
				}
			}
		});
	}

	public void sephoneSpeechStop() {
		runOnUiThread(() -> {
			if (speech != null) {
				speech.stop();
			}
		});
	}

	// ---- file picker

	public void sephonePickFile(byte[] mime) {
		final String type = new String(mime, StandardCharsets.UTF_8);
		runOnUiThread(() -> {
			Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			intent.setType(type);
			try {
				startActivityForResult(intent, PICK_REQUEST);
			} catch (RuntimeException e) {
				send(FILE_FAILED, 0, "no file picker on this phone");
			}
		});
	}

	@Override
	protected void onActivityResult(int request, int result, Intent data) {
		super.onActivityResult(request, result, data);
		if (request == PICK_REQUEST) {
			if (result == RESULT_OK && data != null && data.getData() != null) {
				final Uri uri = data.getData();
				new Thread(() -> copyPicked(uri)).start();
			} else {
				send(FILE_CANCELLED, 0, "");
			}
		}
	}

	/** Eiffel reads plain files, so the chosen document is copied into the app's cache. */
	private void copyPicked(Uri uri) {
		try {
			File folder = new File(getCacheDir(), "picked");
			folder.mkdirs();
			File target = new File(folder, displayName(uri));
			try (InputStream in = getContentResolver().openInputStream(uri);
				 OutputStream out = new FileOutputStream(target)) {
				byte[] buffer = new byte[65536];
				int n;
				while ((n = in.read(buffer)) > 0) {
					out.write(buffer, 0, n);
				}
			}
			send(FILE_PICKED, 0, target.getAbsolutePath());
		} catch (Exception e) {
			send(FILE_FAILED, 0, String.valueOf(e.getMessage()));
		}
	}

	private String displayName(Uri uri) {
		String name = "picked_file";
		try (Cursor cursor = getContentResolver().query(uri, new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null)) {
			if (cursor != null && cursor.moveToFirst() && cursor.getString(0) != null) {
				name = new File(cursor.getString(0)).getName();
			}
		}
		return name;
	}

	@Override
	protected void onDestroy() {
		if (speech != null) {
			speech.shutdown();
		}
		super.onDestroy();
	}
}
