note
	description: "[
		An ARGB32 image in memory (the layout cairo uses), shown with
		PHONE_SCREEN.present_argb. Brush dabs are round.
	]"
	author: "Larry Rix"

class
	PAD_CANVAS

create
	make

feature {NONE} -- Initialization

	make (a_width, a_height: INTEGER)
			-- A blank canvas of that size.
		require
			size_ok: a_width > 0 and a_height > 0
		do
			width := a_width
			height := a_height
			create pixels.make (a_width * a_height * 4)
		ensure
			width_set: width = a_width
			height_set: height = a_height
		end

feature -- Access

	width, height: INTEGER

	pixels: MANAGED_POINTER
			-- One 0xAARRGGBB word per pixel, rows `stride' bytes apart.

	stride: INTEGER
			-- Bytes per row.
		do
			Result := width * 4
		end

feature -- Drawing

	clear (a_rgb: INTEGER)
			-- Fill everything with `a_rgb'. One row by hand, then copy it down.
		local
			x, y: INTEGER
			l_word: NATURAL_32
		do
			l_word := word (a_rgb)
			from x := 0 until x = width loop
				pixels.put_natural_32 (l_word, x * 4)
				x := x + 1
			end
			from y := 1 until y = height loop
				(pixels.item + y * stride).memory_copy (pixels.item, stride)
				y := y + 1
			end
		end

	dab (a_x, a_y, a_radius, a_rgb: INTEGER)
			-- A round dab centered at (`a_x', `a_y'), clipped to the canvas.
		require
			radius_ok: a_radius > 0
		local
			x, y, l_dy2, l_r2: INTEGER
			l_word: NATURAL_32
		do
			l_word := word (a_rgb)
			l_r2 := a_radius * a_radius
			from y := (a_y - a_radius).max (0) until y > (a_y + a_radius).min (height - 1) loop
				l_dy2 := (y - a_y) * (y - a_y)
				from x := (a_x - a_radius).max (0) until x > (a_x + a_radius).min (width - 1) loop
					if (x - a_x) * (x - a_x) + l_dy2 <= l_r2 then
						pixels.put_natural_32 (l_word, y * stride + x * 4)
					end
					x := x + 1
				end
				y := y + 1
			end
		end

	line (a_x1, a_y1, a_x2, a_y2, a_radius, a_rgb: INTEGER)
			-- Dabs from point 1 to point 2, close enough to look continuous.
		require
			radius_ok: a_radius > 0
		local
			l_steps, i: INTEGER
		do
			l_steps := ((a_x2 - a_x1).abs.max ((a_y2 - a_y1).abs) // (a_radius // 2).max (1)).max (1)
			from i := 0 until i > l_steps loop
				dab (a_x1 + (a_x2 - a_x1) * i // l_steps, a_y1 + (a_y2 - a_y1) * i // l_steps, a_radius, a_rgb)
				i := i + 1
			end
		end

	block (a_x, a_y, a_size, a_rgb: INTEGER)
			-- A filled square (the hint text's pixels), clipped.
		local
			x, y: INTEGER
			l_word: NATURAL_32
		do
			l_word := word (a_rgb)
			from y := a_y.max (0) until y >= (a_y + a_size).min (height) loop
				from x := a_x.max (0) until x >= (a_x + a_size).min (width) loop
					pixels.put_natural_32 (l_word, y * stride + x * 4)
					x := x + 1
				end
				y := y + 1
			end
		end

feature {NONE} -- Implementation

	word (a_rgb: INTEGER): NATURAL_32
			-- Opaque ARGB word for `a_rgb'.
		do
			Result := {NATURAL_32} 0xFF000000 + a_rgb.to_natural_32
		end

invariant
	size_ok: width > 0 and height > 0
	pixels_fit: pixels.count = width * height * 4

end
