note
	description: "[
		A scrolling list of any length. Android's ListView. Rows are not stored
		here: `row_text' is asked for each row as it is about to come into view,
		a block at a time. Rows count from 1.
	]"
	author: "Larry Rix"

class
	PHONE_LIST

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
			make_control (a_controls, Control_list, Void)
		ensure
			mine: controls = a_controls
			empty: row_count = 0
		end

feature -- Access

	row_count: INTEGER

	selected_index: INTEGER
			-- The row last tapped; 0 if none.

	row_text: detachable FUNCTION [TUPLE [INTEGER], READABLE_STRING_32]
			-- Gives the text of a row.

	on_select: detachable PROCEDURE [TUPLE [INTEGER]]
			-- Called when the user taps a row.

feature -- Element change

	set_row_text (a_function: FUNCTION [TUPLE [INTEGER], READABLE_STRING_32])
		do
			row_text := a_function
		ensure
			set: row_text = a_function
		end

	set_row_count (a_count: INTEGER)
			-- Set how many rows there are. Every row is asked for afresh.
		require
			non_negative: a_count >= 0
		do
			row_count := a_count
			selected_index := 0
			order (Op_row_count, a_count, 0, Void)
		ensure
			set: row_count = a_count
			none_selected: selected_index = 0
		end

	set_on_select (a_action: PROCEDURE [TUPLE [INTEGER]])
		do
			on_select := a_action
		ensure
			set: on_select = a_action
		end

	scroll_to_row (a_row: INTEGER)
		require
			in_range: a_row >= 1 and a_row <= row_count
		do
			order (Op_select, a_row, 0, Void)
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
		do
			inspect a_event.kind
			when Kind_control_rows then
				send_rows (a_event.x)
			when Kind_control_selected then
				if a_event.x >= 1 and then a_event.x <= row_count then
					selected_index := a_event.x
					if attached on_select as al_action then
						al_action.call ([selected_index])
					end
				end
			else
			end
		end

	send_rows (a_first: INTEGER)
			-- Send the block of rows starting at position `a_first' (counting from 0).
		local
			i, l_stop: INTEGER
		do
			if attached row_text as al_text then
				l_stop := (a_first + Row_block).min (row_count)
				from i := a_first until i >= l_stop loop
					order (Op_row, i, 0, al_text.item ([i + 1]))
					i := i + 1
				end
				order (Op_rows_done, 0, 0, Void)
			end
		end

invariant
	rows_non_negative: row_count >= 0
	selection_in_range: selected_index >= 0 and selected_index <= row_count

end
