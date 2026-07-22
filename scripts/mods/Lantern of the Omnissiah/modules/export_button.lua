local mod = get_mod("Lantern of the Omnissiah")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local M = {}

local ICON = "content/ui/materials/icons/presets/preset_12"
local SCENEGRAPH_ID = "corner_bottom_right"
local OFFSET = { 3, 35 }
local SIZE = { 48, 48 }
local COLOR_IDLE = { 255, 200, 222, 64 }
local COLOR_HOVER = { 255, 220, 240, 120 }

local definition = UIWidget.create_definition({
	{
		content_id = "hotspot",
		pass_type = "hotspot",
		style = {
			size = { SIZE[1], SIZE[2] },
			horizontal_alignment = "center",
			vertical_alignment = "center",
		},
		content = {
			on_hover_sound = UISoundEvents.default_mouse_hover,
		},
	},
	{
		pass_type = "texture",
		style_id = "icon",
		value = ICON,
		style = {
			offset = { 0, 0, 2 },
			size = { SIZE[1], SIZE[2] },
			horizontal_alignment = "center",
			vertical_alignment = "center",
			color = { COLOR_IDLE[1], COLOR_IDLE[2], COLOR_IDLE[3], COLOR_IDLE[4] },
		},
		change_function = function(content, style)
			local hotspot = content.hotspot
			local p = (hotspot and hotspot.anim_hover_progress) or 0
			local color = style.color
			for i = 1, 4 do
				color[i] = COLOR_IDLE[i] + (COLOR_HOVER[i] - COLOR_IDLE[i]) * p
			end
		end,
	},
}, SCENEGRAPH_ID)

function M.install(view, on_pressed)
	if not view or view._lantern_export_button then return end

	local widgets = view._widgets
	if not widgets then
		mod:warning("[export_button] view has no _widgets list")
		return
	end

	local ok, widget = pcall(view._create_widget, view, "lantern_export_button", definition)
	if not ok or not widget then
		mod:warning("[export_button] could not create widget: %s", tostring(widget))
		return
	end

	widget.offset[1] = OFFSET[1]
	widget.offset[2] = OFFSET[2]
	widget.content.hotspot.pressed_callback = on_pressed

	widgets[#widgets + 1] = widget
	view._lantern_export_button = widget
	mod.dbg("[export_button] installed (%d widgets)", #widgets)
end

return M
