const info = document.getElementById("info");
document.onmousemove = e => onMouseMove(e);
document.onmousedown = e => onMouseDown(e);
window.onhashchange = e => onHashChange(e);
goToURL(location);

// set up duplicate detection
const mapAtomToDupGroup = new Map();
dupGroups.forEach(group => group.forEach(atom => mapAtomToDupGroup.set(atom, group)));

// whether to pause onMouseMove
var focused = false;
// what the location's hash was just set to
var newHash;

// print html in the bottom right corner
function show(str) {
	info.innerHTML = str;
}

function onMouseMove(e) {
	if (focused)
		return;
	
	if (e.target.tagName === "IMG")
		return withPosition(e, describe);
	else
		return show("");
}

function onMouseDown(e) {
	console.log(e);
	if (e.target.tagName === "IMG") {
		focused = true;
		return withPosition(e, clickImage);
	} else if (!info.contains(e.target)) {
		focused = false;
		return show("");
	}
}

function onHashChange(e) {
	return goToURL(new URL(e.newURL));
}

function goToURL(url) {
	if (newHash === url.hash) return;
	newHash = url.hash;
	const match = newHash.match(/#([^:]+):(.+)/);
	if (!match) return;
	const index = Number(match[2]);
	if (!index) return;
	const sheet = match[1];
	return goToSprite(sheet, index);
}

// figure out the position on sheet, sheet size and filename of a mouse event
function withPosition(e, callback) {
	const rect = e.target.getBoundingClientRect();
	// mouse position on image
	const mx = e.clientX - rect.x;
	const my = e.clientY - rect.y;
	// bounds check, just in case
	if (mx < 0 || mx >= rect.width || my < 0 || my >= rect.height)
		return show("");
	// pixel position
	const px = Math.floor(mx / scale);
	const py = Math.floor(my / scale);
	// image size
	const sw = Math.floor(rect.width / scale);
	const sh = Math.floor(rect.height / scale);
	// image name, for lack of a better place to get it
	const file = e.target.attributes.src.value;
	// const sheet = fileToSheets[file][0];
	return callback(px, py, sw, sh, file);
}

function describe(px, py, sw, sh, file) {
	const info = fileToSheets[file].map(sheet => {
		var animated = false;
		const asset = assets.images[sheet] || (animated = true) && assets.animatedchars[sheet];
		const stride = sw / asset.w;
		// tile position
		const tx = Math.floor(px / asset.w);
		const ty = Math.floor(py / asset.h);
		const index = ty * stride + tx;
		// the real stuff
		const usages = indexes[sheet][index];
		const usagesTable = usages ? `<table>` + usages.map(x => `<tr><td>${x.id}<td>${x.xml}</tr>`).join("") + `</table>` : "";
		const atom = `${sheet}:${animated ? index : "0x" + index.toString(16)}`;
		const duplicates = mapAtomToDupGroup.has(atom) ? "Duplicates: " + mapAtomToDupGroup.get(atom).map(x => `<a href="#${x}">${x}</a>`).join(", ") : "";
		return `${usagesTable}${duplicates}<h3>${atom}</h3>`;
	}).filter(Boolean);
	if (!info.length)
		return ""; // no longer possible
	return show(info.join("<hr>"));
}

function clickImage(px, py, sw, sh, file) {
	const sheet = fileToSheets[file][0];
	var animated = false;
	const asset = assets.images[sheet] || (animated = true) && assets.animatedchars[sheet];
	const element = document.getElementById(file);
	const rect = element.getBoundingClientRect();
	const stride = sw / asset.w;
	// tile position
	const tx = Math.floor(px / asset.w);
	const ty = Math.floor(py / asset.h);
	const index = ty * stride + tx;
	// set location's hash
	newHash = `#${sheet}:${animated ? index : "0x" + index.toString(16)}`;
	document.location.hash = newHash;
	return describe(px, py, sw, sh, file);
}

function goToSprite(sheet, index) {
	const asset = assets.images[sheet] || assets.animatedchars[sheet];
	const file = asset.file;
	const element = document.getElementById(file);
	const rect = element.getBoundingClientRect();
	// tile position on the sheet
	const stride = Math.floor(rect.width / (scale * asset.w));
	const tx = index % stride;
	const ty = Math.floor(index / stride);
	// position in pixels on the element
	const my = ty * asset.h * scale;
	// scroll to sprite
	window.scrollTo(0, window.scrollY + rect.top + my);
	// todo: highlight sprite
}
