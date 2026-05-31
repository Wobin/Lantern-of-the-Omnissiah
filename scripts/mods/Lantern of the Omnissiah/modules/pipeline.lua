-- The post-resolution pipeline: takes a fully-resolved set of anchors with
-- their slug → talent_id mappings and:
--   1. Archetype-gates against the active character
--   2. Resolves talent_ids to widget_names via the layout lookup
--   3. Budget-checks per layout
--   4. Sanity-validates dependency chains
--   5. Renders the confirmation popup
--   6. On confirm, writes the preset (new or overwrite)
--
-- Inter-module deps (Layout / Popups / Preset) are read lazily from mod._modules
-- at call time so this file has no load-order coupling.

local mod = get_mod("Lantern of the Omnissiah")

local Archetypes          = require("scripts/settings/archetype/archetypes")
local ProfileUtils        = require("scripts/utilities/profile_utils")
local TalentLayoutParser  = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local PresetsSettings     = require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")

local SLUG_TO_ARCHETYPE = {
	arbites      = "adamant",
	["hive-scum"] = "broker",
}

local M = {}

-- ctx = {
--   title           : string,
--   archetype_slug  : string,            -- gameslantern URL slug
--   anchors         : array of { slug, talent_id_or_nil },
--   slug_to_talent  : map slug → talent_id (resolved via inline pairs + cache + phase-2),
--   mode            : "new_preset" | "overwrite_current",
--   url             : string,
--   on_handled      : optional callback, called when import succeeds in new_preset mode
--                     (used to set _last_handled_url for session memoisation)
-- }
function M.apply_build(ctx)
	local Layout = mod._modules.layout
	local Popups = mod._modules.popups
	local Preset = mod._modules.preset

	local player = Managers.player and Managers.player:local_player(1)
	local profile = player and player:profile()
	if not profile then
		mod:notify("Lantern: no local player profile yet — try again in a moment")
		return
	end

	-- Archetype gate.
	local build_archetype_name = SLUG_TO_ARCHETYPE[ctx.archetype_slug] or ctx.archetype_slug
	local current_archetype_name = profile.archetype and profile.archetype.name
	if build_archetype_name ~= current_archetype_name then
		local current_pretty = (profile.archetype and profile.archetype.archetype_name) or current_archetype_name or "?"
		local build_pretty   = (Archetypes[build_archetype_name] and Archetypes[build_archetype_name].archetype_name) or build_archetype_name
		Popups.error("Wrong archetype",
			string.format("This build is for %s; your current character is %s. Switch character and try again.",
				build_pretty, current_pretty))
		return
	end

	local archetype = profile.archetype
	local layouts   = Layout.archetype_layouts(archetype)
	local lookup    = Layout.build_talent_lookup(layouts)

	-- Resolve every anchor's slug → talent_id → widget_name. Slug → talent_id
	-- comes from the shipped slug cache (built offline via
	-- tools/build_slug_cache.ps1); anything not in the cache is skipped and the
	-- validator drops orphan children.

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
			mod:info("[apply] no talent_id for slug %s", a.slug)
		else
			local info = lookup[talent_id]
			if not info then
				unknown_talent = unknown_talent + 1
				mod:info("[apply] no layout node for talent %s (slug=%s)", talent_id, a.slug)
			else
				local idx = info.layout_index
				if cost_per_layout[idx] + info.cost <= budgets[idx] then
					node_tiers[info.widget_name] = 1
					cost_per_layout[idx] = cost_per_layout[idx] + info.cost
					applied = applied + 1
				else
					over_budget = over_budget + 1
					mod:info("[apply] over budget, skipping talent %s (slug=%s)", talent_id, a.slug)
				end
			end
		end
	end
	mod:info("[apply] resolved=%d unresolved_slug=%d unknown_talent=%d over_budget=%d cost={base=%d,spec=%d}",
		applied, unresolved_slug, unknown_talent, over_budget,
		cost_per_layout[1], cost_per_layout[2])

	-- Strict slug retrieval — no autocomplete fallback. Anything we couldn't
	-- resolve to a specific in-game talent_id stays out of the preset, even if
	-- that orphans some icon-bearing children (the validator will drop them).
	-- Fidelity to the source build trumps completeness.
	local before = 0
	for _ in pairs(node_tiers) do before = before + 1 end
	TalentLayoutParser.validate_talent_layouts(node_tiers, layouts, true)
	local after = 0
	for _ in pairs(node_tiers) do after = after + 1 end
	local validator_dropped = before - after
	if validator_dropped > 0 then
		mod:warning("[apply] validator dropped %d nodes (orphaned by unresolved stat parents)", validator_dropped)
	end
	applied = after
	local skipped = #ctx.anchors - applied
	mod:info("[apply] FINAL applied=%d skipped=%d", applied, skipped)

	if applied == 0 then
		Popups.error("Lantern of the Omnissiah", "None of the talents on that page could be resolved.")
		return
	end

	-- Resolve destination mode.
	local effective_mode = ctx.mode
	if effective_mode == "overwrite_current" then
		local active_id = ProfileUtils.get_active_profile_preset_id()
		if not active_id or not ProfileUtils.get_profile_preset(active_id) then
			mod:notify("Lantern: no active preset to overwrite — creating a new one")
			effective_mode = "new_preset"
		end
	end
	if effective_mode == "new_preset" then
		local cap = (PresetsSettings and PresetsSettings.max_profile_presets) or 8
		local presets = ProfileUtils.get_profile_presets() or {}
		if #presets >= cap then
			Popups.error("Preset slots full",
				string.format("Preset slots are full (%d/%d). Delete a preset or use Re-check Clipboard to overwrite the current one.", #presets, cap))
			return
		end
	end

	local action_line
	if effective_mode == "overwrite_current" then
		action_line = string.format("Overwrite the current preset's talents with %d of %d from this build?", applied, #ctx.anchors)
	else
		action_line = string.format("Apply %d of %d talents to a new preset slot?", applied, #ctx.anchors)
	end
	local body_lines = {
		string.format("Build: %s", ctx.title or "(untitled)"),
		"",
		action_line,
	}
	if skipped > 0 then
		body_lines[#body_lines + 1] = ""
		body_lines[#body_lines + 1] = string.format("%d talents will be skipped (%d unresolved, %d unknown, %d over budget).",
			skipped, unresolved_slug, unknown_talent, over_budget)
	end

	local title_text = ctx.title or "Import gameslantern build"
	local body_text  = table.concat(body_lines, "\n")
	local talents_version = TalentLayoutParser.talents_version(profile)
	local build_title_for_preset = ctx.title or "Imported build"

	Popups.confirm(title_text, body_text, function()
		if effective_mode == "overwrite_current" then
			local id = Preset.overwrite_active_with_talents(node_tiers, talents_version, build_title_for_preset)
			mod:notify(string.format("Lantern: overwrote current preset with '%s' — %d talents applied (%d skipped)",
				build_title_for_preset, applied, skipped))
			mod:info("[import] overwrote preset %s with %d talents", tostring(id), applied)
		else
			local new_id = Preset.create_with_talents(node_tiers, talents_version, build_title_for_preset)
			mod:notify(string.format("Lantern: imported '%s' — %d talents applied (%d skipped)",
				build_title_for_preset, applied, skipped))
			mod:info("[import] created preset %s with %d talents", tostring(new_id), applied)
			if ctx.on_handled then ctx.on_handled(ctx.url) end
		end
	end)
end

return M
