local mod = get_mod("Lantern of the Omnissiah")

local M = {}
M.NODE_TIER = 1

function M.from_profile(player)
  local profile = player and player:profile()
  if not profile then return nil end
  local Layout = mod._modules.layout
  local archetype_name = profile.archetype and profile.archetype.name
  local layouts = Layout.archetype_layouts(profile.archetype)
  local cost_of = {}
  for _, lay in ipairs(layouts) do
    for _, n in ipairs(lay.nodes) do cost_of[n.widget_name] = n.cost or 0 end
  end
  local node_tiers, target_set = {}, {}
  for widget_name, tier in pairs(profile.selected_nodes or {}) do
    if tier and tier > 0 and (cost_of[widget_name] or 0) > 0 then
      node_tiers[widget_name] = M.NODE_TIER
      target_set[widget_name] = true
    end
  end
  local local_player = Managers.player and Managers.player:local_player(1)
  local source = (player == local_player) and "self" or "teammate"
  local char = profile.name
  local title
  if source == "teammate" and char and char ~= "" then
    title = mod:localize("loc_lantern_export_named", tostring(char), tostring(archetype_name))
  else
    title = mod:localize("loc_lantern_export_default_name", tostring(archetype_name))
  end
  return {
    archetype  = archetype_name,
    node_tiers = node_tiers,
    target_set = target_set,
    equipment  = mod._modules.loadout_recommendation.build(profile),
    title      = title,
    author     = nil,
    source     = source,
  }
end
local SLUG_TO_ARCHETYPE = {
  arbites       = "adamant",
  ["hive-scum"] = "broker",
  skitarii      = "cryptic",
}

function M.from_gl(parsed)
  local Layout = mod._modules.layout
  local Archetypes = require("scripts/settings/archetype/archetypes")
  local archetype_name = SLUG_TO_ARCHETYPE[parsed.archetype_slug] or parsed.archetype_slug
  local arch = Archetypes[archetype_name]
  if not arch then return nil, { reason = "unknown_archetype", archetype = archetype_name } end
  local layouts = Layout.archetype_layouts(arch)
  local lookup = Layout.build_talent_lookup(layouts)
  local target_set = {}
  local unresolved_slug, unknown_talent = 0, 0
  for _, a in ipairs(parsed.anchors or {}) do
    local talent_id = parsed.slug_to_talent[a.slug]
    if not talent_id then
      unresolved_slug = unresolved_slug + 1
    else
      local info = lookup[talent_id]
      if not info then unknown_talent = unknown_talent + 1
      else target_set[info.widget_name] = true end
    end
  end
  local node_tiers = {}
  for wn in pairs(target_set) do node_tiers[wn] = M.NODE_TIER end
  local build = {
    archetype  = archetype_name,
    node_tiers = node_tiers,
    target_set = target_set,
    equipment  = parsed.equipment,
    title      = parsed.title,
    author     = parsed.equipment and parsed.equipment.author,
    source     = "gameslantern",
  }
  local counts = { unresolved_slug = unresolved_slug, unknown_talent = unknown_talent, total_anchors = #(parsed.anchors or {}) }
  return build, counts
end

function M.to_preset(build, mode, opts)
  local Preset = mod._modules.preset
  local BS = mod._modules.build_store
  local local_player = Managers.player and Managers.player:local_player(1)
  local profile = local_player and local_player:profile()
  if not profile then return nil end
  local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
  local talents_version = TalentLayoutParser.talents_version(profile)
  local id
  if mode == "overwrite_current" then
    id = Preset.overwrite_active_with_talents(build.node_tiers, talents_version, build.title, build.equipment)
  else
    id = Preset.create_with_talents(build.node_tiers, talents_version, build.title, build.equipment)
  end
  if id then
    BS.set(id, { equipment = build.equipment, target_set = build.target_set, title = build.title, source = build.source })
  end
  return id
end

function M.budget_limit(node_tiers, profile)
  local Layout = mod._modules.layout
  local layouts = Layout.archetype_layouts(profile.archetype)
  local budgets = { profile.talent_points or 0, profile.expertise_points or 0 }
  local total_in = 0
  for _ in pairs(node_tiers or {}) do total_in = total_in + 1 end
  local limited, applied = {}, 0
  for li = 1, #layouts do
    local layout = layouts[li]
    local budget = budgets[li] or 0
    local by_name = {}
    for _, n in ipairs(layout.nodes) do by_name[n.widget_name] = n end
    local pending = {}
    for wn in pairs(node_tiers or {}) do
      if by_name[wn] then pending[wn] = by_name[wn] end
    end
    local function parent_ok(node)
      for _, p in ipairs(node.parents or {}) do
        local pn = by_name[p]
        if pn and (pn.type == "start" or limited[p]) then return true end
      end
      return false
    end
    local spent, progress = 0, true
    while progress and spent < budget do
      progress = false
      local elig = {}
      for wn, n in pairs(pending) do
        if parent_ok(n) then elig[#elig + 1] = wn end
      end
      table.sort(elig)
      for _, wn in ipairs(elig) do
        if spent >= budget then break end
        local c = pending[wn].cost or 0
        if spent + c <= budget then
          limited[wn] = M.NODE_TIER
          spent = spent + c
          applied = applied + 1
          pending[wn] = nil
          progress = true
        end
      end
    end
  end
  return limited, total_in - applied, applied
end

function M.to_gl_json(build, opts)
  opts = opts or {}
  local Export = mod._modules.export
  local Maps = mod._modules.export_maps
  local Layout = mod._modules.layout
  local Archetypes = require("scripts/settings/archetype/archetypes")
  local class_id = build.archetype and Maps.CLASS_MAP[build.archetype]
  local class_nodes = build.archetype and Maps.TALENT_NODES[build.archetype]
  if not class_id or not class_nodes then return nil, nil, "no_map" end
  local arch = Archetypes[build.archetype]
  local layouts = Layout.archetype_layouts(arch)
  local all_nodes = {}
  for _, lay in ipairs(layouts) do for _, n in ipairs(lay.nodes) do all_nodes[#all_nodes + 1] = n end end
  local layout_index = Export._layout_index(all_nodes)
  local selected = {}
  for widget_name in pairs(build.node_tiers or {}) do selected[#selected + 1] = widget_name end
  local ids_default, ids_stimm, skipped = Export._resolve(selected, layout_index, class_nodes)
  local json, counts = Export.assemble({
    name = build.title, class_id = class_id,
    ids_default = ids_default, ids_stimm = ids_stimm,
    weapons = opts.weapons or {}, curios = opts.curios or {},
  })
  counts.skipped = skipped
  return json, counts
end

return M
