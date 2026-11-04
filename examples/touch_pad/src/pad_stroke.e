note
	description: "One finger's trail: its color and the points it passed through."
	author: "Larry Rix"

class
	PAD_STROKE

create
	make

feature {NONE} -- Initialization

	make (a_rgb: INTEGER)
			-- An empty stroke in color `a_rgb' (0xRRGGBB).
		require
			rgb_ok: 0 <= a_rgb and a_rgb <= 0xFFFFFF
		do
			rgb := a_rgb
			create xs.make (64)
			create ys.make (64)
		ensure
			rgb_set: rgb = a_rgb
			empty: count = 0
		end

feature -- Access

	rgb: INTEGER
	xs, ys: ARRAYED_LIST [INTEGER]

	count: INTEGER
			-- Number of points.
		do
			Result := xs.count
		end

feature -- Element change

	extend (a_x, a_y: INTEGER)
			-- Add the point (`a_x', `a_y').
		do
			xs.extend (a_x)
			ys.extend (a_y)
		ensure
			one_more: count = old count + 1
		end

invariant
	paired: xs.count = ys.count

end
