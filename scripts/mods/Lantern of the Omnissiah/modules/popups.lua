-- UI popup wrappers — title/body strings passed through unlocalised so we
-- can interpolate runtime data (build title, talent counts, etc).

local M = {}

function M.error(title, body)
	Managers.event:trigger("event_show_ui_popup", {
		title_text_unlocalized       = title,
		description_text_unlocalized = body,
		no_exit_sound                = true,
		options = {
			{ close_on_pressed = true, hotkey = "back", text = "loc_popup_button_close" },
		},
	})
end

function M.confirm(title, body, on_confirm)
	Managers.event:trigger("event_show_ui_popup", {
		title_text_unlocalized       = title,
		description_text_unlocalized = body,
		no_exit_sound                = true,
		options = {
			{
				close_on_pressed = true,
				no_localization  = true,
				text             = "Create Preset",
				callback         = on_confirm,
			},
			{
				close_on_pressed = true,
				hotkey           = "back",
				template_type    = "terminal_button_small",
				text             = "loc_popup_button_cancel",
			},
		},
	})
end

return M
