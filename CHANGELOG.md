# Changelog

## [0.4.0] - unreleased

### Added
- **Android's own controls from Eiffel** (cluster `src/controls`, `controls = true`): label, button, text box, check box, switch, slider, progress bar, drop-down, radio group, list, scroll, column, row, canvas, toast, dialog, date and time pickers.
- **Any other control, by name:** `PHONE_CONTROL.make_any`, with `call`, `ask` and `listen`. 26 more classes were made this way in testing.
- **`phone.run_controls`, `controls.set_on_back`, `PHONE_CONTROL.discard`.**
- **`examples/controls_demo`:** every control, a list of 31,000 rows, and drawing with a finger.
- **cairo for Android:** `runtime/native/build_cairo.sh` builds it and what it needs. `[native] libraries`, `$ABI` and `$EIFPHONE_NATIVE` link it. See `examples/cairo_draw`.
- **`simple_widgets` on the phone, unchanged** (cluster `android_shell`, `simple_widgets_android.ecf`). See `examples/widgets_demo`.

### Changed
- **Apps start in their own private folder,** so plain relative file names work. They used to start in `/`, which they cannot write.

### Known limitations
- Nothing in this version has run on a real phone yet.
- `simple_widgets` on the phone has no Hebrew and no keyboard yet.

## [0.3.0] - unreleased

### Added
- **Read-aloud:** `phone.speech` reads text aloud, Hebrew included if the engine has it. Needs `java_helper = true`.
- **File picker:** `phone.files` opens Android's picker. A chosen file arrives as a plain file in the app's cache.
- **Java answers Eiffel:** the helper's results arrive as ordinary events, through a locked mailbox in the C glue.
- **`examples/read_aloud`:** choose a text file and hear it.
- **Tests:** 6 more logic tests and 6 more on-device tests.

### Known limitations
- Read-aloud has only run on the emulator, which has no sound. The engine ran each sentence to its end, but nobody has heard it yet.

## [0.2.0] - unreleased

### Added
- **SQLite on the phone:** `simple_sql` runs unchanged, full-text search and Hebrew text included.
- **`[native]` in `eifphone.toml`:** a project can name extra C sources, include folders and defines. Each is checked when the project loads.
- **Touch pad:** saves strokes in a SQLite database, and brings in the save file of earlier versions.
- **On-device tests:** three more, for SQLite. Total 21.

### Fixed
- **Old generated C is cleared before each build:** a target that generates fewer files could otherwise compile leftovers from the last one.
- **A silent `adb` no longer hangs the tool:** it is ended after 5 minutes, and the tool exits with code 5. `EIFPHONE_ADB_SECONDS` sets a different limit.

## [0.1.0] - 2026-11-04

### Added
- **`eifphone` tool:** doctor, new, build, install, run, log, test. Builds without Gradle, compiles only changed C, and reports each stage's first error.
- **`simple_eif_phone` library:**
  - pulled event queue;
  - app-life and touch models with contracts;
  - frames, including ARGB32 present;
  - metrics with system-bar insets;
  - storage, assets, log, Back policy, keep-screen-on, clean process end.
- **Runtime:** C glue (`sephone_`) and the Java helper scaffold.
- **Examples:** hello, touch_pad, phone_tests (18 on-device tests), java_scaffold, touch_bench (speed measures).
- **Icons:** `[app] icon` now reaches the APK; a missing icon file is a settings error.
- **`[signing] debug_keystore`:** keeps a project's debug key elsewhere.
- **Devices not ready:** the tool names them, for example a phone that has not allowed this PC.
- **Two kinds of build:** `eifphone new` writes `app` (contracts on) and `app_fast` (contracts off).

### Fixed
- **Touch pad lag on a real phone:** contract checks ran per pixel and per touch, and each one made a system call on Android. `runtime/c/sephone_fastjmp.h` removes the system call from every phone build; the pad now ships with contracts off. A stroke segment went from 17 ms to 6 microseconds on the emulator.
- **Two Eiffel systems in one process:** a quick relaunch while the app was ending aborted in the garbage collector. The first main now owns the process, and a later one ends it for a fresh start. Every app gets this.
- **Process end:** uses `_exit`, avoiding a race with Android's own threads.
- **Empty files:** an empty `eifphone.toml`, save file or hash file no longer crashes anything.
- **Tool errors:** an unexpected failure now ends in one line, never a stack trace.
- **Labels:** a label may start with `@` or `?`.
- **hello:** the text no longer overlaps in landscape.
- **Touch pad:** full redraw only when the window size changes; at most 64 events between frames.

### Known limitations
- The tool runs on Windows only. Threads and SCOOP are not supported on the phone yet.
- `eifphone run` shows the first 3 seconds of the log; use `eifphone log` for the rest.
- On-device tests have run on the emulator only. One real ARM phone was checked by hand.
- Two one-off failures are unexplained: `tap_arrives` failed once after a stress session, and one stress run stopped on a crash from a process that was not identified. Both passed when repeated.
