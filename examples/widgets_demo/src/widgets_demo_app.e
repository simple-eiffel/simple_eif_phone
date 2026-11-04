note
	description: "simple_widgets on the phone: the library the PC uses, unchanged, drawn by cairo."
	author: "Larry Rix"

class
	WIDGETS_DEMO_APP

create
	make

feature {NONE} -- Initialization

	make
		local
			l_theme: SW_THEME
			l_root: SW_COLUMN
			l_title, l_hebrew, l_greek: SW_LABEL
		do
			create l_theme.make_light
			create window.make ("Widgets", 0, 0, 1080, 2400, l_theme)
			l_theme.set_text_scale (window.density)
			window.enable_shaped_text
			window.phone.log.set_tag ("Eiffel")
			create l_title.make ("simple_widgets on Android", {SW_PAINTER}.Role_ui, 20.0, True)
			create l_hebrew.make (Hebrew_line, {SW_PAINTER}.Role_ui, 20.0, False)
			create l_greek.make (Greek_line, {SW_PAINTER}.Role_ui, 20.0, False)
			create status.make_ui ("Nothing tapped yet")
			create box.make_single_line ("")
			create list.make (600.0)
			create check_box.make ("A check box", False, Void)
			create button.make_primary ("Tap me", Void)
			check_box.set_on_change (agent on_check)
			button.set_on_click (agent on_tap)
			box.set_on_change (agent on_typed)
			list.set_grow (1.0)
			list.set_row_count (5000)
			list.set_row_height (32.0 * window.density)
			list.set_row_renderer (agent draw_row)
			list.set_on_select (agent on_row)
			create l_root.make
			l_root.put (l_title)
			l_root.put (l_hebrew)
			l_root.put (l_greek)
			l_root.put (status)
			l_root.put (button)
			l_root.put (box)
			l_root.put (check_box)
			l_root.put (list)
			window.set_root (l_root)
			window.set_on_tick (agent on_tick)
			window.set_wants_typing (agent takes_typing_at)
			window.phone.log.info ("widgets: starting")
			window.run
		end

feature {NONE} -- Reactions

	on_tick
			-- The tests find the widgets through the log: Android sees one surface.
		do
			beats := beats + 1
			if beats = 2 then
				say_place ("button", button)
				say_place ("check", check_box)
				say_place ("box", box)
				say_place ("list", list)
				window.phone.log.info ("widgets: frame " + beats.out)
				say_shaping ("hebrew", Hebrew_line)
				say_shaping ("greek", Greek_line)
				say_shaping ("emoji", Emoji_line)
				say_wrapping
			end
			if list.first_visible /= last_first then
				last_first := list.first_visible
				window.phone.log.info ("widgets: first row " + last_first.out)
			end
		end

	say_place (a_name: STRING_8; a_widget: SW_WIDGET)
			-- Log the screen position of the middle of `a_widget'.
		do
			window.phone.log.info ("widgets: at " + a_name + " "
				+ (a_widget.x + a_widget.width / 2.0).truncated_to_integer.out + " "
				+ (a_widget.y + a_widget.height / 2.0 + window.area_top).truncated_to_integer.out)
		end

	say_shaping (a_name: STRING_8; a_text: STRING_32)
			-- Log what the shaper made of `a_text'.
		do
			if attached window.shaping as al_kit then
				if attached al_kit.layout_for (a_text, 1000, 40) as al_layout then
					window.phone.log.info ("widgets: shaped " + a_name + " rtl " + al_layout.is_rtl.out
						+ " whole " + al_layout.covers_all_characters.out + " notes " + al_layout.notes.count.out)
					across al_layout.notes as ic loop
						window.phone.log.info ("widgets: note " + a_name + " " + ic.code.out)
					end
				end
			end
		end

	say_wrapping
			-- Log how the Hebrew line breaks in a narrow space.
		do
			if attached window.shaping as al_kit then
				if attached al_kit.layout_for (Hebrew_line, 250, 40) as al_layout then
					window.phone.log.info ("widgets: wrapped lines " + al_layout.lines.count.out
						+ " whole " + al_layout.covers_all_characters.out)
				end
			end
		end

	takes_typing_at (a_x, a_y: INTEGER): BOOLEAN
			-- Does the widget at (`a_x', `a_y') take typing?
		do
			Result := attached window.root as al_root and then attached al_root.widget_at (a_x, a_y) as al_widget
				and then al_widget.takes_typing
		end

	on_typed
		do
			window.phone.log.info ("widgets: box holds " + box.text.count.out + " letters")
			if not box.text.is_empty then
				window.phone.log.info ("widgets: last letter " + box.text.code (box.text.count).out)
			end
		end

	on_check
		do
			window.phone.log.info ("widgets: checked " + check_box.is_checked.out)
		end

	on_tap
		do
			taps := taps + 1
			status.set_text ("Tapped " + taps.out + " times")
			window.phone.log.info ("widgets: tapped " + taps.out)
		end

	on_row (a_row: INTEGER)
		do
			status.set_text ("Row " + a_row.out)
			window.phone.log.info ("widgets: row " + a_row.out)
		end

	draw_row (a_painter: SW_PAINTER; a_row: INTEGER; a_x, a_y, a_width, a_height: REAL_64)
		do
			a_painter.font ({SW_PAINTER}.Role_ui, 13.0, False)
			a_painter.set_color (a_painter.theme.ink)
			a_painter.text (a_x + 8.0 * window.density, a_y + a_height - 9.0 * window.density, "Row " + a_row.out)
		end

feature {NONE} -- Samples

	Hebrew_line: STRING_32 = "%/1489/%/1468/%/1456/%/1512/%/1461/%/1488/%/1513/%/1460/%/1497/%/1514/ Genesis 1:1 %/1489/%/1512/%/1488/"
			-- Pointed Hebrew with English inside it.

	Greek_line: STRING_32 = "%/7960/%/957/ %/7936/%/961/%/967/%/8135/ %/7974/%/957/ %/8001/ %/955/%/972/%/947/%/959/%/962/"
			-- Polytonic Greek.

	Emoji_line: STRING_32 = "Emoji %/128512/ here"
			-- A picture character. No pictures are packed, so the shaper reports it.

feature {NONE} -- Implementation

	window: SW_WINDOW
	status: SW_LABEL
	list: SW_LIST
	button: SW_BUTTON
	check_box: SW_CHECK_BOX
	box: SW_TEXT_BOX
	taps, beats, last_first: INTEGER

end
