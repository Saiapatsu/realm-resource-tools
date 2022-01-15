-- typeexplorer <dir> [<out>]
-- Save a 256x256 png representing all the types used in the xmls in dir

local fs = require "fs"
local xmls = require "xmls"

local shouldMorton = true

-- warning: naive popen()
local dir = args[2]
local out = args[3] or "out.png"
if dir == nil then io.stderr:write("No directory specified\n") return end

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

local typeid = {} -- set of types

local function HasType(parser)
	local type
	-- local id
	for attr, value in parser do
		if     attr == "type" then type = tonumber(value)
		-- elseif attr == "id"   then id   = value
		end
	end
	
	local index
	if shouldMorton then
		index = morton1(bit.rshift(type - 1, 1)) * 256 + morton1(type - 1)
	else
		index = type
	end
	
	if typeid[index] then
		-- notify of duplicate type
		-- io.stderr:write(type .. " " .. id .. "\n")
	else
		-- typeid[index] = id
		typeid[index] = true
	end
	
	xmls.wasteContent(parser)
end

local Root = {
	Objects = {
		Object = HasType,
	},
	-- GroundTypes = {
		-- Ground = HasType,
	-- },
}

for filename in fs.scandirSync(dir) do
	local parser = xmls.parser(fs.readFileSync(dir .. "\\" .. filename))
	pcall(xmls.scan, parser, Root)
end

local imgsize = 256
local size = imgsize * imgsize

local file = io.popen(table.concat({
	"magick",
	"-depth 8",
	"-size " .. imgsize .. "x" .. imgsize,
	"GRAY:-",
	out,
}, " "), "wb")
file:write(string.rep("\0", size):gsub("().", function(type) return typeid[type - 1] and "\255" end))
file:close()
