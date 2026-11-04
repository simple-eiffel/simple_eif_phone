note
	description: "[
		Where the external tools live, and whether they are the pinned
		versions: gec, the Gobo library, the NDK (clang, native_app_glue),
		build-tools (aapt2, aapt, zipalign, apksigner, d8), the platform
		android.jar, the JDK (javac, keytool) and adb.
		Lookup order (Larry, 2026-11-03: "standard settings first"):
		1. the standard environment variables (JAVA_HOME, ANDROID_HOME or
		   ANDROID_SDK_ROOT, ANDROID_NDK_HOME, GOBO);
		2. Larry's layout (D:\prod\gobo-26.10, D:\android\...);
		3. a project's [tools] table, which overrides both.
	]"
	author: "Larry Rix"

class
	EIFPHONE_TOOLCHAIN

create
	make_default

feature {NONE} -- Initialization

	make_default
			-- Default locations; nothing checked yet.
		local
			l_env: SIMPLE_ENV
			l_sdk: PATH
		do
			create l_env
			if attached l_env.get ("ANDROID_HOME") as al_v and then not al_v.is_empty then
				create l_sdk.make_from_string (al_v)
			elseif attached l_env.get ("ANDROID_SDK_ROOT") as al_v and then not al_v.is_empty then
				create l_sdk.make_from_string (al_v)
			else
				create l_sdk.make_from_string (Default_sdk)
			end
			if attached l_env.get ("ANDROID_NDK_HOME") as al_v and then not al_v.is_empty then
				create ndk.make_from_string (al_v)
			else
				ndk := l_sdk.extended ("ndk").extended (Pinned_ndk)
			end
			build_tools := l_sdk.extended ("build-tools").extended (Pinned_build_tools)
			platform_jar := l_sdk.extended ("platforms").extended (Pinned_platform).extended ("android.jar")
			adb := l_sdk.extended ("platform-tools").extended ("adb.exe")
			if attached l_env.get ("JAVA_HOME") as al_v and then not al_v.is_empty then
				create jdk.make_from_string (al_v)
			else
				create jdk.make_from_string (Default_jdk)
			end
			if attached l_env.get ("GOBO") as al_v and then not al_v.is_empty then
				gec := (create {PATH}.make_from_string (al_v)).extended ("bin").extended ("gec.exe")
			else
				create gec.make_from_string (Default_gec)
			end
			if attached l_env.get ("GOBO_LIBRARY") as al_v and then not al_v.is_empty then
				create gobo_library.make_from_string (al_v)
			else
				create gobo_library.make_from_string (Default_gobo_library)
			end
			if attached l_env.get ("ISE_LIBRARY") as al_v and then not al_v.is_empty then
				create ise_library.make_from_string (al_v)
			elseif attached l_env.get ("ISE_EIFFEL") as al_v and then not al_v.is_empty then
				create ise_library.make_from_string (al_v)
			else
				create ise_library.make_from_string (Default_ise)
			end
			if attached l_env.get ("SIMPLE_EIFFEL") as al_v and then not al_v.is_empty then
				create simple_eiffel.make_from_string (al_v)
			else
				create simple_eiffel.make_from_string (Default_simple_eiffel)
			end
			create missing.make (0)
			create pin_mismatches.make (0)
		ensure
			not_checked: not is_checked
		end

