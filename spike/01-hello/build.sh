#!/usr/bin/env bash
# Spike 01 build: Eiffel -> C (gec) -> libhello.so per ABI (NDK clang) -> APK -> align -> sign.
# Usage: ./build.sh            (from any folder)
# Output: out/eif-hello.apk
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# --- Tools -------------------------------------------------------------------
GEC=/d/prod/gobo-26.10/gobo/bin/gec.exe
NDK=/d/android/sdk/ndk/30.0.16248370
CLANG=$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe
GLUE=$NDK/sources/android/native_app_glue
BT=/d/android/sdk/build-tools/36.0.0
ANDROID_JAR=/d/android/sdk/platforms/android-36/android.jar
KEYTOOL=/d/android/jdk/bin/keytool.exe
KS=/d/android/keys/eifphone-debug.jks
API=26
LIB=hello

export ISE_EIFFEL='C:\Program Files\Eiffel Software\EiffelStudio 25.02 Standard'
export ISE_LIBRARY="$ISE_EIFFEL"
export ISE_PLATFORM=win64
export GOBO_LIBRARY='D:\prod\simple_gobo\library'
export GOBO_EIFFEL=ise
unset GOBO || true
export JAVA_HOME='D:\android\jdk'

rm -rf gen out
mkdir -p gen out/obj out/apk/lib

# --- 1. Eiffel -> C ----------------------------------------------------------
echo "[1/5] gec: Eiffel -> C"
( cd gen && "$GEC" --cc=no --finalize ../hello.ecf > ../out/gec.log 2>&1 ) || { tail -40 out/gec.log; exit 1; }
CDIR=gen/.gobo
ls $CDIR/*.c >/dev/null

# --- 2. C -> one shared library per ABI --------------------------------------
CFLAGS="-fPIC -O2 -DNDEBUG -pthread -fno-strict-aliasing -fno-sanitize=undefined \
 -Wno-unused-value -Wno-tautological-compare -Wno-absolute-value -Wno-void-pointer-to-int-cast \
 -Wno-deprecated-declarations -Wno-deprecated-non-prototype -Wno-unused-command-line-argument \
 -Wno-incompatible-pointer-types -Wno-int-conversion \
 -I$CDIR -Iclib -I$GLUE -I/d/prod/gobo-26.10/gobo/tool/gec/backend/c/boehm_gc/include"
for pair in arm64-v8a:aarch64-linux-android x86_64:x86_64-linux-android; do
  abi=${pair%%:*}; triple=${pair##*:}
  echo "[2/5] clang: $abi"
  od=out/obj/$abi; mkdir -p $od out/apk/lib/$abi
  for c in $CDIR/*.c clib/eif_phone_glue.c $GLUE/android_native_app_glue.c; do
    "$CLANG" --target=$triple$API $CFLAGS -c "$c" -o "$od/$(basename "${c%.c}").o" 2>> out/clang-$abi.log \
      || { echo "compile failed: $c"; tail -30 out/clang-$abi.log; exit 1; }
  done
  "$CLANG" --target=$triple$API -shared -o out/apk/lib/$abi/lib$LIB.so $od/*.o \
    -u ANativeActivity_onCreate -Wl,-z,max-page-size=16384 -Wl,--no-undefined \
    -landroid -llog -lm -ldl -pthread 2>> out/clang-$abi.log \
    || { echo "link failed: $abi"; tail -30 out/clang-$abi.log; exit 1; }
  ls -la out/apk/lib/$abi/lib$LIB.so
done

# --- 3. Package ---------------------------------------------------------------
echo "[3/5] aapt2 link + add native libraries"
"$BT/aapt2.exe" link -o out/unsigned.apk --manifest AndroidManifest.xml -I "$ANDROID_JAR" \
  --min-sdk-version $API --target-sdk-version 36
( cd out/apk && "$BT/aapt.exe" add ../unsigned.apk lib/arm64-v8a/lib$LIB.so lib/x86_64/lib$LIB.so >/dev/null )

# --- 4. Align (16 KB pages for native libraries) -------------------------------
echo "[4/5] zipalign"
"$BT/zipalign.exe" -P 16 -f 4 out/unsigned.apk out/aligned.apk

# --- 5. Sign -------------------------------------------------------------------
echo "[5/5] apksigner"
if [ ! -f "$KS" ]; then
  "$KEYTOOL" -genkeypair -keystore "$(cygpath -w "$KS")" -storepass eifphone -keypass eifphone \
    -alias eifphone -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=simple_eif_phone debug" >/dev/null 2>&1
fi
/c/Windows/System32/cmd.exe //c "$(cygpath -w "$BT/apksigner.bat")" sign --ks "$(cygpath -w "$KS")" --ks-pass pass:eifphone \
  --out "$(cygpath -w out/eif-hello.apk)" "$(cygpath -w out/aligned.apk)"
/c/Windows/System32/cmd.exe //c "$(cygpath -w "$BT/apksigner.bat")" verify "$(cygpath -w out/eif-hello.apk)" && echo "signed OK"
ls -la out/eif-hello.apk
