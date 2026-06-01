local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local TEMP_DIR = os.getenv("TEMP") or os.getenv("TMP") or "."
local _seq     = 0

function M.safe_remove(path)
	pcall(os.remove, path)
end

function M.read_file(path)
	local f = Mods.lua.io.open(path, "rb")
	if not f then return nil end
	local content = f:read("*a")
	f:close()
	return content
end

local function write_script(path, lines)
	local f = Mods.lua.io.open(path, "w")
	if not f then return false end
	for _, line in ipairs(lines) do
		f:write(line)
		f:write("\r\n")
	end
	f:close()
	return true
end

local function detach_run(script_path)
	local cmd = string.format('cmd /c start "" /B "%s"', script_path)
	local handle = Mods.lua.io.popen(cmd)
	if handle then handle:close() end
end

function M.spawn_build(url)
	_seq = _seq + 1
	local seq = _seq
	local html_path = string.format("%s\\lantern_html_%d.html", TEMP_DIR, seq)
	local done_path = string.format("%s\\lantern_done_%d.done", TEMP_DIR, seq)
	local bat_path  = string.format("%s\\lantern_bat_%d.bat",  TEMP_DIR, seq)
	if not write_script(bat_path, {
		"@echo off",
		string.format('curl -s -L --compressed -o "%s" "%s"', html_path, url),
		string.format('type nul > "%s"', done_path),
	}) then
		mod:warning("[fetch] failed to write build script %s", bat_path)
		return nil
	end
	mod:info("[fetch] spawning seq=%d %s", seq, url)
	detach_run(bat_path)
	return {
		html_path = html_path,
		done_path = done_path,
		bat_path  = bat_path,
		seq       = seq,
	}
end

return M
