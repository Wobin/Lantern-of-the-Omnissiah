-- Persistent slug → talent_id cache, stored as a Lua return-table at
-- <mod_dir>/slug_cache.lua. Loaded lazily on first access; written when new
-- mappings are learned (typically after the first import per archetype).

local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local _mod_dir = nil

-- Derive the mod directory by asking the OS for the binaries CWD and substituting
-- "binaries" → "mods\Lantern of the Omnissiah". DLS uses the same trick.
local function get_mod_dir()
	if _mod_dir then return _mod_dir end
	local h = Mods.lua.io.popen("cd")
	local cwd = h and h:read() or ""
	if h then h:close() end
	cwd = cwd:gsub("[\r\n]+$", "")
	if cwd:lower():sub(-9) == "\\binaries" then
		_mod_dir = cwd:sub(1, -10) .. "\\mods\\Lantern of the Omnissiah"
	else
		_mod_dir = cwd .. "\\mods\\Lantern of the Omnissiah"
	end
	return _mod_dir
end

local function cache_path()
	return get_mod_dir() .. "\\slug_cache.lua"
end

local _cache = nil

-- Returns the cache table, loading from disk on first call. The returned table
-- is the live mutable map — callers can write to it directly; call M.save() to
-- persist.
function M.get()
	if _cache then return _cache end
	_cache = {}
	local path = cache_path()
	local f = Mods.lua.io.open(path, "r")
	if not f then return _cache end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then return _cache end
	-- DMF sandbox doesn't expose the bare `loadstring` global; reach for the
	-- engine-provided one via Mods.lua (the same path DMF itself uses internally).
	local _loadstring = Mods.lua.loadstring
	local fn, err = _loadstring(content)
	if not fn then
		mod:warning("[slug_cache] load error: %s", tostring(err))
		return _cache
	end
	local ok, result = pcall(fn)
	if ok and type(result) == "table" then
		_cache = result
		local count = 0
		for _ in pairs(_cache) do count = count + 1 end
		mod:info("[slug_cache] loaded %d entries from %s", count, path)
	end
	return _cache
end

-- Persist the in-memory cache to disk. Sorted-key output for clean diffs.
function M.save()
	if not _cache then return end
	local keys = {}
	for k in pairs(_cache) do keys[#keys + 1] = k end
	table.sort(keys)
	local lines = { "return {" }
	for _, k in ipairs(keys) do
		lines[#lines + 1] = string.format('  ["%s"] = "%s",', k, _cache[k])
	end
	lines[#lines + 1] = "}"
	local path = cache_path()
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
