class_name JoystickPrefs
extends RefCounted
## Touch joystick presets: how big the base circle is and how far the hole
## accelerates for a given drag. Indices are stored in the save file.

const NAMES := ["JOY_SMALL", "JOY_NORMAL", "JOY_LARGE"]
const SIZES := [64.0, 90.0, 124.0]
## Multiplier on the drag length before it is clamped to full speed.
const GAINS := [1.2, 1.6, 2.4]
const DEFAULT := 1


static func clamp_index(i: int) -> int:
	return clampi(i, 0, NAMES.size() - 1)


static func size_for(i: int) -> float:
	return SIZES[clamp_index(i)]


static func gain_for(i: int) -> float:
	return GAINS[clamp_index(i)]


## Final move vector for a raw joystick vector (length 0..1): full speed is
## reached sooner with a higher gain.
static func apply_gain(v: Vector2, gain: float) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	return v.normalized() * clampf(v.length() * gain, 0.0, 1.0)
