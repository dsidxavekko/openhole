class_name DailyMissions
extends RefCounted
## Three small goals per date, the same for everyone. Each is judged on a
## single match; once met, it stays done for the rest of the day.
## Pure rules: Game feeds in the match stats, Save keeps the done-mask.

## stat: key in the match-stats dictionary; text: i18n key (with one %d);
## base/step: the target is base + step * (0..2) depending on the date.
const KINDS := [
	{"stat": "eaten", "text": "MISSION_EAT", "base": 300, "step": 150},
	{"stat": "combo", "text": "MISSION_COMBO", "base": 8, "step": 4},
	{"stat": "shift_kills", "text": "MISSION_SHIFT_KILLS", "base": 1, "step": 1},
	{"stat": "powerups", "text": "MISSION_POWERUPS", "base": 2, "step": 1},
	{"stat": "points", "text": "MISSION_POINTS", "base": 3000, "step": 1500},
	{"stat": "shifts", "text": "MISSION_SHIFTS", "base": 2, "step": 1},
]
const PER_DAY := 3


## Today's missions: [{kind, stat, text, need}] with PER_DAY distinct kinds.
static func for_seed(daily_seed: int) -> Array:
	var pool := range(KINDS.size())
	var out := []
	var h := hash(daily_seed * 17 + 3)
	for i in PER_DAY:
		var pick := posmod(h, pool.size())
		var kind: int = pool[pool.size() - 1 - pick] if i % 2 == 1 else pool[pick]
		pool.erase(kind)
		var k: Dictionary = KINDS[kind]
		var tier := posmod(h >> 7, 3)
		out.append({"kind": kind, "stat": k.stat, "text": k.text, "need": int(k.base) + int(k.step) * tier})
		h = hash(h + i + 1)
	return out


## Bitmask (bit i = mission i) of the missions `stats` satisfies.
static func met_mask(missions: Array, stats: Dictionary) -> int:
	var mask := 0
	for i in missions.size():
		if float(stats.get(missions[i].stat, 0.0)) >= float(missions[i].need):
			mask |= 1 << i
	return mask


static func is_done(mask: int, index: int) -> bool:
	return (mask >> index) & 1 == 1


## Bits set in `now` but not in `before`.
static func newly_done(before: int, now: int) -> int:
	return now & ~before


static func count_bits(mask: int) -> int:
	var n := 0
	for i in PER_DAY:
		if is_done(mask, i):
			n += 1
	return n
