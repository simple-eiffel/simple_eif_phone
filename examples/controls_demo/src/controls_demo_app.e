note
	description: "[
		Android's own controls, driven from Eiffel. Three screens: a form with
		every control that has a class of its own, a list of 31,000 rows, and a
		drawing area. The stars show the general route, which reaches a control
		that has no class here. Each thing the user does is logged, for the tests.
	]"
	author: "Larry Rix"

class
	CONTROLS_DEMO_APP

create
	make

feature {NONE} -- Initialization

	make
		do
			create phone.make
			phone.log.set_tag ("Eiffel")
			create strokes.make (64)
			controls := phone.controls
			create form.make (controls)
			create rows_screen.make (controls)
			create draw_screen.make (controls)
			create more_screen.make (controls)
			create typed.make (controls, {STRING_32} "Nothing typed yet")
			create slider_value.make (controls, {STRING_32} "Slider: 0")
			create progress.make (controls, 100)
			create chosen_row.make (controls, {STRING_32} "No row tapped")
			create canvas.make (controls)
			create stars.make_any (controls, "android.widget.RatingBar")
			create box.make_single_line (controls)
			build_form
			build_rows
			build_draw
			controls.show (form)
			phone.log.info ("controls: shown")
			phone.run_controls
		end

feature {NONE} -- Screens

	build_form
		local
			l_body: PHONE_COLUMN
			l_scroll: PHONE_SCROLL
			l_title, l_verse: PHONE_LABEL
			l_nonsense: PHONE_CONTROL
			l_check: PHONE_CHECK_BOX
			l_switch: PHONE_SWITCH
			l_slider: PHONE_SLIDER
			l_choice: PHONE_CHOICE
			l_radio: PHONE_RADIO_GROUP
			l_stars_row: PHONE_ROW
			l_menu: PHONE_BUTTON
		do
			create l_title.make (controls, {STRING_32} "Android controls from Eiffel")
			l_title.set_style (22, True)
			create l_verse.make (controls, Verse)
			l_verse.set_style (24, False)
			box.set_hint ({STRING_32} "Type here")
			box.set_on_change (agent on_typed)
			create l_check.make (controls, {STRING_32} "A check box")
			l_check.set_on_change (agent on_toggled ("check", ?))
			create l_switch.make (controls, {STRING_32} "A switch")
			l_switch.set_on_change (agent on_toggled ("switch", ?))
			create l_slider.make (controls, 100)
			l_slider.set_on_change (agent on_slider)
			create l_choice.make (controls)
			l_choice.add_option ({STRING_32} "First choice")
			l_choice.add_option ({STRING_32} "Second choice")
			l_choice.add_option ({STRING_32} "Third choice")
			l_choice.set_on_change (agent on_picked ("choice", ?))
			create l_radio.make (controls)
			l_radio.add_option ({STRING_32} "Option A")
			l_radio.add_option ({STRING_32} "Option B")
			l_radio.set_on_change (agent on_picked ("radio", ?))
			stars.call_integer ("setNumStars", 5)
			stars.call_boolean ("setIsIndicator", False)
			stars.listen ("setOnRatingBarChangeListener", agent on_stars)
			stars.set_on_failure (agent on_failure)
			stars.call ("noSuchMethod")
			create l_nonsense.make_any (controls, "android.widget.NoSuchWidget")
			l_nonsense.set_on_failure (agent on_failure)
			create l_body.make (controls)
			l_body.set_spacing (10, 16)
			l_body.extend (nav_row)
			l_body.extend (l_title)
			l_body.extend (l_verse)
			l_body.extend (box)
			l_body.extend (typed)
			l_body.extend (l_nonsense)   -- a control Android refused still holds its place, and does nothing
			l_body.extend (create {PHONE_BUTTON}.make (controls, {STRING_32} "Round trip", agent on_round_trip))
			l_body.extend (create {PHONE_BUTTON}.make (controls, {STRING_32} "Show a toast", agent on_toast))
			l_body.extend (create {PHONE_BUTTON}.make (controls, {STRING_32} "Ask a question", agent on_ask))
			l_body.extend (create {PHONE_BUTTON}.make (controls, {STRING_32} "Pick a date", agent on_date))
			l_body.extend (create {PHONE_BUTTON}.make (controls, {STRING_32} "Pick a time", agent on_time))
			l_body.extend (l_check)
			l_body.extend (l_switch)
			l_body.extend (l_slider)
			l_body.extend (slider_value)
			l_body.extend (progress)
			l_body.extend (l_choice)
			l_body.extend (l_radio)
			create l_stars_row.make (controls)
			l_stars_row.extend (stars)   -- a RatingBar stretched to the full width grows extra stars
			l_body.extend (l_stars_row)
			storm_area := l_body
			create l_menu.make (controls, {STRING_32} "Open a menu", agent on_menu)
			menu_button := l_menu
			l_body.extend (l_menu)
			l_body.extend (create {PHONE_IMAGE}.make (controls, {STRING_32} "eiffel.png"))
			l_body.extend (missing_image)
			l_body.extend (create {PHONE_BUTTON}.make (controls, {STRING_32} "Order storm", agent on_storm))
			create l_scroll.make (controls)
			l_scroll.set_child (l_body)
			form.extend_growing (l_scroll, 1)
		end

	build_rows
		local
			l_list: PHONE_LIST
		do
			create l_list.make (controls)
			l_list.set_row_text (agent row_of)
			l_list.set_row_count (Row_total)
			l_list.set_on_select (agent on_row)
			rows_screen.extend (nav_row)
			rows_screen.extend (chosen_row)
			rows_screen.extend_growing (l_list, 1)
		end

	build_draw
		do
			canvas.set_on_paint (agent paint)
			canvas.set_on_press (agent on_press)
			canvas.set_on_sweep (agent on_sweep)
			canvas.set_on_release (agent on_release)
			draw_screen.extend (nav_row)
			draw_screen.extend_growing (canvas, 1)
		end

	nav_row: PHONE_ROW
			-- A row of buttons to change screens. A control has one parent, so each screen gets its own.
		do
			create Result.make (controls)
			Result.set_spacing (4, 4)
			Result.extend_growing (nav_button ({STRING_32} "Form", agent go (form, "form")), 1)
			Result.extend_growing (nav_button ({STRING_32} "List", agent go (rows_screen, "list")), 1)
			Result.extend_growing (nav_button ({STRING_32} "Draw", agent go (draw_screen, "draw")), 1)
			Result.extend_growing (nav_button ({STRING_32} "More", agent go_more), 1)
		end

	nav_button (a_label: READABLE_STRING_32; a_action: PROCEDURE [TUPLE]): PHONE_BUTTON
			-- A narrow button, whose label still fits when the phone's text size is large.
		do
			create Result.make (controls, a_label, a_action)
			Result.set_padding (4, 8)
		end

