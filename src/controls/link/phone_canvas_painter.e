note
	description: "The real painter: Android's Canvas, through runtime/c/sephone_controls.c."
	author: "Larry Rix"

class
	PHONE_CANVAS_PAINTER

inherit
	PHONE_PAINTER

feature -- Status

	is_drawing: BOOLEAN

feature -- Frames

	start_frame (a_canvas, a_background: INTEGER)
		do
			is_drawing := c_begin (a_canvas, a_background) /= 0
		end

	finish_frame
		do
			c_end
			is_drawing := False
		end

feature -- Drawing

	set_color (a_rgb: INTEGER)
		do
			c_color (a_rgb)
		end

	fill_rect (a_x, a_y, a_width, a_height: REAL_64)
		do
			c_rect (a_x, a_y, a_width, a_height)
		end

	line (a_x1, a_y1, a_x2, a_y2, a_width: REAL_64)
		do
			c_line (a_x1, a_y1, a_x2, a_y2, a_width)
		end

	text (a_x, a_y: REAL_64; a_text: READABLE_STRING_32; a_size: REAL_64; a_bold: BOOLEAN)
		local
			l_text: C_STRING
		do
			create l_text.make ({UTF_CONVERTER}.utf_32_string_to_utf_8_string_8 (a_text))
			c_text (a_x, a_y, l_text.item, a_size, a_bold.to_integer)
		end

feature {NONE} -- C

	c_begin (a_canvas, a_background: INTEGER): INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_canvas_begin((int)$a_canvas, (int)$a_background);" end

	c_end
		external "C inline use %"sephone.h%"" alias "sephone_canvas_end();" end

	c_color (a_rgb: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_canvas_color((int)$a_rgb);" end

	c_rect (a_x, a_y, a_width, a_height: REAL_64)
		external "C inline use %"sephone.h%"" alias "sephone_canvas_rect($a_x, $a_y, $a_width, $a_height);" end

	c_line (a_x1, a_y1, a_x2, a_y2, a_width: REAL_64)
		external "C inline use %"sephone.h%"" alias "sephone_canvas_line($a_x1, $a_y1, $a_x2, $a_y2, $a_width);" end

	c_text (a_x, a_y: REAL_64; a_text: POINTER; a_size: REAL_64; a_bold: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_canvas_text($a_x, $a_y, (const char *)$a_text, $a_size, (int)$a_bold);" end

end
