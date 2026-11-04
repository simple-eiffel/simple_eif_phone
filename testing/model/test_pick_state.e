note
	description: "PHONE_PICK_STATE with its phone-only command opened for the tests."

class
	TEST_PICK_STATE

inherit
	PHONE_PICK_STATE

create
	make

feature -- Test access

	open
		do
			note_picking
		end

end
