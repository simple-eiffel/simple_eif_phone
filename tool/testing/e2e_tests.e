note
	description: "[
		End-to-end tests: each one drives the real eifphone.exe as a user would
		and reads what it produced, with Android's own tools as the judge.
		Needs the built tool (EIFGENs/eifphone/F_code) and the Android tools.
		Device behavior is tested against a fake adb, a batch file standing in
		for the real one, so no device or emulator is needed here.
		Everything lands in testing/tmp/e2e.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	E2E_TESTS

inherit
	TEST_SET_BASE

feature -- Doctor (AC-1, Task 10)

	test_ac1_doctor_reports_missing_tool
			-- AC-1: a tool path pointed at nothing is named NOT FOUND, exit 1.
		local
			d: PATH
		do
			d := new_project ("doctorfile")
			toml_append (d, "%N[tools]%Nadb = %"" + slashed (d.extended ("no_such_adb.exe")) + "%"%N")
			run_tool ({STRING_32} "doctor " + text_of (d))
			assert ("exit 1: " + last_exit.out, last_exit = 1)
			assert ("adb named", last_text.has_substring ("NOT FOUND: adb"))
		end

	test_t10_missing_folder_reported
			-- A folder set to a missing path is reported missing.
		local
			d: PATH
		do
			d := new_project ("doctorfolder")
			toml_append (d, "%N[tools]%Ngobo_library = %"" + slashed (d.extended ("no_such_folder")) + "%"%N")
			run_tool ({STRING_32} "doctor " + text_of (d))
			assert ("exit 1: " + last_exit.out, last_exit = 1)
			assert ("folder named", last_text.has_substring ("NOT FOUND: gobo_library"))
		end

	test_t10_prompting_command_returns
			-- RA-2: a command that reads its input gets end-of-file at once, so
			-- it cannot hang a build. simple_process gives every child an empty
			-- input; run this suite with its own input held open to see it bite.
		do
			runner.run ({STRING_32} "findstr no_such_text", tmp_root, tmp_root.extended ("prompt.log"))
			assert ("returned promptly: " + runner.last_seconds.out, runner.last_seconds < 5.0)
			assert ("non-zero exit: " + runner.last_exit_code.out, runner.last_exit_code /= 0)
		end

