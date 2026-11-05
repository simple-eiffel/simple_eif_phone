package io.github.simple_eiffel.eifphone;

import android.app.NativeActivity;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Rect;
import android.net.Uri;
import android.os.Build;
import android.provider.OpenableColumns;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.PopupWindow;

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
	private static final int KEYBOARD_TEXT = 46;
	private static final int KEYBOARD_BACKSPACE = 47;
	private static final int KEYBOARD_ENTER = 48;
	private static final int KEYBOARD_CLOSED = 49;
	private static final int KEYBOARD_TOP = 63;

	private static final int FAILED_NO_ENGINE = 1;
	private static final int FAILED_LANGUAGE = 2;
	private static final int FAILED_UTTERANCE = 3;
	private static final int DONE_FINISHED = 0;
	private static final int DONE_STOPPED = 1;

	private static final int PICK_REQUEST = 4201;

	private TextToSpeech speech;
	private int utterance = 0;

	/** Kept in the hidden box, so that a backspace has something to delete. */
	private static final String KEYBOARD_MARK = "\u200B";
	private PopupWindow keyboardWindow;
	private EditText keyboardBox;
	private boolean keyboardResetting;
	private int keyboardTop;

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

	// ---- the phone's keyboard, for screens that draw their own text boxes

	public void sephoneKeyboard(int show) {
		runOnUiThread(() -> {
			if (show != 0) {
				openKeyboard();
			} else if (keyboardWindow != null) {
				keyboardWindow.dismiss();
			}
		});
	}

	/**
	 * NativeActivity's window takes no text, so a hidden one-pixel box in a popup
	 * window receives it. Everything typed goes to Eiffel, and the box is emptied.
	 * The popup fills the screen, unseen and letting touches through, because only
	 * a window the keyboard overlaps is told where the keyboard is.
	 */
	private void openKeyboard() {
		if (keyboardWindow != null && keyboardWindow.isShowing()) {
			return;
		}
		keyboardBox = new EditText(this) {
			// Back closes the keyboard and its popup together, or it would take a second
			// Back to close the popup, which nobody can see.
			@Override
			public boolean onKeyPreIme(int key, KeyEvent event) {
				if (key == KeyEvent.KEYCODE_BACK && event.getAction() == KeyEvent.ACTION_UP) {
					keyboardWindow.dismiss();
					return true;
				}
				return super.onKeyPreIme(key, event);
			}
		};
		keyboardBox.setSingleLine(true);
		keyboardBox.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
		keyboardBox.setText(KEYBOARD_MARK);
		keyboardBox.setSelection(KEYBOARD_MARK.length());
		keyboardBox.setOnEditorActionListener((view, action, event) -> {
			send(KEYBOARD_ENTER, 0, "");
			return true;
		});
		keyboardBox.addTextChangedListener(new TextWatcher() {
			@Override public void beforeTextChanged(CharSequence s, int a, int b, int c) { }
			@Override public void onTextChanged(CharSequence s, int a, int b, int c) { }
			@Override public void afterTextChanged(Editable s) {
				if (!keyboardResetting) {
					keyboardTyped(s);
				}
			}
		});
		FrameLayout holder = new FrameLayout(this);
		holder.addView(keyboardBox, new FrameLayout.LayoutParams(1, 1));
		if (Build.VERSION.SDK_INT >= 30) {
			holder.setOnApplyWindowInsetsListener((view, insets) -> {
				int bottom = insets.getInsets(WindowInsets.Type.ime()).bottom;
				view.post(() -> tellKeyboardTop(view, bottom));
				return insets;
			});
		} else {
			// Before Android 11 no inset names the keyboard: what is left of the window does.
			holder.getViewTreeObserver().addOnGlobalLayoutListener(() -> {
				Rect left = new Rect();
				holder.getWindowVisibleDisplayFrame(left);
				int screen = getWindow().getDecorView().getHeight();
				int top = screen - left.bottom > screen / 6 ? left.bottom : 0;
				if (top != keyboardTop) {
					keyboardTop = top;
					send(KEYBOARD_TOP, top, "");
				}
			});
		}
		keyboardWindow = new PopupWindow(holder, ViewGroup.LayoutParams.MATCH_PARENT,
			ViewGroup.LayoutParams.MATCH_PARENT, true);
		keyboardWindow.setTouchable(false);   // the app below still takes touches
		keyboardWindow.setInputMethodMode(PopupWindow.INPUT_METHOD_NEEDED);
		// A request made now would come before the popup has the focus, and be dropped.
		keyboardWindow.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
		if (Build.VERSION.SDK_INT < 30) {
			// Only a window that resizes is told about the keyboard. The popup does that, and
			// the app's own window stays put, or it would move on top of Eiffel's slide.
			keyboardWindow.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
				| WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
			getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING);
		}
		keyboardWindow.setOnDismissListener(() -> {
			keyboardTop = 0;
			send(KEYBOARD_CLOSED, 0, "");
		});
		keyboardWindow.showAtLocation(getWindow().getDecorView(), Gravity.TOP | Gravity.START, 0, 0);
		keyboardBox.requestFocus();
	}

	private void tellKeyboardTop(View view, int bottom) {
		int[] place = new int[2];
		view.getLocationOnScreen(place);
		int top = bottom > 0 ? place[1] + view.getHeight() - bottom : 0;
		if (top != keyboardTop) {
			keyboardTop = top;
			send(KEYBOARD_TOP, top, "");
		}
	}

	private void keyboardTyped(Editable box) {
		String typed = box.toString();
		if (typed.isEmpty()) {
			send(KEYBOARD_BACKSPACE, 0, "");
		} else if (!typed.equals(KEYBOARD_MARK)) {
			send(KEYBOARD_TEXT, 0, typed.replace(KEYBOARD_MARK, ""));
		}
		keyboardResetting = true;
		box.replace(0, box.length(), KEYBOARD_MARK);
		Selection.setSelection(box, KEYBOARD_MARK.length());
		keyboardResetting = false;
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

	/** Told of results the activity itself did not ask for. */
	public interface ResultListener {
		void onResult(int request, int result, Intent data);
	}

	private ResultListener resultListener;

	public void setResultListener(ResultListener l) {
		resultListener = l;
	}

	@Override
	protected void onActivityResult(int request, int result, Intent data) {
		super.onActivityResult(request, result, data);
		if (resultListener != null) resultListener.onResult(request, result, data);
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
