note
	description: "[
		Event codes for SIMPLE_EIF_PHONE, grouped in three families:
		lifecycle (1-14), touch (20-23) and key (30-31). Code 0 means
		no event (a timed poll that ran out).
		The numbers are shared with the C glue (runtime/c/sephone.h);
		change both together.
	]"
	author: "Larry Rix"

class
	PHONE_EVENT_KIND

feature -- Codes: none

	Kind_none: INTEGER = 0
			-- No event (timed poll ran out).

feature -- Codes: lifecycle

	Kind_started: INTEGER = 1
	Kind_resumed: INTEGER = 2
	Kind_paused: INTEGER = 3
	Kind_stopped: INTEGER = 4
	Kind_destroyed: INTEGER = 5
	Kind_window_ready: INTEGER = 6
	Kind_window_lost: INTEGER = 7
	Kind_window_resized: INTEGER = 8
	Kind_redraw_needed: INTEGER = 9
	Kind_focus_gained: INTEGER = 10
	Kind_focus_lost: INTEGER = 11
	Kind_configuration_changed: INTEGER = 12
	Kind_low_memory: INTEGER = 13
	Kind_content_rect_changed: INTEGER = 14

feature -- Codes: touch

	Kind_touch_down: INTEGER = 20
	Kind_touch_move: INTEGER = 21
	Kind_touch_up: INTEGER = 22
	Kind_touch_cancel: INTEGER = 23

feature -- Codes: key

	Kind_key_down: INTEGER = 30
	Kind_key_up: INTEGER = 31

feature -- Families

	is_lifecycle_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' a lifecycle code?
		do
			Result := Kind_started <= a_k and a_k <= Kind_content_rect_changed
		end

	is_touch_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' a touch code?
		do
			Result := Kind_touch_down <= a_k and a_k <= Kind_touch_cancel
		end

	is_key_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' a key code?
		do
			Result := a_k = Kind_key_down or a_k = Kind_key_up
		end

	is_valid_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' none or a member of exactly one family?
		do
			Result := a_k = Kind_none or is_lifecycle_kind (a_k) or is_touch_kind (a_k) or is_key_kind (a_k)
		ensure
			definition: Result = (a_k = Kind_none or is_lifecycle_kind (a_k) or is_touch_kind (a_k) or is_key_kind (a_k))
			families_disjoint: (is_lifecycle_kind (a_k).to_integer + is_touch_kind (a_k).to_integer + is_key_kind (a_k).to_integer) <= 1
		end

feature -- Names

	kind_name (a_k: INTEGER): STRING_8
			-- Lower-case name of `a_k', for logs and tests (e.g. "touch_down").
		require
			valid: is_valid_kind (a_k)
		do
			inspect a_k
			when Kind_started then Result := "started"
			when Kind_resumed then Result := "resumed"
			when Kind_paused then Result := "paused"
			when Kind_stopped then Result := "stopped"
			when Kind_destroyed then Result := "destroyed"
			when Kind_window_ready then Result := "window_ready"
			when Kind_window_lost then Result := "window_lost"
			when Kind_window_resized then Result := "window_resized"
			when Kind_redraw_needed then Result := "redraw_needed"
			when Kind_focus_gained then Result := "focus_gained"
			when Kind_focus_lost then Result := "focus_lost"
			when Kind_configuration_changed then Result := "configuration_changed"
			when Kind_low_memory then Result := "low_memory"
			when Kind_content_rect_changed then Result := "content_rect_changed"
			when Kind_touch_down then Result := "touch_down"
			when Kind_touch_move then Result := "touch_move"
			when Kind_touch_up then Result := "touch_up"
			when Kind_touch_cancel then Result := "touch_cancel"
			when Kind_key_down then Result := "key_down"
			when Kind_key_up then Result := "key_up"
			else
				Result := "none"
			end
				-- A fresh copy, so callers may modify it.
			Result := Result.twin
		ensure
			not_empty: not Result.is_empty
		end

end
