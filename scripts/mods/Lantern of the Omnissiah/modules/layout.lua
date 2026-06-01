local M = {}

local _layouts_cache = {}
local _lookup_cache  = {}

function M.archetype_layouts(archetype)
	local key = archetype.name
	local cached = _layouts_cache[key]
	if cached then return cached end
	local layouts = { require(archetype.talent_layout_file_path) }
	if archetype.specialization_talent_layout_file_path then
		layouts[2] = require(archetype.specialization_talent_layout_file_path)
	end
	_layouts_cache[key] = layouts
	return layouts
end

function M.build_talent_lookup(layouts)
	local key = layouts[1] and layouts[1].archetype_name
	assert(key, "Lantern: layout table has no archetype_name; cannot key cache")
	local cached = _lookup_cache[key]
	if cached then return cached end
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
	_lookup_cache[key] = by_talent
	return by_talent
end

return M
