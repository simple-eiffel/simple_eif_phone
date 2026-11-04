note
	description: "[
		Picks the first real error line out of a tool's output, by tool kind:
		gec ("Error code:"), clang/aapt2 ("error:"), apksigner/adb ("ERROR",
		"Failure", "error:"). Pure: no I/O, PC-tested.
	]"
	author: "Larry Rix"

class
	EIFPHONE_ERROR_FINDER

feature -- Tool kinds

	Tool_gec: STRING_8 = "gec"
	Tool_clang: STRING_8 = "clang"
	Tool_javac: STRING_8 = "javac"
	Tool_d8: STRING_8 = "d8"
	Tool_aapt2: STRING_8 = "aapt2"
	Tool_aapt: STRING_8 = "aapt"
	Tool_zipalign: STRING_8 = "zipalign"
	Tool_apksigner: STRING_8 = "apksigner"
	Tool_keytool: STRING_8 = "keytool"
	Tool_adb: STRING_8 = "adb"

	is_known_tool (a_tool: READABLE_STRING_8): BOOLEAN
			-- Is `a_tool' one of the kinds above?
		do
			Result := across known_tools as ic some ic.same_string (a_tool) end
		end

feature -- Query

	first_error (a_tool: READABLE_STRING_8; a_output: READABLE_STRING_32): detachable STRING_32
			-- First line of `a_output' that `a_tool' uses to report an error
			-- (trimmed), or Void if none is recognized.
		require
			known_tool: is_known_tool (a_tool)
		local
			l_line: STRING_32
		do
			across a_output.split ('%N') as ic until Result /= Void loop
				l_line := ic.to_string_32
				l_line.prune_all ('%R')
				l_line.adjust
				if not l_line.is_empty and then is_error_line (a_tool, l_line) then
					Result := l_line
				end
			end
		ensure
			from_output: attached Result as al_r implies a_output.has_substring (al_r)
			one_line: attached Result as al_r implies not al_r.has ('%N')
			not_blank: attached Result as al_r implies not al_r.is_empty
		end

	fallback_line (a_output: READABLE_STRING_32): STRING_32
			-- Last non-blank line of `a_output' (used when a tool failed but
			-- printed nothing recognizable), or "(no output)".
		local
			l_line: STRING_32
		do
			across a_output.split ('%N') as ic loop
				l_line := ic.to_string_32
				l_line.prune_all ('%R')
				l_line.adjust
				if not l_line.is_empty then
					Result := l_line
				end
			end
			if Result = Void then
				Result := {STRING_32} "(no output)"
			end
		ensure
			one_line: not Result.has ('%N')
			not_blank: not Result.is_empty
		end

feature {NONE} -- Recognizers

	is_error_line (a_tool: READABLE_STRING_8; a_line: STRING_32): BOOLEAN
			-- Does `a_line' (trimmed, no CR) report an error in `a_tool''s style?
		local
			l_lower: STRING_32
		do
			l_lower := a_line.as_lower
			if a_tool.same_string (Tool_gec) then
					-- gec: "[VUEX-1] class PROBE (2,27): ..."; ISE style "Error code: ...".
				Result := is_validity_tag_line (a_line) or a_line.starts_with ({STRING_32} "Error code:")
					or a_line.starts_with ({STRING_32} "Error:")
			elseif a_tool.same_string (Tool_clang) or a_tool.same_string (Tool_javac)
				or a_tool.same_string (Tool_aapt2) or a_tool.same_string (Tool_d8) then
				Result := l_lower.has_substring ({STRING_32} "error:") and not l_lower.has_substring ({STRING_32} "error: linker command failed")
					or l_lower.has_substring ({STRING_32} "undefined symbol")
			elseif a_tool.same_string (Tool_keytool) then
				Result := l_lower.has_substring ({STRING_32} "keytool error")
			elseif a_tool.same_string (Tool_adb) then
				Result := l_lower.has_substring ({STRING_32} "error:") or a_line.has_substring ({STRING_32} "Failure")
			else
					-- aapt, zipalign, apksigner
				Result := a_line.has_substring ({STRING_32} "ERROR") or l_lower.has_substring ({STRING_32} "error:")
					or a_line.has_substring ({STRING_32} "Verification FAILED") or a_line.has_substring ({STRING_32} "Exception")
			end
		end

	is_validity_tag_line (a_line: STRING_32): BOOLEAN
			-- Does `a_line' start like "[VEEN] " or "[VUEX-1] "?
		local
			i: INTEGER
		do
			if a_line.count >= 4 and then a_line [1] = '[' and then a_line [2].is_upper then
				i := a_line.index_of (']', 2)
				Result := i >= 4 and i <= 16
			end
		end

feature {NONE} -- Implementation

	known_tools: ARRAY [STRING_8]
		once
			Result := <<Tool_gec, Tool_clang, Tool_javac, Tool_d8, Tool_aapt2, Tool_aapt,
				Tool_zipalign, Tool_apksigner, Tool_keytool, Tool_adb>>
		end

end
