note
	description: "[
		Writes a starter project for `eifphone new': eifphone.toml, an ECF
		that uses simple_eif_phone, and a root class with the canonical
		event loop (spec 06).
	]"
	author: "Larry Rix"

class
	EIFPHONE_TEMPLATE

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_error.make_empty
		end

feature -- Basic operations

	write (a_dir: PATH; a_app_id: READABLE_STRING_8; a_label: READABLE_STRING_32)
			-- Create the starter files in `a_dir' (created if missing).
		require
			id_given: not a_app_id.is_empty
			label_given: not a_label.is_empty
		do
			create last_error.make_empty
			if not can_write_to (a_dir) then
				last_error := {STRING_32} "the folder is not empty: " + a_dir.name
			else
				make_folder (a_dir.extended ("src"))
				write_file (a_dir.extended ("eifphone.toml"), toml_text (a_app_id, a_label))
				write_file (a_dir.extended ("app.ecf"), Ecf_text)
				write_file (a_dir.extended ("src").extended ("app_main.e"), Root_text)
			end
		ensure
			error_or_written: last_error.is_empty implies files_exist (a_dir)
		end

	can_write_to (a_dir: PATH): BOOLEAN
			-- Is `a_dir' missing or empty? (`new' never overwrites.)
		do
			Result := not (create {DIRECTORY}.make_with_path (a_dir)).exists
				or else (create {DIRECTORY}.make_with_path (a_dir)).is_empty
		end

	files_exist (a_dir: PATH): BOOLEAN
			-- Are eifphone.toml, the ECF and the root class all present?
		do
			Result := exists (a_dir.extended ("eifphone.toml")) and exists (a_dir.extended ("app.ecf"))
				and exists (a_dir.extended ("src").extended ("app_main.e"))
		end

feature -- Access

	last_error: STRING_32

feature {NONE} -- Texts

	toml_text (a_app_id: READABLE_STRING_8; a_label: READABLE_STRING_32): STRING_32
			-- Starter eifphone.toml.
		do
			create Result.make (256)
			Result.append ({STRING_32} "[app]%Nid = %"" + a_app_id.to_string_32 + {STRING_32} "%"%N")
			Result.append ({STRING_32} "label = %"" + a_label + {STRING_32} "%"%N")
			Result.append ({STRING_32} "version_code = 1%Nversion_name = %"0.1.0%"%N%N")
			Result.append ({STRING_32} "[eiffel]%Necf = %"app.ecf%"%Ntarget = %"app%"%N%N")
			Result.append ({STRING_32} "[android]%Nabis = [%"arm64-v8a%", %"x86_64%"]%Nmin_sdk = 26%Ntarget_sdk = 36%Njava_helper = false%N")
		end

	Ecf_text: STRING_32 = "[
<?xml version="1.0" encoding="ISO-8859-1"?>
<system xmlns="http://www.eiffel.com/developers/xml/configuration-1-23-0" name="app" uuid="00000000-0000-4000-8000-0000000000A0">
	<target name="app">
		<root class="APP_MAIN" feature="make"/>
		<option warning="warning">
			<assertions precondition="true" postcondition="true" check="true" invariant="true" loop="true" supplier_precondition="true"/>
		</option>
		<setting name="console_application" value="true"/>
		<capability>
			<void_safety support="all"/>
		</capability>
		<library name="base" location="$ISE_LIBRARY\library\base\base.ecf"/>
		<library name="simple_eif_phone" location="$SIMPLE_EIFFEL\simple_eif_phone\simple_eif_phone.ecf"/>
		<cluster name="src" location=".\src\"/>
	</target>
	<target name="app_fast">
		<description>Contracts off, for time-sensitive work such as live drawing. Set target = "app_fast" in eifphone.toml.</description>
		<root class="APP_MAIN" feature="make"/>
		<option warning="warning">
			<assertions precondition="false" postcondition="false" check="false" invariant="false" loop="false" supplier_precondition="false"/>
		</option>
		<setting name="console_application" value="true"/>
		<capability>
			<void_safety support="all"/>
		</capability>
		<library name="base" location="$ISE_LIBRARY\library\base\base.ecf">
			<option><assertions precondition="false" postcondition="false" check="false" invariant="false" loop="false" supplier_precondition="false"/></option>
		</library>
		<library name="simple_eif_phone" location="$SIMPLE_EIFFEL\simple_eif_phone\simple_eif_phone.ecf">
			<option><assertions precondition="false" postcondition="false" check="false" invariant="false" loop="false" supplier_precondition="false"/></option>
		</library>
		<cluster name="src" location=".\src\"/>
	</target>
</system>

	]"

	Root_text: STRING_32 = "[
note
	description: "A new simple_eif_phone app: paints the screen, logs each event."

class
	APP_MAIN

inherit
	PHONE_EVENT_KIND

create
	make

feature {NONE} -- Initialization

	make
			-- Run until Android destroys the app.
		do
			create phone.make
			from until phone.lifecycle.is_destroyed loop
				phone.wait_for_event
				phone.log.info (phone.last_event.out_line)
				inspect phone.last_event.kind
				when Kind_window_ready, Kind_window_resized, Kind_redraw_needed then
					draw
				else
				end
			end
		end

feature {NONE} -- Implementation

	phone: SIMPLE_EIF_PHONE

	draw
			-- Paint the whole screen.
		do
			if phone.screen.has_window then
				phone.screen.begin_frame
				if phone.screen.in_frame then
					phone.screen.fill_rect (0, 0, phone.screen.width, phone.screen.height, 0x14161C)
					phone.screen.end_frame
				end
			end
		end

end

	]"

feature {NONE} -- Implementation

	exists (a_path: PATH): BOOLEAN
		do
			Result := (create {RAW_FILE}.make_with_path (a_path)).exists
		end

	make_folder (a_path: PATH)
		local
			d: DIRECTORY
		do
			create d.make_with_path (a_path)
			if not d.exists then
				d.recursive_create_dir
			end
		end

	write_file (a_path: PATH; a_text: READABLE_STRING_32)
			-- Save `a_text' as UTF-8.
		local
			f: PLAIN_TEXT_FILE
			u: UTF_CONVERTER
		do
			create f.make_with_path (a_path)
			f.open_write
			f.put_string (u.string_32_to_utf_8_string_8 (a_text))
			f.close
		end

end
