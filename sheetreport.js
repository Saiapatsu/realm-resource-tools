const info = document.getElementById("info");
document.body.onmousemove = e => onMouseMove(e);
// document.body.onscroll = e => onMouseMove(e);
function show(str) {
	info.innerHTML = str;
}
function onMouseMove(e) {
	const target = e.target;
	// not pointing at an image?
	if (target.tagName !== "IMG")
		return show("");
	const rect = target.getBoundingClientRect();
	// mouse position on image
	const mx = e.clientX - rect.x;
	const my = e.clientY - rect.y;
	// bounds check, just in case
	if (mx < 0 || mx >= rect.width || my < 0 || my >= rect.height)
		return show("");
	// pixel position
	const x = Math.floor(mx / scale);
	const y = Math.floor(my / scale);
	// image size
	const sw = Math.floor(rect.width / scale);
	const sh = Math.floor(rect.height / scale);
	// image name, for lack of a better place to get it
	const file = target.attributes.src.value;
	// const sheet = fileToSheets[file][0];
	const info = fileToSheets[file].map(sheet => {
		var animated = false;
		const asset = assets.images[sheet] || (animated = true) && assets.animatedchars[sheet];
		const stride = sw / asset.w;
		// tile position
		const tx = Math.floor(x / asset.w);
		const ty = Math.floor(y / asset.h);
		const index = ty * stride + tx;
		// the real stuff
		const usages = indexes[sheet][index];
		const sheetindex = `<h3>${sheet} ${animated ? index : "0x" + index.toString(16)}</h3>`;
		if (!usages)
			return sheetindex;
		return `<table>` + usages.map(x => `<tr><td>${x.id}<td>${x.xml}</tr>`).join("") + `</table>${sheetindex}`;
	}).filter(Boolean);
	if (!info.length)
		return ""; // no longer possible
	return show(info.join("<hr>"));
}
