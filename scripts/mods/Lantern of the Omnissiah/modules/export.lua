local mod = get_mod("Lantern of the Omnissiah")

local M = {}

M.BOOKMARKLET = "javascript:(async()=>{try{var x=document.cookie.split('; ').find(c=>c.startsWith('XSRF-TOKEN='));if(!x){alert('Log in to Gameslantern first (no XSRF cookie).');return}var token=decodeURIComponent(x.split('=')[1]);var body;try{body=await navigator.clipboard.readText()}catch(e){body=prompt('Paste the Lantern build JSON:')}if(!body){alert('No build JSON on clipboard.');return}var r=await fetch('https://darktide.gameslantern.com/api/build-editor/build',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json','X-Requested-With':'XMLHttpRequest','X-XSRF-TOKEN':token},body:body});if(!r.ok){alert('Gameslantern POST failed: HTTP '+r.status);return}var d=await r.json();window.open(d.url||('https://darktide.gameslantern.com/builds/'+d.id),'_blank')}catch(e){alert('Export error: '+e)}})();"

local function json_escape(s)
	s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
	return s
end

local function json_str(s)
	return '"' .. json_escape(tostring(s)) .. '"'
end

local function json_str_array(arr)
	local parts = {}
	for i = 1, #arr do parts[i] = json_str(arr[i]) end
	return '[' .. table.concat(parts, ',') .. ']'
end

