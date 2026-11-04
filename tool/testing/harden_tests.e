note
	description: "[
		Phase 6: hostile input for the eifphone tool. Every test wants one of
		two things: the job works anyway, or the tool stops with a known exit
		code and a message, never a stack trace.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	HARDEN_TESTS

inherit
	E2E_TESTS

feature -- Settings files

	test_h_toml_malformed
		do
			assert_bad_toml ("hmalformed", "[app%Nid = ")
		end

	test_h_toml_empty
		do
			assert_bad_toml ("hempty", "")
		end

	test_h_toml_binary_junk
		do
			assert_bad_toml ("hjunk", "%/0/%/1/%/255/%/254/[[[===%N%/200/%/201/")
		end

	test_h_toml_missing
		local
			d: PATH
		do
			d := new_project ("hnotoml")
			(create {RAW_FILE}.make_with_path (d.extended ("eifphone.toml"))).delete
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_folder_missing
		do
			run_tool ({STRING_32} "build " + text_of (tmp_root.extended ("no_such_project")))
			assert_exit (2)
		end

	test_h_min_sdk_above_target
		local
			d: PATH
		do
			d := new_project ("hminsdk")
			toml_replace (d, "min_sdk = 26", "min_sdk = 40")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_abis_empty
		local
			d: PATH
		do
			d := new_project ("habisempty")
			toml_replace (d, "abis = [%"x86_64%"]", "abis = []")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_abis_unknown
		local
			d: PATH
		do
			d := new_project ("habisunknown")
			toml_replace (d, "abis = [%"x86_64%"]", "abis = [%"mips%"]")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_abis_duplicate
		local
			d: PATH
		do
			d := new_project ("habisdup")
			toml_replace (d, "abis = [%"x86_64%"]", "abis = [%"x86_64%", %"x86_64%"]")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_version_code_zero
		local
			d: PATH
		do
			d := new_project ("hvczero")
			toml_replace (d, "version_code = 1", "version_code = 0")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_version_code_too_big
			-- Larger than Android's version code can hold.
		local
			d: PATH
		do
			d := new_project ("hvcbig")
			toml_replace (d, "version_code = 1", "version_code = 99999999999")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_password_env_injection
		local
			d: PATH
		do
			d := new_project ("hinject")
			write_text (d.extended ("k.jks"), "x")
			toml_append (d, "%N[signing]%Nkeystore = %"k.jks%"%Nalias = %"a%"%Npassword_env = %"X & calc%"%N")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	test_h_release_password_unset
			-- The named variable is empty: a clear refusal, and no prompt.
		local
			d: PATH
		do
			d := new_project ("hnopass")
			write_text (d.extended ("k.jks"), "x")
			toml_append (d, "%N[signing]%Nkeystore = %"k.jks%"%Nalias = %"a%"%Npassword_env = %"EIFPHONE_TEST_NEVER_SET%"%N")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_known_exit
			assert ("refused: " + last_text, last_exit /= 0)
			assert ("variable named: " + last_text, last_text.has_substring ("EIFPHONE_TEST_NEVER_SET"))
		end

	test_h_ecf_missing
		local
			d: PATH
		do
			d := new_project ("hnoecf")
			(create {RAW_FILE}.make_with_path (d.extended ("app.ecf"))).delete
			run_tool ({STRING_32} "build " + text_of (d))
			assert_known_exit
			assert ("refused: " + last_text, last_exit /= 0)
		end

	test_h_target_not_in_ecf
		local
			d: PATH
		do
			d := new_project ("hnotarget")
			toml_replace (d, "target = %"app%"", "target = %"nothing_here%"")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_known_exit
			assert ("refused: " + last_text, last_exit /= 0)
		end

