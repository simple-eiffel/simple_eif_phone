note
	description: "[
		A tiny 5x7 block font drawn by Eiffel with filled squares.
		Spike-only: real text will come from the shaping stack later.
		Each glyph is 7 rows of 5 cells; '#' is ink, '.' is blank.
	]"

class
	PAD_FONT

feature -- Measurement

	text_width (a_text: STRING; a_scale: INTEGER): INTEGER
			-- Width in pixels of `a_text' at `a_scale' (6 cells per glyph, no trailing gap).
		do
			if a_text.count > 0 then
				Result := (a_text.count * 6 - 1) * a_scale
			end
		end

feature -- Drawing

	draw (a_canvas: PAD_CANVAS; a_text: STRING; a_x, a_y, a_scale, a_rgb: INTEGER)
			-- Draw `a_text' with its top-left corner at (`a_x', `a_y').
		local
			i, l_row, l_col, l_x: INTEGER
			l_glyph: STRING
		do
			l_x := a_x
			from i := 1 until i > a_text.count loop
				l_glyph := glyph (a_text [i])
				from l_row := 0 until l_row > 6 loop
					from l_col := 0 until l_col > 4 loop
						if l_glyph [l_row * 5 + l_col + 1] = '#' then
							a_canvas.block (l_x + l_col * a_scale, a_y + l_row * a_scale, a_scale, a_rgb)
						end
						l_col := l_col + 1
					end
					l_row := l_row + 1
				end
				l_x := l_x + 6 * a_scale
				i := i + 1
			end
		end

feature {NONE} -- Glyphs

	glyph (a_c: CHARACTER): STRING
			-- Cells for `a_c' (blank if unknown).
		do
			if attached glyphs.item (a_c) as al_g then
				Result := al_g
			else
				Result := Blank
			end
		end

	Blank: STRING = "..................................."

	glyphs: HASH_TABLE [STRING, CHARACTER]
			-- All known glyphs.
		once
			create Result.make (48)
			Result.put (Blank, ' ')
			Result.put ("#...##...##...#######...##...##...#", 'H')
			Result.put ("######....#....####.#....#....#####", 'E')
			Result.put ("#....#....#....#....#....#....#####", 'L')
			Result.put (".###.#...##...##...##...##...#.###.", 'O')
			Result.put ("######....#....####.#....#....#....", 'F')
			Result.put ("####.#...##...#####.#.#..#..#.#...#", 'R')
			Result.put ("#...###.###.#.##.#.##...##...##...#", 'M')
			Result.put (".###...#....#....#....#....#...###.", 'I')
			Result.put (".###.#...##...#######...##...##...#", 'A')
			Result.put ("####.#...##...#####.#....#....#....", 'P')
			Result.put ("#####..#....#....#....#....#....#..", 'T')
			Result.put (".#####....#.....###.....#....#####.", 'S')
			Result.put ("#...###..##.#.##.#.##..###...##...#", 'N')
			Result.put (".###.#...##....#....#....#...#.###.", 'C')
			Result.put ("#...##...##...##...##...##...#.###.", 'U')
			Result.put ("#...##...#.#.#...#....#....#....#..", 'Y')
			Result.put ("#...##...##...##.#.##.#.###.###...#", 'W')
			Result.put ("####.#...##...#####.#...##...#####.", 'B')
			Result.put ("####.#...##...##...##...##...#####.", 'D')
			Result.put (".###.#...##....#.####...##...#.###.", 'G')
			Result.put (".###.#...##..###.#.###..##...#.###.", '0')
			Result.put ("..#...##....#....#....#....#...###.", '1')
			Result.put (".###.#...#....#...#...#...#...#####", '2')
			Result.put ("#####...#...#.....#.....##...#.###.", '3')
			Result.put ("...#...##..#.#.#..#.#####...#....#.", '4')
			Result.put ("######....####.....#....##...#.###.", '5')
			Result.put ("..##..#...#....####.#...##...#.###.", '6')
			Result.put ("#####....#...#...#...#....#....#...", '7')
			Result.put (".###.#...##...#.###.#...##...#.###.", '8')
			Result.put (".###.#...##...#.####....#...#..##..", '9')
			Result.put (".......#....#.........#....#.......", ':')
		end

invariant
	blank_is_35: Blank.count = 35

end
