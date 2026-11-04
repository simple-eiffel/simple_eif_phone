note
	description: "[
		Creates and caches SHAPING_FONTs, on Android. Same interface as simple_shaping's
		class of this name. A family is a file in /system/fonts, or one the app loaded.
		The Windows family names simple_shaping asks for by default map to the
		nearest font on the phone: Android's usual file if it is there, then a file
		named for the kind of font, then any file that really draws the script.
	]"
	author: "Larry Rix"

class
	FONT_REGISTRY

inherit
	SHAPING_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make
		do
			create fonts.make (8)
			create family_verdicts.make (8)
			create private_files.make (2)
			create found_files.make (8)
			fonts_folder := System_fonts_folder
		ensure
			registry_empty: count = 0
		end

feature -- Access

	count: INTEGER
		do
			Result := fonts.count
		ensure
			non_negative: Result >= 0
		end

	font (a_family: READABLE_STRING_32; a_weight: INTEGER; a_italic: BOOLEAN;
			a_pixel_size: INTEGER): SHAPING_FONT
		require
			family_not_empty: not a_family.is_empty
			weight_range: a_weight >= 1 and a_weight <= 1000
			size_positive: a_pixel_size > 0
		local
			l_key: STRING_32
		do
			l_key := registry_key (a_family, a_weight, a_italic, a_pixel_size)
			if attached fonts.item (l_key) as al_font then
				Result := al_font
			else
				create Result.make (a_family, a_weight, a_italic, a_pixel_size, Current)
				fonts.put (Result, l_key)
			end
			if not Result.is_realization_attempted then
				Result.realize (file_for (a_family, a_weight, a_italic))
			end
		ensure
			owned: Result.registry = Current
			realized_on_first_use: Result.is_realization_attempted
		end

	registry_key (a_family: READABLE_STRING_32; a_weight: INTEGER; a_italic: BOOLEAN;
			a_pixel_size: INTEGER): STRING_32
		require
			family_not_empty: not a_family.is_empty
		do
			create Result.make (a_family.count + 12)
			Result.append_string_general (a_family.as_lower)
			Result.append_character ('|')
			Result.append_string_general (a_weight.out)
			Result.append_character ('|')
			if a_italic then
				Result.append_character ('1')
			else
				Result.append_character ('0')
			end
			Result.append_character ('|')
			Result.append_string_general (a_pixel_size.out)
		ensure
			never_empty: not Result.is_empty
		end

	family_exists (a_family: READABLE_STRING_32): BOOLEAN
		require
			family_not_empty: not a_family.is_empty
		local
			l_key: STRING_32
		do
			l_key := a_family.as_string_32.as_lower
			if family_verdicts.has (l_key) then
				Result := family_verdicts.item (l_key)
			else
				Result := not file_for (a_family, 400, False).is_empty
				family_verdicts.put (Result, l_key)
			end
		end

	fonts_folder: STRING_8
			-- Where fonts are looked for, ending in a slash.

	verdict_count: INTEGER
		do
			Result := family_verdicts.count
		ensure
			non_negative: Result >= 0
		end

