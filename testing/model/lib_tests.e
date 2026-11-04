note
	description: "[
		Tests for the pure model classes: PHONE_EVENT_KIND, PHONE_EVENT,
		PHONE_LIFECYCLE, PHONE_TOUCHES, PHONE_RECT. Contracts do most of the
		checking; these tests drive realistic Android sequences through them.
		Skeletal in Phase 1: bodies arrive in Phase 4, more cases in Phase 5.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

	PHONE_EVENT_KIND
		undefine
			default_create
		end

feature -- Event kinds

	test_kind_families_are_disjoint
			-- Every code 0..40 is in at most one family.
		local
			k: INTEGER
		do
			from k := 0 until k > 40 loop
				assert ("at most one family " + k.out,
					is_lifecycle_kind (k).to_integer + is_touch_kind (k).to_integer + is_key_kind (k).to_integer <= 1)
				k := k + 1
			end
		end

	test_speech_state_rules
			-- Ready, speak, done; a language failure leaves the engine ready.
		local
			s: TEST_SPEECH_STATE
		do
			create s.make
			assert ("idle", not s.is_ready and not s.is_starting)
			s.begin
			assert ("starting", s.is_starting)
			s.apply (service (Kind_speech_ready, 0, ""))
			assert ("ready", s.is_ready and not s.is_starting)
			s.say
			assert ("speaking", s.is_speaking)
			s.apply (service (Kind_speech_done, s.Done_finished, ""))
			assert ("quiet", not s.is_speaking and s.is_ready)
			s.say
			s.apply (service (Kind_speech_failed, s.Failure_language, "he-IL"))
			assert ("language failure kept", s.last_failure = s.Failure_language)
			assert ("still ready", s.is_ready and not s.is_speaking)
		end

	test_speech_no_engine
			-- No engine: not ready, and the reason is kept.
		local
			s: TEST_SPEECH_STATE
		do
			create s.make
			s.begin
			s.apply (service (Kind_speech_failed, s.Failure_no_engine, ""))
			assert ("not ready", not s.is_ready and not s.is_starting)
			assert ("reason", s.last_failure = s.Failure_no_engine)
		end

	test_speech_ignores_other_events
			-- A touch or a file result changes nothing.
		local
			s: TEST_SPEECH_STATE
			e: PHONE_EVENT
		do
			create s.make
			s.begin
			create e.make_touch (Kind_touch_down, 0, 1, 2, 3)
			s.apply (e)
			s.apply (service (Kind_file_picked, 0, "a"))
			assert ("still starting", s.is_starting and not s.is_ready)
		end

	test_pick_outcomes
			-- Picked, cancelled and failed each leave one clear result.
		local
			p: TEST_PICK_STATE
		do
			create p.make
			p.open
			assert ("open", p.is_picking)
			p.apply (service (Kind_file_picked, 0, "/data/x.txt"))
			assert ("closed", not p.is_picking)
			assert ("path", attached p.last_path as al_path and then al_path.same_string_general ("/data/x.txt"))
			p.open
			assert ("fresh", p.last_path = Void)
			p.apply (service (Kind_file_cancelled, 0, ""))
			assert ("cancelled", p.was_cancelled and p.last_path = Void)
			p.open
			p.apply (service (Kind_file_failed, 0, "no room"))
			assert ("error", p.last_error.same_string_general ("no room"))
			assert ("not cancelled", not p.was_cancelled and p.last_path = Void)
		end

	test_pick_result_after_restart
			-- A result may arrive in a fresh process, with no pick open.
		local
			p: TEST_PICK_STATE
		do
			create p.make
			p.apply (service (Kind_file_picked, 0, "/data/y.txt"))
			assert ("taken", attached p.last_path)
		end

	test_service_event_family
			-- A service event is one family, and carries text, including Hebrew.
		local
			e: PHONE_EVENT
			l_word: STRING_32
		do
			create l_word.make_empty
			l_word.append_code (0x5D0)
			l_word.append_code (0x5D1)
			create e.make_service (Kind_file_picked, 0, l_word, 5)
			assert ("service", e.is_service and not e.is_touch and not e.is_key and not e.is_lifecycle)
			assert ("text", e.text.same_string (l_word))
			assert ("named", e.out_line.starts_with ("file_picked"))
			create e.make_touch (Kind_touch_up, 1, 2, 3, 4)
			assert ("touch has no text", e.text.is_empty and e.service_code = 0)
		end

	test_kind_names
			-- Names match the C side's vocabulary.
		do
			assert ("touch_down", kind_name (Kind_touch_down).same_string ("touch_down"))
			assert ("window_ready", kind_name (Kind_window_ready).same_string ("window_ready"))
			assert ("none", kind_name (Kind_none).same_string ("none"))
		end

