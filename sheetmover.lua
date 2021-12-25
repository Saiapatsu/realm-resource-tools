local fs = require "fs"
local json = require "json"
local xmls = require "xmls"

-- warning: naive popen()

-- todo: add xmls attribute support, harvest type="", map onto z-curve
-- set bits in a table, keep track of highest set index (sparse array..)
-- string.rep("\0"):gsub(., remap), pipe to magick gray:-
-- maybe let each non-null byte stand for the sheet it was used in?
-- but you need to create a report anyway...

-- todo: ensure it works fine when simply renaming a file (e.g. arena to arena8x8)

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local srcdir  = rootdir .. "src\\"
local dstdir  = rootdir .. "dst\\"

local function print(...)
	local list = {...}
	for k, v in ipairs(list) do list[k] = tostring(v) end
	io.stderr:write(table.concat(list, "\t") .. "\n")
end

local function tonumber2(str)
	if string.sub(str, 1, 2) == "0x" then
		return assert(tonumber(string.sub(str, 3), 16))
	else
		return assert(tonumber(str))
	end
end

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
--]]

local typeid = {}
local types = {}
local lasttype = 0

local function HasType(parser)
	local type, id
	for attr, value in parser do
		if
			attr == "type" then type = tonumber2(value) elseif
			attr == "id"   then id   = value
		end
	end
	if typeid[type] then
		print(type, id)
	else
		typeid[type] = id
		table.insert(types, type)
		lasttype = math.max(lasttype, type)
	end
	xmls.wastecontent(parser)
end

local Root = {
	-- Objects = {
		-- Object = HasType,
	-- },
	GroundTypes = {
		Ground = HasType,
	},
}

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	
	rope, cursor = {}, 1
	xmls.scan(parser, Root)
	-- concat rope, output
end

print("max", lasttype)

table.sort(types)

for _,type in ipairs(types) do
	io.write(type .. "\t" .. typeid[type] .. "\n")
end

do return end

local log2 = 0
while lasttype ~= 0 do
	log2 = log2 + 1
	lasttype = bit.rshift(lasttype, 1)
end

log2 = log2 + 1
log2 = log2 + bit.band(log2, 1)

local size = bit.lshift(1, log2) - 1
local imgsize = bit.lshift(1, log2 / 2)

print("log2", log2)
print("size", size)
print("imgsize", imgsize)

local file = io.popen(table.concat({
	"magick",
	"-depth 8",
	"-size " .. imgsize .. "x" .. imgsize,
	"GRAY:-",
	"out.png",
}, " "), "wb")
file:write(string.rep("\0", size):gsub("().", function(type) return typeid[type] and "\255" end))
file:close()

do return end

-- iterator that returns size bytes of a file each time
function chunker(file, size)
	return function(file, index)
		local data = file:read(size)
		if data then
			return index + 1, data
		end
	end, file, -1
end

-- perform a callback for each wxh square in an image
local function readSprites(filepath, w, h, callback)
	-- size of each sprite in bytes
	local size = w * h * 4
	-- split image into sprites
	local file = io.popen(table.concat({
		"magick",
		filepath,
		-- normalize fully transparent pixels
		"-background #00000000",
		"-alpha Background",
		-- split
		" -crop", w .. "x" .. h,
		-- output
		"-depth 8",
		"RGBA:-",
	}, " "), "rb")
	-- read each sprite and map it to a position in a file
	for index, tile in chunker(file, size) do
		callback(index, tile)
	end
	file:close()
end

-- local function writeSprites(filepath, w, h)
-- magick montage is fine here...
-- file:write(sprite)
-- file:close()

-- sprite location to string
local function makePos(id, i)
	return string.format("%s:%s", id, i)
end

local stats = {}
local statlist = {}
-- for lack of a ++ operator
local function stat(key)
	stats[key] = 0
	table.insert(statlist, key)
	return function(n)
		stats[key] = stats[key] + (n or 1)
	end
end

