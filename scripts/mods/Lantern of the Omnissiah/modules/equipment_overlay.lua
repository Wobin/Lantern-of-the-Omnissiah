local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local UIWidget   = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local ProfileUtils = require("scripts/utilities/profile_utils")

local SLOTS = {
	"slot_primary",
	"slot_secondary",
	"slot_attachment_1",
	"slot_attachment_2",
	"slot_attachment_3",
}

local ICON_INNER     = { 22, 22 }
local ICON_TEXTURE   = "content/ui/materials/icons/item_types/devices"
local ICON_COLOR     = { 255, 220, 134, 38 }

local TOOLTIP_WIDTH  = 380
local TOOLTIP_MAX_H  = 700
local TOOLTIP_OFFSET = { 40, 260, 0 }
local TOOLTIP_PADDING = 14
local TOOLTIP_Z      = 200

local HEADER_H       = 18
local HEADER_GAP     = 8
local SUBHEADER_H    = 22
local SUBHEADER_GAP  = 24
local DUMP_STAT_H    = 18
local DUMP_STAT_GAP  = 4
local TRAIT_SIZE     = 36
local TRAIT_GAP      = 8
local ROW_NAME_H     = 18
local ROW_DESC_H     = 36
local ROW_HEIGHT     = ROW_NAME_H + ROW_DESC_H
local ROW_GAP        = 8
local ROW_TEXT_X     = TOOLTIP_PADDING + TRAIT_SIZE + TRAIT_GAP
local ROW_TEXT_W     = TOOLTIP_WIDTH - ROW_TEXT_X - TOOLTIP_PADDING
local SECONDARY_LINE_H = 18

local TRAIT_MATERIAL    = "content/ui/materials/icons/traits/traits_container"
local TRAIT_DEFAULT_TEX = "content/ui/textures/icons/traits/weapon_trait_default"

local function find_weapon_for_slot(eq, slot_name)
	if not eq or not eq.weapons or #eq.weapons == 0 then return nil end
	if slot_name == "slot_primary"   then return eq.weapons[1] end
	if slot_name == "slot_secondary" then return eq.weapons[2] or eq.weapons[1] end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Builders: turn an equipment table into an entry's structured display data.
-- ─────────────────────────────────────────────────────────────────────────────

local HEADER_TEXT = "RECOMMENDED: from GamesLantern"

