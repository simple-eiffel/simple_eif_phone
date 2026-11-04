note
	description: "A value from 0 to `maximum', set by finger. Android's SeekBar."
	author: "Larry Rix"

class
	PHONE_SLIDER

inherit
	PHONE_CONTROL
		redefine
			handle_own
		end

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_maximum: INTEGER)
		require
			maximum_positive: a_maximum > 0
		do
			make_control (a_controls, Control_slider, Void)
			maximum := a_maximum
			order (Op_maximum, a_maximum, 0, Void)
		ensure
			mine: controls = a_controls
			maximum_set: maximum = a_maximum
			at_zero: value = 0
		end

feature -- Access

	value: INTEGER

	maximum: INTEGER

	on_change: detachable PROCEDURE [TUPLE [INTEGER]]
			-- Called when the user moves it; not when `set_value' does.

feature -- Element change

	set_value (a_value: INTEGER)
		require
			in_range: a_value >= 0 and a_value <= maximum
		do
			value := a_value
			order (Op_value, a_value, 0, Void)
		ensure
			set: value = a_value
		end

	set_on_change (a_action: PROCEDURE [TUPLE [INTEGER]])
		do
			on_change := a_action
		ensure
			set: on_change = a_action
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
		do
			if a_event.kind = Kind_control_changed then
				value := a_event.x.max (0).min (maximum)
				if attached on_change as al_action then
					al_action.call ([value])
				end
			end
		end

invariant
	in_range: value >= 0 and value <= maximum

end
