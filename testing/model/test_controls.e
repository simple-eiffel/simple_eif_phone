note
	description: "[
		Tests for the controls cluster: the orders each control sends, and what
		each does with Android's events. Runs on a PC against a recording port.
		Real controls are tested on the emulator by examples/controls_demo.
	]"
	testing: "covers"

class
	TEST_CONTROLS

inherit
	TEST_SET_BASE

	PHONE_CONTROL_CODES
		undefine
			default_create
		end

	PHONE_EVENT_KIND
		undefine
			default_create
		end

feature -- Building

	test_ids_and_orders
			-- Each control gets its own id, and a box tells C about its children.
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_column: PHONE_COLUMN
			l_label: PHONE_LABEL
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_column.make (l_controls)
			create l_label.make (l_controls, {STRING_32} "hello")
			l_column.extend (l_label)
			l_controls.show (l_column)
			assert ("ids differ", l_column.id /= l_label.id)
			assert ("two made", l_port.count_of (Op_new) = 2 and l_controls.count = 2)
			assert ("label text sent", attached l_port.last_of (Op_text) as al_o and then al_o.text.same_string ({STRING_32} "hello"))
			assert ("child added", attached l_port.last_of (Op_add) as al_o and then al_o.id = l_column.id and then al_o.first = l_label.id)
			assert ("shown", l_controls.root = l_column and l_port.count_of (Op_show) = 1)
		end

	test_growing_share
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_row: PHONE_ROW
			l_label: PHONE_LABEL
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_row.make (l_controls)
			create l_label.make (l_controls, {STRING_32} "x")
			l_row.extend_growing (l_label, 2)
			assert ("share in hundredths", attached l_port.last_of (Op_add) as al_o and then al_o.second = 200)
			l_row.remove (l_label)
			assert ("removed", l_row.children.is_empty and l_port.count_of (Op_remove) = 1)
		end

feature -- Events

	test_button_click
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_button: PHONE_BUTTON
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_button.make (l_controls, {STRING_32} "Go", agent count_up)
			hits := 0
			l_controls.dispatch (event (Kind_control_clicked, l_button.id, 0, ""))
			assert ("clicked once", hits = 1)
		end

	test_event_for_nobody_is_ignored
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
		do
			create l_port.make
			create l_controls.make (l_port)
			l_controls.dispatch (event (Kind_control_clicked, 999, 0, ""))
			l_controls.dispatch (create {PHONE_EVENT}.make_lifecycle (Kind_resumed, 1))
			assert ("nothing happened", l_controls.count = 0)
		end

	test_text_box_follows_typing
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_box: PHONE_TEXT_BOX
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_box.make_single_line (l_controls)
			l_box.set_on_change (agent count_up)
			hits := 0
			l_controls.dispatch (event (Kind_control_changed, l_box.id, 0, "abc"))
			assert ("text taken", l_box.text.same_string ({STRING_32} "abc"))
			assert ("told once", hits = 1)
			l_controls.dispatch (event (Kind_control_changed, l_box.id, 0, "abc"))
			assert ("the same text is no change", hits = 1)
			l_box.set_text ({STRING_32} "set by Eiffel")
			assert ("no echo", hits = 1)
		end

	test_toggle_and_slider
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_check: PHONE_CHECK_BOX
			l_slider: PHONE_SLIDER
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_check.make (l_controls, {STRING_32} "c")
			create l_slider.make (l_controls, 10)
			l_controls.dispatch (event (Kind_control_changed, l_check.id, 1, ""))
			assert ("on", l_check.is_on)
			l_controls.dispatch (event (Kind_control_changed, l_slider.id, 7, ""))
			assert ("seven", l_slider.value = 7)
			l_controls.dispatch (event (Kind_control_changed, l_slider.id, 99, ""))
			assert ("held to the maximum", l_slider.value = 10)
		end

	test_choice_ignores_android_opening_report
			-- Android reports the option a Spinner starts on; that is not a choice.
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_choice: PHONE_CHOICE
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_choice.make (l_controls)
			l_choice.add_option ({STRING_32} "a")
			l_choice.add_option ({STRING_32} "b")
			l_choice.set_on_change (agent note_index)
			last_index := 0
			l_controls.dispatch (event (Kind_control_changed, l_choice.id, 1, ""))
			assert ("no report", last_index = 0)
			l_controls.dispatch (event (Kind_control_changed, l_choice.id, 2, ""))
			assert ("real choice", last_index = 2 and l_choice.selected_index = 2)
			l_controls.dispatch (event (Kind_control_changed, l_choice.id, 9, ""))
			assert ("outside the options", l_choice.selected_index = 2)
		end

	test_radio_group
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_radio: PHONE_RADIO_GROUP
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_radio.make (l_controls)
			l_radio.add_option ({STRING_32} "a")
			l_radio.add_option ({STRING_32} "b")
			assert ("each option sent", l_port.count_of (Op_radio_add) = 2)
			l_controls.dispatch (event (Kind_control_changed, l_radio.id, 2, ""))
			assert ("chosen", l_radio.selected_index = 2)
			l_controls.dispatch (event (Kind_control_changed, l_radio.id, -1, ""))
			assert ("Android's cleared code changes nothing", l_radio.selected_index = 2)
		end

