note
	description: "[
		Drawing on a PHONE_CANVAS, through Android's own Canvas: smooth lines, and
		text in any script. Measures are density-independent pixels. Colors are
		0xRRGGBB. A canvas hands this to its `on_paint' agent, between frames only.
	]"
	author: "Larry Rix"

deferred class
	PHONE_PAINTER

feature -- Status

	is_drawing: BOOLEAN
			-- Is a frame open?
		deferred
		end

feature -- Frames

	start_frame (a_canvas, a_background: INTEGER)
			-- Open a frame on canvas `a_canvas', cleared to `a_background'.
			-- `is_drawing' stays False if the canvas has gone away.
		require
			not_drawing: not is_drawing
		deferred
		end

	finish_frame
			-- Show the frame.
		require
			drawing: is_drawing
		deferred
		ensure
			closed: not is_drawing
		end

feature -- Drawing

	set_color (a_rgb: INTEGER)
		require
			drawing: is_drawing
			valid: a_rgb >= 0 and a_rgb <= 0xFFFFFF
		deferred
		end

	fill_rect (a_x, a_y, a_width, a_height: REAL_64)
		require
			drawing: is_drawing
		deferred
		end

	line (a_x1, a_y1, a_x2, a_y2, a_width: REAL_64)
		require
			drawing: is_drawing
			width_positive: a_width > 0.0
		deferred
		end

	text (a_x, a_y: REAL_64; a_text: READABLE_STRING_32; a_size: REAL_64; a_bold: BOOLEAN)
			-- Draw `a_text' with its baseline at `a_y'.
		require
			drawing: is_drawing
			size_positive: a_size > 0.0
		deferred
		end

end
