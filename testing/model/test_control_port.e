note
	description: "A port that records every order, so controls can be tested on a PC."

class
	TEST_CONTROL_PORT

inherit
	PHONE_CONTROL_PORT

	PHONE_PAINTER
		rename
			text as draw_text
		end

create
	make

feature {NONE} -- Initialization

	make
		do
			create orders.make (32)
		end

feature -- Port

	is_connected: BOOLEAN = True

	density_percent: INTEGER = 200

	painter: PHONE_PAINTER
		do
			Result := Current
		end

	send (a_order, a_id, a_first, a_second: INTEGER; a_text: detachable READABLE_STRING_32)
		do
			orders.extend ([a_order, a_id, a_first, a_second, if attached a_text as al_t then al_t.to_string_32 else {STRING_32} "" end])
		end

feature -- Painter

	is_drawing: BOOLEAN

	frames: INTEGER

	start_frame (a_canvas, a_background: INTEGER)
		do
			is_drawing := True
		end

	finish_frame
		do
			is_drawing := False
			frames := frames + 1
		end

	set_color (a_rgb: INTEGER)
		do
		end

	fill_rect (a_x, a_y, a_width, a_height: REAL_64)
		do
		end

	line (a_x1, a_y1, a_x2, a_y2, a_width: REAL_64)
		do
		end

	draw_text (a_x, a_y: REAL_64; a_text: READABLE_STRING_32; a_size: REAL_64; a_bold: BOOLEAN)
		do
		end

feature -- Record

	orders: ARRAYED_LIST [TUPLE [order, id, first, second: INTEGER; text: STRING_32]]

	count_of (a_order: INTEGER): INTEGER
			-- How many orders of kind `a_order' went out?
		do
			across orders as ic loop
				if ic.order = a_order then
					Result := Result + 1
				end
			end
		end

	last_of (a_order: INTEGER): detachable TUPLE [order, id, first, second: INTEGER; text: STRING_32]
			-- The newest order of kind `a_order'.
		do
			across orders as ic loop
				if ic.order = a_order then
					Result := ic
				end
			end
		end

end
