local mod = get_mod("Lantern of the Omnissiah")
local ProfileUtils  = require("scripts/utilities/profile_utils")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local M = {}

local function EquipmentStore()
	return mod._modules and mod._modules.equipment_store
end

function M.set_loadout_name(preset_id, name)
	if not name or name == "" then return end
	local LN = get_mod("LoadoutNames")
	if LN and type(LN.set_loadout_name) == "function" then
		LN.set_loadout_name(preset_id, name)
	end
end

local function update_loadout_name_textbox(name)
	if not name or name == "" then return end
	local inv_view = Managers.ui and Managers.ui:view_instance("inventory_background_view")
	if not inv_view then return end
	local presets_elem = inv_view._profile_presets_element
	if not presets_elem or not presets_elem._widgets_by_name then return end
	local tbox = presets_elem._widgets_by_name.loadout_name_tbox
	if tbox and tbox.content then
		tbox.content.input_text = name
	end
end

function M.create_with_talents(node_tiers, talents_version, build_title, equipment)
	Managers.event:trigger("event_player_save_changes_to_current_preset")
	local new_id = ProfileUtils.add_profile_preset()
	Managers.event:trigger("event_on_player_preset_created", new_id)
	ProfileUtils.save_talent_nodes_for_profile_preset(new_id, node_tiers, talents_version)
	M.set_loadout_name(new_id, build_title)
	local es = EquipmentStore()
	if equipment and es then es.set(new_id, equipment) end

	local inv_view = Managers.ui and Managers.ui:view_instance("inventory_background_view")
	local presets_elem = inv_view and inv_view._profile_presets_element
	if presets_elem then
		presets_elem:_play_sound(UISoundEvents.add_profile_preset)
		presets_elem:_setup_preset_buttons()
		local _, idx = presets_elem:_get_widget_by_preset_id(new_id)
		if idx then
			presets_elem:on_profile_preset_index_change(idx)
		end
	end
	if Managers.save then Managers.save:queue_save() end

	return new_id
end

function M.overwrite_active_with_talents(node_tiers, talents_version, build_title, equipment)
	local active_id = ProfileUtils.get_active_profile_preset_id()
	if not active_id or not ProfileUtils.get_profile_preset(active_id) then return nil end
	Managers.event:trigger("event_player_save_changes_to_current_preset")
	ProfileUtils.save_talent_nodes_for_profile_preset(active_id, node_tiers, talents_version)
	update_loadout_name_textbox(build_title)
	M.set_loadout_name(active_id, build_title)
	local es = EquipmentStore()
	if equipment and es then es.set(active_id, equipment) end
	Managers.event:trigger("event_on_profile_preset_changed", ProfileUtils.get_profile_preset(active_id))
	return active_id
end

return M
