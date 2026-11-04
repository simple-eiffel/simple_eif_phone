note
	description: "[
		Window size, density and the content rectangle: the area not
		covered by the status and navigation bars (or the on-screen
		keyboard). Insets are derived from it. Values are read from
		Android at `refresh'; SIMPLE_EIF_PHONE refreshes on window,
		configuration and content-rect events.
		Font scale is not here: the NDK has no getter for it (spec 03 A-6).
	]"
	author: "Larry Rix"

class
	PHONE_METRICS

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
			-- All zero until the first `refresh'.
		do
			create content_rect.make (0, 0, 0, 0)
		ensure
			zero: width = 0 and height = 0 and density_dpi = 0
		end

feature -- Access

	width, height: INTEGER
			-- Window size in pixels.

	density_dpi: INTEGER
			-- Screen density in dots per inch.

	content_rect: PHONE_RECT
			-- Area where content is seen by the user.

	layout_is_rtl: BOOLEAN
			-- Is the phone's layout direction right-to-left?

	inset_left: INTEGER
			-- Pixels covered on the left.
		do
			Result := content_rect.left.max (0)
		ensure
			non_negative: Result >= 0
		end

	inset_top: INTEGER
			-- Pixels covered at the top (status bar).
		do
			Result := content_rect.top.max (0)
		ensure
			non_negative: Result >= 0
		end

	inset_right: INTEGER
			-- Pixels covered on the right.
		do
			Result := (width - content_rect.right).max (0)
		ensure
			non_negative: Result >= 0
		end

	inset_bottom: INTEGER
			-- Pixels covered at the bottom (navigation bar, keyboard).
		do
			Result := (height - content_rect.bottom).max (0)
		ensure
			non_negative: Result >= 0
		end

	dp (a_dp: INTEGER): INTEGER
			-- `a_dp' density-independent pixels in real pixels (160 dpi baseline).
		require
			non_negative: a_dp >= 0
		do
			Result := (a_dp * density_dpi + 80) // 160
		ensure
			non_negative: Result >= 0
		end

feature -- Update

	refresh
			-- Re-read every value from Android. The content rectangle is
			-- clamped to the window; an empty one from Android (none reported
			-- yet) means the whole window (Phase 2 RB-4).
		local
			l, t, r, b: INTEGER
		do
			width := c_window_width.max (0)
			height := c_window_height.max (0)
			density_dpi := c_density
			layout_is_rtl := c_rtl
				-- Clamp Android's rectangle into the window.
			l := c_content_left.max (0).min (width)
			t := c_content_top.max (0).min (height)
			r := c_content_right.min (width).max (l)
			b := c_content_bottom.min (height).max (t)
			if r <= l or b <= t then
					-- Nothing reported yet (or degenerate): use the whole window.
				l := 0
				t := 0
				r := width
				b := height
			end
			create content_rect.make (l, t, r, b)
		ensure
			clamped_across: content_rect.left >= 0 and content_rect.right <= width
			clamped_down: content_rect.top >= 0 and content_rect.bottom <= height
			empty_is_full: (width > 0 and height > 0) implies (content_rect.width > 0 and content_rect.height > 0)
			density_known: (width > 0 and height > 0) implies (120 <= density_dpi and density_dpi <= 640)
		end

invariant
	sizes_non_negative: width >= 0 and height >= 0 and density_dpi >= 0
	insets_fit_across: width > 0 implies inset_left + inset_right <= width
	insets_fit_down: height > 0 implies inset_top + inset_bottom <= height
	content_inside_across: width > 0 implies (content_rect.left >= 0 and content_rect.right <= width)
	content_inside_down: height > 0 implies (content_rect.top >= 0 and content_rect.bottom <= height)

end
