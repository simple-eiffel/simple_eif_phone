note
	description: "[
		simple_eif_phone example: the canonical event loop (spec 06).
		Draws a greeting and a tap counter with HELLO_FONT, changes the
		background on each tap, and logs every event it receives.
	]"
	author: "Larry Rix"

class
	HELLO_APP

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Run until Android destroys the app.
		do
			create phone.make
			create font
			phone.log.set_tag ("Eiffel")
			phone.log.info ("hello: started")
			from
			until
				phone.lifecycle.is_destroyed
			loop
				phone.wait_for_event
				phone.log.info ("event " + phone.last_event.out_line)
				inspect phone.last_event.kind
				when Kind_window_ready, Kind_window_resized, Kind_redraw_needed, Kind_content_rect_changed then
					draw
				when Kind_touch_down then
					taps := taps + 1
					draw
				else
				end
			end
			phone.log.info ("hello: loop ended")
		end

feature {NONE} -- Access

	phone: SIMPLE_EIF_PHONE
	font: HELLO_FONT
	taps: INTEGER

	backgrounds: ARRAY [INTEGER]
		once
			Result := <<0x14161C, 0x1C2433, 0x1F2A1E, 0x2E1F2A, 0x2B2516>>
		end

	Title: STRING = "HELLO FROM EIFFEL"

feature {NONE} -- Drawing

	draw
			-- Paint the whole screen, below the status bar.
		local
			w, h, l_top, l_scale: INTEGER
			s: PHONE_SCREEN
		do
			s := phone.screen
			if s.has_window then
				s.begin_frame
				if s.in_frame then
					w := s.width
					h := s.height
					l_top := phone.metrics.inset_top
					s.fill_rect (0, 0, w, h, backgrounds [(taps \\ backgrounds.count) + 1])
					l_scale := (w // (Title.count * 6 + 4)).min ((h - l_top) // 64).max (1)
					centered (Title, l_top + (h - l_top) // 3, l_scale, 0xF2E6C9)
					centered ("TAPS: " + taps.out, l_top + (h - l_top) // 3 + l_scale * 12, l_scale, 0x8FB8DE)
					centered ("DPI: " + phone.metrics.density_dpi.out, l_top + (h - l_top) // 3 + l_scale * 24, (l_scale * 2 // 3).max (1), 0x9CC28A)
					centered ("TAP ANYWHERE", h - h // 5, (l_scale // 2).max (1), 0x7A7F8C)
					s.end_frame
				end
			end
		end

	centered (a_text: STRING; a_y, a_scale, a_rgb: INTEGER)
		do
			font.draw (phone.screen, a_text, (phone.screen.width - font.text_width (a_text, a_scale)) // 2, a_y, a_scale, a_rgb)
		end

end
