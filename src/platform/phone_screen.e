note
	description: "[
		The window's pixel buffer, one frame at a time.
		`present_argb' copies a cairo-format ARGB32 image (native-endian
		0xAARRGGBB words) to the screen at (0,0), clipped. It is the one
		seam a GPU path would replace (research D-005).
		`has_window' is the live truth from Android; see SIMPLE_EIF_PHONE's
		invariant for why it matches the lifecycle model at every delivery.
	]"
	author: "Larry Rix"

class
	PHONE_SCREEN

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
			-- Screen access, not in a frame.
		do
		ensure
			not_in_frame: not in_frame
		end

feature -- Status

	has_window: BOOLEAN
			-- Does Android currently give us a window?
		do
			Result := c_window_exists
		end

	in_frame: BOOLEAN
			-- Is the buffer locked for drawing?

	width: INTEGER
			-- Window width in pixels (0 without a window).
		do
			Result := c_window_width.max (0)
		ensure
			non_negative: Result >= 0
		end

	height: INTEGER
			-- Window height in pixels (0 without a window).
		do
			Result := c_window_height.max (0)
		ensure
			non_negative: Result >= 0
		end

feature -- Frame

	begin_frame
			-- Lock the buffer. Android may refuse: check `in_frame' after.
		require
			has_window: has_window
			not_nested: not in_frame
		do
			in_frame := c_frame_lock
		ensure
			sized_when_locked: in_frame implies (width > 0 and height > 0)
		end

	fill_rect (a_x, a_y, a_w, a_h, a_rgb: INTEGER)
			-- Fill a rectangle with color `a_rgb' (0xRRGGBB), clipped to the window.
		require
			in_frame: in_frame
			size_ok: a_w >= 0 and a_h >= 0
			rgb_ok: 0 <= a_rgb and a_rgb <= 0xFFFFFF
		do
			c_frame_fill (a_x, a_y, a_w, a_h, a_rgb)
		ensure
			still_in_frame: in_frame
		end

	present_argb (a_pixels: POINTER; a_width, a_height, a_stride: INTEGER)
			-- Copy an ARGB32 image (`a_stride' bytes per row) to (0,0), clipped.
		require
			in_frame: in_frame
			pixels_exist: a_pixels /= default_pointer
			size_ok: a_width > 0 and a_height > 0
			stride_ok: a_stride >= a_width * 4
		do
			c_frame_present_argb (a_pixels, a_width, a_height, a_stride)
		ensure
			still_in_frame: in_frame
		end

	present_argb_at (a_pixels: POINTER; a_width, a_height, a_stride, a_x, a_y: INTEGER)
			-- Copy an ARGB32 image to (`a_x', `a_y'), clipped.
		require
			in_frame: in_frame
			pixels_exist: a_pixels /= default_pointer
			size_ok: a_width > 0 and a_height > 0
			stride_ok: a_stride >= a_width * 4
			place_ok: a_x >= 0 and a_y >= 0
		do
			c_frame_present_argb_at (a_pixels, a_width, a_height, a_stride, a_x, a_y)
		ensure
			still_in_frame: in_frame
		end

	end_frame
			-- Unlock and show the frame.
		require
			in_frame: in_frame
		do
			c_frame_unlock
			in_frame := False
		ensure
			not_in_frame: not in_frame
		end

feature -- Testing

	peek (a_x, a_y: INTEGER): NATURAL_32
			-- Window buffer word at (`a_x', `a_y'); for byte-order tests only.
		require
			in_frame: in_frame
			inside: 0 <= a_x and a_x < width and 0 <= a_y and a_y < height
		do
			Result := c_frame_peek (a_x, a_y)
		end

invariant
	frame_needs_window: in_frame implies has_window

end
