note
	description: "[
		One thing that happened on the phone: a lifecycle change, a touch
		or a key. Immutable. Exactly one family per event (or none, for a
		timed poll that ran out).
		Touch coordinates are window pixels, rounded; they may lie outside
		the window while a finger drags off the edge.
	]"
	author: "Larry Rix"

class
	PHONE_EVENT

inherit
	PHONE_EVENT_KIND

create
	make_none,
	make_lifecycle,
	make_touch,
	make_key

feature {NONE} -- Initialization

	make_none
			-- No event.
		do
			kind := Kind_none
			pointer_id := -1
		ensure
			is_none: is_none
			no_id: pointer_id = -1
			no_code: key_code = 0
			no_time: time_ms = 0
		end

	make_lifecycle (a_kind, a_time: INTEGER)
			-- Lifecycle event `a_kind' at `a_time' ms.
		require
			lifecycle_kind: is_lifecycle_kind (a_kind)
			time_ok: a_time >= 0
		do
			kind := a_kind
			time_ms := a_time
			pointer_id := -1
		ensure
			kind_set: kind = a_kind
			time_set: time_ms = a_time
			no_id: pointer_id = -1
			no_code: key_code = 0
			no_position: x = 0 and y = 0
		end

	make_touch (a_kind, a_id, a_x, a_y, a_time: INTEGER)
			-- Touch event `a_kind' for pointer `a_id' at (`a_x', `a_y').
		require
			touch_kind: is_touch_kind (a_kind)
			id_ok: a_id >= 0
			time_ok: a_time >= 0
		do
			kind := a_kind
			pointer_id := a_id
			x := a_x
			y := a_y
			time_ms := a_time
		ensure
			kind_set: kind = a_kind
			id_set: pointer_id = a_id
			x_set: x = a_x
			y_set: y = a_y
			time_set: time_ms = a_time
			no_code: key_code = 0
		end

	make_key (a_kind, a_code, a_time: INTEGER)
			-- Key event `a_kind' for Android key code `a_code'.
		require
			key_kind: is_key_kind (a_kind)
			code_ok: a_code > 0
			time_ok: a_time >= 0
		do
			kind := a_kind
			key_code := a_code
			time_ms := a_time
			pointer_id := -1
		ensure
			kind_set: kind = a_kind
			code_set: key_code = a_code
			time_set: time_ms = a_time
			no_id: pointer_id = -1
			no_position: x = 0 and y = 0
		end

feature -- Access

	kind: INTEGER
			-- Event code (see PHONE_EVENT_KIND).

	time_ms: INTEGER
			-- Android uptime in milliseconds, masked to 31 bits by the glue:
			-- never negative; wraps to 0 after 2^31 ms (~24.8 days).
			-- Compare two times by their difference, not by `<'.

	pointer_id: INTEGER
			-- Finger id for touch events; -1 otherwise.

	x, y: INTEGER
			-- Window pixel position for touch events; 0 otherwise.

	key_code: INTEGER
			-- Android key code for key events; 0 otherwise.

feature -- Status

	is_none: BOOLEAN
			-- Is this "no event"?
		do
			Result := kind = Kind_none
		end

	is_lifecycle: BOOLEAN
			-- Is this a lifecycle event?
		do
			Result := is_lifecycle_kind (kind)
		end

	is_touch: BOOLEAN
			-- Is this a touch event?
		do
			Result := is_touch_kind (kind)
		end

	is_key: BOOLEAN
			-- Is this a key event?
		do
			Result := is_key_kind (kind)
		end

feature -- Output

	out_line: STRING_8
			-- One-line description, e.g. "touch_down id=0 x=12 y=40 t=1234".
		do
			Result := kind_name (kind)
			if is_touch then
				Result.append (" id=" + pointer_id.out + " x=" + x.out + " y=" + y.out)
			elseif is_key then
				Result.append (" code=" + key_code.out)
			end
			Result.append (" t=" + time_ms.out)
		ensure
			starts_with_name: Result.starts_with (kind_name (kind))
			one_line: not Result.has ('%N')
		end

invariant
	valid_kind: is_valid_kind (kind)
	one_family: is_none.to_integer + is_lifecycle.to_integer + is_touch.to_integer + is_key.to_integer = 1
	touch_has_id: is_touch implies pointer_id >= 0
	non_touch_no_id: not is_touch implies pointer_id = -1
	key_has_code: is_key = (key_code > 0)
	non_touch_no_position: not is_touch implies (x = 0 and y = 0)
	time_non_negative: time_ms >= 0

end
