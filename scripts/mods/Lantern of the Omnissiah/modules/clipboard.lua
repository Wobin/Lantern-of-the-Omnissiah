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

return M
