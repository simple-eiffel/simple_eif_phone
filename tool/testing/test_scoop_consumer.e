note
	description: "SCOOP consumer compatibility check for the tool's types (Phase 1 gate)."
	author: "Larry Rix"

class
	TEST_SCOOP_CONSUMER

feature -- Test

	test_scoop_compatibility
			-- The tool's main types compile and work in a SCOOP-enabled system.
		local
			l_project: EIFPHONE_PROJECT
			l_tools: EIFPHONE_TOOLCHAIN
			l_report: EIFPHONE_TEST_REPORT
			l_finder: EIFPHONE_ERROR_FINDER
		do
			create l_project.make
			create l_tools.make_default
			create l_report.make
			create l_finder
		end

end
