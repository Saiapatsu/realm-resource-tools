--[[
checkused <dir>

Reads all XMLs and spritesheets and splits them into "used" and "unused" spritesheets

]]

local fs = require "fs"
local json = require "json"
local common = require "./common"

-- Parse arguments
local script, dir = unpack(args)
if dir == nil then print("No directory specified") return end

local chunker = common.chunker
local readSprites = common.readSprites
local writeSprites = common.writeSprites
local makePos = common.makePos
local pathsep = common.pathsep

local srcxml = dir .. pathsep .. "xml"
local pathJson = dir .. pathsep .. "assets.json"
local dirUsed = dir .. pathsep .. "sheets-used"
local dirUnused = dir .. pathsep .. "sheets-unused"
local dirSheets = dir .. pathsep .. "sheets"

-----------------------------------

print("Reading data")

local usedTextures = {}
local usedAnimatedTextures = {}
local usedSheets = {}

function Texture(xml, name)
	xml:skipAttr()
	local sheet, index = common.fileindex(xml)
	local atom = makePos(sheet, tonumber(index))
	local bin = name == "Texture" and usedTextures or usedAnimatedTextures
	bin[atom] = true
	usedSheets[sheet] = true
end

local root = common.makeTextureRoot(Texture, Texture)
common.forEachXml(srcxml, function(xml)
	xml:doTagsRoot(root)
end)

-----------------------------------

fs.mkdirSync(dirUsed)
fs.mkdirSync(dirUnused)

-----------------------------------

print("Processing images")

local assets = json.parse(fs.readFileSync(pathJson))

for id, asset in pairs(assets.images) do
	if not usedSheets[id] then goto continue end
	
	local pathFile = dirSheets .. pathsep .. asset.file
	if not fs.existsSync(pathFile) then goto continue end
	
	local empty = string.rep("\0", asset.w * asset.h * 4)
	local fileUsed = writeSprites(dirUsed .. pathsep .. id .. ".png", asset.w, asset.h, 16)
	local fileUnused = writeSprites(dirUnused .. pathsep .. id .. ".png", asset.w, asset.h, 16)
	
	readSprites(pathFile, asset.w, asset.h, function(i, tile)
		local atom = makePos(id, i)
		if usedTextures[atom] then
			fileUsed:write(tile)
			fileUnused:write(empty)
		else
			fileUsed:write(empty)
			fileUnused:write(tile)
		end
	end)
	
	fileUsed:close()
	fileUnused:close()
	
	::continue::
end

for id, asset in pairs(assets.animatedchars) do
	if not usedSheets[id] then goto continue end
	
	local pathFile = dirSheets .. pathsep .. asset.file
	if not fs.existsSync(pathFile) then goto continue end
	
	local empty = string.rep("\0", asset.w * asset.h * 4)
	local fileUsed = writeSprites(dirUsed .. pathsep .. id .. ".png", asset.w, asset.h, 1)
	local fileUnused = writeSprites(dirUnused .. pathsep .. id .. ".png", asset.w, asset.h, 1)
	
	readSprites(dirSheets .. pathsep .. asset.file, asset.w, asset.h, function(i, tile)
		local atom = makePos(id, i)
		if usedAnimatedTextures[atom] then
			fileUsed:write(tile)
			fileUnused:write(empty)
		else
			fileUsed:write(empty)
			fileUnused:write(tile)
		end
	end)
	
	fileUsed:close()
	fileUnused:close()
	
	if asset.mask then
		local fileUsed = writeSprites(dirUsed .. pathsep .. id .. "Mask.png", asset.w, asset.h, 1)
		local fileUnused = writeSprites(dirUnused .. pathsep .. id .. "Mask.png", asset.w, asset.h, 1)
		
		readSprites(dirSheets .. pathsep .. asset.mask, asset.w, asset.h, function(i, tile)
			local atom = makePos(id, i)
			if usedAnimatedTextures[atom] then
				fileUsed:write(tile)
				fileUnused:write(empty)
			else
				fileUsed:write(empty)
				fileUnused:write(tile)
			end
		end)
		
		fileUsed:close()
		fileUnused:close()
	end
	
	::continue::
end
