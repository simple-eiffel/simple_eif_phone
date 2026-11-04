#!/usr/bin/env bash
# drive.sh <shots-folder> [serial]: plays the human for examples/controls_demo on an
# emulator: taps real Android controls found by their text, types, swipes, and checks
# what the Eiffel side logged. Prints PASS or FAIL for each step.
export MSYS_NO_PATHCONV=1
SHOTS=${1:-shots}
ADB=/d/android/sdk/platform-tools/adb.exe
[ -n "${2:-}" ] && ADB="$ADB -s $2"
PKG=io.github.ljr1981.eifphone.controls
ACT=$PKG/io.github.simple_eiffel.eifphone.EifPhoneControlsActivity
mkdir -p "$SHOTS"
pass=0; fail=0

ui () {   # the screen's control tree, one element per line
  $ADB shell uiautomator dump /sdcard/eifphone_ui.xml > /dev/null 2>&1
  $ADB shell cat /sdcard/eifphone_ui.xml | tr '>' '\n'
}
centre () {   # centre of the first element matching $1
  b=$(ui | grep -- "$1" | grep -o 'bounds="[^"]*"' | head -1 | grep -o '[0-9]*' | tr '\n' ' ')
  [ -z "$b" ] && return 1
  set -- $b
  echo "$(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))"
}
tap () {   # tap the element showing text $1
  c=$(centre "text=\"$1\"") || { echo "  (not on screen: $1)"; return 1; }
  $ADB shell input tap $c
  sleep 1
}
scroll_to () {   # swipe up until text $1 is on screen
  for n in 1 2 3 4 5 6; do
    ui | grep -q -- "text=\"$1\"" && return 0
    $ADB shell input swipe 500 1500 500 800 400
    sleep 0.7
  done
  return 1
}
said () {   # did Eiffel log $1?
  $ADB logcat -d -s Eiffel:* 2>/dev/null | grep -q -- "controls: $1"
}
check () {   # check <name> <text Eiffel should have logged>
  sleep 0.6
  if said "$2"; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1 (no: $2)"; fail=$((fail + 1)); fi
}
seen () {   # seen <name> <pattern on screen>
  if ui | grep -q -- "$2"; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1 (not on screen: $2)"; fail=$((fail + 1)); fi
}
shot () { $ADB exec-out screencap -p > "$SHOTS/$1.png"; }

$ADB shell am force-stop $PKG
$ADB logcat -c
$ADB shell am start -n $ACT > /dev/null
sleep 4
check "app starts and shows controls" "shown"
check "a wrong method is reported" "failure noSuchMethod"
check "a wrong class is reported" "failure android.widget.NoSuchWidget"
check "a missing picture is reported" "failure not_there.png"
seen "real Android button" 'class="android.widget.Button"'
seen "real Android text box" 'class="android.widget.EditText"'
seen "real Android rating bar (general route)" 'class="android.widget.RatingBar"'
shot form

c=$(centre 'class="android.widget.EditText"')
$ADB shell input tap $c; sleep 1
$ADB shell input text 'hello'
check "typing reaches Eiffel" "typed 5 letters"
seen "Eiffel answers on screen" 'text="You typed: hello"'
shot typing
$ADB shell input keyevent 4; sleep 1   # closes the keyboard

tap "Round trip"; check "Hebrew and emoji through a real control" "round trip same True"
tap "Show a toast"; check "button click and toast" "toast"
tap "Ask a question"; sleep 1; shot dialog
tap "[Yy][Ee][Ss]"; check "dialog answer" "answer True"
tap "Pick a date"; sleep 1; shot date
tap "OK"; check "date picker" "date \[2026-11-4\]"
tap "Pick a time"; sleep 1; shot time
tap "OK"; check "time picker" "time \[9:30\]"
scroll_to "A check box"
tap "A check box"; check "check box" "check True"
scroll_to "A switch"
tap "A switch"; check "switch" "switch True"
scroll_to "Option B"
c=$(centre 'class="android.widget.SeekBar"')
$ADB shell input tap $c; check "slider" "slider "
tap "First choice"; sleep 1; shot choice
tap "Third choice"; check "drop-down choice" "choice 3"
tap "Option B"; check "radio button" "radio 2"
scroll_to "NO-SUCH-TEXT"
c=$(centre 'class="android.widget.RatingBar"')
$ADB shell input tap $c; check "rating bar listener (general route)" "stars onRatingChanged"
check "asking Android for a value (general route)" "rating "
shot form_end
seen "a picture from the app's assets" 'class="android.widget.ImageView"'
tap "Open a menu"; sleep 1; shot menu
tap "Second item"; check "pop-up menu" "menu 2"
tap "Order storm"; check "40,000 orders sent" "storm sent"
sleep 6
scroll_to "NO-SUCH-TEXT"
$ADB shell input swipe 500 500 500 1700 200; sleep 1
seen "Android kept up with the storm" 'text="Storm over"'
tap "A switch"; check "still answers after the storm" "switch False"

