note
	description: "[
		On-device tests of simple_eif_phone. Every contract in the library
		is live here, so a violation anywhere fails the run (the process dies
		before END, and `eifphone test' reports it).
		Steps marked "driven" wait for drive.sh to act (tap, Home, rotate, Back).
	]"
	author: "Larry Rix"

class
	PHONE_TESTS_APP

inherit
	PHONE_EVENT_KIND

	PHONE_KEY_CODES

create
	make

feature {NONE} -- Initialization

	make
		do
			create phone.make
			create seen.make (32)
			create t.make (phone.log)
			wait_for (Kind_focus_gained, 30_000)
			t.begin (Total)
				-- Self-contained checks.
			t.run ("startup_order", agent startup_order)
			t.run ("metrics_sane", agent metrics_sane)
			t.run ("fill_byte_order", agent fill_byte_order)
			t.run ("present_byte_order", agent present_byte_order)
			t.run ("present_full_screen_time", agent present_full_screen_time)
			t.run ("storage_round_trip", agent storage_round_trip)
			t.run ("sql_round_trip", agent sql_round_trip)
			t.run ("sql_full_text", agent sql_full_text)
			t.run ("sql_hebrew_text", agent sql_hebrew_text)
			t.run ("asset_read", agent asset_read)
			t.run ("asset_missing", agent asset_missing)
			t.run ("asset_in_folder", agent asset_in_folder)
			t.run ("asset_copied", agent asset_copied)
			t.run ("install_stamp_known", agent install_stamp_known)
			t.run ("back_policy_round_trip", agent back_policy_round_trip)
			t.run ("keep_screen_on", agent keep_screen_on_flag)
			t.run ("poll_timeout", agent poll_timeout)
			t.run ("queue_overflow", agent queue_overflow)
			t.run ("rescue_after_violation", agent rescue_after_violation)
				-- Driven checks.
			t.run ("tap_arrives", agent tap_arrives)
			t.run ("home_and_return", agent home_and_return)
			t.run ("rotation", agent rotation)
			t.run ("window_storm", agent window_storm)
			t.run ("java_helper_present", agent java_helper_present)
			t.run ("speech_answers", agent speech_answers)
			t.run ("speech_language_refused", agent speech_language_refused)
			t.run ("speech_stop_ends_it", agent speech_stop_ends_it)
			t.run ("file_pick_cancelled", agent file_pick_cancelled)
			t.run ("file_pick_chosen", agent file_pick_chosen)
			t.run ("back_policy_app", agent back_policy_app)
			t.finish
				-- Back under the system policy: `destroyed' must arrive cleanly.
			t.step ("exit")
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
			end
			phone.log.info ("tests: destroyed delivered cleanly")
		end

feature {NONE} -- Access

	phone: SIMPLE_EIF_PHONE
	t: PHONE_TEST_LOG
	seen: ARRAYED_LIST [INTEGER]
			-- Kinds delivered so far by `wait_for'.

	Total: INTEGER = 30

feature {NONE} -- Self-contained tests

	rescue_after_violation: BOOLEAN
			-- Contract violations are caught by rescue and retry, again and
			-- again, with locals intact (the build's jump is sephone_fastjmp.h).
		local
			i, l_caught: INTEGER
		do
			from i := 1 until i > 1000 loop
				if caught_violation (i) = i then
					l_caught := l_caught + 1
				end
				i := i + 1
			end
			phone.log.info ("measure rescue: caught " + l_caught.out + " of 1000")
			Result := l_caught = 1000
		end

	caught_violation (a_value: INTEGER): INTEGER
			-- `a_value', reached only by way of a caught precondition violation.
		local
			l_retried: BOOLEAN
		do
			if l_retried then
				Result := a_value
			else
				must_be_positive (-a_value)
			end
		rescue
			l_retried := True
			retry
		end

	must_be_positive (a_number: INTEGER)
			-- Nothing, for a positive `a_number'.
		require
			positive: a_number > 0
		do
		end

	startup_order: BOOLEAN
			-- started, then resumed, then window_ready.
		local
			a, b, c: INTEGER
		do
			a := seen.index_of (Kind_started, 1)
			b := seen.index_of (Kind_resumed, 1)
			c := seen.index_of (Kind_window_ready, 1)
			Result := 0 < a and a < b and b < c
		end

	metrics_sane: BOOLEAN
			-- Window, density and the content rectangle make sense.
		local
			m: PHONE_METRICS
		do
			m := phone.metrics
			phone.log.info ("metrics " + m.width.out + "x" + m.height.out + " dpi=" + m.density_dpi.out
				+ " insets=" + m.inset_left.out + "," + m.inset_top.out + "," + m.inset_right.out + "," + m.inset_bottom.out)
			Result := m.width > 0 and m.height > 0 and m.density_dpi >= 120
				and m.content_rect.width > 0 and m.content_rect.height > 0 and m.dp (160) = m.density_dpi
				and m.inset_top > 0 and m.inset_bottom > 0
				and m.content_rect.height = m.height - m.inset_top - m.inset_bottom
		end

	fill_byte_order: BOOLEAN
			-- 0xRRGGBB reaches the buffer as R,G,B bytes.
		do
			phone.screen.begin_frame
			if phone.screen.in_frame then
				phone.screen.fill_rect (0, 0, 4, 4, 0x112233)
				Result := phone.screen.peek (1, 1) & 0xFFFFFF = 0x332211
				phone.screen.end_frame
			end
		end

	present_byte_order: BOOLEAN
			-- A cairo-style ARGB32 word 0xFFAABBCC reaches the buffer as R,G,B bytes.
		local
			m: MANAGED_POINTER
		do
			create m.make (4 * 4)
			m.put_natural_32 (0xFFAABBCC, 0)
			phone.screen.begin_frame
			if phone.screen.in_frame then
				phone.screen.present_argb (m.item, 1, 1, 16)
				Result := phone.screen.peek (0, 0) & 0xFFFFFF = 0xCCBBAA
				phone.screen.end_frame
			end
		end

	present_full_screen_time: BOOLEAN
			-- NFR-001: logs the time for one full-screen copy; passes if it ran.
		local
			m: MANAGED_POINTER
			w, h, i, p: INTEGER
			l_start, l_copy, l_lock, l_t: INTEGER_64
			l_last_ok: BOOLEAN
		do
			w := phone.screen.width
			h := phone.screen.height
			create m.make (w * h * 4)
				-- Real pixels, so the copy reads memory, not untouched zero pages.
			from p := 0 until p >= w * h * 4 loop
				m.put_natural_32 ({NATURAL_32} 0xFF102030 + ((p // 4) \\ 256).to_natural_32, p)
				p := p + 4
			end
			m.put_natural_32 (0xFFAABBCC, (w * h - 1) * 4)
			l_start := now_us
			from i := 1 until i > 20 loop
				l_t := now_us
				phone.screen.begin_frame
				l_lock := l_lock + now_us - l_t
				if phone.screen.in_frame then
					l_t := now_us
					phone.screen.present_argb (m.item, w, h, w * 4)
					l_copy := l_copy + now_us - l_t
					l_last_ok := phone.screen.peek (w - 1, h - 1) & 0xFFFFFF = 0xCCBBAA
					phone.screen.end_frame
				end
				i := i + 1
			end
			phone.log.info ("measure full-screen " + w.out + "x" + h.out + " over 20 frames: copy "
				+ (l_copy // 20).out + " us, lock wait " + (l_lock // 20).out + " us, whole frame "
				+ ((now_us - l_start) // 20).out + " us")
			Result := l_last_ok
		end

	storage_round_trip: BOOLEAN
			-- A file written under `internal_path' reads back.
		local
			f: PLAIN_TEXT_FILE
			l_path: STRING
		do
			l_path := phone.storage.internal_path + "/round_trip.txt"
			create f.make_create_read_write (l_path)
			f.put_string ("eiffel on the phone")
			f.close
			create f.make_open_read (l_path)
			f.read_line
			Result := f.last_string.same_string ("eiffel on the phone")
			f.close
			f.delete
		end

	sql_path: STRING_8
			-- A database file in the app's own folder.
		do
			Result := phone.storage.internal_path + "/sql_test.db"
		end

	sql_round_trip: BOOLEAN
			-- 1,000 rows in one transaction survive closing and reopening the file.
		local
			l_db: SIMPLE_SQL_DATABASE
			l_rows: SIMPLE_SQL_RESULT
			i: INTEGER
		do
			create l_db.make (sql_path)
			l_db.execute ("DROP TABLE IF EXISTS notes")
			l_db.execute ("CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)")
			l_db.execute ("BEGIN")
			from i := 1 until i > 1000 loop
				l_db.execute ("INSERT INTO notes (body) VALUES ('note " + i.out + "')")
				i := i + 1
			end
			l_db.execute ("COMMIT")
			l_db.close
			create l_db.make_read_only (sql_path)
			l_rows := l_db.query ("SELECT body FROM notes WHERE id = 1000")
			Result := l_rows.count = 1 and then l_rows.first.string_value ("body").same_string_general ("note 1000")
			l_rows := l_db.query ("SELECT COUNT(*) AS n FROM notes")
			Result := Result and then l_rows.first.integer_value ("n") = 1000
			l_db.close
		end

	sql_full_text: BOOLEAN
			-- FTS5 finds a word, and does not find one that is absent.
		local
			l_db: SIMPLE_SQL_DATABASE
		do
			create l_db.make (sql_path)
			l_db.execute ("DROP TABLE IF EXISTS finder")
			l_db.execute ("CREATE VIRTUAL TABLE finder USING fts5 (body)")
			l_db.execute ("INSERT INTO finder (body) VALUES ('In the beginning God created')")
			Result := l_db.query ("SELECT body FROM finder WHERE finder MATCH 'beginning'").count = 1
				and then l_db.query ("SELECT body FROM finder WHERE finder MATCH 'absent'").count = 0
				and then not l_db.has_error
			l_db.close
		end

	sql_hebrew_text: BOOLEAN
			-- Hebrew goes in as UTF-8 and comes back as the same characters.
		local
			l_db: SIMPLE_SQL_DATABASE
			l_word: STRING_32
			l_rows: SIMPLE_SQL_RESULT
		do
			create l_word.make_empty
			across <<0x5D1, 0x5E8, 0x5D0, 0x5E9, 0x5D9, 0x5EA>> as ic loop
				l_word.append_code (ic.to_natural_32)
			end
			create l_db.make (sql_path)
			l_db.execute ("DROP TABLE IF EXISTS words")
			l_db.execute ("CREATE TABLE words (body TEXT)")
			l_db.execute ("INSERT INTO words (body) VALUES ('" + {UTF_CONVERTER}.utf_32_string_to_utf_8_string_8 (l_word) + "')")
			l_rows := l_db.query ("SELECT body, length (body) AS n FROM words")
			Result := l_rows.count = 1 and then l_rows.first.integer_value ("n") = 6
				and then l_rows.first.string_value ("body").same_string (l_word)
			l_db.close
		end

	asset_read: BOOLEAN
			-- assets/test.txt reads back byte for byte.
		local
			a: PHONE_ASSETS
		do
			a := phone.assets
			a.read_asset ("test.txt")
			if attached a.last_asset as al_d then
				Result := a.last_asset_size = 12 and then al_d.read_natural_8 (0) = ('e').code.to_natural_8
					and then al_d.read_natural_8 (11) = ('e').code.to_natural_8
			end
		end

	asset_in_folder: BOOLEAN
			-- assets/sub/nested.txt is found by its forward-slash name.
		do
			Result := phone.assets.has_asset ("sub/nested.txt")
		end

	asset_copied: BOOLEAN
			-- A copy lands whole, with its progress reaching the end, and leaves no part file.
		local
			l_target: STRING_8
			l_file: RAW_FILE
			l_last: CELL [REAL_64]
		do
			l_target := phone.storage.internal_path + "/copied.txt"
			create l_last.put (0.0)
			phone.copy_asset ("test.txt", l_target, agent (a_cell: CELL [REAL_64]; a_at: REAL_64) do a_cell.put (a_at) end (l_last, ?))
			create l_file.make_with_name (l_target)
			Result := not phone.assets.copy_failed and l_file.exists and then l_file.count = 12
				and l_last.item = 1.0 and not (create {RAW_FILE}.make_with_name (l_target + ".part")).exists
			if l_file.exists then
				l_file.delete
			end
		end

	install_stamp_known: BOOLEAN
			-- The stamp is there, and the same when read twice.
		do
			Result := not phone.assets.install_stamp.is_empty
				and phone.assets.install_stamp.same_string (phone.assets.install_stamp)
		end

	asset_missing: BOOLEAN
			-- A missing asset is a normal Void, not an error.
		do
			phone.assets.read_asset ("no_such_file.txt")
			Result := phone.assets.last_asset = Void and not phone.assets.has_asset ("no_such_file.txt")
				and phone.assets.has_asset ("test.txt")
		end

	back_policy_round_trip: BOOLEAN
		do
			phone.set_back_policy (phone.Back_app)
			Result := phone.back_policy = phone.Back_app
			phone.set_back_policy (phone.Back_system)
			Result := Result and phone.back_policy = phone.Back_system
		end

	keep_screen_on_flag: BOOLEAN
		do
			phone.set_keep_screen_on (True)
			Result := phone.keep_screen_on
			phone.set_keep_screen_on (False)
			Result := Result and not phone.keep_screen_on
		end

	poll_timeout: BOOLEAN
			-- A timed poll with nothing queued returns close to its timeout.
			-- An event may cut a poll short, so try until one really times out.
		local
			l_start, l_took: INTEGER_64
			i: INTEGER
			l_timed_out: BOOLEAN
		do
			from i := 1 until l_timed_out or i > 50 loop
				drain
				l_start := now_ms
				phone.poll_event (200)
				l_took := now_ms - l_start
				l_timed_out := phone.last_event.is_none
				record
				i := i + 1
			end
			phone.log.info ("measure poll 200 ms took " + l_took.out + " ms (try " + (i - 1).out + ")")
			Result := l_timed_out and 195 <= l_took and l_took <= 230
		end

	queue_overflow: BOOLEAN
			-- DR-005: flood the queue; key and lifecycle events survive, drops are counted.
		local
			i, l_keys, l_low, l_before: INTEGER
		do
			drain
			l_before := phone.dropped_event_count
				-- A key event first, then far more moves than the queue holds, then a lifecycle event.
			c_test_push (Kind_key_down, -1, 0, 0, Key_volume_up)
			from i := 1 until i > 1500 loop
				c_test_push (Kind_touch_move, 5, i, i, 0)
				c_test_push (Kind_touch_move, 6, i, i, 0)
				i := i + 1
			end
			c_test_push (Kind_low_memory, -1, 0, 0, 0)
			from
				phone.poll_event (0)
			until
				phone.last_event.is_none
			loop
				if phone.last_event.kind = Kind_key_down then l_keys := l_keys + 1 end
				if phone.last_event.kind = Kind_low_memory then l_low := l_low + 1 end
				phone.poll_event (0)
			end
			phone.log.info ("measure overflow: dropped " + (phone.dropped_event_count - l_before).out + ", capacity " + c_test_capacity.out)
			Result := l_keys = 1 and l_low = 1 and phone.dropped_event_count > l_before
				-- With no moves to drop, the queue must grow: every lifecycle event survives.
			l_low := 0
			from i := 1 until i > 1500 loop
				c_test_push (Kind_low_memory, -1, 0, 0, 0)
				i := i + 1
			end
			from
				phone.poll_event (0)
			until
				phone.last_event.is_none
			loop
				if phone.last_event.kind = Kind_low_memory then l_low := l_low + 1 end
				phone.poll_event (0)
			end
			phone.log.info ("measure growth: delivered " + l_low.out + " of 1500, capacity " + c_test_capacity.out)
			Result := Result and l_low = 1500 and c_test_capacity > 1024
		end

feature {NONE} -- Driven tests

	java_helper_present: BOOLEAN
			-- This app carries the helper, so both services are on offer.
		do
			Result := phone.speech.is_available and phone.files.is_available
		end

	wait_any (a_first, a_second, a_ms: INTEGER)
			-- Take events until a new one of two kinds arrives, or `a_ms' of quiet has passed.
			-- `last_event' on entry does not count: it is the answer to something earlier.
		local
			l_left: INTEGER
			l_seen: BOOLEAN
		do
			from
				l_left := a_ms
			until
				l_left <= 0 or l_seen
			loop
				phone.poll_event (200)
				if phone.last_event.is_none then
					l_left := l_left - 200
				else
					l_seen := phone.last_event.kind = a_first or phone.last_event.kind = a_second
				end
			end
		end

	speech_answers: BOOLEAN
			-- The engine answers either way. If there is one, it reads a line to the end.
		do
			phone.speech.start
			wait_any (Kind_speech_ready, Kind_speech_failed, 30_000)
			if phone.speech.is_ready then
				phone.log.info ("tests: speech engine ready")
				phone.speech.speak ({STRING_32} "one two three", "en-US")
				wait_any (Kind_speech_done, Kind_speech_failed, 30_000)
				phone.log.info ("tests: speech ended, failure code " + phone.speech.last_failure.out)
				Result := not phone.speech.is_speaking
			else
				phone.log.info ("tests: no speech engine, failure code " + phone.speech.last_failure.out)
				Result := phone.speech.last_failure = phone.speech.Failure_no_engine
			end
		end

	speech_language_refused: BOOLEAN
			-- A language the engine lacks is a named failure, and the engine stays usable.
		do
			if phone.speech.is_ready then
				phone.speech.speak ({STRING_32} "one", "zz-ZZ")
				wait_any (Kind_speech_failed, Kind_speech_done, 15_000)
				phone.log.info ("tests: refused language gave failure code " + phone.speech.last_failure.out)
				Result := phone.speech.last_failure = phone.speech.Failure_language
					and phone.speech.is_ready and not phone.speech.is_speaking
			else
				Result := True
			end
		end

	speech_stop_ends_it: BOOLEAN
			-- `stop' ends a long utterance, and says it was stopped.
		do
			if phone.speech.is_ready then
				phone.speech.speak ({STRING_32} "This sentence is long enough that there is plenty of time to stop it before it reaches its end, and then some more words after that.", "en-US")
				phone.poll_event (300)
				phone.speech.stop
				wait_any (Kind_speech_done, Kind_speech_failed, 15_000)
				phone.log.info ("tests: stop gave code " + phone.last_event.service_code.out)
				Result := phone.last_event.kind = Kind_speech_done and phone.last_event.service_code = phone.speech.Done_stopped
					and not phone.speech.is_speaking
			else
				Result := True
			end
		end

	file_pick_cancelled: BOOLEAN
			-- Backing out of the picker is an answer, not a hang.
		do
			phone.files.pick ("*/*")
			t.step ("pickcancel")
			wait_any (Kind_file_cancelled, Kind_file_failed, 40_000)
			Result := phone.files.was_cancelled and not phone.files.is_picking
			wait_for (Kind_focus_gained, 10_000)
		end

	file_pick_chosen: BOOLEAN
			-- A chosen file arrives as a plain file holding the same text.
		local
			f: PLAIN_TEXT_FILE
		do
			phone.files.pick ("*/*")
			t.step ("pickchoose")
			wait_any (Kind_file_picked, Kind_file_failed, 60_000)
			if attached phone.files.last_path as al_path then
				phone.log.info ("tests: picked " + al_path.to_string_8)
				create f.make_with_name (al_path)
				if f.exists then
					f.open_read
					f.read_line
					Result := f.last_string.same_string ("eifphone pick test")
					f.close
				end
			else
				phone.log.info ("tests: pick error " + phone.files.last_error.to_string_8)
			end
			wait_for (Kind_focus_gained, 10_000)
		end

	tap_arrives: BOOLEAN
			-- A tap gives down, then up, with one id, and the finger is gone after.
		do
			t.step ("tap")
			wait_for (Kind_touch_down, 30_000)
			Result := phone.last_event.kind = Kind_touch_down and phone.touches.count = 1
			wait_for (Kind_touch_up, 5_000)
			Result := Result and phone.last_event.kind = Kind_touch_up and phone.touches.count = 0
		end

	home_and_return: BOOLEAN
			-- Home stops the app; returning restores the window as a new generation.
		local
			g: INTEGER
		do
			g := phone.lifecycle.window_generation
			t.step ("home")
			wait_for (Kind_stopped, 30_000)
			Result := not phone.lifecycle.is_started and not phone.lifecycle.has_window
			wait_for (Kind_focus_gained, 30_000)
			Result := Result and phone.lifecycle.is_resumed and phone.lifecycle.has_window
				and phone.lifecycle.window_generation = g + 1
		end

	rotation: BOOLEAN
			-- With configChanges the window resizes in place, same generation.
		local
			w, h, g: INTEGER
		do
			w := phone.metrics.width
			h := phone.metrics.height
			g := phone.lifecycle.window_generation
			t.step ("rotate")
			wait_for (Kind_window_resized, 30_000)
			wait_for (Kind_redraw_needed, 5_000)
			phone.log.info ("rotated " + phone.metrics.width.out + "x" + phone.metrics.height.out
				+ " content " + phone.metrics.content_rect.width.out + "x" + phone.metrics.content_rect.height.out)
			Result := phone.lifecycle.window_generation = g and phone.metrics.width = h and phone.metrics.height = w
			t.step ("unrotate")
			wait_for (Kind_window_resized, 30_000)
			wait_for (Kind_redraw_needed, 5_000)
			Result := Result and phone.metrics.width = w
		end

	window_storm: BOOLEAN
			-- G-1: a burst of Home/return and rotations; `services_consistent'
			-- is checked on every delivery, so surviving is the test.
		local
			l_start: INTEGER_64
		do
			t.step ("storm")
			l_start := now_ms
			from until now_ms - l_start > 12_000 loop
				phone.poll_event (100)
				record
				if phone.screen.has_window then
					phone.screen.begin_frame
					if phone.screen.in_frame then
						phone.screen.fill_rect (0, 0, 8, 8, 0x223344)
						phone.screen.end_frame
					end
				end
			end
			wait_for (Kind_focus_gained, 15_000)
			Result := phone.lifecycle.is_resumed
		end

	back_policy_app: BOOLEAN
			-- Under Back_app the key reaches Eiffel and the app stays alive.
		do
			phone.set_back_policy (phone.Back_app)
			t.step ("back")
			wait_for (Kind_key_up, 30_000)
			Result := phone.last_event.kind = Kind_key_up and phone.last_event.key_code = Key_back
				and not phone.lifecycle.is_destroyed
			phone.poll_event (500)
			Result := Result and phone.lifecycle.is_resumed
			phone.set_back_policy (phone.Back_system)
		end

feature {NONE} -- Helpers

	wait_for (a_kind, a_timeout_ms: INTEGER)
			-- Pull events until one of `a_kind' arrives, or `a_timeout_ms' passes.
		local
			l_start: INTEGER_64
			l_found: BOOLEAN
		do
			l_start := now_ms
			from until l_found or now_ms - l_start > a_timeout_ms loop
				phone.poll_event (100)
				record
				l_found := phone.last_event.kind = a_kind
			end
		end

	record
			-- Note `last_event', and repaint when Android asks.
		do
			if not phone.last_event.is_none then
				seen.extend (phone.last_event.kind)
				if phone.last_event.kind = Kind_window_ready or phone.last_event.kind = Kind_redraw_needed then
					paint
				end
			end
		end

	paint
			-- Keep the window drawn so Android counts it as shown.
		do
			if phone.screen.has_window then
				phone.screen.begin_frame
				if phone.screen.in_frame then
					phone.screen.fill_rect (0, 0, phone.screen.width, phone.screen.height, 0x14161C)
					phone.screen.end_frame
				end
			end
		end

	drain
			-- Take everything already queued.
		do
			from phone.poll_event (0) until phone.last_event.is_none loop
				record
				phone.poll_event (0)
			end
		end

	now_ms: INTEGER_64
			-- Milliseconds on a steady clock.
		external
			"C inline use <time.h>"
		alias
			"struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (EIF_INTEGER_64) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;"
		end

	now_us: INTEGER_64
			-- Microseconds on a steady clock.
		external
			"C inline use <time.h>"
		alias
			"struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (EIF_INTEGER_64) ts.tv_sec * 1000000 + ts.tv_nsec / 1000;"
		end

	c_test_push (a_kind, a_id, a_x, a_y, a_code: INTEGER)
		external
			"C inline use %"sephone.h%""
		alias
			"sephone_test_push((int)$a_kind, (int)$a_id, (int)$a_x, (int)$a_y, (int)$a_code);"
		end

	c_test_capacity: INTEGER
		external
			"C inline use %"sephone.h%""
		alias
			"return (EIF_INTEGER) sephone_test_capacity();"
		end

end
