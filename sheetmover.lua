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
		"-depth 8",
		"-background #00000000",
		filepath,
		"-alpha Background", -- normalize fully transparent pixels
		" -crop", w .. "x" .. h,
		-- "-append",
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

-- print stats
for _,v in ipairs(statlist) do print(v .. string.rep(" ", 11 - #v) .. stats[v]) end

-----------------------------------

do return end

print("Updating data")

local function num(str)
	if string.sub(str, 1, 2) == "0x" then
		return assert(tonumber(string.sub(str, 3), 16))
	else
		return assert(tonumber(str))
	end
end

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
	local atom = makePos(file, num(index))
	if srcPosToDstPos[atom] then
		print("Moving:" .. atom .. " to " .. srcPosToDstPos[atom])
		-- table.insert(rope, string.sub(parser.str, cursor, locA - 1)) -- up to text
		-- table.insert(rope, string.sub(parser.str, locB, locC - 1)) -- between texts
		-- cursor = locD
	end
end

local Object = {
	Texture = Texture,
	AnimatedTexture = AnimatedTexture,
	Animation = {},
}

local Root = {
	Objects = {Object = Object},
	Object = Object, -- yes, some of the xmls have no root element
	GroundTypes = {},
}

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	
	rope, cursor = {}, 1
	xmls.scan(parser, Root)
	-- concat rope, output
end
