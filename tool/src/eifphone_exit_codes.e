note
	description: "Process exit codes for eifphone (single choice: one list)."
	author: "Larry Rix"

class
	EIFPHONE_EXIT_CODES

feature -- Codes

	Exit_ok: INTEGER = 0
	Exit_failed: INTEGER = 1
			-- doctor: a tool is missing; test: a test failed.
	Exit_bad_input: INTEGER = 2
			-- Bad arguments, or the project file is invalid.
	Exit_pin_mismatch: INTEGER = 3
	Exit_stage_failed: INTEGER = 4
	Exit_device: INTEGER = 5

	is_known_exit_code (a_c: INTEGER): BOOLEAN
		do
			Result := Exit_ok <= a_c and a_c <= Exit_device
		end

end
