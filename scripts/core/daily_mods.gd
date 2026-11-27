class_name DailyMods
extends RefCounted
## Daily challenge twist: one rule change per date, the same for everybody.

enum Kind { NONE, SPRINT, NO_POWERUPS, POWER_RAIN, HEAD_START }

const COUNT := 5
const NAMES := {
	Kind.NONE: "MOD_NONE", Kind.SPRINT: "MOD_SPRINT", Kind.NO_POWERUPS: "MOD_NO_POWERUPS",
	Kind.POWER_RAIN: "MOD_POWER_RAIN", Kind.HEAD_START: "MOD_HEAD_START",
}
const DESCS := {
	Kind.NONE: "MOD_NONE_DESC", Kind.SPRINT: "MOD_SPRINT_DESC", Kind.NO_POWERUPS: "MOD_NO_POWERUPS_DESC",
	Kind.POWER_RAIN: "MOD_POWER_RAIN_DESC", Kind.HEAD_START: "MOD_HEAD_START_DESC",
}
const SPRINT_TIME := 90.0
const HEAD_START_LEVEL := 4
const RAIN_COUNT := 12
const RAIN_RESPAWN := 7.0


## The twist for a date key such as 20261127. Hashed so it does not march
## through the list in step with the date (or with the map theme).
static func for_seed(daily_seed: int) -> int:
	return posmod(hash(daily_seed * 31 + 7), COUNT)


static func match_time(base: float, kind: int) -> float:
	return SPRINT_TIME if kind == Kind.SPRINT else base


static func powerup_count(base: int, kind: int) -> int:
	match kind:
		Kind.NO_POWERUPS:
			return 0
		Kind.POWER_RAIN:
			return RAIN_COUNT
	return base


static func powerup_respawn(base: float, kind: int) -> float:
	return RAIN_RESPAWN if kind == Kind.POWER_RAIN else base


static func start_level(kind: int) -> int:
	return HEAD_START_LEVEL if kind == Kind.HEAD_START else 1


## Easier twists must not feed the shared Solo record (it unlocks skins and
## achievements), so only neutral or harder days count towards it.
static func counts_for_solo(kind: int) -> bool:
	return kind != Kind.POWER_RAIN and kind != Kind.HEAD_START
