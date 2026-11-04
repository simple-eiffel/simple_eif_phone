note
	description: "A sliding switch. Android's Switch."
	author: "Larry Rix"

class
	PHONE_SWITCH

inherit
	PHONE_TOGGLE

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_label: READABLE_STRING_32)
		do
			make_toggle (a_controls, Control_switch, a_label)
		ensure
			mine: controls = a_controls
			off: not is_on
		end

end
