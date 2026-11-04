#!/usr/bin/env bash
# drive.sh [serial]: plays the human for examples/phone_tests. It watches the log
# for "SEPHONE-TEST STEP <name>" and acts. Start it, then run: eifphone test .
export MSYS_NO_PATHCONV=1   # keep Git Bash from rewriting /sdcard paths
ADB=/d/android/sdk/platform-tools/adb.exe
[ -n "${1:-}" ] && ADB="$ADB -s $1"
PKG=io.github.ljr1981.eifphone.tests/io.github.simple_eiffel.eifphone.EifPhoneActivity
PICK=eifphone_pick.txt
$ADB logcat -c   # steps left in the log by an earlier run must not be replayed
printf 'eifphone pick test\n' > "${TMP:-/tmp}/$PICK"
$ADB push "$(cygpath -w "${TMP:-/tmp}/$PICK")" /sdcard/Download/$PICK > /dev/null
$ADB shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/$PICK > /dev/null
tap_text () {   # tap the on-screen item showing $1; returns 1 if it is not there
  $ADB shell uiautomator dump /sdcard/eifphone_ui.xml > /dev/null 2>&1
  b=$($ADB shell cat /sdcard/eifphone_ui.xml | tr '>' '\n' | grep "text=\"$1\"" | grep -o 'bounds="[^"]*"' | head -1 | grep -o '[0-9]*' | tr '\n' ' ')
  [ -z "$b" ] && return 1
  set -- $b
  $ADB shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}
done_steps=""
rotate () { $ADB shell settings put system accelerometer_rotation 0; $ADB shell settings put system user_rotation "$1"; }
for i in $(seq 1 600); do
  steps=$($ADB logcat -d -s Eiffel:* 2>/dev/null | grep -o 'SEPHONE-TEST STEP [a-z]*' | awk '{print $3}')
  for s in $steps; do
    case " $done_steps " in *" $s "*) continue ;; esac
    done_steps="$done_steps $s"
    echo "step: $s"
    case $s in
      tap) $ADB shell input tap 540 1200 ;;
      home) $ADB shell input keyevent 3; sleep 2; $ADB shell am start -n $PKG >/dev/null ;;
      rotate) rotate 1 ;;
      unrotate) rotate 0 ;;
      storm)
        for n in 1 2 3; do
          rotate 1; sleep 0.3; rotate 0; sleep 0.3
          $ADB shell input keyevent 3; $ADB shell am start -n $PKG >/dev/null; sleep 0.5
        done ;;
      pickcancel) sleep 3; $ADB shell input keyevent 4 ;;
      pickchoose)
        sleep 3
        tap_text "$PICK" || { $ADB shell input keyevent 4; echo "pick: file not on screen"; } ;;
      back) $ADB shell input keyevent 4 ;;
      exit) sleep 1; $ADB shell input keyevent 4; sleep 2; echo "driver done"; exit 0 ;;
    esac
  done
  sleep 0.5
done
echo "driver timed out"
