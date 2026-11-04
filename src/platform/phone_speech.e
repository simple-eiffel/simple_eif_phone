note
	description: "[
		Read text aloud. Needs `java_helper = true' in eifphone.toml.
		Call `start', and wait for Kind_speech_ready or Kind_speech_failed.
		Then `speak'. Kind_speech_done says when it ends.
	]"
	author: "Larry Rix"

class
	PHONE_SPEECH

inherit
	PHONE_SPEECH_STATE

inherit {NONE}
	PHONE_NATIVE

create
	make

feature -- Status

	is_available: BOOLEAN
			-- Does this app carry the Java helper?
		do
			Result := c_helper_present /= 0
		end

feature -- Commands

	start
			-- Ask for the speech engine. The answer arrives as an event.
		require
			available: is_available
			idle: not is_starting and not is_ready
		do
			note_starting
			c_speech_start
		ensure
			starting: is_starting
		end

	speak (a_text: READABLE_STRING_32; a_language: READABLE_STRING_8)
			-- Read `a_text' aloud in `a_language', such as "en-US" or "he-IL".
			-- Anything already being read stops first.
		require
			ready: is_ready
			text_given: not a_text.is_empty
			language_given: not a_language.is_empty
		local
			l_text, l_language: C_STRING
		do
			note_speaking
			create l_text.make ({UTF_CONVERTER}.utf_32_string_to_utf_8_string_8 (a_text))
			create l_language.make (a_language)
			c_speak (l_text.item, l_language.item)
		ensure
			speaking: is_speaking
		end

	stop
			-- Stop reading.
		require
			ready: is_ready
		do
			c_speech_stop
		end

end