feature -- Lists

	test_list_sends_a_block
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_list: PHONE_LIST
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_list.make (l_controls)
			l_list.set_row_text (agent row_text)
			l_list.set_row_count (31000)
			assert ("no rows yet", l_port.count_of (Op_row) = 0)
			l_controls.dispatch (event (Kind_control_rows, l_list.id, 64, ""))
			assert ("one block", l_port.count_of (Op_row) = Row_block)
			assert ("told it is done", l_port.count_of (Op_rows_done) = 1)
			assert ("rows count from one", attached l_port.last_of (Op_row) as al_o and then al_o.first = 127 and then al_o.text.same_string ({STRING_32} "128"))
		end

	test_list_last_block_is_short
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_list: PHONE_LIST
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_list.make (l_controls)
			l_list.set_row_text (agent row_text)
			l_list.set_row_count (70)
			l_controls.dispatch (event (Kind_control_rows, l_list.id, 64, ""))
			assert ("six rows", l_port.count_of (Op_row) = 6)
		end

	test_list_selection
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_list: PHONE_LIST
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_list.make (l_controls)
			l_list.set_row_count (5)
			l_list.set_on_select (agent note_index)
			l_controls.dispatch (event (Kind_control_selected, l_list.id, 3, ""))
			assert ("selected", l_list.selected_index = 3 and last_index = 3)
			l_controls.dispatch (event (Kind_control_selected, l_list.id, 6, ""))
			assert ("past the end", l_list.selected_index = 3)
			l_list.set_row_count (2)
			assert ("new rows, no selection", l_list.selected_index = 0)
		end

feature -- Canvas

	test_canvas_paints_when_ready
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_canvas: PHONE_CANVAS
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_canvas.make (l_controls)
			l_canvas.set_on_paint (agent note_paint)
			l_canvas.repaint
			assert ("not before it is ready", l_port.frames = 0)
			l_controls.dispatch (control_event (Kind_control_canvas_ready, l_canvas.id, 800, 1200))
			assert ("painted", l_port.frames = 1 and not l_port.is_drawing)
			assert ("size in density-independent pixels", last_width = 400 and last_height = 600)
			l_controls.dispatch (event (Kind_control_canvas_lost, l_canvas.id, 0, ""))
			l_canvas.repaint
			assert ("not after it is lost", l_port.frames = 1)
		end

	test_canvas_finger
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_canvas: PHONE_CANVAS
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_canvas.make (l_controls)
			l_canvas.set_on_sweep (agent note_finger)
			l_controls.dispatch (control_event (Kind_control_swept, l_canvas.id, 100, 61))
			assert ("scaled", last_x = 50.0 and last_y = 30.5)
		end

	test_repaint_requests_collapse
			-- However many ask while events wait, one frame is drawn.
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_canvas: PHONE_CANVAS
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_canvas.make (l_controls)
			l_canvas.set_on_paint (agent note_paint)
			l_controls.dispatch (control_event (Kind_control_canvas_ready, l_canvas.id, 800, 1200))
			l_canvas.request_repaint
			l_canvas.request_repaint
			l_canvas.request_repaint
			assert ("nothing drawn yet", l_port.frames = 1)
			l_controls.repaint_waiting
			assert ("one frame", l_port.frames = 2 and not l_canvas.is_repaint_waiting)
			l_controls.repaint_waiting
			assert ("nothing left waiting", l_port.frames = 2)
		end

feature -- Questions and the general route

	test_confirm_answers_once
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_id: INTEGER
		do
			create l_port.make
			create l_controls.make (l_port)
			l_controls.confirm ({STRING_32} "t", {STRING_32} "m", {STRING_32} "Yes", {STRING_32} "No", agent note_answer)
			assert ("sent", attached l_port.last_of (Op_dialog) as al_o and then al_o.text.occurrences (Field_mark) = 3)
			if attached l_port.last_of (Op_dialog) as al_o then
				l_id := al_o.id
			end
			hits := 0
			l_controls.dispatch (event (Kind_control_answered, l_id, 1, ""))
			assert ("yes", hits = 1 and last_answer)
			l_controls.dispatch (event (Kind_control_answered, l_id, 1, ""))
			assert ("only once", hits = 1)
		end

	test_general_route
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_any: PHONE_CONTROL
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_any.make_any (l_controls, "android.widget.RatingBar")
			assert ("class sent", attached l_port.last_of (Op_new) as al_o and then al_o.first = Control_any and then al_o.text.same_string ({STRING_32} "android.widget.RatingBar"))
			l_any.call_integer ("setNumStars", 5)
			assert ("number sent", attached l_port.last_of (Op_call) as al_o and then al_o.first = 5 and then al_o.second = Argument_integer)
			l_any.ask ("getRating", agent note_text)
			assert ("asked", attached l_port.last_of (Op_ask) as al_o and then al_o.first = 1)
			l_controls.dispatch (event (Kind_control_answered, l_any.id, 1, "3.5"))
			assert ("answered", last_text.same_string ({STRING_32} "3.5"))
			l_any.listen ("setOnRatingBarChangeListener", agent note_text)
			l_controls.dispatch (event (Kind_control_called, l_any.id, 0, "onRatingChanged|4.0|true"))
			assert ("heard", last_text.same_string ({STRING_32} "onRatingChanged|4.0|true"))
			l_controls.dispatch (event (Kind_control_failed, l_any.id, 0, "setNope: no such method"))
			assert ("failure kept", attached l_any.last_failure as al_f and then al_f.has_substring ("setNope"))
		end

