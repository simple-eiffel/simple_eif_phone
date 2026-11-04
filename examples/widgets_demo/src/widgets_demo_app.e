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
			l_title: SW_LABEL
			l_box: SW_TEXT_BOX
		do
			create l_theme.make_light
			create window.make ("Widgets", 0, 0, 1080, 2400, l_theme)
			l_theme.set_text_scale (window.density)
			window.phone.log.set_tag ("Eiffel")
			create l_title.make ("simple_widgets on Android", {SW_PAINTER}.Role_ui, 20.0, True)
			create status.make_ui ("Nothing tapped yet")
			create l_box.make_single_line ("Text box")
			create list.make (600.0)
			create check_box.make ("A check box", False, Void)
			create button.make_primary ("Tap me", Void)
			check_box.set_on_change (agent on_check)
			button.set_on_click (agent on_tap)
			list.set_grow (1.0)
			list.set_row_count (5000)
			list.set_row_height (32.0 * window.density)
			list.set_row_renderer (agent draw_row)
			list.set_on_select (agent on_row)
			create l_root.make
			l_root.put (l_title)
			l_root.put (status)
			l_root.put (button)
			l_root.put (l_box)
			l_root.put (check_box)
			l_root.put (list)
			window.set_root (l_root)
			window.set_on_tick (agent on_tick)
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
				say_place ("list", list)
				window.phone.log.info ("widgets: frame " + beats.out)
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

feature {NONE} -- Implementation

	window: SW_WINDOW
	status: SW_LABEL
	list: SW_LIST
	button: SW_BUTTON
	check_box: SW_CHECK_BOX
	taps, beats, last_first: INTEGER

end
