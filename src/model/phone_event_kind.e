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

feature -- Codes: services

	Kind_speech_ready: INTEGER = 40
	Kind_speech_failed: INTEGER = 41
	Kind_speech_done: INTEGER = 42
	Kind_file_picked: INTEGER = 43
	Kind_file_cancelled: INTEGER = 44
	Kind_file_failed: INTEGER = 45
	Kind_keyboard_text: INTEGER = 46
	Kind_keyboard_backspace: INTEGER = 47
	Kind_keyboard_enter: INTEGER = 48
	Kind_keyboard_closed: INTEGER = 49

feature -- Codes: Android's controls

	Kind_control_clicked: INTEGER = 50
	Kind_control_changed: INTEGER = 51
	Kind_control_rows: INTEGER = 52
			-- A list wants a block of rows, starting at position `x'.
	Kind_control_selected: INTEGER = 53
	Kind_control_pressed: INTEGER = 54
	Kind_control_swept: INTEGER = 55
	Kind_control_released: INTEGER = 56
	Kind_control_canvas_ready: INTEGER = 57
	Kind_control_canvas_lost: INTEGER = 58
	Kind_control_answered: INTEGER = 59
	Kind_control_called: INTEGER = 60
	Kind_control_failed: INTEGER = 61
	Kind_control_back: INTEGER = 62

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
			Result := a_k = Kind_none or is_lifecycle_kind (a_k) or is_touch_kind (a_k) or is_key_kind (a_k) or is_service_kind (a_k) or is_control_kind (a_k)
		ensure
			definition: Result = (a_k = Kind_none or is_lifecycle_kind (a_k) or is_touch_kind (a_k) or is_key_kind (a_k) or is_service_kind (a_k) or is_control_kind (a_k))
			families_disjoint: (is_lifecycle_kind (a_k).to_integer + is_touch_kind (a_k).to_integer + is_key_kind (a_k).to_integer) <= 1
		end

	is_control_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' from one of Android's controls?
		do
			Result := Kind_control_clicked <= a_k and a_k <= Kind_control_back
		end

	is_speech_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' a read-aloud result?
		do
			Result := Kind_speech_ready <= a_k and a_k <= Kind_speech_done
		end

	is_file_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' a file picker result?
		do
			Result := Kind_file_picked <= a_k and a_k <= Kind_file_failed
		end

	is_keyboard_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' from the phone's keyboard?
		do
			Result := Kind_keyboard_text <= a_k and a_k <= Kind_keyboard_closed
		end

	is_service_kind (a_k: INTEGER): BOOLEAN
			-- Is `a_k' a result from a Java service?
		do
			Result := is_speech_kind (a_k) or is_file_kind (a_k) or is_keyboard_kind (a_k)
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
			when Kind_speech_ready then Result := "speech_ready"
			when Kind_speech_failed then Result := "speech_failed"
			when Kind_speech_done then Result := "speech_done"
			when Kind_file_picked then Result := "file_picked"
			when Kind_file_cancelled then Result := "file_cancelled"
			when Kind_file_failed then Result := "file_failed"
			when Kind_keyboard_text then Result := "keyboard_text"
			when Kind_keyboard_backspace then Result := "keyboard_backspace"
			when Kind_keyboard_enter then Result := "keyboard_enter"
			when Kind_keyboard_closed then Result := "keyboard_closed"
			when Kind_control_clicked then Result := "control_clicked"
			when Kind_control_changed then Result := "control_changed"
			when Kind_control_rows then Result := "control_rows"
			when Kind_control_selected then Result := "control_selected"
			when Kind_control_pressed then Result := "control_pressed"
			when Kind_control_swept then Result := "control_swept"
			when Kind_control_released then Result := "control_released"
			when Kind_control_canvas_ready then Result := "control_canvas_ready"
			when Kind_control_canvas_lost then Result := "control_canvas_lost"
			when Kind_control_answered then Result := "control_answered"
			when Kind_control_called then Result := "control_called"
			when Kind_control_failed then Result := "control_failed"
			when Kind_control_back then Result := "control_back"
			else
				Result := "none"
			end
				-- A fresh copy, so callers may modify it.
			Result := Result.twin
		ensure
			not_empty: not Result.is_empty
		end

end
