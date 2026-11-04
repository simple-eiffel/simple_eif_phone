note
	description: "[
		Measures what the touch pad pays per touch and per frame, at phone
		size (1080 x 2400, 16 px brush). Each figure goes to the log as a BENCH
		line and onto the screen, so a phone needs no cable or pairing: install
		it, wait for DONE, take a screenshot.
		The on-screen labels use only the letters PAD_FONT can draw.
	]"
	author: "Larry Rix"

class
	TOUCH_BENCH_APP

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Wait for the window, run every measure, show the results.
		do
			create phone.make
			create ballast.make (64)
			create lines.make (24)
			create font
			create screen_canvas.make (1, 1)
			from until phone.last_event.kind = Kind_window_ready loop
				phone.wait_for_event
			end
			drain
			lines.extend ("RUNNING")
			paint
			lines.wipe_out
			lines.extend ("EIFFEL PHONE RESULTS")
			add_result ("SCREEN " + phone.metrics.width.out, phone.metrics.height.out)
			add_result ("DPI", phone.metrics.density_dpi.out)
			measure_delivery (1, "TOUCH 1 US")
			measure_delivery (5, "TOUCH 5 US")
			measure_line
			measure_present
			add_ballast (40_000)
			measure_delivery (5, "TOUCH 5 BIG US")
			measure_save_load
			measure_redraw (2_000)
			measure_rescue
			lines.extend ("DONE")
			phone.log.info ("BENCH done")
			paint
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				inspect phone.last_event.kind
				when Kind_window_ready, Kind_window_resized, Kind_redraw_needed, Kind_content_rect_changed then
					paint
				else
				end
			end
		end

feature {NONE} -- Access

	phone: SIMPLE_EIF_PHONE

	ballast: ARRAYED_LIST [PAD_STROKE]
			-- Strokes held alive, like a big restored drawing.

	lines: ARRAYED_LIST [STRING]
			-- What the screen shows.

	font: PAD_FONT

	screen_canvas: PAD_CANVAS

	Brush: INTEGER = 16

