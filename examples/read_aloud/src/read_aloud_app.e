note
	description: "[
		simple_eif_phone demo: choose a text file, and hear it read. Tap the
		top half to choose, the bottom half to read or stop. Hebrew text is
		read in Hebrew, if the phone's speech engine has it.
	]"
	author: "Larry Rix"

class
	READ_ALOUD_APP

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Run until Android destroys the app.
		do
			create phone.make
			create font
			create words.make_empty
			status := "STARTING SPEECH"
			phone.log.set_tag ("Eiffel")
			if phone.speech.is_available then
				phone.speech.start
			else
				status := "NO JAVA HELPER"
			end
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				handle
			end
		end

feature {NONE} -- Access

	phone: SIMPLE_EIF_PHONE
	font: READ_FONT

	words: STRING_32
			-- The text to read.

	status: STRING
			-- The line at the foot of the screen.

	Most_characters: INTEGER = 3900
			-- Android's speech engines refuse text of 4,000 characters or more.

feature {NONE} -- Events

	handle
			-- React to `last_event'.
		do
			inspect phone.last_event.kind
			when Kind_window_ready, Kind_window_resized, Kind_redraw_needed, Kind_content_rect_changed then
				draw
			when Kind_touch_up then
				tapped (phone.last_event.y)
				draw
			when Kind_speech_ready then
				status := "READY"
				draw
			when Kind_speech_done then
				status := "DONE"
				draw
			when Kind_speech_failed then
				status := "SPEECH FAILED: " + phone.speech.last_failure.out
				draw
			when Kind_file_picked then
				load_picked
				draw
			when Kind_file_cancelled then
				status := "NOTHING CHOSEN"
				draw
			when Kind_file_failed then
				status := "COULD NOT OPEN IT"
				draw
			else
			end
		end

	tapped (a_y: INTEGER)
			-- Top half chooses; bottom half reads or stops.
		do
			if a_y < phone.screen.height // 2 then
				if phone.files.is_available and not phone.files.is_picking then
					phone.files.pick ("text/*")
				end
			elseif phone.speech.is_speaking then
				phone.speech.stop
			elseif phone.speech.is_ready and not words.is_empty then
				status := "READING"
				phone.speech.speak (words, language_of (words))
			end
		end

	load_picked
			-- Read the chosen file into `words'.
		local
			f: RAW_FILE
		do
			if attached phone.files.last_path as al_path then
				create f.make_with_name (al_path)
				if f.exists and then f.count > 0 then
					f.open_read
					f.read_stream (f.count.min (Most_characters * 2))
					words := {UTF_CONVERTER}.utf_8_string_8_to_string_32 (f.last_string)
					f.close
					if words.count > Most_characters then
						words.keep_head (Most_characters)
					end
					status := "CHOSEN: " + words.count.out + " LETTERS"
				else
					status := "THAT FILE IS EMPTY"
				end
			end
		end

	language_of (a_text: READABLE_STRING_32): STRING
			-- "he-IL" if `a_text' has Hebrew letters, else "en-US".
		do
			Result := "en-US"
			across a_text as ic loop
				if 0x590 <= ic.code and ic.code <= 0x5FF then
					Result := "he-IL"
				end
			end
		end

feature {NONE} -- Drawing

	draw
			-- Two big buttons and a status line.
		local
			s: PHONE_SCREEN
			w, h, l_scale: INTEGER
		do
			s := phone.screen
			if s.has_window then
				s.begin_frame
				if s.in_frame then
					w := s.width
					h := s.height
					l_scale := (w // 90).max (1)
					s.fill_rect (0, 0, w, h // 2, 0x1C2433)
					s.fill_rect (0, h // 2, w, h - h // 2, 0x1F2A1E)
					centered ("CHOOSE A FILE", h // 4, l_scale, 0xF2E6C9)
					if phone.speech.is_speaking then
						centered ("STOP", h * 3 // 4, l_scale, 0xE8707A)
					else
						centered ("READ IT", h * 3 // 4, l_scale, 0x8FD18A)
					end
					centered (status, h - h // 8, (l_scale // 2).max (1), 0x7A7F8C)
					s.end_frame
				end
			end
		end

	centered (a_text: STRING; a_y, a_scale, a_rgb: INTEGER)
		do
			font.draw (phone.screen, a_text, (phone.screen.width - font.text_width (a_text, a_scale)) // 2, a_y, a_scale, a_rgb)
		end

end
