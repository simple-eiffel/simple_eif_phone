note
	description: "A button. Android's Button."
	author: "Larry Rix"

class
	PHONE_BUTTON

inherit
	PHONE_CONTROL
		redefine
			handle_own
		end

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_label: READABLE_STRING_32; a_on_click: detachable PROCEDURE [TUPLE])
		do
			label := a_label
			on_click := a_on_click
			make_control (a_controls, Control_button, Void)
			order (Op_text, 0, 0, a_label)
		ensure
			mine: controls = a_controls
			label_set: label.same_string (a_label)
			action_set: on_click = a_on_click
		end

feature -- Access

	label: READABLE_STRING_32

	on_click: detachable PROCEDURE [TUPLE]

feature -- Element change

	set_label (a_label: READABLE_STRING_32)
		do
			label := a_label
			order (Op_text, 0, 0, a_label)
		ensure
			set: label.same_string (a_label)
		end

	set_on_click (a_action: PROCEDURE [TUPLE])
		do
			on_click := a_action
		ensure
			set: on_click = a_action
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
		do
			if a_event.kind = Kind_control_clicked and then attached on_click as al_action then
				al_action.call ([])
			end
		end

end
