note
	description: "[
		Tests for the eifphone tool's pure parts (stage results, error
		finder, test report, project validation, toolchain defaults).
		The slow end-to-end tests are in E2E_TESTS.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Stage results

	test_stage_result_success
		local
			r: EIFPHONE_STAGE_RESULT
		do
			create r.make_success ("generate_c", 1.5, create {PATH}.make_from_string ("build\logs\generate_c.log"))
			assert ("success", r.is_success)
			assert ("no error", r.first_error = Void)
		end

	test_stage_result_failure
		local
			r: EIFPHONE_STAGE_RESULT
		do
			create r.make_failure ("compile arm64-v8a", 0.2, create {PATH}.make_from_string ("x.log"), {STRING_32} "hello_2.c:10: error: unknown type")
			assert ("failure", not r.is_success)
			assert ("error kept", attached r.first_error as al_e and then al_e.has_substring ({STRING_32} "unknown type"))
		end

feature -- Error finder

	test_error_finder_gec
		local
			f: EIFPHONE_ERROR_FINDER
		do
			create f
			assert ("gec error found", attached f.first_error (f.Tool_gec,
				{STRING_32} "Degree 6%N[VEEN] class HELLO_APP: unknown identifier%NError code: VEEN%N") as e
				and then e.has_substring ({STRING_32} "VEEN"))
		end

	test_error_finder_clang
		local
			f: EIFPHONE_ERROR_FINDER
		do
			create f
			assert ("clang error found", attached f.first_error (f.Tool_clang,
				{STRING_32} "warning: unused%Nglue.c:12:3: error: use of undeclared identifier 'x'%N1 error generated.%N") as e
				and then e.has_substring ({STRING_32} "undeclared"))
		end

	test_error_finder_nothing
		local
			f: EIFPHONE_ERROR_FINDER
		do
			create f
			assert ("nothing", f.first_error (f.Tool_aapt2, {STRING_32} "all fine%N") = Void)
		end

feature -- Test report

	test_report_all_pass
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "x%NSEPHONE-TEST BEGIN 2%NSEPHONE-TEST PASS a%NSEPHONE-TEST PASS b%NSEPHONE-TEST END%N")
			assert ("all passed", r.all_passed)
		end

	test_report_failure_named
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "SEPHONE-TEST BEGIN 2%NSEPHONE-TEST PASS a%NSEPHONE-TEST FAIL b :: byte order%NSEPHONE-TEST END%N")
			assert ("not passed", not r.all_passed)
			assert ("b named", r.failed_names.count = 1 and then r.failed_names.first.same_string ("b"))
		end

	test_report_crash_is_not_pass
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "SEPHONE-TEST BEGIN 2%NSEPHONE-TEST PASS a%N")
			assert ("no END = not a pass", not r.all_passed)
		end

	test_report_zero_tests_is_not_pass
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "SEPHONE-TEST BEGIN 0%NSEPHONE-TEST END%N")
			assert ("zero tests = not a pass", not r.all_passed)
		end