feature -- Names that reach the manifest

	test_h_label_xml_characters
		do
			assert_label_builds ("hlabelxml", "A & B <C> %%d", "A & B <C> %%d")
		end

	test_h_label_apostrophe
		do
			assert_label_builds ("hlabelapos", "Bob's App", "Bob's App")
		end

	test_h_label_at_sign
			-- aapt2 reads a leading @ as a resource reference.
		do
			assert_label_builds ("hlabelat", "@home", "@home")
		end

	test_h_label_question_mark
			-- aapt2 reads a leading ? as a theme reference.
		do
			assert_label_builds ("hlabelq", "?why", "?why")
		end

	test_h_label_resource_form
			-- Looks exactly like a real reference.
		do
			assert_label_builds ("hlabelres", "@string/app_name", "@string/app_name")
		end

	test_h_label_backslash
		do
			assert_label_builds ("hlabelbs", "a\\\\b", "a\\b")
		end

	test_h_label_double_quote
			-- `dump badging' prints a stored " as \".
		do
			assert_label_builds ("hlabeldq", "Say \%"hi\%"", "Say \%"hi\%"")
		end

	test_h_version_name_quotes
		local
			d: PATH
		do
			d := new_project ("hvname")
			toml_replace (d, "version_name = %"0.1.0%"", "version_name = %"1.0 'beta' <rc>%"")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
		end

	test_h_app_id_reserved_word
			-- `class' cannot be part of a Java package.
		local
			d: PATH
		do
			d := new_project ("hreserved")
			toml_replace (d, "id = %"io.github.test.hreserved%"", "id = %"io.class.app%"")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_known_exit
		end

feature -- Paths

	test_h_folder_with_spaces
		do
			run_tool ({STRING_32} "new " + quoted_text (tmp_root.extended ("with space")) + {STRING_32} " --id io.github.test.spaces --label Spaces")
			if last_exit = 2 then
				(create {DIRECTORY}.make_with_path (tmp_root.extended ("with space"))).recursive_delete;
				run_tool ({STRING_32} "new " + quoted_text (tmp_root.extended ("with space")) + {STRING_32} " --id io.github.test.spaces --label Spaces")
			end
			assert_exit (0)
			run_tool ({STRING_32} "build " + quoted_text (tmp_root.extended ("with space")) + {STRING_32} " --abi x86_64")
			assert_exit (0)
		end

	test_h_folder_with_accent
		local
			d: PATH
		do
			create d.make_from_string (tmp_root.name + {STRING_32} "\caf%/233/")
			if (create {DIRECTORY}.make_with_path (d)).exists then
				(create {DIRECTORY}.make_with_path (d)).recursive_delete
			end
			run_tool ({STRING_32} "new " + quoted_text (d) + {STRING_32} " --id io.github.test.accent --label Accent")
			assert_exit (0)
			run_tool ({STRING_32} "build " + quoted_text (d) + {STRING_32} " --abi x86_64")
			assert_known_exit
			assert ("built, or a clear reason: " + last_text, last_exit = 0 or last_text.has_substring ("FAILED at"))
		end

feature -- Stale and damaged build folders

	test_h_deleted_object_is_rebuilt
			-- The hash says unchanged, but the object is gone.
		local
			d: PATH
		do
			d := new_project ("hdelobj")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
			(create {RAW_FILE}.make_with_path (d.extended ("build").extended ("obj").extended ("x86_64").extended ("sephone_glue.o"))).delete
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
		end

	test_h_corrupt_hash_file
		local
			d: PATH
		do
			d := new_project ("hhash")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
			across (create {DIRECTORY}.make_with_path (d.extended ("build").extended ("hashes"))).entries as ic loop
				if not ic.is_current_symbol and not ic.is_parent_symbol then
					write_text (d.extended ("build").extended ("hashes").extended_path (ic), "%/1/not a hash%N=====%N")
				end
			end
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
		end

	test_h_empty_hash_file
		local
			d: PATH
		do
			d := new_project ("hhashempty")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
			across (create {DIRECTORY}.make_with_path (d.extended ("build").extended ("hashes"))).entries as ic loop
				if not ic.is_current_symbol and not ic.is_parent_symbol then
					write_text (d.extended ("build").extended ("hashes").extended_path (ic), "")
				end
			end
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
		end

	test_h_changed_eiffel_is_never_stale
			-- The other side of FR-008: changed code reaches the APK.
		local
			d, l_so: PATH
			l_before: STRING
			l_root: STRING
		do
			d := new_project ("hstale")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
			l_so := d.extended ("build").extended ("apk").extended ("lib").extended ("x86_64").extended ("libapp.so")
			l_before := read_text (l_so)
			l_root := read_text (d.extended ("src").extended ("app_main.e"))
			l_root.replace_substring_all ("0x14161C", "0x224466")
			write_text (d.extended ("src").extended ("app_main.e"), l_root)
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
			assert ("library changed", not read_text (l_so).same_string (l_before))
		end

	test_h_icon_not_an_image
		local
			d: PATH
		do
			d := new_project ("hbadicon")
			write_text (d.extended ("icon.png"), "this is not a png")
			toml_replace (d, "[eiffel]", "icon = %"icon.png%"%N%N[eiffel]")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (4)
			assert ("stage named", last_text.has_substring ("FAILED at package"))
		end

	test_h_build_folder_is_a_file
		local
			d: PATH
		do
			d := new_project ("hbuildfile")
			write_text (d.extended ("build"), "not a folder")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_known_exit
			assert ("refused: " + last_text, last_exit /= 0)
		end

	test_h_debug_keystore_impossible_path
		local
			d: PATH
		do
			d := new_project ("hkeypath")
			toml_append (d, "%N[signing]%Ndebug_keystore = %"eifphone.toml/key.jks%"%N")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_known_exit
			assert ("refused: " + last_text, last_exit /= 0)
		end

