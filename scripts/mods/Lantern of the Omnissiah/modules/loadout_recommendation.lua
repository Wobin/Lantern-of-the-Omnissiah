local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local WEAPON_SLOTS = { "slot_primary", "slot_secondary" }
local CURIO_SLOTS  = { "slot_attachment_1", "slot_attachment_2", "slot_attachment_3" }
local CURIO_KEYWORDS = { "health", "toughness", "stamina", "wound" }

local function weapon_entry(it, deps)
  local ItemUtils, MasterItems, WeaponTemplates, strip_values =
    deps.ItemUtils, deps.MasterItems, deps.WeaponTemplates, deps.strip_values

  local blessings = {}
  for _, tr in ipairs(it.traits or {}) do
    local mi = MasterItems.get_item(tr.id)
    local n = mi and mi.icon and tostring(mi.icon):match("weapon_trait_(%d+)")
    local desc = mi and ItemUtils.trait_description and ItemUtils.trait_description(mi, tr.rarity, tr.value)
    local bname = mi and ItemUtils.display_name(mi)
    blessings[#blessings + 1] = { trait_id = n, name = bname, description = desc or "" }
  end

  local perks = {}
  for _, p in ipairs(it.perks or {}) do
    local mi = MasterItems.get_item(p.id)
    local desc = mi and ItemUtils.trait_description and ItemUtils.trait_description(mi, p.rarity, p.value)
    perks[#perks + 1] = strip_values(desc or "")
  end

  local stats = {}
  local ok, tmpl = pcall(WeaponTemplates.weapon_template_from_item, it)
  if ok and tmpl and tmpl.base_stats then
    local disp = {}
    for stat_name, cfg in pairs(tmpl.base_stats) do
      if cfg.display_name then disp[stat_name] = Localize(cfg.display_name) end
    end
    for _, s in ipairs(it.base_stats or {}) do
      local d = disp[s.name]
      if d then stats[#stats + 1] = { name = d, value = math.floor((tonumber(s.value) or 0) * 100 + 0.5) } end
    end
  end

  return {
    name = ItemUtils.display_name(it), rarity = it.rarity or 5,
    perks = perks, blessings = blessings, stats = stats,
  }
end

local function curio_entry(it, deps)
  local ItemUtils, MasterItems, strip_values = deps.ItemUtils, deps.MasterItems, deps.strip_values
  local mi = MasterItems.get_item(it.name)
  local name = (mi and mi.display_name and Localize(mi.display_name)) or ItemUtils.display_name(it) or ""
  local stat_txt = (ItemUtils.display_name(it) or ""):lower()
  local primary
  for _, k in ipairs(CURIO_KEYWORDS) do if stat_txt:find(k, 1, true) then primary = k; break end end
  local secondary = {}
  for _, p in ipairs(it.perks or {}) do
    local pmi = MasterItems.get_item(p.id)
    local desc = pmi and ItemUtils.trait_description and ItemUtils.trait_description(pmi, p.rarity, p.value)
    secondary[#secondary + 1] = strip_values(desc or "")
  end
  return { name = name, rarity = it.rarity or 5, primary = primary, secondary = secondary }
end

function M.build(profile)
  local deps = {
    ItemUtils = require("scripts/utilities/items"),
    MasterItems = require("scripts/backend/master_items"),
    WeaponTemplates = require("scripts/utilities/weapon/weapon_template"),
    strip_values = mod._modules.strip_values,
  }
  local lo = profile and profile.loadout or {}
  local weapons, curios = {}, {}
  for _, slot in ipairs(WEAPON_SLOTS) do
    local it = lo[slot]
    if it and it.name then weapons[#weapons + 1] = weapon_entry(it, deps) end
  end
  for _, slot in ipairs(CURIO_SLOTS) do
    local it = lo[slot]
    if it and it.name then curios[#curios + 1] = curio_entry(it, deps) end
  end
  return { weapons = weapons, curios = curios }
end

return M
