note
	description: "[
		SHELL_WINDOW for Android: simple_shell's window, with the phone in place
		of Windows. An app selects this cluster with an ECF override, and
		simple_widgets runs on it unchanged.

		The window is the screen, less the system bars. Touch arrives as the pointer events a widget
		expects, except that a finger has to mean two things. A finger that moves
		quickly is scrolling, and becomes wheel events; a tap is a press and a
		release; a finger that holds still first, and then moves, drags.
		The first touch is not passed on until one of these is known.
	]"
	author: "Larry Rix"

deferred class
	SHELL_WINDOW

inherit
	SHELL_EVENTS

	PHONE_EVENT_KIND

feature -- Access

	hwnd: POINTER
			-- Not null while the window runs. No handle stands behind it.

	phone: SIMPLE_EIF_PHONE
			-- The phone, for the app's own use as well.
		once
			create Result.make
		end

	area_top: INTEGER

	pan: INTEGER
			-- How many pixels the drawing is slid up, clear of the keyboard.
			-- How far down the screen the app's area starts, below the status bar.

	density: REAL_64
			-- Screen pixels per density-independent pixel. Give it to
			-- SW_THEME.set_text_scale, and sizes match other phones.
		do
			Result := c_density_dpi / 160.0
		ensure
			positive: Result > 0.0
		end

	c_density_dpi: INTEGER
			-- Known from the start: PHONE_METRICS waits for a window.
		external
			"C inline use %"sephone.h%""
		alias
			"return (EIF_INTEGER) sephone_metric_density();"
		end

feature -- Operation

	shell_run (a_title: READABLE_STRING_GENERAL; a_x, a_y, a_w, a_h: INTEGER)
			-- Pump Android's events until the app ends, handing each to `dispatch'.
		require
			sane_size: a_w > 0 and a_h > 0
		local
			l_next_beat, l_wait: INTEGER
		do
			hwnd := default_pointer + 1
			if heartbeat_ms = 0 then
				heartbeat_ms := 250
			end
			on_shell_open
			from
				l_next_beat := tick_ms + heartbeat_ms
			until
				phone.lifecycle.is_destroyed
			loop
				l_wait := (l_next_beat - tick_ms).max (0)
				if finger_is_undecided then
					l_wait := l_wait.min (Hold_ms)
				end
				phone.poll_event (l_wait)
				take_event (phone.last_event)
				settle_finger
				if tick_ms - l_next_beat >= 0 then
					dispatch (Event_tick, 0, 0)
					l_next_beat := tick_ms + heartbeat_ms
				end
			end
			hwnd := default_pointer
		end

	set_wants_typing (a_query: FUNCTION [TUPLE [INTEGER, INTEGER], BOOLEAN])
			-- `a_query' says whether the widget at x and y takes typing. A tap on one
			-- brings up the phone's keyboard, and a tap anywhere else puts it away.
			-- Needs `java_helper = true' in eifphone.toml.
		do
			wants_typing := a_query
		ensure
			set: wants_typing = a_query
		end

	dispatch (a_type, a_x, a_y: INTEGER)
			-- One event. The numbers are simple_shell's (SHELL_EVENTS).
		deferred
		end

	on_shell_open
			-- Hook: the window is up. Default: nothing.
		do
		end

feature -- Measurement

	event_extra: INTEGER
			-- The current event's fourth field (wheel delta).

	tick_ms: INTEGER
			-- Milliseconds of uptime.
		external
			"C inline use <time.h>"
		alias
			"struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (EIF_INTEGER)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);"
		end

	shift_is_down: BOOLEAN
		do
		end

	set_window_icon (a_ico_path: READABLE_STRING_GENERAL)
		do
		end

feature -- Visibility

	set_starts_hidden (a_on: BOOLEAN)
		do
		end

	is_window_shown: BOOLEAN
		do
			Result := phone.screen.has_window
		end

	show_window
		do
		end

	hide_window
		do
		end

feature -- Timers

	set_fast_timer (a_ms: INTEGER)
		do
		end

	kill_fast_timer
		do
		end

	set_caption (a_title: READABLE_STRING_GENERAL)
		do
		end

	close
		do
			if not phone.is_finishing and not phone.lifecycle.is_destroyed then
				phone.finish
			end
		end

