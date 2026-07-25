local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local _state = mod:persistent_table("staged_build_state", { build = nil })

function M.set(build) _state.build = build end
function M.get() return _state.build end
function M.clear() _state.build = nil end

return M
