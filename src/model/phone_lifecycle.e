note
	description: "[
		Where the app is in Android's life, built from delivered events.
		Pure Eiffel: no platform calls, so it is tested on the PC.
		Lenient by design (Phase 2 RB-17): it accepts any order of events
		Android may send and only refuses use after `destroyed'. Each event
		changes exactly the state its kind names (per-kind frame clauses).
		`resumed' also sets `is_started' (Android always starts before it
		resumes), so the model stays consistent even if an event is lost.
	]"
	author: "Larry Rix"

class
	PHONE_LIFECYCLE

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Nothing has happened yet.
		do
				-- Every attribute starts False / 0 / Void.
		ensure
			not_started: not is_started
			not_resumed: not is_resumed
			no_window: not has_window
			no_focus: not has_focus
			not_destroyed: not is_destroyed
			generation_zero: window_generation = 0
			nothing_applied: last_applied = Void
		end

feature -- Status

	is_started: BOOLEAN
			-- Between `started' and `stopped'?

	is_resumed: BOOLEAN
			-- Between `resumed' and `paused' (in the foreground)?

	has_window: BOOLEAN
			-- Between `window_ready' and `window_lost'?

	has_focus: BOOLEAN
			-- Between `focus_gained' and `focus_lost'?

	is_destroyed: BOOLEAN
			-- Has `destroyed' been applied? (final)

	window_generation: INTEGER
			-- Number of `window_ready' events so far; lets apps drop caches
			-- tied to an older window.

	last_applied: detachable PHONE_EVENT
			-- Most recent event passed to `apply' (any family).

	affects_state (a_k: INTEGER): BOOLEAN
			-- Does lifecycle code `a_k' change this model?
		do
			inspect a_k
			when Kind_started, Kind_resumed, Kind_paused, Kind_stopped, Kind_destroyed,
				Kind_window_ready, Kind_window_lost, Kind_focus_gained, Kind_focus_lost then
				Result := True
			else
				Result := False
			end
		end

feature -- Element change

	apply (a_e: PHONE_EVENT)
			-- Update the model for `a_e'. Touch, key and the non-state
			-- lifecycle events (resized, redraw, configuration, low memory,
			-- content rect) change nothing but `last_applied'.
		require
			not_destroyed: not is_destroyed
		do
			inspect a_e.kind
			when Kind_started then
				is_started := True
			when Kind_resumed then
				is_started := True
				is_resumed := True
			when Kind_paused then
				is_resumed := False
			when Kind_stopped then
				is_started := False
				is_resumed := False
			when Kind_destroyed then
				is_destroyed := True
				is_started := False
				is_resumed := False
				has_window := False
				has_focus := False
			when Kind_window_ready then
				has_window := True
				window_generation := window_generation + 1
			when Kind_window_lost then
				has_window := False
			when Kind_focus_gained then
				has_focus := True
			when Kind_focus_lost then
				has_focus := False
			else
					-- Not a state-changing kind.
			end
			last_applied := a_e
		ensure
			recorded: last_applied = a_e
				-- Each state-changing kind: its effect, then a frame naming what it leaves alone (RB-6).
			started: a_e.kind = Kind_started implies is_started
			started_frame: a_e.kind = Kind_started implies
				(is_resumed = old is_resumed and has_window = old has_window and has_focus = old has_focus)
			resumed: a_e.kind = Kind_resumed implies (is_started and is_resumed)
			resumed_frame: a_e.kind = Kind_resumed implies (has_window = old has_window and has_focus = old has_focus)
			paused: a_e.kind = Kind_paused implies not is_resumed
			paused_frame: a_e.kind = Kind_paused implies
				(is_started = old is_started and has_window = old has_window and has_focus = old has_focus)
			stopped: a_e.kind = Kind_stopped implies (not is_started and not is_resumed)
			stopped_frame: a_e.kind = Kind_stopped implies (has_window = old has_window and has_focus = old has_focus)
			window_in: a_e.kind = Kind_window_ready implies (has_window and window_generation = old window_generation + 1)
			window_in_frame: a_e.kind = Kind_window_ready implies
				(is_started = old is_started and is_resumed = old is_resumed and has_focus = old has_focus)
			window_out: a_e.kind = Kind_window_lost implies not has_window
			window_out_frame: a_e.kind = Kind_window_lost implies
				(is_started = old is_started and is_resumed = old is_resumed and has_focus = old has_focus)
			focus_in: a_e.kind = Kind_focus_gained implies has_focus
			focus_out: a_e.kind = Kind_focus_lost implies not has_focus
			focus_frame: (a_e.kind = Kind_focus_gained or a_e.kind = Kind_focus_lost) implies
				(is_started = old is_started and is_resumed = old is_resumed and has_window = old has_window)
			destroyed: a_e.kind = Kind_destroyed implies (is_destroyed and not is_started and not has_window and not has_focus)
			destroyed_only_by_destroy: a_e.kind /= Kind_destroyed implies not is_destroyed
			generation_only_on_window_ready: a_e.kind /= Kind_window_ready implies window_generation = old window_generation
			others_unchanged: not affects_state (a_e.kind) implies
				(is_started = old is_started and is_resumed = old is_resumed and has_window = old has_window
				and has_focus = old has_focus and is_destroyed = old is_destroyed)
		end

invariant
	resumed_implies_started: is_resumed implies is_started
	destroyed_is_final: is_destroyed implies not (is_started or is_resumed or has_window or has_focus)
	generation_non_negative: window_generation >= 0

end
