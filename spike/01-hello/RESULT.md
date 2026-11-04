# Spike 01: hello APK. PASSED (2026-11-03)

**Question:** Can Eiffel source go all the way to an installed, running Android app using only gec + the NDK + Google's SDK tools?

**Answer:** Yes. It ran on the first build on the test phone (x86_64) AND on a real ARM phone. Rebuild with `./build.sh` (about a minute) to get `out/eif-hello.apk` (340 KB, signed with the spike debug key).

## What was proven (emulator `sbtest`, x86_64, Android 15)

| Check | Evidence |
|---|---|
| gec output compiles for Android unchanged | Both ABIs built with 0 compiler diagnostics. The generated C picks its platform at C-compile time, and nothing Windows-specific is baked in. |
| Eiffel starts inside the app | logcat: `EifPhone: android_main: starting Eiffel`, then `Eiffel: Hello from Eiffel: app started` |
| Eiffel draws the screen | `shots/01-start.png`. Text comes from an Eiffel 5x7 pixel font (`EP_PIXEL_FONT`) filled through `ep_fill`. |
| Touch input reaches Eiffel | `shots/02-three-taps.png`, plus "tap N" in the log |
| Background → resume keeps state | `shots/03-after-resume.png` (count 4 survived) |
| Back ends the Eiffel loop cleanly | `loop ended` → `Eiffel returned` → activity finished |
| Relaunch in the same process works | A second `GE_main` in pid 1963 on a new thread; fresh state, no crash |
| Boehm GC reclaims memory on Android | 20 taps × 500,000 strings = 10,000,000 strings, **983 collections, heap flat at 1 MB** (`shots/05-gc-20-taps.png`) |
| ARM library is right for phones | `llvm-readelf`: AArch64, LOAD align 0x4000 (16 KB), exports `ANativeActivity_onCreate` + `GE_main`; needs only libandroid/liblog/libm/libdl/libc |

## Not yet proven

- ~~Running on real ARM hardware~~ **PROVEN 2026-11-03:** on the real phone after 9 taps (4.5M strings) the heap was still 1 MB. His word: "Runs". His screenshot exposed a missing `B` glyph ("1 M" instead of "1 MB"), now fixed in source. J K Q V X Z are still not drawn; spike-only, since real text will come from the shaping stack.
- Rotation and other screen-size changes (`APP_CMD_CONFIG_CHANGED` is queued as a redraw; untested).
- Anything that needs the library: real text (cairo + shaping), the keyboard, files, SQLite, read-aloud.

## Lessons for the driver tool

- `gec --cc=no --finalize` writes `.gobo/<system>_N.c` and `<system>.h`. Boehm GC sources are `#include`d by absolute Windows path, which NDK clang on Windows accepts.
- Link flags: `-shared -u ANativeActivity_onCreate -Wl,-z,max-page-size=16384 -Wl,--no-undefined -landroid -llog -lm -ldl -pthread`.
- `aapt2 link` can't add native libraries; `aapt add` (v1, still in build-tools 36) can.
- `sdkmanager` package names contain `;`. Pass them with `--package_file=` from PowerShell, or the batch file splits them.
- Android keeps the process alive after Back, so `GE_main` can run twice in one process. It worked here, but the library must treat this as a contract, not luck.
