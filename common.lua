local fs = require "fs"
local pathsep = require "path".sep
local unparse = require "escape".unparse
local xmls = require "xmls2"

local common = {}

-- luvit's console_write() fails when piping for some reason, just output to stdio manually
function common.print(...)
	local list = {...}
	for k, v in ipairs(list) do list[k] = prettyPrint.dump(v) end
	io.stderr:write(table.concat(list, "\t"))
	return io.stderr:write("\n")
end

function common.printf(...)
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
