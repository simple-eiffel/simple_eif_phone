note
	description: "A box to tick. Android's CheckBox."
	author: "Larry Rix"

class
	PHONE_CHECK_BOX

inherit
	PHONE_TOGGLE

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_label: READABLE_STRING_32)
		do
			make_toggle (a_controls, Control_check_box, a_label)
		ensure
			mine: controls = a_controls
			off: not is_on
		end

end
