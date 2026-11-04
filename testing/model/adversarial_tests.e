note
	description: "[
		Phase 6: event sequences Android should not send, and volumes it might.
		Every contract is on, so any broken promise fails the test.
	]"
	author: "Larry Rix"
	testing: "covers"

class
	ADVERSARIAL_TESTS

inherit
	TEST_SET_BASE

	PHONE_EVENT_KIND
		undefine
			default_create
		end

feature -- Lifecycle in the wrong order

	test_a_resumed_before_started
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			l.apply (lifecycle (Kind_resumed))
			assert ("resumed implies started", l.is_resumed and l.is_started)
		end

	test_a_repeated_and_unmatched
			-- Every pause, stop and loss, with nothing to pause, stop or lose.
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			across <<Kind_paused, Kind_paused, Kind_stopped, Kind_stopped, Kind_window_lost, Kind_window_lost,
				Kind_focus_lost, Kind_focus_lost>> as ic loop
				l.apply (lifecycle (ic))
			end
			assert ("nothing on", not l.is_started and not l.is_resumed and not l.has_window and not l.has_focus)
			assert ("not destroyed", not l.is_destroyed)
		end

	test_a_window_ready_twice_counts_twice
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			l.apply (lifecycle (Kind_window_ready))
			l.apply (lifecycle (Kind_window_ready))
			assert ("two generations", l.window_generation = 2 and l.has_window)
		end

	test_a_focus_without_window
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			l.apply (lifecycle (Kind_focus_gained))
			assert ("focus alone", l.has_focus and not l.has_window)
		end

	test_a_destroyed_from_any_state
		local
			l: PHONE_LIFECYCLE
		do
			create l.make
			across <<Kind_started, Kind_resumed, Kind_window_ready, Kind_focus_gained, Kind_destroyed>> as ic loop
				l.apply (lifecycle (ic))
			end
			assert ("all off", l.is_destroyed and not l.is_started and not l.is_resumed and not l.has_window and not l.has_focus)
		end

	test_a_lifecycle_random_storm
			-- 100,000 lifecycle events in random order; contracts check each one.
		local
			l: PHONE_LIFECYCLE
			l_kinds: ARRAY [INTEGER]
			i: INTEGER
		do
			l_kinds := <<Kind_started, Kind_resumed, Kind_paused, Kind_stopped, Kind_window_ready, Kind_window_lost,
				Kind_focus_gained, Kind_focus_lost, Kind_window_resized, Kind_redraw_needed, Kind_low_memory, Kind_content_rect_changed>>
			create l.make
			from i := 1 until i > 100_000 loop
				l.apply (lifecycle (l_kinds [(next_random \\ l_kinds.count) + 1]))
				i := i + 1
			end
			assert ("still alive", not l.is_destroyed)
		end

feature -- Touches in the wrong order

	test_a_down_twice_same_finger
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 3, 10, 10))
			t.apply (touch (Kind_touch_down, 3, 20, 30))
			assert ("one finger", t.count = 1)
			assert ("second position", t.x_of (3) = 20 and t.y_of (3) = 30)
		end

	test_a_up_unknown_finger
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 1, 10, 10))
			t.apply (touch (Kind_touch_up, 7, 0, 0))
			assert ("first still down", t.count = 1 and t.is_active (1))
		end

	test_a_up_with_no_fingers_and_cancel_twice
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_up, 0, 0, 0))
			t.apply (touch (Kind_touch_cancel, 0, 0, 0))
			t.apply (touch (Kind_touch_cancel, 0, 0, 0))
			assert ("none", t.count = 0)
		end

	test_a_thirty_two_fingers
			-- More than any phone reports, and above the table's first size.
		local
			t: PHONE_TOUCHES
			i: INTEGER
		do
			create t.make
			from i := 0 until i = 32 loop
				t.apply (touch (Kind_touch_down, i, i, i))
				i := i + 1
			end
			assert ("all down", t.count = 32)
			from i := 0 until i = 32 loop
				t.apply (touch (Kind_touch_up, i, i, i))
				i := i + 1
			end
			assert ("all up", t.count = 0)
		end

	test_a_extreme_coordinates
			-- Off the screen in every direction.
		local
			t: PHONE_TOUCHES
		do
			create t.make
			t.apply (touch (Kind_touch_down, 0, {INTEGER}.min_value, {INTEGER}.max_value))
			t.apply (touch (Kind_touch_move, 0, {INTEGER}.max_value, {INTEGER}.min_value))
			assert ("kept exactly", t.x_of (0) = {INTEGER}.max_value and t.y_of (0) = {INTEGER}.min_value)
		end

	test_a_touch_random_storm
			-- 20,000 touch events with five fingers in random order.
		local
			t: PHONE_TOUCHES
			l_kinds: ARRAY [INTEGER]
			i: INTEGER
		do
			l_kinds := <<Kind_touch_down, Kind_touch_move, Kind_touch_move, Kind_touch_move, Kind_touch_up>>
			create t.make
			from i := 1 until i > 20_000 loop
				t.apply (touch (l_kinds [(next_random \\ 5) + 1], next_random \\ 5, next_random \\ 2000, next_random \\ 2000))
				i := i + 1
			end
			t.apply (touch (Kind_touch_cancel, 0, 0, 0))
			assert ("clean end", t.count = 0)
		end

feature -- Values at the edges

	test_a_event_largest_time
		local
			e: PHONE_EVENT
		do
			create e.make_touch (Kind_touch_move, 0, 0, 0, {INTEGER}.max_value)
			assert ("kept", e.time_ms = {INTEGER}.max_value)
			assert ("line made", not e.out_line.is_empty)
		end

	test_a_rect_empty_at_a_point
		local
			r: PHONE_RECT
		do
			create r.make (5, 5, 5, 5)
			assert ("no size", r.width = 0 and r.height = 0)
		end

	test_a_every_kind_has_a_name
		local
			i: INTEGER
		do
			from i := 0 until i > 40 loop
				if is_valid_kind (i) then
					assert ("named " + i.out, not kind_name (i).is_empty)
				end
				i := i + 1
			end
		end

feature {NONE} -- Helpers

	lifecycle (a_kind: INTEGER): PHONE_EVENT
		do
			create Result.make_lifecycle (a_kind, 1)
		end

	touch (a_kind, a_id, a_x, a_y: INTEGER): PHONE_EVENT
		do
			create Result.make_touch (a_kind, a_id, a_x, a_y, 1)
		end

	seed: INTEGER
			-- State of `next_random'.

	next_random: INTEGER
			-- A repeatable pseudo-random number, 0 or more.
		do
			seed := (seed * 1103515245 + 12345) & 0x7FFFFFFF
			Result := seed // 65536
		end

end
