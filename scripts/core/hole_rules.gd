class_name HoleRules
extends RefCounted
## Pure game rules: levels, radius, what fits, who eats whom.

const BASE_RADIUS := 0.8
const GROWTH := 1.28
const MAX_LEVEL := 16
const FIT_FACTOR := 0.92
const EAT_HOLE_RATIO := 1.2
## Tall things count as wider: a skyscraper needs a big hole, not just its base.
const HEIGHT_WEIGHT := 0.3


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


## Effective size used for "does it fit": base width or a share of the height.
static func fit_size(extent: float, height: float) -> float:
	return maxf(extent, height * HEIGHT_WEIGHT)


## `size` is the effective size from fit_size().
static func fits(size: float, radius: float) -> bool:
	return size < radius * 2.0 * FIT_FACTOR


static func can_eat_hole(big_r: float, small_r: float, dist: float) -> bool:
	return big_r > small_r * EAT_HOLE_RATIO and dist < big_r - small_r * 0.3


## Sub-linear in volume: small things matter, skyscrapers do not dominate.
static func points_for_size(size: Vector3) -> int:
	return maxi(1, int(ceil(2.0 * pow(size.x * size.y * size.z, 0.7))))


## Eating streak bonus: +2.5 % per item in the streak, up to +50 %.
static func combo_multiplier(combo: int) -> float:
	return 1.0 + clampi(combo - 1, 0, 20) * 0.025


# --- Shift: the player's role swap ------------------------------------------
# While shifted the hole is small and fast, cannot be eaten, eats no city,
# and swallows any hole it dives into, however big.

const SHIFT_RADIUS_FACTOR := 0.45
const SHIFT_SPEED_FACTOR := 1.25
## Seconds after a shift ends before the next one is ready.
const SHIFT_COOLDOWN := 8.0


static func shifted_radius(radius: float) -> float:
	return maxf(radius * SHIFT_RADIUS_FACTOR, BASE_RADIUS * 0.75)


static func shifted_speed(speed: float) -> float:
	return speed * SHIFT_SPEED_FACTOR


## How deep a shifted hole must dive into another one, as a share of its radius.
const SHIFT_EAT_DEPTH := 0.5


## A shifted hole eats another one when it reaches the inner half of it.
## There is no size limit: the small one swallows the big one, but it has to
## dive in deep within its short Shift, which takes aim on a big target.
static func can_shift_eat(shifted_r: float, target_r: float, dist: float) -> bool:
	return dist < maxf(target_r * SHIFT_EAT_DEPTH, shifted_r)


## Room for future limits (e.g. a minimum level); every level can shift for now.
static func can_be_shifted(_level: int) -> bool:
	return true


# --- Bot Shift (hard bots only) ----------------------------------------------

## How close a hole that could eat us must be before a bot shifts to escape.
static func shift_escape_reach(radius: float) -> float:
	return 2.0 + radius * 1.5


## Whether a bot should spend its Shift diving into a bigger hole: the victim
## must be too big to eat the usual way and reachable during the short Shift.
static func can_shift_dive(me_r: float, target_r: float, dist: float) -> bool:
	return target_r > me_r * EAT_HOLE_RATIO and dist < 9.0 + target_r * 1.5
