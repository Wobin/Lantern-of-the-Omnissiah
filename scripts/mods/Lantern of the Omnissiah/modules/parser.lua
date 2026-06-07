local M = {}

function M.parse_title(html)
	for block in html:gmatch('<script[^>]+type="application/ld%+json"[^>]*>%s*(.-)%s*</script>') do
		local title = block:match('"headLine"%s*:%s*"(.-)"')
		if title then
			title = title:gsub('\\/', '/'):gsub('\\"', '"'):gsub('\\\\', '\\')
			return title
		end
	end
end

function M.parse_author(html)
	for block in html:gmatch('<script[^>]+type="application/ld%+json"[^>]*>%s*(.-)%s*</script>') do
		local author = block:match('"author".-"name"%s*:%s*"(.-)"')
			or block:match('"author"%s*:%s*"(.-)"')
		if author then
			author = author:gsub('\\/', '/'):gsub('\\"', '"'):gsub('\\\\', '\\')
			return author
		end
	end
end

function M.parse_archetype_slug(html)
	for block in html:gmatch('<script[^>]+type="application/ld%+json"[^>]*>%s*(.-)%s*</script>') do
		if block:find('"BreadcrumbList"', 1, true) then
			local slug = block:match('"position":3.-"@id":"[^"]-\\/builds\\/([%a%-]+)"')
			if slug then return slug end
		end
	end
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

return M
