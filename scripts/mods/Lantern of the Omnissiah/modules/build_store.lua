local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local function bkey(id) return id and ("build_" .. tostring(id)) or nil end
local function ekey(id) return id and ("equipment_" .. tostring(id)) or nil end
local function tkey(id) return id and ("talent_target_" .. tostring(id)) or nil end

function M.get(preset_id)
  local k = bkey(preset_id)
  if not k then return nil end
  local rec = mod:get(k)
  if rec then return rec end
  local eq = mod:get(ekey(preset_id))
  local ts = mod:get(tkey(preset_id))
  if not eq and not ts then return nil end
  rec = {
    equipment  = eq,
    target_set = ts,
    title      = eq and eq.title,
    source     = "gameslantern",
  }
  mod:set(k, rec)
  return rec
end

function M.set(preset_id, stored)
  local k = bkey(preset_id)
  if not k then return end
  mod:set(k, stored)
end

function M.clear(preset_id)
  if not preset_id then return end
  mod:set(bkey(preset_id), nil)
  mod:set(ekey(preset_id), nil)
  mod:set(tkey(preset_id), nil)
end

function M.equipment(preset_id)
  local r = M.get(preset_id); return r and r.equipment
end

function M.target_set(preset_id)
  local r = M.get(preset_id); return r and r.target_set
end

return M
