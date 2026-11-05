note
	description: "[
		Pages swiped sideways, any number of them, on three children reused in turn.
		Add exactly three children. When a page is about to come near, `on_page_wanted'
		is told which child to fill and with which page. Pages count from 1 and
		children from 1; page n sits in child (n - 1) \\ 3 + 1.
	]"
	author: "Larry Rix"

class
	PHONE_PAGER

inherit
	PHONE_BOX

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS)
		do
			create children.make (3)
			make_control (a_controls, Control_any, Pager_class)
			listen ("setOnPageListener", agent on_called)
		ensure
			mine: controls = a_controls
			no_pages: page_count = 0
		end

feature -- Access

	page_count: INTEGER

	page: INTEGER
			-- The page showing; 0 before there is one.

	on_page_wanted: detachable PROCEDURE [TUPLE [INTEGER, INTEGER]]
			-- Told a child and the page to put in it.

	on_page_chosen: detachable PROCEDURE [TUPLE [INTEGER]]
			-- Told the page now showing.

feature -- Element change

	set_on_page_wanted (a_action: PROCEDURE [TUPLE [INTEGER, INTEGER]])
		do
			on_page_wanted := a_action
		ensure
			set: on_page_wanted = a_action
		end

	set_on_page_chosen (a_action: PROCEDURE [TUPLE [INTEGER]])
		do
			on_page_chosen := a_action
		ensure
			set: on_page_chosen = a_action
		end

	set_page_count (a_count: INTEGER)
			-- Every near page is asked for afresh.
		require
			non_negative: a_count >= 0
		do
			page_count := a_count
			call_integer ("setPageCount", a_count)
		ensure
			set: page_count = a_count
		end

	go_to (a_page: INTEGER)
			-- Show `a_page' at once.
		require
			in_range: a_page >= 1 and a_page <= page_count
		do
			page := a_page
			call_integer ("setPage", a_page - 1)
		ensure
			set: page = a_page
		end

	slide (a_step: INTEGER)
			-- Slide one page, as a swipe would: 1 forward, -1 back.
		require
			one_step: a_step = 1 or a_step = -1
		do
			call_integer ("slide", a_step)
		end

feature {NONE} -- Implementation

	on_called (a_words: READABLE_STRING_32)
			-- A call from the pager: its method's name, then its arguments, split by |.
		local
			l_parts: LIST [READABLE_STRING_32]
		do
			l_parts := a_words.split ('|')
			if l_parts.first.same_string ({STRING_32} "onPageWanted") and l_parts.count = 3 then
				if attached on_page_wanted as al_action then
					al_action.call ([l_parts [2].to_integer + 1, l_parts [3].to_integer + 1])
				end
			elseif l_parts.first.same_string ({STRING_32} "onPageChosen") and l_parts.count = 2 then
				page := l_parts [2].to_integer + 1
				if attached on_page_chosen as al_action then
					al_action.call ([page])
				end
			end
		end

	Pager_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhonePager"

invariant
	pages_non_negative: page_count >= 0
	page_in_range: page >= 0 and page <= page_count

end