feature -- Cursor

	set_cursor_kind (a_kind: INTEGER)
			-- A phone has no cursor.
		do
		end

feature -- Heartbeat

	heartbeat_ms: INTEGER

	set_heartbeat_ms (a_ms: INTEGER)
		do
			heartbeat_ms := a_ms
		end

feature -- Dwell timer

	arm_dwell_timer (a_ms: INTEGER)
		do
		end

	cancel_dwell_timer
		do
		end

	is_dwell_timer_armed: BOOLEAN
		do
		end

feature -- Appearance

	title_bar_is_dark: BOOLEAN

	set_dark_title_bar (a_dark: BOOLEAN)
		do
			title_bar_is_dark := a_dark
		end

	appearance: SHELL_APPEARANCE
		once ("OBJECT")
			create Result
		end

feature -- Element change

	set_backdrop_rgb (a_rgb: INTEGER)
			-- The color behind the system bars.
		do
			backdrop_rgb := a_rgb
		end

feature -- Services

	window_dc: POINTER
			-- What the frame is painted onto: an image, on Android. Null without a window.
		local
			l_width, l_height: INTEGER
		do
			if phone.screen.has_window then
				l_width := area_width
				l_height := area_height
				if l_width > 0 and l_height > 0 then
					if attached frame_image as al_image and then (frame_width /= l_width or frame_height /= l_height) then
						al_image.destroy
						frame_image := Void
					end
					if frame_image = Void then
						frame_image := create {CAIRO_SURFACE}.make (l_width, l_height)
						frame_width := l_width
						frame_height := l_height
					end
					if attached frame_image as al_image then
						Result := al_image.handle
					end
				end
			end
		end

	release_window_dc (a_dc: POINTER)
			-- The frame is painted: show it.
		do
			if attached frame_image as al_image and then phone.screen.has_window then
				al_image.flush.do_nothing
				phone.screen.begin_frame
				if phone.screen.in_frame then
					phone.screen.fill_rect (0, 0, phone.screen.width, area_top, backdrop_rgb)
					phone.screen.fill_rect (0, area_top + frame_height - pan, phone.screen.width,
						phone.screen.height - area_top - frame_height + pan, backdrop_rgb)
					phone.screen.present_argb_at (al_image.data + pan * al_image.stride, frame_width, frame_height - pan,
						al_image.stride, area_left, area_top)
					phone.screen.end_frame
				end
			end
		end

	add_font (a_path: READABLE_STRING_GENERAL): BOOLEAN
		do
		end

	native_text_menu (a_can_cut, a_can_copy, a_can_paste, a_can_select: BOOLEAN): INTEGER
		do
		end

	take_dropped_paths: ARRAYED_LIST [STRING_32]
		do
			create Result.make (0)
		end

