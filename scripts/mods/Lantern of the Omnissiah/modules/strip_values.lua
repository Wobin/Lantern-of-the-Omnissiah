return function(s)
	if not s then return "" end
	s = tostring(s):lower():gsub("[%d%%%+%-–%.,]+", " "):gsub("%s+", " ")
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