feature {NONE} -- Results

	add_result (a_label, a_value: STRING)
			-- Log and show one figure.
		do
			lines.extend (a_label + ": " + a_value)
			phone.log.info ("BENCH " + a_label + ": " + a_value)
		end

	paint
			-- Show `lines'.
		local
			l_scale, y: INTEGER
		do
			if phone.screen.has_window and phone.metrics.width > 0 and phone.metrics.height > 0 then
				if screen_canvas.width /= phone.metrics.width or screen_canvas.height /= phone.metrics.height then
					create screen_canvas.make (phone.metrics.width, phone.metrics.height)
				end
				screen_canvas.clear (0x14161C)
				l_scale := (phone.metrics.width // 170).max (1).min ((phone.metrics.height - phone.metrics.inset_top) // (lines.count.max (1) * 10 + 10))
				l_scale := l_scale.max (1)
				y := phone.metrics.inset_top + l_scale * 6
				across lines as ic loop
					font.draw (screen_canvas, ic, l_scale * 4, y, l_scale, 0xF2E6C9)
					y := y + l_scale * 10
				end
				phone.screen.begin_frame
				if phone.screen.in_frame then
					phone.screen.present_argb (screen_canvas.pixels.item, screen_canvas.width, screen_canvas.height, screen_canvas.stride)
					phone.screen.end_frame
				end
			end
		end

feature {NONE} -- Measures

	measure_delivery (a_fingers: INTEGER; a_label: STRING)
			-- Microseconds to deliver one touch move through the real path.
		local
			i, r: INTEGER
			t: INTEGER_64
		do
			from i := 0 until i = a_fingers loop
				c_test_push (Kind_touch_down, i, 100 + i, 100, 0)
				i := i + 1
			end
			drain
			t := now_us
			from r := 1 until r > 8 loop
				from i := 0 until i = 500 loop
					c_test_push (Kind_touch_move, i \\ a_fingers, 100 + i, 200 + r, 0)
					i := i + 1
				end
				drain
				r := r + 1
			end
			t := now_us - t
			add_result (a_label, (t // 4000).out)
			from i := 0 until i = a_fingers loop
				c_test_push (Kind_touch_up, i, 100, 100, 0)
				i := i + 1
			end
			drain
		end

	measure_line
			-- Microseconds for one 16 px stroke segment.
		local
			c: PAD_CANVAS
			i: INTEGER
			t: INTEGER_64
		do
			create c.make (1080, 2400)
			t := now_us
			from i := 0 until i = 1000 loop
				c.line (200, 100 + i * 2, 216, 100 + i * 2, Brush, 0xF2B84B)
				i := i + 1
			end
			t := now_us - t
			add_result ("SEGMENT US", (t // 1000).out)
		end

	measure_present
			-- Microseconds for each part of a full frame (NFR-001; RB-13 for the lock).
		local
			c: PAD_CANVAS
			i, n: INTEGER
			t, l_begin, l_copy, l_end, l_worst: INTEGER_64
		do
			create c.make (phone.metrics.width, phone.metrics.height)
			from i := 0 until i = 60 loop
				t := now_us
				phone.screen.begin_frame
				l_begin := l_begin + now_us - t
				if phone.screen.in_frame then
					t := now_us
					phone.screen.present_argb (c.pixels.item, c.width, c.height, c.stride)
					t := now_us - t
					l_copy := l_copy + t
					l_worst := l_worst.max (t)
					t := now_us
					phone.screen.end_frame
					l_end := l_end + now_us - t
					n := n + 1
				end
				i := i + 1
			end
			n := n.max (1)
			add_result ("FRAME BEGIN US", (l_begin // n).out)
			add_result ("FRAME COPY US", (l_copy // n).out)
			add_result ("FRAME COPY MOST US", l_worst.out)
			add_result ("FRAME END US", (l_end // n).out)
		end

	measure_save_load
			-- Milliseconds to save and reload 12,000 points, as the pad does.
		local
			f: PLAIN_TEXT_FILE
			l_path: STRING
			l_parts: LIST [STRING]
			l_loaded, i: INTEGER
			t: INTEGER_64
		do
			l_path := phone.storage.internal_path + "/bench.txt"
			t := now_us
			create f.make_create_read_write (l_path)
			across ballast as ic loop
				if @ic.cursor_index <= 120 then
					f.put_string (ic.rgb.out)
					from i := 1 until i > ic.count loop
						f.put_string (" " + ic.xs [i].out + " " + ic.ys [i].out)
						i := i + 1
					end
					f.put_new_line
				end
			end
			f.close
			add_result ("STORE 12000 MS", ((now_us - t) // 1000).out)
			t := now_us
			create f.make_with_name (l_path)
			f.open_read
			from until f.end_of_file or else not f.file_readable loop
				f.read_line
				l_parts := f.last_string.split (' ')
				from i := 2 until i + 1 > l_parts.count loop
					if l_parts [i].is_integer and l_parts [i + 1].is_integer then
						l_loaded := l_loaded + 1
					end
					i := i + 2
				end
			end
			f.close
			add_result ("READ " + l_loaded.out + " MS", ((now_us - t) // 1000).out)
		end

	measure_redraw (a_points: INTEGER)
			-- Milliseconds to redraw a drawing of `a_points' points.
		local
			c: PAD_CANVAS
			l_stroke: PAD_STROKE
			i: INTEGER
			t: INTEGER_64
		do
			create c.make (1080, 2400)
			create l_stroke.make (0xF2B84B)
			from i := 0 until i = a_points loop
				l_stroke.extend (100 + (i * 12) \\ 800, 100 + (i // 60) * 7 \\ 2000)
				i := i + 1
			end
			t := now_us
			c.clear (0x14161C)
			c.dab (l_stroke.xs.first, l_stroke.ys.first, Brush, l_stroke.rgb)
			from i := 2 until i > l_stroke.count loop
				c.line (l_stroke.xs [i - 1], l_stroke.ys [i - 1], l_stroke.xs [i], l_stroke.ys [i], Brush, l_stroke.rgb)
				i := i + 1
			end
			t := now_us - t
			add_result ("REDRAW " + a_points.out + " MS", (t // 1000).out)
		end

	measure_rescue
			-- Contract violations caught by rescue on this processor. The
			-- src cluster keeps its preconditions on for this.
		local
			i, l_caught: INTEGER
			t: INTEGER_64
		do
			t := now_us
			from i := 1 until i > 1000 loop
				if caught_violation (i) = i then
					l_caught := l_caught + 1
				end
				i := i + 1
			end
			t := now_us - t
			add_result ("RESCUE OF 1000", l_caught.out)
			add_result ("RESCUE US", (t // 1000).out)
		end

	caught_violation (a_value: INTEGER): INTEGER
			-- `a_value', reached only by way of a caught precondition violation.
		local
			l_retried: BOOLEAN
		do
			if l_retried then
				Result := a_value
			else
				must_be_positive (-a_value)
			end
		rescue
			l_retried := True
			retry
		end

	must_be_positive (a_number: INTEGER)
			-- Nothing, for a positive `a_number'.
		require
			positive: a_number > 0
		do
		end

	add_ballast (a_points: INTEGER)
			-- Hold `a_points' points in 100-point strokes.
		local
			i: INTEGER
			s: PAD_STROKE
		do
			create s.make (0x5EC4E8)
			from i := 0 until i = a_points loop
				if i \\ 100 = 0 then
					create s.make (0x5EC4E8)
					ballast.extend (s)
				end
				s.extend (i, i)
				i := i + 1
			end
		end

	drain
			-- Take everything queued.
		do
			from phone.poll_event (0) until phone.last_event.is_none loop
				phone.poll_event (0)
			end
		end

feature {NONE} -- Externals

	now_us: INTEGER_64
			-- Microseconds on a steady clock.
		external
			"C inline use <time.h>"
		alias
			"struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (EIF_INTEGER_64) ts.tv_sec * 1000000 + ts.tv_nsec / 1000;"
		end

	c_test_push (a_kind, a_id, a_x, a_y, a_code: INTEGER)
		external
			"C inline use %"sephone.h%""
		alias
			"sephone_test_push((int)$a_kind, (int)$a_id, (int)$a_x, (int)$a_y, (int)$a_code);"
		end

end
