--[[
Name: Lantern of the Omnissiah
Author: Wobin
Date: 20/08/2026
Repository: https://github.com/Wobin/Lantern-of-the-Omnissiah
--]]

local mod = get_mod("Lantern of the Omnissiah")
mod.version = mod.get_metadata and mod:get_metadata("version") or "unknown"

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
	name_key          = mod:io_dofile(MODULES .. "name_key"),
	strip_values      = mod:io_dofile(MODULES .. "strip_values"),
	equipment_overlay = mod:io_dofile(MODULES .. "equipment_overlay"),
	layout            = mod:io_dofile(MODULES .. "layout"),
	popups            = mod:io_dofile(MODULES .. "popups"),
	preset            = mod:io_dofile(MODULES .. "preset"),
	pipeline          = mod:io_dofile(MODULES .. "pipeline"),
	export              = mod:io_dofile(MODULES .. "export"),
	export_maps         = mod:io_dofile("Lantern of the Omnissiah/scripts/mods/Lantern of the Omnissiah/gameslantern_export_maps"),
	talent_target_store = mod:io_dofile(MODULES .. "talent_target_store"),
	talent_rings        = mod:io_dofile(MODULES .. "talent_rings"),
	export_button       = mod:io_dofile(MODULES .. "export_button"),
	loadout_recommendation = mod:io_dofile(MODULES .. "loadout_recommendation"),
	build_store         = mod:io_dofile(MODULES .. "build_store"),
	staged_build        = mod:io_dofile(MODULES .. "staged_build"),
	build               = mod:io_dofile(MODULES .. "build"),
	import_menu         = mod:io_dofile(MODULES .. "import_menu"),
}
local Clipboard        = mod._modules.clipboard
local SlugCache        = mod._modules.slug_cache
local Fetch            = mod._modules.fetch
local Parser           = mod._modules.parser
local EquipmentParser  = mod._modules.equipment_parser
local Pipeline         = mod._modules.pipeline

local _pending          = nil
local _test             = nil

local FETCH_TIMEOUT_SEC = 30
local POLL_INTERVAL_SEC = 0.1

mod.is_fetch_in_flight = function() return _pending ~= nil end

local _rings_enabled = true

local function refresh_ring_setting()
	_rings_enabled = mod:get("show_build_rings")
	if _rings_enabled == nil then _rings_enabled = true end
	mod._modules.talent_rings.set_enabled(_rings_enabled)
end

function mod.copy_bookmarklet()
	local bm = mod._modules.export.BOOKMARKLET
	if not bm then mod:echo("(bookmarklet unavailable)"); return end
	local method = mod._modules.clipboard.write(bm)
	if method == "clipboard" then
		mod:notify(mod:localize("loc_lantern_toast_bookmarklet_clipboard"))
	elseif method == "file" then
		mod:notify(mod:localize("loc_lantern_toast_bookmarklet_file", mod._modules.clipboard.export_file_path()))
	else
		mod:notify(mod:localize("loc_lantern_toast_export_failed"))
	end
end

function mod.on_setting_changed(setting_id)
	if setting_id == "show_build_rings" then
		refresh_ring_setting()
	end
end

local function push_active_target()
	local ProfileUtils = require("scripts/utilities/profile_utils")
	local id = ProfileUtils.get_active_profile_preset_id()
	local set = id and mod._modules.build_store.target_set(id) or nil
	mod._modules.talent_rings.set_target(set)
end

