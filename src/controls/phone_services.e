note
	description: "[
		What the app asks of the phone rather than of a control: a timer, the clipboard,
		sharing text, keeping the screen on. Make one and keep it.
	]"
	author: "Larry Rix"

class
	PHONE_SERVICES

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create waiting.make (4)
			make_control (a_controls, Control_any, Services_class)
			listen ("setOnDueListener", agent due)
			listen ("setOnFileListener", agent file_heard)
		ensure
			mine: controls = a_controls
		end

feature -- Timing

	after (a_milliseconds: INTEGER; a_action: PROCEDURE [TUPLE])
			-- Run `a_action' once, `a_milliseconds' from now.
		require
			not_negative: a_milliseconds >= 0
		do
			last_timer := last_timer + 1
			waiting.force (a_action, last_timer)
			call_integer ("setDelay", a_milliseconds)
			call_integer ("start", last_timer)
		end

feature -- Sharing

	copy_text (a_text: READABLE_STRING_32)
			-- Put `a_text' on the clipboard.
		do
			call_text ("copyText", a_text)
		end

	share_text (a_text: READABLE_STRING_32)
			-- Offer `a_text' to the apps that take shared text.
		do
			call_text ("shareText", a_text)
		end

feature -- Files

	open_file (a_types: ARRAY [READABLE_STRING_8]; a_target: READABLE_STRING_GENERAL; a_action: PROCEDURE [TUPLE [outcome: READABLE_STRING_32; detail: READABLE_STRING_32]])
			-- Let the user choose a file of one of `a_types'; it is copied to `a_target'. `a_action'
			-- hears "done", "cancelled", or "failed" with why.
		local
			l_wire: STRING_32
		do
			create l_wire.make_from_string_general (a_target)
			across a_types as ic loop
				l_wire.append_character (Field)
				l_wire.append_string_general (ic)
			end
			file_action := a_action
			call_text ("openFile", l_wire)
		end

	save_file (a_source, a_name: READABLE_STRING_GENERAL; a_type: READABLE_STRING_8; a_action: PROCEDURE [TUPLE [outcome: READABLE_STRING_32; detail: READABLE_STRING_32]])
			-- Let the user choose where `a_source' goes, suggesting `a_name'. `a_action' hears as
			-- for `open_file'.
		local
			l_wire: STRING_32
		do
			create l_wire.make_from_string_general (a_source)
			l_wire.append_character (Field)
			l_wire.append_string_general (a_name)
			l_wire.append_character (Field)
			l_wire.append_string_general (a_type)
			file_action := a_action
			call_text ("saveFile", l_wire)
		end

feature -- Screen

	hide_keyboard
		do
			call ("hideKeyboard")
		end

	keep_screen_on (a_on: BOOLEAN)
		do
			call_boolean ("keepScreenOn", a_on)
		end

	open_speech_settings
			-- Open the phone's text-to-speech settings.
		do
			call ("openTextToSpeechSettings")
		end

feature {NONE} -- Implementation

	due (a_words: READABLE_STRING_32)
			-- "onDue|token".
		local
			l_number: STRING_32
		do
			l_number := a_words.substring (a_words.index_of ('|', 1) + 1, a_words.count)
			if l_number.is_integer and then attached waiting.item (l_number.to_integer) as al_action then
				waiting.remove (l_number.to_integer)
				al_action.call ([])
			end
		end

	file_heard (a_words: READABLE_STRING_32)
			-- "onFile|outcome|detail".
		local
			l_first, l_second: INTEGER
		do
			l_first := a_words.index_of ('|', 1)
			l_second := a_words.index_of ('|', l_first + 1)
			if l_second > 0 and then attached file_action as al_action then
				file_action := Void
				al_action.call ([a_words.substring (l_first + 1, l_second - 1), a_words.substring (l_second + 1, a_words.count)])
			end
		end

	file_action: detachable PROCEDURE [TUPLE [outcome: READABLE_STRING_32; detail: READABLE_STRING_32]]

	Field: CHARACTER_32 = '%/29/'

	waiting: HASH_TABLE [PROCEDURE [TUPLE], INTEGER]

	last_timer: INTEGER

	Services_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneServices"

end
