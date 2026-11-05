note
	description: "[
		One of Android's controls. The classes that inherit this cover the common
		ones. Any other works through this class itself:

			create l_stars.make_any (phone.controls, "android.widget.RatingBar")
			l_stars.call_integer ("setNumStars", 5)
			l_stars.listen ("setOnRatingBarChangeListener", agent on_rating)
			l_stars.ask ("getRating", agent on_answer)

		Any public method taking nothing, a whole number, a true/false or a text
		can be called by name, and any setOn...Listener can be listened to.
	]"
	author: "Larry Rix"

class
	PHONE_CONTROL

inherit
	PHONE_CONTROL_CODES

	PHONE_EVENT_KIND

create
	make_any

feature {NONE} -- Initialization

	make_any (a_controls: PHONE_CONTROLS; a_class: READABLE_STRING_8)
			-- The control of Java class `a_class', such as "android.widget.RatingBar".
			-- It needs a public constructor taking a Context. A wrong name reports
			-- through `last_failure'.
		require
			class_given: not a_class.is_empty
		do
			make_control (a_controls, Control_any, a_class.to_string_32)
		ensure
			mine: controls = a_controls
		end

	make_control (a_controls: PHONE_CONTROLS; a_kind: INTEGER; a_class: detachable READABLE_STRING_32)
			-- Enroll in `a_controls' and order the control made.
		do
			controls := a_controls
			is_enabled := True
			is_visible := True
			create asked.make (4)
			create listeners.make (2)
			id := a_controls.enroll (Current)
			a_controls.port.send (Op_new, id, a_kind, 0, a_class)
		ensure
			mine: controls = a_controls
			has_id: id > 0
			enabled: is_enabled
			visible: is_visible
		end

feature -- Access

	controls: PHONE_CONTROLS

	id: INTEGER
			-- This control's number, shared with the C side.

	last_failure: detachable READABLE_STRING_32
			-- What Android last refused, if anything.

	on_failure: detachable PROCEDURE [TUPLE [READABLE_STRING_32]]

feature -- Status

	is_discarded: BOOLEAN
			-- Has Android been told to forget this control?

	is_enabled: BOOLEAN

	is_visible: BOOLEAN

feature -- Element change

	set_enabled (a_on: BOOLEAN)
		do
			is_enabled := a_on
			order (Op_enabled, a_on.to_integer, 0, Void)
		ensure
			set: is_enabled = a_on
		end

	set_visible (a_on: BOOLEAN)
			-- Show or hide. A hidden control takes up no room.
		do
			is_visible := a_on
			order (Op_visible, a_on.to_integer, 0, Void)
		ensure
			set: is_visible = a_on
		end

	set_height (a_height: INTEGER)
			-- Fix the height, in density-independent pixels.
		require
			positive: a_height > 0
		do
			order (Op_height, a_height, 0, Void)
		end

	set_padding (a_sides, a_top_and_bottom: INTEGER)
			-- Set the space inside the control, in density-independent pixels. Android's
			-- buttons keep a lot at the sides, which matters to narrow ones when the
			-- phone's text size is set large.
		require
			sides_valid: a_sides >= 0
			top_and_bottom_valid: a_top_and_bottom >= 0
		do
			order (Op_padding, a_sides, a_top_and_bottom, Void)
		end

	set_least_width (a_width: INTEGER)
			-- Be at least `a_width' wide, in density-independent pixels.
		require
			positive: a_width > 0
		do
			order (Op_least_width, a_width, 0, Void)
		end

	set_least_height (a_height: INTEGER)
			-- Be at least `a_height' tall, in density-independent pixels, and grow past it with what is inside.
		require
			positive: a_height > 0
		do
			order (Op_least_height, a_height, 0, Void)
		end

	set_padding_each (a_start, a_top, a_end, a_bottom: INTEGER)
			-- Set the space inside the control, side by side, in density-independent pixels.
		require
			start_valid: a_start >= 0 and a_start < 65536
			top_valid: a_top >= 0 and a_top < 65536
			end_valid: a_end >= 0 and a_end < 65536
			bottom_valid: a_bottom >= 0 and a_bottom < 65536
		do
			order (Op_padding_each, a_start * 65536 + a_end, a_top * 65536 + a_bottom, Void)
		end

	set_on_tap (a_action: PROCEDURE [TUPLE])
			-- Make the control tappable, with Android's ripple.
		do
			if on_tap = Void then
				listen ("setOnClickListener", agent tap_heard)
				order (Op_ripple, 0, 0, Void)
			end
			on_tap := a_action
		ensure
			set: on_tap = a_action
		end

	set_surface (a_color: NATURAL_32; a_radius: INTEGER)
			-- A background of `a_color' (0xAARRGGBB), corners rounded by `a_radius'
			-- density-independent pixels.
		require
			radius_valid: a_radius >= 0
		do
			order (Op_surface, a_color.as_integer_32, a_radius, {STRING_32} "")
		end

	set_bordered_surface (a_color: NATURAL_32; a_radius: INTEGER; a_border: NATURAL_32; a_border_width: INTEGER)
			-- As `set_surface', with a border.
		require
			radius_valid: a_radius >= 0
			width_positive: a_border_width > 0
		do
			order (Op_surface, a_color.as_integer_32, a_radius, a_border.to_hex_string.to_string_32 + {STRING_32} " " + a_border_width.out.to_string_32)
		end

	discard
			-- Finished with this control: Android lets go of it. Take it out of its
			-- parent first. Screens that are shown again need not do this; an app
			-- that keeps building new controls should, or they stay in memory.
		require
			not_shown: controls.root /= Current
		do
			order (Op_discard, 0, 0, Void)
			controls.forget (Current)
			is_discarded := True
		ensure
			discarded: is_discarded
		end

	request_focus
			-- Take the focus. In a text box, this is where typing goes.
		do
			order (Op_focus, 0, 0, Void)
		end

	set_on_failure (a_action: PROCEDURE [TUPLE [READABLE_STRING_32]])
		do
			on_failure := a_action
		ensure
			set: on_failure = a_action
		end

feature -- The general route

	call (a_method: READABLE_STRING_8)
			-- Call public method `a_method', which takes nothing.
		require
			method_given: not a_method.is_empty
		do
			order (Op_call, 0, Argument_none, call_text_of (a_method, {STRING_32} ""))
		end

	call_integer (a_method: READABLE_STRING_8; a_value: INTEGER)
		require
			method_given: not a_method.is_empty
		do
			order (Op_call, a_value, Argument_integer, call_text_of (a_method, {STRING_32} ""))
		end

	call_boolean (a_method: READABLE_STRING_8; a_value: BOOLEAN)
		require
			method_given: not a_method.is_empty
		do
			order (Op_call, a_value.to_integer, Argument_boolean, call_text_of (a_method, {STRING_32} ""))
		end

	call_text (a_method: READABLE_STRING_8; a_value: READABLE_STRING_32)
		require
			method_given: not a_method.is_empty
		do
			order (Op_call, 0, Argument_text, call_text_of (a_method, a_value))
		end

	ask (a_method: READABLE_STRING_8; a_answer: PROCEDURE [TUPLE [READABLE_STRING_32]])
			-- Call public method `a_method', which takes nothing. `a_answer' gets
			-- what it returned, as text. Android answers later, as an event.
		require
			method_given: not a_method.is_empty
		do
			last_token := last_token + 1
			asked.force (a_answer, last_token)
			order (Op_ask, last_token, 0, a_method.to_string_32)
		end

	listen (a_setter: READABLE_STRING_8; a_action: PROCEDURE [TUPLE [READABLE_STRING_32]])
			-- Listen through `a_setter', such as "setOnRatingBarChangeListener".
			-- `a_action' gets the callback's name and its arguments, split by |.
		require
			setter_given: not a_setter.is_empty
		do
			listeners.extend (a_action)
			order (Op_listen, 0, 0, a_setter.to_string_32)
		end

