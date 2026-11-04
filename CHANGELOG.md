# Changelog

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
- An `adb` that never answers hangs the tool: the runner has no timeout.
- `eifphone run` shows the first 3 seconds of the log; use `eifphone log` for the rest.
- On-device tests have run on the emulator only. One real ARM phone was checked by hand.
- Two one-off failures are unexplained: `tap_arrives` failed once after a stress session, and one stress run stopped on a crash from a process that was not identified. Both passed when repeated.
