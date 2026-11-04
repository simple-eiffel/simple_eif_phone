note
	description: "A picture packed in the app's assets folder. Android's ImageView."
	author: "Larry Rix"

class
	PHONE_IMAGE

inherit
	PHONE_CONTROL

create
	make

feature {NONE} -- Initialization

	make (a_controls: PHONE_CONTROLS; a_asset: READABLE_STRING_32)
			-- Show the picture `a_asset'. A missing one reports through `last_failure'.
		require
			asset_given: not a_asset.is_empty
		do
			asset := a_asset
			make_control (a_controls, Control_image, Void)
			order (Op_image, 0, 0, a_asset)
		ensure
			mine: controls = a_controls
			asset_set: asset.same_string (a_asset)
		end

feature -- Access

	asset: READABLE_STRING_32

feature -- Element change

	set_asset (a_asset: READABLE_STRING_32)
		require
			asset_given: not a_asset.is_empty
		do
			asset := a_asset
			order (Op_image, 0, 0, a_asset)
		ensure
			set: asset.same_string (a_asset)
		end

end
