local mod = get_mod("Lantern of the Omnissiah")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local M = {}

local FONT_TYPE = "proxima_nova_bold"
local FONT_SIZE = 18
local PADX      = 18
local ROW_PADY  = 13
local ROW_H     = FONT_SIZE + ROW_PADY * 2
local TOP_INSET = 18
local BOT_INSET = 18
local MENU_Y    = -40
local GAP       = 14
local MARGIN    = 6

local BG_MAT    = "content/ui/materials/backgrounds/terminal_basic"
local FRAME_UP  = "content/ui/materials/frames/item_info_upper"
local FRAME_LO  = "content/ui/materials/frames/item_info_lower"
local BAR_H     = 37
local OVERHANG  = 10
local BAR_STICK = 5
local BTN_BASE  = "content/ui/materials/backgrounds/default_square"
local BTN_BEVEL = "content/ui/materials/gradients/gradient_vertical"
local BTN_FRAME = "content/ui/materials/frames/frame_tile_2px"
local BTN_HOVER = "content/ui/materials/frames/hover"

local Z_SCRIM, Z_PANEL = 500, 505
local Z_BASE, Z_BEVEL, Z_BFRAME, Z_HOVER, Z_TEXT = 510, 511, 512, 513, 515
local Z_FRAME = 520

local COL_TEXT    = { 255, 220, 210, 170 }
local COL_BG      = { 235, 90, 90, 90 }
local COL_FRAME   = { 255, 255, 255, 255 }
local COL_BTN     = { 255, 24, 40, 28 }
local COL_BEVEL   = { 35, 255, 255, 255 }
local COL_BFRAME  = { 255, 110, 105, 85 }
local COL_HOVER   = { 0, 255, 245, 210 }
local HOVER_MAX_A = 200

local SEED_W, SEED_MX = 320, -334

local function tex(style_id, value, z, color, y)
	return { pass_type = "texture", style_id = style_id, value = value,
		style = { size = { SEED_W, ROW_H }, offset = { SEED_MX, y, z }, horizontal_alignment = "left", vertical_alignment = "top",
			color = { color[1], color[2], color[3], color[4] } } }
end

local function row_def(id, label_key, y)
	return {
		{ content_id = id .. "_hs", pass_type = "hotspot", style_id = id .. "_hit",
		  style = { size = { SEED_W, ROW_H }, offset = { SEED_MX, y, Z_BASE }, horizontal_alignment = "left", vertical_alignment = "top" },
		  content = { on_hover_sound = UISoundEvents.default_mouse_hover } },
		tex(id .. "_base", BTN_BASE, Z_BASE, COL_BTN, y),
		tex(id .. "_bevel", BTN_BEVEL, Z_BEVEL, COL_BEVEL, y),
		tex(id .. "_bframe", BTN_FRAME, Z_BFRAME, COL_BFRAME, y),
		{ pass_type = "texture", style_id = id .. "_hover", value = BTN_HOVER,
		  style = { size = { SEED_W, ROW_H }, offset = { SEED_MX, y, Z_HOVER }, horizontal_alignment = "left", vertical_alignment = "top",
			color = { COL_HOVER[1], COL_HOVER[2], COL_HOVER[3], COL_HOVER[4] } },
		  change_function = function(content, style)
			local hs = content[id .. "_hs"]
			local p = (hs and hs.anim_hover_progress) or 0
			style.color[1] = math.floor(HOVER_MAX_A * p)
		  end },
		{ pass_type = "text", style_id = id .. "_txt", value_id = id .. "_txt", value = mod:localize(label_key),
		  style = { size = { SEED_W - PADX * 2, ROW_H }, offset = { SEED_MX + PADX, y + ROW_PADY, Z_TEXT },
			horizontal_alignment = "left", vertical_alignment = "top",
			font_type = FONT_TYPE, font_size = FONT_SIZE,
			text_color = { COL_TEXT[1], COL_TEXT[2], COL_TEXT[3], COL_TEXT[4] } } },
	}
end