feature {NONE} -- Android's events

	take_event (a_event: PHONE_EVENT)
			-- Turn `a_event' into what a window expects.
		do
			inspect a_event.kind
			when Kind_window_ready, Kind_window_resized, Kind_content_rect_changed then
				area_left := phone.metrics.content_rect.left
				area_top := phone.metrics.content_rect.top
				area_width := phone.metrics.content_rect.width
				area_height := phone.metrics.content_rect.height
				dispatch (Event_window_resize, area_width, area_height)
				dispatch (Event_window_expose, 0, 0)
			when Kind_redraw_needed then
				dispatch (Event_window_expose, 0, 0)
			when Kind_keyboard_top, Kind_keyboard_closed then
				place_for_keyboard
			when Kind_touch_down then
				if not is_finger_down then
					is_finger_down := True
					finger := a_event.pointer_id
					finger_x := a_event.x - area_left
					finger_y := a_event.y - area_top + pan
					last_y := finger_y
					finger_time := tick_ms
					finger_mode := Mode_undecided
				end
			when Kind_touch_move then
				if is_finger_down and then a_event.pointer_id = finger then
					finger_moved (a_event.x - area_left, a_event.y - area_top + pan)
				end
			when Kind_touch_up then
				if is_finger_down and then a_event.pointer_id = finger then
					if finger_mode = Mode_undecided then
						dispatch (Event_window_press, finger_x, finger_y)
						finger_mode := Mode_dragging
					end
					if finger_mode = Mode_dragging then
						dispatch (Event_window_release, a_event.x - area_left, a_event.y - area_top + pan)
					end
					is_finger_down := False
						-- A scroll can end anywhere, and says nothing about typing.
					if finger_mode /= Mode_scrolling then
						refresh_keyboard (a_event.x - area_left, a_event.y - area_top + pan)
					end
				end
			when Kind_keyboard_text then
				across a_event.text as ic loop
					dispatch (Event_window_char, ic.code, 0)
				end
			when Kind_keyboard_backspace then
				dispatch (Event_window_char, 8, 0)
			when Kind_keyboard_enter then
				dispatch (Event_window_char, 13, 0)
			when Kind_touch_cancel then
				if is_finger_down and finger_mode = Mode_dragging then
					dispatch (Event_window_release, finger_x, finger_y)
				end
				is_finger_down := False
			else
			end
		end

	finger_moved (a_x, a_y: INTEGER)
			-- The finger went to (`a_x', `a_y').
		do
			if finger_mode = Mode_undecided and then
				((a_x - finger_x).abs > Slop_pixels or (a_y - finger_y).abs > Slop_pixels)
			then
				finger_mode := Mode_scrolling
			end
			if finger_mode = Mode_scrolling then
				event_extra := (a_y - last_y) * Wheel_per_pixel
				last_y := a_y
				if event_extra /= 0 then
					dispatch (Event_window_wheel, finger_x, finger_y)
				end
			elseif finger_mode = Mode_dragging then
				dispatch (Event_window_drag, a_x, a_y)
			end
		end

	settle_finger
			-- A finger that has held still long enough is pressing.
		do
			if finger_is_undecided and then tick_ms - finger_time >= Hold_ms then
				finger_mode := Mode_dragging
				dispatch (Event_window_press, finger_x, finger_y)
			end
		end

	refresh_keyboard (a_x, a_y: INTEGER)
			-- Bring the keyboard up or put it away, to suit what was just touched at (`a_x', `a_y').
		do
			if attached wants_typing as al_query and then phone.keyboard.is_available then
				if al_query.item ([a_x, a_y]) then
					typing_y := a_y
					phone.keyboard.show
					place_for_keyboard
				elseif phone.keyboard.is_shown then
					phone.keyboard.hide
				end
			end
		end

	place_for_keyboard
			-- Slide the drawing up just enough to keep what is being typed in above the keyboard.
		local
			l_pan: INTEGER
		do
			if phone.keyboard.is_shown and phone.keyboard.top > 0 then
				l_pan := (typing_y + area_top + (Typing_room * density).truncated_to_integer - phone.keyboard.top)
					.max (0).min ((frame_height - 1).max (0))
			end
			if l_pan /= pan then
				pan := l_pan
				dispatch (Event_window_expose, 0, 0)
			end
		ensure
			in_the_frame: pan >= 0
		end

	finger_is_undecided: BOOLEAN
			-- Is a finger down, with its meaning not yet known?
		do
			Result := is_finger_down and finger_mode = Mode_undecided
		end

feature {NONE} -- Implementation

	is_finger_down: BOOLEAN
			-- Is a finger being followed? Other fingers are ignored.

	finger: INTEGER
			-- The pointer being followed.

	finger_x, finger_y, last_y, finger_time, finger_mode: INTEGER

	Typing_room: INTEGER = 56
			-- Density-independent pixels kept clear below a tap on a text box.

	typing_y: INTEGER
			-- Where in the drawing the last tap on a text box was.

	Mode_undecided: INTEGER = 0
	Mode_scrolling: INTEGER = 1
	Mode_dragging: INTEGER = 2

	Hold_ms: INTEGER = 180
			-- A finger still for this long is pressing, not starting to scroll.

	Slop_pixels: INTEGER = 24
			-- A finger that moves less than this has not moved.

	Wheel_per_pixel: INTEGER = 2
			-- Windows' wheel units for each pixel the finger moves.

	frame_image: detachable CAIRO_SURFACE
	frame_width, frame_height: INTEGER

	area_left, area_width, area_height: INTEGER
			-- The part of the screen the app has, clear of the system bars.

	backdrop_rgb: INTEGER

	wants_typing: detachable FUNCTION [TUPLE [INTEGER, INTEGER], BOOLEAN]

end
