note
	description: "[
		Read-only files packed in the APK's assets/ folder, by relative name
		(e.g. "fonts/noto.ttf"). Missing files are a normal outcome, not an
		error: `last_asset' is Void.
	]"
	author: "Larry Rix"

class
	PHONE_ASSETS

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
		do
		ensure
			nothing_read: last_asset = Void and last_asset_size = 0
		end

feature -- Status

	has_asset (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' packed in the APK?
		require
			name_ok: is_valid_name (a_name)
		local
			c: C_STRING
		do
			create c.make (a_name)
			Result := c_asset_size (c.item) >= 0
		end

	is_valid_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Non-empty and relative.
		do
			Result := not a_name.is_empty and then a_name [1] /= '/'
		end

feature -- Access

	last_asset: detachable MANAGED_POINTER
			-- Bytes from the last `read_asset', or Void if it was missing.

	last_asset_size: INTEGER
			-- Byte count of `last_asset' (0 if missing).

feature -- Basic operations

	read_asset (a_name: READABLE_STRING_8)
			-- Read `a_name' into `last_asset'.
		require
			name_ok: is_valid_name (a_name)
		local
			c: C_STRING
			n, l_got: INTEGER
			m: MANAGED_POINTER
		do
			last_asset := Void
			last_asset_size := 0
			create c.make (a_name)
			n := c_asset_size (c.item)
			if n >= 0 then
				create m.make (n)
				l_got := c_asset_read (c.item, m.item, n)
				if l_got = n then
					last_asset := m
					last_asset_size := n
				end
			end
		ensure
			found_has_data: attached last_asset as al_d implies al_d.count = last_asset_size
			missing_has_none: last_asset = Void implies last_asset_size = 0
		end

invariant
	size_non_negative: last_asset_size >= 0

end
