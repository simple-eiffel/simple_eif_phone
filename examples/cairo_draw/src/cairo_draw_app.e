note
	description: "[
		simple_cairo on the phone: the same library the PC uses, drawing into an
		image, and the image going to the window. Draw with a finger: every stroke
		is a smooth cairo path. Track 1 of the phone's two kinds of screen.
	]"
	author: "Larry Rix"

class
	CAIRO_DRAW_APP

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
		do
			create phone.make
			phone.log.set_tag ("Eiffel")
			create cairo.make
			create points.make (256)
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				inspect phone.last_event.kind
				when Kind_window_ready, Kind_redraw_needed, Kind_window_resized then
					paint
				when Kind_touch_down then
					points.extend ([phone.last_event.x.to_double, phone.last_event.y.to_double, False])
				when Kind_touch_move then
					points.extend ([phone.last_event.x.to_double, phone.last_event.y.to_double, True])
					paint
				when Kind_touch_up then
					paint
					phone.log.info ("cairo: stroke done, " + points.count.out + " points")
				else
				end
			end
		end

feature {NONE} -- Drawing

	paint
			-- Draw everything into an image, and show the image.
		local
			l_surface: CAIRO_SURFACE
			l_context: CAIRO_CONTEXT
			l_gradient: CAIRO_GRADIENT
			l_width, l_height, i: INTEGER
		do
			if phone.screen.has_window then
				l_width := phone.screen.width
				l_height := phone.screen.height
				if l_width > 0 and l_height > 0 then
					l_surface := cairo.create_surface (l_width, l_height)
					l_context := cairo.create_context (l_surface)
					create l_gradient.make_linear (0, 0, 0, l_height)
					l_gradient.add_stop_rgb (0.0, 0.10, 0.16, 0.32).do_nothing
					l_gradient.add_stop_rgb (1.0, 0.45, 0.20, 0.45).do_nothing
					l_context.set_gradient (l_gradient).paint.do_nothing
					l_context.set_color_rgba (1.0, 0.85, 0.3, 0.8).fill_circle (l_width * 0.7, l_height * 0.2, l_width * 0.14).do_nothing
					l_context.set_color_rgba (0.3, 0.8, 1.0, 0.5).rounded_rectangle (l_width * 0.1, l_height * 0.35, l_width * 0.8, l_height * 0.1, 40).fill.do_nothing
					l_context.set_color_rgb (1, 1, 1).set_line_width (6)
						.move_to (l_width * 0.1, l_height * 0.6)
						.curve_to (l_width * 0.4, l_height * 0.45, l_width * 0.6, l_height * 0.75, l_width * 0.9, l_height * 0.6)
						.stroke.do_nothing
					l_context.select_font ("sans", 0, 0).set_font_size (70).move_to (60, 230).show_text ("simple_cairo").do_nothing
					l_context.set_color_rgb (1.0, 0.3, 0.3).set_line_width (14).set_line_cap (1).set_line_join (1).do_nothing
					from i := 1 until i > points.count loop
						if points [i].joined then
							l_context.line_to (points [i].x, points [i].y).do_nothing
						else
							l_context.stroke.do_nothing
							l_context.move_to (points [i].x, points [i].y).do_nothing
						end
						i := i + 1
					end
					l_context.stroke.do_nothing
					l_surface.flush.do_nothing
					phone.screen.begin_frame
					if phone.screen.in_frame then
						phone.screen.present_argb (l_surface.data, l_width, l_height, l_surface.stride)
						phone.screen.end_frame
					end
					l_context.destroy
					l_gradient.destroy
					l_surface.destroy
				end
			end
		end

feature {NONE} -- Implementation

	phone: SIMPLE_EIF_PHONE
	cairo: SIMPLE_CAIRO
	points: ARRAYED_LIST [TUPLE [x, y: REAL_64; joined: BOOLEAN]]

end
