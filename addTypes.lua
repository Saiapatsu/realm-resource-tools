-- addtypes <indir> [<outdir>]
-- Add missing type attributes to object and ground xmls
-- indir: directory containing all xml files with objects and grounds in them
-- outdir: all modified xmls get written in this directory, if not into indir

-- warning: not portable, given that pathsep is hardcoded for Windows here

local xmls = require "xmls2"
local fs = require "fs" -- from luvit
local pathsep = "\\"

-- Parse arguments
local script, indir, outdir = unpack(args)
assert(indir, "No directory specified")
outdir = outdir or indir

-- array of objects corresponding to files that need to be modified
local files = {}
-- sets of types seen on any object and ground so far
local typesObject = {[0x0000] = true}
local typesGround = {}

-- recursive directory traversal, I have no clue why I implemented this
-- outdir does not account for it
local traverse
function traverse(dir, callback)
	for name, type in fs.scandirSync(dir) do
		local path = dir .. pathsep .. name
		if type == "directory" then
			traverse(path, callback)
		elseif type == "file" then
			callback(path, dir, name)
		end
	end
end

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

-- process start tag of an Object or Ground
local function doTag(xml, types)
	local type, id
	for k,v in xml:attrs() do
		if     k == "type" then type = v
		elseif k == "id"   then id = v end
	end
	if not id then
		print("Tag with no id", xml.name, xml.pos)
	elseif not type then
		-- record the position to add a type to and which table to fill from
		table.insert(xml.missingPos, xml.pos)
		table.insert(xml.missingSet, types)
	else
		-- type exists, mark it
		local typenum = tonumber(type)
		if types[typenum] then
			print("Tag with duplicate id", xml.name, types[typenum], type)
		end
		types[typenum] = xml.name
	end
	xml:skipContent()
end

local tree = {
	Objects = {Object = function(xml) return doTag(xml, typesObject) end},
	GroundTypes = {Ground = function(xml) return doTag(xml, typesGround) end},
}

-- find all xmls with missing types
traverse(indir, function(path, dir, name)
	local data = fs.readFileSync(path)
	local xml = xmls.new(data)
	xml.path = path
	xml.dir = dir
	xml.name = name
	-- positions of attribute lists that don't have a type
	xml.missingPos = {}
	-- set to fill in missing attributes from
	xml.missingSet = {}
	local success, message = pcall(xml.doRoots, xml, tree)
	if not success then print(path, message) end
	if #xml.missingPos > 0 then table.insert(files, xml) end
end)

-- amend all xmls with missing types
for _, xml in pairs(files) do
	local str = xml.str
	local pos = 1
	local rope = {}
	for i, errpos in ipairs(xml.missingPos) do
		local types = xml.missingSet[i]
		table.insert(rope, str:sub(pos, errpos - 1))
		table.insert(rope, string.format(' type="0x%04x"', getNextFreeType(types)))
		pos = errpos
	end
	table.insert(rope, str:sub(pos))
	-- print(table.concat(rope))
	fs.writeFileSync(outdir .. pathsep .. xml.name, table.concat(rope))
end
