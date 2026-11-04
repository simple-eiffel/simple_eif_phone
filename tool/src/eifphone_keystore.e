note
	description: "[
		The signing identity for a build. With no [signing] table: the shared
		debug key (made on first use with keytool). With one: the named
		release key, its password read from the environment variable the
		project names, never from a file.
	]"
	author: "Larry Rix"

class
	EIFPHONE_KEYSTORE

create
	make

feature {NONE} -- Initialization

	make (a_project: EIFPHONE_PROJECT; a_tools: EIFPHONE_TOOLCHAIN)
		require
			loaded: a_project.is_loaded
		do
			project := a_project
			tools := a_tools
			if attached a_project.debug_keystore as al_k then
				debug_key_path := al_k
			else
				create debug_key_path.make_from_string ("D:\android\keys\eifphone-debug.jks")
			end
			create last_error.make_empty
		ensure
			debug_by_default: is_debug = not a_project.has_release_key
		end

feature -- Access

	project: EIFPHONE_PROJECT
	tools: EIFPHONE_TOOLCHAIN

	debug_key_path: PATH
			-- The debug keystore: `[signing] debug_keystore', or the one all apps share.

	Debug_alias: STRING_8 = "eifphone"

	Debug_password: STRING_8 = "eifphone"
			-- Public by design (Larry, 2026-11-03); never used for a release.

	is_debug: BOOLEAN
			-- Signing with the debug key?
		do
			Result := not project.has_release_key
		end

	last_error: STRING_32
			-- Why the last command failed (empty after success).

feature -- Basic operations

	ensure_debug_key
			-- Make the debug keystore if it is missing.
		require
			debug_mode: is_debug
		local
			r: EIFPHONE_RUNNER
			f: EIFPHONE_ERROR_FINDER
		do
			create last_error.make_empty
			if not debug_key_ready then
				make_key_folder
			end
			if not debug_key_ready and last_error.is_empty then
				create r.make
				r.run (r.quoted (tools.keytool) + {STRING_32} " -genkeypair -keystore " + r.quoted (debug_key_path)
					+ {STRING_32} " -storepass " + Debug_password.to_string_32 + {STRING_32} " -keypass " + Debug_password.to_string_32
					+ {STRING_32} " -alias " + Debug_alias.to_string_32
					+ {STRING_32} " -keyalg RSA -keysize 2048 -validity 10000 -dname %"CN=eifphone debug%"",
					debug_key_path.parent, debug_key_path.parent.extended ("eifphone-keytool.log"))
				if not r.succeeded or not debug_key_ready then
					create f
					if attached f.first_error (f.Tool_keytool, r.last_output) as al_e then
						last_error := al_e
					else
						last_error := f.fallback_line (r.last_output)
					end
				end
			end
		ensure
			error_or_ready: last_error.is_empty implies debug_key_ready
		end

	make_key_folder
			-- Make the debug key's folder; `last_error' says so if that cannot be done.
		local
			d: DIRECTORY
			l_failed: BOOLEAN
		do
			if l_failed then
				last_error := {STRING_32} "cannot make the folder for the debug key: " + debug_key_path.parent.name
			else
				create d.make_with_path (debug_key_path.parent)
				if not d.exists then
					d.recursive_create_dir
				end
			end
		rescue
			l_failed := True
			retry
		end

	debug_key_ready: BOOLEAN
			-- Does the debug keystore file exist?
		do
			Result := (create {RAW_FILE}.make_with_path (debug_key_path)).exists
		end

	release_password_available: BOOLEAN
			-- Is the release key's password variable set and non-empty?
		require
			release_mode: project.has_release_key
		do
			if attached project.password_env as al_v and then attached (create {SIMPLE_ENV}).get (al_v) as al_value then
				Result := not al_value.is_empty
			end
		end

	signer_arguments: STRING_32
			-- apksigner arguments: --ks, --ks-key-alias, --ks-pass, --key-pass.
			-- Debug key: `pass:eifphone' (public by design; Larry, 2026-11-03).
			-- Release key: both passwords come ONLY from the environment
			-- variable the project names; one variable serves both (Phase 2
			-- verdict default). `--key-pass' is always given, because without
			-- it apksigner prompts and the build would hang (RA-2).
		require
			ready: is_debug implies debug_key_ready
			password: not is_debug implies release_password_available
		local
			l_ks: PATH
			l_alias: STRING_8
			l_pass: STRING_32
		do
			if is_debug then
				l_ks := debug_key_path
				l_alias := Debug_alias
				l_pass := {STRING_32} "pass:" + Debug_password.to_string_32
			else
				check attached project.keystore_path as al_k and attached project.key_alias as al_a and attached project.password_env as al_v then
					l_ks := al_k
					l_alias := al_a
					l_pass := {STRING_32} "env:" + al_v.to_string_32
				end
			end
			create Result.make_from_string ({STRING_32} "--ks %"")
			Result.append (l_ks.name)
			Result.append ({STRING_32} "%" --ks-key-alias " + l_alias.to_string_32)
			Result.append ({STRING_32} " --ks-pass " + l_pass + {STRING_32} " --key-pass " + l_pass)
		ensure
			names_keystore: Result.has_substring ({STRING_32} "--ks ")
			always_key_pass: Result.has_substring ({STRING_32} "--key-pass ")
			release_env: not is_debug implies (attached project.password_env as al_v and then
				(Result.has_substring ({STRING_32} "--ks-pass env:" + al_v.to_string_32)
				and Result.has_substring ({STRING_32} "--key-pass env:" + al_v.to_string_32)))
			no_clear_release_password: not is_debug implies not (Result.has_substring ({STRING_32} "pass:")
				or Result.has_substring ({STRING_32} "file:") or Result.has_substring ({STRING_32} "stdin"))
		end

end