feature -- Build (AC-2, AC-4, FR-008, FR-011)

	test_ac2_new_then_build
			-- AC-2: `new', then `build', gives a signed APK for both processors.
		do
			assert ("apk exists", file_exists (built_project.extended ("build").extended ("app.apk")))
			assert ("arm built", built_output.has_substring ("ok  link arm64-v8a"))
			assert ("x86 built", built_output.has_substring ("ok  link x86_64"))
			assert ("signed", built_output.has_substring ("ok  sign"))
		end

	test_native_c_reaches_the_library
			-- [native]: a project's own C is compiled, sees its define, and lands in the .so.
		local
			l_dir: PATH
		do
			l_dir := new_project ("nativec")
			write_text (l_dir.extended ("probe.c"), "#ifndef PROBE_ON%N#error PROBE_ON missing%N#endif%Nint eifphone_native_probe (void) { return 41; }%N")
			toml_append (l_dir, "%N[native]%Nsources = [%"probe.c%"]%Ndefines = [%"PROBE_ON%"]%N")
			run_tool ({STRING_32} "build " + runner.quoted (l_dir) + {STRING_32} " --abi x86_64")
			assert ("built: " + last_text, last_exit = 0)
			run_command (runner.quoted (readelf) + {STRING_32} " -s -W "
				+ runner.quoted (l_dir.extended ("build").extended ("apk").extended ("lib").extended ("x86_64").extended ("libapp.so")))
			assert ("symbol present", last_text.has_substring ("eifphone_native_probe"))
		end

	test_ac4_aligned_and_signed
			-- AC-4: Android's own tools accept the APK; every .so has 16 KB pages.
		local
			l_apk: PATH
		do
			l_apk := built_project.extended ("build").extended ("app.apk")
			run_command (runner.quoted (tools.zipalign) + {STRING_32} " -c -P 16 4 " + runner.quoted (l_apk))
			assert ("zipalign accepts: " + last_text, last_exit = 0)
			runner.set_java_home (tools.jdk)
			run_command (runner.quoted (tools.apksigner) + {STRING_32} " verify " + runner.quoted (l_apk))
			assert ("apksigner accepts: " + last_text, last_exit = 0)
			across <<"arm64-v8a", "x86_64">> as ic_abi loop
				run_command (runner.quoted (readelf) + {STRING_32} " -l -W "
					+ runner.quoted (built_project.extended ("build").extended ("apk").extended ("lib").extended (ic_abi).extended ("libapp.so")))
				assert ("readelf ran", last_exit = 0)
				across last_text.split ('%N') as ic_l loop
					if ic_l.has_substring (" LOAD ") then
						assert ("16 KB page: " + ic_l, ic_l.has_substring ("0x4000"))
					end
				end
			end
		end

	test_fr003_right_processor_and_entry_point
			-- FR-003: each .so is for its processor and exports Android's entry point.
		local
			l_lib: PATH
		do
			across <<"arm64-v8a", "x86_64">> as ic loop
				l_lib := built_project.extended ("build").extended ("apk").extended ("lib").extended (ic).extended ("libapp.so")
				run_command (runner.quoted (readelf) + {STRING_32} " -h " + runner.quoted (l_lib))
				if ic.same_string ("x86_64") then
					assert ("x86-64 machine", last_text.has_substring ("X86-64"))
				else
					assert ("arm machine", last_text.has_substring ("AArch64"))
				end
				run_command (runner.quoted (readelf) + {STRING_32} " --dyn-syms -W " + runner.quoted (l_lib))
				assert ("entry point exported", last_text.has_substring ("ANativeActivity_onCreate"))
			end
		end

	test_nfr003_apk_under_a_megabyte
			-- NFR-003: a starter APK for both processors stays under 1 MB.
		local
			l_file: RAW_FILE
		do
			create l_file.make_with_path (built_project.extended ("build").extended ("app.apk"))
			assert ("size: " + l_file.count.out, l_file.count <= 1_048_576)
		end

	test_fr008_incremental_skips_unchanged
			-- FR-008: a second build with no change recompiles no C file.
		local
			l_obj: PATH
			l_before: INTEGER
			l_file: RAW_FILE
		do
			l_obj := built_project.extended ("build").extended ("obj").extended ("x86_64").extended ("sephone_glue.o")
			create l_file.make_with_path (l_obj)
			l_before := l_file.date;
			(create {EXECUTION_ENVIRONMENT}).sleep (2_100_000_000)
			run_tool ({STRING_32} "build " + text_of (built_project))
			assert ("second build ok", last_exit = 0)
			create l_file.make_with_path (l_obj)
			assert ("object untouched", l_file.date = l_before)
		end

	test_fr011_dex_only_with_helper
			-- FR-011: without java_helper there is no dex stage and no classes.dex.
		do
			assert ("no dex stage", not built_output.has_substring ("ok  dex"))
			run_command (runner.quoted (tools.aapt) + {STRING_32} " list " + runner.quoted (built_project.extended ("build").extended ("app.apk")))
			assert ("no classes.dex", not last_text.has_substring ("classes.dex"))
			assert ("hasCode false", read_text (built_project.extended ("build").extended ("AndroidManifest.xml")).has_substring ("android:hasCode=%"false%""))
		end

	test_ac10_java_helper_scaffold
			-- AC-10: java_helper = true gives classes.dex, hasCode and the helper activity.
		local
			d: PATH
			l_manifest: STRING
		do
			d := new_project ("javahelper")
			toml_replace (d, "java_helper = false", "java_helper = true")
			run_tool ({STRING_32} "build " + text_of (d))
			assert ("built: " + last_text, last_exit = 0)
			assert ("dex stage", last_text.has_substring ("ok  dex"))
			run_command (runner.quoted (tools.aapt) + {STRING_32} " list " + runner.quoted (d.extended ("build").extended ("app.apk")))
			assert ("classes.dex", last_text.has_substring ("classes.dex"))
			l_manifest := read_text (d.extended ("build").extended ("AndroidManifest.xml"))
			assert ("hasCode true", l_manifest.has_substring ("android:hasCode=%"true%""))
			assert ("helper activity", l_manifest.has_substring ("EifPhoneActivity"))
			assert ("speech engine visible", l_manifest.has_substring ("android.intent.action.TTS_SERVICE"))
		end

	test_controls_app
			-- controls = true brings the Java helper and names the controls activity.
		local
			d: PATH
			l_manifest: STRING
		do
			d := new_project ("controlsapp")
			toml_replace (d, "java_helper = false", "controls = true")
			run_tool ({STRING_32} "build " + text_of (d))
			assert ("built: " + last_text, last_exit = 0)
			assert ("dex stage", last_text.has_substring ("ok  dex"))
			l_manifest := read_text (d.extended ("build").extended ("AndroidManifest.xml"))
			assert ("hasCode true", l_manifest.has_substring ("android:hasCode=%"true%""))
			assert ("controls activity", l_manifest.has_substring ("EifPhoneControlsActivity"))
		end

	test_q12_icon_and_permissions_in_manifest
			-- Q12: [app] icon and [android] permissions reach the finished APK.
		local
			d: PATH
			l_png: RAW_FILE
			l_copy: RAW_FILE
		do
			d := new_project ("iconperm")
			create l_png.make_with_name ("../examples/touch_pad/shots/01-empty.png")
			create l_copy.make_with_path (d.extended ("icon.png"))
			l_png.open_read
			l_copy.create_read_write
			l_png.copy_to (l_copy)
			l_png.close
			l_copy.close
			toml_replace (d, "[eiffel]", "icon = %"icon.png%"%N%N[eiffel]")
			toml_append (d, "permissions = [%"android.permission.INTERNET%"]%N")
			run_tool ({STRING_32} "build " + text_of (d))
			assert ("built: " + last_text, last_exit = 0)
			run_command (runner.quoted (tools.aapt2) + {STRING_32} " dump badging " + runner.quoted (d.extended ("build").extended ("app.apk")))
			assert ("permission in the APK", last_text.has_substring ("uses-permission: name='android.permission.INTERNET'"))
			assert ("icon in the APK: " + last_text, last_text.has_substring ("icon='res/"))
		end

	test_q12_missing_icon_named
			-- A named icon that is not there is a settings error, exit 2.
		local
			d: PATH
		do
			d := new_project ("noicon")
			toml_replace (d, "[eiffel]", "icon = %"gone.png%"%N%N[eiffel]")
			run_tool ({STRING_32} "build " + text_of (d))
			assert ("exit 2: " + last_text, last_exit = 2)
			assert ("named", last_text.has_substring ("[app] icon file not found"))
		end

