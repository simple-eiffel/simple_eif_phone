note
	description: "[
		An app project: the settings in `eifphone.toml', loaded and validated.
		Every error names the file and the key, e.g.
		"eifphone.toml: [android] min_sdk must be at least 26 (found 21)".
		Passwords never live in the file: `[signing] password_env' names an
		environment variable instead.
	]"
	author: "Larry Rix"

class
	EIFPHONE_PROJECT

create
	make

feature {NONE} -- Initialization

	make
			-- Empty, not loaded.
		do
			create directory.make_empty
			create app_id.make_empty
			create label.make_empty
			create version_name.make_empty
			create ecf_name.make_empty
			create ecf_target.make_empty
			create abis.make (2)
			create permissions.make (0)
			create native_sources.make (0)
			create native_includes.make (0)
			create native_defines.make (0)
			create native_libraries.make (4)
			create native_abi_includes.make (2)
			create errors.make (0)
		ensure
			not_loaded: not is_loaded
			not_valid: not is_valid
		end

feature -- Loading

	load (a_dir: PATH)
			-- Read and validate `a_dir'/eifphone.toml. Errors from any
			-- earlier load are cleared first. Every error starts with
			-- "eifphone.toml: [<table>]" ([file] and [syntax] for a missing or
			-- unreadable file). A half-filled [signing] table gives one error
			-- per missing key, never a broken object (RA-3).
		local
			l_toml: SIMPLE_TOML
			l_file: PATH
		do
			reset
			directory := a_dir
			is_loaded := True
			l_file := a_dir.extended (Settings_file_name)
			if not (create {RAW_FILE}.make_with_path (l_file)).exists then
				add_error ("file", {STRING_32} "not found in " + a_dir.name)
			elseif (create {RAW_FILE}.make_with_path (l_file)).count = 0 then
				add_error ("file", {STRING_32} "is empty in " + a_dir.name)
			else
				create l_toml
				if attached l_toml.load_file (l_file.name) as al_root then
					read_app (al_root)
					read_eiffel (al_root)
					read_android (al_root)
					read_signing (al_root)
					read_tools (al_root)
					read_native (al_root)
				else
					across l_toml.last_errors as ic loop
						add_error ("syntax", ic)
					end
					if errors.is_empty then
						add_error ("syntax", {STRING_32} "the file could not be read as TOML")
					end
				end
			end
		ensure
			loaded: is_loaded
			directory_set: directory = a_dir
			valid_xor_errors: is_valid = errors.is_empty
			defines_safe: across native_defines as ic all is_native_define (ic) end
			errors_name_file_and_table: across errors as ic all ic.starts_with ({STRING_32} "eifphone.toml: [") end
			release_key_resolved: attached keystore_path as al_k implies al_k.is_absolute
		end

feature -- Status

	is_loaded: BOOLEAN
			-- Has `load' run?

	is_valid: BOOLEAN
			-- Loaded with no errors?
		do
			Result := is_loaded and errors.is_empty
		end

	has_release_key: BOOLEAN
			-- Does `[signing]' name a release keystore?
		do
			Result := attached keystore_path
		end

feature -- Access: [app]

	directory: PATH
	app_id: STRING_8
	label: STRING_32
	version_code: INTEGER
	version_name: STRING_8
	icon_path: detachable PATH

feature -- Access: [eiffel]

	ecf_name: STRING_8
	ecf_target: STRING_8

feature -- Access: [android]

	abis: ARRAYED_LIST [STRING_8]
	min_sdk: INTEGER
	target_sdk: INTEGER
	uses_java_helper: BOOLEAN
	uses_controls: BOOLEAN
			-- Does the app use Android's own controls? Brings the Java helper with it.
	permissions: ARRAYED_LIST [STRING_8]

feature -- Access: [native]

	native_sources: ARRAYED_LIST [PATH]
			-- C files compiled into the app, for libraries that bring their own.

	native_includes: ARRAYED_LIST [PATH]
			-- Folders added to the C search path.

	native_defines: ARRAYED_LIST [STRING_8]
			-- NAME or NAME=value, passed to clang.

	native_libraries: ARRAYED_LIST [STRING_8]
			-- Static libraries (.a) linked into the app, in order, as written in
			-- the file. $ABI stands for the processor type being built.

	native_abi_includes: ARRAYED_LIST [STRING_8]
			-- Include folders that differ by processor type, with $ABI in them.

	for_abi (a_text: READABLE_STRING_8; a_abi: READABLE_STRING_8): PATH
			-- `a_text' as a path for processor type `a_abi'.
		local
			l_text: STRING_8
		do
			create l_text.make_from_string (a_text)   -- the original stays as written, for the next ABI
			l_text.replace_substring_all (Abi_mark, a_abi)
			Result := native_path (l_text)
		end

	is_native_define (a_text: READABLE_STRING_8): BOOLEAN
			-- Is `a_text' NAME or NAME=value, with nothing a command line could act on?
		local
			i, l_equals: INTEGER
			c: CHARACTER_8
		do
			l_equals := a_text.index_of ('=', 1)
			if not a_text.is_empty and then l_equals /= 1 and then not a_text [1].is_digit then
				Result := True
				from i := 1 until i > a_text.count or not Result loop
					c := a_text [i]
					if l_equals = 0 or i < l_equals then
						Result := c.is_alpha or c.is_digit or c = '_'
					elseif i > l_equals then
						Result := c.is_alpha or c.is_digit or c = '_' or c = '.' or c = '-'
					end
					i := i + 1
				end
			end
		end

feature -- Access: [signing]

	keystore_path: detachable PATH
	key_alias: detachable STRING_8
	debug_keystore: detachable PATH
			-- `[signing] debug_keystore': where the debug key lives, if not the
			-- shared default. Does not count toward the three release keys.

	password_env: detachable STRING_8

