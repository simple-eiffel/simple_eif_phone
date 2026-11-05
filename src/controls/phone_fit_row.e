note
	description: "[
		A row whose first child takes what room it needs while the others keep theirs,
		so a long title wraps and the chip after it stays whole.
	]"
	author: "Larry Rix"

class
	PHONE_FIT_ROW

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create children.make (2)
			make_control (a_controls, Control_any, Fit_class)
		ensure
			mine: controls = a_controls
		end

feature {NONE} -- Implementation

	Fit_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneFitRow"

end
