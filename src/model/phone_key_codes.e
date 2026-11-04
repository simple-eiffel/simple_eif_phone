note
	description: "[
		Android key codes the layer names (values from android/keycodes.h).
		Inherit it to compare `last_event.key_code' by name.
	]"
	author: "Larry Rix"

class
	PHONE_KEY_CODES

feature -- Codes

	Key_home: INTEGER = 3
	Key_back: INTEGER = 4
	Key_dpad_up: INTEGER = 19
	Key_dpad_down: INTEGER = 20
	Key_dpad_left: INTEGER = 21
	Key_dpad_right: INTEGER = 22
	Key_volume_up: INTEGER = 24
	Key_volume_down: INTEGER = 25
	Key_enter: INTEGER = 66
	Key_del: INTEGER = 67
	Key_menu: INTEGER = 82

end
