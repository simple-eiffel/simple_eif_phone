# Changelog

## [0.4.1] - 2026-11-04

### Fixed
- **`eifphone --help` and `--version` work.** The usage line promised `--help`, and it printed the usage line again.
- **The keyboard no longer covers a text box low on the screen.** `simple_widgets` slides its drawing up clear of the keyboard, and touches follow. `phone.keyboard.top` gives the keyboard's top edge.
- **Fonts under other names.** `android_shaping` tries Android's usual file, then a file named for the kind of font, then any file that really draws the script. A phone with no Hebrew font at all still shows boxes.
- Tested on Android 10 and 15, and on one real phone with Samsung's keyboard. Android 8 and 9 use the Android 10 path, untested.

## [0.4.0] - 2026-11-04

### Added
- **Android's own controls from Eiffel** (cluster `src/controls`, `controls = true`): label, button, text box, check box, switch, slider, progress bar, drop-down, radio group, list, scroll, column, row, canvas, image, toast, dialog, pop-up menu, date and time pickers.
- **Any other control, by name:** `PHONE_CONTROL.make_any`, with `call`, `ask` and `listen`. 26 more classes were made this way in testing.
- **`phone.run_controls`, `controls.set_on_back`, `PHONE_CONTROL.discard`, `PHONE_CONTROL.set_padding`.**
- **`examples/controls_demo`:** every control, a list of 31,000 rows, and drawing with a finger.
- **cairo for Android:** `runtime/native/build_cairo.sh` builds it and what it needs. `[native] libraries`, `$ABI` and `$EIFPHONE_NATIVE` link it. See `examples/cairo_draw`.
- **`simple_widgets` on the phone, unchanged** (cluster `android_shell`, `simple_widgets_android.ecf`). See `examples/widgets_demo` and `examples/widgets_7guis`.
- **`phone.keyboard`:** the phone's keyboard for screens that draw their own text boxes.
- **Hebrew, Greek and real fonts in `simple_widgets`** (cluster `android_shaping`, `window.enable_shaped_text`). HarfBuzz shapes, FriBidi orders, and fonts come from `/system/fonts`. `runtime/native/build_text.sh` builds both libraries. `simple_shaping`'s source is unchanged.

### Changed
- **Apps start in their own private folder,** so plain relative file names work. They used to start in `/`, which they cannot write.

### Known limitations
- This version has run on one real phone, without rotation or the list's fast-scroll thumb.
- Fonts in `simple_widgets` are found by file name, so a phone that names them differently shows boxes.
- Emoji in `simple_widgets` show as boxes: no emoji pictures are packed.
- Lines in `simple_widgets` break only after a space, hyphen or maqaf.

## [0.3.0] - 2026-11-04

### Added
- **Read-aloud:** `phone.speech` reads text aloud, Hebrew included if the engine has it. Needs `java_helper = true`.
- **File picker:** `phone.files` opens Android's picker. A chosen file arrives as a plain file in the app's cache.
- **Java answers Eiffel:** the helper's results arrive as ordinary events, through a locked mailbox in the C glue.
- **`examples/read_aloud`:** choose a text file and hear it.
- **Tests:** 6 more logic tests and 6 more on-device tests.

### Known limitations
- Read-aloud needs the language's voice on the phone. On the one real phone tried, Hebrew stayed silent, with a failure reported, until its voice was downloaded in the phone's text-to-speech settings.

## [0.2.0] - 2026-11-04

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
