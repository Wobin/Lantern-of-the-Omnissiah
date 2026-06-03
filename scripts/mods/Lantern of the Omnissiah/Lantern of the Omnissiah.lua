--[[
Name: Lantern of the Omnissiah
Author: Wobin
Date: 04/06/2026
Version: 1.3
Repository: https://github.com/Wobin/Lantern-of-the-Omnissiah
--]]

local mod = get_mod("Lantern of the Omnissiah")
mod.version = "1.3"

mod.dbg = function(fmt, ...)
	if mod:get("debug") then mod:info(fmt, ...) end
end

local MODULES = "Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/modules/"
mod._modules = {
	clipboard         = mod:io_dofile(MODULES .. "clipboard"),
	slug_cache        = mod:io_dofile(MODULES .. "slug_cache"),
	fetch             = mod:io_dofile(MODULES .. "fetch"),
	parser            = mod:io_dofile(MODULES .. "parser"),
	equipment_parser  = mod:io_dofile(MODULES .. "equipment_parser"),
	equipment_store   = mod:io_dofile(MODULES .. "equipment_store"),
	equipment_overlay = mod:io_dofile(MODULES .. "equipment_overlay"),
	layout            = mod:io_dofile(MODULES .. "layout"),
	popups            = mod:io_dofile(MODULES .. "popups"),
	preset            = mod:io_dofile(MODULES .. "preset"),
	pipeline          = mod:io_dofile(MODULES .. "pipeline"),
}
local Clipboard        = mod._modules.clipboard
local SlugCache        = mod._modules.slug_cache
local Fetch            = mod._modules.fetch
local Parser           = mod._modules.parser
local EquipmentParser  = mod._modules.equipment_parser
local Pipeline         = mod._modules.pipeline

local _pending          = nil

local FETCH_TIMEOUT_SEC = 30
local POLL_INTERVAL_SEC = 0.1

mod.is_fetch_in_flight = function() return _pending ~= nil end

local HTML_CACHE_MAX = 16
local _html_cache = mod:persistent_table("html_cache", { entries = {}, order = {} })

