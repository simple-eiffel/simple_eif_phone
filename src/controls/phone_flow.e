note
	description: "[
		Children in lines that wrap. With `set_cell_width' it is a grid of as many
		equal columns as fit, each at least that wide. Without it, each child keeps
		its size. Lines can run right to left, for Hebrew word by word.
	]"
	author: "Larry Rix"

class
	PHONE_FLOW

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create children.make (8)
			make_control (a_controls, Control_any, Flow_class)
		ensure
			mine: controls = a_controls
			empty: children.is_empty
		end

feature -- Element change

	set_cell_width (a_width: INTEGER)
			-- Columns at least `a_width' density-independent pixels wide; 0 for none.
		require
			non_negative: a_width >= 0
		do
			call_integer ("setCellWidth", a_width)
		end

	set_cell_height (a_height: INTEGER)
			-- Every child `a_height' tall; 0 lets each choose.
		require
			non_negative: a_height >= 0
		do
			call_integer ("setCellHeight", a_height)
		end

	set_flow_gap (a_gap: INTEGER)
			-- Space between children, across and down.
		require
			non_negative: a_gap >= 0
		do
			call_integer ("setGap", a_gap)
		end

	set_right_to_left (a_on: BOOLEAN)
		do
			call_boolean ("setRightToLeft", a_on)
		end

feature {NONE} -- Implementation

	Flow_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneFlow"

end
