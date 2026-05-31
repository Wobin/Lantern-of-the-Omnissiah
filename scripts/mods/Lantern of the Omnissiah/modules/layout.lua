-- Archetype talent-layout helpers. Wraps the in-game layout require() and
-- builds a talent_id → {widget_name, cost, layout_index} lookup.

local M = {}

-- Returns the archetype's base layout plus (if non-nil) its specialization layout.
function M.archetype_layouts(archetype)
	local layouts = { require(archetype.talent_layout_file_path) }
	if archetype.specialization_talent_layout_file_path then
		layouts[2] = require(archetype.specialization_talent_layout_file_path)
	end
	return layouts
end

-- (talent_id → {widget_name, cost, layout_index}) lookup across both layouts.
-- Skips start nodes (cost 0, no talent field).
function M.build_talent_lookup(layouts)
	local by_talent = {}
	for li = 1, #layouts do
		for _, node in ipairs(layouts[li].nodes) do
			if node.talent and node.widget_name and (node.cost or 0) > 0 then
				by_talent[node.talent] = {
					widget_name  = node.widget_name,
					cost         = node.cost,
					layout_index = li,
				}
			end
		end
	end
	return by_talent
end

return M
