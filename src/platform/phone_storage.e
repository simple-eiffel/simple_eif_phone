note
	description: "[
		App-private folders on the phone. `internal_path' always exists and
		needs no permission; `external_path' may be absent.
	]"
	author: "Larry Rix"

class
	PHONE_STORAGE

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
		do
		end

feature -- Access

	internal_path: STRING_8
			-- The app's private files folder (UTF-8 path).
		local
			p: POINTER
		do
			p := c_path_internal
			if p /= default_pointer then
				create Result.make_from_c (p)
			else
				create Result.make_empty
			end
		ensure
			absolute: not Result.is_empty implies Result.starts_with ("/")
		end

	external_path: detachable STRING_8
			-- The app's folder on shared storage, if Android offers one.
		local
			p: POINTER
			s: STRING_8
		do
			p := c_path_external
			if p /= default_pointer then
				create s.make_from_c (p)
				if not s.is_empty then
					Result := s
				end
			end
		ensure
			absolute: attached Result as al_r implies (not al_r.is_empty and al_r.starts_with ("/"))
		end

end
