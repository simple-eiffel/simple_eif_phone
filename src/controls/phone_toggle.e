note
	description: "A control that is on or off."
	author: "Larry Rix"

deferred class
	PHONE_TOGGLE

inherit
	PHONE_CONTROL
		redefine
			handle_own
		end

feature {NONE} -- Initialization

	make_toggle (a_controls: PHONE_CONTROLS; a_kind: INTEGER; a_label: READABLE_STRING_32)
		do
			label := a_label
			make_control (a_controls, a_kind, Void)
			order (Op_text, 0, 0, a_label)
		ensure
			off: not is_on
		end

feature -- Access

	label: READABLE_STRING_32

	is_on: BOOLEAN

	on_change: detachable PROCEDURE [TUPLE [BOOLEAN]]
			-- Called when the user flips it; not when `set_on' does.

feature -- Element change

	set_on (a_on: BOOLEAN)
		do
			is_on := a_on
			order (Op_checked, a_on.to_integer, 0, Void)
		ensure
			set: is_on = a_on
		end

	set_on_change (a_action: PROCEDURE [TUPLE [BOOLEAN]])
		do
			on_change := a_action
		ensure
			set: on_change = a_action
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
		do
			if a_event.kind = Kind_control_changed then
				is_on := a_event.x /= 0
				if attached on_change as al_action then
					al_action.call ([is_on])
				end
			end
		end

end
