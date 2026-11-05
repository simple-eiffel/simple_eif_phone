note
	description: "[
		An outlined text field in Material's form: a label that floats into the outline,
		a placeholder while focused and empty, and the keyboard's action key.
		`text' follows what the user types, one event behind.
	]"
	author: "Larry Rix"

class
	PHONE_FIELD

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_label: READABLE_STRING_32; a_accent, a_outline, a_muted, a_words: NATURAL_32)
			-- A field with `a_label', in these colors.
		do
			text := {STRING_32} ""
			make_control (a_controls, Control_any, Field_class)
			call_integer ("setAccent", a_accent.as_integer_32)
			call_integer ("setOutline", a_outline.as_integer_32)
			call_integer ("setMuted", a_muted.as_integer_32)
			call_integer ("setWords", a_words.as_integer_32)
			call_text ("setLabel", a_label)
			listen ("setOnFieldListener", agent heard)
		ensure
			mine: controls = a_controls
			empty: text.is_empty
		end

feature -- Access

	text: READABLE_STRING_32

	on_change: detachable PROCEDURE [TUPLE]
			-- Told when the user changes the text; not when `set_text' does.

	on_action: detachable PROCEDURE [TUPLE]
			-- Told when the user presses the keyboard's action key.

	on_left: detachable PROCEDURE [TUPLE]
			-- Told when the field loses the focus.

feature -- Constants

	Action_go: INTEGER = 2

	Action_search: INTEGER = 3

	Action_done: INTEGER = 6

feature -- Element change

	set_text (a_text: READABLE_STRING_32)
		do
			text := a_text
			call_text ("setText", a_text)
		ensure
			set: text.same_string (a_text)
		end

	set_placeholder (a_text: READABLE_STRING_32)
		do
			call_text ("setPlaceholder", a_text)
		end

	set_keyboard_action (a_action: INTEGER)
			-- Show `a_action' on the keyboard's action key.
		do
			call_integer ("setKeyboardAction", a_action)
		end

	set_multi_line (a_lines: INTEGER)
			-- Take more than one line, and show at least `a_lines'.
		require
			positive: a_lines > 0
		do
			call_integer ("setMultiLine", a_lines)
		end

	set_box_height (a_height: INTEGER)
			-- Make the box at least `a_height' tall, in density-independent pixels.
		require
			positive: a_height > 0
		do
			call_integer ("setBoxHeight", a_height)
		end

	set_on_change (a_action: PROCEDURE [TUPLE])
		do
			on_change := a_action
		ensure
			set: on_change = a_action
		end

	set_on_action (a_action: PROCEDURE [TUPLE])
		do
			on_action := a_action
		ensure
			set: on_action = a_action
		end

	set_on_left (a_action: PROCEDURE [TUPLE])
		do
			on_left := a_action
		ensure
			set: on_left = a_action
		end

	enter
			-- Take the focus and bring up the keyboard.
		do
			call ("enter")
		end

	leave
			-- Give up the focus and put the keyboard away.
		do
			call ("leave")
		end

feature {NONE} -- Implementation

	heard (a_words: READABLE_STRING_32)
			-- "onChanged|text", "onAction" or "onLeft".
		local
			l_bar: INTEGER
		do
			l_bar := a_words.index_of ('|', 1)
			if a_words.starts_with ({STRING_32} "onChanged") then
				if l_bar > 0 then
					text := a_words.substring (l_bar + 1, a_words.count)
				else
					text := {STRING_32} ""
				end
				if attached on_change as al_action then
					al_action.call ([])
				end
			elseif a_words.starts_with ({STRING_32} "onAction") then
				if attached on_action as al_action then
					al_action.call ([])
				end
			elseif attached on_left as al_action then
				al_action.call ([])
			end
		end

	Field_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneField"

end
