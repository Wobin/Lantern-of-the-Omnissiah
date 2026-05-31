--[[
Name: Lantern of the Omnissiah
Author: Wobin
Date: 01/06/2026
Version: 1.0
Repository: https://github.com/Wobin/Lantern-of-the-Omnissiah
--]]

-- Top-level orchestration only. Concerns are split across modules under
-- scripts/mods/Lantern of the Omnissiah/modules/.
--
-- The slug → talent_id cache is PRE-BUILT offline via
--   tools/build_slug_cache.ps1
-- and shipped as slug_cache.lua at the mod root. The runtime never crawls
-- /abilities/<slug> pages or runs elimination — it just reads the cache,
-- learns any inline pairs available for free from the build page itself, and
-- skips slugs the cache doesn't know about (validator drops orphan children).
-- Re-run the build script when Fatshark patches talents.

local mod = get_mod("Lantern of the Omnissiah")
mod.version = "1.0"

local MODULES = "Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/modules/"
mod._modules = {
	clipboard  = mod:io_dofile(MODULES .. "clipboard"),
	slug_cache = mod:io_dofile(MODULES .. "slug_cache"),
	fetch      = mod:io_dofile(MODULES .. "fetch"),
	parser     = mod:io_dofile(MODULES .. "parser"),
	layout     = mod:io_dofile(MODULES .. "layout"),
	popups     = mod:io_dofile(MODULES .. "popups"),
	preset     = mod:io_dofile(MODULES .. "preset"),
	pipeline   = mod:io_dofile(MODULES .. "pipeline"),
}
local Clipboard = mod._modules.clipboard
local SlugCache = mod._modules.slug_cache
local Fetch     = mod._modules.fetch
local Parser    = mod._modules.parser
local Pipeline  = mod._modules.pipeline

local _pending          = nil   -- { url, started_t, force, mode }
local _last_handled_url = nil   -- session memoisation (only set on the new-preset path)

local FETCH_TIMEOUT_SEC = 30

local function on_build_html_ready(html, url, mode)
	if not html or #html == 0 then
		mod:notify("Lantern: empty response from gameslantern")
		return
	end

	local title          = Parser.parse_title(html)
	local archetype_slug = Parser.parse_archetype_slug(html)
	local anchors        = Parser.parse_active_anchors(html)
	mod:info("[parse] title=%s slug=%s active_anchors=%d", tostring(title), tostring(archetype_slug), #anchors)

	if not archetype_slug or #anchors == 0 then
		mod._modules.popups.error("Lantern of the Omnissiah",
			"Could not read any selected talents from that gameslantern page.")
		return
	end

	-- Resolve slug → talent_id from: 1) inline icon pairs in the build page,
	-- 2) the shipped cache. Anything not resolved is skipped. The cache also
	-- absorbs the inline pairs so the file grows on its own from real-world
	-- builds even without re-running the offline crawler.
	local slug_to_talent = {}
	local cache = SlugCache.get()
	local cache_changed = false
	for _, a in ipairs(anchors) do
		if a.talent_id then
			slug_to_talent[a.slug] = a.talent_id
			if cache[a.slug] ~= a.talent_id then
				cache[a.slug] = a.talent_id
				cache_changed = true
			end
		end
	end
	for slug, talent_id in pairs(cache) do
		if not slug_to_talent[slug] then slug_to_talent[slug] = talent_id end
	end
	if cache_changed then SlugCache.save() end

	local unresolved = 0
	for _, a in ipairs(anchors) do
		if not slug_to_talent[a.slug] then
			unresolved = unresolved + 1
			mod:info("[unresolved] %s — not in cache; will be skipped", a.slug)
		end
	end
	if unresolved > 0 then
		mod:info("[parse] %d/%d slugs unresolved (re-run tools/build_slug_cache.ps1 to extend the cache)",
			unresolved, #anchors)
	end

	Pipeline.apply_build({
		title           = title,
		archetype_slug  = archetype_slug,
		anchors         = anchors,
		slug_to_talent  = slug_to_talent,
		mode            = mode,
		url             = url,
		on_handled      = function(handled_url) _last_handled_url = handled_url end,
	})
end

mod.run_import = function(force, mode)
	mode = mode or "new_preset"
	if _pending then
		mod:info("[run_import] fetch already in progress; ignoring")
		return
	end
	local raw = Clipboard.read()
	local url = Clipboard.extract_gameslantern_url(raw)
	if not url then
		if force then mod:notify("Lantern: no gameslantern URL on the clipboard") end
		return
	end
	if not force and url == _last_handled_url then
		mod:info("[run_import] same URL already handled; skipping (force=false)")
		return
	end
	_pending = {
		url       = url,
		started_t = os.clock(),
		force     = force,
		mode      = mode,
	}
	Fetch.spawn_build(url)
end

mod.update = function(dt)
	if not _pending then return end

	local f = Mods.lua.io.open(Fetch.BUILD_DONE, "rb")
	if f then
		f:close()
		local url, mode = _pending.url, _pending.mode
		_pending = nil
		local html = Fetch.read_file(Fetch.BUILD_HTML)
		Fetch.safe_remove(Fetch.BUILD_HTML)
		Fetch.safe_remove(Fetch.BUILD_DONE)
		on_build_html_ready(html, url, mode)
		return
	end

	if os.clock() - _pending.started_t > FETCH_TIMEOUT_SEC then
		_pending = nil
		mod:warning("[fetch] timed out")
		mod:notify("Lantern: fetch timed out — check your internet connection")
	end
end

mod.on_all_mods_loaded = function()
	mod:info(mod.version)

	mod:command("lantern", "Apply a gameslantern build URL (overwrites current preset)", function()
		mod.run_import(true, "overwrite_current")
	end)

	mod:hook(CLASS.TalentBuilderView, "on_enter", function(orig, self, ...)
		local ret = orig(self, ...)
		if not self._is_readonly then
			mod.run_import(false, "new_preset")
		end
		return ret
	end)

	mod:hook(CLASS.InventoryBackgroundView, "_setup_input_legend", function(orig, self, ...)
		local ret = orig(self, ...)
		local legend = self._input_legend_element
		if legend and type(legend.add_entry) == "function" then
			legend:add_entry(
				mod:localize("loc_lantern_recheck_clipboard"),
				"hotkey_menu_special_2",
				function(parent)
					if parent._is_readonly then return false end
					local av = parent._active_view
					return av == "talent_builder_view" or av == "broker_stimm_builder_view"
				end,
				function(_id, _pressed)
					mod.run_import(true, "overwrite_current")
				end,
				"right_alignment"
			)
		end
		return ret
	end)
end
