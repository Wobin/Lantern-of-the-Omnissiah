local M = {}

local URL_PATTERN = "gameslantern%.com/builds/([0-9a-fA-F%-]+)"

function M.read()
	local cb = rawget(_G, "Clipboard")
	if not cb or type(cb.get) ~= "function" then return nil end
	local ok, value = pcall(cb.get)
	if not ok then return nil end
	return type(value) == "string" and value or nil
end

function M.extract_gameslantern_url(text)
	if not text then return nil end
	local uuid = text:match(URL_PATTERN)
	return uuid and ("https://darktide.gameslantern.com/builds/" .. uuid) or nil
end

local EXPORT_FILE = "lantern_export.json"

function M.write(text)
	local cb = rawget(_G, "Clipboard")
	if cb then
		for _, name in ipairs({ "put", "set", "copy" }) do
			if type(cb[name]) == "function" then
				local ok = pcall(cb[name], text)
				if ok then return "clipboard" end
			end
		end
	end
	local f = Mods.lua.io.open(EXPORT_FILE, "wb")
	if f then f:write(text); f:close(); return "file" end
	return nil
end

function M.export_file_path() return EXPORT_FILE end

return M
