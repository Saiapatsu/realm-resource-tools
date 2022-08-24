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

local pathsep = common.pathsep

local srcxml = dir .. pathsep .. "xml"
local pathJson = dir .. pathsep .. "assets.json"
local dirUsed = dir .. pathsep .. "sheets-used"
local dirUnused = dir .. pathsep .. "sheets-unused"
local dirSheets = dir .. pathsep .. "sheets"

local function get(tbl, key)
	local value = tbl[key]
	if value == nil then
		value = {}
		tbl[key] = value
	end
	return value
end

-----------------------------------

print("Reading data")

local usedTextures = {}
local usedAnimatedTextures = {}
local usedSheets = {}

function Texture(xml, name)
	xml:skipAttr()
	local sheet, index = common.fileindex(xml)
	index = tonumber(index)
	local bin = name == "Texture" and usedTextures or usedAnimatedTextures
	get(bin, sheet)[index] = true
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

local function split(used, sheet, file, w, h, stride, mask)
	local pathFile = dirSheets .. pathsep .. file
	if not fs.existsSync(pathFile) then
		print("Missing " .. pathFile)
		return
		
	else
		print(pathFile)
	end
	
	local countUsed   = 0
	local countUnused = 0
	local ropeUsed   = {}
	local ropeUnused = {}
	
	local empty = string.rep("\0", w * h * 4)
	
	common.readSprites(pathFile, w, h, function(index, tile)
		if tile == empty then
			table.insert(ropeUsed  , empty)
			table.insert(ropeUnused, empty)
		elseif get(used, sheet)[index] then
			countUsed = countUsed + 1
			table.insert(ropeUsed  , tile)
			table.insert(ropeUnused, empty)
		else
			countUnused = countUnused + 1
			table.insert(ropeUsed  , empty)
			table.insert(ropeUnused, tile)
		end
	end)
	
	if mask then
		sheet = sheet .. "Mask"
	end
	
	if countUsed ~= 0 then
		common.writeSpritesSync(dirUsed   .. pathsep .. sheet .. ".png", w, h, stride, table.concat(ropeUsed  ))
	end
	if countUnused ~= 0 then
		common.writeSpritesSync(dirUnused .. pathsep .. sheet .. ".png", w, h, stride, table.concat(ropeUnused))
	end
end

for sheet, asset in pairs(assets.images) do
	if usedSheets[sheet] then
		split(usedTextures, sheet, asset.file, asset.w, asset.h, 16, false)
	end
end

for sheet, asset in pairs(assets.animatedchars) do
	if usedSheets[sheet] then
		split(usedAnimatedTextures, sheet, asset.file, asset.w, asset.h, 1, false)
		if asset.mask then
			split(usedAnimatedTextures, sheet, asset.mask, asset.w, asset.h, 1, true)
		end
	end
end
