note
	description: "Children side by side."
	author: "Larry Rix"

class
	PHONE_ROW

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_box (a_controls, Control_row)
		ensure
			mine: controls = a_controls
		end

end