local function build_weapon_entry(w)
	local rows = {}
	for _, b in ipairs(w.blessings or {}) do
		if #rows < 2 then
			rows[#rows + 1] = {
				trait_path = b.trait_id
					and ("content/ui/textures/icons/traits/weapon_trait_" .. b.trait_id)
					or TRAIT_DEFAULT_TEX,
				name = tostring(b.name or "?"),
				desc = tostring(b.description or ""),
			}
		end
	end
	local perk_lines = {}
	for _, p in ipairs(w.perks or {}) do
		perk_lines[#perk_lines + 1] = "● " .. tostring(p)
	end

	local dump_stat
	if w.stats and #w.stats > 0 then
		local min_val = 101
		for _, s in ipairs(w.stats) do
			if s.value and s.value < min_val then min_val = s.value end
		end
		local names = {}
		for _, s in ipairs(w.stats) do
			if s.value == min_val then names[#names + 1] = s.name end
		end
		if #names > 0 then
			dump_stat = string.format("Dump stat: %s (%d)", table.concat(names, ", "), min_val)
		end
	end

	return {
		kind            = "weapon",
		header          = HEADER_TEXT,
		subheader       = tostring(w.name or "?"),
		dump_stat       = dump_stat,
		rows            = rows,
		secondary_block = table.concat(perk_lines, "\n"),
	}
end

local function build_curio_entry(c, idx)
	local lines = {}
	if c.primary and c.primary ~= "" then
		lines[#lines + 1] = "● " .. c.primary
	end
	for _, m in ipairs(c.secondary or {}) do
		lines[#lines + 1] = "      " .. m
	end
	return {
		kind            = "curio",
		header          = HEADER_TEXT,
		subheader       = string.format("Curio %d:  %s", idx, tostring(c.name or "?")),
		rows            = {},
		secondary_block = table.concat(lines, "\n"),
	}
end

local function build_entry_for_slot(eq, slot_name)
	if not eq then return nil end
	if slot_name == "slot_primary" or slot_name == "slot_secondary" then
		local w = find_weapon_for_slot(eq, slot_name)
		return w and build_weapon_entry(w) or nil
	end
	local idx = tonumber(slot_name:match("(%d+)$"))
	local c = idx and eq.curios and eq.curios[idx]
	return c and build_curio_entry(c, idx) or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Pass templates
-- ─────────────────────────────────────────────────────────────────────────────

local function icon_pass_template()
	return {
		{ pass_type = "hotspot", content_id = "hotspot",
		  style = { horizontal_alignment = "right", vertical_alignment = "top",
		            offset = { -4, 4, 0 }, size = ICON_INNER } },
		{ pass_type = "rect", style_id = "background",
		  style = { horizontal_alignment = "right", vertical_alignment = "top",
		            offset = { -4, 4, 30 }, size = ICON_INNER, color = { 220, 8, 8, 8 } } },
		{ pass_type = "texture", style_id = "icon", value = ICON_TEXTURE, value_id = "icon",
		  style = { horizontal_alignment = "right", vertical_alignment = "top",
		            offset = { -4, 4, 31 }, size = ICON_INNER,
		            color = { ICON_COLOR[1], ICON_COLOR[2], ICON_COLOR[3], ICON_COLOR[4] } } },
	}
end

local function tooltip_pass_template()
	local TXT_REGULAR = "proxima_nova_medium"
	local TXT_BOLD    = "proxima_nova_bold"

	local function text_pass(style_id, value_id, font, font_size, alpha, rgb)
		rgb = rgb or { 230, 230, 230 }
		return {
			pass_type = "text",
			style_id  = style_id,
			value_id  = value_id,
			value     = "",
			style     = {
				font_type                 = font,
				font_size                 = font_size,
				text_color                = { alpha, rgb[1], rgb[2], rgb[3] },
				text_horizontal_alignment = "left",
				text_vertical_alignment   = "top",
				line_spacing              = 1.15,
				offset                    = { TOOLTIP_PADDING, TOOLTIP_PADDING, TOOLTIP_Z + 2 },
				size                      = { TOOLTIP_WIDTH - TOOLTIP_PADDING * 2, 200 },
				color                     = { alpha, rgb[1], rgb[2], rgb[3] },
			},
		}
	end

	local function trait_pass(style_id)
		return {
			pass_type = "texture",
			style_id  = style_id,
			value     = TRAIT_MATERIAL,
			style     = {
				material_values = { icon = TRAIT_DEFAULT_TEX },
				size            = { TRAIT_SIZE, TRAIT_SIZE },
				offset          = { TOOLTIP_PADDING, TOOLTIP_PADDING, TOOLTIP_Z + 2 },
				color           = { 0, 255, 255, 255 },
			},
		}
	end

	return {
		{ pass_type = "rect", style_id = "background",
		  style = { offset = { 0, 0, TOOLTIP_Z }, color = { 245, 8, 8, 8 } } },
		{ pass_type = "rect", style_id = "border_top",
		  style = { offset = { 0, 0, TOOLTIP_Z + 1 }, color = { 255, 220, 134, 38 },
		            size = { TOOLTIP_WIDTH, 2 } } },
		text_pass("header",           "header",          TXT_REGULAR, 13, 180),
		text_pass("subheader",        "subheader",       TXT_BOLD,    16, 240),
		text_pass("dump_stat",        "dump_stat",       TXT_REGULAR, 13,   0, { 220, 134, 38 }),
		trait_pass("trait_1"),
		text_pass("row_1_name",       "row_1_name",      TXT_BOLD,    14, 0),
		text_pass("row_1_desc",       "row_1_desc",      TXT_REGULAR, 13, 0),
		trait_pass("trait_2"),
		text_pass("row_2_name",       "row_2_name",      TXT_BOLD,    14, 0),
		text_pass("row_2_desc",       "row_2_desc",      TXT_REGULAR, 13, 0),
		text_pass("secondary_block",  "secondary_block", TXT_REGULAR, 14, 0),
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout: walks visible passes in document order, assigns y/size, returns the
-- total tooltip height. Hides passes that don't apply by zeroing alpha.
-- ─────────────────────────────────────────────────────────────────────────────

local function count_lines(s)
	if not s or s == "" then return 0 end
	local n = 1
	for _ in s:gmatch("\n") do n = n + 1 end
	return n
end

local function set_pass_xy(style, x, y, size_x, size_y)
	if not style then return end
	style.offset[1] = x
	style.offset[2] = y
	style.size[1]   = size_x
	style.size[2]   = size_y
end

local function set_alpha(style, a)
	if style and style.color then style.color[1] = a end
	if style and style.text_color then style.text_color[1] = a end
end

local function layout_tooltip(tooltip, entry)
	local s = tooltip.style
	local content_w = TOOLTIP_WIDTH - TOOLTIP_PADDING * 2
	local y = TOOLTIP_PADDING

	set_pass_xy(s.header, TOOLTIP_PADDING, y, content_w, HEADER_H)
	set_alpha(s.header, 180)
	y = y + HEADER_H + HEADER_GAP

	set_pass_xy(s.subheader, TOOLTIP_PADDING, y, content_w, SUBHEADER_H)
	set_alpha(s.subheader, 240)
	y = y + SUBHEADER_H

	if entry.kind == "weapon" and entry.dump_stat and entry.dump_stat ~= "" then
		y = y + DUMP_STAT_GAP
		set_pass_xy(s.dump_stat, TOOLTIP_PADDING, y, content_w, DUMP_STAT_H)
		set_alpha(s.dump_stat, 220)
		y = y + DUMP_STAT_H + SUBHEADER_GAP - DUMP_STAT_GAP
	else
		set_alpha(s.dump_stat, 0)
		y = y + SUBHEADER_GAP
	end

	if entry.kind == "weapon" then
		for i = 1, 2 do
			local row = entry.rows[i]
			local icon_style = s["trait_" .. i]
			local name_style = s["row_" .. i .. "_name"]
			local desc_style = s["row_" .. i .. "_desc"]
			if row then
				set_pass_xy(icon_style, TOOLTIP_PADDING, y, TRAIT_SIZE, TRAIT_SIZE)
				if icon_style and icon_style.material_values then
					icon_style.material_values.icon = row.trait_path
				end
				if icon_style then icon_style.color[1] = 255 end
				set_pass_xy(name_style, ROW_TEXT_X, y, ROW_TEXT_W, ROW_NAME_H)
				set_alpha(name_style, 240)
				set_pass_xy(desc_style, ROW_TEXT_X, y + ROW_NAME_H, ROW_TEXT_W, ROW_DESC_H)
				set_alpha(desc_style, 200)
				y = y + ROW_HEIGHT + ROW_GAP
			else
				set_alpha(icon_style, 0)
				set_alpha(name_style, 0)
				set_alpha(desc_style, 0)
			end
		end
	else
		for i = 1, 2 do
			set_alpha(s["trait_" .. i], 0)
			set_alpha(s["row_" .. i .. "_name"], 0)
			set_alpha(s["row_" .. i .. "_desc"], 0)
		end
	end

	local sb = entry.secondary_block
	if sb and sb ~= "" then
		if entry.kind == "weapon" then y = y + ROW_GAP end
		local lines  = count_lines(sb)
		local height = math.max(SECONDARY_LINE_H, lines * SECONDARY_LINE_H)
		set_pass_xy(s.secondary_block, TOOLTIP_PADDING, y, content_w, height)
		set_alpha(s.secondary_block, 220)
		y = y + height
	else
		set_alpha(s.secondary_block, 0)
	end

	local total_h = math.min(TOOLTIP_MAX_H, y + TOOLTIP_PADDING)
	if s.background then s.background.size = { TOOLTIP_WIDTH, total_h } end
	if s.border_top then s.border_top.size = { TOOLTIP_WIDTH, 2 } end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- State management
-- ─────────────────────────────────────────────────────────────────────────────

local function get_state(inventory_view)
	if not inventory_view._lantern_overlay then
		inventory_view._lantern_overlay = {
			icons       = {},
			tooltip     = nil,
			last_preset = nil,
		}
	end
	return inventory_view._lantern_overlay
end

local function refresh_slot_data(state)
	local active_id = ProfileUtils.get_active_profile_preset_id()
	if state.last_preset == active_id then return end
	state.last_preset = active_id
	local store = mod._modules and mod._modules.equipment_store
	local eq    = store and store.get(active_id)
	for _, entry in ipairs(state.icons) do
		entry.data = eq and build_entry_for_slot(eq, entry.slot_name) or nil
	end
	state._last_hovered = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

function M.install(inventory_view)
	if not inventory_view._loadout_widgets then return end
	local state = get_state(inventory_view)
	state.icons = {}

	for _, loadout_widget in ipairs(inventory_view._loadout_widgets) do
		local element = loadout_widget.content and loadout_widget.content.element
		local slot    = element and element.slot
		if slot and table.contains(SLOTS, slot.name) then
			local sg_id = loadout_widget.scenegraph_id
			local slot_size = (loadout_widget.style and loadout_widget.style.size)
				or (loadout_widget.content and loadout_widget.content.size)
				or { 280, 140 }
			local def  = UIWidget.create_definition(icon_pass_template(), sg_id, nil, slot_size)
			local icon = UIWidget.init("lantern_icon_" .. slot.name, def)
			state.icons[#state.icons + 1] = {
				widget    = icon,
				slot_name = slot.name,
				data      = nil,
			}
		end
	end

	if not state.tooltip then
		local def     = UIWidget.create_definition(tooltip_pass_template(), "screen", nil,
			{ TOOLTIP_WIDTH, TOOLTIP_MAX_H })
		local tooltip = UIWidget.init("lantern_tooltip", def)
		tooltip.offset = { TOOLTIP_OFFSET[1], TOOLTIP_OFFSET[2], TOOLTIP_OFFSET[3] }
		state.tooltip = tooltip
	end

	state.last_preset   = nil
	state._last_hovered = nil
end

function M.draw(inventory_view, dt, t, input_service, ui_renderer)
	local state = inventory_view._lantern_overlay
	if not state or not state.icons or #state.icons == 0 then return end

	refresh_slot_data(state)

	UIRenderer.begin_pass(ui_renderer, inventory_view._ui_scenegraph, input_service, dt, inventory_view._render_settings)

	local hovered_entry
	for _, entry in ipairs(state.icons) do
		if entry.data then
			UIWidget.draw(entry.widget, ui_renderer)
			local hotspot = entry.widget.content and entry.widget.content.hotspot
			if hotspot and hotspot.is_hover then hovered_entry = entry end
		end
	end

	if hovered_entry and hovered_entry.data and state.tooltip then
		if hovered_entry ~= state._last_hovered then
			local c    = state.tooltip.content
			local data = hovered_entry.data
			c.header           = data.header
			c.subheader        = data.subheader
			c.dump_stat        = data.dump_stat or ""
			c.row_1_name       = (data.rows[1] and data.rows[1].name) or ""
			c.row_1_desc       = (data.rows[1] and data.rows[1].desc) or ""
			c.row_2_name       = (data.rows[2] and data.rows[2].name) or ""
			c.row_2_desc       = (data.rows[2] and data.rows[2].desc) or ""
			c.secondary_block  = data.secondary_block or ""
			layout_tooltip(state.tooltip, data)
			state._last_hovered = hovered_entry
		end
		UIWidget.draw(state.tooltip, ui_renderer)
	end

	UIRenderer.end_pass(ui_renderer)
end

function M.teardown(inventory_view)
	if inventory_view._lantern_overlay then
		inventory_view._lantern_overlay = nil
	end
end

return M
