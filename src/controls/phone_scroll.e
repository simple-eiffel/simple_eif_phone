note
	description: "One child taller than the screen, scrolled by finger. Android's ScrollView."
	author: "Larry Rix"

class
	PHONE_SCROLL

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_control (a_controls, Control_scroll, Void)
		ensure
			mine: controls = a_controls
			empty: child = Void
		end

feature -- Access

	child: detachable PHONE_CONTROL

feature -- Element change

	set_child (a_child: PHONE_CONTROL)
		require
			mine: a_child.controls = controls
			empty: child = Void
			not_self: a_child /= Current
		do
			child := a_child
			order (Op_add, a_child.id, 0, Void)
		ensure
			set: child = a_child
		end

end
