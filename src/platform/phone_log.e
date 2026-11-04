note
	description: "Write lines to the Android log (logcat) under `tag'."
	author: "Larry Rix"

class
	PHONE_LOG

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
			-- Log under tag "Eiffel".
		do
			tag := "Eiffel"
		ensure
			default_tag: tag.same_string ("Eiffel")
		end

feature -- Access

	tag: STRING_8
			-- Log tag (what `adb logcat -s <tag>' filters on).

feature -- Settings

	set_tag (a_tag: READABLE_STRING_8)
			-- Use `a_tag' from now on.
		require
			not_empty: not a_tag.is_empty
			short: a_tag.count <= 23
		do
			tag := a_tag.to_string_8
		ensure
			set: tag.same_string (a_tag)
		end

feature -- Output

	debug_line (a_text: READABLE_STRING_8)
			-- Debug-level line.
		do
			write (3, a_text)
		end

	info (a_text: READABLE_STRING_8)
			-- Info-level line.
		do
			write (4, a_text)
		end

	warn (a_text: READABLE_STRING_8)
			-- Warning-level line.
		do
			write (5, a_text)
		end

	error (a_text: READABLE_STRING_8)
			-- Error-level line.
		do
			write (6, a_text)
		end

feature {NONE} -- Implementation

	write (a_level: INTEGER; a_text: READABLE_STRING_8)
			-- Send `a_text' to logcat at Android priority `a_level' (3 debug .. 6 error).
		local
			l_tag, l_text: C_STRING
		do
			create l_tag.make (tag)
			create l_text.make (a_text)
			c_log (a_level, l_tag.item, l_text.item)
		end

invariant
	tag_ok: not tag.is_empty and tag.count <= 23

end
