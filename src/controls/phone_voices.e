note
	description: "[
		The phone's text-to-speech engines and installed voices, all of them. The app says
		what to read one stretch at a time, naming the language; `on_voice' hears when a
		stretch is done, when no voice has its language, and when other audio took over.
		Never a voice that needs the network. Make one and keep it.
	]"
	author: "Larry Rix"

class
	PHONE_VOICES

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_control (a_controls, Control_any, Voices_class)
			listen ("setOnVoiceListener", agent heard)
		ensure
			mine: controls = a_controls
		end

feature -- Access

	on_voice: detachable PROCEDURE [TUPLE [kind: READABLE_STRING_32; detail: READABLE_STRING_32]]
			-- Told "done" with a stretch's id, "missing" with one no voice can read,
			-- "lost" when other audio takes over, "report" with what `ask_report' asked.

feature -- Element change

	set_on_voice (a_action: PROCEDURE [TUPLE [kind: READABLE_STRING_32; detail: READABLE_STRING_32]])
		do
			on_voice := a_action
		ensure
			set: on_voice = a_action
		end

	set_rate (a_rate: REAL_64)
			-- Speak at `a_rate' times normal speed.
		require
			positive: a_rate > 0
		do
			call_integer ("setRate", (a_rate * 100).rounded)
		end

feature -- Speaking

	speak (a_id: INTEGER; a_codes, a_country, a_fallback: READABLE_STRING_8; a_text: READABLE_STRING_32)
			-- Read `a_text' in the language of `a_codes' (comma-separated), better from
			-- `a_country'; failing that in `a_fallback'.
		local
			l_wire: STRING_32
		do
			create l_wire.make (a_text.count + 24)
			l_wire.append_integer (a_id)
			l_wire.append_character (Field)
			l_wire.append_string_general (a_codes)
			l_wire.append_character (Field)
			l_wire.append_string_general (a_country)
			l_wire.append_character (Field)
			l_wire.append_string_general (a_fallback)
			l_wire.append_character (Field)
			l_wire.append (a_text)
			call_text ("speakStretch", l_wire)
		end

	stop
		do
			call ("stopSpeaking")
		end

	take_audio (a_on: BOOLEAN)
			-- Ask for the phone's audio, or give it back.
		do
			call_boolean ("requestFocus", a_on)
		end

	ask_report (a_wire: READABLE_STRING_32)
			-- Ask which voice each language gets. `a_wire' holds each language as its label,
			-- codes, country and fallback, split by U+001D, the languages by U+001E.
		do
			call_text ("askReport", a_wire)
		end

feature {NONE} -- Implementation

	heard (a_words: READABLE_STRING_32)
			-- "onVoice|kind|detail".
		local
			l_first, l_second: INTEGER
		do
			l_first := a_words.index_of ('|', 1)
			l_second := a_words.index_of ('|', l_first + 1)
			if l_second > 0 and then attached on_voice as al_action then
				al_action.call ([a_words.substring (l_first + 1, l_second - 1), a_words.substring (l_second + 1, a_words.count)])
			end
		end

	Field: CHARACTER_32 = '%/29/'

	Voices_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneVoices"

end
