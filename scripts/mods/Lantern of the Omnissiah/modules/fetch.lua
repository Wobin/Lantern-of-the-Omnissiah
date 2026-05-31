-- Detached HTTP fetch driver using curl.exe.
--
-- Only fetches the build page. Slug → talent_id lookups are pre-built offline
-- via tools/build_slug_cache.ps1; the runtime never crawls /abilities/<slug>
-- pages or runs elimination. If a slug isn't in the shipped cache the mod
-- skips it and the validator drops orphan children.
--
-- Why curl, not PowerShell:
--   * curl.exe ships in C:\Windows\System32 on Windows 10 1803+ (April 2018).
--   * Cold-start ~5-20ms vs PowerShell's ~150-500ms — no visible UI hitch.
--   * Also present in Wine/Proton.
--
-- Why a .bat helper instead of inline cmd /c "...": writing a tiny .bat to
-- %TEMP% lets cmd handle path quoting via %~1 / %~2 naturally instead of
-- escape-gymnastics in nested double-quoted command strings.

local mod = get_mod("Lantern of the Omnissiah")

local M = {}

M.TEMP_DIR     = os.getenv("TEMP") or os.getenv("TMP") or "."
M.BUILD_HTML   = M.TEMP_DIR .. "\\lantern_of_the_omnissiah.html"
M.BUILD_DONE   = M.TEMP_DIR .. "\\lantern_of_the_omnissiah.done"

local BUILD_BAT = M.TEMP_DIR .. "\\lantern_fetch_build.bat"

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
	-- `start "" /B "<bat>"`: empty title, no new window, detached.
	local cmd = string.format('cmd /c start "" /B "%s"', script_path)
	local handle = Mods.lua.io.popen(cmd)
	if handle then handle:close() end
end

function M.spawn_build(url)
	M.safe_remove(M.BUILD_HTML)
	M.safe_remove(M.BUILD_DONE)
	if not write_script(BUILD_BAT, {
		"@echo off",
		string.format('curl -s -L -o "%s" "%s"', M.BUILD_HTML, url),
		string.format('type nul > "%s"', M.BUILD_DONE),
	}) then
		mod:warning("[fetch] failed to write build script %s", BUILD_BAT)
		return
	end
	mod:info("[fetch] spawning %s", url)
	detach_run(BUILD_BAT)
end

return M
