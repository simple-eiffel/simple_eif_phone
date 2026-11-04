note
	description: "[
		Codes shared with the C side (runtime/c/sephone.h): the kinds of control
		and the orders Eiffel sends. Change both together.
	]"
	author: "Larry Rix"

class
	PHONE_CONTROL_CODES

feature -- Kinds of control

	Control_label: INTEGER = 1
	Control_button: INTEGER = 2
	Control_text_box: INTEGER = 3
	Control_column: INTEGER = 4
	Control_row: INTEGER = 5
	Control_list: INTEGER = 6
	Control_canvas: INTEGER = 7
	Control_scroll: INTEGER = 8
	Control_check_box: INTEGER = 9
	Control_switch: INTEGER = 10
	Control_slider: INTEGER = 11
	Control_progress: INTEGER = 12
	Control_choice: INTEGER = 13
	Control_radio_group: INTEGER = 14
	Control_any: INTEGER = 15
	Control_image: INTEGER = 16

feature -- Orders

	Op_new: INTEGER = 1
	Op_add: INTEGER = 2
	Op_remove: INTEGER = 3
	Op_show: INTEGER = 4
	Op_text: INTEGER = 5
	Op_enabled: INTEGER = 6
	Op_visible: INTEGER = 7
	Op_text_style: INTEGER = 8
	Op_spacing: INTEGER = 9
	Op_height: INTEGER = 10
	Op_checked: INTEGER = 11
	Op_value: INTEGER = 12
	Op_maximum: INTEGER = 13
	Op_choice_add: INTEGER = 14
	Op_choice_clear: INTEGER = 15
	Op_select: INTEGER = 16
	Op_radio_add: INTEGER = 17
	Op_row_count: INTEGER = 18
	Op_row: INTEGER = 19
	Op_rows_done: INTEGER = 20
	Op_single_line: INTEGER = 21
	Op_masked: INTEGER = 22
	Op_hint: INTEGER = 23
	Op_focus: INTEGER = 24
	Op_toast: INTEGER = 25
	Op_dialog: INTEGER = 26
	Op_date: INTEGER = 27
	Op_time: INTEGER = 28
	Op_call: INTEGER = 29
	Op_ask: INTEGER = 30
	Op_listen: INTEGER = 31
	Op_discard: INTEGER = 32
	Op_back: INTEGER = 33
	Op_image: INTEGER = 34
	Op_menu: INTEGER = 35
	Op_padding: INTEGER = 36

feature -- Arguments of the general route

	Argument_none: INTEGER = 0
	Argument_integer: INTEGER = 1
	Argument_boolean: INTEGER = 2
	Argument_text: INTEGER = 3

feature -- Text

	Field_mark: CHARACTER_32 = '%/31/'
			-- Separates the fields of an order that carries several texts.

	Row_block: INTEGER = 64
			-- Rows the C side asks for at a time.

end