local function build_equipment(player)
	local ItemUtils = require("scripts/utilities/items")
	local MasterItems = require("scripts/backend/master_items")
	local WeaponTemplates = require("scripts/utilities/weapon/weapon_template")
	local Export = mod._modules.export
	local Maps = mod._modules.export_maps
	local maps = {
		name_key = mod._modules.name_key,
		WEAPONS = Maps.WEAPONS, WEAPON_BARS = Maps.WEAPON_BARS, WEAPON_TRAITS = Maps.WEAPON_TRAITS,
		CURIOS = Maps.CURIOS, CURIO_TRAITS = Maps.CURIO_TRAITS,
		WEAPON_MODIFIERS = Maps.WEAPON_MODIFIERS, CURIO_MODIFIERS = Maps.CURIO_MODIFIERS,
	}
	local profile = player and player:profile()
	local lo = profile and profile.loadout or {}

	local function blessing_ns(item)
		local out = {}
		for _, t in ipairs(item.traits or {}) do
			local mi = MasterItems.get_item(t.id)
			local n = mi and mi.icon and tostring(mi.icon):match("weapon_trait_(%d+)")
			out[#out + 1] = n and tonumber(n) or false
		end
		return out
	end
	local function stat_display(item)
		local disp = {}
		local ok, tmpl = pcall(WeaponTemplates.weapon_template_from_item, item)
		if ok and tmpl and tmpl.base_stats then
			for stat_name, cfg in pairs(tmpl.base_stats) do
				if cfg.display_name then disp[stat_name] = Localize(cfg.display_name) end
			end
		end
		return disp
	end
	local strip_values = mod._modules.strip_values
	local function perk_effects(item)
		local out = {}
		for _, p in ipairs(item.perks or {}) do
			local mi = MasterItems.get_item(p.id)
			local desc = mi and ItemUtils.trait_description and ItemUtils.trait_description(mi, p.rarity, p.value)
			out[#out + 1] = strip_values(desc or "")
		end
		return out
	end

	local weapons, curios, unmatched = {}, {}, 0
	for _, slot in ipairs({ "slot_primary", "slot_secondary" }) do
		local it = lo[slot]
		if it and it.name then
			local e, miss = Export._weapon_entry({
				display_name = ItemUtils.display_name(it), rarity = it.rarity or 5,
				base_stats = it.base_stats or {}, stat_display = stat_display(it),
				blessing_ns = blessing_ns(it), perk_effects = perk_effects(it),
			}, maps)
			if e then weapons[#weapons + 1] = e else unmatched = unmatched + 1; mod.dbg("[export] no GL weapon match %s (nk=%s)", slot, tostring(miss)) end
		end
	end
	for _, slot in ipairs({ "slot_attachment_1", "slot_attachment_2", "slot_attachment_3" }) do
		local it = lo[slot]
		if it and it.name then
			local mi = MasterItems.get_item(it.name)
			local dn = mi and mi.display_name and Localize(mi.display_name) or ""
			local stat_txt = (ItemUtils.display_name(it) or ""):lower()
			local kw
			for _, k in ipairs({ "health", "toughness", "stamina", "wound" }) do
				if stat_txt:find(k, 1, true) then kw = k; break end
			end
			local e, miss = Export._curio_entry({ display_name = dn, rarity = it.rarity or 5, stat_keyword = kw, perk_effects = perk_effects(it) }, maps)
			if e then curios[#curios + 1] = e else unmatched = unmatched + 1; mod.dbg("[export] no GL curio match %s (nk=%s)", slot, tostring(miss)) end
		end
	end
	return weapons, curios, unmatched
end

local function run_export(player)
	local Maps   = mod._modules.export_maps
	local local_player = Managers.player and Managers.player:local_player(1)
	player = player or local_player
	local profile = player and player:profile()
	if not profile then mod:notify(mod:localize("loc_lantern_toast_no_player")); return end
	local archetype = profile.archetype and profile.archetype.name
	local class_id = archetype and Maps.CLASS_MAP[archetype]
	local class_nodes = archetype and Maps.TALENT_NODES[archetype]
	if not class_id or not class_nodes then mod:echo("[export] no export map for archetype %s", tostring(archetype)); return end

	local build = mod._modules.build.from_profile(player)
	if not build or not next(build.node_tiers) then mod:notify(mod:localize("loc_lantern_toast_export_empty")); return end

	local weapons, curios, unmatched_eq = build_equipment(player)
	local json, counts = mod._modules.build.to_gl_json(build, { weapons = weapons, curios = curios })
	if not json then mod:echo("[export] no export map for archetype %s", tostring(archetype)); return end
	local method = mod._modules.clipboard.write(json)
	local staged = false
	if player ~= local_player and build then
		mod._modules.staged_build.set(build)
		staged = true
	end
	mod.dbg("[export] archetype=%s default=%d stimm=%d skipped=%d unmatched_eq=%d method=%s staged=%s",
		tostring(archetype), counts.default, counts.stimm, counts.skipped or 0, unmatched_eq, tostring(method), tostring(staged))
	if method == "clipboard" then
		if staged then
			mod:notify(mod:localize("loc_lantern_toast_export_staged"))
		else
			mod:notify(mod:localize("loc_lantern_toast_export_clipboard2", counts.default + counts.stimm, #weapons, #curios))
		end
	elseif method == "file" then
		mod:notify(mod:localize("loc_lantern_toast_export_file", mod._modules.clipboard.export_file_path()))
	else
		mod:notify(mod:localize("loc_lantern_toast_export_failed"))
	end
end

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
	equipment.title  = title
	equipment.author = Parser.parse_author(html)
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
	local fetch, reason = Fetch.spawn_build(url)
	if not fetch then
		if reason == "linux_unsupported" then
			mod:notify(mod:localize("loc_lantern_toast_linux_unsupported"))
		end
		return false
	end
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
		err_path  = fetch.err_path,
		seq       = fetch.seq,
	}
	mod:notify(mod:localize("loc_lantern_toast_fetching"))
	return true
end

local function _test_cleanup(h)
	Fetch.safe_remove(h.html_path)
	Fetch.safe_remove(h.done_path)
	Fetch.safe_remove(h.bat_path)
	Fetch.safe_remove(h.err_path)
end

mod.update = function(dt)
	if _test then
		local h = _test.handle
		if os.clock() - _test.started_t > FETCH_TIMEOUT_SEC then
			_test = nil
			mod:echo("[fetchtest] TIMEOUT after %ds — done file never appeared", FETCH_TIMEOUT_SEC)
			_test_cleanup(h)
		else
			local tf = Mods.lua.io.open(h.done_path, "rb")
			if tf then
				tf:close()
				_test = nil
				local html = Fetch.read_file(h.html_path)
				local code, err = Fetch.read_diagnostics(h)
				mod:echo("[fetchtest] done exit=%s bytes=%s err=%s",
					tostring(code), tostring(html and #html or 0), tostring(err))
				_test_cleanup(h)
			end
		end
	end

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
		Fetch.safe_remove(p.err_path)
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
		if not html or #html == 0 then
			local code, err = Fetch.read_diagnostics(p)
			mod:warning("[fetch] empty html seq=%d curl_exit=%s stderr=%s",
				p.seq, tostring(code), tostring(err))
		end
		Fetch.safe_remove(p.html_path)
		Fetch.safe_remove(p.done_path)
		Fetch.safe_remove(p.bat_path)
		Fetch.safe_remove(p.err_path)
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

	mod._modules.talent_rings.install()
	refresh_ring_setting()

	mod:add_global_localize_strings({
		loc_lantern_recheck_clipboard = {
			en = "Re-check Clipboard for GamesLantern link",
		},
	})

	mod:command("lantern", "Apply a gameslantern build URL (overwrites current preset)", function()
		mod.run_import("overwrite_current", { notify_when_empty = true })
	end)

	mod:command("lantern_export", "Copy the current build's talents to the clipboard for Gameslantern export", function() run_export() end)

	mod:command("lantern_export_bookmarklet", "Copy the Gameslantern export bookmarklet to the clipboard", mod.copy_bookmarklet)

	mod:command("lantern_fetchtest", "Diagnostic: fetch a build URL via the active transport and report the result", function()
		local raw = Clipboard.read()
		local url = Clipboard.extract_gameslantern_url(raw)
			or "https://darktide.gameslantern.com/builds/a07df7b0-bb70-49fc-972e-237b68db7582"
		local wine = Application and Application.wine_version and Application.wine_version()
		local handle, reason = Fetch.spawn_build(url)
		if not handle then
			mod:echo("[fetchtest] spawn failed: %s (wine=%s)", tostring(reason), tostring(wine))
			return
		end
		_test = { handle = handle, started_t = os.clock() }
		mod:echo("[fetchtest] spawned (wine=%s) %s", tostring(wine), url)
	end)

	mod:command("lantern_show_equipment", "Print the active preset's stored gameslantern equipment recommendation", function()
		local ProfileUtils = require("scripts/utilities/profile_utils")
		local active_id = ProfileUtils.get_active_profile_preset_id()
		if not active_id then mod:echo("no active preset"); return end
		local eq = mod._modules.build_store.equipment(active_id)
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

	local function view_owns_build(self)
		return self._is_own_player and not self._is_readonly
	end

	mod:hook("TalentBuilderView", "on_enter", function(orig, self, ...)
		local ret = orig(self, ...)
		local owns = view_owns_build(self)
		mod._modules.talent_rings.set_active(owns)
		if owns then push_active_target() end
		return ret
	end)

	mod:hook("TalentBuilderView", "on_exit", function(orig, self, ...)
		mod._modules.talent_rings.set_active(false)
		return orig(self, ...)
	end)

	mod:hook("TalentBuilderView", "event_on_profile_preset_changed", function(orig, self, ...)
		local ret = orig(self, ...)
		if view_owns_build(self) then push_active_target() end
		return ret
	end)

	mod:command("lantern_show_target", "Print the active preset's stored talent-ring target set", function()
		local ProfileUtils = require("scripts/utilities/profile_utils")
		local id = ProfileUtils.get_active_profile_preset_id()
		if not id then mod:echo("no active preset"); return end
		local set = mod._modules.build_store.target_set(id)
		if not set then mod:echo("preset %s has no stored talent target", tostring(id)); return end
		local n = 0
		for w in pairs(set) do n = n + 1; mod:echo("  target: %s", tostring(w)) end
		mod:echo("=== preset %s target: %d nodes (rings=%s) ===", tostring(id), n, tostring(_rings_enabled))
	end)

	mod:hook(CLASS.InventoryBackgroundView, "on_enter", function(orig, self, ...)
		local ret = orig(self, ...)
		local view = self
		mod._modules.export_button.install(self, function()
			run_export(view._preview_player)
		end)
		return ret
	end)

	local function do_import_or_notify()
		local SB = mod._modules.staged_build
		local staged = SB and SB.get()
		if staged then
			local player = Managers.player and Managers.player:local_player(1)
			local profile = player and player:profile()
			local current = profile and profile.archetype and profile.archetype.name
			if staged.archetype == current then
				staged.node_tiers = mod._modules.build.budget_limit(staged.node_tiers, profile)
				local id = mod._modules.build.to_preset(staged, "new_preset")
				if id then
					SB.clear()
					local n = 0; for _ in pairs(staged.node_tiers or {}) do n = n + 1 end
					mod:notify(mod:localize("loc_lantern_toast_staged_imported", tostring(staged.title), n))
				end
				return
			end
			mod:notify(mod:localize("loc_lantern_toast_staged_mismatch", tostring(staged.archetype)))
			return
		end
		if not mod.run_import("new_preset") then
			mod:notify(mod:localize("loc_lantern_toast_nothing_to_import"))
		end
	end

	mod:hook(CLASS.ViewElementProfilePresets, "init", function(orig, self, ...)
		local ret = orig(self, ...)
		mod._modules.import_menu.install(self)
		return ret
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "cb_add_new_profile_preset", function(orig, self)
		mod._modules.import_menu.open(self, {
			on_import = do_import_or_notify,
			on_create = function() orig(self) end,
		})
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "update", function(orig, self, ...)
		local ret = orig(self, ...)
		mod._modules.import_menu.process(self)
		return ret
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "draw", function(orig, self, dt, t, ui_renderer, ...)
		mod._modules.import_menu.measure(self, ui_renderer)
		return orig(self, dt, t, ui_renderer, ...)
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

	mod:hook("InventoryWeaponsView", "draw", function(orig, self, dt, t, input_service, layer)
		orig(self, dt, t, input_service, layer)
		mod._modules.equipment_overlay.draw_weapon_select(self, dt, t, input_service, self._ui_default_renderer)
	end)

	mod:hook("CraftingMechanicusModifyView", "draw", function(orig, self, dt, t, input_service, layer)
		orig(self, dt, t, input_service, layer)
		mod._modules.equipment_overlay.draw_crafting(self, dt, t, input_service, self._ui_default_renderer)
	end)

	for _, view_name in ipairs({ "CraftingMechanicusReplacePerkView", "CraftingMechanicusReplaceTraitView" }) do
		mod:hook(view_name, "draw", function(orig, self, dt, t, input_service, layer)
			orig(self, dt, t, input_service, layer)
			mod._modules.equipment_overlay.draw_refine(self, dt, t, input_service, self._ui_renderer)
		end)
	end

	mod:hook(CLASS.ViewElementProfilePresets, "can_add_profile_preset", function(orig, self)
		if mod.is_fetch_in_flight() then return false end
		return orig(self)
	end)

	mod:hook(CLASS.ViewElementProfilePresets, "_remove_profile_preset", function(orig, self, widget, element)
		local idx = self._active_customize_preset_index
		local preset_id = idx and self:_get_profile_preset_id_by_widget_index(idx)
		local ret = orig(self, widget, element)
		if preset_id then
			mod._modules.build_store.clear(preset_id)
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


mod.on_settings_reset = function()
	refresh_ring_setting()
end