local cd = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)

local xmls = require(cd .. "xmls.lua")

--------------------------------------------------------------------------------

local function prompt(text)
	io.stderr:write(text)
	return io.read()
end

local path = args[2] or prompt("Path to XML: ")
local name = args[3] or prompt("Name of the dungeon: ")

local infile = io.open(path, "rb")
if not infile then
	prompt("File does not exist")
	return
end
local data = infile:read("*a")
infile:close()

--------------------------------------------------------------------------------

local filename = "BehaviorDb." .. name .. ".cs"
local outfile = io.open(cd .. filename, "w")
if not outfile then
	prompt("Cannot open " .. filename)
	return
end

local function print(...)
	local tbl = {}
	for _,v in ipairs({...}) do
		table.insert(tbl, tostring(v))
	end
	outfile:write(table.concat(tbl, "\t") .. "\n")
end

--------------------------------------------------------------------------------

local function Projectile(parser)
	local id
	local objectId
	local damage
	
	-- attributes
	for key, value in parser do
		if key == "id" then
			id = value
		end
	end
	
	-- tags
	for tag in xmls.tags, parser do
		if tag == "ObjectId" then
			objectId = xmls.texttag(parser, tag)
		elseif tag == "Damage" then
			damage = xmls.texttag(parser, tag)
		else
			xmls.waste(parser)
		end
	end
	
	return "// Proj " .. id .. ": " .. damage .. " damage " .. objectId
end

local function Object(parser)
	local id
	local displayId
	local group
	local projectiles = {}
	local shouldOutput = false
	
	-- attributes
	for key, value in parser do
		if key == "id" then
			id = value
		end
	end
	
	-- tags
	for tag in xmls.tags, parser do
		if tag == "Class" then
			local class = xmls.texttag(parser, tag)
			if class == "Character"
			or class == "GameObject"
			then
				shouldOutput = true
			end
		elseif tag == "DisplayId" then
			displayId = xmls.texttag(parser, tag)
		elseif tag == "Projectile" then
			table.insert(projectiles, Projectile(parser))
		elseif tag == "Group" then
			group = xmls.texttag(parser, tag)
		else
			xmls.waste(parser)
		end
	end
	
	if shouldOutput == false then return end
	
	-- output
	local output = {}
	if displayId then table.insert(output, "// DisplayId: " .. displayId) end
	if group then table.insert(output, "// Group: " .. group) end
	for _,v in ipairs(projectiles) do table.insert(output, v) end
	table.insert(output, string.format([[.Init("%s", new State(
    // behaviors
)
    // , loot
)
]], id))
	print(table.concat(output, "\n"))
end

--------------------------------------------------------------------------------

print([[using wServer.logic.behaviors;
using wServer.logic.loot;
using wServer.logic.transitions;

namespace wServer.logic
{
    partial class BehaviorDb
    {
        private _ ]] .. name .. [[ = () => Behav()
]])

local parser = xmls.parser(data)
xmls.scan(parser, {Objects = {Object = Object}})

print([[
;

    }
}]])

--------------------------------------------------------------------------------

prompt("Created " .. filename)
