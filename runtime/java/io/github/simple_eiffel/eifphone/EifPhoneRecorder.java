package io.github.simple_eiffel.eifphone;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.View;

import java.util.ArrayList;

/**
 * Records the microphone to a 16 kHz mono WAV file, even with the screen locked. Never shown.
 * Apps use PHONE_RECORDER and never edit this. eifphone.toml needs recorder = true.
 */
public class EifPhoneRecorder extends View {
	/** Told what happened: granted, denied, recording, stopped or failed, with detail. */
	public interface OnRecorderListener {
		void onRecorder(String state, String detail);
	}

	private static final int PERMISSION_REQUEST = 7303;
	private static EifPhoneRecorder current;

	private OnRecorderListener listener;

	public EifPhoneRecorder(Context context) {
		super(context);
		current = this;
	}

	public void setOnRecorderListener(OnRecorderListener l) {
		listener = l;
	}

	/** Ask for the microphone, and for the notification that shows it is on. */
	public void askPermission() {
		Activity activity = (Activity) getContext();
		if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
			told("granted", "");
			return;
		}
		ArrayList<String> wanted = new ArrayList<>();
		wanted.add(Manifest.permission.RECORD_AUDIO);
		if (Build.VERSION.SDK_INT >= 33) wanted.add(Manifest.permission.POST_NOTIFICATIONS);
		activity.requestPermissions(wanted.toArray(new String[0]), PERMISSION_REQUEST);
	}

	/** Start recording to `path'. */
	public void start(String path) {
		Context context = getContext();
		Intent intent = new Intent(context, EifPhoneRecordingService.class);
		intent.putExtra(EifPhoneRecordingService.PATH, path);
		try {
			context.startForegroundService(intent);
		} catch (RuntimeException e) {
			told("failed", String.valueOf(e.getMessage()));
		}
	}

	/** Stop recording. `stopped' follows when the file is complete. */
	public void stop() {
		EifPhoneRecordingService.finish();
	}

	/** Whole seconds recorded so far. */
	public String recordedSeconds() {
		return Long.toString(EifPhoneRecordingService.recordedSeconds());
	}

	/** Called by the activity with Android's answer. */
	static void permissionResult(int code, String[] permissions, int[] results) {
		if (code != PERMISSION_REQUEST || current == null) return;
		boolean granted = false;
		for (int i = 0; i < permissions.length && i < results.length; i++) {
			if (Manifest.permission.RECORD_AUDIO.equals(permissions[i])) {
				granted = results[i] == PackageManager.PERMISSION_GRANTED;
			}
		}
		current.told(granted ? "granted" : "denied", "");
	}

	/** Called by the service from any thread. */
	static void report(String state, String detail) {
		if (current != null) current.told(state, detail);
	}

	private void told(final String state, final String detail) {
		// This view is never attached, and an unattached view's post waits for ever.
		new Handler(Looper.getMainLooper()).post(() -> {
			if (listener != null) listener.onRecorder(state, detail);
		});
	}
}
