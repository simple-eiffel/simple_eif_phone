package io.github.simple_eiffel.eifphone;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.IBinder;

import java.io.IOException;
import java.io.RandomAccessFile;

/**
 * Keeps the microphone running when the screen locks. Android freezes an app that has no
 * foreground service, so the recording lives here and shows a notification while it runs.
 */
public class EifPhoneRecordingService extends Service {
	static final String PATH = "path";

	private static final int RATE = 16000;
	private static final int HEADER = 44;
	private static final int NOTE_ID = 7304;
	private static final String CHANNEL = "eifphone_recording";
	/** The header is rewritten this often, so a killed app still leaves a readable file. */
	private static final int PATCH_BYTES = RATE * 2 * 10;

	private static volatile boolean running;
	private static volatile long dataBytes;

	@Override
	public IBinder onBind(Intent intent) {
		return null;
	}

	static void finish() {
		running = false;
	}

	static long recordedSeconds() {
		return dataBytes / (RATE * 2);
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		String path = intent == null ? null : intent.getStringExtra(PATH);
		showNotification();
		if (path == null || running) {
			if (path == null) stopNow();
			return START_NOT_STICKY;
		}
		running = true;
		dataBytes = 0;
		final String target = path;
		new Thread(() -> record(target), "EifPhoneRecorder").start();
		return START_NOT_STICKY;
	}

	private void showNotification() {
		NotificationManager manager = getSystemService(NotificationManager.class);
		manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Recording", NotificationManager.IMPORTANCE_LOW));
		Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
		PendingIntent tap = open == null ? null
			: PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
		Notification note = new Notification.Builder(this, CHANNEL)
			.setContentTitle("Recording")
			.setContentText("The microphone is on")
			.setSmallIcon(android.R.drawable.ic_btn_speak_now)
			.setContentIntent(tap)
			.setOngoing(true)
			.build();
		if (Build.VERSION.SDK_INT >= 29) {
			startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
		} else {
			startForeground(NOTE_ID, note);
		}
	}

	private void record(String path) {
		AudioRecord mic = null;
		String failure = null;
		try (RandomAccessFile file = new RandomAccessFile(path, "rw")) {
			int least = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
			int size = Math.max(least * 2, RATE);
			mic = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, RATE,
				AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size);
			if (mic.getState() != AudioRecord.STATE_INITIALIZED) throw new IOException("the microphone did not open");
			file.setLength(0);
			writeHeader(file, 0);
			byte[] buffer = new byte[size];
			long sincePatch = 0;
			mic.startRecording();
			EifPhoneRecorder.report("recording", "");
			while (running) {
				int got = mic.read(buffer, 0, buffer.length);
				if (got < 0) throw new IOException("the microphone stopped: " + got);
				file.write(buffer, 0, got);
				dataBytes += got;
				sincePatch += got;
				if (sincePatch >= PATCH_BYTES) {
					sincePatch = 0;
					long end = file.getFilePointer();
					writeHeader(file, dataBytes);
					file.seek(end);
				}
			}
			mic.stop();
			writeHeader(file, dataBytes);
		} catch (IOException | RuntimeException e) {
			failure = String.valueOf(e.getMessage());
		} finally {
			if (mic != null) mic.release();
		}
		running = false;
		if (failure == null) {
			EifPhoneRecorder.report("stopped", Long.toString(recordedSeconds()));
		} else {
			EifPhoneRecorder.report("failed", failure);
		}
		stopNow();
	}

	private void stopNow() {
		stopForeground(STOP_FOREGROUND_REMOVE);
		stopSelf();
	}

	private static void writeHeader(RandomAccessFile file, long data) throws IOException {
		byte[] h = new byte[HEADER];
		put(h, 0, "RIFF");
		little(h, 4, 4, data + HEADER - 8);
		put(h, 8, "WAVEfmt ");
		little(h, 16, 4, 16);
		little(h, 20, 2, 1);
		little(h, 22, 2, 1);
		little(h, 24, 4, RATE);
		little(h, 28, 4, RATE * 2);
		little(h, 32, 2, 2);
		little(h, 34, 2, 16);
		put(h, 36, "data");
		little(h, 40, 4, data);
		file.seek(0);
		file.write(h);
	}

	private static void put(byte[] to, int at, String text) {
		for (int i = 0; i < text.length(); i++) to[at + i] = (byte) text.charAt(i);
	}

	private static void little(byte[] to, int at, int count, long value) {
		for (int i = 0; i < count; i++) to[at + i] = (byte) (value >> (8 * i));
	}
}
