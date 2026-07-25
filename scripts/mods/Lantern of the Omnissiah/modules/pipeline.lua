local mod = get_mod("Lantern of the Omnissiah")

local M = {}

function M.apply_build(ctx)
	local Popups = mod._modules.popups
	local Build  = mod._modules.build
	local Layout = mod._modules.layout
	local Archetypes = require("scripts/settings/archetype/archetypes")
	local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
	local ProfileUtils = require("scripts/utilities/profile_utils")
	local PresetsSettings = require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")

	local player = Managers.player and Managers.player:local_player(1)
	local profile = player and player:profile()
	if not profile then mod:notify(mod:localize("loc_lantern_toast_no_player")); return end

	local build, gl = Build.from_gl({
		archetype_slug = ctx.archetype_slug,
		anchors        = ctx.anchors,
		slug_to_talent = ctx.slug_to_talent,
		equipment      = ctx.equipment,
		title          = ctx.title,
	})
	local current_archetype_name = profile.archetype and profile.archetype.name
	local function pretty(name) local a = Archetypes[name]; return (a and a.archetype_name and Localize(a.archetype_name)) or name or "?" end
	if not build then
		Popups.error(mod:localize("loc_lantern_err_archetype_title"),
			mod:localize("loc_lantern_err_archetype_body", pretty(gl and gl.archetype), pretty(current_archetype_name)))
		return
	end
	if build.archetype ~= current_archetype_name then
		Popups.error(mod:localize("loc_lantern_err_archetype_title"),
			mod:localize("loc_lantern_err_archetype_body", pretty(build.archetype), pretty(current_archetype_name)))
		return
	end

	local layouts = Layout.archetype_layouts(profile.archetype)
	local node_tiers, over_budget = Build.budget_limit(build.node_tiers, profile)
	TalentLayoutParser.validate_talent_layouts(node_tiers, layouts, true)
	local applied = 0; for _ in pairs(node_tiers) do applied = applied + 1 end
	local skipped = gl.total_anchors - applied

	if applied == 0 then
		Popups.error(mod:localize("mod_name"), mod:localize("loc_lantern_err_no_resolved_body")); return
	end

	local effective_mode = ctx.mode
	if effective_mode == "overwrite_current" then
		local active_id = ProfileUtils.get_active_profile_preset_id()
		if not active_id or not ProfileUtils.get_profile_preset(active_id) then
			mod:notify(mod:localize("loc_lantern_toast_no_active_preset")); effective_mode = "new_preset"
		end
	end
	if effective_mode == "new_preset" then
		local cap = (PresetsSettings and PresetsSettings.max_profile_presets) or 8
		local presets = ProfileUtils.get_profile_presets() or {}
		if #presets >= cap then
			Popups.error(mod:localize("loc_lantern_err_capacity_title"),
				mod:localize("loc_lantern_err_capacity_body", #presets, cap)); return
		end
	end

	local action_line = (effective_mode == "overwrite_current")
		and mod:localize("loc_lantern_confirm_apply_overwrite", applied, gl.total_anchors)
		or  mod:localize("loc_lantern_confirm_apply_new", applied, gl.total_anchors)
	local build_line = ctx.title or "(untitled)"
	if build.author and build.author ~= "" then build_line = build_line .. " by " .. build.author end
	local body_lines = { mod:localize("loc_lantern_confirm_build_line", build_line), "", action_line }
	if over_budget > 0 then
		body_lines[#body_lines + 1] = ""
		body_lines[#body_lines + 1] = mod:localize("loc_lantern_confirm_warn_underleveled", over_budget, gl.total_anchors)
	end
	local other_skipped = gl.unresolved_slug + gl.unknown_talent
	if other_skipped > 0 then
		body_lines[#body_lines+1] = ""; body_lines[#body_lines+1] = mod:localize("loc_lantern_confirm_skip_other", other_skipped, gl.unresolved_slug, gl.unknown_talent)
	end

	local display_title = ctx.title or mod:localize("loc_lantern_confirm_title_default")
	build.title = ctx.title
	build.node_tiers = node_tiers

	local on_confirm = function()
		if effective_mode == "overwrite_current" then
			local id = Build.to_preset(build, "overwrite_current")
			mod:notify(mod:localize("loc_lantern_toast_overwrote", display_title, applied, skipped))
			mod.dbg("[import] overwrote preset %s with %d talents", tostring(id), applied)
		else
			local new_id = Build.to_preset(build, "new_preset")
			mod:notify(mod:localize("loc_lantern_toast_imported", display_title, applied, skipped))
			mod.dbg("[import] created preset %s with %d talents", tostring(new_id), applied)
		end
	end

	if mod:get("skip_confirm") then on_confirm() else Popups.confirm(display_title, table.concat(body_lines, "\n"), on_confirm) end
end

return M
