note
	description: "[
		Writes the SEPHONE-TEST lines `eifphone test' reads. A test is a
		predicate: True passes, False fails, an exception (such as a
		contract violation) fails with its tag. Not a test framework:
		simple_testing stays the framework on the PC (intent Q9).
	]"
	author: "Larry Rix"

class
	PHONE_TEST_LOG

create
	make

feature {NONE} -- Initialization

	make (a_log: PHONE_LOG)
		do
			log := a_log
		end

feature -- Report

	begin (a_total: INTEGER)
			-- Announce `a_total' tests.
		do
			log.info ("SEPHONE-TEST BEGIN " + a_total.out)
		end

	step (a_name: STRING)
			-- Tell the driver script to act.
		do
			log.info ("SEPHONE-TEST STEP " + a_name)
		end

	finish
			-- All tests have run.
		do
			log.info ("SEPHONE-TEST END")
		end

	run (a_name: STRING; a_test: FUNCTION [BOOLEAN])
			-- Run `a_test' and report it under `a_name'.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				if a_test.item ([]) then
					log.info ("SEPHONE-TEST PASS " + a_name)
				else
					log.error ("SEPHONE-TEST FAIL " + a_name + " :: returned False")
				end
			end
		rescue
			l_retried := True
			if attached (create {EXCEPTION_MANAGER}).last_exception as al_ex and then attached al_ex.description as al_d then
				log.error ("SEPHONE-TEST FAIL " + a_name + " :: " + al_d.to_string_8)
			else
				log.error ("SEPHONE-TEST FAIL " + a_name + " :: exception")
			end
			retry
		end

feature {NONE} -- Access

	log: PHONE_LOG

end
