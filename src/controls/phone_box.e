note
	description: "Controls that hold other controls in a line. Android's LinearLayout."
	author: "Larry Rix"

deferred class
	PHONE_BOX

inherit
	PHONE_CONTROL

feature {NONE} -- Initialization

	make_box (a_controls: PHONE_CONTROLS; a_kind: INTEGER)
		do
			create children.make (4)
			make_control (a_controls, a_kind, Void)
		ensure
			empty: children.is_empty
		end

feature -- Access

	children: ARRAYED_LIST [PHONE_CONTROL]

	gap: INTEGER
			-- Space between children.

	padding: INTEGER
			-- Space around them.

feature -- Element change

	set_spacing (a_gap, a_padding: INTEGER)
			-- Set both, in density-independent pixels. Applies to children added from now on.
		require
			gap_ok: a_gap >= 0
			padding_ok: a_padding >= 0
		do
			gap := a_gap
			padding := a_padding
			order (Op_spacing, a_gap, a_padding, Void)
		ensure
			gap_set: gap = a_gap
			padding_set: padding = a_padding
		end

	extend (a_child: PHONE_CONTROL)
			-- Add `a_child' at its natural size.
		require
			mine: a_child.controls = controls
			new: not children.has (a_child)
			not_self: a_child /= Current
		do
			children.extend (a_child)
			order (Op_add, a_child.id, 0, Void)
		ensure
			added: children.last = a_child
			counted: children.count = old children.count + 1
		end

	extend_growing (a_child: PHONE_CONTROL; a_share: INTEGER)
			-- Add `a_child', to take `a_share' of the room left over.
		require
			mine: a_child.controls = controls
			new: not children.has (a_child)
			not_self: a_child /= Current
			share_positive: a_share > 0
		do
			children.extend (a_child)
			order (Op_add, a_child.id, a_share * 100, Void)
		ensure
			added: children.last = a_child
			counted: children.count = old children.count + 1
		end

	remove (a_child: PHONE_CONTROL)
		require
			held: children.has (a_child)
		do
			children.prune_all (a_child)
			order (Op_remove, a_child.id, 0, Void)
		ensure
			gone: not children.has (a_child)
		end

end