local srcamount  = stat "srcamount"  -- total amount of tiles
local dstamount  = stat "dstamount"  -- total amount of tiles
local srctile    = stat "srctile"    -- amount of non-empty tiles
local dsttile    = stat "dsttile"    -- amount of non-empty tiles
local srcuniq    = stat "srcuniq"    -- amount of unique tiles
local dstuniq    = stat "dstuniq"    -- amount of unique tiles
local dstcommon  = stat "dstcommon"  -- amount of tiles common with src
local dstmoved   = stat "dstmoved"   -- amount of tiles common with src that have moved
local dstadded   = stat "dstadded"   -- amount of tiles only present in dst
local dstremoved = stat "dstremoved" -- amount of tiles only present in src

-----------------------------------

-- Outside of rotmg, source images might be images in a folder,
-- here they're assetlibrary entries

print("Reading source images")
local srcTileToPos = {}
local srcPosToTile = {}

for id, asset in pairs(json.parse(fs.readFileSync(srcdir .. "assets\\assets.json"))) do
	readSprites(srcdir .. "assets\\" .. asset.file, asset.w, asset.h, function(i, tile)
		srcamount()
		
		if tile:match("[^%z]") then
			-- substantial tile
			srctile()
			
			local atom = makePos(id, i)
			srcPosToTile[atom] = tile
			
			if not srcTileToPos[tile] then
				-- unique tile
				srcuniq()
				srcTileToPos[tile] = atom
				
			end
		end
	end)
end

-----------------------------------

print("Reading destination images")
local srcPosToDstPos = {}
local dstTileToPos = {}

for id, asset in pairs(json.parse(fs.readFileSync(dstdir .. "assets\\assets.json"))) do
	readSprites(dstdir .. "assets\\" .. asset.file, asset.w, asset.h, function(i, tile)
		dstamount()
		
		if tile:match("[^%z]") then
			-- substantial tile
			dsttile()
			
			local atom = makePos(id, i)
			local match = srcTileToPos[tile]
			
			if not dstTileToPos[tile] then
				-- unique tile
				dstuniq()
				dstTileToPos[tile] = atom
			end
			
			if match then
				-- common with src
				dstcommon()
				
				if atom ~= match and srcPosToTile[atom] ~= tile then
					-- tile in common with src found at a different position
					-- and the tile in the same spot in src as in dst aren't the same tile
					-- print("Moved:" .. match .. " -> " .. atom)
					dstmoved()
					srcPosToDstPos[match] = atom
				end
				
			else
				-- only in dst, not in src
				dstadded()
				print("New tile: " .. atom)
			end
		end
	end)
end

-- count tiles that are only in src, not in dst
for k in pairs(srcTileToPos) do
	if not dstTileToPos[k] then
		dstremoved()
		print("Missing tile: " .. k)
	end
end

-----------------------------------

print("Stats")

-- print stats
for _,v in ipairs(statlist) do print(v .. string.rep(" ", 11 - #v) .. stats[v]) end

-----------------------------------

print("Updating data")

local rope, cursor

function Texture(parser)
	-- <Texture><File>file</File><Index>0</Index></Texture>
	-- A, B, C, D are start of text, etag, text, etag respectively
	local lkey, file , locA, locA, locB = assert(xmls.kvtags(parser))
	local rkey, index, locC, locC, locD = assert(xmls.kvtags(parser))
	assert(xmls.tags(parser) == nil)
	-- might as well enforce an order if they're all like this in real data
	assert(lkey == "File")
	assert(rkey == "Index")
	-- print(lkey, lvalue, rkey, rvalue)
	local atom = makePos(file, tonumber2(index))
	if srcPosToDstPos[atom] then
		print("Moving " .. atom .. " to " .. srcPosToDstPos[atom])
		-- table.insert(rope, string.sub(parser.str, cursor, locA - 1)) -- up to text
		-- table.insert(rope, string.sub(parser.str, locB, locC - 1)) -- between texts
		-- cursor = locD
	end
end

-- xmls.children{Texture = Texture, Animation = xmls.children{}}
-- xmls.descendants{Texture = Texture}
-- maybe propagate varargs??

local Root = {
	Objects = {
		Object = {
			Texture = Texture,
			AnimatedTexture = AnimatedTexture,
			Animation = {
				Frame = {
					Texture = Texture,
					AnimatedTexture = AnimatedTexture,
				},
			},
		},
	},
	GroundTypes = {},
}

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	
	rope, cursor = {}, 1
	xmls.scan(parser, Root)
	-- concat rope, output
end
