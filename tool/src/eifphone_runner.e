note
	description: "[
		Runs one external command (via simple_process) in a folder, saves
		its whole output to a log file, and keeps the exit code and output
		for the caller. The only place the tool starts other programs.
	]"
	author: "Larry Rix"

class
	EIFPHONE_RUNNER

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_output.make_empty
		ensure
			nothing_run: not has_run
		end

feature -- Execution

	run (a_command: READABLE_STRING_32; a_directory: PATH; a_log: PATH)
			-- Run `a_command' in `a_directory'; write its output to `a_log'.
			-- The child gets an EMPTY stdin (simple_process execute_with_input_in_directory),
			-- so any tool that prompts reads end-of-file and fails instead of
			-- hanging the build (RA-2). JAVA_HOME is set for the child from
			-- `java_home' when given (RA-12: apksigner.bat refuses to start without it).
		require
			command_given: not a_command.is_empty
		do
			execute (a_command, a_directory)
			write_log (a_log, a_command)
		ensure
			ran: has_run
			seconds_ok: last_seconds >= 0.0
			launch_failed_is_failure: not process_started implies not succeeded
		end

	ask (a_command: READABLE_STRING_32; a_directory: PATH)
			-- Run `a_command' in `a_directory' for its output alone, with no log file.
		require
			command_given: not a_command.is_empty
		do
			execute (a_command, a_directory)
		ensure
			ran: has_run
			launch_failed_is_failure: not process_started implies not succeeded
		end

	execute (a_command: READABLE_STRING_32; a_directory: PATH)
			-- Run `a_command' in `a_directory' and keep what happened.
		require
			command_given: not a_command.is_empty
		local
			l_process: SIMPLE_PROCESS
			l_start: NATURAL_64
		do
			if attached java_home as al_j then
				(create {SIMPLE_ENV}).set ("JAVA_HOME", al_j.name)
			end
			create l_process.make
			l_start := tick_ms
			l_process.execute_with_input_in_directory (a_command, {STRING_32} "", a_directory.name)
			last_seconds := (tick_ms - l_start).to_real_64 / 1000.0
			has_run := True
			process_started := l_process.was_successful
			last_exit_code := l_process.last_exit_code
			if attached l_process.last_output as al_o then
				last_output := al_o.to_string_32
			elseif attached l_process.last_error as al_e then
				last_output := al_e.to_string_32
			else
				create last_output.make_empty
			end
		ensure
			ran: has_run
			seconds_ok: last_seconds >= 0.0
			launch_failed_is_failure: not process_started implies not succeeded
		end

	run_limited (a_command: READABLE_STRING_32; a_directory: PATH; a_log: PATH; a_seconds: INTEGER)
			-- As `run', but give up after `a_seconds': a program that never answers
			-- is ended, and `timed_out' says so.
		require
			command_given: not a_command.is_empty
			limit_positive: a_seconds > 0
		local
			l_process: SIMPLE_ASYNC_PROCESS
			l_start: NATURAL_64
			l_ignored: INTEGER
			l_killed: BOOLEAN
		do
			if attached java_home as al_j then
				(create {SIMPLE_ENV}).set ("JAVA_HOME", al_j.name)
			end
			timed_out := False
			create l_process.make
			l_start := tick_ms
			l_process.start_in_directory (a_command, a_directory.name)
			process_started := l_process.was_started_successfully
			if process_started then
				from until not l_process.is_running or l_process.elapsed_seconds >= a_seconds loop
					l_ignored := l_process.wait (100)
					if attached l_process.read_available_output as al_more then
						-- Reading keeps the pipe from filling; `accumulated_output' holds it.
					end
				end
				if l_process.is_running then
					l_killed := l_process.kill
					timed_out := True
					last_exit_code := -1
				else
					if attached l_process.read_available_output as al_more then
						-- The last of the output.
					end
					last_exit_code := l_process.exit_code
				end
				last_output := l_process.accumulated_output.twin
			elseif attached l_process.last_error as al_e then
				last_output := al_e.to_string_32
			else
				create last_output.make_empty
			end
			l_process.close
			last_seconds := (tick_ms - l_start).to_real_64 / 1000.0
			has_run := True
			write_log (a_log, a_command)
		ensure
			ran: has_run
			seconds_ok: last_seconds >= 0.0
			launch_failed_is_failure: not process_started implies not succeeded
			timed_out_is_failure: timed_out implies not succeeded
		end

feature -- Settings

	java_home: detachable PATH
			-- JAVA_HOME given to every child.

	set_java_home (a_path: PATH)
		do
			java_home := a_path
		ensure
			set: java_home = a_path
		end

feature -- Formatting

	quoted (a_path: PATH): STRING_32
			-- `a_path' in double quotes, for command lines (paths may hold spaces).
		do
			create Result.make_from_string ({STRING_32} "%"")
			Result.append (a_path.name)
			Result.append_character ('"')
		ensure
			opens: Result.starts_with ({STRING_32} "%"")
			closes: Result.ends_with ({STRING_32} "%"")
			at_least_quotes: Result.count >= 2
		end

feature -- Access

	has_run: BOOLEAN
	process_started: BOOLEAN
			-- Did the last `run' start the program at all?
	last_exit_code: INTEGER
	last_output: STRING_32
	last_seconds: REAL_64

	timed_out: BOOLEAN
			-- Did the last `run_limited' hit its limit?

	succeeded: BOOLEAN
			-- Did the last command start and exit with 0?
		require
			ran: has_run
		do
			Result := process_started and last_exit_code = 0
		end

feature {NONE} -- Implementation

	write_log (a_log: PATH; a_command: READABLE_STRING_32)
			-- Save the command line and all output to `a_log'.
		local
			d: DIRECTORY
			f: PLAIN_TEXT_FILE
			u: UTF_CONVERTER
		do
			create d.make_with_path (a_log.parent)
			if not d.exists then
				d.recursive_create_dir
			end
			create f.make_with_path (a_log)
			f.open_write
			f.put_string (u.string_32_to_utf_8_string_8 ({STRING_32} "$ " + a_command + {STRING_32} "%N"))
			f.put_string (u.string_32_to_utf_8_string_8 (last_output))
			f.put_string ("%N[exit " + last_exit_code.out + ", " + last_seconds.out + " s]%N")
			f.close
		end

	tick_ms: NATURAL_64
			-- Milliseconds since Windows started.
		external
			"C inline use <windows.h>"
		alias
			"return (EIF_NATURAL_64) GetTickCount64();"
		end

end
