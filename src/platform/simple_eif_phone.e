note
	description: "[
		The app's one handle on the phone. Eiffel owns the loop:
		`wait_for_event' / `poll_event' deliver `last_event', and before
		they return, `lifecycle' and `touches' have already applied it.
		There are no callbacks into Eiffel: the C glue queues, Eiffel pulls.
		One handle per process; when the app's root returns, the glue
		finishes the activity and ends the process (research D-012).
	]"
	author: "Larry Rix"

class
	SIMPLE_EIF_PHONE

inherit
	PHONE_EVENT_KIND

inherit {NONE}
	PHONE_NATIVE

create
	make

feature {NONE} -- Initialization

	make
			-- Claim the platform for this process.
		require
			first_handle: not handle_exists
		do
			c_handle_claim
			c_set_back_policy (Back_system)
			create last_event.make_none
			create lifecycle.make
			create touches.make
			create screen.make
			create metrics.make
			create storage.make
			create assets.make
			create log.make
			create speech.make
			create files.make
			create keyboard.make
			create controls.make (create {PHONE_CONTROL_LINK}.make)
		ensure
			claimed: handle_exists
			nothing_yet: last_event.is_none
			back_default: back_policy = Back_system
			screen_default: not keep_screen_on
			not_finishing: not is_finishing
		end

feature -- Constants

	Back_system: INTEGER = 0
			-- Android also handles Back (finishes the app); the key is still delivered.

	Back_app: INTEGER = 1
			-- Back is consumed; only the app reacts.

