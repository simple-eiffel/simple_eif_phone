note
	description: "[
		Where the file picker stands: open or not, and how the last pick
		ended. Pure Eiffel, so its rules run on a PC too. Results reach it
		as events, through `apply'.
	]"
	author: "Larry Rix"

class
	PHONE_PICK_STATE

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_error.make_empty
		ensure
			closed: not is_picking
			nothing_picked: last_path = Void
			no_error: last_error.is_empty
			not_cancelled: not was_cancelled
		end

feature -- Status

	is_picking: BOOLEAN
			-- Is the picker open?

	was_cancelled: BOOLEAN
			-- Did the last pick end with nothing chosen?

feature -- Access

	last_path: detachable STRING_32
			-- The chosen file, copied into the app's cache, if the last pick found one.

	last_error: STRING_32
			-- Why the last pick failed; empty if it did not.

feature -- Events

	apply (a_event: PHONE_EVENT)
			-- Take in `a_event'. Events from other services change nothing.
			-- A pick can end after a restart, so a result is taken even when `is_picking' is False.
		do
			inspect a_event.kind
			when Kind_file_picked then
				is_picking := False
				was_cancelled := False
				last_path := a_event.text.to_string_32
				create last_error.make_empty
			when Kind_file_cancelled then
				is_picking := False
				was_cancelled := True
				last_path := Void
				create last_error.make_empty
			when Kind_file_failed then
				is_picking := False
				was_cancelled := False
				last_path := Void
				last_error := a_event.text.to_string_32
			else
			end
		ensure
			closed_on_result: is_file_kind (a_event.kind) implies not is_picking
			path_on_picked: a_event.kind = Kind_file_picked implies attached last_path
			no_path_otherwise: (a_event.kind = Kind_file_cancelled or a_event.kind = Kind_file_failed) implies last_path = Void
			cancelled_noted: a_event.kind = Kind_file_cancelled implies was_cancelled
			others_change_nothing: not is_file_kind (a_event.kind) implies is_picking = old is_picking
		end

feature {NONE} -- Commands for the phone class

	note_picking
			-- The picker has been opened.
		require
			closed: not is_picking
		do
			is_picking := True
			was_cancelled := False
			last_path := Void
			create last_error.make_empty
		ensure
			open: is_picking
			fresh: last_path = Void and last_error.is_empty and not was_cancelled
		end

invariant
	open_has_no_result: is_picking implies (last_path = Void and last_error.is_empty and not was_cancelled)
	one_outcome: not (was_cancelled and attached last_path)

end