feature -- Pictures and menus

	test_image_names_its_asset
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_image: PHONE_IMAGE
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_image.make (l_controls, {STRING_32} "logo.png")
			assert ("kind", attached l_port.last_of (Op_new) as al_o and then al_o.first = Control_image)
			assert ("asset sent", attached l_port.last_of (Op_image) as al_o and then al_o.text.same_string ({STRING_32} "logo.png"))
			l_controls.dispatch (event (Kind_control_failed, l_image.id, 0, "logo.png"))
			assert ("a missing file is reported", attached l_image.last_failure)
		end

	test_menu_answers_once
			-- Android reports a choice, and then that the menu closed: only the first counts.
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_anchor: PHONE_LABEL
			l_id: INTEGER
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_anchor.make (l_controls, {STRING_32} "x")
			l_controls.show_menu (l_anchor, <<{STRING_32} "One", {STRING_32} "Two">>, agent note_index)
			assert ("items sent", attached l_port.last_of (Op_menu) as al_o and then al_o.text.occurrences (Field_mark) = 1)
			if attached l_port.last_of (Op_menu) as al_o then
				l_id := al_o.first
			end
			last_index := -1
			l_controls.dispatch (event (Kind_control_answered, l_id, 2, ""))
			assert ("chosen", last_index = 2)
			l_controls.dispatch (event (Kind_control_answered, l_id, 0, ""))
			assert ("closing changes nothing", last_index = 2)
		end

feature -- Finishing with controls

	test_discard
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_label: PHONE_LABEL
			l_id: INTEGER
		do
			create l_port.make
			create l_controls.make (l_port)
			create l_label.make (l_controls, {STRING_32} "x")
			l_id := l_label.id
			l_label.discard
			assert ("told C", l_port.count_of (Op_discard) = 1)
			assert ("forgotten", l_controls.item (l_id) = Void and l_label.is_discarded)
			l_controls.dispatch (event (Kind_control_clicked, l_id, 0, ""))
			assert ("a late event harms nothing", l_controls.count = 0)
		end

	test_back
		local
			l_port: TEST_CONTROL_PORT
			l_controls: PHONE_CONTROLS
			l_id: INTEGER
		do
			create l_port.make
			create l_controls.make (l_port)
			hits := 0
			l_controls.set_on_back (agent count_up)
			if attached l_port.last_of (Op_back) as al_o then
				l_id := al_o.first
			end
			assert ("asked for Back", l_id > 0)
			l_controls.dispatch (event (Kind_control_back, l_id, 0, ""))
			assert ("called", hits = 1)
			l_controls.clear_on_back
			assert ("given back", attached l_port.last_of (Op_back) as al_o and then al_o.first = 0)
			l_controls.dispatch (event (Kind_control_back, l_id, 0, ""))
			assert ("not called after", hits = 1)
		end

feature {NONE} -- Helpers

	event (a_kind, a_id, a_x: INTEGER; a_text: STRING_8): PHONE_EVENT
		do
			create Result.make_control (a_kind, a_id, a_x, 0, a_text.to_string_32, 1)
		end

	control_event (a_kind, a_id, a_x, a_y: INTEGER): PHONE_EVENT
		do
			create Result.make_control (a_kind, a_id, a_x, a_y, {STRING_32} "", 1)
		end

	hits, last_index, last_width, last_height: INTEGER

	last_x, last_y: REAL_64

	last_answer: BOOLEAN

	last_text: READABLE_STRING_32
		attribute
			Result := {STRING_32} ""
		end

	count_up
		do
			hits := hits + 1
		end

	note_index (a_index: INTEGER)
		do
			last_index := a_index
		end

	note_answer (a_yes: BOOLEAN)
		do
			hits := hits + 1
			last_answer := a_yes
		end

	note_text (a_text: READABLE_STRING_32)
		do
			last_text := a_text
		end

	note_paint (a_painter: PHONE_PAINTER; a_width, a_height: INTEGER)
		do
			last_width := a_width
			last_height := a_height
		end

	note_finger (a_x, a_y: REAL_64)
		do
			last_x := a_x
			last_y := a_y
		end

	row_text (a_row: INTEGER): READABLE_STRING_32
		do
			Result := a_row.out.to_string_32
		end

end
