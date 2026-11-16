class_name Achievements
extends RefCounted
## Lifetime achievements, checked against counters stored in Save.

## stat: key in the stats dictionary; need: threshold.
const LIST := [
	{"key": "ACH_FIRST_BITE", "stat": "total_eaten", "need": 1},
	{"key": "ACH_HUNDRED", "stat": "total_eaten", "need": 100},
	{"key": "ACH_THOUSAND", "stat": "total_eaten", "need": 1000},
	{"key": "ACH_FIVE_THOUSAND", "stat": "total_eaten", "need": 5000},
	{"key": "ACH_FIRST_SHIFT", "stat": "shift_kills", "need": 1},
	{"key": "ACH_TEN_SHIFT", "stat": "shift_kills", "need": 10},
	{"key": "ACH_CLASSIC_1000", "stat": "classic", "need": 1000},
	{"key": "ACH_CLASSIC_3000", "stat": "classic", "need": 3000},
	{"key": "ACH_SOLO_40", "stat": "solo", "need": 40},
	{"key": "ACH_SOLO_60", "stat": "solo", "need": 60},
	{"key": "ACH_BATTLE_WIN", "stat": "battle_wins", "need": 1},
	{"key": "ACH_BATTLE_FIVE", "stat": "battle_wins", "need": 5},
	{"key": "ACH_MATCHES_10", "stat": "matches", "need": 10},
	{"key": "ACH_STREAK_3", "stat": "best_daily_streak", "need": 3},
	{"key": "ACH_STREAK_7", "stat": "best_daily_streak", "need": 7},
]
const STATS_KEYS := ["total_eaten", "shift_kills", "classic", "solo",
	"battle_wins", "matches", "best_daily_streak"]


static func name_of(i: int) -> String:
	return TranslationServer.translate(LIST[i].key)


static func count() -> int:
	return LIST.size()


## Indices earned with `stats` ({stat key: value}).
static func earned_set(stats: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i in LIST.size():
		if float(stats.get(LIST[i].stat, 0)) >= float(LIST[i].need):
			out.append(i)
	return out


## Achievements earned with `after` but not with `before`.
static func new_set(before: Dictionary, after: Dictionary) -> Array[int]:
	var had := earned_set(before)
	var out: Array[int] = []
	for i in earned_set(after):
		if not had.has(i):
			out.append(i)
	return out


## "12/100" or "35/40%", for the locked rows on the stats screen.
static func progress_text(i: int, stats: Dictionary) -> String:
	var value := int(float(stats.get(LIST[i].stat, 0)))
	var need := int(LIST[i].need)
	if LIST[i].stat == "solo":
		return "%d/%d%%" % [value, need]
	return "%d/%d" % [value, need]


## Counters from the Save autoload, looked up at runtime so the class also
## compiles in headless tests where autoloads are not identifiers.
static func current_stats() -> Dictionary:
	var out := {}
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("Save") if tree else null
	for k in STATS_KEYS:
		out[k] = float(save.get_record(k)) if save else 0.0
	return out
