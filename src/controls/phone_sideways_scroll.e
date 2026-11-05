note
	description: "One child wider than the screen, scrolling sideways. Android's HorizontalScrollView."
	author: "Larry Rix"

class
	PHONE_SIDEWAYS_SCROLL

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_control (a_controls, Control_any, Scroll_class)
			call_boolean ("setHorizontalScrollBarEnabled", False)
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

feature {NONE} -- Implementation

	Scroll_class: STRING_32 = "android.widget.HorizontalScrollView"

end
