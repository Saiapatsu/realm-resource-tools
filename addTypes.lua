-- addtypes <indir> [<outdir>]
-- Add missing type attributes to object and ground xmls
-- indir: directory containing all xml files with objects and grounds in them
-- outdir: all modified xmls get written in this directory, if not into indir
local xmls = require "xmls2"
local fs = require "fs" -- from luvit
local common = require "./common"
local pathsep = common.pathsep
local forEachXml = common.forEachXml
local printf = common.printf

-- Parse arguments
local script, indir, outdir = unpack(args)
assert(indir, "No directory specified")
outdir = outdir or indir

-- get next unset numeric key, set it and return it
local function getNextFreeType(types)
	local i = types.free or 0
	while types[i] do
		i = i + 1
	end
	types[i] = true
	types.free = i + 1
	return i
end

local function opInsert(xml, types, pos)
	local newtype = string.format("0x%04x", getNextFreeType(types))
	table.insert(xml.rope, xml:cut(xml.pos, pos))
	table.insert(xml.rope, string.format(' type="%s"', newtype))
	xml.pos = pos
	printf("Inserted type %s at %s", newtype, xml:traceback(pos))
end

local function opReplace(xml, types, posA, posB)
	local oldtype = xml:cut(posA, posB)
	local newtype = string.format("0x%04x", getNextFreeType(types))
	table.insert(xml.rope, xml:cut(xml.pos, posA))
	table.insert(xml.rope, newtype)
	xml.pos = posB
	printf("Replaced type %s with %s at %s", oldtype, newtype, xml:traceback(posA))
end

-- process start tag of an Object or Ground
local function doTag(xml, types)
	local type, id, ta, tb = common.typeid(xml)
	if not id then
		printf("Tag with no id at %s", xml:traceback())
	elseif type == nil then
		-- no type found, insert type here (after the attr list)
		table.insert(xml, {opInsert, types, xml.pos})
	else
		local typenum = tonumber(type)
		if typenum == nil then -- or shouldRegen()
			-- type exists, but should be regenerated, replace its value
			table.insert(xml, {opReplace, types, ta, tb})
		else
			-- type exists and is valid, mark it
			if types[typenum] then
				printf("Duplicate type %s at %s with %s", type, xml:traceback(), types[typenum])
			end
			types[typenum] = xml.path
		end
	end
	xml:skipContent()
end

-- sets of types seen on any object and ground so far
local typesObject = {[0x0000] = true}
local typesGround = {}

local tree = {
	Objects = {Object = function(xml) return doTag(xml, typesObject) end},
	GroundTypes = {Ground = function(xml) return doTag(xml, typesGround) end},
}

-- find all xmls with missing types
local files = {}
forEachXml(indir, function(xml)
	xml:doTagsRoot(tree)
	-- if the file needs to be modified, store it for the next phase
	if #xml > 0 then
		table.insert(files, xml)
	end
end)

-- todo track and print how many of each action was taken
-- how many types left as-is? how many added? how many invalid? how many regenerated?

-- amend xmls with missing types
for _, xml in pairs(files) do
	xml.pos = 1
	xml.rope = {}
	for i, action in ipairs(xml) do
		local operation = action[1]
		operation(xml, select(2, unpack(action)))
	end
	table.insert(xml.rope, xml:cutEnd(xml.pos))
	fs.writeFileSync(outdir .. pathsep .. xml.name, table.concat(xml.rope))
end
