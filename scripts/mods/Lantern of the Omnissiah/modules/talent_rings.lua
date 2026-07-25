local mod = get_mod("Lantern of the Omnissiah")
local UIWidget = require("scripts/managers/ui/ui_widget")

local M = {}

local RING_STYLE_ID = "lantern_build_ring"
local RING_COLOR    = { 255, 255, 140, 0 }
local RING_OFFSET_Z = -10
local RING_GROW     = 16
local DEFAULT_GLOW  = "content/ui/materials/frames/talents/circular_frame_glow"

local _state = mod:persistent_table("talent_rings_state", { target = {}, enabled = true, active = false })

local NODE_DEF_NAMES = {
	"node_definition",
	"node_definition_start",
	"node_definition_stat",
	"node_definition_tactical",
	"node_definition_tactical_modifier",
	"node_definition_ability",
	"node_definition_ability_modifier",
	"node_definition_aura",
	"node_definition_keystone",
}

local function ring_visible(content)
	if not _state.enabled then return false end
	if not _state.active then return false end
	local nd = content.node_data
	if not nd then return false end
	if not _state.target[nd.widget_name] then return false end
	return not content.has_points_spent
end

local function glow_value_of(def)
	local passes  = def and def.passes
	local content = def and def.content
	if not passes or not content then return DEFAULT_GLOW end
	for i = 1, #passes do
		local vid = passes[i].value_id
		local v = vid and content[vid]
		if type(v) == "string" and v:find("_glow", 1, true) then
			return v
		end
	end
	return DEFAULT_GLOW
end

local function already_injected(def)
	local passes = def and def.passes
	if not passes then return false end
	for i = 1, #passes do
		if passes[i].style_id == RING_STYLE_ID then return true end
	end
	return false
end

local function inject(def)
	if not def or not def.passes then return false end
	if already_injected(def) then return true end
	local glow = glow_value_of(def)
	UIWidget.add_definition_pass(def, {
		pass_type = "texture",
		style_id  = RING_STYLE_ID,
		value     = glow,
		style = {
			horizontal_alignment = "center",
			vertical_alignment   = "center",
			offset        = { 0, 0, RING_OFFSET_Z },
			size_addition = { RING_GROW, RING_GROW },
			color         = { RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], RING_COLOR[4] },
		},
		visibility_function = ring_visible,
	})
	return true
end

function M.install()
	_state.active = false
	local ok, node_defs = pcall(require, "scripts/ui/views/talent_builder_view/talent_builder_view_node_definitions")
	if not ok or not node_defs then
		mod:warning("[rings] node_definitions unavailable; rings disabled")
		return
	end
	local injected, skipped = 0, 0
	for _, name in ipairs(NODE_DEF_NAMES) do
		local iok, res = pcall(inject, node_defs[name])
		if iok and res then injected = injected + 1 else skipped = skipped + 1 end
	end
	mod.dbg("[rings] install injected=%d skipped=%d", injected, skipped)
end

function M.set_target(widget_set)
	_state.target = widget_set or {}
end

function M.set_enabled(v)
	_state.enabled = v and true or false
end

function M.set_active(v)
	_state.active = v and true or false
end

return M