feature -- Events

	wait_for_event
			-- Block until an event arrives; it becomes `last_event'.
		require
			not_destroyed: not lifecycle.is_destroyed
			no_open_frame: not screen.in_frame
		local
			l_ready: INTEGER
		do
			l_ready := c_wait (-1)
			check ready: l_ready = 1 end
			deliver
		ensure
			delivered: not last_event.is_none
			counted: delivery_count = old delivery_count + 1
			fresh_event: last_event /= old last_event
			kind_from_c: last_event.kind = c_cur_kind
			lifecycle_in_step: lifecycle.last_applied = last_event
			touches_in_step: touches.last_applied = last_event
			metrics_refreshed: is_metric_kind (last_event.kind) implies
				(metrics.width = screen.width and metrics.height = screen.height)
			drops_monotonic: dropped_event_count >= old dropped_event_count
		end

	poll_event (a_timeout_ms: INTEGER)
			-- Wait at most `a_timeout_ms'; `last_event' is none on timeout.
		require
			timeout_ok: a_timeout_ms >= 0
			not_destroyed: not lifecycle.is_destroyed
			no_open_frame: not screen.in_frame
		do
			if c_wait (a_timeout_ms) = 1 then
				deliver
			else
				create last_event.make_none
			end
		ensure
			counted_when_delivered: not last_event.is_none implies delivery_count = old delivery_count + 1
			nothing_taken_on_timeout: last_event.is_none implies delivery_count = old delivery_count
			kind_from_c: not last_event.is_none implies last_event.kind = c_cur_kind
			lifecycle_in_step: not last_event.is_none implies lifecycle.last_applied = last_event
			touches_in_step: not last_event.is_none implies touches.last_applied = last_event
			metrics_refreshed: is_metric_kind (last_event.kind) implies
				(metrics.width = screen.width and metrics.height = screen.height)
			timeout_changes_nothing: last_event.is_none implies
				(lifecycle.last_applied = old lifecycle.last_applied and touches.last_applied = old touches.last_applied)
			drops_monotonic: dropped_event_count >= old dropped_event_count
		end

	delivery_count: INTEGER
			-- Events delivered so far (the C side's count of taken events).
		do
			Result := c_delivery_count
		ensure
			non_negative: Result >= 0
		end

	is_metric_kind (a_k: INTEGER): BOOLEAN
			-- Does an event of kind `a_k' make `metrics' re-read Android?
		do
			Result := a_k = Kind_window_ready or a_k = Kind_window_resized
				or a_k = Kind_configuration_changed or a_k = Kind_content_rect_changed
		end

	last_event: PHONE_EVENT
			-- Most recent delivery (none before the first, or after a timeout).

	dropped_event_count: INTEGER
			-- Touch moves dropped on queue overflow so far (never lifecycle or key events).
		do
			Result := c_dropped
		ensure
			non_negative: Result >= 0
		end

	run_controls
			-- Deliver events to `controls' until Android ends the app. Apps with a
			-- loop of their own call `wait_for_event' and `controls.dispatch' instead.
		require
			not_destroyed: not lifecycle.is_destroyed
			no_open_frame: not screen.in_frame
		do
			from until lifecycle.is_destroyed loop
				poll_event (0)
				if last_event.is_none then
					controls.repaint_waiting
					wait_for_event
				end
				controls.dispatch (last_event)
			end
		ensure
			ended: lifecycle.is_destroyed
		end

feature -- State

	lifecycle: PHONE_LIFECYCLE
			-- Where the app is in Android's life, including `last_event'.

	touches: PHONE_TOUCHES
			-- Fingers down, including `last_event'.

	handle_exists: BOOLEAN
			-- Has this process claimed its platform handle?
		do
			Result := c_handle_exists
		end

feature -- Services

	screen: PHONE_SCREEN
	metrics: PHONE_METRICS
	storage: PHONE_STORAGE
	assets: PHONE_ASSETS
	log: PHONE_LOG
	speech: PHONE_SPEECH
	files: PHONE_FILES
	keyboard: PHONE_KEYBOARD
	controls: PHONE_CONTROLS

feature -- Behavior

	back_policy: INTEGER
			-- `Back_system' or `Back_app' (read from the C side, Phase 2 RB-16).
		do
			Result := c_back_policy
		end

	set_back_policy (a_policy: INTEGER)
			-- Decide who handles the Back key from now on.
		require
			valid: a_policy = Back_system or a_policy = Back_app
		do
			c_set_back_policy (a_policy)
		ensure
			set: back_policy = a_policy
		end

	keep_screen_on: BOOLEAN
			-- Is the screen kept from dimming?

	set_keep_screen_on (a_on: BOOLEAN)
			-- Keep the screen awake while the app is shown (or stop).
		do
			c_keep_screen_on (a_on)
			keep_screen_on := a_on
		ensure
			set: keep_screen_on = a_on
		end

	is_finishing: BOOLEAN
			-- Has `finish' been asked for?

	finish
			-- Ask Android to end the app; `destroyed' follows.
		require
			not_destroyed: not lifecycle.is_destroyed
		do
			c_finish
			is_finishing := True
		ensure
			finishing: is_finishing
		end

feature {NONE} -- Implementation

	deliver
			-- Take the head of the C queue, turn it into `last_event', and
			-- apply it to `lifecycle' and `touches' (and `metrics' on metric kinds).
		require
			not_destroyed: not lifecycle.is_destroyed
		local
			k: INTEGER
			e: PHONE_EVENT
		do
			c_take
			k := c_cur_kind
			if is_touch_kind (k) then
				create e.make_touch (k, c_cur_id.max (0), c_cur_x, c_cur_y, c_cur_time.max (0))
			elseif is_key_kind (k) then
				create e.make_key (k, c_cur_code.max (1), c_cur_time.max (0))
			elseif is_service_kind (k) then
				create e.make_service (k, c_cur_code.max (0), current_text, c_cur_time.max (0))
			elseif is_control_kind (k) then
				create e.make_control (k, c_cur_id.max (1), c_cur_x, c_cur_y, current_text, c_cur_time.max (0))
			else
				check lifecycle_kind: is_lifecycle_kind (k) end
				create e.make_lifecycle (k, c_cur_time.max (0))
			end
			lifecycle.apply (e)
			touches.apply (e)
			speech.apply (e)
			files.apply (e)
			keyboard.apply (e)
			if is_metric_kind (k) then
				metrics.refresh
			end
			last_event := e
		end

	current_text: STRING_32
			-- The text of the event just taken, decoded from UTF-8.
		local
			l_bytes: STRING_8
		do
			if c_cur_text = default_pointer then
				create Result.make_empty
			else
				create l_bytes.make_from_c (c_cur_text)
				Result := {UTF_CONVERTER}.utf_8_string_8_to_string_32 (l_bytes)
			end
		end

invariant
	valid_back_policy: back_policy = Back_system or back_policy = Back_app
	services_consistent: screen.has_window = lifecycle.has_window

end
