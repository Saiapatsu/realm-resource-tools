-- visualizeTypes <dirXml> <pathImageObjects> <pathImageGrounds> [<method>]
-- Create a 256x256 image representing all the types used in the xmls in dir
-- dirXml: directory containing all xml files with objects and grounds in them
-- pathImageObjects: path to image that will display object types
-- pathImageGrounds: path to image that will display ground types
-- method: if there is any 5th argument at all, then morton/z-curve transform type ids

local unparse = require "escape".unparse
local forEachXml = require "./common".forEachXml
local printf = require "./common".printf

-----------------------------------

-- Parse arguments
local script, xmldir, pathImageObjects, pathImageGrounds, method = unpack(args)
if xmldir == nil then print("No directory specified") return end
if pathImageObjects == nil then print("No objects image output path specified") return end
if pathImageGrounds == nil then print("No grounds image output path specified") return end

local imgsize = 256
local size = imgsize * imgsize

-----------------------------------

-- https://stackoverflow.com/questions/4909263/how-to-efficiently-de-interleave-bits-inverse-morton
local function morton1(x)
	x = bit.band(x, 0x55555555);
	x = bit.band(bit.bor(x, bit.rshift(x, 1)), 0x33333333)
	x = bit.band(bit.bor(x, bit.rshift(x, 2)), 0x0F0F0F0F)
	x = bit.band(bit.bor(x, bit.rshift(x, 4)), 0x00FF00FF)
	x = bit.band(bit.bor(x, bit.rshift(x, 8)), 0x0000FFFF)
	return x
end

local transform = method
	and function(type) return morton1(bit.rshift(type - 1, 1)) * 256 + morton1(type - 1) end
	or function(type) return type end

-- set of transformed types
local typesObject = {}
local typesGround = {}

local function doTag(xml, types, what)
	local type
	local id
	for k,v in xml:attrs() do
		if     k == "type" then type = v
		elseif k == "id"   then id   = v
		end
	end
	
	local typenum = tonumber(type)
	-- pixel index in the output image
	local index = transform(typenum)
	
	if typenum >= size then
		printf("out-of-bounds %s %s %s", what, type, id)
	end
	
	if types[index] then
		printf("duplicate %s %s %s", what, type, id)
	else
		types[index] = true
	end
	
	xml:skipContent()
end

local tree = {
	Objects = {Object = function(xml) return doTag(xml, typesObject, "object") end},
	GroundTypes = {Ground = function(xml) return doTag(xml, typesGround, "ground") end},
}

-- process all xmls
forEachXml(xmldir, function(xml) return xml:doRoots(tree) end)

function visualize(types, pathImage)
	local file = io.popen(table.concat({
		"magick",
		"-depth 8",
		"-size " .. imgsize .. "x" .. imgsize,
		"GRAY:-",
		unparse(pathImage),
	}, " "), "wb")
	file:write(string.rep("\0", size):gsub("().", function(type) return types[type - 1] and "\255" end))
	file:close()
end

visualize(typesObject, pathImageObjects)
visualize(typesGround, pathImageGrounds)
