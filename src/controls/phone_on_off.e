note
	description: "Material 3's switch. It shows a state; the row around it takes the tap and says `set_on'."
	author: "Larry Rix"

class
	PHONE_ON_OFF

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_on: BOOLEAN; a_accent, a_on_accent, a_outline, a_track: NATURAL_32)
		do
			make_control (a_controls, Control_any, On_off_class)
			call_integer ("setAccent", a_accent.as_integer_32)
			call_integer ("setOnAccent", a_on_accent.as_integer_32)
			call_integer ("setOutline", a_outline.as_integer_32)
			call_integer ("setTrack", a_track.as_integer_32)
			is_on := a_on
			call_boolean ("setOnNow", a_on)
		ensure
			mine: controls = a_controls
			set: is_on = a_on
		end

feature -- Access

	is_on: BOOLEAN

feature -- Element change

	set_on (a_on: BOOLEAN)
			-- Move to `a_on'.
		do
			is_on := a_on
			call_boolean ("setOnMoving", a_on)
		ensure
			set: is_on = a_on
		end

feature {NONE} -- Implementation

	On_off_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneOnOff"

end
