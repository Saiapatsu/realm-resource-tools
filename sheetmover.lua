-- sheetmover [<srcdir>] [<dstdir>]

local fs = require "fs"
local json = require "json"
local xmls = require "xmls"
local common = require "common"

-- warning: naive popen()
local srcdir = args[2] or "src"
local dstdir = args[3] or "dst"

local chunker = common.chunker
local readSprites = common.readSprites
local makePos = common.makePos

-----------------------------------

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

local assets = json.parse(fs.readFileSync(srcdir .. "assets\\assets.json"))

for id, asset in pairs(assets.images) do
	local emptytile = string.rep("\0", asset.w * asset.h * 4)
	
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

local assets = json.parse(fs.readFileSync(dstdir .. "assets\\assets.json"))

for id, asset in pairs(assets.images) do
	local emptytile = string.rep("\0", asset.w * asset.h * 4)
	
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
for k, v in pairs(srcTileToPos) do
	if not dstTileToPos[k] then
		dstremoved()
		print("Missing tile: " .. v)
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
	xmls.wasteAttr(parser)
	-- <Texture><File>file</File><Index>0</Index></Texture>
	-- A, B, C, D are start of text, etag, text, etag respectively
	local lkey, file , locA, locA, locB = assert(xmls.kvtags(parser))
	local rkey, index, locC, locC, locD = assert(xmls.kvtags(parser))
	assert(xmls.tags(parser) == nil)
	-- might as well enforce an order if they're all like this in real data
	assert(lkey == "File")
	assert(rkey == "Index")
	-- print(lkey, lvalue, rkey, rvalue)
	local atom = makePos(file, tonumber(index))
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