feature -- Planted errors (AC-3)

	test_ac3_planted_gec_error
		do
			assert_failed_at (planted_root ("plantgec", "not_a_real_feature", ""), "generate_c")
			assert ("Eiffel code named", last_text.has_substring ("[V"))
		end

	test_ac3_planted_clang_error
		do
			assert_failed_at (planted_root ("plantclang", "broken_c", Broken_c_feature), "compile x86_64")
		end

	test_ac3_planted_link_error
		do
			assert_failed_at (planted_root ("plantlink", "broken_c", Broken_link_feature), "link x86_64")
			assert ("symbol named", last_text.has_substring ("sephone_no_such_symbol"))
		end

	test_ac3_planted_package_error
			-- A corrupt android.jar stops aapt2.
		local
			d, l_jar: PATH
		do
			d := new_project ("plantaapt")
			l_jar := d.extended ("platforms").extended ("android-36").extended ("android.jar");
			(create {DIRECTORY}.make_with_path (l_jar.parent)).recursive_create_dir
			write_text (l_jar, "this is not a jar")
			toml_append (d, "%N[tools]%Nplatform_jar = %"" + slashed (l_jar) + "%"%N")
			assert_failed_at (d, "package")
		end

	test_ac3_planted_sign_error
			-- A corrupt keystore stops apksigner.
		local
			d: PATH
		do
			d := new_project ("plantsign")
			write_text (d.extended ("bad.jks"), "this is not a keystore")
			toml_append (d, "%N[signing]%Nkeystore = %"bad.jks%"%Nalias = %"x%"%Npassword_env = %"EIFPHONE_TEST_BAD%"%N");
			(create {SIMPLE_ENV}).set ("EIFPHONE_TEST_BAD", "whatever")
			assert_failed_at (d, "sign")
		end

