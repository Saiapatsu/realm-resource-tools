local fs = require "fs"
local json = require "json"
local xmls = require "xmls"

local DEPTH = 4

-- warning: naive popen()

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local dir  = rootdir .. "src\\"

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
		"-crop", w .. "x" .. h,
		-- some sheets (e.g. the willem drawings) are ill-fitting, enlarge sprites
		"-extent", w .. "x" .. h,
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

-- return a file handle to write to
local function writeSprites(filepath, w, h, ww)
	return io.popen(table.concat({
		"magick montage",
		"-depth 8",
		"-size", w .. "x" .. h,
		"-tile", ww .. "x",
		"-geometry +0+0",
		"-border 0x0",
		"-background #00000000",
		"RGBA:-",
		filepath,
	}, " "), "wb")
end

-- sprite location to string
local function makePos(id, i)
	return string.format("%s:%s", id, i)
end

-----------------------------------

print("Reading data")

local usedTextures = {}
local usedAnimatedTextures = {}

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
	local empty = string.rep("\0", asset.w * asset.h * DEPTH)
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
end

for id, asset in pairs(assets.animatedchars) do
	local empty = string.rep("\0", asset.w * asset.h * DEPTH)
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
end
