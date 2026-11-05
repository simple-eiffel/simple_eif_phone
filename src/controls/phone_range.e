note
	description: "Material 3's slider, from 0 to `maximum', with a dot at each step when asked."
	author: "Larry Rix"

class
	PHONE_RANGE

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_maximum: INTEGER; a_active, a_inactive, a_on_active: NATURAL_32)
		require
			positive: a_maximum > 0
		do
			maximum := a_maximum
			make_control (a_controls, Control_any, Range_class)
			call_integer ("setMaximum", a_maximum)
			call_integer ("setActiveColor", a_active.as_integer_32)
			call_integer ("setInactiveColor", a_inactive.as_integer_32)
			call_integer ("setOnActiveColor", a_on_active.as_integer_32)
			listen ("setOnRangeListener", agent heard)
		ensure
			mine: controls = a_controls
			maximum_set: maximum = a_maximum
		end

feature -- Access

	value: INTEGER

	maximum: INTEGER

	on_change: detachable PROCEDURE [TUPLE [INTEGER]]
			-- Told when the user moves it; not when `set_value' does.

feature -- Element change

	set_value (a_value: INTEGER)
		require
			in_range: a_value >= 0 and a_value <= maximum
		do
			value := a_value
			call_integer ("setValue", a_value)
		ensure
			set: value = a_value
		end

	show_steps
			-- Put a dot at each step.
		do
			call_boolean ("setShowSteps", True)
		end

	set_on_change (a_action: PROCEDURE [TUPLE [INTEGER]])
		do
			on_change := a_action
		ensure
			set: on_change = a_action
		end

feature {NONE} -- Implementation

	heard (a_words: READABLE_STRING_32)
			-- "onValue|n".
		local
			l_number: STRING_32
		do
			l_number := a_words.substring (a_words.index_of ('|', 1) + 1, a_words.count)
			if l_number.is_integer then
				value := l_number.to_integer
				if attached on_change as al_action then
					al_action.call ([value])
				end
			end
		end

	Range_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneRange"

invariant
	in_range: value >= 0 and value <= maximum

end
