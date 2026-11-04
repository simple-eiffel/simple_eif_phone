note
	description: "Test application for the simple_eif_phone model classes (PC side)."
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running simple_eif_phone model tests...%N%N")
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
			l_hostile: ADVERSARIAL_TESTS
			l_consumer: TEST_SCOOP_CONSUMER
		do
			create l_lib_tests
			run_test (agent l_lib_tests.test_kind_families_are_disjoint, "test_kind_families_are_disjoint")
			run_test (agent l_lib_tests.test_speech_state_rules, "test_speech_state_rules")
			run_test (agent l_lib_tests.test_speech_no_engine, "test_speech_no_engine")
			run_test (agent l_lib_tests.test_speech_ignores_other_events, "test_speech_ignores_other_events")
			run_test (agent l_lib_tests.test_pick_outcomes, "test_pick_outcomes")
			run_test (agent l_lib_tests.test_pick_result_after_restart, "test_pick_result_after_restart")
			run_test (agent l_lib_tests.test_service_event_family, "test_service_event_family")
			run_test (agent l_lib_tests.test_kind_names, "test_kind_names")
			run_test (agent l_lib_tests.test_event_touch_fields, "test_event_touch_fields")
			run_test (agent l_lib_tests.test_event_key_fields, "test_event_key_fields")
			run_test (agent l_lib_tests.test_event_none, "test_event_none")
			run_test (agent l_lib_tests.test_lifecycle_normal_launch, "test_lifecycle_normal_launch")
			run_test (agent l_lib_tests.test_lifecycle_home_and_return, "test_lifecycle_home_and_return")
			run_test (agent l_lib_tests.test_lifecycle_destroy_is_final, "test_lifecycle_destroy_is_final")
			run_test (agent l_lib_tests.test_lifecycle_window_generation, "test_lifecycle_window_generation")
			run_test (agent l_lib_tests.test_lifecycle_ignores_touch, "test_lifecycle_ignores_touch")
			run_test (agent l_lib_tests.test_touches_two_fingers, "test_touches_two_fingers")
			run_test (agent l_lib_tests.test_touches_move_updates_position, "test_touches_move_updates_position")
			run_test (agent l_lib_tests.test_touches_stray_move_ignored, "test_touches_stray_move_ignored")
			run_test (agent l_lib_tests.test_touches_cancel_clears_all, "test_touches_cancel_clears_all")
			run_test (agent l_lib_tests.test_rect_size, "test_rect_size")
			run_test (agent l_lib_tests.test_lifecycle_rotation_changes_nothing, "test_lifecycle_rotation_changes_nothing")
			run_test (agent l_lib_tests.test_touches_focus_lost_clears, "test_touches_focus_lost_clears")
			create l_hostile
			run_test (agent l_hostile.test_a_resumed_before_started, "test_a_resumed_before_started")
			run_test (agent l_hostile.test_a_repeated_and_unmatched, "test_a_repeated_and_unmatched")
			run_test (agent l_hostile.test_a_window_ready_twice_counts_twice, "test_a_window_ready_twice_counts_twice")
			run_test (agent l_hostile.test_a_focus_without_window, "test_a_focus_without_window")
			run_test (agent l_hostile.test_a_destroyed_from_any_state, "test_a_destroyed_from_any_state")
			run_test (agent l_hostile.test_a_lifecycle_random_storm, "test_a_lifecycle_random_storm")
			run_test (agent l_hostile.test_a_down_twice_same_finger, "test_a_down_twice_same_finger")
			run_test (agent l_hostile.test_a_up_unknown_finger, "test_a_up_unknown_finger")
			run_test (agent l_hostile.test_a_up_with_no_fingers_and_cancel_twice, "test_a_up_with_no_fingers_and_cancel_twice")
			run_test (agent l_hostile.test_a_thirty_two_fingers, "test_a_thirty_two_fingers")
			run_test (agent l_hostile.test_a_extreme_coordinates, "test_a_extreme_coordinates")
			run_test (agent l_hostile.test_a_touch_random_storm, "test_a_touch_random_storm")
			run_test (agent l_hostile.test_a_event_largest_time, "test_a_event_largest_time")
			run_test (agent l_hostile.test_a_rect_empty_at_a_point, "test_a_rect_empty_at_a_point")
			run_test (agent l_hostile.test_a_every_kind_has_a_name, "test_a_every_kind_has_a_name")
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
			print ("  FAIL: " + a_name)
			if attached (create {EXCEPTION_MANAGER}).last_exception as al_ex then
				print ("  [" + al_ex.generating_type.name + " " + if attached al_ex.tag as al_t then al_t.to_string_8 else "" end
					+ " in " + if attached al_ex.recipient_name as al_r then al_r.to_string_8 else "?" end + "]")
			end
			print ("%N")
			failed := failed + 1
			l_retried := True
			retry
		end

feature {NONE} -- Access

	passed, failed: INTEGER

end
