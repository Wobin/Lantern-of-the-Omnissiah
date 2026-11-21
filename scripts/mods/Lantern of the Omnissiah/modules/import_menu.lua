local mod = get_mod("Lantern of the Omnissiah")

local M = {}

function M.open(_, handlers)
	handlers = handlers or {}
	local context = {
		title_text_unlocalized = mod:localize("loc_lantern_menu_title"),
		description_text_unlocalized = mod:localize("loc_lantern_menu_desc"),
		options = {
			{
				text = mod:localize("loc_lantern_menu_import"),
				no_localization = true,
				close_on_pressed = true,
				callback = function()
					if handlers.on_import then handlers.on_import() end
				end,
			},
			{
				text = mod:localize("loc_lantern_menu_create"),
				no_localization = true,
				close_on_pressed = true,
				callback = function()
					if handlers.on_create then handlers.on_create() end
				end,
			},
			{
				text = mod:localize("loc_lantern_menu_cancel"),
				no_localization = true,
				close_on_pressed = true,
				hotkey = "back",
				template_type = "terminal_button_small",
				callback = function() end,
			},
		},
	}
	Managers.event:trigger("event_show_ui_popup", context)
end

return M