feature -- Signing (RA-1, RA-10)

	test_ra1_release_password_never_in_clear
			-- RA-1: the secret signs the APK, and appears in no argument and no log.
		local
			d: PATH
			l_project: EIFPHONE_PROJECT
			l_key: EIFPHONE_KEYSTORE
		do
			d := new_project ("release")
			runner.run (runner.quoted (tools.keytool) + {STRING_32} " -genkeypair -keystore "
				+ runner.quoted (d.extended ("release.jks")) + {STRING_32} " -storepass " + Secret.to_string_32 + {STRING_32} " -keypass " + Secret.to_string_32
				+ {STRING_32} " -alias rel -keyalg RSA -keysize 2048 -validity 100 -dname %"CN=release test%"",
				tmp_root, tmp_root.extended ("keytool-secret.log"))
			assert ("test key made", runner.succeeded)
			toml_append (d, "%N[signing]%Nkeystore = %"release.jks%"%Nalias = %"rel%"%Npassword_env = %"EIFPHONE_TEST_SECRET%"%N");
			(create {SIMPLE_ENV}).set ("EIFPHONE_TEST_SECRET", Secret)
			run_tool ({STRING_32} "build " + text_of (d))
			assert ("built: " + last_text, last_exit = 0)
			assert ("not in the output", not last_text.has_substring (Secret))
			create l_project.make
			l_project.load (d)
			tools.check_all
			create l_key.make (l_project, tools)
			assert ("argument names the variable", l_key.signer_arguments.has_substring ({STRING_32} "env:EIFPHONE_TEST_SECRET"))
			assert ("argument holds no secret", not l_key.signer_arguments.has_substring (Secret.to_string_32))
			across (create {DIRECTORY}.make_with_path (d.extended ("build").extended ("logs"))).entries as ic loop
				if not ic.is_current_symbol and not ic.is_parent_symbol then
					assert ("not in " + ic.name.to_string_8, not read_text (d.extended ("build").extended ("logs").extended_path (ic)).has_substring (Secret))
				end
			end
			runner.set_java_home (tools.jdk)
			run_command (runner.quoted (tools.apksigner) + {STRING_32} " verify --print-certs " + runner.quoted (d.extended ("build").extended ("app.apk")))
			assert ("signed by the release key: " + last_text, last_text.has_substring ("CN=release test"))
		end

	test_ra10_debug_keystore_override
			-- RA-10: [signing] debug_keystore moves the debug key, alone.
		local
			d: PATH
		do
			d := new_project ("debugkey")
			toml_append (d, "%N[signing]%Ndebug_keystore = %"mine.jks%"%N")
			run_tool ({STRING_32} "build " + text_of (d))
			assert ("built: " + last_text, last_exit = 0)
			assert ("key made there", file_exists (d.extended ("mine.jks")))
		end

