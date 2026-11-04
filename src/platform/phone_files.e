note
	description: "[
		Let the person choose a file. Needs `java_helper = true' in eifphone.toml.
		Call `pick', then wait for Kind_file_picked, Kind_file_cancelled or
		Kind_file_failed. A chosen file is copied into the app's cache, so
		`last_path' is a plain file the app can open.
	]"
	author: "Larry Rix"

class
	PHONE_FILES

inherit
	PHONE_PICK_STATE

inherit {NONE}
	PHONE_NATIVE

create
	make

feature -- Status

	is_available: BOOLEAN
			-- Does this app carry the Java helper?
		do
			Result := c_helper_present /= 0
		end

	is_valid_type (a_type: READABLE_STRING_8): BOOLEAN
			-- Is `a_type' a media type, such as "text/plain" or "*/*"?
		do
			Result := a_type.occurrences ('/') = 1 and then not a_type.starts_with ("/") and then not a_type.ends_with ("/")
		end

feature -- Commands

	pick (a_type: READABLE_STRING_8)
			-- Open the picker for files of `a_type'. The result arrives as an event.
		require
			available: is_available
			closed: not is_picking
			valid_type: is_valid_type (a_type)
		local
			l_type: C_STRING
		do
			note_picking
			create l_type.make (a_type)
			c_pick_file (l_type.item)
		ensure
			open: is_picking
		end

end
