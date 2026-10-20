local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local TEMP_DIR = os.getenv("TEMP") or os.getenv("TMP") or "."
local CURL     = (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\curl.exe"
local UA       = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
local _seq     = 0

local _is_wine
local function is_wine()
	if _is_wine == nil then
		_is_wine = (Application and Application.wine_version and Application.wine_version()) and true or false
	end
	return _is_wine
end

local _z_root
local function z_is_root()
	if _z_root == nil then
		local f = Mods.lua.io.open("Z:\\proc\\version", "r")
		if f then
			local s = f:read(64)
			f:close()
			_z_root = (s and s:find("Linux", 1, true)) and true or false
		else
			_z_root = false
		end
	end
	return _z_root
end

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

local function write_script(path, lines, eol)
	eol = eol or "\r\n"
	local f = Mods.lua.io.open(path, "wb")
	if not f then return false end
	for _, line in ipairs(lines) do
		f:write(line)
		f:write(eol)
	end
	f:close()
	return true
end

local function detach_run(script_path)
	local cmd = string.format('cmd /c start "" /B "%s"', script_path)
	local handle = Mods.lua.io.popen(cmd)
	if handle then handle:close() end
end

local function spawn_build_windows(url)
	_seq = _seq + 1
	local seq = _seq
	local html_path = string.format("%s\\lantern_html_%d.html", TEMP_DIR, seq)
	local done_path = string.format("%s\\lantern_done_%d.done", TEMP_DIR, seq)
	local bat_path  = string.format("%s\\lantern_bat_%d.bat",  TEMP_DIR, seq)
	local err_path  = string.format("%s\\lantern_err_%d.txt",  TEMP_DIR, seq)
	M.safe_remove(html_path)
	M.safe_remove(done_path)
	M.safe_remove(err_path)
	if not write_script(bat_path, {
		"@echo off",
		string.format('"%s" -s -S -L -A "%s" -o "%s" "%s" 2> "%s"', CURL, UA, html_path, url, err_path),
		string.format('>"%s" echo %%ERRORLEVEL%%', done_path),
	}) then
		mod:warning("[fetch] failed to write build script %s", bat_path)
		return nil
	end
	mod.dbg("[fetch] spawning seq=%d %s", seq, url)
	detach_run(bat_path)
	return {
		html_path = html_path,
		done_path = done_path,
		bat_path  = bat_path,
		err_path  = err_path,
		seq       = seq,
	}
end

local function spawn_build_wine(url)
	if not z_is_root() then
		mod:warning("[fetch] Wine detected but Z:\\ is not mapped to / — cannot reach host curl")
		return nil, "linux_unsupported"
	end
	_seq = _seq + 1
	local seq = _seq
	local html_unix  = string.format("/tmp/lantern_html_%d.html", seq)
	local done_unix  = string.format("/tmp/lantern_done_%d.done", seq)
	local err_unix   = string.format("/tmp/lantern_err_%d.txt",  seq)
	local stage_unix = string.format("/tmp/lantern_stage_%d.txt", seq)
	local sh_unix    = string.format("/tmp/lantern_%d.sh",       seq)
	local html_win   = string.format("Z:\\tmp\\lantern_html_%d.html", seq)
	local done_win   = string.format("Z:\\tmp\\lantern_done_%d.done", seq)
	local err_win    = string.format("Z:\\tmp\\lantern_err_%d.txt",   seq)
	local stage_win  = string.format("Z:\\tmp\\lantern_stage_%d.txt", seq)
	local sh_win     = string.format("Z:\\tmp\\lantern_%d.sh",        seq)
	local wrap_win   = string.format("Z:\\tmp\\lantern_wrap_%d.bat",  seq)
	M.safe_remove(html_win)
	M.safe_remove(done_win)
	M.safe_remove(err_win)
	M.safe_remove(stage_win)
	M.safe_remove(wrap_win)
	if not write_script(sh_win, {
		string.format("stage='%s'; out='%s'; err='%s'; done='%s'", stage_unix, html_unix, err_unix, done_unix),
		"echo sh_begin > \"$stage\"",
		"if command -v curl >/dev/null 2>&1; then",
		"  echo curl >> \"$stage\"",
		string.format("  curl -s -S -L -A '%s' -o \"$out\" '%s' 2> \"$err\"; echo $? > \"$done\"", UA, url),
		"elif command -v wget >/dev/null 2>&1; then",
		"  echo wget >> \"$stage\"",
		string.format("  wget -q -U '%s' -O \"$out\" '%s' 2> \"$err\"; echo $? > \"$done\"", UA, url),
		"else",
		"  echo no_http >> \"$stage\"",
		"  echo 'no curl or wget on host' > \"$err\"; echo 127 > \"$done\"",
		"fi",
		"echo sh_done >> \"$stage\"",
	}, "\n") then
		mod:warning("[fetch] failed to write build script %s", sh_win)
		return nil
	end
	if not write_script(wrap_win, {
		"@echo off",
		string.format('start "" /b "Z:\\bin\\sh" %s 2>&1', sh_unix),
		"echo start_exit=%ERRORLEVEL%",
	}) then
		mod:warning("[fetch] failed to write build script %s", wrap_win)
		return nil
	end
	mod.dbg("[fetch] spawning (wine) seq=%d %s", seq, url)
	local spawn_out
	local h = Mods.lua.io.popen(string.format('cmd /c "%s"', wrap_win))
	if h then
		spawn_out = h:read("*a")
		h:close()
	end
	if spawn_out then spawn_out = spawn_out:gsub("%s+$", "") end
	mod.dbg("[fetch] wine spawn seq=%d result: %s", seq, tostring(spawn_out))
	return {
		html_path  = html_win,
		done_path  = done_win,
		bat_path   = sh_win,
		wrap_path  = wrap_win,
		err_path   = err_win,
		stage_path = stage_win,
		seq        = seq,
	}
end

function M.spawn_build(url)
	if is_wine() then
		return spawn_build_wine(url)
	end
	return spawn_build_windows(url)
end

function M.read_diagnostics(p)
	local code
	local d = p.done_path and M.read_file(p.done_path)
	if d then code = tonumber((d:gsub("%s+", ""))) end
	local err = p.err_path and M.read_file(p.err_path)
	if err then
		err = err:gsub("%s+$", "")
		if err == "" then err = nil end
	end
	return code, err
end

function M.read_stage(p)
	local s = p.stage_path and M.read_file(p.stage_path)
	if not s then return nil end
	s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then return nil end
	return s
end

function M.sweep_orphans()
	local h = Mods.lua.io.popen(string.format('cmd /c del /Q "%s\\lantern_html_*.html" "%s\\lantern_done_*.done" "%s\\lantern_bat_*.bat" "%s\\lantern_err_*.txt" 2>nul', TEMP_DIR, TEMP_DIR, TEMP_DIR, TEMP_DIR))
	if h then h:close() end
	if is_wine() and z_is_root() then
		local h2 = Mods.lua.io.popen('cmd /c del /Q "Z:\\tmp\\lantern_html_*.html" "Z:\\tmp\\lantern_done_*.done" "Z:\\tmp\\lantern_err_*.txt" "Z:\\tmp\\lantern_stage_*.txt" "Z:\\tmp\\lantern_*.sh" "Z:\\tmp\\lantern_wrap_*.bat" 2>nul')
		if h2 then h2:close() end
	end
end

return M
