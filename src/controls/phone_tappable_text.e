note
	description: "[
		Styled text whose runs marked `Tappable' in PHONE_RICH_ROW can be tapped.
		Runs count from 1, every run of the block counting, tappable or not.
	]"
	author: "Larry Rix"

class
	PHONE_TAPPABLE_TEXT

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			make_control (a_controls, Control_any, Tappable_class)
			listen ("setOnRunListener", agent heard)
		ensure
			mine: controls = a_controls
		end

feature -- Access

	on_run: detachable PROCEDURE [TUPLE [INTEGER]]

feature -- Element change

	set_rich (a_row: PHONE_RICH_ROW)
			-- Show the first block of `a_row'.
		require
			has_block: a_row.block_count > 0
		do
			order (Op_rich, 0, 0, a_row.wire)
		end

	set_on_run (a_action: PROCEDURE [TUPLE [INTEGER]])
		do
			on_run := a_action
		ensure
			set: on_run = a_action
		end

feature {NONE} -- Implementation

	heard (a_words: READABLE_STRING_32)
			-- "onRun|index", the index from 0.
		local
			l_number: STRING_32
		do
			l_number := a_words.substring (a_words.index_of ('|', 1) + 1, a_words.count)
			if l_number.is_integer and then attached on_run as al_action then
				al_action.call ([l_number.to_integer + 1])
			end
		end

	Tappable_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneTappable"

end