feature {NONE} -- Reactions

	go (a_screen: PHONE_CONTROL; a_name: READABLE_STRING_8)
			-- Show `a_screen'. Away from the form, Back returns to it; on the form, Back closes the app.
		do
			controls.show (a_screen)
			if a_screen = form then
				controls.clear_on_back
			else
				controls.set_on_back (agent go (form, "form"))
			end
			say ("screen " + a_name)
		end

	go_more
			-- Build the gallery the first time it is wanted.
		do
			if more_screen.children.is_empty then
				build_more
			end
			go (more_screen, "more")
		end

	build_more
			-- Every class here reaches Eiffel through `make_any': none has a class of its own.
		local
			l_body: PHONE_COLUMN
			l_scroll: PHONE_SCROLL
			l_control: PHONE_CONTROL
			l_name: PHONE_LABEL
		do
			create l_body.make (controls)
			l_body.set_spacing (6, 12)
			across Gallery as ic loop
				create l_name.make (controls, ic.to_string_32)
				l_name.set_style (12, True)
				l_body.extend (l_name)
				create l_control.make_any (controls, ic)
				l_control.set_on_failure (agent on_failure)
				l_body.extend (l_control)
			end
			create l_scroll.make (controls)
			l_scroll.set_child (l_body)
			more_screen.extend (nav_row)
			more_screen.extend_growing (l_scroll, 1)
			say ("gallery built, " + Gallery.count.out + " classes")
		end

	on_typed
		do
			typed.set_text ({STRING_32} "You typed: " + box.text)
			say ("typed " + box.text.count.out + " letters")
		end

	on_round_trip
			-- Hebrew and an emoji go to Android and come back through a real control.
		do
			box.set_text (Round_trip_text)
			box.ask ("getText", agent on_round_trip_answer)
		end

	on_round_trip_answer (a_answer: READABLE_STRING_32)
		do
			say ("round trip same " + a_answer.same_string (Round_trip_text).out)
		end

	on_toggled (a_name: READABLE_STRING_8; a_on: BOOLEAN)
		do
			say (a_name + " " + a_on.out)
		end

	on_slider (a_value: INTEGER)
		do
			slider_value.set_text ({STRING_32} "Slider: " + a_value.out.to_string_32)
			progress.set_value (a_value)
			say ("slider " + a_value.out)
		end

	on_picked (a_name: READABLE_STRING_8; a_index: INTEGER)
		do
			say (a_name + " " + a_index.out)
		end

	on_stars (a_words: READABLE_STRING_32)
		do
			say ("stars " + a_words.to_string_8)
			stars.ask ("getRating", agent on_rating)
		end

	on_rating (a_answer: READABLE_STRING_32)
		do
			say ("rating " + a_answer.to_string_8)
		end

	on_failure (a_words: READABLE_STRING_32)
		do
			say ("failure " + a_words.to_string_8)
		end

	on_storm
			-- Orders at full speed from the Eiffel thread: 40,000 changes to live
			-- controls, and 300 controls added and taken away. Android must keep up.
		local
			i: INTEGER
			l_label: PHONE_LABEL
		do
			from i := 1 until i > 20000 loop
				slider_value.set_text ({STRING_32} "Storm " + i.out.to_string_32)
				progress.set_value (i \\ 100)
				i := i + 1
			end
			from i := 1 until i > 300 loop
				create l_label.make (controls, {STRING_32} "Passing through")
				storm_area.extend (l_label)
				storm_area.remove (l_label)
				l_label.discard
				i := i + 1
			end
			slider_value.set_text ({STRING_32} "Storm over")
			say ("storm sent")
		end

	on_toast
		do
			controls.toast ({STRING_32} "Hello from Eiffel")
			say ("toast")
		end

	missing_image: PHONE_IMAGE
			-- A picture that is not there, to show how that is reported.
		do
			create Result.make (controls, {STRING_32} "not_there.png")
			Result.set_on_failure (agent on_failure)
		end

	on_menu
		do
			if attached menu_button as al_button then
				controls.show_menu (al_button, <<{STRING_32} "First item", {STRING_32} "Second item", {STRING_32} "Third item">>, agent on_menu_item)
			end
		end

	on_menu_item (a_item: INTEGER)
		do
			say ("menu " + a_item.out)
		end

	on_ask
		do
			controls.confirm ({STRING_32} "A question", {STRING_32} "Does this come from Eiffel?",
				{STRING_32} "Yes", {STRING_32} "No", agent on_answer)
		end

	on_answer (a_yes: BOOLEAN)
		do
			say ("answer " + a_yes.out)
		end

	on_date
		do
			controls.pick_date (2026, 11, 4, agent on_picked_text ("date", ?))
		end

	on_time
		do
			controls.pick_time (9, 30, agent on_picked_text ("time", ?))
		end

	on_picked_text (a_name: READABLE_STRING_8; a_answer: READABLE_STRING_32)
		do
			say (a_name + " [" + a_answer.to_string_8 + "]")
		end

	on_row (a_row: INTEGER)
		do
			chosen_row.set_text ({STRING_32} "Tapped row " + a_row.out.to_string_32)
			say ("row " + a_row.out)
		end

	row_of (a_row: INTEGER): READABLE_STRING_32
		do
			Result := {STRING_32} "Row " + a_row.out.to_string_32 + {STRING_32} "  " + Verse
		end

