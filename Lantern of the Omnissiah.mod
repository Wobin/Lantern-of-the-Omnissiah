return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Lantern of the Omnissiah` encountered an error loading the Darktide Mod Framework.")

		new_mod("Lantern of the Omnissiah", {
			mod_script       = "Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/Lantern of the Omnissiah",
			mod_data         = "Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/Lantern of the Omnissiah_data",
			mod_localization = "Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/Lantern of the Omnissiah_localization",
		})
	end,
	version = "1.5",
	packages = {},
}
