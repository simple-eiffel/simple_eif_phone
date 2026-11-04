note
	description: "[
		Android's own controls, for Eiffel: `phone.controls'. Build controls, give
		the top one to `show', and pass each event to `dispatch' (or let
		SIMPLE_EIF_PHONE.run_controls do that). Needs `controls = true' in eifphone.toml.

		Nothing here waits for Android. Orders go out through `port'; what the
		user does comes back as events, and `dispatch' turns those into calls of
		the agents the app gave its controls, on the app's own thread.
	]"
	author: "Larry Rix"

class
	PHONE_CONTROLS

inherit
	PHONE_CONTROL_CODES

	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make (a_port: PHONE_CONTROL_PORT)
			-- Controls that take orders through `a_port'.
		do
			port := a_port
			create members.make (32)
			create answers.make (4)
			create waiting_canvases.make (1)
		ensure
			port_set: port = a_port
			none_yet: count = 0
			nothing_shown: root = Void
		end

feature -- Access

	port: PHONE_CONTROL_PORT

	root: detachable PHONE_CONTROL
			-- The control filling the screen.

	item (a_id: INTEGER): detachable PHONE_CONTROL
			-- The control with id `a_id'.
		do
			Result := members.item (a_id)
		end

	count: INTEGER
			-- Controls made so far.
		do
			Result := members.count
		end

	on_back: detachable PROCEDURE [TUPLE]
			-- What the Back key does, if not Android's default.

	is_available: BOOLEAN
			-- Was this app built with `controls = true'?
		do
			Result := port.is_connected
		end

feature -- Commands

	show (a_root: PHONE_CONTROL)
			-- Fill the screen with `a_root', in place of what was there.
		require
			mine: a_root.controls = Current
		do
			root := a_root
			port.send (Op_show, a_root.id, 0, 0, Void)
		ensure
			shown: root = a_root
		end

	toast (a_text: READABLE_STRING_32)
			-- A brief message at the bottom of the screen.
		require
			text_given: not a_text.is_empty
		do
			port.send (Op_toast, 0, 0, 0, a_text)
		end

	confirm (a_title, a_message, a_yes, a_no: READABLE_STRING_32; a_answer: PROCEDURE [TUPLE [BOOLEAN]])
			-- Ask a question. `a_answer' gets True for `a_yes'; False for `a_no' or
			-- when the user backs out. An empty `a_no' leaves one button.
		require
			yes_given: not a_yes.is_empty
		local
			l_text: STRING_32
			l_id: INTEGER
		do
			l_id := new_id
			answers.force (agent answer_confirm (a_answer, ?), l_id)
			create l_text.make_from_string (a_title)
			l_text.append_character (Field_mark)
			l_text.append (a_message)
			l_text.append_character (Field_mark)
			l_text.append (a_yes)
			l_text.append_character (Field_mark)
			l_text.append (a_no)
			port.send (Op_dialog, l_id, 0, 0, l_text)
		end

	pick_date (a_year, a_month, a_day: INTEGER; a_answer: PROCEDURE [TUPLE [READABLE_STRING_32]])
			-- Android's date picker, opened at the date given. `a_answer' gets
			-- "year-month-day", or empty text when the user backs out.
		require
			month_valid: a_month >= 1 and a_month <= 12
			day_valid: a_day >= 1 and a_day <= 31
		local
			l_id: INTEGER
		do
			l_id := new_id
			answers.force (agent answer_text (a_answer, ?), l_id)
			port.send (Op_date, l_id, a_year, a_month * 100 + a_day, Void)
		end

	pick_time (a_hour, a_minute: INTEGER; a_answer: PROCEDURE [TUPLE [READABLE_STRING_32]])
			-- Android's time picker. `a_answer' gets "hour:minute", or empty text
			-- when the user backs out.
		require
			hour_valid: a_hour >= 0 and a_hour <= 23
			minute_valid: a_minute >= 0 and a_minute <= 59
		local
			l_id: INTEGER
		do
			l_id := new_id
			answers.force (agent answer_text (a_answer, ?), l_id)
			port.send (Op_time, l_id, a_hour, a_minute, Void)
		end

	set_on_back (a_action: PROCEDURE [TUPLE])
			-- From now on the Back key calls `a_action' and leaves the app alone.
		do
			on_back := a_action
			if back_id = 0 then
				back_id := new_id
			end
			port.send (Op_back, 0, back_id, 0, Void)
		ensure
			set: on_back = a_action
		end

	clear_on_back
			-- From now on Back does what Android does: it closes the app.
		do
			on_back := Void
			port.send (Op_back, 0, 0, 0, Void)
		ensure
			cleared: on_back = Void
		end

	repaint_waiting
			-- Paint the canvases that asked for it. Call when no event is waiting.
		do
			across waiting_canvases as ic loop
				ic.repaint
			end
			waiting_canvases.wipe_out
		end

	dispatch (a_event: PHONE_EVENT)
			-- Hand `a_event' to its control. Anything else is ignored.
		local
			l_id: INTEGER
		do
			if a_event.is_control then
				l_id := a_event.control_id
				if a_event.kind = Kind_control_back then
					if attached on_back as al_action then
						al_action.call ([])
					end
				elseif attached answers.item (l_id) as al_answer then
					answers.remove (l_id)
					al_answer.call ([a_event])
				elseif attached members.item (l_id) as al_control then
					al_control.handle (a_event)
				end
			end
		end

feature {PHONE_CANVAS} -- Painting

	note_repaint (a_canvas: PHONE_CANVAS)
			-- `a_canvas' wants to paint.
		do
			waiting_canvases.extend (a_canvas)
		end

feature {PHONE_CONTROL} -- Membership

	enroll (a_control: PHONE_CONTROL): INTEGER
			-- Give `a_control' its id.
		do
			Result := new_id
			members.force (a_control, Result)
		ensure
			positive: Result > 0
			enrolled: item (Result) = a_control
			counted: count = old count + 1
		end

	forget (a_control: PHONE_CONTROL)
			-- `a_control' is finished with.
		do
			members.remove (a_control.id)
		ensure
			gone: item (a_control.id) = Void
		end

	to_pixels (a_value: INTEGER): INTEGER
			-- Screen pixels `a_value' arrived in, as density-independent pixels.
		do
			Result := a_value * 100 // port.density_percent
		end

	to_measure (a_value: INTEGER): REAL_64
			-- As `to_pixels', keeping the fraction, so that a drawn line stays smooth.
		do
			Result := a_value * 100.0 / port.density_percent
		end

feature {NONE} -- Implementation

	members: HASH_TABLE [PHONE_CONTROL, INTEGER]

	waiting_canvases: ARRAYED_LIST [PHONE_CANVAS]

	answers: HASH_TABLE [PROCEDURE [TUPLE [PHONE_EVENT]], INTEGER]
			-- Questions in flight, by the id they were asked under.

	last_id: INTEGER

	back_id: INTEGER
			-- The id Android's Back reports under; 0 until an app asks for Back.

	new_id: INTEGER
			-- An id no control or question has had.
		do
			last_id := last_id + 1
			Result := last_id
		ensure
			fresh: Result = old last_id + 1
		end

	answer_confirm (a_answer: PROCEDURE [TUPLE [BOOLEAN]]; a_event: PHONE_EVENT)
		do
			a_answer.call ([a_event.x = 1])
		end

	answer_text (a_answer: PROCEDURE [TUPLE [READABLE_STRING_32]]; a_event: PHONE_EVENT)
		do
			a_answer.call ([a_event.text])
		end

invariant
	count_non_negative: count >= 0
	ids_ahead: last_id >= count

end
