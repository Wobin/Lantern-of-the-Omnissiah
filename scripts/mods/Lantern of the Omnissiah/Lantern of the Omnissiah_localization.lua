return {
	mod_name = {
		en = "Lantern of the Omnissiah",
	},
	mod_description = {
		en = "Import and export a Gameslantern build directly into your loadouts",
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
	loc_setting_show_build_rings = {
		en = "Show build rings in talent tree",
	},
	loc_setting_show_build_rings_tooltip = {
		en = "Draw an orange ring behind each talent in the imported build that you have not selected yet. Rings clear as you spend points, and reappear if you remove a build talent.",
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

	loc_lantern_toast_export_clipboard = { en = "Build copied (%d talents). Click your saved Gameslantern Export bookmarklet in your logged-in browser tab." },
	loc_lantern_toast_export_clipboard2 = { en = "Build copied (%d talents, %d weapons, %d curios). Click your saved Gameslantern Export bookmarklet." },
	loc_lantern_toast_export_file      = { en = "Clipboard unavailable; build written to %s. Open it, copy all, then use the bookmarklet." },
	loc_lantern_toast_export_failed    = { en = "Export failed: could not write the build out." },
	loc_lantern_toast_export_empty     = { en = "No talents selected to export." },
	loc_lantern_export_default_name    = { en = "%s build" },
	loc_lantern_export_named           = { en = "%s's %s build" },
	loc_lantern_toast_export_staged     = { en = "Build copied and staged. Go to your matching character and press + to add it as a preset." },
	loc_lantern_toast_staged_imported   = { en = "Added %s as a new preset (%d talents)." },
	loc_lantern_toast_staged_mismatch   = { en = "Staged build is for %s; switch to that character, then press +." },
	loc_lantern_toast_nothing_to_import = { en = "Nothing to import - copy a GamesLantern link or export a teammate's build first." },
	loc_lantern_menu_import             = { en = "Import from GamesLantern/Inspect" },
	loc_lantern_menu_create             = { en = "Create new profile" },
	loc_lantern_toast_bookmarklet_clipboard = { en = "Export bookmarklet copied. Make a NEW browser bookmark and paste it as the URL - do not paste it into the address bar." },
	loc_lantern_toast_bookmarklet_file      = { en = "Clipboard unavailable; bookmarklet written to %s. Open it and paste the line as a NEW bookmark URL (not the address bar)." },
	loc_setting_export_bookmarklet          = { en = "Copy export bookmarklet to clipboard" },
	loc_setting_export_bookmarklet_tooltip  = { en = "Toggle on to copy the Gameslantern export bookmarklet to your clipboard. It flips back off automatically." },
}
