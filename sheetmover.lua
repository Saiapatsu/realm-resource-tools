--[[
sheetmover <srcdir> <dstdir>
Fixes references to sprites in xmls after rearranging sprites in sheets.

srcdir and dstdir are shaped like this:
	xml\
		<xml files>
	sheets\
		<spritesheets>
	assets.json

assets.json is an ad-hoc conversion of AssetLoader.as (?) to JSON so as to avoid having to parse as3 in this script.
It is shaped like this:
{
	"images": {
		<asset name>: {
			"file": <asset file name>,
			"w": <tile width>,
			"h": <tile height>
		} ...
	},
	"animatedchars": {
		<asset name>: {
			"file": <asset file name>,
			"mask": <null|asset file name>,
			"w": <animation width>,
			"h": <animation height>,
			"sw": <tile width>,
			"sh": <tile height>,
			"facing": <"RIGHT"|"DOWN">,
		} ...
	}
}
For example, animatedchars.players.w is 56, h is 24, sw is 8, sh is 8.
facing and mask are unused.

Arrange your xmls, sheets and AssetLoader in the manner specified into srcdir.
Duplicate srcdir, let it be dstdir.
Make your rearrangements in dstdir\sheets.
	Do not accidentally modify/recolor, duplicate, add or lose any sprites.
	You can add new sheets if you create new assets for them in assets.json.
Run the script on the two directories.
Replace your sheets with dstdir\sheets, your AssetLoader with dstdir\assets.json and paste dstdir\xml over your xmls.
	The ultimate output of the script will be in dstdir\xml, although only the modified xmls will be written.

The script prefers to not modify sprite references if it's the same sprite at the same position in both src and dst.

The script might not play nice with duplicate tiles, preferring to choose a different sprite than where you intended to move a tile to.
I don't know the actual behavior because this script hasn't been battle-tested yet.
Ideally, it should point to the "new" position of the sprite, not to any other "stale" duplicate sprites. (That's a TODO.)

The script also warns about duplicate sprites.
A lot of them will come from sheets with white backgrounds, such as textiles and the silly faces Kabam devs left among the sheets, which should just be removed from AssetLoader.

This script does not account for animated textures' masks yet.
You're responsible for keeping the masks in sync.
In the future, the script could attempt move the masks around when the sheet is modified.
]]

local fs = require "fs"
local json = require "json"
local xmls = require "xmls"
local common = require "./common"
local chunker = common.chunker
local readSprites = common.readSprites
local makePos = common.makePos
local pathsep = common.pathsep
local printf = common.printf
local warnf = common.warnf

local script, srcdir, dstdir = unpack(args)
if srcdir == nil then warnf("No source directory specified") return end
if dstdir == nil then warnf("No destination directory specified") return end

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
local srcdup     = stat "srcdup"     -- amount of duplicate tiles
local dstdup     = stat "dstdup"     -- amount of duplicate tiles
local dstcommon  = stat "dstcommon"  -- amount of tiles common with src
local dstmoved   = stat "dstmoved"   -- amount of tiles common with src that have moved
local dstadded   = stat "dstadded"   -- amount of tiles only present in dst
local dstremoved = stat "dstremoved" -- amount of tiles only present in src

-----------------------------------

-- Outside of rotmg, source images might be images in a folder,
-- here they're assetlibrary entries

printf("Reading source images")
local srcTileToPos = {}
local srcPosToTile = {}
local srcTileToDupGroup = {}

local srcassets = json.parse(fs.readFileSync(srcdir .. pathsep .. "assets.json"))

local function doSrcAsset(id, asset)
	local emptytile = string.rep("\0", asset.w * asset.h * 4)
	
	readSprites(srcdir .. pathsep .. "sheets" .. pathsep .. asset.file, asset.w, asset.h, function(i, tile)
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
				
			else
				-- duplicate tile
				srcdup()
				local group = srcTileToDupGroup[tile]
				if group == nil then
					group = {}
					srcTileToDupGroup[tile] = group
					table.insert(group, srcTileToPos[tile])
				end
				table.insert(group, atom)
			end
		end
	end)
end

for id, asset in pairs(srcassets.images) do
	doSrcAsset(id, asset)
end

for id, asset in pairs(srcassets.animatedchars) do
	doSrcAsset(id, asset)
end

printf("Duplicates:")
printf("-----------------------")
for tile, group in pairs(srcTileToDupGroup) do
	printf(table.concat(group, "\n"))
	printf("-----------------------")
end

-----------------------------------

printf("Reading destination images")
local srcPosToDstPos = {}
local dstTileToPos = {}
local dstTileToDupGroup = {}

local dstassets = json.parse(fs.readFileSync(dstdir .. pathsep .. "assets.json"))

local function doDstAsset(id, asset)
	local emptytile = string.rep("\0", asset.w * asset.h * 4)
	
	readSprites(dstdir .. pathsep .. "sheets" .. pathsep .. asset.file, asset.w, asset.h, function(i, tile)
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
			else
				-- duplicate tile
				dstdup()
				local group = dstTileToDupGroup[tile]
				if group == nil then
					group = {}
					dstTileToDupGroup[tile] = group
					table.insert(group, dstTileToPos[tile])
				end
				table.insert(group, atom)
			end
			
			if match then
				-- common with src
				dstcommon()
				
				if atom ~= match and srcPosToTile[atom] ~= tile then
					-- tile in common with src found at a different position
					-- and the tile in the same spot in src as in dst aren't the same tile
					-- printf("Moved:" .. match .. " -> " .. atom)
					dstmoved()
					srcPosToDstPos[match] = atom
				end
				
			else
				-- only in dst, not in src
				dstadded()
				printf("New tile: " .. atom)
			end
		end
	end)
end

for id, asset in pairs(dstassets.images) do
	doDstAsset(id, asset)
end

for id, asset in pairs(dstassets.animatedchars) do
	doDstAsset(id, asset)
end

printf("Duplicates:")
printf("-----------------------")
for tile, group in pairs(dstTileToDupGroup) do
	printf(table.concat(group, "\n"))
	printf("-----------------------")
end

-- count tiles that are only in src, not in dst
for k, v in pairs(srcTileToPos) do
	if not dstTileToPos[k] then
		dstremoved()
		printf("Missing tile: " .. v)
	end
end

-----------------------------------

printf("Stats")

-- print stats
for _,v in ipairs(statlist) do printf(v .. string.rep(" ", 11 - #v) .. stats[v]) end

-----------------------------------

printf("Updating data")

local rope, cursor

local function replace(xml, a, b, str)
	table.insert(xml, xml:cut(xml.replacePos or 1, a))
	table.insert(xml, str)
	xml.replacePos = b
end

local function replaceFinish(xml)
	table.insert(xml, xml:cutEnd(xml.replacePos))
end

local function Texture(xml)
	local pos = xml.pos
	xml:skipAttr()
	-- <Texture><File>file</File><Index>0</Index></Texture>
	local fa, fb, ia, ib
	for name in xml:forTag() do
		xml:skipAttr()
		if name == "File" then
			fa, fb, opening = xml:getInnerPos()
			assert(opening)
		elseif name == "Index" then
			ia, ib, opening = xml:getInnerPos()
			assert(opening)
		else
			error("Unexpected tag in a Texture")
		end
	end
	local srcatom = makePos(xml:cut(fa, fb), tonumber(xml:cut(ia, ib)))
	local dstatom = srcPosToDstPos[srcatom]
	if dstatom then
		printf("Moving %s to %s at %s", srcatom, dstatom, xml:traceback(pos))
		local dstfile, dstindex = dstatom:match("^([^:]*):(.*)$")
		-- if the file is not an animated character, convert index to hex
		if dstassets.images[dstfile] then
			dstindex = string.format("0x%x", tonumber(dstindex))
		end
		if fa < ia then
			replace(xml, fa, fb, dstfile)
			replace(xml, ia, ib, dstindex)
		else
			replace(xml, ia, ib, dstindex)
			replace(xml, fa, fb, dstfile)
		end
	end
end

local AnimatedTexture = Texture

local TextureOrAnimatedTexture = {
	Texture = Texture,
	AnimatedTexture = AnimatedTexture,
	-- RemoteTexture,
}

local RandomTexture = {
	Texture = Texture,
}

local TextureOrRandomTexture = {
	Texture = Texture,
	RandomTexture = RandomTexture,
}

local Root = {
	Objects = {Object = {
		Texture = Texture,
		AnimatedTexture = AnimatedTexture,
		RandomTexture = TextureOrAnimatedTexture,
		AltTexture = TextureOrAnimatedTexture,
		Portrait = TextureOrAnimatedTexture,
		Animation = {
			Frame = TextureOrRandomTexture,
		},
		-- RemoteTexture,
		Mask = Texture, -- dyes and textiles are masked; Tex1, Tex2 set the dye or cloth
		-- wall textures
		Top = TextureOrRandomTexture,
		TTexture = Texture,
		LineTexture = Texture,
		CrossTexture = Texture,
		LTexture = Texture,
		DotTexture = Texture,
		ShortLineTexture = Texture,
	}},
	GroundTypes = {Ground = {
		Texture = Texture,
		RandomTexture = RandomTexture,
		-- top of the tile as seen on OT tiles or onsen steam
		Top = TextureOrRandomTexture,
		-- carpet edges
		Edge = TextureOrRandomTexture,
		InnerCorner = TextureOrRandomTexture,
		Corner = TextureOrRandomTexture,
	}},
}

-- ensure xml output directory exists
if not fs.existsSync(dstdir .. pathsep .. "xml") then
	fs.mkdirSync(dstdir .. pathsep .. "xml")
end

common.forEachXml(srcdir .. pathsep .. "xml", function(xml)
	xml:doRoots(Root)
	if #xml > 0 then
		printf("Writing " .. xml.name)
		replaceFinish(xml)
		fs.writeFileSync(dstdir .. pathsep .. "xml" .. pathsep .. xml.name, table.concat(xml))
	end
end)
