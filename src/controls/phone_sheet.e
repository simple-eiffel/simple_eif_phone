note
	description: "[
		A modal sheet from the bottom of the screen, over a dimmed scrim. It opens at half
		height, and goes to full height or away by dragging, as Material's bottom sheet does.
		Put one child in it, and place it over everything else in a PHONE_STACK.
	]"
	author: "Larry Rix"

class
	PHONE_SHEET

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_color, a_handle: NATURAL_32)
		do
			create children.make (1)
			make_control (a_controls, Control_any, Sheet_class)
			call_integer ("setSheetColor", a_color.as_integer_32)
			call_integer ("setHandleColor", a_handle.as_integer_32)
			listen ("setOnSheetListener", agent on_called)
		ensure
			mine: controls = a_controls
		end

feature -- Access

	on_gone: detachable PROCEDURE [TUPLE]
			-- Told when the sheet has gone. Take it out of its parent then.

feature -- Element change

	set_on_gone (a_action: PROCEDURE [TUPLE])
		do
			on_gone := a_action
		ensure
			set: on_gone = a_action
		end

	dismiss
			-- Slide away; `on_gone' is told when it has.
		do
			call ("dismiss")
		end

feature {NONE} -- Implementation

	on_called (a_words: READABLE_STRING_32)
		do
			if attached on_gone as al_action then
				al_action.call ([])
			end
		end

	Sheet_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneSheet"

end
