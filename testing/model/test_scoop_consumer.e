note
	description: "SCOOP consumer compatibility check for the model types (Phase 1 gate)."
	author: "Larry Rix"

class
	TEST_SCOOP_CONSUMER

feature -- Test

	test_scoop_compatibility
			-- The model types compile and work in a SCOOP-enabled system.
		local
			l_life: PHONE_LIFECYCLE
			l_touches: PHONE_TOUCHES
			l_event: PHONE_EVENT
			l_rect: PHONE_RECT
		do
			create l_life.make
			create l_touches.make
			create l_event.make_none
			create l_rect.make (0, 0, 1, 1)
		end

end