local function menu_definition()
	local panel_h = TOP_INSET + ROW_H * 2 + BOT_INSET
	local passes = {}
	passes[#passes + 1] = { content_id = "scrim", pass_type = "hotspot", style_id = "scrim",
		style = { size = { 4096, 4096 }, offset = { -2048, -2048, Z_SCRIM }, horizontal_alignment = "center", vertical_alignment = "center" } }
	passes[#passes + 1] = { pass_type = "texture", style_id = "panel", value = BG_MAT,
		style = { size = { SEED_W, panel_h }, offset = { SEED_MX, MENU_Y, Z_PANEL }, horizontal_alignment = "left", vertical_alignment = "top",
			color = { COL_BG[1], COL_BG[2], COL_BG[3], COL_BG[4] } } }
	for _, p in ipairs(row_def("import", "loc_lantern_menu_import", TOP_INSET + MENU_Y)) do passes[#passes + 1] = p end
	for _, p in ipairs(row_def("create", "loc_lantern_menu_create", TOP_INSET + ROW_H + MENU_Y)) do passes[#passes + 1] = p end
	passes[#passes + 1] = { pass_type = "texture", style_id = "frame_up", value = FRAME_UP,
		style = { size = { SEED_W, BAR_H }, offset = { SEED_MX, -BAR_STICK + MENU_Y, Z_FRAME }, horizontal_alignment = "left", vertical_alignment = "top",
			color = { COL_FRAME[1], COL_FRAME[2], COL_FRAME[3], COL_FRAME[4] } } }
	passes[#passes + 1] = { pass_type = "texture", style_id = "frame_lo", value = FRAME_LO,
		style = { size = { SEED_W, BAR_H }, offset = { SEED_MX, panel_h - BAR_H + BAR_STICK + MENU_Y, Z_FRAME }, horizontal_alignment = "left", vertical_alignment = "top",
			color = { COL_FRAME[1], COL_FRAME[2], COL_FRAME[3], COL_FRAME[4] } } }
	return UIWidget.create_definition(passes, "profile_preset_add_button")
end

local _definition = menu_definition()

function M.install(element)
	if not element or element._lantern_import_menu then return end
	local widgets = element._widgets
	if not widgets then return end
	local ok, w = pcall(element._create_widget, element, "lantern_import_menu", _definition)
	if not ok or not w then mod:warning("[import_menu] create failed: %s", tostring(w)); return end
	w.visible = false
	local state = { widget = w, pending = nil, handlers = nil, measured = false }
	w.content.scrim.pressed_callback     = function() state.pending = "close" end
	w.content.import_hs.pressed_callback = function() state.pending = "import" end
	w.content.create_hs.pressed_callback = function() state.pending = "create" end
	widgets[#widgets + 1] = w
	element._lantern_import_menu = state
	mod.dbg("[import_menu] installed")
end

local function set_pass(s, key, sx, sy, ox, oy)
	local v = s[key]
	if not v then return end
	v.size[1], v.size[2] = sx, sy
	v.offset[1], v.offset[2] = ox, oy
end

local function set_row(s, id, MX, W, y, H)
	set_pass(s, id .. "_hit", W, H, MX, y)
	set_pass(s, id .. "_base", W, H, MX, y)
	set_pass(s, id .. "_bevel", W, H, MX, y)
	set_pass(s, id .. "_bframe", W, H, MX, y)
	set_pass(s, id .. "_hover", W, H, MX, y)
	set_pass(s, id .. "_txt", W - PADX * 2, H, MX + PADX, y + ROW_PADY)
end

function M.measure(element, ui_renderer)
	local state = element and element._lantern_import_menu
	if not state or state.measured or not ui_renderer then return end
	local w1 = UIRenderer.text_size(ui_renderer, mod:localize("loc_lantern_menu_import"), FONT_TYPE, FONT_SIZE)
	local w2 = UIRenderer.text_size(ui_renderer, mod:localize("loc_lantern_menu_create"), FONT_TYPE, FONT_SIZE)
	local text_area = math.ceil(math.max(w1 or 0, w2 or 0)) + MARGIN
	local W = text_area + PADX * 2
	local H = ROW_H
	local MX = -(W + GAP)
	local panel_h = TOP_INSET + H * 2 + BOT_INSET
	local s = state.widget.style
	set_pass(s, "panel", W, panel_h, MX, MENU_Y)
	set_pass(s, "frame_up", W + OVERHANG * 2, BAR_H, MX - OVERHANG, -BAR_STICK + MENU_Y)
	set_pass(s, "frame_lo", W + OVERHANG * 2, BAR_H, MX - OVERHANG, panel_h - BAR_H + BAR_STICK + MENU_Y)
	set_row(s, "import", MX, W, TOP_INSET + MENU_Y, H)
	set_row(s, "create", MX, W, TOP_INSET + H + MENU_Y, H)
	state.widget.dirty = true
	state.measured = true
	mod.dbg("[import_menu] measured W=%d (text=%d)", W, text_area)
end

function M.open(element, handlers)
	M.install(element)
	local state = element._lantern_import_menu
	if not state then return end
	state.handlers = handlers
	state.pending = nil
	state.widget.visible = true
end

function M.close(element)
	local state = element and element._lantern_import_menu
	if not state then return end
	state.widget.visible = false
end

function M.process(element)
	local state = element and element._lantern_import_menu
	if not state or not state.pending then return end
	local action = state.pending
	state.pending = nil
	local handlers = state.handlers
	M.close(element)
	if action == "import" and handlers and handlers.on_import then handlers.on_import()
	elseif action == "create" and handlers and handlers.on_create then handlers.on_create() end
end

return M
