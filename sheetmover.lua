local fs = require "fs"
local json = require "json"
local xmls = require "xmls"

-- warning: naive popen()

-- Get all sprites in src, associate with their positions
-- Get all sprites in dst, associate src positions with dst positions
-- Modify data, change references to src positions to dst positions

-- todo: output used/unused sprites

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local srcdir  = rootdir .. "src\\"
local dstdir  = rootdir .. "dst\\"

function chunker(file, size)
	return function(file, index)
		local data = file:read(size)
		if data then
			return index + 1, data
		end
	end, file, -1
end

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
	}, " "))
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

-----------------------------------

-- value, location
local function tags(parser)
	while true do
		local type, value, location = parser()
		if type == nil or type == "tag" then
			return value, location
		end
	end
end

-- key, value, location
local function kvtags(parser)
	while true do
		local type, value, location = parser()
		if type == nil then
			return type, value, location
		elseif type == "tag" then
			local type2, value2 = parser()
			assert(type2 == "text")
			assert(parser() == nil)
			return value, value2, location
		end
	end
end

local function Object(parser)
	return xmls.waste(parser)
end

local function Objects(parser)
	for type, value in parser do
		if type ~= "tag" then goto continue end
		if value ~= "Object" then
			print("Object waste", type, value)
			xmls.waste(parser)
			goto continue
		end
		Object(parser)
		::continue::
	end
end

local function GroundTypes(parser)
	return xmls.waste(parser)
end

for filename in fs.scandirSync(srcdir .. "data") do
	local parser = xmls.parser(fs.readFileSync(srcdir .. "data\\" .. filename))
	for tag in tags, parser do
		if
			tag == "Objects"     then Objects(parser) elseif
			tag == "Object"      then Object(parser) elseif
			tag == "GroundTypes" then GroundTypes(parser)
		else
			print("Root waste", tag)
			xmls.waste(parser)
		end
	end
end

do return end

local srcamount = 0
local srcnull = 0
local srcuniq = 0
local src = {}
local srcdups = {}
for id, asset in pairs(json.parse(fs.readFileSync(srcdir .. "assets\\assets.json"))) do
	-- print(id)
	readSprites(srcdir .. asset.file, asset.w, asset.h, function(i, tile)
		-- [data] = "lofiObj4:0"
		-- print(tile)
		if tile:match("[^%z]") then
			srcamount = srcamount + 1
			if not src[tile] then
				srcuniq = srcuniq + 1
				src[tile] = string.format("%s:%s", id, i)
			elseif not srcdups[tile] then
				srcdups[tile] = true
				print(string.format("Duplicate: %s, %s:%s", src[tile], id, i))
			end
		else
			srcnull = srcnull + 1
		end
	end)
end

local dstcommon = 0
local dstnull = 0
local dst = {}
for id, asset in pairs(json.parse(fs.readFileSync(dstdir .. "assets\\assets.json"))) do
	-- print(id)
	readSprites(dstdir .. asset.file, asset.w, asset.h, function(i, tile)
		-- ["lofiObj4:0"] = "lofiObj4:20"
		if tile:match("[^%z]") then
			local match = src[tile]
			if match then
				dst[match] = string.format("%s:%s", id, i)
				dstcommon = dstcommon + 1
			end
		else
			dstnull = dstnull + 1
		end
	end)
end

print("srcamount: " .. srcamount)
print("dstcommon: " .. dstcommon)
print("srcnull: " .. srcnull)
print("dstnull: " .. dstnull)
print("srcdup: " .. srcamount - srcuniq)
