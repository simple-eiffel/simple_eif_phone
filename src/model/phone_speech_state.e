note
	description: "[
		Where read-aloud stands: starting, ready, speaking, and why it last
		failed. Pure Eiffel, so its rules run on a PC too. Results reach it
		as events, through `apply'.
	]"
	author: "Larry Rix"

class
	PHONE_SPEECH_STATE

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
		do
		ensure
			idle: not is_starting and not is_ready and not is_speaking
			no_failure: last_failure = 0
		end

feature -- Status

	is_starting: BOOLEAN
			-- Has the engine been asked for, with no answer yet?

	is_ready: BOOLEAN
			-- Can the phone speak now?

	is_speaking: BOOLEAN
			-- Is an utterance under way?

	last_failure: INTEGER
			-- Why it last failed: 0, or one of the Failure_ codes.

feature -- Codes

	Failure_no_engine: INTEGER = 1
			-- This phone has no speech engine, or it would not start.

	Failure_language: INTEGER = 2
			-- The engine cannot speak that language.

	Failure_utterance: INTEGER = 3
			-- The engine failed part way.

	Done_finished: INTEGER = 0
			-- The utterance reached its end.

	Done_stopped: INTEGER = 1
			-- `stop' ended the utterance.

feature -- Events

	apply (a_event: PHONE_EVENT)
			-- Take in `a_event'. Events from other services change nothing.
		do
			inspect a_event.kind
			when Kind_speech_ready then
				is_starting := False
				is_ready := True
				last_failure := 0
			when Kind_speech_failed then
				is_starting := False
				is_speaking := False
				last_failure := a_event.service_code
				if a_event.service_code = Failure_no_engine then
					is_ready := False
				end
			when Kind_speech_done then
				is_speaking := False
			else
			end
		ensure
			ready_on_ready: a_event.kind = Kind_speech_ready implies is_ready
			quiet_on_done: a_event.kind = Kind_speech_done implies not is_speaking
			quiet_on_failure: a_event.kind = Kind_speech_failed implies not is_speaking
			failure_kept: a_event.kind = Kind_speech_failed implies last_failure = a_event.service_code
			others_change_nothing: not is_speech_kind (a_event.kind) implies
				(is_starting = old is_starting and is_ready = old is_ready and is_speaking = old is_speaking and last_failure = old last_failure)
		end

feature {NONE} -- Commands for the phone class

	note_starting
			-- The engine has been asked for.
		require
			idle: not is_starting and not is_ready
		do
			is_starting := True
			last_failure := 0
		ensure
			starting: is_starting
		end

	note_speaking
			-- An utterance has been asked for.
		require
			ready: is_ready
		do
			is_speaking := True
		ensure
			speaking: is_speaking
		end

invariant
	starting_is_not_ready: is_starting implies not is_ready
	speaking_needs_ready: is_speaking implies is_ready
	failure_known: last_failure >= 0

end
