note
	description: "[
		Spike-only access to the Android screen and events through the
		C glue in eif_phone.h. Seed of the simple_eif_phone library.
	]"

class
	EP_PHONE

feature -- Events

	event_none: INTEGER = 0
	event_window_ready: INTEGER = 1
	event_window_lost: INTEGER = 2
	event_destroy: INTEGER = 3
	event_tap: INTEGER = 4

	next_event: INTEGER
			-- Wait for the next event and return its code.
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER) ep_next_event();"
		end

	tap_x: INTEGER
			-- X of the last tap, in pixels.
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER) ep_tap_x();"
		end

	tap_y: INTEGER
			-- Y of the last tap, in pixels.
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER) ep_tap_y();"
		end

feature -- Screen

	width: INTEGER
			-- Screen width in pixels (0 if no window).
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER) ep_width();"
		end

	height: INTEGER
			-- Screen height in pixels (0 if no window).
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER) ep_height();"
		end

	begin_frame: BOOLEAN
			-- Lock the screen for drawing. False if there is no window.
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_BOOLEAN) ep_begin_frame();"
		end

	fill (a_x, a_y, a_w, a_h, a_rgb: INTEGER)
			-- Fill a rectangle with color `a_rgb' (0xRRGGBB), clipped to the screen.
		external
			"C inline use %"eif_phone.h%""
		alias
			"ep_fill((int)$a_x, (int)$a_y, (int)$a_w, (int)$a_h, (int)$a_rgb);"
		end

	end_frame
			-- Show what was drawn.
		external
			"C inline use %"eif_phone.h%""
		alias
			"ep_end_frame();"
		end

feature -- Memory

	heap_size: INTEGER_64
			-- Bytes in the garbage-collected heap.
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER_64) ep_heap_size();"
		end

	collections: INTEGER_64
			-- Number of garbage collections so far.
		external
			"C inline use %"eif_phone.h%""
		alias
			"return (EIF_INTEGER_64) ep_gc_count();"
		end

feature -- Log

	log (a_message: READABLE_STRING_8)
			-- Write `a_message' to the Android log (tag "Eiffel").
		local
			l_c: C_STRING
		do
			create l_c.make (a_message)
			c_log (l_c.item)
		end

feature {NONE} -- Implementation

	c_log (a_text: POINTER)
		external
			"C inline use %"eif_phone.h%""
		alias
			"ep_log((const char *)$a_text);"
		end

end
