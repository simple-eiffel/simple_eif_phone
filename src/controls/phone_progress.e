note
	description: "How far along something is. Android's ProgressBar."
	author: "Larry Rix"

class
	PHONE_PROGRESS

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_maximum: INTEGER)
		require
			maximum_positive: a_maximum > 0
		do
			make_control (a_controls, Control_progress, Void)
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

invariant
	in_range: value >= 0 and value <= maximum

end
