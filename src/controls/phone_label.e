note
	description: "Text to read, in any script. Android's TextView."
	author: "Larry Rix"

class
	PHONE_LABEL

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_text: READABLE_STRING_32)
		do
			text := a_text
			size := 16
			make_control (a_controls, Control_label, Void)
			order (Op_text, 0, 0, a_text)
		ensure
			mine: controls = a_controls
			text_set: text.same_string (a_text)
		end

feature -- Access

	text: READABLE_STRING_32

	size: INTEGER
			-- In scale-independent pixels, which follow the user's font setting.

	is_bold: BOOLEAN

feature -- Element change

	set_text (a_text: READABLE_STRING_32)
		do
			text := a_text
			order (Op_text, 0, 0, a_text)
		ensure
			set: text.same_string (a_text)
		end

	set_color (a_color: NATURAL_32)
			-- Text in `a_color' (0xAARRGGBB).
		do
			call_integer ("setTextColor", a_color.as_integer_32)
		end

	set_rich (a_row: PHONE_RICH_ROW)
			-- Show the first block of `a_row', with its styles.
		require
			has_block: a_row.block_count > 0
		do
			order (Op_rich, 0, 0, a_row.wire)
		end

	set_style (a_size: INTEGER; a_bold: BOOLEAN)
		require
			size_positive: a_size > 0
		do
			size := a_size
			is_bold := a_bold
			order (Op_text_style, a_size * 100, a_bold.to_integer, Void)
		ensure
			size_set: size = a_size
			bold_set: is_bold = a_bold
		end

end