feature {PHONE_CONTROLS} -- Events

	handle (a_event: PHONE_EVENT)
			-- React to `a_event', which is for this control.
		require
			for_me: a_event.control_id = id
		do
			inspect a_event.kind
			when Kind_control_answered then
				if attached asked.item (a_event.x) as al_answer then
					asked.remove (a_event.x)
					al_answer.call ([a_event.text])
				end
			when Kind_control_called then
				across listeners as ic loop
					ic.call ([a_event.text])
				end
			when Kind_control_failed then
				last_failure := a_event.text
				if attached on_failure as al_action then
					al_action.call ([a_event.text])
				end
			else
				handle_own (a_event)
			end
		end

feature {NONE} -- Implementation

	on_tap: detachable PROCEDURE [TUPLE]
			-- What a tap does, if the control takes them.

	tap_heard (a_words: READABLE_STRING_32)
		do
			if attached on_tap as al_action then
				al_action.call ([])
			end
		end

	handle_own (a_event: PHONE_EVENT)
			-- React to an event only this kind of control receives.
		do
		end

	order (a_order, a_first, a_second: INTEGER; a_text: detachable READABLE_STRING_32)
			-- Send `a_order' for this control.
		require
			not_discarded: not is_discarded
		do
			controls.port.send (a_order, id, a_first, a_second, a_text)
		end

	call_text_of (a_method: READABLE_STRING_8; a_value: READABLE_STRING_32): STRING_32
			-- The method name and its text argument, as one order's text.
		do
			Result := a_method.to_string_32
			Result.append_character (Field_mark)
			Result.append (a_value)
		end

	asked: HASH_TABLE [PROCEDURE [TUPLE [READABLE_STRING_32]], INTEGER]
			-- Questions in flight, by token.

	last_token: INTEGER

	listeners: ARRAYED_LIST [PROCEDURE [TUPLE [READABLE_STRING_32]]]

invariant
	has_id: id > 0
	known: not is_discarded implies controls.item (id) = Current

end
