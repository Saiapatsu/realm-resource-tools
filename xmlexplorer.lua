local fs = require "fs"
local xmls = require "xmls"

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local srcdir  = rootdir .. "src\\"

function find(self, match, i)
	for i = i or 1, #self do
		if self[i]._name == match then
			return self[i]
		end
	end
end

local root = {}
local counts = {}

for filename in fs.scandirSync(srcdir .. "data") do
-- for filename in fs.scandirSync(rootdir .. "haizor") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	-- local parser = xmls.parser(fs.readFileSync(rootdir .. "haizor\\" .. filename))
	local stack = {root}
	while true do
		local type, value, loc = parser()
		if type == "tag" then
			local tbl = find(stack[#stack], value)
			if not tbl then
				tbl = {_name = value}
				table.insert(stack[#stack], tbl)
			end
			table.insert(stack, tbl)
			counts[tbl] = (counts[tbl] or 0) + 1
			
			for attr, value in parser do
				local tbl = find(stack[#stack], "@" .. attr)
				if not tbl then
					tbl = {_name = "@" .. attr}
					table.insert(stack[#stack], tbl)
				end
				counts[tbl] = (counts[tbl] or 0) + 1
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
		prn(v, v._name, level + 1)
	end
end

prn(root, "root", 0)
