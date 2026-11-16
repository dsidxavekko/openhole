class_name GraphicsQuality
extends RefCounted
## Coarse graphics presets for phones: shadow atlas, MSAA and 3D render scale.

enum Level { LOW, MEDIUM, HIGH }

const KEYS := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]
## soft: RenderingServer shadow filter quality (hard / low / medium).
const PRESETS := [
	{"shadow": 1024, "msaa": Viewport.MSAA_DISABLED, "scale": 0.75, "soft": 0},
	{"shadow": 2048, "msaa": Viewport.MSAA_2X, "scale": 0.9, "soft": 1},
	{"shadow": 4096, "msaa": Viewport.MSAA_4X, "scale": 1.0, "soft": 2},
]


static func preset(level: int) -> Dictionary:
	return PRESETS[clampi(level, 0, PRESETS.size() - 1)]


static func name_key(level: int) -> String:
	return KEYS[clampi(level, 0, KEYS.size() - 1)]