function M._layout_index(layout_nodes)
	local talent_of = {}
	for _, n in ipairs(layout_nodes) do talent_of[n.widget_name] = n.talent end
	local idx = {}
	for _, n in ipairs(layout_nodes) do
		local function tids(list)
			local out = {}
			if list then
				for _, wn in ipairs(list) do
					local t = talent_of[wn]
					if t then out[#out + 1] = t end
				end
			end
			return out
		end
		idx[n.widget_name] = { talent = n.talent, parents = tids(n.parents), children = tids(n.children) }
	end
	return idx
end

local function multiset_score(a, b)
	local have = {}
	for _, x in ipairs(a) do have[x] = (have[x] or 0) + 1 end
	local score = 0
	for _, x in ipairs(b) do
		if (have[x] or 0) > 0 then have[x] = have[x] - 1; score = score + 1 end
	end
	return score
end

local function best_node(entry, candidates)
	if #candidates == 1 then return candidates[1] end
	local best, best_score = nil, -1
	for _, c in ipairs(candidates) do
		local sc = multiset_score(entry.parents, c.parents) + multiset_score(entry.children, c.children)
		if sc > best_score then best, best_score = c, sc end
	end
	return best
end

function M._resolve(selected_widgets, layout_index, class_nodes)
	local ids_default, ids_stimm, skipped = {}, {}, 0
	for _, wn in ipairs(selected_widgets) do
		local entry = layout_index[wn]
		local candidates = entry and entry.talent and class_nodes[entry.talent]
		if not candidates then
			skipped = skipped + 1
			mod.dbg("[export] no GL node for widget %s (talent=%s)", tostring(wn), tostring(entry and entry.talent))
		else
			local node = best_node(entry, candidates)
			if node.tree_type == "broker_stimm" then
				ids_stimm[#ids_stimm + 1] = node.uuid
			else
				ids_default[#ids_default + 1] = node.uuid
			end
		end
	end
	return ids_default, ids_stimm, skipped
end

M.NULL = {}

local function json_val(x)
	if x == nil or x == M.NULL then return "null" end
	return '"' .. json_escape(tostring(x)) .. '"'
end

local function json_val_array(arr, n)
	local parts = {}
	for i = 1, n do parts[i] = json_val(arr[i]) end
	return "[" .. table.concat(parts, ",") .. "]"
end

local function round100(v)
	return math.floor((tonumber(v) or 0) * 100 + 0.5)
end

function M._bars(base_stats, bar_names, stat_display)
	local disp2val = {}
	for _, s in ipairs(base_stats) do
		local disp = stat_display[s.name]
		if disp then disp2val[disp] = round100(s.value) end
	end
	local bars = {}
	for i = 1, #bar_names do bars[i] = disp2val[bar_names[i]] or 0 end
	return bars
end

local function tok_set(s)
	local t, n = {}, 0
	for w in s:gmatch("%S+") do if not t[w] then t[w] = true; n = n + 1 end end
	return t, n
end

local function best_overlap(stripped, scope_map)
	local mine, mn = tok_set(stripped)
	if mn == 0 then return nil end
	local best, bestj = nil, 0
	for k, u in pairs(scope_map) do
		local theirs, tn = tok_set(k)
		local inter = 0
		for w in pairs(mine) do if theirs[w] then inter = inter + 1 end end
		local uni = mn + tn - inter
		local j = uni > 0 and inter / uni or 0
		if j > bestj then best, bestj = u, j end
	end
	if bestj >= 0.6 then return best end
	return nil
end

function M._modifiers(perk_effects, scope_map, n)
	local out = {}
	for i = 1, n do
		local stripped = perk_effects[i]
		local u
		if stripped and stripped ~= "" then
			u = scope_map[stripped]
			if not u then
				u = best_overlap(stripped, scope_map)
				if u then mod.dbg("[export] perk fuzzy-matched '%s'", stripped)
				else mod.dbg("[export] perk unmatched '%s'", stripped) end
			end
		end
		out[i] = u or M.NULL
	end
	return out
end

function M._weapon_entry(r, maps)
	local nk = maps.name_key(r.display_name)
	local uuid = maps.WEAPONS[nk]
	if not uuid then return nil, nk end
	local wt = maps.WEAPON_TRAITS[uuid] or {}
	local traits = {}
	for i = 1, 2 do
		local n = r.blessing_ns[i]
		traits[i] = (n and wt[n]) or M.NULL
	end
	return {
		id = uuid, quality = r.rarity,
		traits = traits, modifiers = M._modifiers(r.perk_effects or {}, (maps.WEAPON_MODIFIERS or {})[uuid] or {}, 2),
		bars = M._bars(r.base_stats, maps.WEAPON_BARS[uuid] or {}, r.stat_display),
	}
end

local function token_set(nk)
	local t = {}
	for w in nk:gmatch("%S+") do t[w] = true end
	return t
end

function M._curio_entry(r, maps)
	local nk = maps.name_key(r.display_name:gsub("%s*%b()%s*$", ""))
	local uuid = maps.CURIOS[nk]
	if not uuid then
		local mine = token_set(nk)
		for k, u in pairs(maps.CURIOS) do
			local kt = token_set(k)
			local sub = true
			for tok in pairs(mine) do if not kt[tok] then sub = false; break end end
			if sub then uuid = u; break end
		end
	end
	if not uuid then local _, any = next(maps.CURIOS); uuid = any end
	if not uuid then return nil, nk end
	local trait = (r.stat_keyword and maps.CURIO_TRAITS[r.stat_keyword]) or M.NULL
	return { id = uuid, quality = r.rarity, trait = trait, modifiers = M._modifiers(r.perk_effects or {}, maps.CURIO_MODIFIERS or {}, 3) }
end

local function weapon_json(w)
	return "{" ..
		'"id":' .. json_val(w.id) .. ',' ..
		'"quality":' .. tostring(w.quality) .. ',' ..
		'"modifiers":' .. json_val_array(w.modifiers, 2) .. ',' ..
		'"traits":' .. json_val_array(w.traits, 2) .. ',' ..
		'"bars":[' .. table.concat(w.bars, ",") .. "]" ..
	"}"
end

local function curio_json(c)
	return "{" ..
		'"id":' .. json_val(c.id) .. ',' ..
		'"quality":' .. tostring(c.quality) .. ',' ..
		'"trait":' .. json_val(c.trait) .. ',' ..
		'"modifiers":' .. json_val_array(c.modifiers, 3) ..
	"}"
end

function M.assemble(opts)
	local abilities = '{"type":"default","ids":' .. json_str_array(opts.ids_default) .. '}'
	if #opts.ids_stimm > 0 then
		abilities = abilities .. ',{"type":"broker_stimm","ids":' .. json_str_array(opts.ids_stimm) .. '}'
	end
	local ws = {}
	for _, w in ipairs(opts.weapons or {}) do ws[#ws + 1] = weapon_json(w) end
	local cs = {}
	for _, c in ipairs(opts.curios or {}) do cs[#cs + 1] = curio_json(c) end
	local json = table.concat({
		'{',
		'"name":', json_str(opts.name), ',',
		'"description":null,"image":null,"youtube":null,',
		'"classId":', json_str(opts.class_id), ',',
		'"roles":[],"threatLevelId":null,"visibility":1,',
		'"abilities":[', abilities, '],',
		'"weapons":[' .. table.concat(ws, ",") .. '],"curios":[' .. table.concat(cs, ",") .. ']',
		'}',
	})
	local counts = { default = #opts.ids_default, stimm = #opts.ids_stimm }
	return json, counts
end

return M
