note
	description: "[
		A dialog with whatever content the app gives it, centered over a dimmed screen.
		Put one child in it, and place it over everything else in a PHONE_STACK. A tap
		outside tells `on_outside'; closing it is the app's to do.
	]"
	author: "Larry Rix"

class
	PHONE_DIALOG

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create children.make (1)
			make_control (a_controls, Control_any, Dialog_class)
			listen ("setOnDialogListener", agent heard)
		ensure
			mine: controls = a_controls
		end

feature -- Access

	on_outside: detachable PROCEDURE [TUPLE]

feature -- Element change

	set_on_outside (a_action: PROCEDURE [TUPLE])
		do
			on_outside := a_action
		ensure
			set: on_outside = a_action
		end

feature {NONE} -- Implementation

	heard (a_words: READABLE_STRING_32)
		do
			if attached on_outside as al_action then
				al_action.call ([])
			end
		end

	Dialog_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneDialog"

end
