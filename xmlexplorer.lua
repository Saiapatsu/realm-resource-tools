local fs = require "fs"
local xmls = require "xmls"

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local srcdir  = rootdir .. "src\\"
local dir = srcdir .. "data"
-- local dir = rootdir .. "haizor"

local root = {}
local counts = {}
local names = {}

function find(self, match)
	for i = 1, #self do
		if names[self[i]] == match then
			return self[i]
		end
	end
end

local function get(tbl, key)
	local item = find(tbl, key)
	if not item then
		item = {}
		names[item] = key
		counts[item] = 0
		table.insert(tbl, item)
	end
	return item
end

for filename in fs.scandirSync(dir) do
	local parser = xmls.parser(fs.readFileSync(dir .. "\\" .. filename))
	local stack = {root}
	
	while true do
		local type, value, loc = parser()
		
		if type == "tag" then
			local tbl = get(stack[#stack], value)
			table.insert(stack, tbl)
			counts[tbl] = counts[tbl] + 1
			
			for attr, value in parser do
				attr = "@" .. attr
				local tbl = get(tbl, attr)
				counts[tbl] = counts[tbl] + 1
			end
			
		elseif type == nil then
			if value == nil then break end -- end of document
			table.remove(stack)
			
		end
	end
end

local function prn(tbl, name, level)
	table.sort(tbl, function(a, b) return counts[a] > counts[b] end)
	io.write(string.rep("\t", level) .. name .. " " .. (counts[tbl] or "X") .. "\n")
	for i,v in ipairs(tbl) do
		prn(v, names[v], level + 1)
	end
end

prn(root, "root", 0)
