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

end
