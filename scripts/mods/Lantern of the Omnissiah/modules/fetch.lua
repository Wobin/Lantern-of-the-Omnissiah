local mod = get_mod("Lantern of the Omnissiah")

local M = {}

local TEMP_DIR = os.getenv("TEMP") or os.getenv("TMP") or "."
local CURL     = (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\curl.exe"
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
		string.format('"%s" -s -S -L --compressed -o "%s" "%s" 2> "%s"', CURL, html_path, url, err_path),
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
	local html_unix = string.format("/tmp/lantern_html_%d.html", seq)
	local done_unix = string.format("/tmp/lantern_done_%d.done", seq)
	local err_unix  = string.format("/tmp/lantern_err_%d.txt",  seq)
	local sh_unix   = string.format("/tmp/lantern_%d.sh",       seq)
	local html_win  = string.format("Z:\\tmp\\lantern_html_%d.html", seq)
	local done_win  = string.format("Z:\\tmp\\lantern_done_%d.done", seq)
	local err_win   = string.format("Z:\\tmp\\lantern_err_%d.txt",   seq)
	local sh_win    = string.format("Z:\\tmp\\lantern_%d.sh",        seq)
	M.safe_remove(html_win)
	M.safe_remove(done_win)
	M.safe_remove(err_win)
	if not write_script(sh_win, {
		string.format("out='%s'; err='%s'; done='%s'", html_unix, err_unix, done_unix),
		"if command -v curl >/dev/null 2>&1; then",
		string.format("  curl -s -S -L --compressed -o \"$out\" '%s' 2> \"$err\"; echo $? > \"$done\"", url),
		"elif command -v wget >/dev/null 2>&1; then",
		string.format("  wget -q -O \"$out\" '%s' 2> \"$err\"; echo $? > \"$done\"", url),
		"else",
		"  echo 'no curl or wget on host' > \"$err\"; echo 127 > \"$done\"",
		"fi",
	}, "\n") then
		mod:warning("[fetch] failed to write build script %s", sh_win)
		return nil
	end
	mod.dbg("[fetch] spawning (wine) seq=%d %s", seq, url)
	local h = Mods.lua.io.popen("cmd /c start /unix /bin/sh " .. sh_unix)
	if h then h:close() end
	return {
		html_path = html_win,
		done_path = done_win,
		bat_path  = sh_win,
		err_path  = err_win,
		seq       = seq,
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

function M.sweep_orphans()
	local h = Mods.lua.io.popen(string.format('cmd /c del /Q "%s\\lantern_html_*.html" "%s\\lantern_done_*.done" "%s\\lantern_bat_*.bat" "%s\\lantern_err_*.txt" 2>nul', TEMP_DIR, TEMP_DIR, TEMP_DIR, TEMP_DIR))
	if h then h:close() end
	if is_wine() and z_is_root() then
		local h2 = Mods.lua.io.popen('cmd /c del /Q "Z:\\tmp\\lantern_html_*.html" "Z:\\tmp\\lantern_done_*.done" "Z:\\tmp\\lantern_err_*.txt" "Z:\\tmp\\lantern_*.sh" 2>nul')
		if h2 then h2:close() end
	end
end

return M
