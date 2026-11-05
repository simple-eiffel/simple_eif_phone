note
	description: "[
		One row of styled text for a PHONE_LIST: a background, then blocks of text,
		each block made of runs with their own color, size and weight. Give `wire'
		to the list as the row's text. Plain rows and rich rows can share a list.

		Sizes are in scale-independent pixels, which follow the user's font setting.
		Colors are 0xAARRGGBB. A font is "" for the phone's own, "serif" for its
		serif, a name beginning "sans-serif" for that family (such as
		"sans-serif-medium"), or the path of a font file among the app's assets.
	]"
	author: "Larry Rix"

class
	PHONE_RICH_ROW

create
	make, make_padded

feature {NONE} -- Initialization

	make (a_background: NATURAL_32; a_sides, a_top_and_bottom: INTEGER)
			-- A row with `a_background', padded by the two measures.
		require
			sides_non_negative: a_sides >= 0
			ends_non_negative: a_top_and_bottom >= 0
		do
			make_padded (a_background, a_sides, a_top_and_bottom, a_top_and_bottom)
		ensure
			no_blocks: block_count = 0
		end

	make_padded (a_background: NATURAL_32; a_sides, a_top, a_bottom: INTEGER)
			-- A row with `a_background', and a different space above and below.
		require
			sides_non_negative: a_sides >= 0
			top_non_negative: a_top >= 0
			bottom_non_negative: a_bottom >= 0
		do
			create wire.make (256)
			wire.append_character (Rich_mark)
			wire.append_string_general (a_background.to_hex_string)
			wire.append_character (Field_mark)
			wire.append_integer (a_sides)
			wire.append_character (Field_mark)
			wire.append_integer (a_top)
			wire.append_character (Field_mark)
			wire.append_integer (a_bottom)
		ensure
			no_blocks: block_count = 0
		end

feature -- Access

	wire: STRING_32
			-- The row, in the form the list reads.

	block_count: INTEGER

feature -- Constants

	Bold: INTEGER = 1

	Italic: INTEGER = 2

	Superscript: INTEGER = 4

	Semi_bold: INTEGER = 8

	Tappable: INTEGER = 16
			-- A run a PHONE_TAPPABLE_TEXT reports taps on.

	Underlined: INTEGER = 32

feature -- Element change

	add_block (a_font: READABLE_STRING_8; a_size, a_line_height: REAL_64; a_color: NATURAL_32; a_right_to_left: BOOLEAN; a_above: INTEGER)
			-- Start a block of text, `a_above' clear of the one before.
		require
			size_positive: a_size > 0
			line_height_positive: a_line_height > 0
			above_non_negative: a_above >= 0
		do
			wire.append_character (Block_mark)
			wire.append_string_general (a_font)
			wire.append_character (Field_mark)
			wire.append_string_general (a_size.out)
			wire.append_character (Field_mark)
			wire.append_string_general (a_line_height.out)
			wire.append_character (Field_mark)
			wire.append_string_general (a_color.to_hex_string)
			wire.append_character (Field_mark)
			wire.append_integer (a_right_to_left.to_integer)
			wire.append_character (Field_mark)
			wire.append_integer (a_above)
			block_count := block_count + 1
		ensure
			one_more: block_count = old block_count + 1
		end

	add_material_block (a_font: READABLE_STRING_8; a_size, a_line_height, a_letter_spacing: REAL_64; a_color: NATURAL_32; a_above: INTEGER)
			-- Start a block set as Material's text styles are: every line its full height with
			-- the text centered in it, and `a_letter_spacing' between letters, in the units of the size.
		require
			size_positive: a_size > 0
			line_height_positive: a_line_height > 0
			above_non_negative: a_above >= 0
		do
			add_block (a_font, a_size, a_line_height, a_color, False, a_above)
			wire.append_character (Field_mark)
			wire.append_string_general ((a_letter_spacing / a_size).out)
		ensure
			one_more: block_count = old block_count + 1
		end

	center_block
			-- Center the Material block just started.
		require
			has_block: block_count > 0
		do
			wire.append_character (Field_mark)
			wire.append_character ('c')
		end

	add_text (a_text: READABLE_STRING_32)
			-- Add `a_text' in the block's own style.
		require
			has_block: block_count > 0
			clean: is_clean (a_text)
		do
			add_run (a_text, 0, 0, 0.0)
		end

	add_run (a_text: READABLE_STRING_32; a_style: INTEGER; a_color: NATURAL_32; a_scale: REAL_64)
			-- Add `a_text' with `a_style' (a sum of the style constants), `a_color'
			-- (0 keeps the block's) and `a_scale' times the block's size (0 keeps it).
		require
			has_block: block_count > 0
			clean: is_clean (a_text)
			style_known: a_style >= 0 and a_style <= Bold + Italic + Superscript + Semi_bold + Tappable + Underlined
			scale_non_negative: a_scale >= 0
		do
			wire.append_character (Run_mark)
			wire.append_integer (a_style)
			wire.append_character (Field_mark)
			wire.append_string_general (a_color.to_hex_string)
			wire.append_character (Field_mark)
			wire.append_string_general (a_scale.out)
			wire.append_character (Field_mark)
			wire.append_string_general (a_text)
		end

feature -- Status report

	is_clean (a_text: READABLE_STRING_32): BOOLEAN
			-- Is `a_text' free of the marks the row form uses?
		do
			Result := not (a_text.has (Rich_mark) or a_text.has (Block_mark) or a_text.has (Run_mark) or a_text.has (Field_mark))
		end

feature {NONE} -- Implementation

	Rich_mark: CHARACTER_32 = '%/1/'

	Block_mark: CHARACTER_32 = '%/30/'

	Run_mark: CHARACTER_32 = '%/29/'

	Field_mark: CHARACTER_32 = '%/31/'

invariant
	blocks_non_negative: block_count >= 0

end
