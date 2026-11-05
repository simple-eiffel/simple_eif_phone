note
	description: "[
		Runs the build stages in order and stops at the first failure:
		generate_c (gec) -> compile + link per ABI (NDK clang) -> dex (only
		with the Java helper) -> package (aapt2 link, aapt add) -> align
		(zipalign -P 16) -> sign (apksigner sign + verify).
		Work goes to <project>/build/ (gen, obj/<abi>, lib/<abi>, logs).
		A C file whose hash is unchanged since the last build of that ABI is
		not recompiled.
	]"
	author: "Larry Rix"

class
	EIFPHONE_BUILDER

create
	make

feature {NONE} -- Initialization

	make (a_project: EIFPHONE_PROJECT; a_tools: EIFPHONE_TOOLCHAIN; a_runtime_dir: PATH)
			-- Builder for `a_project' using `a_tools' and the fixed runtime in `a_runtime_dir'.
		require
			project_valid: a_project.is_valid
		do
			project := a_project
			tools := a_tools
			runtime_dir := a_runtime_dir
			create results.make (8)
			create apk_path.make_empty
			create runner.make
			create finder
		ensure
			project_set: project = a_project
			tools_set: tools = a_tools
			nothing_run: results.is_empty
		end

feature -- Access

	project: EIFPHONE_PROJECT
	tools: EIFPHONE_TOOLCHAIN
	runtime_dir: PATH

	results: ARRAYED_LIST [EIFPHONE_STAGE_RESULT]
			-- One per stage run, in order.

	apk_path: PATH
			-- The signed APK (meaningful when `is_success').

	is_success: BOOLEAN
			-- Did the last `build' reach the sign stage and pass it?
		do
			Result := not results.is_empty and then
				(results.last.name.same_string (Stage_sign) and results.last.is_success)
		ensure
			definition: Result = (not results.is_empty and then
				(results.last.name.same_string (Stage_sign) and results.last.is_success))
		end

	failed_stage: detachable EIFPHONE_STAGE_RESULT
			-- The stage that stopped the build, if any.
		do
			if not results.is_empty and then not results.last.is_success then
				Result := results.last
			end
		end

feature -- Model queries

	results_model: MML_SEQUENCE [EIFPHONE_STAGE_RESULT]
			-- `results' as a sequence.
		do
			create Result
			across results as ic loop
				Result := Result & ic
			end
		end

feature -- Settings

	clean_first: BOOLEAN
			-- Remove build/ before building?

	set_clean_first (a_clean: BOOLEAN)
		do
			clean_first := a_clean
		ensure
			set: clean_first = a_clean
		end

	only_abi: detachable STRING_8
			-- Build just this ABI (must be one of the project's).

	set_only_abi (a_abi: detachable READABLE_STRING_8)
		require
			known: attached a_abi as al_a implies project.abis_model [al_a.to_string_8]
		do
			if attached a_abi as al_a then
				only_abi := al_a.to_string_8
			else
				only_abi := Void
			end
		ensure
			set: attached a_abi as al_a implies (attached only_abi as al_o and then al_o.same_string (al_a))
			cleared: a_abi = Void implies only_abi = Void
		end

feature -- Basic operations

	build
			-- Run every stage; stop at the first failure. Results of any
			-- earlier build are discarded first.
		require
			project_valid: project.is_valid
			tools_ok: tools.is_complete_for (project)
		do
			results.wipe_out
			prepare_folders
			set_environment
			do_generate_c
			across selected_abis as ic_a until not last_stage_ok loop
				do_compile (ic_a)
				if last_stage_ok then
					do_link (ic_a)
				end
			end
			if last_stage_ok and project.uses_java_helper then
				do_dex
			end
			if last_stage_ok then
				do_package
			end
			if last_stage_ok then
				do_align
			end
			if last_stage_ok then
				do_check_align
			end
			if last_stage_ok then
				do_sign
			end
		ensure
			ran_something: not results_model.is_empty
			fresh_start: results_model.first.name.same_string (Stage_generate_c)
			bounded: results_model.count <= planned_stage_count
			prefix_succeeded: across 1 |..| (results_model.count - 1) as ic_i all results_model [ic_i].is_success end
			failed_is_last: attached failed_stage as al_f implies al_f = results_model.last
			success_xor_failed: is_success xor attached failed_stage
			success_is_full_run: is_success implies results_model.count = planned_stage_count
			dex_iff_helper: is_success implies (has_stage (Stage_dex) = project.uses_java_helper)
			aligned_before_signed: is_success implies has_stage (Stage_check_align)
		end

feature -- Stages

	Stage_generate_c: STRING_8 = "generate_c"
	Stage_compile: STRING_8 = "compile"
			-- Followed by " <abi>" in a result name.
	Stage_link: STRING_8 = "link"
			-- Followed by " <abi>" in a result name.
	Stage_dex: STRING_8 = "dex"
	Stage_package: STRING_8 = "package"
	Stage_align: STRING_8 = "align"
	Stage_check_align: STRING_8 = "check_align"
			-- zipalign -c -P 16 4 (AC-4; RA-14).
	Stage_sign: STRING_8 = "sign"
			-- apksigner sign, then apksigner verify.

	planned_stage_count: INTEGER
			-- Stages a full build of `project' runs.
		do
			Result := 1 + 2 * abi_count + 4
			if project.uses_java_helper then
				Result := Result + 1
			end
		ensure
			at_least_core: Result >= 7
		end

	abi_count: INTEGER
			-- ABIs this build makes (`only_abi' or all of the project's).
		do
			if only_abi /= Void then
				Result := 1
			else
				Result := project.abis.count
			end
		end

	has_stage (a_name: READABLE_STRING_8): BOOLEAN
			-- Did the last build run a stage named `a_name'?
		do
			Result := across results as ic some ic.name.same_string (a_name) end
		end

feature -- Manifest

	Manifest_config_changes: STRING_8 = "orientation|screenSize|screenLayout|smallestScreenSize|keyboardHidden|uiMode|layoutDirection|density|fontScale|locale"
			-- Changes the app handles itself (window_resized / configuration_changed
			-- instead of a restart). Phase 2 RB-9 widened it.

	manifest_text: STRING_32
			-- AndroidManifest.xml for `project'.
		local
			l_activity: STRING_32
		do
			l_activity := project.launch_activity.to_string_32
			create Result.make (1024)
			Result.append ({STRING_32} "<?xml version=%"1.0%" encoding=%"utf-8%"?>%N")
			Result.append ({STRING_32} "<manifest xmlns:android=%"http://schemas.android.com/apk/res/android%"%N")
			Result.append ({STRING_32} "    package=%"" + project.app_id.to_string_32 + {STRING_32} "%"%N")
			Result.append ({STRING_32} "    android:versionCode=%"" + project.version_code.out.to_string_32 + {STRING_32} "%"%N")
			Result.append ({STRING_32} "    android:versionName=%"" + manifest_value (project.version_name.to_string_32) + {STRING_32} "%">%N")
			across project.permissions as ic loop
				Result.append ({STRING_32} "    <uses-permission android:name=%"" + xml_escaped (ic.to_string_32) + {STRING_32} "%"/>%N")
			end
			if project.uses_java_helper then
					-- Android 11 on: the speech engine stays hidden from an app that does not ask.
				Result.append ({STRING_32} "    <queries>%N        <intent>%N            <action android:name=%"android.intent.action.TTS_SERVICE%"/>%N        </intent>%N    </queries>%N")
			end
			Result.append ({STRING_32} "    <application%N")
			Result.append ({STRING_32} "        android:label=%"" + manifest_value (project.label) + {STRING_32} "%"%N")
			if project.uses_java_helper then
				Result.append ({STRING_32} "        android:hasCode=%"true%"%N")
			else
				Result.append ({STRING_32} "        android:hasCode=%"false%"%N")
			end
			if project.icon_path /= Void then
				Result.append ({STRING_32} "        android:icon=%"@mipmap/ic_launcher%"%N")
			end
				-- A phone's cloud backup never gets an app's private data; right-to-left layouts work.
			Result.append ({STRING_32} "        android:allowBackup=%"false%"%N")
			Result.append ({STRING_32} "        android:supportsRtl=%"true%"%N")
			Result.append ({STRING_32} "        android:extractNativeLibs=%"true%">%N")
			Result.append ({STRING_32} "        <activity%N")
			Result.append ({STRING_32} "            android:name=%"" + l_activity + {STRING_32} "%"%N")
			Result.append ({STRING_32} "            android:exported=%"true%"%N")
			Result.append ({STRING_32} "            android:windowSoftInputMode=%"adjustResize%"%N")
			if attached project.orientation as al_orientation then
				Result.append ({STRING_32} "            android:screenOrientation=%"" + al_orientation + {STRING_32} "%"%N")
			end
			Result.append ({STRING_32} "            android:configChanges=%"" + Manifest_config_changes.to_string_32 + {STRING_32} "%"%N")
			Result.append ({STRING_32} "            android:theme=%"@android:style/Theme.Black.NoTitleBar%">%N")
			Result.append ({STRING_32} "            <meta-data android:name=%"android.app.lib_name%" android:value=%"" + library_name.to_string_32 + {STRING_32} "%"/>%N")
			Result.append ({STRING_32} "            <intent-filter>%N")
			Result.append ({STRING_32} "                <action android:name=%"android.intent.action.MAIN%"/>%N")
			Result.append ({STRING_32} "                <category android:name=%"android.intent.category.LAUNCHER%"/>%N")
			Result.append ({STRING_32} "            </intent-filter>%N")
			Result.append ({STRING_32} "        </activity>%N")
			Result.append ({STRING_32} "    </application>%N")
			Result.append ({STRING_32} "</manifest>%N")
		ensure
			names_package: Result.has_substring ({STRING_32} "package=%"" + project.app_id.to_string_32 + {STRING_32} "%"")
			label_escaped: Result.has_substring (xml_escaped (project.label))
			config_changes: Result.has_substring (Manifest_config_changes.to_string_32)
			code_iff_helper: Result.has_substring ({STRING_32} "android:hasCode=%"true%"") = project.uses_java_helper
		end

	manifest_value (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' as plain text in a manifest attribute. aapt2 reads a
			-- leading @ or ? as a reference, so that is escaped for aapt2, then
			-- everything for XML. It keeps \ and " as they are (tested).
		local
			l_text: STRING_32
		do
			l_text := a_text.to_string_32
			if not l_text.is_empty and then (l_text [1] = '@' or l_text [1] = '?') then
				l_text.prepend ({STRING_32} "\")
			end
			Result := xml_escaped (l_text)
		ensure
			no_raw_markup: not (Result.has ('<') or Result.has ('>') or Result.has ('"'))
		end

	xml_escaped (a_text: READABLE_STRING_32): STRING_32
			-- `a_text' with & < > " ' written as XML entities (RA-8).
		local
			c: CHARACTER_32
			i: INTEGER
		do
			create Result.make (a_text.count + 8)
			from i := 1 until i > a_text.count loop
				c := a_text [i]
				inspect c
				when '&' then Result.append ({STRING_32} "&amp;")
				when '<' then Result.append ({STRING_32} "&lt;")
				when '>' then Result.append ({STRING_32} "&gt;")
				when '"' then Result.append ({STRING_32} "&quot;")
				when '%'' then Result.append ({STRING_32} "&apos;")
				else
					Result.append_character (c)
				end
				i := i + 1
			end
		ensure
			no_raw_markup: not (Result.has ('<') or Result.has ('>') or Result.has ('"'))
		end

feature -- Names

	library_name: STRING_8
			-- Base name of the native library (lib<name>.so).
		do
			Result := project.ecf_target
		end

	build_folder: PATH
			-- <project>/build
		do
			Result := project.directory.absolute_path.extended ("build")
		end

feature {NONE} -- Stages

	do_generate_c
			-- gec: Eiffel -> C (build/gen/.gobo). C from an earlier run goes first: a target
			-- that generates fewer files would otherwise leave stale ones to be compiled.
			-- Hashes keep unchanged files from recompiling.
		do
			across files_with_extension (generated_folder, "c") as ic loop
				(create {RAW_FILE}.make_with_path (ic)).delete
			end
			run_stage (Stage_generate_c, finder.Tool_gec, build_folder.extended ("gen"),
				runner.quoted (tools.gec) + {STRING_32} " --cc=no --finalize --target=" + project.ecf_target.to_string_32
					+ {STRING_32} " " + runner.quoted (project.directory.absolute_path.extended (project.ecf_name)))
		end

	do_compile (a_abi: STRING_8)
			-- NDK clang: each changed C file -> build/obj/<abi>/*.o.
		local
			l_name, l_cflags: STRING_32
			l_new, l_old: HASH_TABLE [NATURAL_64, STRING_32]
			l_base: NATURAL_64
			l_obj: PATH
			l_seconds: REAL_64
			l_stop: BOOLEAN
			l_failure: detachable STRING_32
			l_log: PATH
		do
			l_name := {STRING_32} "compile " + a_abi.to_string_32
			l_log := log_for (l_name.to_string_8)
			l_cflags := compile_flags (a_abi)
			l_old := read_hashes (a_abi)
			create l_new.make (16)
			l_base := header_hash + text_hash (l_cflags)
			across c_sources as ic until l_stop loop
				l_new.force (file_hash (ic) + l_base, ic.name)
				l_obj := object_of (a_abi, ic)
				if l_old.item (ic.name) /= l_new.item (ic.name) or not file_exists (l_obj) then
					runner.run (runner.quoted (tools.clang) + {STRING_32} " " + l_cflags + {STRING_32} " -c "
						+ runner.quoted (ic) + {STRING_32} " -o " + runner.quoted (l_obj), build_folder, l_log)
					l_seconds := l_seconds + runner.last_seconds
					compile_count := compile_count + 1
					if not runner.succeeded then
						l_stop := True
						l_failure := error_line (finder.Tool_clang)
					end
				end
			end
			if attached l_failure as al_e then
				results.extend (create {EIFPHONE_STAGE_RESULT}.make_failure (l_name.to_string_8, l_seconds, l_log, al_e))
			else
				write_hashes (a_abi, l_new)
				results.extend (create {EIFPHONE_STAGE_RESULT}.make_success (l_name.to_string_8, l_seconds, l_log))
			end
		end

	do_link (a_abi: STRING_8)
			-- NDK clang: objects -> build/apk/lib/<abi>/lib<name>.so.
		local
			l_objs: STRING_32
		do
			create l_objs.make (256)
			across c_sources as ic loop
				l_objs.append ({STRING_32} " " + runner.quoted (object_of (a_abi, ic)))
			end
			across project.native_libraries as ic loop
				l_objs.append ({STRING_32} " " + runner.quoted (project.for_abi (ic, a_abi)))
			end
			run_stage (Stage_link + " " + a_abi, finder.Tool_clang, build_folder,
				runner.quoted (tools.clang) + {STRING_32} " --target=" + triple (a_abi) + project.min_sdk.out.to_string_32
					+ {STRING_32} " -shared -o " + runner.quoted (library_file (a_abi)) + l_objs
					+ {STRING_32} " -u ANativeActivity_onCreate -Wl,-z,max-page-size=16384 -Wl,--no-undefined -landroid -llog -lm -ldl -pthread")
		end

	do_dex
			-- javac + d8: the fixed Java helper -> build/apk/classes.dex.
		local
			l_sources, l_class_files: STRING_32
			l_dir, l_list: PATH
		do
			l_dir := build_folder.extended ("dex")
			create l_sources.make (128)
			across files_with_extension (runtime_dir.extended ("java"), "java") as ic loop
				l_sources.append ({STRING_32} " " + runner.quoted (ic))
			end
			run_stage (Stage_dex, finder.Tool_javac, build_folder,
				runner.quoted (tools.javac) + {STRING_32} " --release 17 -classpath " + runner.quoted (tools.platform_jar_for (project.target_sdk))
					+ {STRING_32} " -d " + runner.quoted (l_dir) + l_sources)
			if last_stage_ok then
				create l_class_files.make (128)
				across files_with_extension (l_dir, "class") as ic loop
					l_class_files.append (ic.name + {STRING_32} "%N")
				end
					-- One file name to a line, in a file: the names alone can pass what
					-- Windows allows on a command line.
				l_list := build_folder.extended ("dex_classes.txt")
				write_text (l_list, l_class_files)
					-- The javac result stands for the stage; d8 replaces it.
				results.finish
				results.remove
				run_stage (Stage_dex, finder.Tool_d8, build_folder,
					runner.quoted (tools.d8) + {STRING_32} " --min-api " + project.min_sdk.out.to_string_32
						+ {STRING_32} " --lib " + runner.quoted (tools.platform_jar_for (project.target_sdk))
						+ {STRING_32} " --output " + runner.quoted (build_folder.extended ("apk"))
						+ {STRING_32} " %"@" + l_list.name + {STRING_32} "%"")
			end
		end

	do_package
			-- aapt2 link, then aapt add for the native libraries (and dex).
		local
			l_manifest: PATH
			l_cmd, l_adds: STRING_32
			l_assets: PATH
		do
			l_manifest := build_folder.extended ("AndroidManifest.xml")
			write_text (l_manifest, manifest_text)
			l_cmd := runner.quoted (tools.aapt2) + {STRING_32} " link -o " + runner.quoted (unsigned_apk)
				+ {STRING_32} " --manifest " + runner.quoted (l_manifest)
				+ {STRING_32} " -I " + runner.quoted (tools.platform_jar_for (project.target_sdk))
				+ {STRING_32} " --min-sdk-version " + project.min_sdk.out.to_string_32
				+ {STRING_32} " --target-sdk-version " + project.target_sdk.out.to_string_32
			if project.icon_path /= Void then
				compile_icon
				if last_stage_ok then
					l_cmd.append ({STRING_32} " -R " + runner.quoted (icon_flat))
						-- The icon result stands for the stage; the link replaces it.
					results.finish
					results.remove
				end
			end
			if results.is_empty or else results.last.is_success then
				run_stage (Stage_package, finder.Tool_aapt2, build_folder, l_cmd)
			end
			if last_stage_ok then
				create l_adds.make (128)
				across selected_abis as ic loop
					l_adds.append ({STRING_32} " lib/" + ic.to_string_32 + {STRING_32} "/lib" + library_name.to_string_32 + {STRING_32} ".so")
				end
				if project.uses_java_helper then
					l_adds.append ({STRING_32} " classes.dex")
				end
				results.finish
				results.remove
				run_stage (Stage_package, finder.Tool_aapt, build_folder.extended ("apk"),
					runner.quoted (tools.aapt) + {STRING_32} " add " + runner.quoted (unsigned_apk) + l_adds)
			end
			if last_stage_ok then
				l_assets := project.directory.absolute_path
				create l_adds.make (128)
				across asset_names (l_assets.extended ("assets"), "assets") as ic loop
					l_adds.append ({STRING_32} " %"" + ic + {STRING_32} "%"")
				end
				if not l_adds.is_empty then
					results.finish
					results.remove
					run_stage (Stage_package, finder.Tool_aapt, l_assets,
						runner.quoted (tools.aapt) + {STRING_32} " add " + runner.quoted (unsigned_apk) + l_adds)
				end
			end
		end

	asset_names (a_folder: PATH; a_prefix: READABLE_STRING_32): ARRAYED_LIST [STRING_32]
			-- The files under `a_folder', named from `a_prefix' with forward slashes.
			-- aapt2 link -A would name a file in a subfolder with a backslash on
			-- Windows, and Android would never find it, so aapt add takes them all.
		local
			d: DIRECTORY
			p: PATH
			l_name: STRING_32
		do
			create Result.make (8)
			create d.make_with_path (a_folder)
			if d.exists then
				across d.entries as ic loop
					if not (ic.name.same_string ({STRING_32} ".") or ic.name.same_string ({STRING_32} "..")) then
						p := a_folder.extended_path (ic)
						l_name := a_prefix + {STRING_32} "/" + ic.name
						if (create {DIRECTORY}.make_with_path (p)).exists then
							Result.append (asset_names (p, l_name))
						else
							Result.extend (l_name)
						end
					end
				end
			end
		end

	compile_icon
			-- aapt2 compile: the project's icon -> `icon_flat', as mipmap/ic_launcher.
		require
			has_icon: project.icon_path /= Void
		local
			l_png: PATH
			l_from, l_to: RAW_FILE
			l_dir: DIRECTORY
		do
			l_png := build_folder.extended ("res").extended ("mipmap-xxxhdpi").extended ("ic_launcher.png")
			create l_dir.make_with_path (l_png.parent)
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end
			check attached project.icon_path as al_icon then
				create l_from.make_with_path (al_icon)
			end
			create l_to.make_with_path (l_png)
			l_from.open_read
			l_to.create_read_write
			l_from.copy_to (l_to)
			l_from.close
			l_to.close
			run_stage (Stage_package, finder.Tool_aapt2, build_folder,
				runner.quoted (tools.aapt2) + {STRING_32} " compile " + runner.quoted (l_png) + {STRING_32} " -o " + runner.quoted (build_folder))
		end

	icon_flat: PATH
			-- What aapt2 compile makes of the icon.
		do
			Result := build_folder.extended ("mipmap-xxxhdpi_ic_launcher.png.flat")
		end

	do_align
			-- zipalign, 16 KB pages for native libraries.
		do
			run_stage (Stage_align, finder.Tool_zipalign, build_folder,
				runner.quoted (tools.zipalign) + {STRING_32} " -P 16 -f 4 " + runner.quoted (unsigned_apk) + {STRING_32} " " + runner.quoted (aligned_apk))
		end

	do_check_align
			-- zipalign -c: prove the alignment before signing (RA-14).
		do
			run_stage (Stage_check_align, finder.Tool_zipalign, build_folder,
				runner.quoted (tools.zipalign) + {STRING_32} " -c -P 16 4 " + runner.quoted (aligned_apk))
		end

	do_sign
			-- apksigner sign, then verify.
		local
			l_key: EIFPHONE_KEYSTORE
		do
			create l_key.make (project, tools)
			if l_key.is_debug then
				l_key.ensure_debug_key
			end
			if not l_key.last_error.is_empty then
				results.extend (create {EIFPHONE_STAGE_RESULT}.make_failure (Stage_sign, 0.0, log_for (Stage_sign), l_key.last_error))
			elseif not l_key.is_debug and then not l_key.release_password_available then
				check attached project.password_env as al_v then
					results.extend (create {EIFPHONE_STAGE_RESULT}.make_failure (Stage_sign, 0.0, log_for (Stage_sign),
						{STRING_32} "the release password variable " + al_v.to_string_32 + {STRING_32} " (from [signing] password_env) is not set"))
				end
			else
				apk_path := build_folder.extended (library_name + ".apk")
				run_stage (Stage_sign, finder.Tool_apksigner, build_folder,
					runner.quoted (tools.apksigner) + {STRING_32} " sign " + l_key.signer_arguments
						+ {STRING_32} " --out " + runner.quoted (apk_path) + {STRING_32} " " + runner.quoted (aligned_apk))
				if last_stage_ok then
					results.finish
					results.remove
					run_stage (Stage_sign, finder.Tool_apksigner, build_folder,
						runner.quoted (tools.apksigner) + {STRING_32} " verify " + runner.quoted (apk_path))
				end
			end
		end

feature {NONE} -- Stage support

	run_stage (a_name: READABLE_STRING_8; a_tool: READABLE_STRING_8; a_directory: PATH; a_command: READABLE_STRING_32)
			-- Run one command as stage `a_name' and append its result.
		require
			known_tool: finder.is_known_tool (a_tool)
		local
			l_log: PATH
		do
			l_log := log_for (a_name)
			runner.run (a_command, a_directory, l_log)
			if runner.succeeded then
				results.extend (create {EIFPHONE_STAGE_RESULT}.make_success (a_name, runner.last_seconds, l_log))
			else
				results.extend (create {EIFPHONE_STAGE_RESULT}.make_failure (a_name, runner.last_seconds, l_log, error_line (a_tool)))
			end
		ensure
			one_more: results.count = old results.count + 1
		end

	error_line (a_tool: READABLE_STRING_8): STRING_32
			-- First real error in the runner's output, else its last line.
		require
			known_tool: finder.is_known_tool (a_tool)
		do
			if attached finder.first_error (a_tool, runner.last_output) as al_e then
				Result := al_e
			else
				Result := finder.fallback_line (runner.last_output)
			end
		ensure
			not_blank: not Result.is_empty
			one_line: not Result.has ('%N')
		end

	last_stage_ok: BOOLEAN
			-- Did the most recent stage succeed?
		do
			Result := not results.is_empty and then results.last.is_success
		end

	selected_abis: ARRAYED_LIST [STRING_8]
			-- ABIs this build makes.
		do
			if attached only_abi as al_o then
				create Result.make (1)
				Result.extend (al_o)
			else
				Result := project.abis
			end
		end

	prepare_folders
			-- Make the build tree; remove it first when `clean_first'.
		local
			d: DIRECTORY
		do
			create d.make_with_path (build_folder)
			if clean_first and d.exists then
				d.recursive_delete
			end
			across <<"gen", "logs", "hashes", "dex", "obj", "apk">> as ic_n loop
				make_folder (build_folder.extended (ic_n))
			end
			across selected_abis as ic_a loop
				make_folder (build_folder.extended ("obj").extended (ic_a))
				make_folder (build_folder.extended ("apk").extended ("lib").extended (ic_a))
			end
		end

	make_folder (a_path: PATH)
		local
			d: DIRECTORY
		do
			create d.make_with_path (a_path)
			if not d.exists then
				d.recursive_create_dir
			end
		end

	set_environment
			-- What gec and the batch tools need.
		local
			e: SIMPLE_ENV
		do
			create e
			e.set ("ISE_EIFFEL", tools.ise_library.name)
			e.set ("ISE_LIBRARY", tools.ise_library.name)
			e.set ("ISE_PLATFORM", "win64")
			e.set ("SIMPLE_EIFFEL", tools.simple_eiffel.name)
			e.set ("GOBO_LIBRARY", tools.gobo_library.name)
			e.set ("GOBO_EIFFEL", "ise")
			runner.set_java_home (tools.jdk)
		end

	triple (a_abi: STRING_8): STRING_32
			-- Clang target for `a_abi', without the API level.
		do
			if a_abi.same_string (project.Abi_arm64) then
				Result := {STRING_32} "aarch64-linux-android"
			else
				Result := {STRING_32} "x86_64-linux-android"
			end
		end

	compile_flags (a_abi: STRING_8): STRING_32
			-- Spike 01's proven flags.
		do
			Result := {STRING_32} "--target=" + triple (a_abi) + project.min_sdk.out.to_string_32
				+ {STRING_32} " -fPIC -O2 -DNDEBUG -pthread -fno-strict-aliasing -fno-sanitize=undefined"
				+ {STRING_32} " -Wno-unused-value -Wno-tautological-compare -Wno-absolute-value -Wno-void-pointer-to-int-cast"
				+ {STRING_32} " -Wno-deprecated-declarations -Wno-deprecated-non-prototype -Wno-unused-command-line-argument"
				+ {STRING_32} " -I" + runner.quoted (generated_folder) + {STRING_32} " -I" + runner.quoted (runtime_dir.extended ("c"))
				+ {STRING_32} " -I" + runner.quoted (tools.native_app_glue) + {STRING_32} " -I" + runner.quoted (tools.boehm_gc_include)
				+ {STRING_32} " -include " + runner.quoted (runtime_dir.extended ("c").extended ("sephone_fastjmp.h"))
			Result.append ({STRING_32} " -I" + runner.quoted (tools.gec_runtime_include))
				-- The ISE time library keeps its C header beside its classes.
			Result.append ({STRING_32} " -I" + runner.quoted (tools.ise_library.extended ("library").extended ("time").extended ("spec").extended ("include")))
			across project.native_abi_includes as ic loop
				Result.append ({STRING_32} " -I" + runner.quoted (project.for_abi (ic, a_abi)))
			end
			across project.native_includes as ic loop
				Result.append ({STRING_32} " -I" + runner.quoted (ic))
			end
			across project.native_defines as ic loop
				Result.append ({STRING_32} " -D" + ic.to_string_32)
			end
		end

	generated_folder: PATH
			-- Where gec writes C.
		do
			Result := build_folder.extended ("gen").extended (".gobo")
		end

	c_sources: ARRAYED_LIST [PATH]
			-- Generated C, the sephone glue, native_app_glue and any [native] sources.
		do
			Result := files_with_extension (generated_folder, "c")
			Result.extend (runtime_dir.extended ("c").extended ("sephone_glue.c"))
			Result.extend (runtime_dir.extended ("c").extended ("sephone_controls.c"))
			Result.extend (tools.native_app_glue.extended ("android_native_app_glue.c"))
			Result.append (project.native_sources)
		end

	object_of (a_abi: STRING_8; a_source: PATH): PATH
			-- Object file for `a_source'. [native] sources get their own prefix, so
			-- they can never collide with a file gec generated.
		local
			l_prefix: STRING_32
		do
			create l_prefix.make_empty
			if across project.native_sources as ic some ic.same_as (a_source) end then
				l_prefix.append ({STRING_32} "native_")
			end
			Result := build_folder.extended ("obj").extended (a_abi).extended (l_prefix + base_name (a_source) + {STRING_32} ".o")
		end

	base_name (a_path: PATH): STRING_32
			-- File name of `a_path' without its extension.
		local
			p: INTEGER
		do
			if attached a_path.entry as al_e then
				Result := al_e.name.to_string_32
			else
				Result := a_path.name.to_string_32
			end
			p := Result.last_index_of ('.', Result.count)
			if p > 1 then
				Result := Result.substring (1, p - 1)
			end
		end

	library_file (a_abi: STRING_8): PATH
			-- The .so for `a_abi'.
		do
			Result := build_folder.extended ("apk").extended ("lib").extended (a_abi).extended ("lib" + library_name + ".so")
		end

	unsigned_apk: PATH do Result := build_folder.extended ("unsigned.apk") end
	aligned_apk: PATH do Result := build_folder.extended ("aligned.apk") end

	log_for (a_stage: READABLE_STRING_8): PATH
			-- Log file for `a_stage' (spaces become dashes).
		local
			s: STRING_8
		do
			s := a_stage.to_string_8.twin
			s.replace_substring_all (" ", "-")
			Result := build_folder.extended ("logs").extended (s + ".log")
		end

feature {NONE} -- Files

	file_exists (a_path: PATH): BOOLEAN
		do
			Result := (create {RAW_FILE}.make_with_path (a_path)).exists
		end

	files_with_extension (a_folder: PATH; a_extension: STRING_8): ARRAYED_LIST [PATH]
			-- Files under `a_folder' (recursively) ending in `.<a_extension>'.
		local
			d: DIRECTORY
			p: PATH
		do
			create Result.make (8)
			create d.make_with_path (a_folder)
			if d.exists then
				across d.entries as ic loop
					if not (ic.name.same_string ({STRING_32} ".") or ic.name.same_string ({STRING_32} "..")) then
						p := a_folder.extended_path (ic)
						if (create {DIRECTORY}.make_with_path (p)).exists then
							Result.append (files_with_extension (p, a_extension))
						elseif attached ic.extension as al_x and then al_x.same_string_general (a_extension) then
							Result.extend (p)
						end
					end
				end
			end
		end

	write_text (a_path: PATH; a_text: READABLE_STRING_32)
			-- Save `a_text' as UTF-8.
		local
			f: PLAIN_TEXT_FILE
			u: UTF_CONVERTER
		do
			create f.make_with_path (a_path)
			f.open_write
			f.put_string (u.string_32_to_utf_8_string_8 (a_text))
			f.close
		end

feature {NONE} -- Hashes (FR-008)

	file_hash (a_path: PATH): NATURAL_64
			-- FNV-1a of the file's bytes.
		local
			f: RAW_FILE
		do
			create f.make_with_path (a_path)
			f.open_read
			if f.count > 0 then
				f.read_stream (f.count)
			end
			Result := bytes_hash (f.last_string)
			f.close
		end

	text_hash (a_text: READABLE_STRING_32): NATURAL_64
		local
			u: UTF_CONVERTER
		do
			Result := bytes_hash (u.string_32_to_utf_8_string_8 (a_text))
		end

	bytes_hash (a_bytes: READABLE_STRING_8): NATURAL_64
			-- FNV-1a, 64 bits.
		local
			i: INTEGER
		do
			Result := 0xCBF29CE484222325
			from i := 1 until i > a_bytes.count loop
				Result := (Result.bit_xor (a_bytes [i].natural_32_code.to_natural_64)) * 0x100000001B3
				i := i + 1
			end
		end

	header_hash: NATURAL_64
			-- All headers the C depends on: a change recompiles everything.
		do
			across files_with_extension (generated_folder, "h") as ic loop
				Result := Result + file_hash (ic)
			end
			Result := Result + file_hash (runtime_dir.extended ("c").extended ("sephone.h"))
			Result := Result + file_hash (runtime_dir.extended ("c").extended ("sephone_bridge.h"))
			Result := Result + file_hash (runtime_dir.extended ("c").extended ("sephone_fastjmp.h"))
		end

	hashes_file (a_abi: STRING_8): PATH
		do
			Result := build_folder.extended ("hashes").extended (a_abi + ".txt")
		end

	read_hashes (a_abi: STRING_8): HASH_TABLE [NATURAL_64, STRING_32]
			-- Saved "<hash> <source>" lines for `a_abi'.
		local
			f: PLAIN_TEXT_FILE
			p: INTEGER
			l: STRING_8
			u: UTF_CONVERTER
		do
			create Result.make (16)
			create f.make_with_path (hashes_file (a_abi))
			if f.exists then
				f.open_read
				from until f.end_of_file or else not f.file_readable loop
					f.read_line
					l := f.last_string
					p := l.index_of (' ', 1)
					if p > 1 and then l.substring (1, p - 1).is_natural_64 then
						Result.force (l.substring (1, p - 1).to_natural_64, u.utf_8_string_8_to_string_32 (l.substring (p + 1, l.count)))
					end
				end
				f.close
			end
		end

	write_hashes (a_abi: STRING_8; a_hashes: HASH_TABLE [NATURAL_64, STRING_32])
			-- Save the table for the next build.
		local
			s: STRING_32
		do
			create s.make (256)
			across a_hashes as ic loop
				s.append (ic.out.to_string_32 + {STRING_32} " " + @ic.key + {STRING_32} "%N")
			end
			write_text (hashes_file (a_abi), s)
		end

feature -- Statistics

	compile_count: INTEGER
			-- C files actually compiled by this builder (0 on a no-change rebuild).

feature {NONE} -- Implementation

	runner: EIFPHONE_RUNNER
	finder: EIFPHONE_ERROR_FINDER

end
