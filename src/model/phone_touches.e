note
	description: "[
		The fingers currently on the glass, by pointer id, with their last
		positions. Built from delivered touch events. Pure Eiffel, PC-tested.
		A move for an unknown id (its down was lost) is ignored; any
		`touch_cancel' clears every finger.
	]"
	author: "Larry Rix"

class
	PHONE_TOUCHES

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- No fingers down.
		do
			create positions.make (10)
		ensure
			none_active: active_ids.is_empty
			nothing_applied: last_applied = Void
		end

feature -- Model

	active_ids: MML_SET [INTEGER]
			-- Ids of the fingers currently down.
		do
			create Result
			across positions as ic loop
				Result := Result & @ic.key
			end
		end

	xs_model: MML_MAP [INTEGER, INTEGER]
			-- Last x of each finger down, by id (Phase 2 RB-12).
		do
			create Result
			across positions as ic loop
				Result := Result.updated (@ic.key, ic.x)
			end
		end

	ys_model: MML_MAP [INTEGER, INTEGER]
			-- Last y of each finger down, by id (Phase 2 RB-12).
		do
			create Result
			across positions as ic loop
				Result := Result.updated (@ic.key, ic.y)
			end
		end

feature -- Access

	count: INTEGER
			-- Number of fingers down.
		do
			Result := positions.count
		end

	is_active (a_id: INTEGER): BOOLEAN
			-- Is finger `a_id' down?
		do
			Result := positions.has (a_id)
		ensure
			definition: Result = active_ids [a_id]
		end

	x_of (a_id: INTEGER): INTEGER
			-- Last x of finger `a_id'.
		require
			active: is_active (a_id)
		do
			if attached positions.item (a_id) as al_p then
				Result := al_p.x
			end
		ensure
			definition: Result = xs_model [a_id]
		end

	y_of (a_id: INTEGER): INTEGER
			-- Last y of finger `a_id'.
		require
			active: is_active (a_id)
		do
			if attached positions.item (a_id) as al_p then
				Result := al_p.y
			end
		ensure
			definition: Result = ys_model [a_id]
		end

	last_applied: detachable PHONE_EVENT
			-- Most recent event passed to `apply' (any family).

feature -- Element change

	apply (a_e: PHONE_EVENT)
			-- Update the fingers for `a_e'. Losing the window or focus, or being
			-- destroyed, lifts every finger (Phase 2 RB-11: Android is not
			-- known to send a cancel then). Other non-touch events change
			-- nothing but `last_applied'.
		do
			inspect a_e.kind
			when Kind_touch_down then
				positions.force ([a_e.x, a_e.y], a_e.pointer_id)
			when Kind_touch_move then
				if positions.has (a_e.pointer_id) then
					positions.force ([a_e.x, a_e.y], a_e.pointer_id)
				end
			when Kind_touch_up then
				positions.remove (a_e.pointer_id)
			when Kind_touch_cancel, Kind_window_lost, Kind_focus_lost, Kind_destroyed then
				positions.wipe_out
			else
					-- Nothing to track.
			end
			last_applied := a_e
		ensure
			recorded: last_applied = a_e
			down: a_e.kind = Kind_touch_down implies
				(active_ids |=| (old active_ids & a_e.pointer_id) and x_of (a_e.pointer_id) = a_e.x and y_of (a_e.pointer_id) = a_e.y)
			down_positions: a_e.kind = Kind_touch_down implies
				(xs_model |=| (old xs_model).updated (a_e.pointer_id, a_e.x) and ys_model |=| (old ys_model).updated (a_e.pointer_id, a_e.y))
			move: (a_e.kind = Kind_touch_move and old is_active (a_e.pointer_id)) implies
				(active_ids |=| old active_ids and x_of (a_e.pointer_id) = a_e.x and y_of (a_e.pointer_id) = a_e.y)
			move_positions: (a_e.kind = Kind_touch_move and old is_active (a_e.pointer_id)) implies
				(xs_model |=| (old xs_model).updated (a_e.pointer_id, a_e.x) and ys_model |=| (old ys_model).updated (a_e.pointer_id, a_e.y))
			stray_move_ignored: (a_e.kind = Kind_touch_move and not old is_active (a_e.pointer_id)) implies
				(active_ids |=| old active_ids and xs_model |=| old xs_model and ys_model |=| old ys_model)
			up: a_e.kind = Kind_touch_up implies active_ids |=| (old active_ids / a_e.pointer_id)
			up_positions: a_e.kind = Kind_touch_up implies
				(xs_model |=| (old xs_model).removed (a_e.pointer_id) and ys_model |=| (old ys_model).removed (a_e.pointer_id))
			cancel: a_e.kind = Kind_touch_cancel implies active_ids.is_empty
			cleared: (a_e.kind = Kind_window_lost or a_e.kind = Kind_focus_lost or a_e.kind = Kind_destroyed) implies active_ids.is_empty
			non_touch_unchanged: (not a_e.is_touch and not clears_touches (a_e.kind)) implies
				(active_ids |=| old active_ids and xs_model |=| old xs_model and ys_model |=| old ys_model)
		end

	clears_touches (a_k: INTEGER): BOOLEAN
			-- Does a non-touch event of kind `a_k' lift every finger?
		do
			Result := a_k = Kind_window_lost or a_k = Kind_focus_lost or a_k = Kind_destroyed
		end

feature {NONE} -- Implementation

	positions: HASH_TABLE [TUPLE [x, y: INTEGER], INTEGER]
			-- Last position per active finger id.

invariant
	count_matches_model: count = active_ids.count
	positions_cover_ids: xs_model.domain |=| active_ids and ys_model.domain |=| active_ids

end