feature {NONE} -- Drawing

	paint (a_painter: PHONE_PAINTER; a_width, a_height: INTEGER)
		local
			i: INTEGER
		do
			a_painter.set_color (0x204080)
			a_painter.fill_rect (0, 0, a_width, 48)
			a_painter.set_color (0xFFFFFF)
			a_painter.text (12, 34, Verse, 26, False)
			a_painter.set_color (0xC02020)
			from i := 2 until i > strokes.count loop
				if strokes [i].joined then
					a_painter.line (strokes [i - 1].x, strokes [i - 1].y, strokes [i].x, strokes [i].y, 5)
				end
				i := i + 1
			end
		end

	on_press (a_x, a_y: REAL_64)
		do
			strokes.extend ([a_x, a_y, False])
			say ("press")
		end

	on_sweep (a_x, a_y: REAL_64)
		do
			strokes.extend ([a_x, a_y, True])
			canvas.request_repaint
		end

	on_release (a_x, a_y: REAL_64)
		do
			say ("release, " + strokes.count.out + " points")
		end

feature {NONE} -- Implementation

	say (a_text: READABLE_STRING_8)
		do
			phone.log.info ("controls: " + a_text)
		end

	Row_total: INTEGER = 31000

	Gallery: ARRAY [STRING_8]
			-- Controls in Android's own library that have no class in the controls cluster.
		once
			Result := <<"android.widget.ToggleButton", "android.widget.ImageButton", "android.widget.ImageView",
				"android.widget.Chronometer", "android.widget.TextClock", "android.widget.AutoCompleteTextView",
				"android.widget.MultiAutoCompleteTextView", "android.widget.CheckedTextView", "android.widget.RadioButton",
				"android.widget.QuickContactBadge", "android.widget.GridView", "android.widget.ExpandableListView",
				"android.widget.GridLayout", "android.widget.TableLayout", "android.widget.RelativeLayout",
				"android.widget.FrameLayout", "android.widget.HorizontalScrollView", "android.widget.ViewFlipper",
				"android.widget.Toolbar", "android.widget.VideoView", "android.webkit.WebView",
				"android.widget.SearchView", "android.widget.NumberPicker", "android.widget.TimePicker",
				"android.widget.DatePicker", "android.widget.CalendarView">>
		end

	Verse: STRING_32
			-- Genesis 1:1, first three words, in Hebrew.
		once
			Result := {STRING_32} "%/1489/%/1512/%/1488/%/1513/%/1497/%/1514/ %/1489/%/1512/%/1488/ %/1488/%/1500/%/1492/%/1497/%/1501/"
		end

	Round_trip_text: STRING_32
			-- Hebrew, then an emoji, which takes four bytes in UTF-8.
		once
			Result := Verse + {STRING_32} " %/128512/"
		end

	phone: SIMPLE_EIF_PHONE
	controls: PHONE_CONTROLS
	box: PHONE_TEXT_BOX
	menu_button: detachable PHONE_BUTTON

	storm_area: PHONE_COLUMN
		attribute
			create Result.make (controls)
		end
	form, rows_screen, draw_screen, more_screen: PHONE_COLUMN
	typed, slider_value, chosen_row: PHONE_LABEL
	progress: PHONE_PROGRESS
	canvas: PHONE_CANVAS
	stars: PHONE_CONTROL
	strokes: ARRAYED_LIST [TUPLE [x, y: REAL_64; joined: BOOLEAN]]

end
