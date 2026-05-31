-- Preset save operations. Mirrors the vanilla "+ new preset" sequence
-- (event_player_save_changes_to_current_preset → add_profile_preset →
-- event_on_player_preset_created → save_talent_nodes_for_profile_preset) and
-- handles the optional LoadoutNames integration.

local ProfileUtils = require("scripts/utilities/profile_utils")

local M = {}

-- Optional integration: if mods\LoadoutNames is installed, sets the per-preset
-- display name shown in the preset bar tooltip. No-op when absent.
function M.set_loadout_name(preset_id, name)
	local LN = get_mod("LoadoutNames")
	if LN and type(LN.set_loadout_name) == "function" then
		LN.set_loadout_name(preset_id, name)
	end
end

function M.create_with_talents(node_tiers, talents_version, build_title)
	Managers.event:trigger("event_player_save_changes_to_current_preset")
	local new_id = ProfileUtils.add_profile_preset()
	Managers.event:trigger("event_on_player_preset_created", new_id)
	ProfileUtils.save_talent_nodes_for_profile_preset(new_id, node_tiers, talents_version)
	M.set_loadout_name(new_id, build_title)
	return new_id
end

function M.overwrite_active_with_talents(node_tiers, talents_version, build_title)
	local active_id = ProfileUtils.get_active_profile_preset_id()
	if not active_id or not ProfileUtils.get_profile_preset(active_id) then return nil end
	Managers.event:trigger("event_player_save_changes_to_current_preset")
	ProfileUtils.save_talent_nodes_for_profile_preset(active_id, node_tiers, talents_version)
	M.set_loadout_name(active_id, build_title)
	Managers.event:trigger("event_on_profile_preset_changed", ProfileUtils.get_profile_preset(active_id))
	return active_id
end

return M
