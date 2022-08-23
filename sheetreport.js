// const assets = srcjsontext;
// const indexes = stringifyIndexes(indexes);
// const fileToSheets = json.stringify(fileToSheets);
// const dupGroups = json.stringify(dupGroups);
// const scale = scale;
const info = document.getElementById("info");

// set up event listeners
document.onmousemove = e => onMouseMove(e);
document.onmousedown = e => onMouseDown(e);
document.onscroll = e => onScroll(e);
document.onkeydown = e => onKeyDown(e);
window.onhashchange = e => onHashChange(e);

// set up duplicate detection
const mapAtomToDupGroup = new Map();
dupGroups.forEach(group => group.forEach(atom => mapAtomToDupGroup.set(atom, group)));

// set up highlight square
const highlightElem = document.createElement("div");
highlightElem.className = "highlight";

// whether to pause onMouseMove
var focused = false;
// what the location's hash was just set to
var newHash;
// last mouse movement event, used for replaying mouse move events
var lastMouseEvent;

// use location hash
goToURL(location);

// ---------------------------------------------------------

function onMouseMove(e) {
	lastMouseEvent = e;
	if (focused)
		return;
	
	if (e.target.tagName === "IMG")
		return withPosition(e.target, e.clientX, e.clientY, describe);
	else
		return show("");
}

function onMouseDown(e) {
	if (e.target.tagName === "IMG") {
		return withPosition(e.target, e.clientX, e.clientY, clickImage);
	} else if (!info.contains(e.target)) {
		return unfocus();
	}
}

function onScroll(e) {
	return onMouseMove(lastMouseEvent);
}

function onKeyDown(e) {
	// 27: Escape
	if (e.keyCode == 27 && !e.ctrlKey && !e.shiftKey && !e.altKey) {
		return unfocus();
	}
}

// ---------------------------------------------------------

// print html in the bottom right corner
function show(str) {
	info.innerHTML = str;
}

function unfocus() {
	focused = false;
	highlightElem.remove();
	return onMouseMove(lastMouseEvent);
}

function onHashChange(e) {
	return goToURL(new URL(e.newURL));
}

function goToURL(url) {
	// if the hash was set by a script, do nothing more
	if (newHash === url.hash) return;
	newHash = url.hash;
	const match = newHash.match(/#([^:]+):(.+)/);
	if (!match) return;
	// index: index of sprite on sheet
	const index = Number(match[2]);
	if (!index) return;
	// sheet: sheet name
	const sheet = match[1];
	return goToSprite(sheet, index);
}

// get position on sheet, sheet size and filename from element and mouse position
// element: img element in the DOM
// c: pixel position on client area
function withPosition(element, cx, cy, callback) {
	const rect = element.getBoundingClientRect();
	// i: pixel position on element
	const ix = cx - rect.x;
	const iy = cy - rect.y;
	// bounds check, just in case
	if (ix < 0 || ix >= rect.width || iy < 0 || iy >= rect.height)
		return show("");
	// p: pixel position on sheet
	const px = Math.floor(ix / scale);
	const py = Math.floor(iy / scale);
	// s: sheet size
	const sw = Math.floor(rect.width / scale);
	const sh = Math.floor(rect.height / scale);
	// image filename, for lack of a better place to get it
	const file = element.attributes.id.value;
	return callback(px, py, sw, sh, file, element);
}

// p: pixel position on sheet
// s: sheet size
// file: image filename
// element: img element in the DOM
function describe(px, py, sw, sh, file, element) {
	// show usages in xmls, duplicates and position of sprite under mouse in all sheets associated with file
	// sheet: sheet name
	return show(fileToSheets[file].map(sheet => {
		var animated = false;
		const asset = assets.images[sheet] || (animated = true) && assets.animatedchars[sheet];
		const stride = sw / asset.w;
		// tile position
		const tx = Math.floor(px / asset.w);
		const ty = Math.floor(py / asset.h);
		// index: index of sprite on sheet
		const index = ty * stride + tx;
		// list of all objects/tiles that use this sprite
		const usages = indexes[sheet][index];
		const usagesTable = usages ? `<table>` + usages.map(x => `<tr><td>${x.id}<td>${x.xml}</tr>`).join("") + `</table>` : "";
		// list duplicates of this sprite and link to them
		const atom = `${sheet}:${animated ? index : "0x" + index.toString(16)}`;
		const duplicates = mapAtomToDupGroup.has(atom) ? "Duplicates: " + mapAtomToDupGroup.get(atom).filter(x => x !== atom).map(x => `<a href="#${x}">${x}</a>`).join(", ") : "";
		// the above two things + position of sprite
		return `${usagesTable}${duplicates}<h3>${atom}</h3>`;
	}).filter(Boolean).join("<hr>"));
}

// p: pixel position on sheet
// s: sheet size
// file: image filename
// element: img element in the DOM
function clickImage(px, py, sw, sh, file, element) {
	focused = true;
	// sheet: sheet name
	const sheet = fileToSheets[file][0];
	var animated = false;
	const asset = assets.images[sheet] || (animated = true) && assets.animatedchars[sheet];
	const stride = sw / asset.w;
	// t: tile position on sheet
	const tx = Math.floor(px / asset.w);
	const ty = Math.floor(py / asset.h);
	// index: index of sprite on sheet
	const index = ty * stride + tx;
	// set location's hash
	// does not call goToSprite()
	newHash = `#${sheet}:${animated ? index : "0x" + index.toString(16)}`;
	document.location.hash = newHash;
	highlight(element, tx, ty, asset.w, asset.h);
	return describe(px, py, sw, sh, file, element);
}

// sheet: sheet name
// index: index of sprite on sheet
function goToSprite(sheet, index) {
	focused = true;
	const asset = assets.images[sheet] || assets.animatedchars[sheet];
	const file = asset.file;
	// element: img element in the DOM
	const element = document.getElementById(file);
	const rect = element.getBoundingClientRect();
	// s: sheet size
	const sw = Math.floor(rect.width / scale);
	const sh = Math.floor(rect.height / scale);
	const stride = sw / asset.w;
	// t: tile position on sheet
	const tx = index % stride;
	const ty = Math.floor(index / stride);
	// p: pixel position on sheet
	const px = tx * asset.w;
	const py = ty * asset.h;
	// i: pixel position on element
	const iy = py * scale;
	// scroll to sprite
	window.scrollTo(0, window.scrollY + rect.top + iy - (window.innerHeight - asset.h * scale) / 2);
	highlight(element, tx, ty, asset.w, asset.h);
	return describe(px, py, sw, sh, file, element);
}

// highlight a rectangle on an image
// element: img element in the DOM
// t: tile position on sheet
// a: tile size on sheet
function highlight(element, tx, ty, aw, ah) {
	element.parentNode.appendChild(highlightElem);
	highlightElem.setAttribute("style", `width:${aw * scale}px;height:${ah * scale}px;left:${tx * aw * scale}px;top:${ty * ah * scale}px`)
}
