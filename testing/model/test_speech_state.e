note
	description: "PHONE_SPEECH_STATE with its phone-only commands opened for the tests."

class
	TEST_SPEECH_STATE

inherit
	PHONE_SPEECH_STATE

create
	make

feature -- Test access

	begin
		do
			note_starting
		end

	say
		do
			note_speaking
		end

end