feature -- Configuration

	apply_overrides (a_project: EIFPHONE_PROJECT)
			-- Use `a_project''s [tools] paths where given.
		require
			loaded: a_project.is_loaded
		do
			if attached a_project.tool_overrides as al_o then
				if attached al_o.item ("gec") as al_p then gec := al_p end
				if attached al_o.item ("gobo_library") as al_p then gobo_library := al_p end
				if attached al_o.item ("ndk") as al_p then ndk := al_p end
				if attached al_o.item ("build_tools") as al_p then build_tools := al_p end
				if attached al_o.item ("platform_jar") as al_p then platform_jar := al_p end
				if attached al_o.item ("jdk") as al_p then jdk := al_p end
				if attached al_o.item ("adb") as al_p then adb := al_p end
				if attached al_o.item ("ise_library") as al_p then ise_library := al_p end
				if attached al_o.item ("simple_eiffel") as al_p then simple_eiffel := al_p end
			end
			is_checked := False
		ensure
			needs_new_check: not is_checked
		end

feature -- Paths

	gec, gobo_library, ndk, build_tools, platform_jar, jdk, adb: PATH

	ise_library: PATH
			-- EiffelStudio folder (gec maps base.ecf through it).

	simple_eiffel: PATH
			-- Folder holding the simple_* libraries.

	clang: PATH
			-- NDK clang for Windows hosts.
		do
			Result := ndk.extended ("toolchains").extended ("llvm").extended ("prebuilt").extended ("windows-x86_64").extended ("bin").extended ("clang.exe")
		end

	native_app_glue: PATH
			-- Folder holding android_native_app_glue.c/.h.
		do
			Result := ndk.extended ("sources").extended ("android").extended ("native_app_glue")
		end

feature -- Checking

	check_all
			-- Look for every tool and compare pinned versions. The lists are
			-- rebuilt from scratch on every call (RA-11).
		do
			missing.wipe_out
			pin_mismatches.wipe_out
			require_file ("gec", gec)
			require_folder ("gobo_library", gobo_library)
			require_folder ("ise_library", ise_library)
			require_folder ("simple_eiffel", simple_eiffel)
			require_file ("ndk clang", clang)
			require_file ("native_app_glue", native_app_glue.extended ("android_native_app_glue.c"))
			require_file ("aapt2", aapt2)
			require_file ("aapt", aapt)
			require_file ("zipalign", zipalign)
			require_file ("apksigner", apksigner)
			require_file ("d8", d8)
			require_file ("android.jar", platform_jar)
			require_file ("javac", javac)
			require_file ("keytool", keytool)
			require_file ("adb", adb)
			check_pin ("ndk", ndk, Pinned_ndk)
			check_pin ("build-tools", build_tools, Pinned_build_tools)
			check_pin ("platform", platform_jar, Pinned_platform)
			check_pin ("gec", gec, Pinned_gec)
			is_checked := True
		ensure
			checked: is_checked
			complete_definition: is_complete = missing.is_empty
			pins_definition: pins_match = pin_mismatches.is_empty
			missing_named: across missing as ic all not ic.is_empty end
			each_named_once: missing_model.count = missing.count
		end

	missing_model: MML_SET [STRING_8]
			-- `missing' as a set.
		do
			create Result
			across missing as ic loop
				Result := Result & ic
			end
		end

	is_checked: BOOLEAN

	is_complete: BOOLEAN
			-- Was every tool found by the last `check_all'?
		do
			Result := is_checked and missing.is_empty
		end

	is_complete_for (a_project: EIFPHONE_PROJECT): BOOLEAN
			-- `is_complete', and the platform jar for `a_project''s target SDK exists.
		require
			loaded: a_project.is_loaded
		do
			Result := is_complete and then file_exists (platform_jar_for (a_project.target_sdk))
		ensure
			needs_all_tools: Result implies is_complete
		end

	platform_jar_for (a_sdk: INTEGER): PATH
			-- android.jar for API level `a_sdk', beside the pinned platform.
		do
			if attached platform_jar.parent.parent as al_platforms then
				Result := al_platforms.extended ("android-" + a_sdk.out).extended ("android.jar")
			else
				Result := platform_jar
			end
		end

feature -- Tool files

	aapt2: PATH do Result := build_tools.extended ("aapt2.exe") end
	aapt: PATH do Result := build_tools.extended ("aapt.exe") end
	zipalign: PATH do Result := build_tools.extended ("zipalign.exe") end
	apksigner: PATH do Result := build_tools.extended ("apksigner.bat") end
	d8: PATH do Result := build_tools.extended ("d8.bat") end
	javac: PATH do Result := jdk.extended ("bin").extended ("javac.exe") end
	keytool: PATH do Result := jdk.extended ("bin").extended ("keytool.exe") end
	boehm_gc_include: PATH
			-- Boehm GC headers, inside the gec install.
		do
			Result := gec.parent.parent.extended ("tool").extended ("gec").extended ("backend").extended ("c").extended ("boehm_gc").extended ("include")
		end

	gec_runtime_include: PATH
			-- gec's runtime headers (eif_eiffel.h and friends), for library C that uses them.
		do
			Result := gec.parent.parent.extended ("tool").extended ("gec").extended ("backend").extended ("c").extended ("runtime")
		end

	pins_match: BOOLEAN
			-- Did the last `check_all' find every pinned version?
		do
			Result := is_checked and pin_mismatches.is_empty
		end

	missing: ARRAYED_LIST [STRING_8]
			-- Names of tools not found.

	pin_mismatches: ARRAYED_LIST [STRING_32]
			-- "ndk: expected 30.0.16248370, found ..." lines (warnings).

feature -- Pins

	Pinned_ndk: STRING_8 = "30.0.16248370"
	Pinned_build_tools: STRING_8 = "36.0.0"
	Pinned_platform: STRING_8 = "android-36"
	Pinned_gec: STRING_8 = "26.10"

feature -- Default locations (Larry's layout)

	Default_sdk: STRING_8 = "D:\android\sdk"
	Default_jdk: STRING_8 = "D:\android\jdk"
	Default_gec: STRING_8 = "D:\prod\gobo-26.10\gobo\bin\gec.exe"
	Default_gobo_library: STRING_8 = "D:\prod\simple_gobo\library"
	Default_ise: STRING_8 = "C:\Program Files\Eiffel Software\EiffelStudio 25.02 Standard"
	Default_simple_eiffel: STRING_8 = "D:\prod"

feature {NONE} -- Implementation

	file_exists (a_path: PATH): BOOLEAN
		do
			Result := (create {RAW_FILE}.make_with_path (a_path)).exists
		end

	require_file (a_name: STRING_8; a_path: PATH)
			-- Note `a_name' as missing unless `a_path' exists.
		do
			if not file_exists (a_path) then
				missing.extend (a_name)
			end
		end

	require_folder (a_name: STRING_8; a_path: PATH)
			-- Note `a_name' as missing unless folder `a_path' exists.
		do
			if not (create {DIRECTORY}.make_with_path (a_path)).exists then
				missing.extend (a_name)
			end
		end

	check_pin (a_name: STRING_8; a_path: PATH; a_pin: STRING_8)
			-- Note a mismatch unless `a_path' contains `a_pin'.
		do
			if not a_path.name.has_substring (a_pin.to_string_32) then
				pin_mismatches.extend (a_name.to_string_32 + {STRING_32} ": expected " + a_pin.to_string_32 + {STRING_32} ", found " + a_path.name)
			end
		end

end
