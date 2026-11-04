#!/usr/bin/env bash
# drive.sh <shots-folder> [serial]: plays the human for examples/widgets_demo on an emulator.
# simple_widgets draws its own controls, so Android sees one surface: taps go by position.
export MSYS_NO_PATHCONV=1
SHOTS=${1:-shots}
ADB=/d/android/sdk/platform-tools/adb.exe
[ -n "${2:-}" ] && ADB="$ADB -s $2"
PKG=io.github.ljr1981.eifphone.widgets
mkdir -p "$SHOTS"
pass=0; fail=0
said () { $ADB logcat -d -s Eiffel:* 2>/dev/null | grep -q -- "widgets: $1"; }
check () { sleep 0.8; if said "$2"; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1 (no: $2)"; fail=$((fail + 1)); fi; }
shot () { $ADB exec-out screencap -p > "$SHOTS/$1.png"; }
pos () { $ADB logcat -d -s Eiffel:* | grep "widgets: at $1 " | tail -1 | sed "s/.*widgets: at $1 //"; }

$ADB shell am force-stop $PKG
$ADB logcat -c
$ADB shell am start -n $PKG/io.github.simple_eiffel.eifphone.EifPhoneActivity > /dev/null
sleep 5
check "app starts" "starting"
check "the first frame reaches the screen" "frame "
shot w_first
set -- $(pos button); $ADB shell input tap $1 $2
check "a tap reaches a button" "tapped 1"
sleep 0.5
$ADB shell input tap $1 $2
check "a second tap" "tapped 2"
shot w_tapped
set -- $(pos check); $ADB shell input tap $1 $2
check "a tap reaches a check box" "checked True"
set -- $(pos box); $ADB shell input tap $1 $2
sleep 2
if $ADB shell dumpsys input_method | grep -q "mInputShown=true"; then echo "PASS the keyboard comes up"; pass=$((pass + 1)); else echo "FAIL the keyboard comes up"; fail=$((fail + 1)); fi
shot w_keyboard
$ADB shell input text 'hello'
check "the phone's keyboard types into a drawn text box" "box holds 5 letters"
$ADB shell input keyevent 67
check "backspace" "box holds 4 letters"
shot w_typed
set -- $(pos check); $ADB shell input tap $1 $2
sleep 2
if $ADB shell dumpsys input_method | grep -q "mInputShown=false"; then echo "PASS leaving the text box puts the keyboard away"; pass=$((pass + 1)); else echo "FAIL leaving the text box puts the keyboard away"; fail=$((fail + 1)); fi
set -- $(pos list); $ADB shell input tap $1 $2
check "a tap selects a row" "row "
shot w_row
L=$(pos list); set -- $L
$ADB shell input swipe $1 1800 $1 700 300; sleep 1
shot w_scrolled
check "a swipe scrolls the list" "first row [1-9]"
$ADB shell input keyevent 3; sleep 2
$ADB shell am start -n $PKG/io.github.simple_eiffel.eifphone.EifPhoneActivity > /dev/null; sleep 3
shot w_back
if $ADB shell pidof $PKG > /dev/null; then echo "PASS survives leaving and returning"; pass=$((pass + 1)); else echo "FAIL survives leaving and returning"; fail=$((fail + 1)); fi
$ADB shell input keyevent 4; sleep 3
if $ADB shell pidof $PKG > /dev/null 2>&1; then echo "FAIL Back ends the process"; fail=$((fail + 1)); else echo "PASS Back ends the process"; pass=$((pass + 1)); fi
if $ADB logcat -d | grep -E "system execution failed|Fatal signal" > /dev/null; then echo "FAIL no crash in the log"; fail=$((fail + 1)); $ADB logcat -d | grep -E "EiffelOut" | grep -v glBind | head -12 | cut -c30-120; else echo "PASS no crash in the log"; pass=$((pass + 1)); fi
echo "passed $pass, failed $fail"
