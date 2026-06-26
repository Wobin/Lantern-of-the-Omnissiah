return {
	mod_name = {
		en = "Lantern of the Omnissiah",
	},
	mod_description = {
		en = "Import a Gameslantern build directly into your loadouts",
	},

	loc_lantern_confirm_title_default = {
		en = "Import gameslantern build",
	},
	loc_lantern_confirm_build_line = {
		en = "Build: %s",
	},
	loc_lantern_confirm_apply_new = {
		en = "Apply %d of %d talents to a new preset slot?",
	},
	loc_lantern_confirm_apply_overwrite = {
		en = "Overwrite the current preset's talents with %d of %d from this build?",
	},
	loc_lantern_confirm_warn_underleveled = {
		en = "Your character is below level 30 — %d of the build's %d talents will not fit your current talent-point budget and will be skipped.",
	},
	loc_lantern_confirm_skip_other = {
		en = "%d talents will be skipped (%d unresolved by gameslantern, %d not recognised in the current game version).",
	},
	loc_lantern_button_create_preset = {
		en = "Create Preset",
	},

	loc_lantern_err_archetype_title = {
		en = "Wrong archetype",
	},
	loc_lantern_err_archetype_body = {
		en = "This build is for %s; your current character is %s. Switch character and try again.",
	},
	loc_lantern_err_capacity_title = {
		en = "Preset slots full",
	},
	loc_lantern_err_capacity_body = {
		en = "Preset slots are full (%d/%d). Delete a preset or use Re-check Clipboard to overwrite the current one.",
	},
	loc_lantern_err_no_talents_body = {
		en = "Could not read any selected talents from that gameslantern page.",
	},
	loc_lantern_err_no_resolved_body = {
		en = "None of the talents on that page could be resolved.",
	},

	loc_setting_show_recommendations = {
		en = "Show weapon recommendations",
	},
	loc_setting_show_recommendations_tooltip = {
		en = "When enabled, shows the GamesLantern recommended-weapon icons and tooltips on the loadout screen and the recommendation panel on the weapon selection screen. Turn off to hide all recommendation UI.",
	},
	loc_setting_skip_confirm = {
		en = "Skip confirmation popup",
	},
	loc_setting_skip_confirm_tooltip = {
		en = "When enabled, the import proceeds immediately without showing the 'Apply N of M talents?' popup. Useful once you're confident the build's talents match what you want.",
	},
	loc_setting_debug = {
		en = "Verbose logging",
	},
	loc_setting_debug_tooltip = {
		en = "When enabled, logs the pipeline process",
	},

	loc_lantern_toast_fetching = {
		en = "Lantern: receiving transmission from GamesLantern…",
	},

	loc_lantern_toast_no_url = {
		en = "Lantern: no gameslantern URL on the clipboard",
	},
	loc_lantern_toast_no_player = {
		en = "Lantern: no local player profile yet — try again in a moment",
	},
	loc_lantern_toast_no_active_preset = {
		en = "Lantern: no active preset to overwrite — creating a new one",
	},
	loc_lantern_toast_empty_response = {
		en = "Lantern: empty response from gameslantern",
	},
	loc_lantern_toast_linux_unsupported = {
		en = "Lantern: can't fetch under this Proton setup (Z: drive not mapped to /)",
	},
	loc_lantern_toast_fetch_timeout = {
		en = "Lantern: fetch timed out — check your internet connection",
	},
	loc_lantern_toast_imported = {
		en = "Lantern: imported '%s' — %d talents applied (%d skipped)",
	},
	loc_lantern_toast_overwrote = {
		en = "Lantern: overwrote current preset with '%s' — %d talents applied (%d skipped)",
	},
}