feature -- Project

	test_project_java_package_names
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			assert ("good", p.is_java_package ("io.github.ljr1981.eifphone.hello"))
			assert ("one part", not p.is_java_package ("hello"))
			assert ("digit first", not p.is_java_package ("io.1bad"))
			assert ("dash", not p.is_java_package ("io.bad-name"))
		end

	test_project_valid_file
			-- A complete eifphone.toml loads with no errors.
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (project_folder ("valid", Good_toml))
			assert ("valid: " + p.errors.count.out, p.is_valid)
			assert ("id", p.app_id.same_string ("io.github.test.app"))
			assert ("two abis", p.abis.count = 2)
			assert ("debug signing", not p.has_release_key)
		end

	test_project_launch_activity
			-- Each kind of app starts its own activity.
		local
			p: EIFPHONE_PROJECT
			l_toml: STRING
		do
			create p.make
			p.load (project_folder ("plainapp", Good_toml))
			assert ("plain", p.launch_activity.same_string ("android.app.NativeActivity"))
			l_toml := Good_toml.twin
			l_toml.replace_substring_all ("min_sdk = 26", "min_sdk = 26%Njava_helper = true")
			p.load (project_folder ("helperapp", l_toml))
			assert ("helper", p.launch_activity.ends_with ("EifPhoneActivity"))
			l_toml := Good_toml.twin
			l_toml.replace_substring_all ("min_sdk = 26", "min_sdk = 26%Ncontrols = true")
			p.load (project_folder ("controlsproject", l_toml))
			assert ("controls", p.launch_activity.ends_with ("EifPhoneControlsActivity"))
		end

	test_project_orientation_kept
			-- orientation is optional, and kept when given.
		local
			p: EIFPHONE_PROJECT
			l_toml: STRING
		do
			create p.make
			p.load (project_folder ("noorient", Good_toml))
			assert ("valid without", p.is_valid)
			assert ("follows the phone", p.orientation = Void)
			l_toml := Good_toml.twin
			l_toml.replace_substring_all ("min_sdk = 26", "min_sdk = 26%Norientation = %"portrait%"")
			p.load (project_folder ("orient", l_toml))
			assert ("valid with", p.is_valid)
			assert ("kept", attached p.orientation as al_o and then al_o.same_string ({STRING_32} "portrait"))
		end

	test_project_bad_orientation_named
			-- Only portrait and landscape are allowed.
		local
			p: EIFPHONE_PROJECT
			l_toml: STRING
		do
			create p.make
			l_toml := Good_toml.twin
			l_toml.replace_substring_all ("min_sdk = 26", "min_sdk = 26%Norientation = %"sideways%"")
			p.load (project_folder ("badorient", l_toml))
			assert ("invalid", not p.is_valid)
			assert ("named", p.errors.first.starts_with ({STRING_32} "eifphone.toml: [android] orientation"))
		end

	test_project_bad_min_sdk_named
			-- min_sdk = 21 gives an error naming the file, the table and the key.
		local
			p: EIFPHONE_PROJECT
			l_toml: STRING
		do
			create p.make
			l_toml := Good_toml.twin
			l_toml.replace_substring_all ("min_sdk = 26", "min_sdk = 21")
			p.load (project_folder ("minsdk", l_toml))
			assert ("invalid", not p.is_valid)
			assert ("one error", p.errors.count = 1)
			assert ("named", p.errors.first.starts_with ({STRING_32} "eifphone.toml: [android] min_sdk"))
		end

	test_project_half_signing_named
			-- RA-3: a [signing] table with only a keystore names the two missing keys.
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (project_folder ("halfsign", Good_toml + "%N[signing]%Nkeystore = %"rel.jks%"%N"))
			assert ("invalid", not p.is_valid)
			assert ("two errors", p.errors.count = 2)
			assert ("alias named", across p.errors as ic some ic.has_substring ({STRING_32} "alias is missing") end)
			assert ("password_env named", across p.errors as ic some ic.has_substring ({STRING_32} "password_env is missing") end)
		end

	test_project_native_read
			-- [native]: sources, include folders and defines all arrive, as absolute paths.
		local
			p: EIFPHONE_PROJECT
			l_dir: PATH
		do
			l_dir := project_folder ("nativeok", Good_toml + "%N[native]%Nsources = [%"extra.c%"]%Ninclude = [%".%"]%Ndefines = [%"ALPHA%", %"BETA=2%"]%N")
			touch (l_dir.extended ("extra.c"))
			create p.make
			p.load (l_dir)
			assert ("valid: " + p.errors.count.out, p.is_valid)
			assert ("one source", p.native_sources.count = 1)
			assert ("absolute", p.native_sources.first.is_absolute)
			assert ("one include", p.native_includes.count = 1)
			assert ("two defines", p.native_defines.count = 2)
		end

	test_project_libraries_per_abi
			-- [native] libraries: $ABI is filled in for each processor type, and asking
			-- for one leaves the file's text ready for the next. (A build for two types
			-- once linked the second against the first's libraries.)
		local
			p: EIFPHONE_PROJECT
			l_dir: PATH
		do
			l_dir := project_folder ("nativeabi", Good_toml + "%N[native]%Nlibraries = [%"lib/$ABI/libx.a%"]%Ninclude = [%"inc/$ABI%"]%N")
			create p.make
			p.load (l_dir)
			assert ("valid: " + p.errors.count.out, p.is_valid)
			assert ("one library", p.native_libraries.count = 1)
			assert ("one per-type include", p.native_abi_includes.count = 1)
			assert ("first type", p.for_abi (p.native_libraries.first, "arm64-v8a").name.has_substring ("arm64-v8a"))
			assert ("second type", p.for_abi (p.native_libraries.first, "x86_64").name.has_substring ("x86_64"))
			assert ("text unchanged", p.native_libraries.first.has_substring ("$ABI"))
		end

	test_project_library_must_be_an_archive
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (project_folder ("nativenota", Good_toml + "%N[native]%Nlibraries = [%"libx.so%"]%N"))
			assert ("refused", not p.is_valid)
		end

	test_project_no_native_is_fine
			-- Most apps have no [native] table.
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (project_folder ("nonative", Good_toml))
			assert ("valid", p.is_valid)
			assert ("no sources", p.native_sources.is_empty)
		end

	test_project_native_missing_source_named
			-- A source that is not there is a settings error, by name.
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (project_folder ("nativemiss", Good_toml + "%N[native]%Nsources = [%"gone.c%"]%N"))
			assert ("invalid", not p.is_valid)
			assert ("named", p.errors.first.has_substring ({STRING_32} "[native]") and p.errors.first.has_substring ({STRING_32} "gone.c"))
		end

	test_project_native_only_c_sources
			-- A source must be a .c file.
		local
			p: EIFPHONE_PROJECT
			l_dir: PATH
		do
			l_dir := project_folder ("nativetxt", Good_toml + "%N[native]%Nsources = [%"notes.txt%"]%N")
			touch (l_dir.extended ("notes.txt"))
			create p.make
			p.load (l_dir)
			assert ("invalid", not p.is_valid)
		end

	test_project_native_same_name_refused
			-- Two sources with one file name would share an object file.
		local
			p: EIFPHONE_PROJECT
			l_dir: PATH
			l_sub: DIRECTORY
		do
			l_dir := project_folder ("nativedup", Good_toml + "%N[native]%Nsources = [%"a.c%", %"sub/a.c%"]%N")
			create l_sub.make_with_path (l_dir.extended ("sub"))
			if not l_sub.exists then
				l_sub.create_dir
			end
			touch (l_dir.extended ("a.c"))
			touch (l_dir.extended ("sub").extended ("a.c"))
			create p.make
			p.load (l_dir)
			assert ("invalid", not p.is_valid)
			assert ("said why", p.errors.first.has_substring ({STRING_32} "a.c"))
		end

	test_project_native_define_cannot_carry_a_command
			-- A define reaches clang's command line, so only NAME or NAME=value passes.
		local
			p: EIFPHONE_PROJECT
		do
			across <<"A B", "A;calc", "A&calc", "-X", "1A", "A=b c", "A=%%x%%", "">> as ic loop
				assert ("refused: " + ic, not p_default.is_native_define (ic))
			end
			assert ("plain", p_default.is_native_define ("SQLITE_ENABLE_FTS5"))
			assert ("valued", p_default.is_native_define ("SQLITE_TEMP_STORE=3"))
			create p.make
			p.load (project_folder ("nativebad", Good_toml + "%N[native]%Ndefines = [%"A;calc%"]%N"))
			assert ("invalid", not p.is_valid)
		end

	test_project_native_simple_eiffel_folder
			-- $SIMPLE_EIFFEL opens a path, so a library's C can be named in any project.
		local
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (project_folder ("nativeenv", Good_toml + "%N[native]%Ninclude = [%"$SIMPLE_EIFFEL/simple_eif_phone/runtime/c%"]%N"))
			assert ("valid", p.is_valid)
			assert ("expanded", not p.native_includes.first.name.has_substring ({STRING_32} "$"))
		end

	test_report_duplicate_pass_is_not_pass
			-- RA-5 counter-example: one test passing twice is not two tests.
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "SEPHONE-TEST BEGIN 2%NSEPHONE-TEST PASS a%NSEPHONE-TEST PASS a%NSEPHONE-TEST END%N")
			assert ("one distinct pass", r.passed = 1)
			assert ("not passed", not r.all_passed)
		end

	test_report_only_last_run_counts
			-- An earlier failing run in the same log does not count.
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "I/Eiffel: SEPHONE-TEST BEGIN 1%NI/Eiffel: SEPHONE-TEST FAIL a :: old%NI/Eiffel: SEPHONE-TEST END%N"
				+ "I/Eiffel: SEPHONE-TEST BEGIN 1%R%NI/Eiffel: SEPHONE-TEST PASS a%R%NI/Eiffel: SEPHONE-TEST END%R%N")
			assert ("last run passed", r.all_passed)
		end

