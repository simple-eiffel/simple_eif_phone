#!/usr/bin/env bash
# build_cairo.sh [abi ...]: builds cairo and what it needs (pixman, FreeType, libpng, zlib)
# as static libraries for Android, into $NATIVE/out/<abi>/. Run once; apps link the results.
# Needs: the NDK, Python with `pip install --target $NATIVE/tools meson ninja`, and cairo's source in $NATIVE/src.
set -u
NATIVE=${NATIVE:-/d/android/native}
NDK=${NDK:-/d/android/sdk/ndk/30.0.16248370}
CAIRO=${CAIRO:-cairo-1.18.6}
API=${API:-26}
BIN=$(cygpath -m "$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin")
export PYTHONPATH="$(cygpath -w "$NATIVE/tools")"
MESON="python -m mesonbuild.mesonmain"
export PATH="$NATIVE/tools/bin:$PATH"
export MSYS_NO_PATHCONV=1   # keep Git Bash from rewriting /sysroot

cross_file () {   # cross_file <abi> <clang triple> <cpu family> <cpu>
  cat > "$NATIVE/cross-$1.txt" <<EOF
[binaries]
c = '$BIN/clang.exe'
cpp = '$BIN/clang++.exe'
ar = '$BIN/llvm-ar.exe'
strip = '$BIN/llvm-strip.exe'
ranlib = '$BIN/llvm-ranlib.exe'

[built-in options]
c_args = ['--target=$2$API', '-fPIC', '-fno-sanitize=undefined']
cpp_args = ['--target=$2$API', '-fPIC']
c_link_args = ['--target=$2$API']
cpp_link_args = ['--target=$2$API']

[host_machine]
system = 'android'
cpu_family = '$3'
cpu = '$4'
endian = 'little'
EOF
}

build () {   # build <abi>
  local out="$NATIVE/out/$1" work="$NATIVE/build-$1"
  rm -rf "$work" "$out"
  cd "$NATIVE/src/$CAIRO" || exit 1
  $MESON setup "$(cygpath -m "$work")" --cross-file "$(cygpath -m "$NATIVE/cross-$1.txt")" \
    --prefix /sysroot --libdir lib --default-library=static --buildtype=release \
    --force-fallback-for=pixman,freetype2,libpng,zlib --wrap-mode=default \
    -Dtests=disabled -Dfontconfig=disabled -Dfreetype=enabled -Dpng=enabled -Dzlib=enabled \
    -Dxlib=disabled -Dxcb=disabled -Dglib=disabled -Dspectre=disabled -Dsymbol-lookup=disabled \
    -Dgtk_doc=false -Dlzo=disabled \
    -Dpixman:tests=disabled -Dpixman:demos=disabled -Dpixman:openmp=disabled -Dpixman:gtk=disabled -Dpixman:libpng=disabled \
    || return 1
  $MESON compile -C "$(cygpath -m "$work")" || return 1
  # The prefix is a path on Android, so the files land under $out/sysroot.
  $MESON install -C "$(cygpath -m "$work")" --no-rebuild --destdir "$(cygpath -m "$out")" || return 1
}

[ $# -eq 0 ] && set -- arm64-v8a x86_64
for abi in "$@"; do
  case $abi in
    arm64-v8a) cross_file arm64-v8a aarch64-linux-android aarch64 armv8-a ;;
    x86_64) cross_file x86_64 x86_64-linux-android x86_64 x86_64 ;;
    *) echo "unknown abi: $abi"; exit 2 ;;
  esac
  build "$abi" || { echo "FAILED: $abi"; exit 1; }
  echo "built $abi: $(ls "$NATIVE/out/$abi/sysroot/lib"/*.a 2>/dev/null | wc -l) libraries"
done
