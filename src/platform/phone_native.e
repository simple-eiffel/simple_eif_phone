note
	description: "[
		Every C call of simple_eif_phone, in one place (single choice).
		Inherited with `inherit {NONE}' by the services; never used by apps.
		The C side is runtime/c/sephone_glue.c; its contract is sephone.h.
	]"
	author: "Larry Rix"

class
	PHONE_NATIVE

feature {NONE} -- Handle

	c_handle_exists: BOOLEAN
		external "C inline use %"sephone.h%"" alias "return (EIF_BOOLEAN) sephone_handle_exists();" end

	c_handle_claim
		external "C inline use %"sephone.h%"" alias "sephone_handle_claim();" end

feature {NONE} -- Events

	c_wait (a_timeout_ms: INTEGER): INTEGER
			-- Wait for an event; may block. 1 = ready, 0 = timeout.
		external "C blocking inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_wait((int)$a_timeout_ms);" end

	c_take
		external "C inline use %"sephone.h%"" alias "sephone_take();" end

	c_cur_kind: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_cur_kind();" end

	c_cur_time: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_cur_time();" end

	c_cur_id: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_cur_id();" end

	c_cur_x: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_cur_x();" end

	c_cur_y: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_cur_y();" end

	c_cur_code: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_cur_code();" end

	c_dropped: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_dropped();" end

	c_delivery_count: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_delivery_count();" end

	c_back_policy: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_back_policy();" end

	c_cur_text: POINTER
		external "C inline use %"sephone.h%"" alias "return (EIF_POINTER) sephone_cur_text();" end

feature {NONE} -- Java services

	c_helper_present: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_helper_present();" end

	c_speech_start
		external "C inline use %"sephone.h%"" alias "sephone_speech_start();" end

	c_speak (a_text, a_language: POINTER)
		external "C inline use %"sephone.h%"" alias "sephone_speak((const char *)$a_text, (const char *)$a_language);" end

	c_speech_stop
		external "C inline use %"sephone.h%"" alias "sephone_speech_stop();" end

	c_keyboard (a_show: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_keyboard((int)$a_show);" end

	c_pick_file (a_type: POINTER)
		external "C inline use %"sephone.h%"" alias "sephone_pick_file((const char *)$a_type);" end

feature {NONE} -- Behavior

	c_set_back_policy (a_policy: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_set_back_policy((int)$a_policy);" end

	c_keep_screen_on (a_on: BOOLEAN)
		external "C inline use %"sephone.h%"" alias "sephone_keep_screen_on($a_on ? 1 : 0);" end

	c_finish
		external "C inline use %"sephone.h%"" alias "sephone_finish();" end

feature {NONE} -- Window and frame

	c_window_exists: BOOLEAN
		external "C inline use %"sephone.h%"" alias "return (EIF_BOOLEAN) sephone_window_exists();" end

	c_window_width: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_window_width();" end

	c_window_height: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_window_height();" end

	c_frame_lock: BOOLEAN
		external "C blocking inline use %"sephone.h%"" alias "return (EIF_BOOLEAN) sephone_frame_lock();" end

	c_frame_unlock
		external "C blocking inline use %"sephone.h%"" alias "sephone_frame_unlock();" end

	c_frame_fill (a_x, a_y, a_w, a_h, a_rgb: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_frame_fill((int)$a_x, (int)$a_y, (int)$a_w, (int)$a_h, (int)$a_rgb);" end

	c_frame_present_argb_at (a_pixels: POINTER; a_width, a_height, a_stride, a_x, a_y: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_frame_present_argb_at((const void *)$a_pixels, (int)$a_width, (int)$a_height, (int)$a_stride, (int)$a_x, (int)$a_y);" end

	c_frame_present_argb (a_pixels: POINTER; a_width, a_height, a_stride: INTEGER)
		external "C inline use %"sephone.h%"" alias "sephone_frame_present_argb((const void *)$a_pixels, (int)$a_width, (int)$a_height, (int)$a_stride);" end

	c_frame_peek (a_x, a_y: INTEGER): NATURAL_32
			-- TEST ONLY: buffer word at (`a_x', `a_y') while locked.
		external "C inline use %"sephone.h%"" alias "return (EIF_NATURAL_32) sephone_frame_peek((int)$a_x, (int)$a_y);" end

feature {NONE} -- Metrics

	c_density: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_metric_density();" end

	c_content_left: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_metric_content_left();" end

	c_content_top: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_metric_content_top();" end

	c_content_right: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_metric_content_right();" end

	c_content_bottom: INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_metric_content_bottom();" end

	c_rtl: BOOLEAN
		external "C inline use %"sephone.h%"" alias "return (EIF_BOOLEAN) sephone_metric_rtl();" end

feature {NONE} -- Storage and assets

	c_path_internal: POINTER
		external "C inline use %"sephone.h%"" alias "return (EIF_POINTER) sephone_path_internal();" end

	c_path_external: POINTER
		external "C inline use %"sephone.h%"" alias "return (EIF_POINTER) sephone_path_external();" end

	c_asset_size (a_name: POINTER): INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_asset_size((const char *)$a_name);" end

	c_asset_read (a_name, a_buffer: POINTER; a_count: INTEGER): INTEGER
		external "C inline use %"sephone.h%"" alias "return (EIF_INTEGER) sephone_asset_read((const char *)$a_name, (void *)$a_buffer, (int)$a_count);" end

feature {NONE} -- Log

	c_log (a_level: INTEGER; a_tag, a_text: POINTER)
		external "C inline use %"sephone.h%"" alias "sephone_log((int)$a_level, (const char *)$a_tag, (const char *)$a_text);" end

end
