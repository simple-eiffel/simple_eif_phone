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

feature -- Toolchain

	test_toolchain_default_paths
		local
			t: EIFPHONE_TOOLCHAIN
		do
			create t.make_default
			assert ("clang under ndk", t.clang.name.has_substring ({STRING_32} "clang.exe"))
		end

end
