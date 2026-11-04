note
	description: "A pixel rectangle: left/top inclusive, right/bottom exclusive. Immutable."
	author: "Larry Rix"

class
	PHONE_RECT

create
	make

feature {NONE} -- Initialization

	make (a_left, a_top, a_right, a_bottom: INTEGER)
			-- Rectangle from (`a_left', `a_top') up to (`a_right', `a_bottom').
		require
			ordered: a_left <= a_right and a_top <= a_bottom
		do
			left := a_left
			top := a_top
			right := a_right
			bottom := a_bottom
		ensure
			left_set: left = a_left
			top_set: top = a_top
			right_set: right = a_right
			bottom_set: bottom = a_bottom
		end

feature -- Access

	left, top, right, bottom: INTEGER

	width: INTEGER
			-- `right' - `left'.
		do
			Result := right - left
		ensure
			definition: Result = right - left
		end

	height: INTEGER
			-- `bottom' - `top'.
		do
			Result := bottom - top
		ensure
			definition: Result = bottom - top
		end

invariant
	ordered: left <= right and top <= bottom

end
