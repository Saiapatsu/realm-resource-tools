local xmls = require "xmls"

local path = [[parasiteDenObjects.xml]]
local name = "ParasiteChambers"

local file = io.open(path, "rb")
local data = file:read("*a")
file:close()

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

if npp then npp.ClearConsole() end

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
