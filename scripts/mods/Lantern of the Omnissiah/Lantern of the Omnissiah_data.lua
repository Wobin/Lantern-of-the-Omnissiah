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