feature -- Command line

	test_h_no_arguments
		do
			run_tool ({STRING_32} "")
			assert_known_exit
		end

	test_h_unknown_command
		do
			run_tool ({STRING_32} "explode now")
			assert_exit (2)
		end

	test_h_new_into_full_folder_keeps_files
		local
			d: PATH
			l_before: STRING
		do
			d := new_project ("hfull")
			l_before := read_text (d.extended ("eifphone.toml"))
			run_tool ({STRING_32} "new " + text_of (d) + {STRING_32} " --id io.github.test.other --label Other")
			assert_exit (2)
			assert ("untouched", read_text (d.extended ("eifphone.toml")).same_string (l_before))
		end

	test_h_new_bad_id
		do
			run_tool ({STRING_32} "new " + text_of (tmp_root.extended ("hbadid")) + {STRING_32} " --id not-a-package --label X")
			assert_exit (2)
		end

feature -- A misbehaving device

	test_h_adb_missing_on_log
		local
			d: PATH
		do
			d := new_project ("hnoadb")
			toml_append (d, "%N[tools]%Nadb = %"" + slashed (d.extended ("gone.exe")) + "%"%N")
			run_tool ({STRING_32} "log " + text_of (d))
			assert_exit (5)
		end

	test_h_adb_fails
		local
			d: PATH
		do
			d := fake_adb_project ("hadbfail", "@echo off%R%Necho error: daemon not running%R%Nexit /b 1%R%N")
			run_tool ({STRING_32} "log " + text_of (d))
			assert_exit (5)
		end

	test_h_adb_garbage
		local
			d: PATH
		do
			d := fake_adb_project ("hadbjunk", "@echo off%R%Necho ??? %T%T%T nonsense%R%Necho%T%R%Necho a%Tb%Tc%R%N")
			run_tool ({STRING_32} "log " + text_of (d))
			assert_exit (5)
		end

	test_h_device_offline_named
		local
			d: PATH
		do
			d := fake_adb_project ("hoffline", "@echo off%R%Necho List of devices attached%R%Necho 10.0.0.5:5555%Toffline%R%N")
			run_tool ({STRING_32} "install " + text_of (d))
			assert_exit (5)
			assert ("named: " + last_text, last_text.has_substring ("offline"))
		end

	test_h_crash_during_tests
			-- The app dies mid-run: no END line, so not a pass.
		local
			d: PATH
		do
			d := fake_adb_project ("hcrash", Crash_adb)
			run_tool ({STRING_32} "test " + text_of (d))
			assert_exit (1)
			assert ("said so: " + last_text, last_text.has_substring ("did not finish"))
		end

