--[[
sheetreport <srcdir> <outdir>

srcdir: a directory shaped like what sheetmover expects
dstdir: write the output HTML in this directory. The intent was to also copy all images there for self-contained output.

-- BUG: json.stringify, being an unwieldy library, likes to turn indexes.mountainTempleObjects8x8 into an array with some null holes in it, thereby introducing an off-by-one error.
]]

local fs = require "fs"
local json = require "json"
local xmls = require "xmls"
local common = require "./common"
local pathsep = common.pathsep
local warnf = common.warnf

local script, srcdir, outdir = unpack(args)
if srcdir == nil then warnf("No input directory specified") return end
if outdir == nil then warnf("No output specified") return end

local srcxml = srcdir .. pathsep .. "xml"
local srcsheets = srcdir .. pathsep .. "sheets"
local srcassets = srcdir .. pathsep .. "assets.json"

--------------------------------------------------------------------------------

local function get(tbl, key)
	local value = tbl[key]
	if value == nil then
		value = {}
		tbl[key] = value
	end
	return value
end

--------------------------------------------------------------------------------

-- fileobject = [{file, w, h}]
-- file -> fileobject
local fileToObject = {}
-- sheet -> file
local sheetToFile = {}
-- [fileobject]
local filelist = {}
-- file -> [sheet]
local fileToSheets = {}

-- sheet -> index -> [backreference]
local indexes = {}

--------------------------------------------------------------------------------

-- list all files in use that actually exist (aren't invisible)

local srcjsontext = fs.readFileSync(srcassets)
local srcjson = json.parse(srcjsontext)
local fileset = {}

local function xSheet(list)
	for name, sheet in pairs(list) do
		-- populate sheetToFile and try adding to fileset
		sheetToFile[name] = sheet.file
		indexes[name] = {}
		fileset[sheet.file] = true
		table.insert(get(fileToSheets, sheet.file), name)
	end
end
xSheet(srcjson.images)
xSheet(srcjson.animatedchars)

-- operate on unique files that exist
for name, _ in pairs(fileset) do
	if fs.existsSync(srcsheets .. pathsep .. name) then
		local fileobject = {file = name}
		fileToObject[name] = fileobject
		table.insert(filelist, fileobject)
	end
end

-- get actual sheet dimensions
common.getSizes(filelist, srcsheets)

-- sort filelist alphabetically
table.sort(filelist, function(a, b) return string.upper(a.file) < string.upper(b.file) end)

--------------------------------------------------------------------------------

-- populate list of files used in xmls

local function getIndex(file, index)
	return get(indexes[file], index)
end

local function Texture(xml, animated)
	xml:skipAttr()
	local file, index = common.fileindex(xml)
	index = tonumber(index)
	-- for each file:index combination, save a backreference to where in the xmls it was seen
	table.insert(getIndex(file, index), {
		type = xml.type,
		id = xml.id,
		xml = xml.name,
		pos = xml.pos,
	})
end
local root = common.makeTextureRoot(
	function(xml) return Texture(xml, false) end,
	function(xml) return Texture(xml, true) end
)
common.forEachXml(srcxml, function(xml)
	xml:doRoots(root)
end)

--------------------------------------------------------------------------------

-- ensure xml output directory exists
if not fs.existsSync(outdir) then
	fs.mkdirSync(outdir)
end

-- copy sheets
-- for _,v in ipairs(filelist) do
	-- local src = srcdir .. pathsep .. v.file
	-- local dst = outdir .. pathsep .. v.file
	-- fs.unlinkSync(dst)
	-- fs.writeFileSync(dst, fs.readFileSync(src))
-- end

--------------------------------------------------------------------------------

-- create html report
local html = {}
local scale = 4

table.insert(html, "<!DOCTYPE html>")
table.insert(html, "<html>")
table.insert(html, "<head>")

table.insert(html, "<meta charset=UTF-8>")
table.insert(html, "<title>RotMG spritesheet report</title>")
table.insert(html, "<style>" .. fs.readFileSync(script:match(".*" .. pathsep) .. "sheetreport.css") .. "</style>")

table.insert(html, "</head>")
table.insert(html, "<body>")

table.insert(html, "<h1>RotMG spritesheet report</h1>")

for _,file in ipairs(filelist) do
	table.insert(html, "<h2>" .. file.file .. "</h2>")
	for _,sheet in ipairs(fileToSheets[file.file]) do
		table.insert(html, "<h3>" .. sheet .. "</h3>")
	end
	table.insert(html, string.format("<div class=sprite><img src=\"%s\" width=%d height=%d></div>"
		, file.file
		, file.w * scale
		, file.h * scale
	))
end

table.insert(html, "<div id=info style=position:fixed;right:0;bottom:0;></div>")
table.insert(html, [[<script>
const assets = ]] .. srcjsontext .. [[;
const indexes = ]] .. json.stringify(indexes) .. [[;
const fileToSheets = ]] .. json.stringify(fileToSheets) .. [[;
const scale = ]] .. scale .. [[;
]] .. fs.readFileSync(script:match(".*" .. pathsep) .. "sheetreport.js") .. [[
</script>]])

table.insert(html, "</body>")
table.insert(html, "</html>")

fs.writeFileSync(outdir .. pathsep .. "index.html", table.concat(html, "\n"))