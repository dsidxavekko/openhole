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


class LowFpsMonitor extends RefCounted:
	const FPS_LIMIT := 24.0
	const WINDOW_SECONDS := 2.0
	const SLOW_WINDOWS := 3

	var _seconds := 0.0
	var _frames := 0
	var _slow_windows := 0
	var _reported := false

	func add_frame(delta: float) -> bool:
		if _reported or delta <= 0.0:
			return false
		_seconds += delta
		_frames += 1
		if _seconds < WINDOW_SECONDS:
			return false
		var fps := _frames / _seconds
		_seconds = 0.0
		_frames = 0
		_slow_windows = _slow_windows + 1 if fps < FPS_LIMIT else 0
		if _slow_windows < SLOW_WINDOWS:
			return false
		_reported = true
		return true
