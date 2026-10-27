class_name HoleRules
extends RefCounted
## Pure game rules: levels, radius, what fits, who eats whom.

const BASE_RADIUS := 0.8
const GROWTH := 1.28
const MAX_LEVEL := 16
const FIT_FACTOR := 0.92
const EAT_HOLE_RATIO := 1.2


static func radius_for_level(level: int) -> float:
	return BASE_RADIUS * pow(GROWTH, clampi(level, 1, MAX_LEVEL) - 1)


## Total points needed to reach `level`.
static func points_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var k := radius_for_level(level) / BASE_RADIUS
	return int(round(3.0 * (k * k * k - 1.0)))


static func level_for_points(points: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and points >= points_for_level(lvl + 1):
		lvl += 1
	return lvl


## 0..1 progress towards the next level.
static func level_progress(points: int) -> float:
	var lvl := level_for_points(points)
	if lvl >= MAX_LEVEL:
		return 1.0
	var a := points_for_level(lvl)
	var b := points_for_level(lvl + 1)
	return clampf(float(points - a) / float(b - a), 0.0, 1.0)


## `extent` is the largest horizontal dimension of an object.
static func fits(extent: float, radius: float) -> bool:
	return extent < radius * 2.0 * FIT_FACTOR


static func can_eat_hole(big_r: float, small_r: float, dist: float) -> bool:
	return big_r > small_r * EAT_HOLE_RATIO and dist < big_r - small_r * 0.3


static func points_for_size(size: Vector3) -> int:
	return maxi(1, int(ceil(size.x * size.y * size.z)))
