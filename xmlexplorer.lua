--[[
xmlexplorer <inDirXml>

Print the hierarchy and amount of all tags in a folder full of xml files.

```
Objects 72
	Object 4827
		@type 4827
		@id 4827
		@setType 28
		@setName 28
		Class 4822
		Texture 3286
			File 3286
			Index 3286
		Description 1596
```
etc.
]]

local fs = require "fs"
local xmls = require "xmls2"
local common = require "./common"

local script, dir = unpack(args)
if dir == nil then io.stderr:write("No directory specified\n") return end

-----------------------------------

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

common.forEachXml(dir, function(xml)
	local stack = {root}
	while true do --> text
		local state = xml() --> ?
		
		if state == xml.STAG then
			local name = xml:cut(xml.pos, select(2, xml())) --> attr
			local tbl = get(stack[#stack], name)
			counts[tbl] = counts[tbl] + 1
			for k,v in xml:forAttr() do
				local tbl = get(tbl, "@" .. k)
				counts[tbl] = counts[tbl] + 1
			end --> tagend
			if select(2, xml()) then --> text
				table.insert(stack, tbl)
			end
			
		elseif state == xml.ETAG then
			table.remove(stack)
			xml() --> text
			
		elseif state == xml.EOF then
			break
			
		else
			xml() --> text
		end
	end
end)

local function sortfunc(a, b)
	local aa = string.sub(names[a], 1, 1) == "@"
	local bb = string.sub(names[b], 1, 1) == "@"
	if aa ~= bb then
		return aa
	else
		return counts[a] > counts[b]
	end
end

local function prn(tbl, name, level)
	table.sort(tbl, sortfunc)
	io.write(string.rep("\t", level) .. name .. " " .. counts[tbl] .. "\n")
	for i,v in ipairs(tbl) do
		prn(v, names[v], level + 1)
	end
end

for i,v in ipairs(root) do
	prn(v, names[v], 0)
end
