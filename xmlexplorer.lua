local fs = require "fs"
local xmls = require "xmls"

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local srcdir  = rootdir .. "src\\"

-- parse all xmls and output list of all tag breadcrumbs
--[[
local everything = {}
local everything2 = {}

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	local stack = {}
	while true do
		local type, value, loc = parser()
		if type == "tag" then
			table.insert(stack, value)
			local crumbs = table.concat(stack, ".")
			everything[crumbs] = (everything[crumbs] or 0) + 1
			
		elseif type == nil then
			if value == nil then break end -- end of document
			assert(table.remove(stack) == value, "mismatched end tag at " .. loc)
			
		end
	end
end

for k,v in pairs(everything) do
	table.insert(everything2, string.format("%04d", v) .. "\t" .. k)
end
table.sort(everything2, function(a, b) return a > b end)
for _,v in ipairs(everything2) do
	io.write(v .. "\n")
end
]]

-- hierarchical tags printer version 1
--[[
local root = {}
local counts = {}

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	local stack = {root}
	while true do
		local type, value, loc = parser()
		if type == "tag" then
			local tbl = stack[#stack][value]
			if not tbl then
				tbl = {}
				stack[#stack][value] = tbl
			end
			table.insert(stack, tbl)
			counts[tbl] = (counts[tbl] or 0) + 1
			
		elseif type == nil then
			if value == nil then break end -- end of document
			table.remove(stack)
			
		end
	end
end

local function prn(tbl, name, level)
	io.write(string.rep("\t", level) .. name .. " " .. (counts[tbl] or "X") .. "\n")
	for k,v in pairs(tbl) do
		prn(v, k, level + 1)
	end
end

prn(root, "root", 0)
]]

-- hierarchical tags printer version 2
--[[
function find(self, match, i)
	for i = i or 1, #self do
		if self[i]._name == match then
			return self[i]
		end
	end
end

local root = {}
local counts = {}

-- for filename in fs.scandirSync(srcdir .. "data") do
for filename in fs.scandirSync(rootdir .. "haizor") do
	local parser = xmls.parser(fs.readFileSync(rootdir .. "haizor\\" .. filename))
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
]]

--hierarchical tag printer version 3
--[[
function find(self, match, i)
	for i = i or 1, #self do
		if self[i]._name == match then
			return self[i]
		end
	end
end

local root = {}
local counts = {}

for filename in fs.scandirSync(rootdir .. "aoya") do
	local parser = xmls.parser(fs.readFileSync(rootdir .. "aoya\\" .. filename))
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
]]

-- ver 4
-- what the fuck am I doing
--[[

local counts = {}
local names = {}
local meta
meta = {
	__index = function(self, key)
		local value = setmetatable({}, meta)
		self[key] = value
		counts[value] = 0
		names[value] = key
		return value
	end,
}
local root = setmetatable({}, meta)
counts[root] = 0

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	local stack = {root}
	local head = root
	
	while true do
		local type, value, loc = parser()
		if type == "tag" then
			head = head[value]
			table.insert(stack, head)
			counts[head] = counts[head] + 1
			
			for attr, value in parser do
				attr = head["@" .. attr]
				counts[attr] = counts[attr] + 1
			end
			
		elseif type == nil then
			if value == nil then break end -- end of document
			head = table.remove(stack)
			-- print(string.rep("\t", #stack - 1) .. "End")
			
		end
	end
end

local function prn(tbl, name, level)
	-- local array = {}
	-- for k, v in pairs(tbl) do
		-- table.insert(array, v)
	-- end
	
	-- table.sort(array, function(a, b) return counts[a] > counts[b] end)
	
	-- for _,v in ipairs(array) do
		-- io.write(string.rep("\t", level) .. name .. " " .. counts[v] .. "\n")
		-- prn(v, names[v], level + 1)
	-- end
	
	io.write(string.rep("\t", level) .. name .. " " .. counts[tbl] .. "\n")
	for k,v in pairs(tbl) do
		prn(v, k, level + 1)
	end
end

prn(root, "root", 0)
--]]

-- last version, prints sorted tags and attributes
-- --[[
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
-- --]]
