note
	description: "[
		A map of filled outlines over land and lakes, with named places. It pinches and pans
		by itself and says which outlines lie under a tap. Outlines take their colors
		from their names. Put longitudes and latitudes in as they are.
	]"
	author: "Larry Rix"

class
	PHONE_ATLAS

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_land, a_water, a_label, a_dot: NATURAL_32)
		do
			make_control (a_controls, Control_any, Atlas_class)
			call_integer ("setLandColor", a_land.as_integer_32)
			call_integer ("setWaterColor", a_water.as_integer_32)
			call_integer ("setLabelColor", a_label.as_integer_32)
			call_integer ("setDotColor", a_dot.as_integer_32)
			listen ("setOnAtlasListener", agent heard)
		ensure
			mine: controls = a_controls
		end

feature -- Access

	on_pick: detachable PROCEDURE [TUPLE [ARRAYED_LIST [INTEGER]]]
			-- Told the outlines under a tap, as their places in `set_outlines'.

feature -- Element change

	set_on_pick (a_action: PROCEDURE [TUPLE [ARRAYED_LIST [INTEGER]]])
		do
			on_pick := a_action
		ensure
			set: on_pick = a_action
		end

	set_land (a_rings: LIST [TUPLE [kind: READABLE_STRING_32; ring: ARRAY [REAL_32]]])
			-- The base map. A kind of "lake" is drawn as water.
		do
			call_text ("setLand", wire (a_rings))
		end

	set_outlines (a_rings: LIST [TUPLE [name: READABLE_STRING_32; ring: ARRAY [REAL_32]]])
		do
			call_text ("setAreas", wire (a_rings))
		end

	set_places (a_places: LIST [TUPLE [id, name: READABLE_STRING_32; least_zoom: INTEGER; lon, lat: REAL_32]])
		local
			l_wire: STRING_32
		do
			create l_wire.make (a_places.count * 32)
			across a_places as ic loop
				if not l_wire.is_empty then
					l_wire.append_character (Block)
				end
				l_wire.append (ic.id)
				l_wire.append_character (Field)
				l_wire.append (ic.name)
				l_wire.append_character (Field)
				l_wire.append_integer (ic.least_zoom)
				l_wire.append_character (Field)
				l_wire.append_integer (fixed (ic.lon))
				l_wire.append_character (Field)
				l_wire.append_integer (fixed (ic.lat))
			end
			call_text ("setPlaces", l_wire)
		end

	set_focus_place (a_id: READABLE_STRING_32)
			-- Open on place `a_id' and name it first.
		do
			call_text ("setFocusPlace", a_id)
		end

feature {NONE} -- Implementation

	fixed (a_degrees: REAL_32): INTEGER
		do
			Result := (a_degrees * 100000).rounded
		end

	wire (a_rings: LIST [TUPLE [name: READABLE_STRING_32; ring: ARRAY [REAL_32]]]): STRING_32
		local
			i: INTEGER
			l_ring: ARRAY [REAL_32]
		do
			create Result.make (a_rings.count * 64)
			across a_rings as ic loop
				if not Result.is_empty then
					Result.append_character (Block)
				end
				Result.append (ic.name)
				Result.append_character (Field)
				l_ring := ic.ring
				from i := l_ring.lower until i > l_ring.upper loop
					if i > l_ring.lower then
						Result.append_character (',')
					end
					Result.append_integer (fixed (l_ring [i]))
					i := i + 1
				end
			end
		end

	heard (a_words: READABLE_STRING_32)
			-- "onPicked|3,7".
		local
			l_list: ARRAYED_LIST [INTEGER]
			l_bar: INTEGER
		do
			create l_list.make (4)
			l_bar := a_words.index_of ('|', 1)
			if l_bar > 0 then
				across a_words.substring (l_bar + 1, a_words.count).split (',') as ic loop
					if ic.is_integer then
						l_list.extend (ic.to_integer)
					end
				end
			end
			if attached on_pick as al_action then
				al_action.call ([l_list])
			end
		end

	Field: CHARACTER_32 = '%/29/'

	Block: CHARACTER_32 = '%/30/'

	Atlas_class: STRING_32 = "io.github.simple_eiffel.eifphone.EifPhoneAtlas"

end