feature {NONE} -- Fixtures

	Good_toml: STRING = "[app]%Nid = %"io.github.test.app%"%Nlabel = %"Test%"%Nversion_code = 1%Nversion_name = %"0.1.0%"%N%N[eiffel]%Necf = %"app.ecf%"%Ntarget = %"app%"%N%N[android]%Nabis = [%"arm64-v8a%", %"x86_64%"]%Nmin_sdk = 26%Ntarget_sdk = 36%N"

	p_default: EIFPHONE_PROJECT
			-- A project for its pure queries.
		do
			create Result.make
		end

	touch (a_path: PATH)
			-- Make an empty file at `a_path'.
		local
			f: PLAIN_TEXT_FILE
		do
			create f.make_with_path (a_path)
			f.create_read_write
			f.close
		end

	project_folder (a_name, a_toml: STRING): PATH
			-- A fresh folder testing/tmp/<a_name> holding eifphone.toml and an empty app.ecf.
		local
			d: DIRECTORY
			f: PLAIN_TEXT_FILE
		do
			create Result.make_from_string ("testing/tmp/" + a_name)
			create d.make_with_path (Result)
			if not d.exists then
				d.recursive_create_dir
			end
			create f.make_create_read_write (Result.extended ("eifphone.toml").name)
			f.put_string (a_toml)
			f.close
			create f.make_create_read_write (Result.extended ("app.ecf").name)
			f.close
		end

feature -- Toolchain: finding Gobo (Eric Bezault, 2026-11-05)

	test_gobo_library_is_optional
			-- With GOBO_LIBRARY unset, none is assumed and doctor does not ask for one.
		local
			t: EIFPHONE_TOOLCHAIN
			e: SIMPLE_ENV
			l_kept: detachable STRING_32
		do
			create e
			l_kept := e.get ("GOBO_LIBRARY")
			set_or_clear ("GOBO_LIBRARY", Void)
			create t.make_default
			t.check_all
			set_or_clear ("GOBO_LIBRARY", l_kept)
			assert ("none assumed", t.gobo_library = Void)
			assert ("not asked for", not t.missing.has ("gobo_library"))
		end

	test_gec_found_on_path
			-- With GOBO unset, gec comes from the PATH.
		local
			t: EIFPHONE_TOOLCHAIN
			l_dir: PATH
		do
			l_dir := folder_with_gec ("gec_on_path")
			with_gobo_and_path (Void, l_dir.name)
			create t.make_default
			restore_gobo_and_path
			assert ("from the path: " + t.gec.utf_8_name, t.gec.is_same_file_as (l_dir.extended ("gec.exe")))
		end

	test_gobo_wins_over_path
			-- GOBO, when set, comes before the PATH.
		local
			t: EIFPHONE_TOOLCHAIN
			l_dir: PATH
		do
			l_dir := folder_with_gec ("gec_on_path")
			with_gobo_and_path ("C:\gobo_here", l_dir.name)
			create t.make_default
			restore_gobo_and_path
			assert ("from GOBO: " + t.gec.utf_8_name, t.gec.name.same_string ({STRING_32} "C:\gobo_here\bin\gec.exe"))
		end

	test_gec_default_when_nowhere
			-- With neither, the default location stands.
		local
			t: EIFPHONE_TOOLCHAIN
		do
			with_gobo_and_path (Void, "C:\no_such_folder_here")
			create t.make_default
			restore_gobo_and_path
			assert ("default: " + t.gec.utf_8_name, t.gec.name.same_string (t.Default_gec.to_string_32))
		end

feature {NONE} -- Gobo fixtures

	folder_with_gec (a_name: STRING_8): PATH
			-- A folder under testing\tmp holding an empty gec.exe.
		local
			l_file: RAW_FILE
		do
			Result := (create {EXECUTION_ENVIRONMENT}).current_working_path.extended ("testing").extended ("tmp").extended (a_name)
			(create {DIRECTORY}.make_with_path (Result)).recursive_create_dir
			create l_file.make_with_path (Result.extended ("gec.exe"))
			l_file.open_write
			l_file.close
		end

	with_gobo_and_path (a_gobo: detachable READABLE_STRING_GENERAL; a_path: READABLE_STRING_GENERAL)
			-- Set both, keeping what they were for `restore_gobo_and_path'.
		local
			e: SIMPLE_ENV
		do
			create e
			kept_gobo := e.get ("GOBO")
			kept_path := e.get ("PATH")
			set_or_clear ("GOBO", a_gobo)
			set_or_clear ("PATH", a_path)
		end

	restore_gobo_and_path
			-- Put back what `with_gobo_and_path' kept.
		do
			set_or_clear ("GOBO", kept_gobo)
			set_or_clear ("PATH", kept_path)
		end

	set_or_clear (a_name: READABLE_STRING_GENERAL; a_value: detachable READABLE_STRING_GENERAL)
			-- Give `a_name' the value `a_value', or remove it if there is none.
			-- Windows has no empty variables, so setting "" is not an option.
		local
			e: SIMPLE_ENV
		do
			create e
			if attached a_value as al_v and then not al_v.is_empty then
				e.set (a_name, al_v)
			else
				e.unset (a_name)
			end
		end

	kept_gobo, kept_path: detachable STRING_32

feature -- Toolchain

	test_toolchain_default_paths
		local
			t: EIFPHONE_TOOLCHAIN
		do
			create t.make_default
			assert ("clang under ndk", t.clang.name.has_substring ({STRING_32} "clang.exe"))
		end

end
