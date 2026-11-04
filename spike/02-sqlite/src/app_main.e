note
	description: "Spike 02: does simple_sql run on the phone? Logs each step under SQL-SPIKE."

class
	APP_MAIN

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Run the checks once, then wait for Android to end the app.
		do
			create phone.make
			run_checks
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				inspect phone.last_event.kind
				when Kind_window_ready, Kind_window_resized, Kind_redraw_needed then
					draw
				else
				end
			end
		end

feature {NONE} -- Implementation

	phone: SIMPLE_EIF_PHONE

	say (a_text: STRING_8)
		do
			phone.log.info ("SQL-SPIKE " + a_text)
		end

	run_checks
			-- A file database in the app's folder: write, read, search, reopen.
		local
			l_db: SIMPLE_SQL_DATABASE
			l_path: STRING_8
			l_rows: SIMPLE_SQL_RESULT
			i: INTEGER
		do
			l_path := phone.storage.internal_path + "/spike.db"
			say ("open " + l_path)
			create l_db.make (l_path)
			l_db.execute ("DROP TABLE IF EXISTS notes")
			l_db.execute ("CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)")
			l_db.execute ("BEGIN")
			from i := 1 until i > 1000 loop
				l_db.execute ("INSERT INTO notes (body) VALUES ('note number " + i.out + "')")
				i := i + 1
			end
			l_db.execute ("COMMIT")
			l_rows := l_db.query ("SELECT COUNT(*) AS n FROM notes")
			if l_rows.count = 1 then
				say ("rows " + l_rows.first.integer_value ("n").out)
			end
			l_db.execute ("DROP TABLE IF EXISTS finder")
			l_db.execute ("CREATE VIRTUAL TABLE finder USING fts5 (body)")
			l_db.execute ("INSERT INTO finder (body) VALUES ('In the beginning God created')")
			l_rows := l_db.query ("SELECT COUNT(*) AS n FROM finder WHERE finder MATCH 'beginning'")
			if l_rows.count = 1 then
				say ("fts5 " + l_rows.first.integer_value ("n").out)
			end
			if l_db.has_error and then attached l_db.last_error_message as al_message then
				say ("error " + al_message.to_string_8)
			end
			l_db.close
			create l_db.make_read_only (l_path)
			l_rows := l_db.query ("SELECT body FROM notes WHERE id = 1000")
			if l_rows.count = 1 then
				say ("reopened " + l_rows.first.string_value ("body").to_string_8)
			end
			l_db.close
			say ("done")
		end

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
