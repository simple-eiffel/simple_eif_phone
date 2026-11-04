note
	description: "[
		eifphone: Eiffel project in, signed Android APK out.
		  eifphone doctor  [<dir>]
		  eifphone new     <dir> --id <app.id> [--label <text>]
		  eifphone build   [<dir>] [--abi arm64-v8a|x86_64] [--clean]
		  eifphone install [<dir>] [--device <serial>]
		  eifphone run     [<dir>] [--device <serial>]
		  eifphone log     [<dir>] [--crash] [--device <serial>]
		  eifphone test    [<dir>] [--device <serial>]
		Exit codes: 0 ok; 1 doctor missing tool or tests failed; 2 bad
		arguments or invalid project; 3 version pin mismatch; 4 a build stage
		failed; 5 device or install problem.
	]"
	author: "Larry Rix"

class
	EIFPHONE_APP

inherit {NONE}
	EIFPHONE_EXIT_CODES

create
	make

feature {NONE} -- Initialization

	make
			-- Run one command from the command line, then set the exit code.
			-- An unexpected failure ends in one line and exit 1, not a stack trace.
		local
			l_failed: BOOLEAN
		do
			if not l_failed then
				run_command_line
			end
			if exit_code /= Exit_ok then
				(create {EXCEPTIONS}).die (exit_code)
			end
		rescue
			l_failed := True
			exit_code := Exit_failed
			if attached (create {EXCEPTION_MANAGER}).last_exception as al_ex and then attached al_ex.description as al_d then
				say ({STRING_32} "eifphone: could not finish: " + al_d.to_string_32)
			else
				say ({STRING_32} "eifphone: could not finish")
			end
			retry
		end

