note
	description: "Children on top of one another, each as large as the box. Android's FrameLayout."
	author: "Larry Rix"

class
	PHONE_STACK

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create children.make (4)
			make_control (a_controls, Control_any, Stack_class)
		ensure
			mine: controls = a_controls
			empty: children.is_empty
		end

feature {NONE} -- Implementation

	Stack_class: STRING_32 = "android.widget.FrameLayout"

end
