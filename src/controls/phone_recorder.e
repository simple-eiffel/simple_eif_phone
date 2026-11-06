note
	description: "[
		Records the microphone to a 16 kHz mono WAV file, with the screen locked if need be.
		Needs `recorder = true' under [android] in eifphone.toml. Make one and keep it.

			create recorder.make (phone.controls)
			recorder.ask_permission (agent on_answer)
			recorder.start (path, agent on_change)
			recorder.stop

		While it records, Android shows a notification saying the microphone is on.
	]"
	author: "Larry Rix"

class
	PHONE_RECORDER

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
			-- A recorder, not yet recording.
		do
			make_control (a_controls, Control_any, Recorder_class)
			listen ("setOnRecorderListener", agent heard)
		ensure
			mine: controls = a_controls
			quiet: not is_recording
		end

feature -- Status

	is_recording: BOOLEAN
			-- Is the microphone writing to the file?

	seconds: INTEGER
			-- Whole seconds in the last finished recording.

feature -- Commands

	ask_permission (a_action: PROCEDURE [TUPLE [granted: BOOLEAN]])
			-- Ask the person for the microphone. `a_action' hears the answer.
		do
			permission_action := a_action
			call ("askPermission")
		end

	start (a_path: READABLE_STRING_GENERAL; a_action: PROCEDURE [TUPLE [state: READABLE_STRING_32; detail: READABLE_STRING_32]])
			-- Record to the file at `a_path'. `a_action' hears "recording", then "stopped"
			-- with the seconds recorded, or "failed" with why.
		require
			path_given: not a_path.is_empty
			not_recording: not is_recording
		do
			change_action := a_action
			call_text ("start", a_path.to_string_32)
		end

	stop
			-- Stop recording. "stopped" follows once the file is complete.
		do
			call ("stop")
		end

	ask_seconds (a_action: PROCEDURE [TUPLE [READABLE_STRING_32]])
			-- `a_action' hears the whole seconds recorded so far.
		do
			ask ("recordedSeconds", a_action)
		end

feature {NONE} -- Implementation

	heard (a_words: READABLE_STRING_32)
			-- "onRecorder|state|detail".
		local
			l_first, l_second: INTEGER
			l_state, l_detail: READABLE_STRING_32
		do
			l_first := a_words.index_of ('|', 1)
			l_second := a_words.index_of ('|', l_first + 1)
			if l_first > 0 and l_second > 0 then
				l_state := a_words.substring (l_first + 1, l_second - 1)
				l_detail := a_words.substring (l_second + 1, a_words.count)
				if l_state.same_string ({STRING_32} "granted") or l_state.same_string ({STRING_32} "denied") then
					if attached permission_action as al_action then
						permission_action := Void
						al_action.call ([l_state.same_string ({STRING_32} "granted")])
					end
				else
					note_change (l_state, l_detail)
				end
			end
		end

	note_change (a_state, a_detail: READABLE_STRING_32)
			-- Keep the status up to date and pass the news on.
		do
			is_recording := a_state.same_string ({STRING_32} "recording")
			if a_state.same_string ({STRING_32} "stopped") and a_detail.is_integer then
				seconds := a_detail.to_integer
			end
			if attached change_action as al_action then
				al_action.call ([a_state, a_detail])
			end
		end

	permission_action: detachable PROCEDURE [TUPLE [granted: BOOLEAN]]

	change_action: detachable PROCEDURE [TUPLE [state: READABLE_STRING_32; detail: READABLE_STRING_32]]

	Recorder_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneRecorder"

end
