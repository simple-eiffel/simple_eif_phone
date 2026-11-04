note
	description: "A new simple_eif_phone app: paints the screen, logs each event."

class
	APP_MAIN

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Run until Android destroys the app.
		do
			create phone.make
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				phone.log.info (phone.last_event.out_line)
				inspect phone.last_event.kind
				when Kind_window_ready, Kind_window_resized, Kind_redraw_needed then
					draw
				else
				end
			end
		end

feature {NONE} -- Implementation

	phone: SIMPLE_EIF_PHONE

	draw
			-- Paint the whole screen.
		do
			if phone.screen.has_window then
				phone.screen.begin_frame
				if phone.screen.in_frame then
					phone.screen.fill_rect (0, 0, phone.screen.width, phone.screen.height, 0x14161C)
					phone.screen.end_frame
				end
			end
		end

end
