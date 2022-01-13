local fs = require "fs"
local xmls = require "xmls"

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
local dir = rootdir .. "haizor"

-- bypasses luvit pretty-print console_write() incompetence
function _G.print(...)
	local list = {...}
	for k, v in ipairs(list) do list[k] = tostring(v) end
	io.stderr:write(table.concat(list, "\t") .. "\n")
end

-- https://stackoverflow.com/questions/4909263/how-to-efficiently-de-interleave-bits-inverse-morton
local function morton1(x)
	x = bit.band(x, 0x55555555);
	x = bit.band(bit.bor(x, bit.rshift(x, 1)), 0x33333333)
	x = bit.band(bit.bor(x, bit.rshift(x, 2)), 0x0F0F0F0F)
	x = bit.band(bit.bor(x, bit.rshift(x, 4)), 0x00FF00FF)
	x = bit.band(bit.bor(x, bit.rshift(x, 8)), 0x0000FFFF)
	return x
end

local typeid = {}
-- local types = {}
local lasttype = 0

local function HasType(parser)
	local type, id
	for attr, value in parser do
		if
			attr == "type" then type = tonumber(value) elseif
			attr == "id"   then id   = value
		end
	end
	
	-- local x = morton1(type - 1)
	-- local y = morton1(bit.rshift(type - 1, 1))
	-- local index = y * 256 + x
	index = type
	
	if typeid[index] then
		-- print(type, id)
	else
		typeid[index] = id
		-- table.insert(types, type)
		lasttype = math.max(lasttype, type)
	end
	xmls.wastecontent(parser)
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
	
	rope, cursor = {}, 1
	pcall(xmls.scan, parser, Root)
	-- concat rope, output
end

print("max", lasttype)

-- table.sort(types)

-- for _,type in ipairs(types) do
	-- io.write(type .. "\t" .. typeid[type] .. "\n")
-- end

local log2 = 0
while lasttype ~= 0 do
	log2 = log2 + 1
	lasttype = bit.rshift(lasttype, 1)
end

-- log2 = log2 + 1
-- log2 = log2 + bit.band(log2, 1)

-- local size = bit.lshift(1, log2) - 1
-- local imgsize = bit.lshift(1, log2 / 2)
local size = 256 * 256
local imgsize = 256

print("log2", log2)
print("size", size)
print("imgsize", imgsize)

local file = io.popen(table.concat({
	"magick",
	"-depth 8",
	"-size " .. imgsize .. "x" .. imgsize,
	"GRAY:-",
	"out.png",
}, " "), "wb")
file:write(string.rep("\0", size):gsub("().", function(type) return typeid[type - 1] and "\255" end))
file:close()
