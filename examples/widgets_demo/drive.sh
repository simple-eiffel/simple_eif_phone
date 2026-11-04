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
check "pointed Hebrew shapes right to left, nothing missing" "shaped hebrew rtl True whole True notes 0"
check "polytonic Greek shapes, nothing missing" "shaped greek rtl False whole True notes 0"
check "a picture character is reported, not a crash" "note emoji 2"
check "Hebrew wraps in a narrow space" "wrapped lines [2-9] whole True"
check "a Hebrew font is found by its name" "fonts named hebrew True"
check "a Hebrew font is found by what it draws" "fonts plain hebrew True"
check "no Hebrew font is reported, not a crash" "fonts none hebrew False latin True"
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
# Hebrew on the emulator's own keyboard. `input text' can only send plain letters, so
# this taps the keys. The positions are this emulator's: 1080 by 2400, keyboard shown.
KEYBOARD=$($ADB shell settings get secure selected_input_method_subtype | tr -d '\r')
$ADB shell settings put secure selected_input_method_subtype 1727731901
set -- $(pos box); $ADB shell input tap $1 $2
sleep 3
for key in "54 1854" "810 1854" "702 1686" "918 1686"; do $ADB shell input tap $key; sleep 1; done
check "Hebrew letters from the keyboard arrive in order" "last letter 1501"
check "all four of them" "box holds 8 letters"
shot w_hebrew_typed
set -- $(pos check); $ADB shell input tap $1 $2
sleep 2
$ADB shell settings put secure selected_input_method_subtype -- "$KEYBOARD"
set -- $(pos list); $ADB shell input tap $1 $2
check "a tap selects a row" "row "
shot w_row
L=$(pos list); set -- $L
X=$1; set -- $(pos box)
$ADB shell input swipe $X 1800 $X $2 300; sleep 1
shot w_scrolled
check "a swipe scrolls the list" "first row [1-9]"
if $ADB shell dumpsys input_method | grep -q "mInputShown=false"; then echo "PASS a swipe that ends on a text box brings up no keyboard"; pass=$((pass + 1)); else echo "FAIL a swipe that ends on a text box brings up no keyboard"; fail=$((fail + 1)); fi
set -- $(pos box); $ADB shell input tap $1 $2
sleep 2
$ADB shell input keyevent 4; sleep 2
if $ADB shell dumpsys window | grep mCurrentFocus | grep -q PopupWindow; then echo "FAIL one Back closes the keyboard and its popup"; fail=$((fail + 1)); elif $ADB shell dumpsys input_method | grep -q "mInputShown=true"; then echo "FAIL one Back closes the keyboard and its popup"; fail=$((fail + 1)); elif $ADB shell pidof $PKG > /dev/null; then echo "PASS one Back closes the keyboard and its popup"; pass=$((pass + 1)); else echo "FAIL one Back closes the keyboard and its popup"; fail=$((fail + 1)); fi
# A text box low on the screen: the keyboard must not cover it.
set -- $(pos low); LOW_X=$1; LOW_Y=$2
$ADB shell input tap $LOW_X $LOW_Y
sleep 3
check "the drawing slides up clear of the keyboard" "keyboard top [1-9][0-9]* pan [1-9]"
shot w_low_box
line=$($ADB logcat -d -s Eiffel:* | grep "widgets: keyboard top" | tail -1 | sed "s/.*keyboard top //")
TOP=${line%% *}; PAN=${line##* }
if [ "$((LOW_Y - PAN))" -lt "$TOP" ]; then echo "PASS the low box stands above the keyboard ($((LOW_Y - PAN)) above $TOP)"; pass=$((pass + 1)); else echo "FAIL the low box is under the keyboard ($((LOW_Y - PAN)) against $TOP)"; fail=$((fail + 1)); fi
$ADB shell input text 'low'
check "typing reaches the low box" "low box holds 3 letters"
rows=$($ADB logcat -d -s Eiffel:* | grep -c "widgets: row ")
set -- $(pos list); $ADB shell input tap $1 $(($2 - PAN)); sleep 2
if [ "$($ADB logcat -d -s Eiffel:* | grep -c "widgets: row ")" -gt "$rows" ]; then echo "PASS a tap lands true while the drawing is slid up"; pass=$((pass + 1)); else echo "FAIL a tap lands true while the drawing is slid up"; fail=$((fail + 1)); fi
check "the drawing comes back" "keyboard top 0 pan 0"
$ADB shell input keyevent 3; sleep 2
$ADB shell am start -n $PKG/io.github.simple_eiffel.eifphone.EifPhoneActivity > /dev/null; sleep 3
shot w_back
if $ADB shell pidof $PKG > /dev/null; then echo "PASS survives leaving and returning"; pass=$((pass + 1)); else echo "FAIL survives leaving and returning"; fail=$((fail + 1)); fi
$ADB shell input keyevent 4; sleep 3
if $ADB shell pidof $PKG > /dev/null 2>&1; then echo "FAIL Back ends the process"; fail=$((fail + 1)); else echo "PASS Back ends the process"; pass=$((pass + 1)); fi
if $ADB logcat -d | grep -E "system execution failed|Fatal signal" > /dev/null; then echo "FAIL no crash in the log"; fail=$((fail + 1)); $ADB logcat -d | grep -E "EiffelOut" | grep -v glBind | head -12 | cut -c30-120; else echo "PASS no crash in the log"; pass=$((pass + 1)); fi
echo "passed $pass, failed $fail"
