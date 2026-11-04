note
	description: "[
		A place to type: the phone's keyboard, its autocorrect, its copy and paste,
		and any script the keyboard offers. Android's EditText.
		`text' follows what the user types, one event behind.
	]"
	author: "Larry Rix"

class
	PHONE_TEXT_BOX

inherit
	PHONE_CONTROL
		redefine
			handle_own
		end

create
	make_single_line, make_multi_line

feature {NONE} -- Initialization

	make_single_line (a_controls: PHONE_CONTROLS)
		do
			text := {STRING_32} ""
			make_control (a_controls, Control_text_box, Void)
			is_single_line := True
			order (Op_single_line, 1, 0, Void)
		ensure
			mine: controls = a_controls
			empty: text.is_empty
			single: is_single_line
		end

	make_multi_line (a_controls: PHONE_CONTROLS)
		do
			text := {STRING_32} ""
			make_control (a_controls, Control_text_box, Void)
			order (Op_single_line, 0, 0, Void)
		ensure
			mine: controls = a_controls
			empty: text.is_empty
			multi: not is_single_line
		end

feature -- Access

	text: READABLE_STRING_32

	is_single_line: BOOLEAN

	is_masked: BOOLEAN

	on_change: detachable PROCEDURE [TUPLE]
			-- Called when the user changes the text; not when `set_text' does.

feature -- Element change

	set_text (a_text: READABLE_STRING_32)
		do
			text := a_text
			order (Op_text, 0, 0, a_text)
		ensure
			set: text.same_string (a_text)
		end

	set_hint (a_hint: READABLE_STRING_32)
			-- Gray text shown while the box is empty.
		do
			order (Op_hint, 0, 0, a_hint)
		end

	set_masked (a_on: BOOLEAN)
			-- Hide what is typed, as for a password.
		do
			is_masked := a_on
			order (Op_masked, a_on.to_integer, 0, Void)
		ensure
			set: is_masked = a_on
		end

	set_on_change (a_action: PROCEDURE [TUPLE])
		do
			on_change := a_action
		ensure
			set: on_change = a_action
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
			-- Android also reports while it sets a box up, so only a real change counts.
		do
			if a_event.kind = Kind_control_changed and then not a_event.text.same_string (text) then
				text := a_event.text
				if attached on_change as al_action then
					al_action.call ([])
				end
			end
		end

end
