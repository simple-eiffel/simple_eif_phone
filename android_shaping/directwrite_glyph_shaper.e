note
	description: "[
		Shaping on Android, through HarfBuzz. Keeps simple_shaping's DirectWrite name:
		see DIRECTWRITE_BIDI_RESOLVER. Glyphs come out in visual order, which is what
		the seam wants, and the cluster map is built to match: for each character, the
		first glyph of its cluster. A font that cannot be used gives boxes, and never raises.
	]"
	author: "Larry Rix"

class
	DIRECTWRITE_GLYPH_SHAPER

inherit
	GLYPH_SHAPER

create
	make

feature {NONE} -- Initialization

	make
		do
		end

feature -- Status

	last_shape_was_synthesized: BOOLEAN
			-- Was the last answer made up, because the font could not be used?

feature -- Operations

	shape (a_text: READABLE_STRING_32; a_item: SCRIPT_ITEM; a_font: SHAPING_FONT): SHAPED_ITEM
			-- <Precursor>
		require else
			range_only: a_item.start_index + a_item.count - 1 <= a_text.count
		local
			l_text: MANAGED_POINTER
			i, l_count, l_glyphs: INTEGER
		do
			l_glyphs := -1
			if a_font.has_backend_face then
				l_count := a_text.count
				create l_text.make (l_count * 4)
				from i := 1 until i > l_count loop
					l_text.put_natural_32 (a_text.code (i), (i - 1) * 4)
					i := i + 1
				end
				l_glyphs := c_shape (a_font.backend_face, a_font.pixel_size, l_text.item, l_count,
					a_item.start_index - 1, a_item.count, a_item.is_rtl.to_integer, a_item.script_code)
			end
			if l_glyphs > 0 then
				Result := shaped (a_item, a_font, l_glyphs)
				last_shape_was_synthesized := False
			else
				Result := boxes (a_item, a_font)
				last_shape_was_synthesized := True
			end
		end

feature {NONE} -- Implementation

	shaped (a_item: SCRIPT_ITEM; a_font: SHAPING_FONT; a_glyphs: INTEGER): SHAPED_ITEM
			-- HarfBuzz's answer as a SHAPED_ITEM.
		local
			l_ids, l_clusters, l_advances, l_x, l_y: MANAGED_POINTER
			l_glyphs: ARRAY [NATURAL_32]
			l_advance, l_x_offset, l_y_offset: ARRAY [REAL_64]
			l_map: ARRAY [INTEGER]
			i, c, l_first, l_cluster, l_missing, l_best: INTEGER
		do
			create l_ids.make (a_glyphs * 4)
			create l_clusters.make (a_glyphs * 4)
			create l_advances.make (a_glyphs * 8)
			create l_x.make (a_glyphs * 8)
			create l_y.make (a_glyphs * 8)
			c_shape_read (l_ids.item, l_clusters.item, l_advances.item, l_x.item, l_y.item)
			create l_glyphs.make_filled (0, 1, a_glyphs)
			create l_advance.make_filled (0.0, 1, a_glyphs)
			create l_x_offset.make_filled (0.0, 1, a_glyphs)
			create l_y_offset.make_filled (0.0, 1, a_glyphs)
			from i := 1 until i > a_glyphs loop
				l_glyphs [i] := l_ids.read_natural_32 ((i - 1) * 4)
				l_advance [i] := l_advances.read_real_64 ((i - 1) * 8).max (0.0)
				l_x_offset [i] := l_x.read_real_64 ((i - 1) * 8)
				l_y_offset [i] := l_y.read_real_64 ((i - 1) * 8)
				i := i + 1
			end
			create l_map.make_filled (1, 1, a_item.count)
			from c := 1 until c > a_item.count loop
					-- The cluster holding character c: the largest cluster value not after it.
				l_best := -1
				l_first := 1
				from i := 1 until i > a_glyphs loop
					l_cluster := l_clusters.read_integer_32 ((i - 1) * 4) - (a_item.start_index - 1)
					if l_cluster <= c - 1 and l_cluster > l_best then
						l_best := l_cluster
						l_first := i
					end
					i := i + 1
				end
				l_map [c] := l_first
				if l_glyphs [l_first] = 0 then
					l_missing := l_missing + 1
				end
				c := c + 1
			end
			create Result.make (a_font, a_item.count, l_glyphs, l_advance, l_x_offset, l_y_offset, l_map, l_missing)
		end

	boxes (a_item: SCRIPT_ITEM; a_font: SHAPING_FONT): SHAPED_ITEM
			-- One missing glyph per character, half a size wide.
		local
			l_glyphs: ARRAY [NATURAL_32]
			l_advance, l_zero: ARRAY [REAL_64]
			l_map: ARRAY [INTEGER]
			i: INTEGER
		do
			create l_glyphs.make_filled (0, 1, a_item.count)
			create l_advance.make_filled (a_font.pixel_size / 2.0, 1, a_item.count)
			create l_zero.make_filled (0.0, 1, a_item.count)
			create l_map.make_filled (1, 1, a_item.count)
			from i := 1 until i > a_item.count loop
				if a_item.is_rtl then
					l_map [i] := a_item.count - i + 1
				else
					l_map [i] := i
				end
				i := i + 1
			end
			create Result.make (a_font, a_item.count, l_glyphs, l_advance, l_zero, l_zero.twin, l_map, a_item.count)
		end

feature {NONE} -- C

	c_shape (a_font: POINTER; a_size: INTEGER; a_text: POINTER; a_text_count, a_start, a_count, a_rtl, a_script: INTEGER): INTEGER
		external "C inline use %"sephone_text.h%"" alias "return (EIF_INTEGER) st_shape($a_font, (int)$a_size, (const uint32_t *)$a_text, (int)$a_text_count, (int)$a_start, (int)$a_count, (int)$a_rtl, (int)$a_script);" end

	c_shape_read (a_glyphs, a_clusters, a_advances, a_x, a_y: POINTER)
		external "C inline use %"sephone_text.h%"" alias "st_shape_read((uint32_t *)$a_glyphs, (int32_t *)$a_clusters, (double *)$a_advances, (double *)$a_x, (double *)$a_y);" end

end
