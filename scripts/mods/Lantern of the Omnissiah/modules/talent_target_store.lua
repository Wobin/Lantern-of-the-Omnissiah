local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local function key(preset_id)
	return preset_id and ("talent_target_" .. tostring(preset_id)) or nil
end

function M.set(preset_id, widget_set)
	local k = key(preset_id)
	if not k then return end
	mod:set(k, widget_set)
end

function M.get(preset_id)
	local k = key(preset_id)
	if not k then return nil end
	return mod:get(k)
end

function M.clear(preset_id)
	local k = key(preset_id)
	if not k then return end
	mod:set(k, nil)
end

return M
