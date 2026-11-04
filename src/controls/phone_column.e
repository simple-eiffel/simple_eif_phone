note
	description: "Children top to bottom."
	author: "Larry Rix"

class
	PHONE_COLUMN

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_box (a_controls, Control_column)
		ensure
			mine: controls = a_controls
		end

end
