-- checkused

local fs = require "fs"
local json = require "json"
local xmls = require "xmls"
local common = require "common"

local rootdir = common.rootdir
local dir  = rootdir .. "src\\"

local chunker = common.chunker
local readSprites = common.readSprites
local writeSprites = common.writeSprites
local makePos = common.makePos

-----------------------------------

print("Reading data")

local usedTextures = {}
local usedAnimatedTextures = {}
local usedFiles = {}

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
	usedTextures[atom] = true
	usedFiles[file] = true
end

function AnimatedTexture(parser)
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
	usedAnimatedTextures[atom] = true
	usedFiles[file] = true
end

-- xmls.children{Texture = Texture, Animation = xmls.children{}}
-- xmls.descendants{Texture = Texture}
-- maybe propagate varargs??

local Root = {
	Objects = {
		Object = {
			Texture = Texture,
			AnimatedTexture = AnimatedTexture,
			Mask = Texture, -- dyes and textiles are masked
			-- Tex1, Tex2: set the corresponding textile as used
			-- RemoteTexture,
			AltTexture = {
				Texture = Texture,
				AnimatedTexture = AnimatedTexture,
				-- RemoteTexture,
			},
			RandomTexture = {
				Texture = Texture,
				AnimatedTexture = AnimatedTexture,
			},
			Top = {
				Texture = Texture,
				RandomTexture = {
					Texture = Texture,
				},
			},
			Animation = {
				Frame = {
					Texture = Texture,
					RandomTexture = {
						Texture = Texture,
					},
				},
			},
			Portrait = {
				Texture = Texture,
				AnimatedTexture = AnimatedTexture,
			},
			TTexture = Texture,
			LineTexture = Texture,
			CrossTexture = Texture,
			LTexture = Texture,
			DotTexture = Texture,
			ShortLineTexture = Texture,
		},
	},
	GroundTypes = {
		Ground = {
			Texture = Texture,
			RandomTexture = {
				Texture = Texture,
			},
			Edge = {
				Texture = Texture,
				RandomTexture = {
					Texture = Texture,
				},
			},
			InnerCorner = {
				Texture = Texture,
				RandomTexture = {
					Texture = Texture,
				},
			},
			Corner = {
				Texture = Texture,
				RandomTexture = {
					Texture = Texture,
				},
			},
			Top = {
				Texture = Texture,
				RandomTexture = {
					Texture = Texture,
				},
			},
		}
	},
}

for filename in fs.scandirSync(dir .. "data") do
	local parser = xmls.parser(fs.readFileSync(dir .. "data\\" .. filename))
	xmls.scan(parser, Root)
end

-----------------------------------

print("Processing images")

local assets = json.parse(fs.readFileSync(dir .. "assets\\assets.json"))

for id, asset in pairs(assets.images) do
	if not usedFiles[id] then goto continue end
	
	local empty = string.rep("\0", asset.w * asset.h * 4)
	local fileUsed = writeSprites(dir .. "used\\" .. id .. ".png", asset.w, asset.h, 16)
	local fileUnused = writeSprites(dir .. "unused\\" .. id .. ".png", asset.w, asset.h, 16)
	
	readSprites(dir .. "assets\\" .. asset.file, asset.w, asset.h, function(i, tile)
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
	if not usedFiles[id] then goto continue end
	
	local empty = string.rep("\0", asset.w * asset.h * 4)
	local fileUsed = writeSprites(dir .. "used\\" .. id .. ".png", asset.w, asset.h, 1)
	local fileUnused = writeSprites(dir .. "unused\\" .. id .. ".png", asset.w, asset.h, 1)
	
	readSprites(dir .. "assets\\" .. asset.file, asset.w, asset.h, function(i, tile)
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
		local fileUsed = writeSprites(dir .. "used\\" .. id .. "Mask.png", asset.w, asset.h, 1)
		local fileUnused = writeSprites(dir .. "unused\\" .. id .. "Mask.png", asset.w, asset.h, 1)
		
		readSprites(dir .. "assets\\" .. asset.mask, asset.w, asset.h, function(i, tile)
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