feature -- Device, through a fake adb (Task 12, Task 14)

	test_t12_two_devices_exit_5
			-- With two devices and no --device, the tool says so, exit 5.
		local
			d: PATH
		do
			d := fake_adb_project ("twodevices", "@echo off%R%Necho List of devices attached%R%Necho emulator-5554%Tdevice%R%Necho TESTSERIAL01%Tdevice%R%N")
			run_tool ({STRING_32} "install " + text_of (d))
			assert ("exit 5: " + last_text, last_exit = 5)
			assert ("said so", last_text.has_substring ("more than one device"))
		end

	test_t12_no_device_exit_5
		local
			d: PATH
		do
			d := fake_adb_project ("nodevice", "@echo off%R%Necho List of devices attached%R%N")
			run_tool ({STRING_32} "install " + text_of (d))
			assert ("exit 5: " + last_text, last_exit = 5)
			assert ("said so", last_text.has_substring ("no device"))
		end

	test_ra13_unauthorized_device_named
			-- RA-13: a phone that has not said yes is named, not hidden.
		local
			d: PATH
		do
			d := fake_adb_project ("unauthorized", "@echo off%R%Necho List of devices attached%R%Necho TESTSERIAL01%Tunauthorized%R%N")
			run_tool ({STRING_32} "install " + text_of (d))
			assert ("exit 5: " + last_text, last_exit = 5)
			assert ("named: " + last_text, last_text.has_substring ("TESTSERIAL01") and last_text.has_substring ("unauthorized"))
		end

	test_t12_failed_install_exit_5
			-- adb's install failure reaches the user, exit 5.
		local
			d: PATH
		do
			d := fake_adb_project ("badinstall", Bad_install_adb)
			run_tool ({STRING_32} "install " + text_of (d))
			assert ("exit 5: " + last_text, last_exit = 5)
			assert ("reason shown: " + last_text, last_text.has_substring ("INSTALL_FAILED_NO_ROOM"))
		end

	test_stale_generated_c_is_cleared
			-- C left by another target must not be compiled into this one.
		local
			l_dir: PATH
		do
			l_dir := new_project ("stalec")
			run_tool ({STRING_32} "build " + runner.quoted (l_dir) + {STRING_32} " --abi x86_64")
			assert ("first build: " + last_text, last_exit = 0)
			write_text (l_dir.extended ("build").extended ("gen").extended (".gobo").extended ("left_behind.c"), "#error left behind%N")
			run_tool ({STRING_32} "build " + runner.quoted (l_dir) + {STRING_32} " --abi x86_64")
			assert ("second build: " + last_text, last_exit = 0)
		end

	test_silent_adb_does_not_hang_the_tool
			-- An adb that never answers is ended, and the tool says so, as a device problem.
		local
			d: PATH
			l_env: SIMPLE_ENV
		do
			d := fake_adb_project ("silentadb", "@echo off%R%N:spin%R%Ngoto spin%R%N")
			create l_env
			l_env.set ("EIFPHONE_ADB_SECONDS", "2")
			run_tool ({STRING_32} "install " + text_of (d))
			l_env.unset ("EIFPHONE_ADB_SECONDS")
			assert ("exit 5: " + last_text, last_exit = 5)
			assert ("said why: " + last_text, last_text.has_substring ("did not answer"))
		end

	test_fr006_log_shows_device_lines
			-- FR-006: `log' prints what the device logged.
		local
			d: PATH
		do
			d := fake_adb_project ("logshown", Test_adb)
			run_tool ({STRING_32} "log " + text_of (d))
			assert ("exit 0: " + last_text, last_exit = 0)
			assert ("line shown", last_text.has_substring ("SEPHONE-TEST PASS good_case"))
		end

	test_t14_planted_failing_test_exit_1
			-- A failing on-device test gives exit 1 and names the test.
		local
			d: PATH
		do
			d := fake_adb_project ("plantedtest", Test_adb)
			run_tool ({STRING_32} "test " + text_of (d))
			assert ("exit 1: " + last_text, last_exit = 1)
			assert ("named", last_text.has_substring ("FAIL planted_case") and last_text.has_substring ("deliberate"))
			assert ("count", last_text.has_substring ("1 passed, 1 failed"))
		end

feature {NONE} -- Fixtures

	built_project: PATH
			-- One normal project, built for both processors, shared by the tests that only read it.
		once
			Result := new_project ("built")
			toml_replace (Result, "abis = [%"x86_64%"]", "abis = [%"arm64-v8a%", %"x86_64%"]")
			run_tool ({STRING_32} "build " + text_of (Result))
			built_output_cell.put (last_text.twin)
		end

	built_output: STRING
			-- What building `built_project' printed.
		do
			if built_project.is_empty then
				create Result.make_empty
			else
				Result := built_output_cell.item
			end
		end

	built_output_cell: CELL [STRING]
		once
			create Result.put ("")
		end

	new_project (a_name: STRING): PATH
			-- A fresh `eifphone new' project for x86_64 alone (faster), in testing/tmp/e2e.
		local
			l_dir: DIRECTORY
		do
			Result := tmp_root.extended (a_name)
			create l_dir.make_with_path (Result)
			if l_dir.exists then
				l_dir.recursive_delete
			end
			run_tool ({STRING_32} "new " + text_of (Result) + {STRING_32} " --id io.github.test." + a_name.to_string_32 + {STRING_32} " --label E2E")
			assert ("new: " + last_text, last_exit = 0)
			toml_replace (Result, "abis = [%"arm64-v8a%", %"x86_64%"]", "abis = [%"x86_64%"]")
		end

	planted_root (a_name, a_call, a_feature: STRING): PATH
			-- A project whose root calls `a_call', with `a_feature' added.
		local
			l_root: PATH
			l_text: STRING
		do
			Result := new_project (a_name)
			l_root := Result.extended ("src").extended ("app_main.e")
			l_text := read_text (l_root)
			l_text.replace_substring_all ("create phone.make", "create phone.make%N%T%T%T" + a_call)
			l_text.replace_substring_all ("feature {NONE} -- Implementation", "feature {NONE} -- Implementation%N" + a_feature)
			write_text (l_root, l_text)
		end

	fake_adb_project (a_name, a_batch: STRING): PATH
			-- A project whose adb is a batch file holding `a_batch'.
		do
			Result := new_project (a_name)
			write_text (Result.extended ("fake_adb.bat"), a_batch)
			toml_append (Result, "%N[tools]%Nadb = %"" + slashed (Result.extended ("fake_adb.bat")) + "%"%N")
		end

	assert_failed_at (a_project: PATH; a_stage: STRING)
			-- `build' of `a_project' stops at `a_stage' and prints its first error.
		local
			l_lines: LIST [STRING]
			l_found: BOOLEAN
		do
			run_tool ({STRING_32} "build " + text_of (a_project))
			assert ("exit 4 at " + a_stage + ": " + last_text, last_exit = 4)
			l_lines := last_text.split ('%N')
			from l_lines.start until l_lines.after or l_found loop
				if l_lines.item.has_substring ("FAILED at " + a_stage + ":") then
					l_found := True
				end
				l_lines.forth
			end
			assert ("right stage: " + last_text, l_found)
			assert ("an error line follows: " + last_text, not l_lines.after and then
				(not l_lines.item.has_substring ("full output") and l_lines.item.count > 4))
		end

	Broken_c_feature: STRING = "%N%Tbroken_c%N%T%Texternal%N%T%T%T%"C inline%"%N%T%Talias%N%T%T%T%"this is not C at all (%"%N%T%Tend%N"

	Broken_link_feature: STRING = "%N%Tbroken_c%N%T%Texternal%N%T%T%T%"C inline%"%N%T%Talias%N%T%T%T%"extern void sephone_no_such_symbol(void); sephone_no_such_symbol();%"%N%T%Tend%N"

	Secret: STRING = "pl4nted-s3cret-XYZ"

	Bad_install_adb: STRING = "[
@echo off
if "%1"=="devices" (
echo List of devices attached
echo emulator-5554	device
exit /b 0
)
echo Failure [INSTALL_FAILED_NO_ROOM]
exit /b 1

	]"

	Test_adb: STRING = "[
@echo off
if "%1"=="devices" (
echo List of devices attached
echo emulator-5554	device
exit /b 0
)
if "%1"=="install" (
echo Success
exit /b 0
)
if "%1"=="logcat" if "%2"=="-d" (
echo I/Eiffel: SEPHONE-TEST BEGIN 2
echo I/Eiffel: SEPHONE-TEST PASS good_case
echo E/Eiffel: SEPHONE-TEST FAIL planted_case :: deliberate
echo I/Eiffel: SEPHONE-TEST END
exit /b 0
)
exit /b 0

	]"

feature {NONE} -- Tools

	tools: EIFPHONE_TOOLCHAIN
		once
			create Result.make_default
		end

	runner: EIFPHONE_RUNNER
		once
			create Result.make
		end

	readelf: PATH
		do
			Result := tools.ndk.extended ("toolchains").extended ("llvm").extended ("prebuilt").extended ("windows-x86_64").extended ("bin").extended ("llvm-readelf.exe")
		end

	tmp_root: PATH
			-- Where everything lands.
		once
			Result := (create {PATH}.make_current).absolute_path.extended ("testing").extended ("tmp").extended ("e2e");
			(create {DIRECTORY}.make_with_path (Result)).recursive_create_dir
		end

	tool_exe: PATH
		once
			Result := (create {PATH}.make_current).absolute_path.extended ("EIFGENs").extended ("eifphone").extended ("F_code").extended ("eifphone.exe")
		end

	run_tool (a_arguments: READABLE_STRING_32)
			-- Run eifphone.exe; see `last_exit', `last_text'.
		do
			run_command (runner.quoted (tool_exe) + {STRING_32} " " + a_arguments)
		end

	run_command (a_command: READABLE_STRING_32)
			-- Run `a_command'; see `last_exit', `last_text'.
		do
			runner.run (a_command, tmp_root, tmp_root.extended ("last-command.log"))
			last_exit := runner.last_exit_code
			last_text := runner.last_output.to_string_8
		end

	last_exit: INTEGER

	last_text: STRING
		attribute
			create Result.make_empty
		end

