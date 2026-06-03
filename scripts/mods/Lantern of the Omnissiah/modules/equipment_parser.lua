local M = {}

local function unescape_html(s)
	if not s then return nil end
	return (s:gsub("&#0?39;", "'"):gsub("&quot;", '"'):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"))
end

local function parse_weapon_block(block)
	local name   = unescape_html(block:match('<div class="text%-xl">([^<]+)</div>'))
	local rarity = unescape_html(block:match('<div class="text%-md"%s*>([^<]+)</div>'))
	local fam, slug = block:match('href="[^"]*/weapons/([^/]+)/([^"]+)"')

	local perks = {}
	for perk in block:gmatch('rotate%-45"></div>%s*<div class="text%-%[#D1FFC3%] font%-bold text%-sm">([^<]+)</div>') do
		perks[#perks + 1] = unescape_html(perk)
	end

	local blessings = {}
	for trait_id, inner in block:gmatch('weapon_trait_(%d+)%.webp[^/]*/>%s*<div[^>]*>(.-)</div>') do
		local b_name = unescape_html(inner:match('<h3[^>]*>([^<]+)</h3>'))
		local b_desc = unescape_html(inner:match('<p[^>]*>([^<]+)</p>') or "")
		blessings[#blessings + 1] = { trait_id = trait_id, name = b_name, description = b_desc }
	end

	local stats = {}
	for label, pct in block:gmatch(
			'font%-semibold whitespace%-nowrap text%-sm text%-%[#D1FFC3%]">([^<]+)</div>'
			.. '%s*<div[^>]*>%s*<div[^>]*style="width:%s*(%d+)%%') do
		stats[#stats + 1] = { name = unescape_html(label), value = tonumber(pct) }
	end

	return {
		name      = name,
		rarity    = rarity,
		family    = fam,
		slug      = slug,
		perks     = perks,
		blessings = blessings,
		stats     = stats,
	}
end

local function parse_curio_block(block)
	local name   = unescape_html(block:match('<div class="text%-xl">([^<]+)</div>'))
	local rarity = unescape_html(block:match('<div class="text%-md"%s*>([^<]+)</div>'))
	local primary = unescape_html(block:match('<img src="[^"]*curio%.webp[^/]*/>%s*<h3[^>]*>([^<]+)</h3>'))

	local secondary = {}
	for mod in block:gmatch('rotate%-45"></div>%s*<div class="text%-%[#D1FFC3%] text%-sm leading%-4">([^<]+)</div>') do
		secondary[#secondary + 1] = unescape_html(mod)
	end

	return {
		name      = name,
		rarity    = rarity,
		primary   = primary,
		secondary = secondary,
	}
end

function M.parse(html)
	if not html or #html == 0 then return { weapons = {}, curios = {} } end

	local weapons = {}
	for block in html:gmatch('<div class="max%-w%-sm w%-full">(.-)weapon_box_bottom%.webp') do
		if block:find('/weapons/', 1, true) then
			weapons[#weapons + 1] = parse_weapon_block(block)
		end
	end

	local curios = {}
	for block in html:gmatch('<div class="max%-w%-%[330px%] w%-full">(.-)weapon_box_bottom%.webp') do
		if block:find('/curios/', 1, true) then
			curios[#curios + 1] = parse_curio_block(block)
		end
	end

	return { weapons = weapons, curios = curios }
end

return M
