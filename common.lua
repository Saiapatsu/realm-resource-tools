local fs = require "fs"
local pathsep = require "path".sep
local unparse = require "escape".unparse
local xmls = require "xmls2"

local common = {}

common.pathsep = pathsep

function common.makeTextureRoot(Texture, AnimatedTexture, RemoteTexture)
	-- todo: make these follow the actual logic used in the client
	-- (i.e. TextureDataConcrete)
	
	local TextureOrAnimatedTexture = {
		Texture = Texture,
		RemoteTexture = RemoteTexture,
		AnimatedTexture = AnimatedTexture,
	}
	
	local RandomTexture = {
		Texture = Texture,
		RemoteTexture = RemoteTexture,
	}
	
	local TextureOrRandomTexture = {
		Texture = Texture,
		RemoteTexture = RemoteTexture,
		RandomTexture = RandomTexture,
	}
	
	local Object = {
		Texture = Texture,
		RemoteTexture = RemoteTexture,
		AnimatedTexture = AnimatedTexture,
		RandomTexture = TextureOrAnimatedTexture,
		AltTexture = TextureOrAnimatedTexture,
		Portrait = TextureOrAnimatedTexture,
		Animation = {
			Frame = TextureOrRandomTexture,
		},
		Mask = Texture, -- dyes and textiles are masked; Tex1, Tex2 set the dye or cloth
		-- wall textures
		Top = TextureOrRandomTexture,
		TTexture = Texture,
		LineTexture = Texture,
		CrossTexture = Texture,
		LTexture = Texture,
		DotTexture = Texture,
		ShortLineTexture = Texture,
	}
	
	local Ground = {
		Texture = Texture,
		RandomTexture = RandomTexture,
		RemoteTexture = RemoteTexture,
		-- top of the tile as seen on OT tiles or onsen steam
		Top = TextureOrRandomTexture,
		-- carpet edges
		Edge = TextureOrRandomTexture,
		InnerCorner = TextureOrRandomTexture,
		Corner = TextureOrRandomTexture,
	}
	
	local function infoInjector(tags)
		return function(xml)
			xml.basePos = xml.pos
			xml.type, xml.id = common.typeid(xml)
			xml.typenum = tonumber(xml.typenum)
			return xml:doTags(tags)
		end
	end
	
	return {
		Objects = {Object = infoInjector(Object)},
		GroundTypes = {Ground = infoInjector(Ground)},
	}
end

-- Use at TagEnd of <Texture> or <AnimatedTexture>
-- Transition to Text
function common.fileindex(xml)
	local fa, fb, ia, ib
	for name in xml:forTag() do
		xml:skipAttr()
		if name == "File" then
			fa, fb, opening = xml:getContentPos()
			assert(opening)
		elseif name == "Index" then
			ia, ib, opening = xml:getContentPos()
			assert(opening)
		else
			xml:skipContent()
		end
	end
	return fa and xml:cut(fa, fb), ia and xml:cut(ia, ib), fa, fb, ia, ib
end

-- Use at Attr of <Object>
-- Transition to TagEnd
function common.typeid(xml)
	local ta, tb, ia, ib
	for k in xml:forKey() do
		local va, vb = xml:getValuePos()
		if     k == "type" then ta, tb = va, vb
		elseif k == "id"   then ia, ib = va, vb
		end
	end
	return ta and xml:cut(ta, tb), ia and xml:cut(ia, ib), ta, tb, ia, ib
end

-- luvit's console_write() fails when piping for some reason, just output to stdio manually
function common.print(...)
	local list = {...}
	for k, v in ipairs(list) do list[k] = prettyPrint.dump(v) end
	io.stdout:write(table.concat(list, "\t"))
	return io.stdout:write("\n")
end
function common.printf(...)
	io.stdout:write(string.format(...))
	return io.stdout:write("\n")
end
function common.warn(...)
	local list = {...}
	for k, v in ipairs(list) do list[k] = prettyPrint.dump(v) end
	io.stderr:write(table.concat(list, "\t"))
	return io.stderr:write("\n")
end
function common.warnf(...)
	io.stderr:write(string.format(...))
	return io.stderr:write("\n")
end

-- iterator that returns size bytes of a file each time
function common.chunker(file, size)
	return function(file, index)
		local data = file:read(size)
		if data then
			return index + 1, data
		end
	end, file, -1
end

-- perform a callback for each wxh square in an image
function common.readSprites(filepath, w, h, callback)
	-- size of each sprite in bytes
	local size = w * h * 4
	-- split image into sprites
	local file = io.popen(table.concat({
		"magick",
		unparse(filepath),
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
	for index, tile in common.chunker(file, size) do
		callback(index, tile)
	end
	file:close()
end

-- add w, h to an array of tables {file = string}
function common.getSizes(files, dir)
	local rope = {}
	for _,v in ipairs(files) do
		table.insert(rope, unparse(dir .. pathsep .. v.file))
	end
	local file = io.popen(table.concat({
		"magick",
		"-format \"%w %h \"",
		table.concat(rope, " "),
		"-write info:-",
		"null:",
	}, " "), "rb")
	local str = file:read("*a")
	file:close()
	local i = 1
	for w, h in str:gmatch("(%d+) (%d+) ") do
		files[i].w = tonumber(w)
		files[i].h = tonumber(h)
		i = i + 1
	end
end

-- return a file handle to write to
function common.writeSprites(filepath, w, h, ww)
	return io.popen(table.concat({
		"magick montage",
		"-depth 8",
		"-size", w .. "x" .. h,
		"-tile", ww .. "x",
		"-geometry +0+0",
		"-border 0x0",
		"-background #00000000",
		"RGBA:-",
		unparse(filepath),
	}, " "), "wb")
end

-- Attempt to operate on each XML file in a directory
function common.forEachXml(dir, callback)
	for name in fs.scandirSync(dir) do
		local path = dir .. pathsep .. name
		local xml = xmls.new(fs.readFileSync(path))
		xml.dir = dir
		xml.name = name
		xml.path = path
		local success, message = pcall(callback, xml)
		if not success then
			common.printf("error %s %s", xml:traceback(), message)
		end
	end
end

-- sprite location to string
function common.makePos(id, i)
	return string.format("%s:%s", id, i)
end

return common
