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
			"w": <animation width>,
			"h": <animation height>,
			"sw": <tile width>,
			"sh": <tile height>,
			"facing": <"RIGHT"|"DOWN">,
		} ...
	}
}
For example, animatedchars.players.w is 56, h is 24, sw is 8, sh is 8 and facing is unused.

Arrange your xmls, sheets and AssetLoader in the manner specified into srcdir.
Duplicate srcdir, let it be dstdir.
Make your rearrangements in dstdir. Do not accidentally modify/recolor, duplicate, add or lose any sprites.
Run the script on the two directories.
The ultimate output of the script will be in dstdir\xml, although only the modified xmls will be written.
Replace your sheets with dstdir\sheets, your AssetLoader with dstdir\assets.json and paste dstdir\xml over your xmls.
]]

local fs = require "fs"
local json = require "json"
local xmls = require "xmls"
local common = require "./common"
local chunker = common.chunker
local readSprites = common.readSprites
local makePos = common.makePos
local printf = common.printf
local pathsep = common.pathsep

local script, srcdir, dstdir = unpack(args)
if srcdir == nil then print("No source directory specified") return end
if dstdir == nil then print("No destination directory specified") return end

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

-----------------------------------

print("Reading destination images")
local srcPosToDstPos = {}
local dstTileToPos = {}

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

for id, asset in pairs(dstassets.images) do
	doDstAsset(id, asset)
end

for id, asset in pairs(dstassets.animatedchars) do
	doDstAsset(id, asset)
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
		print("Writing " .. xml.name)
		replaceFinish(xml)
		fs.writeFileSync(dstdir .. pathsep .. "xml" .. pathsep .. xml.name, table.concat(xml))
	end
end)