local function _cache_touch(url)
	for i = #_html_cache.order, 1, -1 do
		if _html_cache.order[i] == url then
			table.remove(_html_cache.order, i)
			break
		end
	end
	_html_cache.order[#_html_cache.order + 1] = url
end

local function cache_get(url)
	local html = _html_cache.entries[url]
	if not html then return nil end
	local uuid = url:match("/builds/([0-9a-fA-F%-]+)$")
	if uuid and not html:find(uuid, 1, true) then
		_html_cache.entries[url] = nil
		for i = #_html_cache.order, 1, -1 do
			if _html_cache.order[i] == url then table.remove(_html_cache.order, i); break end
		end
		mod:warning("[cache] discarding poisoned entry for %s (UUID not in cached HTML)", url)
		return nil
	end
	_cache_touch(url)
	return html
end

local function cache_put(url, html)
	if _html_cache.entries[url] then
		_cache_touch(url)
		_html_cache.entries[url] = html
		return
	end
	while #_html_cache.order >= HTML_CACHE_MAX do
		local oldest = table.remove(_html_cache.order, 1)
		_html_cache.entries[oldest] = nil
	end
	_html_cache.entries[url] = html
	_html_cache.order[#_html_cache.order + 1] = url
end

local function on_build_html_ready(html, url, mode)
	if not html or #html == 0 then
		mod:notify(mod:localize("loc_lantern_toast_empty_response"))
		return
	end

	local title          = Parser.parse_title(html)
	local archetype_slug = Parser.parse_archetype_slug(html)
	local anchors        = Parser.parse_active_anchors(html)
	mod.dbg("[parse] title=%s slug=%s active_anchors=%d", tostring(title), tostring(archetype_slug), #anchors)

	if not archetype_slug or #anchors == 0 then
		mod._modules.popups.error(
			mod:localize("mod_name"),
			mod:localize("loc_lantern_err_no_talents_body"))
		return
	end

	cache_put(url, html)

	local equipment = EquipmentParser.parse(html)
	local total_stats = 0
	for _, w in ipairs(equipment.weapons or {}) do total_stats = total_stats + #(w.stats or {}) end
	mod.dbg("[equipment] parsed weapons=%d, curios=%d, weapon_stats=%d",
		#(equipment.weapons or {}), #(equipment.curios or {}), total_stats)

	local slug_to_talent = {}
	local cache = SlugCache.get()
	local cache_changed = false
	for _, a in ipairs(anchors) do
		if a.talent_id then
			slug_to_talent[a.slug] = a.talent_id
			if not cache[a.slug] then
				cache[a.slug] = a.talent_id
				cache_changed = true
			end
		end
	end
	for slug, talent_id in pairs(cache) do
		if not slug_to_talent[slug] then slug_to_talent[slug] = talent_id end
	end
	if cache_changed then SlugCache.save() end

	Pipeline.apply_build({
		title           = title,
		archetype_slug  = archetype_slug,
		anchors         = anchors,
		slug_to_talent  = slug_to_talent,
		mode            = mode,
		url             = url,
		equipment       = equipment,
	})
end

mod.run_import = function(mode, opts)
	opts = opts or {}
	local raw = Clipboard.read()
	local url = Clipboard.extract_gameslantern_url(raw)
	if not url then
		if opts.notify_when_empty then
			mod:notify(mod:localize("loc_lantern_toast_no_url"))
		end
		return false
	end
	if _pending and _pending.url == url then
		mod.dbg("[run_import] same URL already in flight; dedup")
		return false
	end
	local cached = cache_get(url)
	if cached then
		if _pending then
			mod.dbg("[run_import] URL changed; orphaning previous fetch seq=%d", _pending.seq)
		end
		mod.dbg("[run_import] cache hit for %s", url)
		_pending = {
			url         = url,
			mode        = mode,
			started_t   = os.clock(),
			cached_html = cached,
		}
		return true
	end
	local fetch = Fetch.spawn_build(url)
	if not fetch then return false end
	if _pending then
		mod.dbg("[run_import] URL changed; orphaning previous fetch seq=%d", _pending.seq)
	end
	_pending = {
		url       = url,
		mode      = mode,
		started_t = os.clock(),
		html_path = fetch.html_path,
		done_path = fetch.done_path,
		bat_path  = fetch.bat_path,
		seq       = fetch.seq,
	}
	mod:notify(mod:localize("loc_lantern_toast_fetching"))
	return true
end

mod.update = function(dt)
	if not _pending then return end
	if _pending.cached_html then
		local p = _pending
		_pending = nil
		on_build_html_ready(p.cached_html, p.url, p.mode)
		return
	end
	local now = os.clock()
	if now - _pending.started_t > FETCH_TIMEOUT_SEC then
		local p = _pending
		_pending = nil
		mod:warning("[fetch] timed out seq=%d", p.seq)
		mod:notify(mod:localize("loc_lantern_toast_fetch_timeout"))
		Fetch.safe_remove(p.html_path)
		Fetch.safe_remove(p.done_path)
		Fetch.safe_remove(p.bat_path)
		return
	end
	if (_pending.last_poll_t or 0) + POLL_INTERVAL_SEC > now then return end
	_pending.last_poll_t = now

	local f = Mods.lua.io.open(_pending.done_path, "rb")
	if f then
		f:close()
		local p = _pending
		_pending = nil
		local html = Fetch.read_file(p.html_path)
		Fetch.safe_remove(p.html_path)
		Fetch.safe_remove(p.done_path)
		Fetch.safe_remove(p.bat_path)
		on_build_html_ready(html, p.url, p.mode)
	end
end

mod.on_all_mods_loaded = function()
	local meta = SlugCache.get_metadata()
	local cache = SlugCache.get()
	local count = 0; for _ in pairs(cache) do count = count + 1 end
	mod:info("v%s | slug_cache: %d entries (game %s, built %s)",
		mod.version, count, meta and meta.game_version or "?", meta and meta.cache_built or "?")

	Fetch.sweep_orphans()

	mod:add_global_localize_strings({
		loc_lantern_recheck_clipboard = {
			en = "Re-check Clipboard for GamesLantern link",
		},
	})

	mod:command("lantern", "Apply a gameslantern build URL (overwrites current preset)", function()
		mod.run_import("overwrite_current", { notify_when_empty = true })
	end)

	mod:command("lantern_show_equipment", "Print the active preset's stored gameslantern equipment recommendation", function()
		local ProfileUtils = require("scripts/utilities/profile_utils")
		local active_id = ProfileUtils.get_active_profile_preset_id()
		if not active_id then mod:echo("no active preset"); return end
		local eq = mod._modules.equipment_store.get(active_id)
		if not eq then mod:echo("preset %s has no stored equipment", tostring(active_id)); return end
		mod:echo("=== preset %s equipment ===", tostring(active_id))
		for i, w in ipairs(eq.weapons or {}) do
			mod:echo("  weapon %d: %s (%s)", i, tostring(w.name), tostring(w.rarity))
			for _, b in ipairs(w.blessings or {}) do
				mod:echo("    blessing trait_%s: %s", tostring(b.trait_id), tostring(b.name))
			end
		end
		for i, c in ipairs(eq.curios or {}) do
			mod:echo("  curio %d: %s — %s", i, tostring(c.name), tostring(c.primary))
			for _, m in ipairs(c.secondary or {}) do
				mod:echo("    %s", m)
			end
		end
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "cb_add_new_profile_preset", function(orig, self, ...)
		if mod.run_import("new_preset") then
			return
		end
		return orig(self, ...)
	end)

	mod:hook(CLASS.InventoryView, "_setup_individual_layout", function(orig, self, layout)
		local ret = orig(self, layout)
		mod._modules.equipment_overlay.install(self)
		return ret
	end)
	mod:hook(CLASS.InventoryView, "_draw_loadout_widgets", function(orig, self, dt, t, input_service, ui_renderer)
		orig(self, dt, t, input_service, ui_renderer)
		mod._modules.equipment_overlay.draw(self, dt, t, input_service, ui_renderer)
	end)
	mod:hook(CLASS.InventoryView, "on_exit", function(orig, self, ...)
		mod._modules.equipment_overlay.teardown(self)
		return orig(self, ...)
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "can_add_profile_preset", function(orig, self)
		if mod.is_fetch_in_flight() then return false end
		return orig(self)
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "_remove_profile_preset", function(orig, self, widget, element)
		local idx = self._active_customize_preset_index
		local preset_id = idx and self:_get_profile_preset_id_by_widget_index(idx)
		local ret = orig(self, widget, element)
		if preset_id and mod._modules.equipment_store then
			mod._modules.equipment_store.clear(preset_id)
		end
		return ret
	end)

	mod:hook(CLASS.InventoryBackgroundView, "_setup_input_legend", function(orig, self, ...)
		local ret = orig(self, ...)
		local legend = self._input_legend_element
		if legend and type(legend.add_entry) == "function" then
			legend:add_entry(
				"loc_lantern_recheck_clipboard",
				"hotkey_menu_special_2",
				function(parent)
					if parent._is_readonly then return false end
					local av = parent._active_view
					return av == "talent_builder_view" or av == "broker_stimm_builder_view"
				end,
				function(_id, _pressed)
					mod.run_import("overwrite_current", { notify_when_empty = true })
				end,
				"right_alignment"
			)
		end
		return ret
	end)
end
