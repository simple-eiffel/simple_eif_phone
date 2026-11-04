note
	description: "[
		simple_eif_phone demo: draw with your fingers. Each finger leaves its
		own color. Back clears the pad; Back on an empty pad exits. Strokes
		are saved when the app pauses and restored when it starts, the worked
		example of "apps save their own state" (intent Q8). Rotation redraws
		the same strokes on the new window.
	]"
	author: "Larry Rix"

class
	TOUCH_PAD_APP

inherit
	PHONE_EVENT_KIND

	PHONE_KEY_CODES

create
	make

feature {NONE} -- Initialization

	make
			-- Run until Android destroys the app.
		local
			l_taken: INTEGER
		do
			create phone.make
			create strokes.make (32)
			create active.make (10)
			create hint
			create canvas.make (1, 1)
			phone.set_back_policy (phone.Back_app)
			phone.set_keep_screen_on (True)
			load_strokes
			phone.log.info ("touch pad: loaded " + strokes.count.out + " strokes")
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				handle
					-- Take what is queued, up to a limit, then show one frame.
					-- The limit keeps frames coming while fingers keep moving.
				from
					needs_more := True
					l_taken := 1
				until
					not needs_more or l_taken >= Events_per_frame or phone.lifecycle.is_destroyed
				loop
					phone.poll_event (0)
					if phone.last_event.is_none then
						needs_more := False
					else
						handle
						l_taken := l_taken + 1
					end
				end
				if dirty and not phone.lifecycle.is_destroyed then
					show
				end
			end
		end

feature {NONE} -- Access

	phone: SIMPLE_EIF_PHONE
	canvas: PAD_CANVAS
	hint: PAD_FONT

	strokes: ARRAYED_LIST [PAD_STROKE]
			-- Everything drawn, oldest first.

	active: HASH_TABLE [PAD_STROKE, INTEGER]
			-- The stroke each finger is drawing, by pointer id.

	dirty: BOOLEAN
			-- Does the screen need a new frame?

	needs_more: BOOLEAN

	Background: INTEGER = 0x14161C

	Events_per_frame: INTEGER = 64
			-- Most events taken between frames (five fingers at 240 Hz send
			-- about 20 per 60 Hz frame).

	palette: ARRAY [INTEGER]
			-- Finger colors.
		once
			Result := <<0xF2B84B, 0x5EC4E8, 0xE8707A, 0x8FD18A, 0xC39BE8, 0xF2E6C9, 0x4FD1B5, 0xF08A5D, 0x9CB8F2, 0xE8D15E>>
		end