feature -- Commands

	set_fonts_folder (a_folder: READABLE_STRING_8)
			-- Look for fonts in `a_folder', which ends in a slash.
		require
			ends_in_slash: not a_folder.is_empty and then a_folder [a_folder.count] = '/'
		do
			create fonts_folder.make_from_string (a_folder)
			found_files.wipe_out
			forget_family_verdicts
		ensure
			set: fonts_folder.same_string (a_folder)
		end

	load_private_font_file (a_path: READABLE_STRING_GENERAL): INTEGER
			-- Make the file's name, without its extension, a family.
		require
			path_not_empty: not a_path.is_empty
		local
			l_path: PATH
			l_name: STRING_32
		do
			create l_path.make_from_string (a_path)
			if (create {RAW_FILE}.make_with_path (l_path)).exists and then attached l_path.entry as al_entry then
				l_name := al_entry.name.to_string_32
				if l_name.has ('.') then
					l_name.keep_head (l_name.last_index_of ('.', l_name.count) - 1)
				end
				private_files.force (a_path.to_string_8, l_name.as_lower)
				Result := 1
			end
			forget_family_verdicts
		ensure
			non_negative: Result >= 0
			verdicts_forgotten: verdict_count = 0
		end

	unload_private_font_file (a_path: READABLE_STRING_GENERAL): BOOLEAN
		require
			path_not_empty: not a_path.is_empty
		do
			forget_family_verdicts
		ensure
			verdicts_forgotten: verdict_count = 0
		end

	forget_family_verdicts
		do
			family_verdicts.wipe_out
		ensure
			forgotten: verdict_count = 0
		end

	dispose_all
		do
			across fonts as f loop
				f.dispose
			end
			fonts.wipe_out
		ensure
			count_zero: count = 0
		end

feature -- Model queries (simple_mml)

	fonts_model: MML_MAP [STRING_32, SHAPING_FONT]
		do
			create Result
			across fonts as ic loop
				Result := Result.updated (@ic.key, ic)
			end
		end

feature {NONE} -- Implementation

	fonts: HASH_TABLE [SHAPING_FONT, STRING_32]

	family_verdicts: HASH_TABLE [BOOLEAN, STRING_32]

	private_files: HASH_TABLE [STRING_8, STRING_32]
			-- Fonts the app loaded, by family.

	file_for (a_family: READABLE_STRING_32; a_weight: INTEGER; a_italic: BOOLEAN): STRING_8
			-- The font file for `a_family'; empty if there is none.
		local
			l_family: STRING_32
			l_bold, l_style: STRING_8
		do
			l_family := a_family.as_string_32.as_lower
			if a_weight >= 600 then
				l_bold := "Bold"
			else
				l_bold := "Regular"
			end
			if a_italic then
				l_style := if a_weight >= 600 then "BoldItalic" else "Italic" end
			else
				l_style := l_bold
			end
			if attached private_files.item (l_family) as al_file then
				Result := al_file
			elseif l_family.same_string_general ("segoe ui") or l_family.same_string_general ("arial")
				or l_family.same_string_general ("roboto")
			then
				Result := first_there ("Roboto-Regular.ttf", "RobotoStatic-Regular.ttf")
				if Result.is_empty then
					Result := found (<<<<"roboto">>, <<"sans">>, <<>>>>, Latin_sample, a_weight >= 600)
				end
			elseif l_family.same_string_general ("noto sans hebrew") then
				Result := first_there ("NotoSansHebrew-" + l_bold + ".ttf", "NotoSansHebrew-Regular.ttf")
				if Result.is_empty then
					Result := found (<<<<"hebrew", "sans">>, <<"hebrew">>, <<>>>>, Hebrew_sample, a_weight >= 600)
				end
			elseif l_family.same_string_general ("noto serif hebrew") then
				Result := first_there ("NotoSerifHebrew-" + l_bold + ".ttf", "NotoSerifHebrew-Regular.ttf")
				if Result.is_empty then
					Result := found (<<<<"hebrew", "serif">>, <<"hebrew">>, <<>>>>, Hebrew_sample, a_weight >= 600)
				end
			elseif l_family.same_string_general ("times new roman") or l_family.same_string_general ("palatino linotype") then
				Result := first_there ("NotoSerif-" + l_style + ".ttf", "NotoSerif-Regular.ttf")
				if Result.is_empty then
					Result := found (<<<<"serif">>, <<>>>>, Latin_sample, a_weight >= 600)
				end
			elseif l_family.same_string_general ("consolas") or l_family.same_string_general ("courier new") then
				Result := first_there ("DroidSansMono.ttf", "CutiveMono.ttf")
				if Result.is_empty then
					Result := found (<<<<"mono">>, <<>>>>, Latin_sample, a_weight >= 600)
				end
			else
				create Result.make_empty
			end
		end

	first_there (a_first, a_second: READABLE_STRING_8): STRING_8
			-- The path of whichever of the two is in the system's fonts; empty if neither.
		do
			create Result.make_empty
			if (create {RAW_FILE}.make_with_name (fonts_folder + a_first)).exists then
				Result := fonts_folder + a_first
			elseif (create {RAW_FILE}.make_with_name (fonts_folder + a_second)).exists then
				Result := fonts_folder + a_second
			end
		end

	found (a_word_lists: ARRAY [ARRAY [READABLE_STRING_8]]; a_code: NATURAL_32; a_bold: BOOLEAN): STRING_8
			-- The first file that matches a list of words and draws `a_code', trying the
			-- lists in order; empty if there is none. An empty list matches every file.
			-- Each search is kept, since one may open every font on the phone.
		local
			l_key: STRING_8
			i: INTEGER
		do
			l_key := a_code.out + "|" + a_bold.out + "|" + a_word_lists.count.out
			across a_word_lists as ic loop
				across ic as jc loop
					l_key.append_character ('|')
					l_key.append_string_general (jc)
				end
			end
			if attached found_files.item (l_key) as al_file then
				Result := al_file
			else
				create Result.make_empty
				from i := a_word_lists.lower until i > a_word_lists.upper or not Result.is_empty loop
					Result := best_file (a_word_lists [i], a_code, a_bold)
					i := i + 1
				end
				found_files.put (Result, l_key)
			end
		end

	best_file (a_words: ARRAY [READABLE_STRING_8]; a_code: NATURAL_32; a_bold: BOOLEAN): STRING_8
			-- The file named with all of `a_words' that draws `a_code': the weight wanted
			-- first, then the first by name. Empty if there is none.
		local
			l_name: STRING_8
			l_score, l_best: INTEGER
			l_path: C_STRING
		do
			create Result.make_empty
			l_best := -1
			across font_files as ic loop
				l_name := ic.as_lower
				if across a_words as jc all l_name.has_substring (jc) end
					and then not l_name.has_substring ("italic") and then not l_name.has_substring ("emoji")
				then
					l_score := if l_name.has_substring (if a_bold then "bold" else "regular" end) then 1 else 0 end
					if l_score > l_best or (l_score = l_best and ic < Result) then
						create l_path.make (fonts_folder + ic)
						if c_covers (l_path.item, a_code) /= 0 then
							l_best := l_score
							Result := fonts_folder + ic
							Result.remove_head (fonts_folder.count)
						end
					end
				end
			end
			if not Result.is_empty then
				Result := fonts_folder + Result
			end
		end

	font_files: ARRAYED_LIST [STRING_8]
			-- The names of the font files in `fonts_folder'.
		local
			l_folder: DIRECTORY
			l_name: STRING_8
		do
			create Result.make (32)
			create l_folder.make (fonts_folder)
			if l_folder.exists and then l_folder.is_readable then
				across l_folder.entries as ic loop
					l_name := ic.name.to_string_8
					if l_name.as_lower.ends_with (".ttf") or l_name.as_lower.ends_with (".otf") or l_name.as_lower.ends_with (".ttc") then
						Result.extend (l_name)
					end
				end
			end
		end

	found_files: HASH_TABLE [STRING_8, STRING_8]
			-- The results of `found'.

	System_fonts_folder: STRING_8 = "/system/fonts/"

	Latin_sample: NATURAL_32 = 0x41

	Hebrew_sample: NATURAL_32 = 0x5D0

feature {NONE} -- C

	c_covers (a_path: POINTER; a_code: NATURAL_32): INTEGER
		external "C inline use %"sephone_text.h%"" alias "return (EIF_INTEGER) st_file_covers((const char *)$a_path, (uint32_t)$a_code);" end

end