$ADB shell input swipe 500 500 500 1700 200; $ADB shell input swipe 500 500 500 1700 200; sleep 1
tap "List"; check "change screen" "screen list"
sleep 1
seen "list shows row 1" 'text="Row 1 '
shot list
for n in 1 2 3 4 5 6 7 8; do $ADB shell input swipe 500 1800 500 300 120; done
sleep 1.5
b=$(ui | grep -c 'text="Row ')
echo "  rows on screen after scrolling: $b"
shot list_scrolled
r=$(ui | grep -o 'text="Row [0-9]*' | head -1 | grep -o '[0-9]*')
echo "  first row on screen: $r"
if [ -n "$r" ] && [ "$r" -gt 5 ]; then echo "PASS list scrolls and fills in"; pass=$((pass + 1)); else echo "FAIL list scrolls"; fail=$((fail + 1)); fi
tap "Row $r  $(ui | grep -o "text=\"Row $r [^\"]*" | head -1 | sed "s/text=\"Row $r  //")"
check "tapping a row" "row $r"

$ADB shell input swipe 500 1800 500 1200 150; sleep 0.3
$ADB shell input swipe 1065 700 1065 2230 900   # the fast-scroll thumb, to the bottom
sleep 3
seen "list reaches its last row" 'text="Row 31000 '
shot list_end
$ADB shell input keyevent 4; check "Back returns to the form" "screen form"
tap "List"; sleep 1
tap "Draw"; check "drawing screen" "screen draw"
sleep 1
$ADB shell input swipe 200 900 900 1500 500
sleep 1
check "finger on canvas" "release, "
shot draw

tap "More"; check "gallery of other controls" "gallery built, 26 classes"
sleep 2
if said "failure android"; then
  n=$($ADB logcat -d -s Eiffel:* | grep -c "failure android")
  echo "  classes refused: $n (one is expected: the demo's deliberate wrong name)"
  $ADB logcat -d -s Eiffel:* | grep "failure android" | cut -c30-
fi
shot more
for n in 1 2 3 4 5 6 7 8; do $ADB shell input swipe 500 500 500 1800 250; done   # back to the top
sleep 1
found=""
for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do
  found="$found $(ui | grep -o 'class="[^"]*"' | sort -u | tr '\n' ' ')"
  $ADB shell input swipe 500 1700 500 1100 1200
  sleep 0.4
done
for w in ToggleButton ImageButton ImageView CalendarView DatePicker TimePicker NumberPicker Chronometer AutoCompleteTextView; do
  if echo "$found" | grep -q "android.widget.$w\""; then echo "PASS $w on screen"; pass=$((pass + 1)); else echo "FAIL $w not on screen"; fail=$((fail + 1)); fi
done
shot more_scrolled
tap "Form"; sleep 1
$ADB shell settings put system accelerometer_rotation 0
$ADB shell settings put system user_rotation 1
sleep 3
shot rotated
$ADB shell settings put system user_rotation 0
sleep 3
tap "Form"; check "survives rotation" "screen form"
$ADB shell input keyevent 3; sleep 2
$ADB shell am start -n $ACT > /dev/null; sleep 3
seen "survives leaving and returning" 'class="android.widget.Button"'
$ADB shell input keyevent 4; sleep 3
if $ADB shell pidof $PKG > /dev/null 2>&1; then echo "FAIL Back ends the process"; fail=$((fail + 1)); else echo "PASS Back ends the process"; pass=$((pass + 1)); fi
if $ADB logcat -d | grep -E "FATAL EXCEPTION|F DEBUG|Fatal signal" > /dev/null; then echo "FAIL no crash in the log"; fail=$((fail + 1)); else echo "PASS no crash in the log"; pass=$((pass + 1)); fi
echo "passed $pass, failed $fail"
