note
	description: "[
		An adb target: the emulator or a phone (USB or wireless debugging).
		Install, launch, stop and read the log, all through EIFPHONE_RUNNER.
	]"
	author: "Larry Rix"

class
	EIFPHONE_DEVICE

create
	make

feature {NONE} -- Initialization

	make (a_tools: EIFPHONE_TOOLCHAIN)
		do
			tools := a_tools
			create serials.make (2)
			create skipped.make (2)
			create last_error.make_empty
			create last_log.make_empty
			create runner.make
		ensure
			none_known: serials.is_empty
		end

feature -- Access

	tools: EIFPHONE_TOOLCHAIN

	serials: ARRAYED_LIST [STRING_8]
			-- Devices adb reports as ready ("device" state), from the last `refresh'.

	skipped: ARRAYED_LIST [STRING_8]
			-- Devices adb reports in any other state, as "serial (state)",
			-- for example a phone that has not yet allowed this PC.

	chosen: detachable STRING_8
			-- Serial to use; Void = the only device.

	last_succeeded: BOOLEAN
	last_error: STRING_32
	last_log: STRING_32

feature -- Model

	serials_model: MML_SET [STRING_8]
			-- `serials' as a set.
		do
			create Result
			across serials as ic loop
				Result := Result & ic
			end
		end

feature -- Settings

	choose (a_serial: READABLE_STRING_8)
		require
			not_empty: not a_serial.is_empty
		do
			chosen := a_serial.to_string_8
		ensure
			set: attached chosen as al_c and then al_c.same_string (a_serial)
		end

feature -- Basic operations

	refresh
			-- Ask adb which devices are ready.
		do
			serials.wipe_out
			skipped.wipe_out
			adb_run ("devices")
			if last_succeeded then
				across runner.last_output.split ('%N') as ic loop
					add_device_line (ic)
				end
			end
		ensure
			outcome_known: last_succeeded = last_error.is_empty
			nothing_ready_on_failure: not last_succeeded implies serials_model.is_empty
			serials_distinct: serials_model.count = serials.count
		end

	target_ready: BOOLEAN
			-- Is there exactly one device, or is `chosen' among `serials'?
		do
			if attached chosen as al_c then
				Result := across serials as ic some ic.same_string (al_c) end
			else
				Result := serials.count = 1
			end
		end

	install (a_apk: PATH)
			-- Install (replacing) `a_apk' on the target.
		require
			ready: target_ready
		do
			adb_run ({STRING_32} "install -r " + runner.quoted (a_apk))
		ensure
			outcome_known: last_succeeded = last_error.is_empty
		end

	launch (a_app_id: READABLE_STRING_8; a_activity: READABLE_STRING_8)
			-- Start `a_app_id'/`a_activity'.
		require
			ready: target_ready
			id_given: not a_app_id.is_empty
		do
			adb_run ({STRING_32} "shell am start -n " + a_app_id.to_string_32 + {STRING_32} "/" + a_activity.to_string_32)
		ensure
			outcome_known: last_succeeded = last_error.is_empty
		end

	stop (a_app_id: READABLE_STRING_8)
			-- Force-stop `a_app_id'.
		require
			ready: target_ready
		do
			adb_run ({STRING_32} "shell am force-stop " + a_app_id.to_string_32)
		ensure
			outcome_known: last_succeeded = last_error.is_empty
		end

	read_log (a_tag: READABLE_STRING_8; a_crash_only: BOOLEAN)
			-- Fetch the device log: lines under `a_tag' plus crash lines
			-- (or crash lines only) into `last_log'.
		require
			ready: target_ready
			tag_given: not a_tag.is_empty
		do
			if a_crash_only then
				adb_run ({STRING_32} "logcat -d -s AndroidRuntime:E DEBUG:* libc:F EiffelOut:*")
			else
				adb_run ({STRING_32} "logcat -d -s " + a_tag.to_string_32 + {STRING_32} ":* EifPhone:* EiffelOut:* AndroidRuntime:E DEBUG:* libc:F")
			end
			last_log := runner.last_output.twin
		ensure
			outcome_known: last_succeeded = last_error.is_empty
		end

	clear_log
			-- Empty the device log (before a test run).
		require
			ready: target_ready
		do
			adb_run ("logcat -c")
		ensure
			outcome_known: last_succeeded = last_error.is_empty
		end

feature -- Settings: log

	set_log_file (a_path: PATH)
			-- Keep adb's output in `a_path'.
		do
			log_file := a_path
		ensure
			set: log_file = a_path
		end

feature {NONE} -- Implementation

	runner: EIFPHONE_RUNNER

	log_file: PATH
			-- Where adb's output goes.
		attribute
			create Result.make_from_string ("eifphone-adb.log")
		end

	adb_limit_seconds: INTEGER
			-- How long one adb call may take. EIFPHONE_ADB_SECONDS overrides the default.
		do
			Result := Default_adb_seconds
			if attached (create {SIMPLE_ENV}).get ("EIFPHONE_ADB_SECONDS") as al_v and then al_v.is_integer and then al_v.to_integer > 0 then
				Result := al_v.to_integer
			end
		ensure
			positive: Result > 0
		end

	Default_adb_seconds: INTEGER = 300
			-- Long enough to install a large app over Wi-Fi.

	adb_run (a_arguments: READABLE_STRING_32)
			-- Run adb against the target; record success and the first error.
		local
			l_cmd: STRING_32
			f: EIFPHONE_ERROR_FINDER
		do
			l_cmd := runner.quoted (tools.adb)
			if attached chosen as al_c then
				l_cmd.append ({STRING_32} " -s " + al_c.to_string_32)
			end
			l_cmd.append ({STRING_32} " " + a_arguments)
			runner.run_limited (l_cmd, create {PATH}.make_current, log_file, adb_limit_seconds)
			create f
			last_succeeded := runner.succeeded and then not runner.last_output.has_substring ({STRING_32} "Failure [")
			if last_succeeded then
				create last_error.make_empty
			elseif runner.timed_out then
				last_error := {STRING_32} "adb did not answer within " + adb_limit_seconds.out.to_string_32 + {STRING_32} " seconds"
			elseif attached f.first_error (f.Tool_adb, runner.last_output) as al_e then
				last_error := al_e
			else
				last_error := f.fallback_line (runner.last_output)
			end
		ensure
			error_when_failed: not last_succeeded implies not last_error.is_empty
			outcome_known: last_succeeded = last_error.is_empty
		end

	add_device_line (a_line: READABLE_STRING_32)
			-- Sort a "<serial><tab><state>" line of `adb devices' into `serials' or `skipped'.
		local
			l_line: STRING_32
			p: INTEGER
		do
			l_line := a_line.to_string_32
			l_line.prune_all ('%R')
			p := l_line.index_of ('%T', 1)
			if p > 1 and then l_line.is_valid_as_string_8 then
				if l_line.substring (p + 1, l_line.count).same_string ({STRING_32} "device") then
					serials.extend (l_line.substring (1, p - 1).to_string_8)
				else
					skipped.extend (l_line.substring (1, p - 1).to_string_8 + " (" + l_line.substring (p + 1, l_line.count).to_string_8 + ")")
				end
			end
		end

end