feature {NONE} -- Files

	text_of (a_path: PATH): STRING_32
		do
			Result := a_path.name.to_string_32
		end

	slashed (a_path: PATH): STRING
			-- `a_path' with forward slashes, for a TOML string.
		do
			Result := a_path.name.to_string_8
			Result.replace_substring_all ("\", "/")
		end

	file_exists (a_path: PATH): BOOLEAN
		do
			Result := (create {RAW_FILE}.make_with_path (a_path)).exists
		end

	read_text (a_path: PATH): STRING
		local
			f: RAW_FILE
		do
			create f.make_with_path (a_path)
			f.open_read
			f.read_stream (f.count)
			Result := f.last_string.twin
			f.close
		end

	write_text (a_path: PATH; a_text: STRING)
		local
			f: RAW_FILE
		do
			create f.make_with_path (a_path)
			f.create_read_write
			f.put_string (a_text)
			f.close
		end

	toml_replace (a_dir: PATH; a_old, a_new: STRING)
		local
			l_text: STRING
		do
			l_text := read_text (a_dir.extended ("eifphone.toml"))
			assert ("toml holds " + a_old, l_text.has_substring (a_old))
			l_text.replace_substring_all (a_old, a_new)
			write_text (a_dir.extended ("eifphone.toml"), l_text)
		end

	toml_append (a_dir: PATH; a_text: STRING)
		do
			write_text (a_dir.extended ("eifphone.toml"), read_text (a_dir.extended ("eifphone.toml")) + a_text)
		end

end
