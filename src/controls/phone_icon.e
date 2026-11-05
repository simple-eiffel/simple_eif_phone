note
	description: "[
		An icon drawn from SVG path data on a 24 by 24 grid, in one color. It can be
		tapped. The Material icons' path data goes in as it stands.
	]"
	author: "Larry Rix"

class
	PHONE_ICON

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_path: READABLE_STRING_8; a_tint: NATURAL_32)
		require
			path_given: not a_path.is_empty
		do
			path := a_path
			tint := a_tint
			make_control (a_controls, Control_any, Icon_class)
			call_text ("setPathData", a_path.to_string_32)
			call_integer ("setTint", a_tint.as_integer_32)
		ensure
			mine: controls = a_controls
			path_set: path.same_string (a_path)
			tint_set: tint = a_tint
		end

feature -- Access

	path: READABLE_STRING_8

	tint: NATURAL_32

feature -- Element change

	set_path (a_path: READABLE_STRING_8)
		require
			path_given: not a_path.is_empty
		do
			path := a_path
			call_text ("setPathData", a_path.to_string_32)
		ensure
			set: path.same_string (a_path)
		end

	set_tint (a_tint: NATURAL_32)
		do
			tint := a_tint
			call_integer ("setTint", a_tint.as_integer_32)
		ensure
			set: tint = a_tint
		end

	set_icon_size (a_size: INTEGER)
			-- Draw at `a_size' density-independent pixels; 24 unless told.
		require
			size_positive: a_size > 0
		do
			call_integer ("setIconSize", a_size)
		end

feature {NONE} -- Implementation

	Icon_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneIcon"

end
