package io.github.simple_eiffel.eifphone;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.view.View;
import android.view.WindowManager;

/**
 * What the app asks of the phone rather than of a control: a timer, the clipboard, sharing,
 * the screen staying on. Never shown. Apps use PHONE_SERVICES and never edit this.
 */
public class EifPhoneServices extends View {
	/** Told when a timer is due. */
	public interface OnDueListener {
		void onDue(int token);
	}

	/** Told how a file choice ended: done, cancelled or failed, with why. */
	public interface OnFileListener {
		void onFile(String outcome, String detail);
	}

	private static final int OPEN_REQUEST = 7301;
	private static final int SAVE_REQUEST = 7302;

	private OnDueListener listener;
	private OnFileListener fileListener;
	private int nextDelay;
	private String path = "";

	public EifPhoneServices(Context context) {
		super(context);
	}

	public void setOnDueListener(OnDueListener l) {
		listener = l;
	}

	/** The wait, in milliseconds, of the next `start'. */
	public void setDelay(int ms) {
		nextDelay = ms;
	}

	public void start(int token) {
		new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
			if (listener != null) listener.onDue(token);
		}, nextDelay);
	}

	public void setOnFileListener(OnFileListener l) {
		fileListener = l;
	}

	private void told(final String outcome, final String detail) {
		// This view is never attached, and an unattached view's post waits for ever.
		new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
			if (fileListener != null) fileListener.onFile(outcome, detail);
		});
	}

	/** The target path, then the media types, separated by U+001D. */
	public void openFile(String wire) {
		String[] p = wire.split("\u001D", -1);
		path = p[0];
		String[] types = java.util.Arrays.copyOfRange(p, 1, p.length);
		Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*").putExtra(Intent.EXTRA_MIME_TYPES, types);
		start(intent, OPEN_REQUEST);
	}

	/** The source path, the name to suggest and the media type, separated by U+001D. */
	public void saveFile(String wire) {
		String[] p = wire.split("\u001D", -1);
		path = p[0];
		Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(p[2]).putExtra(Intent.EXTRA_TITLE, p[1]);
		start(intent, SAVE_REQUEST);
	}

	private void start(Intent intent, int request) {
		EifPhoneActivity activity = (EifPhoneActivity) getContext();
		activity.setResultListener(this::result);
		try {
			activity.startActivityForResult(intent, request);
		} catch (RuntimeException e) {
			told("failed", "no file picker on this phone");
		}
	}

	private void result(int request, int outcome, Intent data) {
		if (request != OPEN_REQUEST && request != SAVE_REQUEST) return;
		if (outcome != Activity.RESULT_OK || data == null || data.getData() == null) {
			told("cancelled", "");
			return;
		}
		final android.net.Uri uri = data.getData();
		new Thread(() -> {
			try {
				android.content.ContentResolver files = getContext().getContentResolver();
				try (java.io.InputStream in = request == OPEN_REQUEST ? files.openInputStream(uri) : new java.io.FileInputStream(path);
					 java.io.OutputStream out = request == OPEN_REQUEST ? new java.io.FileOutputStream(path) : files.openOutputStream(uri)) {
					byte[] buffer = new byte[65536];
					int n;
					while ((n = in.read(buffer)) > 0) out.write(buffer, 0, n);
				}
				told("done", "");
			} catch (Exception e) {
				told("failed", String.valueOf(e.getMessage()));
			}
		}).start();
	}

	/** The phone's medium date pattern, its clock offset now, and its short month names. */
	public String dateForm() {
		java.text.DateFormat form = java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM);
		String pattern = form instanceof java.text.SimpleDateFormat ? ((java.text.SimpleDateFormat) form).toPattern() : "MMM d, y";
		StringBuilder out = new StringBuilder(pattern).append('|').append(java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()));
		String[] months = java.text.DateFormatSymbols.getInstance().getShortMonths();
		for (int i = 0; i < 12; i++) out.append('|').append(months[i]);
		return out.toString();
	}

	public void hideKeyboard() {
		View focused = ((Activity) getContext()).getCurrentFocus();
		android.os.IBinder token = focused != null ? focused.getWindowToken() : ((Activity) getContext()).getWindow().getDecorView().getWindowToken();
		((android.view.inputmethod.InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(token, 0);
	}

	public void copyText(String text) {
		((ClipboardManager) getContext().getSystemService(Context.CLIPBOARD_SERVICE))
			.setPrimaryClip(ClipData.newPlainText("text", text));
	}

	public void shareText(String text) {
		Intent send = new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text);
		getContext().startActivity(Intent.createChooser(send, "Share"));
	}

	public void keepScreenOn(boolean on) {
		Activity activity = (Activity) getContext();
		if (on) activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
		else activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
	}

	public void openTextToSpeechSettings() {
		getContext().startActivity(new Intent("com.android.settings.TTS_SETTINGS"));
	}
}