feature -- Events

	test_event_touch_fields
		local
			e: PHONE_EVENT
		do
			create e.make_touch (Kind_touch_down, 1, 120, 340, 5000)
			assert ("touch", e.is_touch)
			assert ("id", e.pointer_id = 1)
			assert ("x", e.x = 120 and e.y = 340)
		end

	test_event_key_fields
		local
			e: PHONE_EVENT
		do
			create e.make_key (Kind_key_up, 4, 10)
			assert ("key", e.is_key)
			assert ("code", e.key_code = 4)
			assert ("no id", e.pointer_id = -1)
		end

	test_event_none
		local
			e: PHONE_EVENT
		do
			create e.make_none
			assert ("none", e.is_none)
		end

feature -- Lifecycle

	test_lifecycle_normal_launch
			-- start, resume, window, focus: the usual launch order.
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			l.apply (lc (Kind_started))
			l.apply (lc (Kind_resumed))
			l.apply (lc (Kind_window_ready))
			l.apply (lc (Kind_focus_gained))
			assert ("foreground with window", l.is_resumed and l.has_window and l.has_focus)
		end

	test_lifecycle_home_and_return
			-- Home: pause, focus lost, window lost, stop; return reverses it.
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			across <<Kind_started, Kind_resumed, Kind_window_ready, Kind_paused, Kind_focus_lost,
				Kind_window_lost, Kind_stopped>> as ic loop
				l.apply (lc (ic))
			end
			assert ("backgrounded", not l.is_started and not l.has_window)
			across <<Kind_started, Kind_resumed, Kind_window_ready>> as ic loop
				l.apply (lc (ic))
			end
			assert ("back", l.is_resumed and l.has_window)
		end

	test_lifecycle_destroy_is_final
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			l.apply (lc (Kind_started))
			l.apply (lc (Kind_destroyed))
			assert ("destroyed", l.is_destroyed and not l.is_started)
		end

	test_lifecycle_window_generation
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			l.apply (lc (Kind_window_ready))
			l.apply (lc (Kind_window_lost))
			l.apply (lc (Kind_window_ready))
			assert ("two windows", l.window_generation = 2)
		end

	test_lifecycle_ignores_touch
		local
			l: PHONE_LIFECYCLE
			e: PHONE_EVENT
		do
			create l.make
			create e.make_touch (Kind_touch_down, 0, 1, 1, 1)
			l.apply (e)
			assert ("unchanged", not l.is_started)
			assert ("recorded", l.last_applied = e)
		end

	test_lifecycle_rotation_changes_nothing
			-- With configChanges, rotation is resize + configuration: no state change.
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			across <<Kind_started, Kind_resumed, Kind_window_ready, Kind_focus_gained>> as ic loop
				l.apply (lc (ic))
			end
			l.apply (lc (Kind_configuration_changed))
			l.apply (lc (Kind_window_resized))
			l.apply (lc (Kind_content_rect_changed))
			assert ("still foreground", l.is_resumed and l.has_window and l.has_focus)
			assert ("same window", l.window_generation = 1)
		end

feature -- Touches

	test_touches_focus_lost_clears
			-- Phase 2 RB-11: losing focus lifts every finger.
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 0, 1, 1))
			t.apply (touch (Kind_touch_down, 3, 9, 9))
			t.apply (lc (Kind_focus_lost))
			assert ("cleared", t.count = 0)
		end

	test_touches_two_fingers
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 0, 10, 10))
			t.apply (touch (Kind_touch_down, 1, 50, 50))
			assert ("two", t.count = 2 and t.is_active (0) and t.is_active (1))
			t.apply (touch (Kind_touch_up, 0, 10, 10))
			assert ("one left", t.count = 1 and t.is_active (1))
		end

	test_touches_move_updates_position
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 0, 10, 10))
			t.apply (touch (Kind_touch_move, 0, 30, 40))
			assert ("moved", t.x_of (0) = 30 and t.y_of (0) = 40)
		end

	test_touches_stray_move_ignored
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_move, 7, 30, 40))
			assert ("still none", t.count = 0)
		end

	test_touches_cancel_clears_all
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 0, 1, 1))
			t.apply (touch (Kind_touch_down, 1, 2, 2))
			t.apply (touch (Kind_touch_cancel, 0, 0, 0))
			assert ("cleared", t.count = 0)
		end

feature -- Rect

	test_rect_size
		local
			r: PHONE_RECT
		do
			create r.make (0, 80, 1080, 2280)
			assert ("width", r.width = 1080)
			assert ("height", r.height = 2200)
		end

feature {NONE} -- Helpers

	lc (a_kind: INTEGER): PHONE_EVENT
			-- Lifecycle event `a_kind' at time 0.
		require
			lifecycle: is_lifecycle_kind (a_kind)
		do
			create Result.make_lifecycle (a_kind, 0)
		end

	touch (a_kind, a_id, a_x, a_y: INTEGER): PHONE_EVENT
			-- Touch event at time 0.
		require
			touch_kind: is_touch_kind (a_kind)
			id_ok: a_id >= 0
		do
			create Result.make_touch (a_kind, a_id, a_x, a_y, 0)
		end

feature {NONE} -- Helpers for service events

	service (a_kind, a_code: INTEGER; a_text: STRING_8): PHONE_EVENT
			-- A service event for the tests.
		do
			create Result.make_service (a_kind, a_code, a_text.to_string_32, 1)
		end

end
