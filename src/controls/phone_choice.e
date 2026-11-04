note
	description: "One option out of a drop-down list. Android's Spinner."
	author: "Larry Rix"

class
	PHONE_CHOICE

inherit
	PHONE_CONTROL
		redefine
			handle_own
		end

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create options.make (4)
			make_control (a_controls, Control_choice, Void)
		ensure
			mine: controls = a_controls
			empty: options.is_empty
		end

feature -- Access

	options: ARRAYED_LIST [READABLE_STRING_32]

	selected_index: INTEGER
			-- 1 for the first option; 0 while there are none.

	on_change: detachable PROCEDURE [TUPLE [INTEGER]]
			-- Called when the user picks another option.

feature -- Element change

	add_option (a_text: READABLE_STRING_32)
			-- The first option added starts out selected.
		do
			options.extend (a_text)
			if selected_index = 0 then
				selected_index := 1
			end
			order (Op_choice_add, 0, 0, a_text)
		ensure
			added: options.count = old options.count + 1
			selected: selected_index >= 1
		end

	select_index (a_index: INTEGER)
		require
			in_range: a_index >= 1 and a_index <= options.count
		do
			selected_index := a_index
			order (Op_select, a_index, 0, Void)
		ensure
			set: selected_index = a_index
		end

	set_on_change (a_action: PROCEDURE [TUPLE [INTEGER]])
		do
			on_change := a_action
		ensure
			set: on_change = a_action
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
			-- Android also reports the option it starts on, so only a real change counts.
		do
			if a_event.kind = Kind_control_changed and then a_event.x /= selected_index
				and then a_event.x >= 1 and then a_event.x <= options.count
			then
				selected_index := a_event.x
				if attached on_change as al_action then
					al_action.call ([selected_index])
				end
			end
		end

invariant
	in_range: selected_index >= 0 and selected_index <= options.count

end
