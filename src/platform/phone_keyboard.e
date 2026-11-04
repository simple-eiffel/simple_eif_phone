note
	description: "[
		The phone's keyboard, for screens that draw their own text boxes. Android's
		own text box brings the keyboard by itself, and has no need of this.
		Needs `java_helper = true' in eifphone.toml. What the user types arrives as
		Kind_keyboard_text, Kind_keyboard_backspace and Kind_keyboard_enter events.
	]"
	author: "Larry Rix"

class
	PHONE_KEYBOARD

inherit
	PHONE_EVENT_KIND

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
		do
		ensure
			hidden: not is_shown
		end

feature -- Status

	is_shown: BOOLEAN
			-- Has the keyboard been asked for, and not put away?

	top: INTEGER
			-- The keyboard's top edge in screen pixels; 0 while Android has not said, or it is gone.

	is_available: BOOLEAN
			-- Does this app carry the Java helper?
		do
			Result := c_helper_present /= 0
		end

feature -- Commands

	show
			-- Bring up the keyboard.
		require
			available: is_available
		do
			if not is_shown then
				is_shown := True
				c_keyboard (1)
			end
		ensure
			shown: is_shown
		end

	hide
			-- Put the keyboard away.
		require
			available: is_available
		do
			if is_shown then
				is_shown := False
				c_keyboard (0)
			end
		ensure
			hidden: not is_shown
		end

	apply (a_event: PHONE_EVENT)
			-- Take in `a_event'. The user can put the keyboard away too.
		do
			if a_event.kind = Kind_keyboard_closed then
				is_shown := False
				top := 0
			elseif a_event.kind = Kind_keyboard_top then
				top := a_event.service_code
			end
		end

end
