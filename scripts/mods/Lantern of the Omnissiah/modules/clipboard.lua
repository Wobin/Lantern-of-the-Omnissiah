-- Clipboard reading and gameslantern URL extraction.

local M = {}

local URL_PATTERN = "gameslantern%.com/builds/([0-9a-fA-F%-]+)"

-- Returns the OS clipboard's current text, or nil if empty / inaccessible.
-- Uses the engine-native Clipboard global (synchronous, no shell-out latency).
function M.read()
	local cb = rawget(_G, "Clipboard")
	if not cb or type(cb.get) ~= "function" then return nil end
	local ok, value = pcall(cb.get)
	if not ok then return nil end
	return type(value) == "string" and value or nil
end

-- Extract the canonical gameslantern build URL from arbitrary clipboard text.
-- Accepts the full /builds/<uuid>/<slug> form, the bare /builds/<uuid> form, or
-- text that just contains the UUID embedded somewhere; returns the canonical
-- darktide.gameslantern.com URL or nil if no UUID was found.
function M.extract_gameslantern_url(text)
	if not text then return nil end
	local uuid = text:match(URL_PATTERN)
	if not uuid then return nil end
	local full = text:match("(https?://[%w%-%.]*gameslantern%.com/builds/" .. uuid .. "[%w%-/_%%%.~]*)")
	if not full then
		full = "https://darktide.gameslantern.com/builds/" .. uuid
	end
	return full
end

return M
