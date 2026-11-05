# simple_eif_phone

[Documentation](https://simple-eiffel.github.io/simple_eif_phone/) •
[GitHub](https://github.com/simple-eiffel/simple_eif_phone) •
[Issues](https://github.com/simple-eiffel/simple_eif_phone/issues)

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Android 8.0+](https://img.shields.io/badge/Android-8.0%2B-green.svg)
![DBC: Contracts](https://img.shields.io/badge/DBC-Contracts-green.svg)

Write an Android app in Eiffel, and get a signed APK from one command. No Gradle, no Android Studio.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

**0.4.1: early, working, not yet widely used.**

- 103 tool tests, 60 logic tests and 27 on-device tests pass, with zero warnings. On-device tests ran on the emulator.
- Android's own controls, and `simple_widgets` drawn by cairo, have run on the emulator and on one real phone.
- On a real ARM phone, the touch pad demo took five fingers at once, and a full screen went up in 6.5 ms at worst.
- The tool runs on Windows. Apps run on Android 8.0 or later, on ARM64 and x86_64.
- See [known limitations](https://simple-eiffel.github.io/simple_eif_phone/#limits) before you rely on it.

## Quick start

```
eifphone doctor                                       # are all the tools there?
eifphone new myapp --id io.github.me.myapp --label "My App"
eifphone build myapp                                  # signed APK in myapp/build/
eifphone run myapp                                    # install on the device, start, show the log
```

The app you write owns its own loop:

```eiffel
create phone.make
from until phone.lifecycle.is_destroyed loop
	phone.wait_for_event
	inspect phone.last_event.kind
	when Kind_window_ready, Kind_redraw_needed then draw
	else
	end
end
```

For complete documentation, see [the docs site](https://simple-eiffel.github.io/simple_eif_phone/).

## Features

- One command from Eiffel source to a signed, aligned APK, for both processor types
- The phone in phone terms: app life, multi-touch, keys, screen, sizes, folders, packed files, log
- SQLite on the phone through `simple_sql`, full-text search included
- Read-aloud and the file picker, Hebrew included, through a small fixed Java helper
- Android's own controls from Eiffel: buttons, text boxes with the phone's keyboard, lists of any length, dialogs and pickers, and any other control by name
- `simple_cairo` and `simple_widgets` on the phone, unchanged, through the `android_shell` cluster, including its 7GUIs benchmark
- Hebrew, Greek and real fonts in `simple_widgets`, through HarfBuzz and FriBidi
- Contracts throughout, with a fast build for live drawing and a checked build for development
- On-device test runner, and clear errors that name the failed stage

For details, see the [User Guide](https://simple-eiffel.github.io/simple_eif_phone/user-guide.html).

## Installation

Build the `eifphone` tool from `tool/eifphone.ecf`, then run `eifphone doctor`. New projects get this line in their ECF:

```xml
<library name="simple_eif_phone" location="$SIMPLE_EIFFEL/simple_eif_phone/simple_eif_phone.ecf"/>
```

Requires `simple_mml` 1.0.3 or later, Gobo gec 26.10, and Android NDK 30.0.16248370.

## License

MIT License. See the LICENSE file.

## Support

- **Docs:** https://simple-eiffel.github.io/simple_eif_phone/
- **GitHub:** https://github.com/simple-eiffel/simple_eif_phone
- **Issues:** https://github.com/simple-eiffel/simple_eif_phone/issues