feature -- Access: [tools] overrides

	tool_overrides: detachable HASH_TABLE [PATH, STRING_8]
			-- Tool name ("ndk", "gec", "build_tools", "jdk", "platform") -> path.

feature -- Errors

	errors: ARRAYED_LIST [STRING_32]

feature -- Model queries

	abis_model: MML_SET [STRING_8]
			-- ABIs as a set (compared by value).
		do
			create Result
			across abis as ic loop
				Result := Result & ic
			end
		end

	supported_abis: MML_SET [STRING_8]
			-- "arm64-v8a" and "x86_64".
		do
			Result := (create {MML_SET [STRING_8]}.singleton (Abi_arm64)) & Abi_x86_64
		end

feature -- Constants

	Abi_arm64: STRING_8 = "arm64-v8a"
	Abi_x86_64: STRING_8 = "x86_64"
	Lowest_min_sdk: INTEGER = 26
	Settings_file_name: STRING_8 = "eifphone.toml"

feature -- Validation helpers

	is_java_package (a_id: READABLE_STRING_8): BOOLEAN
			-- Two or more dot-separated parts, each a Java identifier
			-- (letter or '_' first; letters, digits, '_' after).
		local
			l_parts: LIST [READABLE_STRING_8]
		do
			l_parts := a_id.split ('.')
			Result := l_parts.count >= 2 and then across l_parts as ic all is_identifier (ic) end
		end

	is_env_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Letter or '_' first; letters, digits, '_' after (a variable NAME,
			-- never a value; RA-8).
		do
			Result := is_identifier (a_name)
		end

	is_identifier (a_s: READABLE_STRING_8): BOOLEAN
			-- Non-empty; letter or '_' first; letters, digits or '_' after (ASCII).
		local
			i: INTEGER
			c: CHARACTER_8
		do
			if not a_s.is_empty then
				c := a_s [1]
				Result := c.is_alpha or c = '_'
				from i := 2 until not Result or i > a_s.count loop
					c := a_s [i]
					Result := c.is_alpha or c.is_digit or c = '_'
					i := i + 1
				end
			end
		end

