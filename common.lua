
local common = {}

local rootdir = args[1]:sub(1, args[1]:match("()[^\\]*$") - 1)
common.rootdir = rootdir

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
		filepath,
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
		filepath,
	}, " "), "wb")
end

-- sprite location to string
function common.makePos(id, i)
	return string.format("%s:%s", id, i)
end

-- bypasses luvit pretty-print console_write() incompetence
function common.print(...)
	local list = {...}
	for k, v in ipairs(list) do list[k] = tostring(v) end
	io.stderr:write(table.concat(list, "\t") .. "\n")
end

return common
