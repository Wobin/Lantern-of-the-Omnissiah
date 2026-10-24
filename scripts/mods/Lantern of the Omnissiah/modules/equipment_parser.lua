local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local TERMS
local WEAPON_PERKS_SORTED = {}
local CURIO_PERKS_SORTED = {}

local function by_length_desc(a, b)
	return #a > #b
end

local function rebuild_sorted()
	WEAPON_PERKS_SORTED, CURIO_PERKS_SORTED = {}, {}
	if not TERMS then return end
	for k in pairs(TERMS.weapon_perks or {}) do WEAPON_PERKS_SORTED[#WEAPON_PERKS_SORTED + 1] = k end
	for k in pairs(TERMS.curio_perks or {}) do CURIO_PERKS_SORTED[#CURIO_PERKS_SORTED + 1] = k end
	table.sort(WEAPON_PERKS_SORTED, by_length_desc)
	table.sort(CURIO_PERKS_SORTED, by_length_desc)
end

function M.set_terms(t)
	TERMS = t
	rebuild_sorted()
end

local function load_terms()
	local ok, t = pcall(function()
		return mod:io_dofile("Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/gameslantern_terms")
	end)
	if ok and type(t) == "table" then M.set_terms(t) end
end
load_terms()

local function unescape_html(s)
	if not s then return nil end
	return (s:gsub("&#0?39;", "'"):gsub("&quot;", '"'):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"))
end

local function remove_first(s, needle)
	local i = s:find(needle, 1, true)
	if not i then return s end
	return s:sub(1, i - 1) .. s:sub(i + #needle)
end

local function scan_known(block, sorted)
	local out = {}
	local work = block
	for _, effect in ipairs(sorted) do
		if work:find(effect, 1, true) then
			out[#out + 1] = effect
			work = remove_first(work, effect)
		end
	end
	return out
end

local function parse_weapon_block(block)
	local name   = unescape_html(block:match('<div class="text%-xl">([^<]+)</div>'))
	local rarity = unescape_html(block:match('<div class="text%-md"%s*>([^<]+)</div>'))
	local fam, slug = block:match('href="[^"]*/weapons/([^/]+)/([^"]+)"')

	local perks = {}
	for perk in block:gmatch('<div class="text%-%[#D1FFC3%] font%-bold text%-sm">([^<]+)</div>') do
		perks[#perks + 1] = unescape_html(perk)
	end
	if #perks == 0 then
		perks = scan_known(block, WEAPON_PERKS_SORTED)
	end

	local blessings = {}
	for trait_id, inner in block:gmatch('weapon_trait_(%d+)%.webp[^/]*/>%s*<div[^>]*>(.-)</div>') do
		local b_name = unescape_html(inner:match('<h3[^>]*>([^<]+)</h3>'))
		local b_desc = unescape_html(inner:match('<p[^>]*>([^<]+)</p>') or "")
		if TERMS and TERMS.weapon_blessings and TERMS.weapon_blessings[trait_id] then
			local wb = TERMS.weapon_blessings[trait_id]
			if not b_name or b_name == "" then b_name = wb.name end
			if not b_desc or b_desc == "" then b_desc = wb.effect or "" end
		end
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
	for perk in block:gmatch('<div class="text%-%[#D1FFC3%] text%-sm leading%-4">([^<]+)</div>') do
		secondary[#secondary + 1] = unescape_html(perk)
	end
	if #secondary == 0 then
		secondary = scan_known(block, CURIO_PERKS_SORTED)
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