feature {NONE} -- Reading tables

	reset
			-- Forget everything a previous `load' read.
		do
			create app_id.make_empty
			create label.make_empty
			version_code := 0
			create version_name.make_empty
			icon_path := Void
			create ecf_name.make_empty
			create ecf_target.make_empty
			abis.wipe_out
			min_sdk := 0
			target_sdk := 0
			uses_java_helper := False
			uses_controls := False
			permissions.wipe_out
			keystore_path := Void
			key_alias := Void
			password_env := Void
			debug_keystore := Void
			tool_overrides := Void
			native_sources.wipe_out
			native_includes.wipe_out
			native_defines.wipe_out
			errors.wipe_out
		end

	read_app (a_root: TOML_TABLE)
		do
			if attached required_table (a_root, "app") as al_t then
				if attached text (al_t, "app", "id", True) as al_v then
					app_id := al_v.to_string_8
					if not is_java_package (app_id) then
						add_error ("app", {STRING_32} "id must look like a Java package (e.g. io.github.me.myapp); found %"" + al_v + "%"")
					end
				end
				if attached text (al_t, "app", "label", True) as al_v then
					if al_v.is_empty then add_error ("app", {STRING_32} "label must not be empty") end
					label := al_v
				end
				version_code := whole_number (al_t, "app", "version_code", True)
				if al_t.has ("version_code") and version_code <= 0 then
					add_error ("app", {STRING_32} "version_code must be at least 1 (found " + version_code.out + ")")
				end
				if attached text (al_t, "app", "version_name", True) as al_v then
					if al_v.is_empty then add_error ("app", {STRING_32} "version_name must not be empty") end
					version_name := al_v.to_string_8
				end
				if attached text (al_t, "app", "icon", False) as al_v then
					icon_path := resolved (al_v)
					if attached icon_path as al_icon and then not (create {RAW_FILE}.make_with_path (al_icon)).exists then
						add_error ("app", {STRING_32} "icon file not found: " + al_icon.name)
					end
				end
			end
		end

	read_eiffel (a_root: TOML_TABLE)
		do
			if attached required_table (a_root, "eiffel") as al_t then
				if attached text (al_t, "eiffel", "ecf", True) as al_v then
					ecf_name := al_v.to_string_8
					if not (create {RAW_FILE}.make_with_path (resolved (al_v))).exists then
						add_error ("eiffel", {STRING_32} "ecf %"" + al_v + "%" was not found next to eifphone.toml")
					end
				end
				if attached text (al_t, "eiffel", "target", True) as al_v then
					ecf_target := al_v.to_string_8
				end
			end
		end

	read_android (a_root: TOML_TABLE)
		local
			l_seen: MML_SET [STRING_8]
		do
			if attached required_table (a_root, "android") as al_t then
				if attached string_list (al_t, "android", "abis", True) as al_l then
					create l_seen
					across al_l as ic loop
						if not (ic.same_string (Abi_arm64) or ic.same_string (Abi_x86_64)) then
							add_error ("android", {STRING_32} "abis: %"" + ic.to_string_32 + "%" is not supported (use arm64-v8a, x86_64)")
						elseif l_seen [ic] then
							add_error ("android", {STRING_32} "abis: %"" + ic.to_string_32 + "%" is listed twice")
						else
							abis.extend (ic)
							l_seen := l_seen & ic
						end
					end
					if al_l.is_empty then add_error ("android", {STRING_32} "abis must list at least one ABI") end
				end
				min_sdk := whole_number (al_t, "android", "min_sdk", True)
				target_sdk := whole_number (al_t, "android", "target_sdk", True)
				if al_t.has ("min_sdk") and min_sdk < Lowest_min_sdk then
					add_error ("android", {STRING_32} "min_sdk must be at least " + Lowest_min_sdk.out + " (found " + min_sdk.out + ")")
				end
				if al_t.has ("target_sdk") and target_sdk < min_sdk then
					add_error ("android", {STRING_32} "target_sdk (" + target_sdk.out + ") must not be below min_sdk (" + min_sdk.out + ")")
				end
				uses_java_helper := flag (al_t, "android", "java_helper")
				uses_controls := flag (al_t, "android", "controls")
				uses_java_helper := uses_java_helper or uses_controls
				if attached string_list (al_t, "android", "permissions", False) as al_l then
					permissions.append (al_l)
				end
			end
		end

	read_signing (a_root: TOML_TABLE)
			-- All three keys or none (RA-3); one error per missing key.
		local
			n: INTEGER
		do
			if attached a_root.table_item ("signing") as al_t then
				if attached text (al_t, "signing", "debug_keystore", False) as al_v then
					debug_keystore := resolved (al_v)
				end
				if attached text (al_t, "signing", "keystore", False) as al_v then
					keystore_path := resolved (al_v)
					n := n + 1
				end
				if attached text (al_t, "signing", "alias", False) as al_v then
					key_alias := al_v.to_string_8
					n := n + 1
				end
				if attached text (al_t, "signing", "password_env", False) as al_v then
					password_env := al_v.to_string_8
					n := n + 1
					if not is_env_name (al_v.to_string_8) then
						add_error ("signing", {STRING_32} "password_env must be an environment variable NAME (letters, digits, _), never the password itself")
					end
				end
				if n > 0 and n < 3 then
					if keystore_path = Void then add_error ("signing", {STRING_32} "keystore is missing (release signing needs keystore, alias and password_env)") end
					if key_alias = Void then add_error ("signing", {STRING_32} "alias is missing (release signing needs keystore, alias and password_env)") end
					if password_env = Void then add_error ("signing", {STRING_32} "password_env is missing (release signing needs keystore, alias and password_env)") end
				end
			elseif a_root.has ("signing") then
				add_error ("signing", {STRING_32} "must be a table")
			end
		end

	read_tools (a_root: TOML_TABLE)
		local
			l_map: HASH_TABLE [PATH, STRING_8]
		do
			if attached a_root.table_item ("tools") as al_t then
				create l_map.make (8)
				across al_t.keys as ic loop
					if attached text (al_t, "tools", ic.to_string_8, False) as al_v then
						l_map.force (resolved (al_v), ic.to_string_8)
					end
				end
				tool_overrides := l_map
			end
		end

	read_native (a_root: TOML_TABLE)
			-- Extra C for libraries that bring their own, such as SQLite. The table is optional.
		do
			if attached a_root.table_item ("native") as al_t then
				if attached string_list (al_t, "native", "sources", False) as al_l then
					across al_l as ic loop
						add_native_source (ic)
					end
				end
				if attached string_list (al_t, "native", "include", False) as al_l then
					across al_l as ic loop
						add_native_include (ic)
					end
				end
				if attached string_list (al_t, "native", "libraries", False) as al_l then
					across al_l as ic loop
						if ic.ends_with (".a") then
							native_libraries.extend (ic)
						else
							add_error ("native", {STRING_32} "libraries: " + ic.to_string_32 + " is not a .a file")
						end
					end
				end
				if attached string_list (al_t, "native", "defines", False) as al_l then
					across al_l as ic loop
						if is_native_define (ic) then
							native_defines.extend (ic)
						else
							add_error ("native", {STRING_32} "defines: %"" + ic.to_string_32 + "%" must be NAME or NAME=value")
						end
					end
				end
			end
		end

	add_native_source (a_text: STRING_8)
			-- Record one C file, or say what is wrong with it.
		local
			l_path: PATH
			l_name: STRING_32
		do
			l_path := native_path (a_text)
			l_name := file_name_of (l_path)
			if not l_name.ends_with ({STRING_32} ".c") then
				add_error ("native", {STRING_32} "sources: " + a_text.to_string_32 + " is not a .c file")
			elseif not (create {RAW_FILE}.make_with_path (l_path)).exists then
				add_error ("native", {STRING_32} "sources: " + a_text.to_string_32 + " was not found")
			elseif across native_sources as ic some file_name_of (ic).same_string (l_name) end then
				add_error ("native", {STRING_32} "sources: two files are named " + l_name)
			else
				native_sources.extend (l_path)
			end
		end

	add_native_include (a_text: STRING_8)
			-- Record one folder, or say what is wrong with it.
		local
			l_path: PATH
		do
			if a_text.has_substring (Abi_mark) then
				native_abi_includes.extend (a_text)
			else
				l_path := native_path (a_text)
				if (create {DIRECTORY}.make_with_path (l_path)).exists then
					native_includes.extend (l_path)
				else
					add_error ("native", {STRING_32} "include: " + a_text.to_string_32 + " was not found")
				end
			end
		end

	native_path (a_text: STRING_8): PATH
			-- `a_text' as an absolute path. A leading $SIMPLE_EIFFEL names the library root,
			-- and a leading $EIFPHONE_NATIVE the folder of C libraries built for Android.
		local
			l_env: SIMPLE_ENV
			l_root: STRING_32
		do
			if a_text.starts_with (Library_root_prefix) then
				create l_env
				if attached l_env.get ("SIMPLE_EIFFEL") as al_v and then not al_v.is_empty then
					create l_root.make_from_string_general (al_v)
				else
					create l_root.make_from_string_general ({EIFPHONE_TOOLCHAIN}.Default_simple_eiffel)
				end
				l_root.append_string_general (a_text.substring (Library_root_prefix.count + 1, a_text.count))
				Result := resolved (l_root)
			elseif a_text.starts_with (Native_root_prefix) then
				create l_env
				if attached l_env.get ("EIFPHONE_NATIVE") as al_v and then not al_v.is_empty then
					create l_root.make_from_string_general (al_v)
				else
					create l_root.make_from_string_general ({EIFPHONE_TOOLCHAIN}.Default_native)
				end
				l_root.append_string_general (a_text.substring (Native_root_prefix.count + 1, a_text.count))
				Result := resolved (l_root)
			else
				Result := resolved (a_text.to_string_32)
			end
		ensure
			absolute: Result.is_absolute
		end

	file_name_of (a_path: PATH): STRING_32
			-- Last part of `a_path'.
		do
			if attached a_path.entry as al_entry then
				Result := al_entry.name.to_string_32
			else
				Result := a_path.name.to_string_32
			end
		end

	Library_root_prefix: STRING_8 = "$SIMPLE_EIFFEL"

	Native_root_prefix: STRING_8 = "$EIFPHONE_NATIVE"

	Abi_mark: STRING_8 = "$ABI"

feature {NONE} -- Value helpers

	required_table (a_root: TOML_TABLE; a_name: STRING_8): detachable TOML_TABLE
			-- Table `a_name', or Void with an error.
		do
			Result := a_root.table_item (a_name.to_string_32)
			if Result = Void then
				add_error (a_name, {STRING_32} "table is missing")
			end
		ensure
			only_records_errors: errors.count >= old errors.count
		end

	text (a_t: TOML_TABLE; a_table, a_key: STRING_8; a_required: BOOLEAN): detachable STRING_32
			-- String value of `a_key', or Void (with an error when it is required
			-- or has the wrong type).
		do
			if attached a_t.item (a_key.to_string_32) as al_v then
				if al_v.is_string then
					Result := al_v.as_string
				else
					add_error (a_table, a_key.to_string_32 + {STRING_32} " must be a string")
				end
			elseif a_required then
				add_error (a_table, a_key.to_string_32 + {STRING_32} " is missing")
			end
		ensure
			only_records_errors: errors.count >= old errors.count
		end

	whole_number (a_t: TOML_TABLE; a_table, a_key: STRING_8; a_required: BOOLEAN): INTEGER
			-- Integer value of `a_key' (0 when absent or wrong, with an error).
		do
			if attached a_t.item (a_key.to_string_32) as al_v then
				if al_v.is_integer and then al_v.as_integer.abs <= {INTEGER}.max_value then
					Result := al_v.as_integer.to_integer_32
				else
					add_error (a_table, a_key.to_string_32 + {STRING_32} " must be a whole number")
				end
			elseif a_required then
				add_error (a_table, a_key.to_string_32 + {STRING_32} " is missing")
			end
		ensure
			only_records_errors: errors.count >= old errors.count
		end

	flag (a_t: TOML_TABLE; a_table, a_key: STRING_8): BOOLEAN
			-- Boolean value of `a_key' (False when absent).
		do
			if attached a_t.item (a_key.to_string_32) as al_v then
				if al_v.is_boolean then
					Result := al_v.as_boolean
				else
					add_error (a_table, a_key.to_string_32 + {STRING_32} " must be true or false")
				end
			end
		ensure
			only_records_errors: errors.count >= old errors.count
		end

	string_list (a_t: TOML_TABLE; a_table, a_key: STRING_8; a_required: BOOLEAN): detachable ARRAYED_LIST [STRING_8]
			-- Array of strings at `a_key' (ASCII), or Void.
		do
			if attached a_t.item (a_key.to_string_32) as al_v then
				if al_v.is_array then
					create Result.make (al_v.as_array.count)
					across al_v.as_array.items as ic loop
						if ic.is_string and then ic.as_string.is_valid_as_string_8 then
							Result.extend (ic.as_string.to_string_8)
						else
							add_error (a_table, a_key.to_string_32 + {STRING_32} " must list plain-text strings")
						end
					end
				else
					add_error (a_table, a_key.to_string_32 + {STRING_32} " must be a list, e.g. [%"a%", %"b%"]")
				end
			elseif a_required then
				add_error (a_table, a_key.to_string_32 + {STRING_32} " is missing")
			end
		ensure
			only_records_errors: errors.count >= old errors.count
		end

	resolved (a_path: READABLE_STRING_32): PATH
			-- `a_path' as an absolute path, relative ones taken from `directory'.
		local
			p: PATH
		do
			create p.make_from_string (a_path)
			if p.is_absolute then
				Result := p
			else
				Result := directory.absolute_path.extended_path (p)
			end
		ensure
			absolute: Result.is_absolute
		end

	add_error (a_table: READABLE_STRING_8; a_message: READABLE_STRING_32)
			-- Record "eifphone.toml: [<table>] <message>".
		do
			errors.extend ({STRING_32} "eifphone.toml: [" + a_table.to_string_32 + {STRING_32} "] " + a_message)
		ensure
			one_more: errors.count = old errors.count + 1
		end

invariant
	valid_settings: is_valid implies (
		is_java_package (app_id) and version_code > 0 and not label.is_empty and
		not version_name.is_empty and not ecf_name.is_empty and not ecf_target.is_empty and
		Lowest_min_sdk <= min_sdk and min_sdk <= target_sdk and
		not abis.is_empty and abis_model <= supported_abis)
	distinct_abis: is_valid implies abis.count = abis_model.count
	release_key_complete: is_valid implies
		((attached keystore_path) = (attached key_alias) and (attached key_alias) = (attached password_env))
	env_name_only: (is_valid and attached password_env as al_v) implies is_env_name (al_v)

end
