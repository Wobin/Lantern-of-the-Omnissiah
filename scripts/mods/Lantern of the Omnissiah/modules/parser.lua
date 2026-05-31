-- HTML parsing — pure functions over gameslantern's page HTML.
-- No engine deps, no mod state — easy to test in isolation.

local M = {}

-- Build title from the first JSON-LD <script type="application/ld+json">
-- block's BlogPosting.headLine field. Cleaner than scraping <title> (no site-
-- suffix stripping needed).
function M.parse_title(html)
	for block in html:gmatch('<script[^>]+type="application/ld%+json"[^>]*>%s*(.-)%s*</script>') do
		local title = block:match('"headLine"%s*:%s*"(.-)"')
		if title then
			title = title:gsub('\\/', '/'):gsub('\\"', '"'):gsub('\\\\', '\\')
			return title
		end
	end
end

-- Detect the archetype URL slug from any /talents/<slug>/<category>/<file>.webp
-- reference on the page (ignoring /talents/frames/...). Majority wins.
function M.parse_archetype_slug(html)
	local counts = {}
	for slug in html:gmatch('/talents/([%a%-]+)/[^/"]+/[%w_]+%.webp') do
		if slug ~= "frames" then counts[slug] = (counts[slug] or 0) + 1 end
	end
	local best, best_n = nil, 0
	for s, n in pairs(counts) do
		if n > best_n then best, best_n = s, n end
	end
	return best
end

-- Extract every active anchor on the build page. An "active anchor" is any
-- <a href="/abilities/<slug>"> block whose inner HTML contains a
-- class="ability-active ability" frame. For anchors that also contain a talent
-- icon (<image href="/talents/<arch>/<cat>/<talent_id>.webp">), we extract the
-- inline talent_id so we don't need a phase-2 fetch for that slug.
function M.parse_active_anchors(html)
	local anchors = {}
	for slug, content in html:gmatch('<a[^>]+href="[^"]*/abilities/([^"]+)"[^>]*>(.-)</a>') do
		if content:find('class="ability%-active ability"', 1, false) then
			local talent_id = content:match('href="[^"]*/talents/[%a%-]+/[^/"]+/([%w_]+)%.webp"')
			anchors[#anchors + 1] = { slug = slug, talent_id = talent_id }
		end
	end
	return anchors
end

-- Extract an in-game talent_id from an /abilities/<slug> page. Only accepts the
-- .png "hero image" URL (gameslantern.com/storage/.../<talent_id>.png). The
-- embedded talent-tree SVG uses .webp paths for ALL nodes on the page, so a
-- fallback to .webp would match the first node in the tree (always the top-left
-- talent) rather than the page's own ability — silently wrong, very destructive.
-- Returns nil if no .png hero image is present; the caller falls back to the
-- autocomplete-stat-parents heuristic in that case.
function M.parse_talent_id_from_ability_page(html)
	if not html then return nil end
	return html:match('/talents/[%a%-]+/[^/"]+/([%w_]+)%.png')
end

return M
