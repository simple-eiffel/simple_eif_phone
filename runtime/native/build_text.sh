#!/usr/bin/env bash
# build_text.sh [abi ...]: builds HarfBuzz and FriBidi as static libraries for Android,
# into $NATIVE/out/<abi>/sysroot, beside cairo. Run build_cairo.sh first. Run once.
# Needs their source in $NATIVE/src. Together they give simple_shaping shaping and
# right-to-left text on the phone.
set -u
NATIVE=${NATIVE:-/d/android/native}
HARFBUZZ=${HARFBUZZ:-harfbuzz-10.1.0}
FRIBIDI=${FRIBIDI:-fribidi-1.0.16}
export PYTHONPATH="$(cygpath -w "$NATIVE/tools")"
MESON="python -m mesonbuild.mesonmain"
export PATH="$NATIVE/tools/bin:$PATH"
export MSYS_NO_PATHCONV=1   # keep Git Bash from rewriting /sysroot

one () {   # one <abi> <source folder> <meson options...>
  local abi=$1 src=$2 work="$NATIVE/build-$2-$1" out="$NATIVE/out/$1"
  shift 2
  rm -rf "$work"
  cd "$NATIVE/src/$src" || exit 1
  $MESON setup "$(cygpath -m "$work")" --cross-file "$(cygpath -m "$NATIVE/cross-$abi.txt")" \
    --prefix /sysroot --libdir lib --default-library=static --buildtype=release "$@" || return 1
  $MESON compile -C "$(cygpath -m "$work")" || return 1
  $MESON install -C "$(cygpath -m "$work")" --no-rebuild --destdir "$(cygpath -m "$out")" || return 1
}

[ $# -eq 0 ] && set -- arm64-v8a x86_64
for abi in "$@"; do
  one "$abi" "$FRIBIDI" -Ddocs=false -Dbin=false -Dtests=false || { echo "FAILED: fribidi $abi"; exit 1; }
  one "$abi" "$HARFBUZZ" -Dtests=disabled -Dbenchmark=disabled -Ddocs=disabled -Dutilities=disabled \
    -Dglib=disabled -Dgobject=disabled -Dicu=disabled -Dfreetype=disabled -Dcairo=disabled -Dchafa=disabled \
    -Dintrospection=disabled || { echo "FAILED: harfbuzz $abi"; exit 1; }
  echo "built $abi: $(ls "$NATIVE/out/$abi/sysroot/lib"/*.a 2>/dev/null | wc -l) libraries in all"
done
