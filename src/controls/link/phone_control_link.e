note
	description: "[
		The real port: orders go to runtime/c/sephone_controls.c, which drives
		Android's controls through JNI. The only class here that holds C calls,
		with PHONE_CANVAS_PAINTER.
	]"
	author: "Larry Rix"

class
	PHONE_CONTROL_LINK

inherit
	PHONE_CONTROL_PORT

create
	make

feature {NONE} -- Initialization

	make
		do
			create {PHONE_CANVAS_PAINTER} painter
		end

feature -- Status

	is_connected: BOOLEAN
		do
			Result := c_present /= 0
		end

	density_percent: INTEGER
		do
			Result := c_density_percent.max (1)
		end

feature -- Access

	painter: PHONE_PAINTER

feature -- Commands

	send (a_order, a_id, a_first, a_second: INTEGER; a_text: detachable READABLE_STRING_32)
		local
			l_text: C_STRING
		do
			if attached a_text as al_text then
				create l_text.make ({UTF_CONVERTER}.utf_32_string_to_utf_8_string_8 (al_text))
				c_control (a_order, a_id, a_first, a_second, l_text.item)
			else
				c_control (a_order, a_id, a_first, a_second, default_pointer)
			end
		end

feature {NONE} -- C

	c_present: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_controls_present();" end

	c_density_percent: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_controls_density_percent();" end

	c_control (a_order, a_id, a_first, a_second: INTEGER; a_text: POINTER)
		external "C inline use %"sephone.h%"" alias "sephone_control((int)$a_order, (int)$a_id, (int)$a_first, (int)$a_second, (const char *)$a_text);" end

end
