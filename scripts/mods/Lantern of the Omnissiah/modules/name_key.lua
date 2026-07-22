return function(s)
	local words = {}
	for w in tostring(s or ""):lower():gmatch("%w+") do
		words[#words + 1] = w
	end
	table.sort(words)
	return table.concat(words, " ")
end
