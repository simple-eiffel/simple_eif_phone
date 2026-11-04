note
	description: "[
		Spike 01: the first Eiffel program to run as an Android app.
		Eiffel owns the event loop. It draws a greeting and a tap counter
		with its own pixel font, and changes the background on each tap.
	]"

class
	HELLO_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the app until Android destroys it.
		local
			l_running: BOOLEAN
		do
			create phone
			create font
			phone.log ("Hello from Eiffel: app started")
			from
				l_running := True
			until
				not l_running
			loop
				inspect phone.next_event
				when {EP_PHONE}.event_window_ready then
					draw
				when {EP_PHONE}.event_tap then
					taps := taps + 1
					churn
					phone.log ("Hello from Eiffel: tap " + taps.out + " heap " + heap_mb.out + " MB, collections " + phone.collections.out + ", made " + made.out)
					draw
				when {EP_PHONE}.event_destroy then
					l_running := False
				else
						-- Window lost or other event: nothing to draw.
				end
			end
			phone.log ("Hello from Eiffel: loop ended")
		end

feature {NONE} -- Access

	phone: EP_PHONE
			-- Access to the screen and events.

	font: EP_PIXEL_FONT
			-- Eiffel-drawn 5x7 font.

	taps: INTEGER
			-- Number of taps so far.

	made: INTEGER
			-- Strings made by `churn' so far.

	backgrounds: ARRAY [INTEGER]
			-- Dark background colors, one per tap in turn.
		once
			Result := <<0x14161C, 0x1C2433, 0x1F2A1E, 0x2E1F2A, 0x2B2516>>
		end

feature {NONE} -- Drawing

	draw
			-- Paint the whole screen.
		local
			l_w, l_h, l_scale: INTEGER
			l_count: STRING
		do
			if phone.begin_frame then
				l_w := phone.width
				l_h := phone.height
				phone.fill (0, 0, l_w, l_h, backgrounds [(taps \\ backgrounds.count) + 1])
				l_scale := (l_w // (Title.count * 6 + 4)).max (1)
				centered (Title, l_h // 3, l_scale, 0xF2E6C9)
				l_count := "TAPS: " + taps.out
				centered (l_count, l_h // 3 + l_scale * 12, l_scale, 0x8FB8DE)
				centered ("HEAP: " + heap_mb.out + " MB", l_h // 3 + l_scale * 24, (l_scale * 2 // 3).max (1), 0x9CC28A)
				centered ("TAP ANYWHERE", l_h - l_h // 5, (l_scale // 2).max (1), 0x7A7F8C)
				phone.end_frame
			end
		end

	churn
			-- Make about 50 MB of short-lived strings, to prove the
			-- garbage collector reclaims memory on the phone.
		local
			i: INTEGER
			s: STRING
		do
			from i := 1 until i > 500_000 loop
				create s.make_filled ('x', 100)
				made := made + s.count // 100
				i := i + 1
			end
		end

	heap_mb: INTEGER_64
			-- Heap size in whole megabytes.
		do
			Result := phone.heap_size // 1_048_576
		end

	centered (a_text: STRING; a_y, a_scale, a_rgb: INTEGER)
			-- Draw `a_text' centered across the screen at `a_y'.
		do
			font.draw (phone, a_text, (phone.width - font.text_width (a_text, a_scale)) // 2, a_y, a_scale, a_rgb)
		end

	Title: STRING = "HELLO FROM EIFFEL"
			-- The greeting.

end
