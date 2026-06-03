local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local _mod_dir = nil

local function get_mod_dir()
	if _mod_dir then return _mod_dir end
	local h = Mods.lua.io.popen("cd")
	local cwd = h and h:read() or ""
	if h then h:close() end
	cwd = cwd:gsub("[\r\n]+$", "")
	assert(cwd:lower():sub(-9) == "\\binaries",
		"Lantern: expected CWD to end in \\binaries, got: " .. cwd)
	_mod_dir = cwd:sub(1, -10) .. "\\mods\\Lantern of the Omnissiah"
	return _mod_dir
end

local function cache_path()
	return get_mod_dir() .. "\\scripts\\mods\\Lantern of the Omnissiah\\gameslantern_slugs.lua"
end

local function read_header_lines(path)
	local f = Mods.lua.io.open(path, "r")
	if not f then return nil end
	local lines = {}
	for line in f:lines() do
		if line:match("^%s*return%s*{") then break end
		lines[#lines + 1] = line
	end
	f:close()
	return lines
end

function M.get_metadata()
	local lines = read_header_lines(cache_path())
	if not lines then return nil end
	local meta = {}
	for _, line in ipairs(lines) do
		local key, value = line:match("^%s*--%s*([%w%s]+):%s*(.+)%s*$")
		if key and value then
			meta[key:lower():gsub("%s+", "_")] = value
		end
	end
	return meta
end

local _cache = nil

function M.get()
	if _cache then return _cache end
	_cache = {}
	local path = cache_path()
	local f = Mods.lua.io.open(path, "r")
	if not f then
		mod:warning("[slug_cache] could not open %s — cache will be empty (stat-buff slugs will fail to resolve)", path)
		return _cache
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		mod:warning("[slug_cache] %s is empty — cache will be empty", path)
		return _cache
	end
	local _loadstring = Mods.lua.loadstring
	local fn, err = _loadstring(content)
	if not fn then
		mod:warning("[slug_cache] load error parsing %s: %s", path, tostring(err))
		return _cache
	end
	local ok, result = pcall(fn)
	if not ok then
		mod:warning("[slug_cache] eval error on %s: %s", path, tostring(result))
		return _cache
	end
	if type(result) ~= "table" then
		mod:warning("[slug_cache] %s did not return a table (got %s)", path, type(result))
		return _cache
	end
	_cache = result
	local count = 0
	for _ in pairs(_cache) do count = count + 1 end
	mod:info("[slug_cache] loaded %d entries from %s", count, path)
	return _cache
end

function M.save()
	if not _cache then return end
	local path = cache_path()
	local header = read_header_lines(path)
	local keys = {}
	for k in pairs(_cache) do keys[#keys + 1] = k end
	table.sort(keys)
	local lines = {}
	if header then
		for _, line in ipairs(header) do lines[#lines + 1] = line end
	end
	lines[#lines + 1] = "return {"
	for _, k in ipairs(keys) do
		lines[#lines + 1] = string.format('  ["%s"] = "%s",', k, _cache[k])
	end
	lines[#lines + 1] = "}"
	local f = Mods.lua.io.open(path, "w")
	if not f then
		mod:warning("[slug_cache] failed to open for write: %s", path)
		return
	end
	f:write(table.concat(lines, "\n"))
	f:close()
	mod:info("[slug_cache] saved %d entries to %s", #keys, path)
end

return M
