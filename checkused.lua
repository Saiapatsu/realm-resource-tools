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

local function split(used, sheet, file, w, h, stride)
	local pathFile = dirSheets .. pathsep .. file
	if not fs.existsSync(pathFile) then
		print("Missing " .. pathFile)
		return
		
	else
		print(pathFile)
	end
	
	local fileUsed = writeSprites(dirUsed .. pathsep .. sheet .. ".png", w, h, stride)
	local fileUnused = writeSprites(dirUnused .. pathsep .. sheet .. ".png", w, h, stride)
	
	local empty = string.rep("\0", w * h * 4)
	
	readSprites(pathFile, w, h, function(index, tile)
		local atom = makePos(sheet, index)
		if used[atom] then
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

for sheet, asset in pairs(assets.images) do
	if usedSheets[sheet] then
		split(usedTextures, sheet, asset.file, asset.w, asset.h, 16)
	end
end

for sheet, asset in pairs(assets.animatedchars) do
	if usedSheets[sheet] then
		split(usedAnimatedTextures, sheet, asset.file, asset.w, asset.h, 1)
		if asset.mask then
			split(usedAnimatedTextures, sheet .. "Mask", asset.file, asset.w, asset.h, 1)
		end
	end
end
