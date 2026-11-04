note
	description: "[
		Where orders for Android's controls go. On a phone that is the C side
		(PHONE_CONTROL_LINK). A test on a PC gives a port that records them.
	]"
	author: "Larry Rix"

deferred class
	PHONE_CONTROL_PORT

feature -- Status

	is_connected: BOOLEAN
			-- Can controls be shown? Needs `controls = true' in eifphone.toml.
		deferred
		end

	density_percent: INTEGER
			-- Screen pixels per density-independent pixel, times 100.
		deferred
		ensure
			positive: Result > 0
		end

feature -- Access

	painter: PHONE_PAINTER
			-- What a canvas draws with.
		deferred
		end

feature -- Commands

	send (a_order, a_id, a_first, a_second: INTEGER; a_text: detachable READABLE_STRING_32)
			-- Queue `a_order' for control `a_id'. Returns at once, and never answers.
		require
			order_known: a_order > 0
			id_valid: a_id >= 0
		deferred
		end

end
