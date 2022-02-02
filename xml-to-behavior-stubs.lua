local xmls = require "xmls"

--------------------------------------------------------------------------------

local print, finally, name, path

local function prompt(text)
	io.stderr:write(text)
	return io.read()
end

if npp then
	npp.ClearConsole()
	path = npp:GetCurrentDirectory() .. [[\parasiteDenObjects.xml]]
	name = "ParasiteChambers"
	print = _G.print
	
else
	path = args[2] or prompt("Path to XML: ")
	name = args[3] or prompt("Name of the dungeon: ")
	local output = {}
	
	function print(...)
		local tbl = {}
		for _,v in ipairs({...}) do
			table.insert(tbl, tostring(v))
		end
		table.insert(output, table.concat(tbl, "\t"))
	end
	
	function finally()
		local cd = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
		local filename = "BehaviorDb." .. name .. ".cs"
		local file = io.open(cd .. filename, "w")
		if not file then
			prompt("Cannot open " .. filename)
			return
		end
		file:write(table.concat(output, "\n") .. "\n")
		file:close()
		prompt("Created " .. filename)
	end
end

local file = io.open(path, "rb")
if not file then
	prompt("File does not exist")
	return
end
local data = file:read("*a")
file:close()

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
	
	assert(id and objectId and damage)
	return "// Proj " .. id .. ": " .. damage .. " damage " .. objectId
end

local function Object(parser)
	local id
	local displayId
	local projectiles = {}
	local shouldOutput = false
	local group
	
	-- attributes
	for key, value in parser do
		-- print(key, value)
		if key == "id" then
			id = value
		end
	end
	assert(id, "what")
	
	-- tags
	for tag in xmls.tags, parser do
		if tag == "Class" then
			local class = xmls.texttag(parser, tag)
			-- if class is not character, then waste the rest of this and return
			if class == "Character"
			or class == "GameObject"
			then
				shouldOutput = true
			end
		elseif tag == "DisplayId" then
			displayId = xmls.texttag(parser, tag) -- todo: get text value...
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
	local output = {""}
	if displayId then table.insert(output, "// " .. displayId) end
	if group then table.insert(output, "// Group: " .. group) end
	for _,v in ipairs(projectiles) do table.insert(output, v) end
	table.insert(output, string.format([[.Init("%s", new State(
    // behaviors
)
    // , loot
)]], id))
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
        private _ ]] .. name .. [[ = () => Behav()]])

local parser = xmls.parser(data)
xmls.scan(parser, {Objects = {Object = Object}})

print([[

;

    }
}]])

if finally then finally() end
