note
	description: "[
		Reads the SEPHONE-TEST lines a test APK writes to the log:
		  SEPHONE-TEST BEGIN <total>
		  SEPHONE-TEST PASS <name>
		  SEPHONE-TEST FAIL <name> :: <message>
		  SEPHONE-TEST END
		A run with no END (it crashed) or with zero tests is NOT a pass.
		Pure: PC-tested.
	]"
	author: "Larry Rix"

class
	EIFPHONE_TEST_REPORT

create
	make

feature {NONE} -- Initialization

	make
		do
			create passed_names.make (0)
			create failed_names.make (0)
			create failure_messages.make (0)
		ensure
			empty: total = 0 and passed = 0 and failed = 0
		end

feature -- Parsing

	parse (a_log: READABLE_STRING_32)
			-- Read the SEPHONE-TEST lines of the LAST run in `a_log': everything
			-- before the last BEGIN is ignored, and earlier results are reset.
			-- The marker may appear anywhere in a line (logcat prefixes);
			-- trailing CR is stripped. A name counts once: repeated PASS lines
			-- for one name are one pass (RA-5). A name that both passed and
			-- failed counts as failed.
		local
			l_lines: ARRAYED_LIST [STRING_32]
			l_line, l_rest, l_name: STRING_32
			l_start, i, p: INTEGER
		do
			passed_names.wipe_out
			failed_names.wipe_out
			failure_messages.wipe_out
			announced := 0
			saw_begin := False
			saw_end := False
				-- The marked lines, in order (text after the marker, trimmed).
			create l_lines.make (32)
			across a_log.split ('%N') as ic loop
				l_line := ic.to_string_32
				l_line.prune_all ('%R')
				p := l_line.substring_index (Marker, 1)
				if p > 0 then
					l_rest := l_line.substring (p + Marker.count, l_line.count)
					l_rest.adjust
					l_lines.extend (l_rest)
				end
			end
				-- Start after the last BEGIN.
			l_start := 0
			from i := 1 until i > l_lines.count loop
				if l_lines [i].starts_with ({STRING_32} "BEGIN") then
					l_start := i
				end
				i := i + 1
			end
			if l_start > 0 then
				saw_begin := True
				l_rest := l_lines [l_start].substring (6, l_lines [l_start].count)
				l_rest.adjust
				if l_rest.is_integer then
					announced := l_rest.to_integer.max (0)
				end
				from i := l_start + 1 until i > l_lines.count or saw_end loop
					l_line := l_lines [i]
					if l_line.starts_with ({STRING_32} "PASS ") then
						l_name := l_line.substring (6, l_line.count)
						l_name.adjust
						if l_name.is_valid_as_string_8 and then not l_name.is_empty
							and then not has_name (passed_names, l_name) and then not has_name (failed_names, l_name)
						then
							passed_names.extend (l_name.to_string_8)
						end
					elseif l_line.starts_with ({STRING_32} "FAIL ") then
						l_rest := l_line.substring (6, l_line.count)
						p := l_rest.substring_index ({STRING_32} " :: ", 1)
						if p > 0 then
							l_name := l_rest.substring (1, p - 1)
							l_rest := l_rest.substring (p + 4, l_rest.count)
						else
							l_name := l_rest.twin
							l_rest := {STRING_32} ""
						end
						l_name.adjust
						if l_name.is_valid_as_string_8 and then not l_name.is_empty and then not has_name (failed_names, l_name) then
							remove_name (passed_names, l_name)
							failed_names.extend (l_name.to_string_8)
							failure_messages.extend (l_rest)
						end
					elseif l_line.same_string ({STRING_32} "END") then
						saw_end := True
					end
					i := i + 1
				end
			end
			passed := passed_names.count
			failed := failed_names.count
			total := passed + failed
		ensure
			counts: passed + failed = total
			passes_distinct: passed = passed_model.count
			failed_listed: failed = failed_model.count
			no_name_both_ways: (passed_model * failed_set_model).is_empty
			messages_paired: failure_messages.count = failed_names.count
			end_needs_begin: saw_end implies saw_begin
		end

feature -- Access

	total, passed, failed: INTEGER
			-- Counted from PASS/FAIL lines.

	announced: INTEGER
			-- The number given on BEGIN (0 if none).

	saw_begin, saw_end: BOOLEAN

	passed_names: ARRAYED_LIST [STRING_8]
	failed_names: ARRAYED_LIST [STRING_8]
	failure_messages: ARRAYED_LIST [STRING_32]

	passed_model: MML_SET [STRING_8]
			-- Distinct names that passed.
		do
			create Result
			across passed_names as ic loop
				Result := Result & ic
			end
		end

	failed_model: MML_SEQUENCE [STRING_8]
		do
			create Result
			across failed_names as ic loop
				Result := Result & ic
			end
		end

	failed_set_model: MML_SET [STRING_8]
			-- Distinct names that failed.
		do
			create Result
			across failed_names as ic loop
				Result := Result & ic
			end
		end

	all_passed: BOOLEAN
			-- Complete run, at least one test, every test passed, count as announced.
		do
			Result := saw_begin and saw_end and total > 0 and failed = 0 and total = announced
		ensure
			definition: Result = (saw_begin and saw_end and total > 0 and failed = 0 and total = announced)
		end

feature -- Constants

	Marker: STRING_32 = "SEPHONE-TEST "
			-- What the phone-side test helper prints before each report line.

feature {NONE} -- Implementation

	has_name (a_list: ARRAYED_LIST [STRING_8]; a_name: READABLE_STRING_32): BOOLEAN
		do
			Result := across a_list as ic some ic.same_string_general (a_name) end
		end

	remove_name (a_list: ARRAYED_LIST [STRING_8]; a_name: READABLE_STRING_32)
		do
			from a_list.start until a_list.after loop
				if a_list.item.same_string_general (a_name) then
					a_list.remove
				else
					a_list.forth
				end
			end
		end

invariant
	non_negative: total >= 0 and passed >= 0 and failed >= 0

end
