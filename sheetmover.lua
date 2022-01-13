local fs = require "fs"
local json = require "json"
local xmls = require "xmls"

local DEPTH = 4

-- warning: naive popen()

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

-- https://stackoverflow.com/questions/4909263/how-to-efficiently-de-interleave-bits-inverse-morton
local function morton1(x)
	x = bit.band(x, 0x55555555);
	x = bit.band(bit.bor(x, bit.rshift(x, 1)), 0x33333333)
	x = bit.band(bit.bor(x, bit.rshift(x, 2)), 0x0F0F0F0F)
	x = bit.band(bit.bor(x, bit.rshift(x, 4)), 0x00FF00FF)
	x = bit.band(bit.bor(x, bit.rshift(x, 8)), 0x0000FFFF)
	return x
end

local typeid = {}
-- local types = {}
local lasttype = 0

local function HasType(parser)
	local type, id
	for attr, value in parser do
		if
			attr == "type" then type = tonumber2(value) elseif
			attr == "id"   then id   = value
		end
	end
	
	-- local x = morton1(type - 1)
	-- local y = morton1(bit.rshift(type - 1, 1))
	-- local index = y * 256 + x
	index = type
	
	if typeid[index] then
		-- print(type, id)
	else
		typeid[index] = id
		-- table.insert(types, type)
		lasttype = math.max(lasttype, type)
	end
	xmls.wastecontent(parser)
end

local Root = {
	Objects = {
		Object = HasType,
	},
	-- GroundTypes = {
		-- Ground = HasType,
	-- },
}

local dir = rootdir .. "haizor"
for filename in fs.scandirSync(dir) do
	local parser = xmls.parser(fs.readFileSync(dir .. "\\" .. filename))
	
	rope, cursor = {}, 1
	pcall(xmls.scan, parser, Root)
	-- concat rope, output
end

print("max", lasttype)

-- table.sort(types)

-- for _,type in ipairs(types) do
	-- io.write(type .. "\t" .. typeid[type] .. "\n")
-- end

local log2 = 0
while lasttype ~= 0 do
	log2 = log2 + 1
	lasttype = bit.rshift(lasttype, 1)
end

-- log2 = log2 + 1
-- log2 = log2 + bit.band(log2, 1)

-- local size = bit.lshift(1, log2) - 1
-- local imgsize = bit.lshift(1, log2 / 2)
local size = 256 * 256
local imgsize = 256

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

file:write(string.rep("\0", size):gsub("().", function(type) return typeid[type - 1] and "\255" end))

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
	local size = w * h * DEPTH
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
	local emptytile = string.rep("\0", asset.w * asset.h)
	
	readSprites(srcdir .. "assets\\" .. asset.file, asset.w, asset.h, function(i, tile)
		srcamount()
		
		if tile ~= emptytile then
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
	local emptytile = string.rep("\0", asset.w * asset.h * DEPTH)
	
	readSprites(dstdir .. "assets\\" .. asset.file, asset.w, asset.h, function(i, tile)
		dstamount()
		
		if tile ~= emptytile then
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