feature {NONE} -- Events

	handle
			-- React to `last_event'.
		local
			e: PHONE_EVENT
		do
			e := phone.last_event
			inspect e.kind
			when Kind_window_ready, Kind_window_resized, Kind_content_rect_changed then
				rebuild_canvas
			when Kind_redraw_needed then
				dirty := True
			when Kind_touch_down then
				start_stroke (e)
			when Kind_touch_move then
				continue_stroke (e)
			when Kind_touch_up then
				continue_stroke (e)
				active.remove (e.pointer_id)
			when Kind_touch_cancel, Kind_focus_lost, Kind_window_lost then
				active.wipe_out
			when Kind_paused then
				save_strokes
			when Kind_key_up then
				if e.key_code = Key_back then
					back_pressed
				end
			else
			end
		end

	start_stroke (a_e: PHONE_EVENT)
		local
			s: PAD_STROKE
		do
			create s.make (palette [(a_e.pointer_id \\ palette.count) + 1])
			s.extend (a_e.x, a_e.y)
			strokes.extend (s)
			active.force (s, a_e.pointer_id)
			if strokes.count = 1 then
				render_all
			end
			canvas.dab (a_e.x, a_e.y, brush, s.rgb)
			dirty := True
		end

	continue_stroke (a_e: PHONE_EVENT)
		do
			if attached active.item (a_e.pointer_id) as al_s then
				canvas.line (al_s.xs.last, al_s.ys.last, a_e.x, a_e.y, brush, al_s.rgb)
				al_s.extend (a_e.x, a_e.y)
				dirty := True
			end
		end

	back_pressed
			-- Clear the pad; on an empty pad, leave.
		do
			if strokes.is_empty then
				phone.finish
			else
				strokes.wipe_out
				active.wipe_out
				save_strokes
				render_all
				dirty := True
			end
		end

feature {NONE} -- Drawing

	brush: INTEGER
			-- Brush radius in pixels (6 dp).
		do
			Result := phone.metrics.dp (6).max (2)
		end

	rebuild_canvas
			-- Match the canvas to the window. Strokes are redrawn only when the
			-- size changed: the canvas already holds them otherwise.
		do
			if phone.metrics.width > 0 and phone.metrics.height > 0 then
				if canvas.width /= phone.metrics.width or canvas.height /= phone.metrics.height then
					create canvas.make (phone.metrics.width, phone.metrics.height)
					render_all
				end
				dirty := True
			end
		end

	render_all
			-- Redraw the canvas from `strokes', or the hint when there are none.
		local
			i: INTEGER
			l_scale: INTEGER
		do
			canvas.clear (Background)
			if strokes.is_empty then
				l_scale := (canvas.width // (Hint_text.count * 6 + 4)).max (1)
				hint.draw (canvas, Hint_text, (canvas.width - hint.text_width (Hint_text, l_scale)) // 2,
					canvas.height // 3, l_scale, 0x7A7F8C)
			else
				across strokes as ic loop
					canvas.dab (ic.xs.first, ic.ys.first, brush, ic.rgb)
					from i := 2 until i > ic.count loop
						canvas.line (ic.xs [i - 1], ic.ys [i - 1], ic.xs [i], ic.ys [i], brush, ic.rgb)
						i := i + 1
					end
				end
			end
		end

	Hint_text: STRING = "DRAW HERE"

	show
			-- Put the canvas on the screen.
		do
			if phone.screen.has_window then
				phone.screen.begin_frame
				if phone.screen.in_frame then
					phone.screen.present_argb (canvas.pixels.item, canvas.width, canvas.height, canvas.stride)
					phone.screen.end_frame
					dirty := False
				end
			end
		end

feature {NONE} -- Saving

	save_path: STRING
			-- Where strokes are kept between runs.
		do
			Result := phone.storage.internal_path + "/strokes.txt"
		end

	save_strokes
			-- One line per stroke: "<rgb> x y x y ...".
		local
			f: PLAIN_TEXT_FILE
			i: INTEGER
		do
			create f.make_create_read_write (save_path)
			across strokes as ic loop
				f.put_string (ic.rgb.out)
				from i := 1 until i > ic.count loop
					f.put_string (" " + ic.xs [i].out + " " + ic.ys [i].out)
					i := i + 1
				end
				f.put_new_line
			end
			f.close
			phone.log.info ("touch pad: saved " + strokes.count.out + " strokes")
		end

	load_strokes
			-- Read `save_path', if it is there.
		local
			f: PLAIN_TEXT_FILE
			l_parts: LIST [STRING]
			s: PAD_STROKE
			i: INTEGER
		do
			create f.make_with_name (save_path)
			if f.exists then
				f.open_read
				from until f.end_of_file or else not f.file_readable loop
					f.read_line
					l_parts := f.last_string.split (' ')
					if l_parts.count >= 3 and then l_parts.first.is_integer
						and then 0 <= l_parts.first.to_integer and then l_parts.first.to_integer <= 0xFFFFFF
					then
						create s.make (l_parts.first.to_integer)
						from i := 2 until i + 1 > l_parts.count loop
							if l_parts [i].is_integer and l_parts [i + 1].is_integer then
								s.extend (l_parts [i].to_integer, l_parts [i + 1].to_integer)
							end
							i := i + 2
						end
						if s.count > 0 then
							strokes.extend (s)
						end
					end
				end
				f.close
			end
		end

end
