local mod = get_mod("Lantern of the Omnissiah")

local Archetypes          = require("scripts/settings/archetype/archetypes")
local ProfileUtils        = require("scripts/utilities/profile_utils")
local TalentLayoutParser  = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local PresetsSettings     = require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")

local SLUG_TO_ARCHETYPE = {
	arbites      = "adamant",
	["hive-scum"] = "broker",
	skitarii     = "cryptic",
}

local M = {}

function M.apply_build(ctx)
	local Layout = mod._modules.layout
	local Popups = mod._modules.popups
	local Preset = mod._modules.preset

	local player = Managers.player and Managers.player:local_player(1)
	local profile = player and player:profile()
	if not profile then
		mod:notify(mod:localize("loc_lantern_toast_no_player"))
		return
	end

	local build_archetype_name = SLUG_TO_ARCHETYPE[ctx.archetype_slug] or ctx.archetype_slug
	local current_archetype_name = profile.archetype and profile.archetype.name
	if build_archetype_name ~= current_archetype_name then
		local function pretty_archetype(arch_name)
			local a = Archetypes[arch_name]
			return (a and a.archetype_name and Localize(a.archetype_name)) or arch_name or "?"
		end
		Popups.error(
			mod:localize("loc_lantern_err_archetype_title"),
			mod:localize("loc_lantern_err_archetype_body",
				pretty_archetype(build_archetype_name),
				pretty_archetype(current_archetype_name)))
		return
	end

	local archetype = profile.archetype
	local layouts   = Layout.archetype_layouts(archetype)
	local lookup    = Layout.build_talent_lookup(layouts)

	local node_tiers = {}
	local cost_per_layout = { 0, 0 }
	local base_budget = profile.talent_points or 0
	local spec_budget = profile.expertise_points or 0
	local budgets = { base_budget, spec_budget }

	local applied, unresolved_slug, unknown_talent, over_budget = 0, 0, 0, 0
	for _, a in ipairs(ctx.anchors) do
		local talent_id = ctx.slug_to_talent[a.slug]
		if not talent_id then
			unresolved_slug = unresolved_slug + 1
			mod.dbg("[apply] no talent_id for slug %s", a.slug)
		else
			local info = lookup[talent_id]
			if not info then
				unknown_talent = unknown_talent + 1
				mod.dbg("[apply] no layout node for talent %s (slug=%s)", talent_id, a.slug)
			else
				local idx = info.layout_index
				if cost_per_layout[idx] + info.cost <= budgets[idx] then
					node_tiers[info.widget_name] = 1
					cost_per_layout[idx] = cost_per_layout[idx] + info.cost
					applied = applied + 1
				else
					over_budget = over_budget + 1
					mod.dbg("[apply] over budget, skipping talent %s (slug=%s)", talent_id, a.slug)
				end
			end
		end
	end
	mod.dbg("[apply] resolved=%d unresolved_slug=%d unknown_talent=%d over_budget=%d cost={base=%d,spec=%d}",
		applied, unresolved_slug, unknown_talent, over_budget,
		cost_per_layout[1], cost_per_layout[2])

	local before = applied
	TalentLayoutParser.validate_talent_layouts(node_tiers, layouts, true)
	local after = 0
	for _ in pairs(node_tiers) do after = after + 1 end
	local validator_dropped = before - after
	if validator_dropped > 0 then
		mod:warning("[apply] validator dropped %d nodes (orphaned by unresolved stat parents)", validator_dropped)
	end
	applied = after
	local skipped = #ctx.anchors - applied
	mod.dbg("[apply] FINAL applied=%d skipped=%d", applied, skipped)

	if applied == 0 then
		Popups.error(mod:localize("mod_name"), mod:localize("loc_lantern_err_no_resolved_body"))
		return
	end

	local effective_mode = ctx.mode
	if effective_mode == "overwrite_current" then
		local active_id = ProfileUtils.get_active_profile_preset_id()
		if not active_id or not ProfileUtils.get_profile_preset(active_id) then
			mod:notify(mod:localize("loc_lantern_toast_no_active_preset"))
			effective_mode = "new_preset"
		end
	end
	if effective_mode == "new_preset" then
		local cap = (PresetsSettings and PresetsSettings.max_profile_presets) or 8
		local presets = ProfileUtils.get_profile_presets() or {}
		if #presets >= cap then
			Popups.error(
				mod:localize("loc_lantern_err_capacity_title"),
				mod:localize("loc_lantern_err_capacity_body", #presets, cap))
			return
		end
	end

	local action_line
	if effective_mode == "overwrite_current" then
		action_line = mod:localize("loc_lantern_confirm_apply_overwrite", applied, #ctx.anchors)
	else
		action_line = mod:localize("loc_lantern_confirm_apply_new", applied, #ctx.anchors)
	end
	local author     = ctx.equipment and ctx.equipment.author
	local build_line = ctx.title or "(untitled)"
	if author and author ~= "" then
		build_line = build_line .. " by " .. author
	end
	local body_lines = {
		mod:localize("loc_lantern_confirm_build_line", build_line),
		"",
		action_line,
	}

	if over_budget > 0 then
		body_lines[#body_lines + 1] = ""
		body_lines[#body_lines + 1] = mod:localize("loc_lantern_confirm_warn_underleveled", over_budget, #ctx.anchors)
	end
	local other_skipped = unresolved_slug + unknown_talent
	if other_skipped > 0 then
		body_lines[#body_lines + 1] = ""
		body_lines[#body_lines + 1] = mod:localize("loc_lantern_confirm_skip_other", other_skipped, unresolved_slug, unknown_talent)
	end

	local display_title = ctx.title or mod:localize("loc_lantern_confirm_title_default")
	local preset_name   = ctx.title
	local body_text     = table.concat(body_lines, "\n")
	local talents_version = TalentLayoutParser.talents_version(profile)

	local on_confirm = function()
		if effective_mode == "overwrite_current" then
			local id = Preset.overwrite_active_with_talents(node_tiers, talents_version, preset_name, ctx.equipment)
			mod:notify(mod:localize("loc_lantern_toast_overwrote", display_title, applied, skipped))
			mod.dbg("[import] overwrote preset %s with %d talents", tostring(id), applied)
		else
			local new_id = Preset.create_with_talents(node_tiers, talents_version, preset_name, ctx.equipment)
			mod:notify(mod:localize("loc_lantern_toast_imported", display_title, applied, skipped))
			mod.dbg("[import] created preset %s with %d talents", tostring(new_id), applied)
		end
	end

	if mod:get("skip_confirm") then
		on_confirm()
	else
		Popups.confirm(display_title, body_text, on_confirm)
	end
end

return M