feature -- Hostile logs

	test_h_report_hostile_lines
		local
			r: EIFPHONE_TEST_REPORT
		do
			across <<"", "%N%N%N", "SEPHONE-TEST", "SEPHONE-TEST ", "SEPHONE-TEST BEGIN", "SEPHONE-TEST BEGIN -5%N",
				"SEPHONE-TEST BEGIN abc%NSEPHONE-TEST END%N", "SEPHONE-TEST BEGIN 99999999999999%NSEPHONE-TEST END%N",
				"SEPHONE-TEST END%NSEPHONE-TEST END%N", "SEPHONE-TEST PASS%N", "SEPHONE-TEST FAIL%N",
				"SEPHONE-TEST FAIL x%NSEPHONE-TEST FAIL x%N", "SEPHONE-TEST FAIL  :: %N",
				"SEPHONE-TEST PASS a b c%NSEPHONE-TEST END%N"
				>> as ic loop
				create r.make
				r.parse (ic.to_string_32)
				assert ("not a pass: " + ic, not r.all_passed)
			end
		end

	test_h_report_pass_then_fail_same_name
		local
			r: EIFPHONE_TEST_REPORT
		do
			create r.make
			r.parse ({STRING_32} "SEPHONE-TEST BEGIN 1%NSEPHONE-TEST PASS a%NSEPHONE-TEST FAIL a :: late%NSEPHONE-TEST END%N")
			assert ("a failure wins", not r.all_passed)
		end

	test_h_report_long_log
		local
			r: EIFPHONE_TEST_REPORT
			l_log: STRING_32
			i: INTEGER
		do
			create l_log.make (2_000_000)
			l_log.append ({STRING_32} "SEPHONE-TEST BEGIN 2000%N")
			from i := 1 until i > 2000 loop
				l_log.append ({STRING_32} "noise noise noise%NSEPHONE-TEST PASS t" + i.out.to_string_32 + {STRING_32} "%N")
				i := i + 1
			end
			l_log.append ({STRING_32} "SEPHONE-TEST END%N")
			create r.make
			r.parse (l_log)
			assert ("all counted: " + r.passed.out, r.passed = 2000 and r.all_passed)
		end

	test_h_error_finder_hostile_text
		local
			f: EIFPHONE_ERROR_FINDER
			l_long: STRING_32
		do
			create f
			create l_long.make_filled ('x', 1_000_000)
			across <<f.Tool_gec, f.Tool_clang, f.Tool_aapt2, f.Tool_adb, f.Tool_keytool>> as ic loop
				assert ("empty", f.first_error (ic, {STRING_32} "") = Void)
				assert ("blank", f.first_error (ic, {STRING_32} "%N%N%R%N") = Void)
				assert ("long", f.first_error (ic, l_long) = Void)
			end
		end

feature {NONE} -- Helpers

	assert_bad_toml (a_name, a_text: STRING)
			-- A project whose eifphone.toml holds `a_text' is refused, exit 2.
		local
			d: PATH
		do
			d := new_project (a_name)
			write_text (d.extended ("eifphone.toml"), a_text)
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (2)
		end

	assert_label_builds (a_name, a_label, a_expected: STRING)
			-- A project labeled `a_label' builds, and the APK shows `a_expected'.
		local
			d: PATH
		do
			d := new_project (a_name)
			toml_replace (d, "label = %"E2E%"", "label = %"" + a_label + "%"")
			run_tool ({STRING_32} "build " + text_of (d))
			assert_exit (0)
			run_command (runner.quoted (tools.aapt2) + {STRING_32} " dump badging " + runner.quoted (d.extended ("build").extended ("app.apk")))
			assert ("label shown: " + last_text, last_text.has_substring ("application: label='" + a_expected + "'"))
		end

	assert_exit (a_code: INTEGER)
			-- The last command ended with `a_code', cleanly.
		do
			assert_no_trace
			assert ("exit " + a_code.out + ", got " + last_exit.out + ": " + last_text, last_exit = a_code)
		end

	assert_known_exit
			-- The last command ended with one of the tool's exit codes, cleanly.
		do
			assert_no_trace
			assert ("known exit, got " + last_exit.out + ": " + last_text, 0 <= last_exit and last_exit <= 5)
		end

	assert_no_trace
			-- No Eiffel exception trace reached the user.
		do
			assert ("no trace: " + last_text, not last_text.has_substring ("-------------------------------")
				and not last_text.has_substring ("Failed") and not last_text.has_substring ("Violation"))
		end

	quoted_text (a_path: PATH): STRING_32
		do
			Result := {STRING_32} "%"" + a_path.name.to_string_32 + {STRING_32} "%""
		end

	Crash_adb: STRING = "[
@echo off
if "%1"=="devices" (
echo List of devices attached
echo emulator-5554	device
exit /b 0
)
if "%1"=="logcat" if "%2"=="-d" (
echo I/Eiffel: SEPHONE-TEST BEGIN 2
echo I/Eiffel: SEPHONE-TEST PASS one
echo F/libc: Fatal signal 11 SIGSEGV
exit /b 0
)
echo Success
exit /b 0

	]"

end
