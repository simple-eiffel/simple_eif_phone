note
	description: "One build stage's outcome: success, or failure with its first real error line. Immutable."
	author: "Larry Rix"

class
	EIFPHONE_STAGE_RESULT

create
	make_success,
	make_failure

feature {NONE} -- Initialization

	make_success (a_name: READABLE_STRING_8; a_seconds: REAL_64; a_log: PATH)
			-- Stage `a_name' succeeded in `a_seconds'; its output is in `a_log'.
		require
			named: not a_name.is_empty
			time_ok: a_seconds >= 0.0
		do
			name := a_name.to_string_8
			seconds := a_seconds
			log_path := a_log
			is_success := True
		ensure
			success: is_success
			no_error: first_error = Void
			name_set: name.same_string (a_name)
			seconds_set: seconds = a_seconds
			log_set: log_path = a_log
		end

	make_failure (a_name: READABLE_STRING_8; a_seconds: REAL_64; a_log: PATH; a_first_error: READABLE_STRING_32)
			-- Stage `a_name' failed; `a_first_error' is the line to show.
		require
			named: not a_name.is_empty
			time_ok: a_seconds >= 0.0
			error_given: not a_first_error.is_empty
			one_line: not a_first_error.has ('%N')
		do
			name := a_name.to_string_8
			seconds := a_seconds
			log_path := a_log
			first_error := a_first_error.to_string_32
		ensure
			failure: not is_success
			error_set: attached first_error as al_e and then al_e.same_string (a_first_error)
			name_set: name.same_string (a_name)
		end

feature -- Access

	name: STRING_8
			-- Stage name, e.g. "generate_c", "compile arm64-v8a".

	is_success: BOOLEAN

	first_error: detachable STRING_32
			-- The first real error line (failures only).

	seconds: REAL_64
			-- Wall time taken.

	log_path: PATH
			-- Full output of the stage.

invariant
	success_xor_error: is_success xor attached first_error
	named: not name.is_empty
	time_ok: seconds >= 0.0

end
