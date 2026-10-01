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

local function connect_index(layouts)
  local by_name = {}
  for _, lay in ipairs(layouts) do
    for _, n in ipairs(lay.nodes) do by_name[n.widget_name] = n end
  end
  return by_name
end

local function is_start_node(n) return n ~= nil and n.type == "start" end

local function exclusive_group_of(n)
  local g = n and n.requirements and n.requirements.exclusive_group
  if g and g ~= "" then return g end
  return nil
end

local function path_to_connected(wn, by_name, is_stop, is_free, is_blocked)
  local INF = math.huge
  local dist, prev, done = { [wn] = 0 }, {}, {}
  while true do
    local u, ud = nil, INF
    for node, d in pairs(dist) do
      if not done[node] and d < ud then u, ud = node, d end
    end
    if not u then return nil end
    done[u] = true
    if u ~= wn and is_stop(u) then
      local path, cur = {}, prev[u]
      while cur and cur ~= wn do
        if not is_free(cur) then path[#path + 1] = cur end
        cur = prev[cur]
      end
      return path
    end
    local node = by_name[u]
    if node then
      for _, p in ipairs(node.parents or {}) do
        if by_name[p] and not done[p] and not is_blocked(p) then
          local nd = ud + (is_free(p) and 0 or 1)
          if nd < (dist[p] or INF) then dist[p] = nd; prev[p] = u end
        end
      end
    end
  end
end

function M._connect(node_tiers, layouts)
  local by_name = connect_index(layouts)
  local selected = {}
  for wn, tier in pairs(node_tiers or {}) do selected[wn] = tier end
  local occupied = {}
  for wn in pairs(selected) do
    local g = exclusive_group_of(by_name[wn])
    if g then occupied[g] = wn end
  end
  local function is_blocked(p)
    local g = exclusive_group_of(by_name[p])
    return g ~= nil and occupied[g] ~= nil and occupied[g] ~= p
  end
  local function reachable()
    local reach, changed = {}, true
    while changed do
      changed = false
      for wn in pairs(selected) do
        if not reach[wn] then
          local n = by_name[wn]
          if n then
            for _, p in ipairs(n.parents or {}) do
              local pn = by_name[p]
              if pn and (is_start_node(pn) or (selected[p] and reach[p])) then
                reach[wn] = true; changed = true; break
              end
            end
          end
        end
      end
    end
    return reach
  end
  local added, guard = 0, 0
  while true do
    guard = guard + 1
    if guard > 100000 then break end
    local reach = reachable()
    local target
    for wn in pairs(selected) do
      if by_name[wn] and not reach[wn] then target = wn; break end
    end
    if not target then break end
    local function is_stop(p)
      return is_start_node(by_name[p]) or (selected[p] and reach[p])
    end
    local function is_free(p)
      return is_start_node(by_name[p]) or selected[p] ~= nil
    end
    local path = path_to_connected(target, by_name, is_stop, is_free, is_blocked)
    if path then
      for _, wn in ipairs(path) do
        if not selected[wn] then
          selected[wn] = M.NODE_TIER; added = added + 1
          local g = exclusive_group_of(by_name[wn])
          if g and not occupied[g] then occupied[g] = wn end
        end
      end
    else
      selected[target] = nil
    end
  end
  return selected, added
end

function M.connect_selection(node_tiers, profile)
  local Layout = mod._modules.layout
  local layouts = Layout.archetype_layouts(profile.archetype)
  return M._connect(node_tiers, layouts)
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
    patch_id = Maps.PATCH_ID,
  })
  counts.skipped = skipped
  return json, counts
end

return M
