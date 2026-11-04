#!/usr/bin/env bash
# drive.sh [serial]: plays the human for examples/phone_tests. It watches the log
# for "SEPHONE-TEST STEP <name>" and acts. Start it, then run: eifphone test .
ADB=/d/android/sdk/platform-tools/adb.exe
[ -n "${1:-}" ] && ADB="$ADB -s $1"
PKG=io.github.ljr1981.eifphone.tests/android.app.NativeActivity
$ADB logcat -c   # steps left in the log by an earlier run must not be replayed
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
      back) $ADB shell input keyevent 4 ;;
      exit) sleep 1; $ADB shell input keyevent 4; sleep 2; echo "driver done"; exit 0 ;;
    esac
  done
  sleep 0.5
done
echo "driver timed out"