feature -- Commands (each sets `exit_code' to one of the codes spec 06 lists for it)

	run_doctor (a_dir: detachable PATH)
		do
			doctor (a_dir)
		ensure
			doctor_codes: exit_code = Exit_ok or exit_code = Exit_failed or exit_code = Exit_bad_input or exit_code = Exit_pin_mismatch
		end

	run_new (a_dir: PATH; a_app_id: READABLE_STRING_8; a_label: READABLE_STRING_32)
		do
			new_project (a_dir, a_app_id, a_label)
		ensure
			new_codes: exit_code = Exit_ok or exit_code = Exit_bad_input
		end

	run_build (a_dir: PATH)
		do
			build_project (a_dir)
		ensure
			build_codes: exit_code = Exit_ok or exit_code = Exit_bad_input or exit_code = Exit_stage_failed
		end

	run_install (a_dir: PATH; a_launch: BOOLEAN; a_device: detachable READABLE_STRING_8)
		do
			install_project (a_dir, a_launch, a_device)
		ensure
			install_codes: exit_code = Exit_ok or exit_code = Exit_bad_input or exit_code = Exit_stage_failed or exit_code = Exit_device
		end

	run_log (a_dir: PATH; a_crash_only: BOOLEAN; a_device: detachable READABLE_STRING_8)
		do
			show_log (a_dir, a_crash_only, a_device)
		ensure
			log_codes: exit_code = Exit_ok or exit_code = Exit_bad_input or exit_code = Exit_device
		end

	run_test (a_dir: PATH; a_device: detachable READABLE_STRING_8)
			-- Build and install the test APK, CLEAR the device log, launch,
			-- wait for END (or a crash or time-out), then parse (RA-5).
		do
			test_project (a_dir, a_device)
		ensure
			test_codes: exit_code = Exit_ok or exit_code = Exit_failed or exit_code = Exit_bad_input
				or exit_code = Exit_stage_failed or exit_code = Exit_device
		end

feature -- Access

	exit_code: INTEGER
			-- Process exit code to report.

feature {NONE} -- Command line

	run_command_line
			-- Parse the arguments and run the command they name.
		local
			l_cli: SIMPLE_CLI
			l_rest: LIST [STRING]
			l_dir: PATH
		do
			create l_cli.make
			l_cli.set_app_info ("eifphone", "Eiffel project in, signed Android APK out", "0.1.0")
			l_cli.add_flag ("c|clean", "Remove the build folder first")
			l_cli.add_flag ("crash", "log: show crash lines only")
			l_cli.add_flag ("lenient", "doctor: a version-pin mismatch is only a warning")
			l_cli.add_option ("abi", "build: one ABI only (arm64-v8a or x86_64)", "ABI")
			l_cli.add_option ("device", "The adb device serial", "SERIAL")
			l_cli.add_option ("id", "new: the app id (e.g. io.github.me.myapp)", "ID")
			l_cli.add_option ("label", "new: the app's name on the phone", "TEXT")
			l_cli.parse
			clean_requested := l_cli.has_flag ("clean")
			lenient_requested := l_cli.has_flag ("lenient")
			abi_requested := l_cli.value_of ("abi")
			l_rest := l_cli.arguments_after_command
			if l_rest.is_empty then
				create l_dir.make_current
			else
				create l_dir.make_from_string (l_rest.first)
			end
			if attached l_cli.command as al_c then
				if al_c.same_string ("doctor") then
					if l_rest.is_empty then run_doctor (Void) else run_doctor (l_dir) end
				elseif al_c.same_string ("new") then
					if attached l_cli.value_of ("id") as al_id and not l_rest.is_empty then
						run_new (l_dir, al_id, l_cli.option_value_or_default ("label", "Eiffel App").to_string_32)
					else
						say ({STRING_32} "usage: eifphone new <dir> --id <app.id> [--label <text>]")
						exit_code := Exit_bad_input
					end
				elseif al_c.same_string ("build") then
					run_build (l_dir)
				elseif al_c.same_string ("install") then
					run_install (l_dir, False, l_cli.value_of ("device"))
				elseif al_c.same_string ("run") then
					run_install (l_dir, True, l_cli.value_of ("device"))
				elseif al_c.same_string ("log") then
					run_log (l_dir, l_cli.has_flag ("crash"), l_cli.value_of ("device"))
				elseif al_c.same_string ("test") then
					run_test (l_dir, l_cli.value_of ("device"))
				else
					say ({STRING_32} "unknown command: " + al_c.to_string_32 + {STRING_32} " (doctor, new, build, install, run, log, test)")
					exit_code := Exit_bad_input
				end
			else
				say ({STRING_32} "usage: eifphone doctor|new|build|install|run|log|test [<dir>] (--help for options)")
				exit_code := Exit_bad_input
			end
		end

	clean_requested, lenient_requested: BOOLEAN
	abi_requested: detachable STRING_8

feature {NONE} -- Doctor and new

	doctor (a_dir: detachable PATH)
		local
			t: EIFPHONE_TOOLCHAIN
			p: EIFPHONE_PROJECT
		do
			create t.make_default
			exit_code := Exit_ok
			if attached a_dir as al_d then
				create p.make
				p.load (al_d)
				if p.is_valid then
					t.apply_overrides (p)
				else
					report_errors (p)
					exit_code := Exit_bad_input
				end
			end
			if exit_code = Exit_ok then
				t.check_all
				show_tool ("gec", t.gec)
				show_tool ("gobo library", t.gobo_library)
				show_tool ("ise library", t.ise_library)
				show_tool ("simple_eiffel", t.simple_eiffel)
				show_tool ("ndk clang", t.clang)
				show_tool ("native_app_glue", t.native_app_glue)
				show_tool ("aapt2", t.aapt2)
				show_tool ("aapt", t.aapt)
				show_tool ("zipalign", t.zipalign)
				show_tool ("apksigner", t.apksigner)
				show_tool ("d8", t.d8)
				show_tool ("android.jar", t.platform_jar)
				show_tool ("javac", t.javac)
				show_tool ("keytool", t.keytool)
				show_tool ("adb", t.adb)
				across t.missing as ic loop
					say ({STRING_32} "NOT FOUND: " + ic.to_string_32)
				end
				across t.pin_mismatches as ic loop
					say ({STRING_32} "VERSION: " + ic)
				end
				if not t.is_complete then
					exit_code := Exit_failed
				elseif not t.pins_match and not lenient_requested then
					exit_code := Exit_pin_mismatch
				else
					say ({STRING_32} "doctor: all tools found")
				end
			end
		end

	show_tool (a_name: STRING_8; a_path: PATH)
		do
			say ({STRING_32} "  " + a_name.to_string_32 + {STRING_32} ": " + a_path.name)
		end

	new_project (a_dir: PATH; a_app_id: READABLE_STRING_8; a_label: READABLE_STRING_32)
		local
			t: EIFPHONE_TEMPLATE
		do
			if a_app_id.is_empty or a_label.is_empty or not (create {EIFPHONE_PROJECT}.make).is_java_package (a_app_id) then
				say ({STRING_32} "new: --id must look like a Java package, and --label must not be empty")
				exit_code := Exit_bad_input
			else
				create t.make
				t.write (a_dir, a_app_id, a_label)
				if t.last_error.is_empty then
					say ({STRING_32} "new: wrote " + a_dir.name)
					exit_code := Exit_ok
				else
					say ({STRING_32} "new: " + t.last_error)
					exit_code := Exit_bad_input
				end
			end
		end

feature {NONE} -- Build

	build_project (a_dir: PATH)
			-- Load and build; `last_build' holds the result on a real attempt.
		local
			p: EIFPHONE_PROJECT
			t: EIFPHONE_TOOLCHAIN
			b: EIFPHONE_BUILDER
		do
			last_build := Void
			create p.make
			p.load (a_dir)
			if not p.is_valid then
				report_errors (p)
				exit_code := Exit_bad_input
			else
				create t.make_default
				t.apply_overrides (p)
				t.check_all
				if not t.is_complete_for (p) then
					across t.missing as ic_m loop
						say ({STRING_32} "NOT FOUND: " + ic_m.to_string_32)
					end
					say ({STRING_32} "build: tools are missing; run eifphone doctor")
					exit_code := Exit_bad_input
				else
					create b.make (p, t, t.simple_eiffel.extended ("simple_eif_phone").extended ("runtime"))
					b.set_clean_first (clean_requested)
					if attached abi_requested as al_a and then p.abis_model [al_a] then
						b.set_only_abi (al_a)
					end
					b.build
					last_build := b
					across b.results as ic_r loop
						if ic_r.is_success then
							say ({STRING_32} "  ok  " + ic_r.name.to_string_32 + {STRING_32} " (" + ic_r.seconds.truncated_to_integer.out.to_string_32 + {STRING_32} " s)")
						end
					end
					if attached b.failed_stage as al_f then
						say ({STRING_32} "FAILED at " + al_f.name.to_string_32 + {STRING_32} ":")
						if attached al_f.first_error as al_e then
							say ({STRING_32} "  " + al_e)
						end
						say ({STRING_32} "  full output: " + al_f.log_path.name)
						exit_code := Exit_stage_failed
					else
						say ({STRING_32} "built " + b.apk_path.name)
						exit_code := Exit_ok
					end
				end
			end
		end

	last_build: detachable EIFPHONE_BUILDER
			-- The builder of the last attempt that reached the build itself.

	report_errors (a_p: EIFPHONE_PROJECT)
		do
			across a_p.errors as ic loop
				say (ic)
			end
		end

feature {NONE} -- Device

	selected_device: detachable EIFPHONE_DEVICE
			-- The target `select_device' found, if any.

	select_device (a_b: EIFPHONE_BUILDER; a_device: detachable READABLE_STRING_8)
			-- Find the ready target for `selected_device'; without one, say why and set `exit_code'.
		local
			d: EIFPHONE_DEVICE
		do
			selected_device := Void
			create d.make (a_b.tools)
			d.set_log_file (a_b.build_folder.extended ("logs").extended ("adb.log"))
			d.refresh
			if attached a_device as al_s and then not al_s.is_empty then
				d.choose (al_s)
			end
			if d.target_ready then
				selected_device := d
			else
				if d.serials.is_empty then
					say ({STRING_32} "no device: start the emulator, or pair a phone")
				else
					say ({STRING_32} "more than one device: choose with --device <serial>")
				end
				across d.skipped as ic loop
					say ({STRING_32} "not ready: " + ic.to_string_32)
				end
				exit_code := Exit_device
			end
		ensure
			found_or_failed: selected_device /= Void or exit_code = Exit_device
		end

	activity_of (a_b: EIFPHONE_BUILDER): STRING_8
		do
			if a_b.project.uses_java_helper then
				Result := a_b.Helper_activity
			else
				Result := "android.app.NativeActivity"
			end
		end

	install_project (a_dir: PATH; a_launch: BOOLEAN; a_device: detachable READABLE_STRING_8)
			-- Build, install and optionally launch.
		do
			build_project (a_dir)
			if exit_code = Exit_ok and then attached last_build as al_b then
				select_device (al_b, a_device)
			end
			if exit_code = Exit_ok and then attached last_build as al_b and then attached selected_device as al_d then
				al_d.install (al_b.apk_path)
				if al_d.last_succeeded then
					say ({STRING_32} "installed")
					if a_launch then
						al_d.clear_log
						al_d.stop (al_b.project.app_id)
						al_d.launch (al_b.project.app_id, activity_of (al_b))
						if al_d.last_succeeded then
							(create {EXECUTION_ENVIRONMENT}).sleep (3_000_000_000)
							al_d.read_log ("Eiffel", False)
							say (al_d.last_log)
						end
					end
				end
				if not al_d.last_succeeded then
					say ({STRING_32} "device: " + al_d.last_error)
					exit_code := Exit_device
				end
			end
		end

	show_log (a_dir: PATH; a_crash_only: BOOLEAN; a_device: detachable READABLE_STRING_8)
		local
			t: EIFPHONE_TOOLCHAIN
			d: EIFPHONE_DEVICE
			p: EIFPHONE_PROJECT
		do
			create p.make
			p.load (a_dir)
			if not p.is_valid then
				report_errors (p)
				exit_code := Exit_bad_input
			else
				create t.make_default
				t.apply_overrides (p)
				create d.make (t)
				d.refresh
				if attached a_device as al_s and then not al_s.is_empty then
					d.choose (al_s)
				end
				if d.target_ready then
					d.read_log ("Eiffel", a_crash_only)
					say (d.last_log)
					exit_code := Exit_ok
				else
					say ({STRING_32} "no single device ready: choose with --device <serial>")
					across d.skipped as ic loop
						say ({STRING_32} "not ready: " + ic.to_string_32)
					end
					exit_code := Exit_device
				end
			end
		end

	test_project (a_dir: PATH; a_device: detachable READABLE_STRING_8)
			-- Run a test APK and turn its SEPHONE-TEST lines into an exit code.
		local
			r: EIFPHONE_TEST_REPORT
			i: INTEGER
			l_done: BOOLEAN
		do
			build_project (a_dir)
			if exit_code = Exit_ok and then attached last_build as al_b then
				select_device (al_b, a_device)
			end
			if exit_code = Exit_ok and then attached last_build as al_b and then attached selected_device as al_d then
				al_d.install (al_b.apk_path)
				if al_d.last_succeeded then
					al_d.stop (al_b.project.app_id)
					al_d.clear_log
					al_d.launch (al_b.project.app_id, activity_of (al_b))
				end
				if not al_d.last_succeeded then
					say ({STRING_32} "device: " + al_d.last_error)
					exit_code := Exit_device
				else
					from i := 1 until l_done or i > Test_timeout_seconds loop
						(create {EXECUTION_ENVIRONMENT}).sleep (1_000_000_000)
						al_d.read_log ("Eiffel", False)
						l_done := al_d.last_log.has_substring ({STRING_32} "SEPHONE-TEST END")
							or al_d.last_log.has_substring ({STRING_32} "FATAL EXCEPTION")
							or al_d.last_log.has_substring ({STRING_32} "Fatal signal")
						i := i + 1
					end
					create r.make
					r.parse (al_d.last_log)
					say ({STRING_32} "tests: " + r.passed.out.to_string_32 + {STRING_32} " passed, " + r.failed.out.to_string_32 + {STRING_32} " failed, announced " + r.announced.out.to_string_32)
					across 1 |..| r.failed_names.count as ic loop
						say ({STRING_32} "  FAIL " + r.failed_names [ic].to_string_32 + {STRING_32} " :: " + r.failure_messages [ic])
					end
					if r.all_passed then
						exit_code := Exit_ok
					else
						if not r.saw_end then
							say ({STRING_32} "tests did not finish (no END line): crash or time-out")
						end
						exit_code := Exit_failed
					end
				end
			end
		end

	Test_timeout_seconds: INTEGER = 180

feature {NONE} -- Output

	say (a_line: READABLE_STRING_32)
			-- Print one line (UTF-8).
		local
			u: UTF_CONVERTER
		do
			io.put_string (u.string_32_to_utf_8_string_8 (a_line.to_string_32))
			io.put_new_line
		end

end
