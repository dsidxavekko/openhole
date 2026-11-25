class_name GraphicsQuality
extends RefCounted
## Graphics presets for phones. Low reduces rendering work without changing physics.

enum Level { LOW, MEDIUM, HIGH }

const KEYS := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]
## soft: RenderingServer shadow filter quality (hard / low / medium).
## fps 0 leaves the frame-rate limit to VSync.
const PRESETS := [
	{"shadow": 1024, "msaa": Viewport.MSAA_DISABLED, "scale": 0.65, "soft": 0,
		"fps": 30, "shadows": false, "simple_ground": true, "fx": 0.5},
	{"shadow": 2048, "msaa": Viewport.MSAA_2X, "scale": 0.9, "soft": 1,
		"fps": 60, "shadows": true, "simple_ground": false, "fx": 0.75},
	{"shadow": 4096, "msaa": Viewport.MSAA_4X, "scale": 1.0, "soft": 2,
		"fps": 0, "shadows": true, "simple_ground": false, "fx": 1.0},
]


static func preset(level: int) -> Dictionary:
	return PRESETS[clampi(level, 0, PRESETS.size() - 1)]


static func name_key(level: int) -> String:
	return KEYS[clampi(level, 0, KEYS.size() - 1)]


static func particle_count(level: int, amount: int) -> int:
	return maxi(1, roundi(amount * float(preset(level)["fx"])))
