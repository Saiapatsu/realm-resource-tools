# realm-resource-tools

## Requirements

- **[luvit](https://luvit.io/)**: Lua + libuv, the same thing node.js is based on;
- **[xmls2](https://github.com/Saiapatsu/xmo)**: my pure Lua XML parsing library;
- **[ImageMagick](https://www.imagemagick.org/)**: used to read and write PNG files and split them up into individual tiles.

I had reported an ImageMagick bug that was messing with the output of `checkused.lua` and it was fixed soon afterward, so ensure you have a fairly recent version.

## Utilities

### `addtypes <inDirXml> [<outDirXml>]`

Add missing type attributes to object and ground xmls.

- `inDirXml`: directory containing all xml files with objects and grounds in them
- `outDirXml`: all modified xmls get written in this directory, if not into `inDirXml`

### `checkused <srcAssets>`

Reads all XMLs and spritesheets and splits them into "used" and "unused" spritesheets.

Creates two directories:
- `<srcAssets>\sheets-used`
- `<srcAssets>\sheets-unused`

### `sheetmover <srcAssets> <dstAssets>`

Fixes references to sprites in xmls after you rearrange sprites in sheets.

- `srcAssets`: a clean copy of your assets before any changes
- `dstAssets`: assets directory with rearranged sprites and possibly a modified `assets.json`

The script will fill in the `<dstAssets>\xml` directory.

There's a more in-depth explanation at the top of the script.

### `sheetreport <srcAssets>`

Generate an interactive HTML file where you can mouse over a sprite and see the Objects or Grounds that use it and any of its duplicates.

Creates `<srcAssets>\sheetreport.html`.

### `visualizeTypes <inDirXml> <outPathObjects> <outPathGrounds> [<method>]`

Create a 256x256 bitmap representing all the types used in the xmls in `inDirXml`.

- `inDirXml`: directory containing all xml files with objects and grounds in them
- `outPathObjects`: path to bitmap of object types
- `outPathGrounds`: path to bitmap of ground types
- `method`: if this argument is specified, then morton/z-curve transform type ids

### `xml2behavstub <inPathXml> <outName>`

Convert Objects in `<inPathXml>` into `BehaviorDb.<outName>.cs` C# behavior stubs.

The stubs are empty and meant to be filled in with real behaviors.

Output of an XML file with only `pD Boss Support` in it, where `<outName>` is `ParasiteDen`:
```cs
using wServer.logic.behaviors;
using wServer.logic.loot;
using wServer.logic.transitions;

namespace wServer.logic
{
    partial class BehaviorDb
    {
        private _ ParasiteDen = () => Behav()

// Projectile 0: 150 damage pD Tongue Shot
// Projectile 5: 80 damage pD Quiet Wave
// Projectile 3: 10 damage Puppet Green Wheel
// AltTexture 1
// DisplayId: Nightmare Colony
.Init("pD Boss Support", new State(
    // behaviors
)
    // , loot
)

;

    }
}
```

### `xmlexplorer <inDirXml>`

Print the hierarchy and amount of all tags in a folder full of xml files.

```
Objects 72
	Object 4827
		@type 4827
		@id 4827
		@setType 28
		@setName 28
		Class 4822
		Texture 3286
			File 3286
			Index 3286
		Description 1596
```
etc.

## Assets

An assets directory is shaped like this:
```
assets\
	xml\
		<xml files>
	sheets\
		<spritesheets>
	assets.json
```

`assets.json` is an ad-hoc conversion of `AssetLoader.as` to JSON so as to avoid having to parse as3.
It is shaped like this:
```json
{
	"images": {
		<sheet name>: {
			"file": <image file name>,
			"w": <tile width>,
			"h": <tile height>
		} ...
	},
	"animatedchars": {
		<sheet name>: {
			"file": <image file name>,
			"mask": <null|mask image file name>,
			"w": <animation width>,
			"h": <animation height>,
			"sw": <tile width>,
			"sh": <tile height>,
			"facing": <"RIGHT"|"DOWN">
		} ...
	}
}
```

Example with one of either:
```json
{
	"images": {
		"lofiChar8x8": {"file": "lofiChar.png", "w": 8, "h": 8}
	}, "animatedchars": {
		"chars8x8rBeach": {"file": "chars8x8rBeach.png", "mask": null, "w": 56, "h": 8, "sw": 8, "sh": 8, "facing": "RIGHT"}
	}
}
```

`facing` is not used by any of these utilities.
