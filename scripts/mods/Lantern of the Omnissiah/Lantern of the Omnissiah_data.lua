local mod = get_mod("Lantern of the Omnissiah")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,

	options = {
		widgets = {
			{
				setting_id    = "show_recommendations",
				type          = "checkbox",
				default_value = true,
				title         = "loc_setting_show_recommendations",
				tooltip       = "loc_setting_show_recommendations_tooltip",
			},
			{
				setting_id    = "show_build_rings",
				type          = "checkbox",
				default_value = true,
				title         = "loc_setting_show_build_rings",
				tooltip       = "loc_setting_show_build_rings_tooltip",
			},
			{
				setting_id           = "export_bookmarklet_button",
				type                 = "button",
				button_text          = "loc_setting_export_bookmarklet_button",
				button_trigger       = "held",
				button_hold_duration = 1,
				function_name        = "copy_bookmarklet",
				title                = "loc_setting_export_bookmarklet",
				tooltip              = "loc_setting_export_bookmarklet_tooltip",
			},
			{
				setting_id    = "skip_confirm",
				type          = "checkbox",
				default_value = false,
				title         = "loc_setting_skip_confirm",
				tooltip       = "loc_setting_skip_confirm_tooltip",
			},
			{
				setting_id    = "debug",
				type          = "checkbox",
				default_value = false,
				title         = "loc_setting_debug",
				tooltip       = "loc_setting_debug_tooltip",
			},
		},
	},
}
