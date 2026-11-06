note
	description: "Test application for the eifphone tool."
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running eifphone tool tests...%N%N")
			run_lib_tests
			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")
			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test Runners

	run_lib_tests
		local
			l_lib_tests: LIB_TESTS
			l_hard: HARDEN_TESTS
			l_e2e: E2E_TESTS
			l_consumer: TEST_SCOOP_CONSUMER
		do
			create l_lib_tests
			run_test (agent l_lib_tests.test_project_native_read, "test_project_native_read")
			run_test (agent l_lib_tests.test_project_libraries_per_abi, "test_project_libraries_per_abi")
			run_test (agent l_lib_tests.test_project_library_must_be_an_archive, "test_project_library_must_be_an_archive")
			run_test (agent l_lib_tests.test_project_no_native_is_fine, "test_project_no_native_is_fine")
			run_test (agent l_lib_tests.test_project_native_missing_source_named, "test_project_native_missing_source_named")
			run_test (agent l_lib_tests.test_project_native_only_c_sources, "test_project_native_only_c_sources")
			run_test (agent l_lib_tests.test_project_native_same_name_refused, "test_project_native_same_name_refused")
			run_test (agent l_lib_tests.test_project_native_define_cannot_carry_a_command, "test_project_native_define_cannot_carry_a_command")
			run_test (agent l_lib_tests.test_project_native_simple_eiffel_folder, "test_project_native_simple_eiffel_folder")
			run_test (agent l_lib_tests.test_gobo_library_is_optional, "test_gobo_library_is_optional")
			run_test (agent l_lib_tests.test_gec_found_on_path, "test_gec_found_on_path")
			run_test (agent l_lib_tests.test_gobo_wins_over_path, "test_gobo_wins_over_path")
			run_test (agent l_lib_tests.test_gec_default_when_nowhere, "test_gec_default_when_nowhere")
			run_test (agent l_lib_tests.test_stage_result_success, "test_stage_result_success")
			run_test (agent l_lib_tests.test_stage_result_failure, "test_stage_result_failure")
			run_test (agent l_lib_tests.test_error_finder_gec, "test_error_finder_gec")
			run_test (agent l_lib_tests.test_error_finder_clang, "test_error_finder_clang")
			run_test (agent l_lib_tests.test_error_finder_nothing, "test_error_finder_nothing")
			run_test (agent l_lib_tests.test_report_all_pass, "test_report_all_pass")
			run_test (agent l_lib_tests.test_report_failure_named, "test_report_failure_named")
			run_test (agent l_lib_tests.test_report_crash_is_not_pass, "test_report_crash_is_not_pass")
			run_test (agent l_lib_tests.test_report_zero_tests_is_not_pass, "test_report_zero_tests_is_not_pass")
			run_test (agent l_lib_tests.test_project_java_package_names, "test_project_java_package_names")
			run_test (agent l_lib_tests.test_project_valid_file, "test_project_valid_file")
			run_test (agent l_lib_tests.test_project_launch_activity, "test_project_launch_activity")
			run_test (agent l_lib_tests.test_project_orientation_kept, "test_project_orientation_kept")
			run_test (agent l_lib_tests.test_project_bad_orientation_named, "test_project_bad_orientation_named")
			run_test (agent l_lib_tests.test_project_recorder_needs_controls, "test_project_recorder_needs_controls")
			run_test (agent l_lib_tests.test_project_bad_min_sdk_named, "test_project_bad_min_sdk_named")
			run_test (agent l_lib_tests.test_project_half_signing_named, "test_project_half_signing_named")
			run_test (agent l_lib_tests.test_report_duplicate_pass_is_not_pass, "test_report_duplicate_pass_is_not_pass")
			run_test (agent l_lib_tests.test_report_only_last_run_counts, "test_report_only_last_run_counts")
			run_test (agent l_lib_tests.test_toolchain_default_paths, "test_toolchain_default_paths")
			create l_e2e
			run_test (agent l_e2e.test_version_is_told, "test_version_is_told")
			run_test (agent l_e2e.test_help_is_told, "test_help_is_told")
			run_test (agent l_e2e.test_ac1_doctor_reports_missing_tool, "test_ac1_doctor_reports_missing_tool")
			run_test (agent l_e2e.test_t10_missing_folder_reported, "test_t10_missing_folder_reported")
			run_test (agent l_e2e.test_new_traces_only_the_checked_target, "test_new_traces_only_the_checked_target")
			run_test (agent l_e2e.test_gec_version_comes_from_gec, "test_gec_version_comes_from_gec")
			run_test (agent l_e2e.test_wrong_gec_version_named, "test_wrong_gec_version_named")
			run_test (agent l_e2e.test_t10_prompting_command_returns, "test_t10_prompting_command_returns")
			run_test (agent l_e2e.test_ac2_new_then_build, "test_ac2_new_then_build")
			run_test (agent l_e2e.test_native_c_reaches_the_library, "test_native_c_reaches_the_library")
			run_test (agent l_e2e.test_silent_adb_does_not_hang_the_tool, "test_silent_adb_does_not_hang_the_tool")
			run_test (agent l_e2e.test_stale_generated_c_is_cleared, "test_stale_generated_c_is_cleared")
			run_test (agent l_e2e.test_ac4_aligned_and_signed, "test_ac4_aligned_and_signed")
			run_test (agent l_e2e.test_fr008_incremental_skips_unchanged, "test_fr008_incremental_skips_unchanged")
			run_test (agent l_e2e.test_fr011_dex_only_with_helper, "test_fr011_dex_only_with_helper")
			run_test (agent l_e2e.test_ac10_java_helper_scaffold, "test_ac10_java_helper_scaffold")
			run_test (agent l_e2e.test_controls_app, "test_controls_app")
			run_test (agent l_e2e.test_recorder_app, "test_recorder_app")
			run_test (agent l_e2e.test_deep_folder_builds, "test_deep_folder_builds")
			run_test (agent l_e2e.test_q12_icon_and_permissions_in_manifest, "test_q12_icon_and_permissions_in_manifest")
			run_test (agent l_e2e.test_q12_missing_icon_named, "test_q12_missing_icon_named")
			run_test (agent l_e2e.test_ac3_planted_gec_error, "test_ac3_planted_gec_error")
			run_test (agent l_e2e.test_ac3_planted_clang_error, "test_ac3_planted_clang_error")
			run_test (agent l_e2e.test_ac3_planted_link_error, "test_ac3_planted_link_error")
			run_test (agent l_e2e.test_ac3_planted_package_error, "test_ac3_planted_package_error")
			run_test (agent l_e2e.test_ac3_planted_sign_error, "test_ac3_planted_sign_error")
			run_test (agent l_e2e.test_ra1_release_password_never_in_clear, "test_ra1_release_password_never_in_clear")
			run_test (agent l_e2e.test_ra10_debug_keystore_override, "test_ra10_debug_keystore_override")
			run_test (agent l_e2e.test_t12_two_devices_exit_5, "test_t12_two_devices_exit_5")
			run_test (agent l_e2e.test_t12_no_device_exit_5, "test_t12_no_device_exit_5")
			run_test (agent l_e2e.test_ra13_unauthorized_device_named, "test_ra13_unauthorized_device_named")
			run_test (agent l_e2e.test_t14_planted_failing_test_exit_1, "test_t14_planted_failing_test_exit_1")
			run_test (agent l_e2e.test_fr003_right_processor_and_entry_point, "test_fr003_right_processor_and_entry_point")
			run_test (agent l_e2e.test_nfr003_apk_under_a_megabyte, "test_nfr003_apk_under_a_megabyte")
			run_test (agent l_e2e.test_t12_failed_install_exit_5, "test_t12_failed_install_exit_5")
			run_test (agent l_e2e.test_fr006_log_shows_device_lines, "test_fr006_log_shows_device_lines")
			create l_hard
			run_test (agent l_hard.test_h_toml_malformed, "test_h_toml_malformed")
			run_test (agent l_hard.test_h_toml_empty, "test_h_toml_empty")
			run_test (agent l_hard.test_h_toml_binary_junk, "test_h_toml_binary_junk")
			run_test (agent l_hard.test_h_toml_missing, "test_h_toml_missing")
			run_test (agent l_hard.test_h_folder_missing, "test_h_folder_missing")
			run_test (agent l_hard.test_h_min_sdk_above_target, "test_h_min_sdk_above_target")
			run_test (agent l_hard.test_h_abis_empty, "test_h_abis_empty")
			run_test (agent l_hard.test_h_abis_unknown, "test_h_abis_unknown")
			run_test (agent l_hard.test_h_abis_duplicate, "test_h_abis_duplicate")
			run_test (agent l_hard.test_h_version_code_zero, "test_h_version_code_zero")
			run_test (agent l_hard.test_h_version_code_too_big, "test_h_version_code_too_big")
			run_test (agent l_hard.test_h_password_env_injection, "test_h_password_env_injection")
			run_test (agent l_hard.test_h_release_password_unset, "test_h_release_password_unset")
			run_test (agent l_hard.test_h_ecf_missing, "test_h_ecf_missing")
			run_test (agent l_hard.test_h_target_not_in_ecf, "test_h_target_not_in_ecf")
			run_test (agent l_hard.test_h_label_xml_characters, "test_h_label_xml_characters")
			run_test (agent l_hard.test_h_label_apostrophe, "test_h_label_apostrophe")
			run_test (agent l_hard.test_h_label_at_sign, "test_h_label_at_sign")
			run_test (agent l_hard.test_h_label_question_mark, "test_h_label_question_mark")
			run_test (agent l_hard.test_h_version_name_quotes, "test_h_version_name_quotes")
			run_test (agent l_hard.test_h_app_id_reserved_word, "test_h_app_id_reserved_word")
			run_test (agent l_hard.test_h_folder_with_spaces, "test_h_folder_with_spaces")
			run_test (agent l_hard.test_h_folder_with_accent, "test_h_folder_with_accent")
			run_test (agent l_hard.test_h_deleted_object_is_rebuilt, "test_h_deleted_object_is_rebuilt")
			run_test (agent l_hard.test_h_corrupt_hash_file, "test_h_corrupt_hash_file")
			run_test (agent l_hard.test_h_changed_eiffel_is_never_stale, "test_h_changed_eiffel_is_never_stale")
			run_test (agent l_hard.test_h_icon_not_an_image, "test_h_icon_not_an_image")
			run_test (agent l_hard.test_h_debug_keystore_impossible_path, "test_h_debug_keystore_impossible_path")
			run_test (agent l_hard.test_h_no_arguments, "test_h_no_arguments")
			run_test (agent l_hard.test_h_unknown_command, "test_h_unknown_command")
			run_test (agent l_hard.test_h_new_into_full_folder_keeps_files, "test_h_new_into_full_folder_keeps_files")
			run_test (agent l_hard.test_h_new_bad_id, "test_h_new_bad_id")
			run_test (agent l_hard.test_h_adb_missing_on_log, "test_h_adb_missing_on_log")
			run_test (agent l_hard.test_h_adb_fails, "test_h_adb_fails")
			run_test (agent l_hard.test_h_adb_garbage, "test_h_adb_garbage")
			run_test (agent l_hard.test_h_device_offline_named, "test_h_device_offline_named")
			run_test (agent l_hard.test_h_crash_during_tests, "test_h_crash_during_tests")
			run_test (agent l_hard.test_h_report_hostile_lines, "test_h_report_hostile_lines")
			run_test (agent l_hard.test_h_report_pass_then_fail_same_name, "test_h_report_pass_then_fail_same_name")
			run_test (agent l_hard.test_h_report_long_log, "test_h_report_long_log")
			run_test (agent l_hard.test_h_error_finder_hostile_text, "test_h_error_finder_hostile_text")
			run_test (agent l_hard.test_h_label_resource_form, "test_h_label_resource_form")
			run_test (agent l_hard.test_h_label_backslash, "test_h_label_backslash")
			run_test (agent l_hard.test_h_label_double_quote, "test_h_label_double_quote")
			run_test (agent l_hard.test_h_build_folder_is_a_file, "test_h_build_folder_is_a_file")
			run_test (agent l_hard.test_h_empty_hash_file, "test_h_empty_hash_file")
			create l_consumer
			run_test (agent l_consumer.test_scoop_compatibility, "test_scoop_compatibility")
		end

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			if attached (create {EXCEPTION_MANAGER}).last_exception as al_ex and then attached al_ex.description as al_d then
				print ("    " + al_d.to_string_8 + "%N")
			end
			failed := failed + 1
			l_retried := True
			retry
		end

feature {NONE} -- Access

	passed, failed: INTEGER

end
