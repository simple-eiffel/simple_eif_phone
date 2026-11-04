note
	description: "[
		A place to draw and to take a finger's path. Android's SurfaceView, painted
		through Android's Canvas. Everything is repainted in `on_paint', so keep
		what must stay on screen in the app. Measures are density-independent pixels.
	]"
	author: "Larry Rix"

class
	PHONE_CANVAS

inherit
	PHONE_CONTROL
		redefine
			handle_own
		end

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_control (a_controls, Control_canvas, Void)
			background := 0xFFFFFF
		ensure
			mine: controls = a_controls
			not_ready: not is_ready
		end

feature -- Access

	width, height: INTEGER
			-- Size, once `is_ready'.

	background: INTEGER
			-- 0xRRGGBB, cleared to before each paint.

	is_ready: BOOLEAN
			-- Is the surface there to draw on?

	on_paint: detachable PROCEDURE [TUPLE [PHONE_PAINTER, INTEGER, INTEGER]]
			-- Draws everything: painter, width, height.

	on_press, on_sweep, on_release: detachable PROCEDURE [TUPLE [REAL_64, REAL_64]]
			-- The finger came down, moved, or lifted, at x and y.

	is_repaint_waiting: BOOLEAN
			-- Has `request_repaint' been called since the last paint?

feature -- Element change

	set_background (a_rgb: INTEGER)
		require
			valid: a_rgb >= 0 and a_rgb <= 0xFFFFFF
		do
			background := a_rgb
		ensure
			set: background = a_rgb
		end

	set_on_paint (a_action: PROCEDURE [TUPLE [PHONE_PAINTER, INTEGER, INTEGER]])
		do
			on_paint := a_action
		ensure
			set: on_paint = a_action
		end

	set_on_press (a_action: PROCEDURE [TUPLE [REAL_64, REAL_64]])
		do
			on_press := a_action
		ensure
			set: on_press = a_action
		end

	set_on_sweep (a_action: PROCEDURE [TUPLE [REAL_64, REAL_64]])
		do
			on_sweep := a_action
		ensure
			set: on_sweep = a_action
		end

	set_on_release (a_action: PROCEDURE [TUPLE [REAL_64, REAL_64]])
		do
			on_release := a_action
		ensure
			set: on_release = a_action
		end

feature -- Commands

	request_repaint
			-- Draw once the events now waiting are done, however many ask.
			-- A finger sends far more points than a screen can show.
		do
			if not is_repaint_waiting then
				is_repaint_waiting := True
				controls.note_repaint (Current)
			end
		ensure
			waiting: is_repaint_waiting
		end

	repaint
			-- Draw now, if the surface is there.
		local
			l_painter: PHONE_PAINTER
		do
			is_repaint_waiting := False
			if is_ready and then attached on_paint as al_paint then
				l_painter := controls.port.painter
				l_painter.start_frame (id, background)
				if l_painter.is_drawing then
					al_paint.call ([l_painter, width, height])
					l_painter.finish_frame
				end
			end
		end

feature {NONE} -- Implementation

	handle_own (a_event: PHONE_EVENT)
		do
			inspect a_event.kind
			when Kind_control_canvas_ready then
				is_ready := True
				width := controls.to_pixels (a_event.x)
				height := controls.to_pixels (a_event.y)
				repaint
			when Kind_control_canvas_lost then
				is_ready := False
			when Kind_control_pressed then
				finger (on_press, a_event)
			when Kind_control_swept then
				finger (on_sweep, a_event)
			when Kind_control_released then
				finger (on_release, a_event)
			else
			end
		end

	finger (a_action: detachable PROCEDURE [TUPLE [REAL_64, REAL_64]]; a_event: PHONE_EVENT)
			-- Report the finger's place to `a_action'.
		do
			if attached a_action as al_action then
				al_action.call ([controls.to_measure (a_event.x), controls.to_measure (a_event.y)])
			end
		end

invariant
	size_non_negative: width >= 0 and height >= 0

end
