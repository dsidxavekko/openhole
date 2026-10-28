class_name Skins
extends RefCounted
## Player hole skins: rim colour + rim pattern (drawn by ground.gdshader),
## unlocked by records stored in Save.

enum Pattern { SOLID, STRIPES, DOTS, RAINBOW, PULSE, SHIMMER }

## need: [record key, value]; an empty key means unlocked from the start.
const LIST := [
	{"name": "SKIN_SKY", "color": Color("4cc9f0"), "pattern": Pattern.SOLID, "need": ["", 0]},
	{"name": "SKIN_ROSE", "color": Color("f72585"), "pattern": Pattern.SOLID, "need": ["", 0]},
	{"name": "SKIN_LIME", "color": Color("80ed99"), "pattern": Pattern.STRIPES, "need": ["classic", 1000]},
	{"name": "SKIN_SUN", "color": Color("ffd60a"), "pattern": Pattern.DOTS, "need": ["solo", 5]},
	{"name": "SKIN_NEON", "color": Color("b388eb"), "pattern": Pattern.PULSE, "need": ["total_eaten", 500]},
	{"name": "SKIN_TIGER", "color": Color("ff8500"), "pattern": Pattern.STRIPES, "need": ["classic", 3000]},
	{"name": "SKIN_ICE", "color": Color("caf0f8"), "pattern": Pattern.SHIMMER, "need": ["solo", 15]},
	{"name": "SKIN_RUBY", "color": Color("e63946"), "pattern": Pattern.PULSE, "need": ["battle_wins", 1]},
	{"name": "SKIN_GOLD", "color": Color("ffc300"), "pattern": Pattern.SHIMMER, "need": ["battle_wins", 5]},
	{"name": "SKIN_RAINBOW", "color": Color("ffffff"), "pattern": Pattern.RAINBOW, "need": ["total_eaten", 5000]},
]

## Text shown under a locked skin, per record key.
const NEED_TEXT := {
	"classic": "NEED_CLASSIC",
	"solo": "NEED_SOLO",
	"battle_wins": "NEED_BATTLE_WINS",
	"total_eaten": "NEED_EATEN",
}


static func count() -> int:
	return LIST.size()


static func get_skin(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


## Pure check against a {record key: value} dictionary (testable without Save).
static func unlocked_with(stats: Dictionary, i: int) -> bool:
	var need: Array = get_skin(i).need
	return need[0] == "" or float(stats.get(need[0], 0)) >= float(need[1])


static func is_unlocked(i: int) -> bool:
	return unlocked_with(current_stats(), i)


## Records from the Save autoload (looked up at runtime, so this class also
## compiles in headless test runs where autoloads are not identifiers).
static func current_stats() -> Dictionary:
	var out := {}
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("Save") if tree else null
	for k in NEED_TEXT:
		out[k] = save.get_record(k) if save else 0.0
	return out


static func unlocked_set(stats: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i in LIST.size():
		if unlocked_with(stats, i):
			out.append(i)
	return out


## Localised unlock condition, e.g. "Classic: 1000 points".
static func need_text(i: int) -> String:
	var need: Array = get_skin(i).need
	if need[0] == "":
		return ""
	return TranslationServer.translate(NEED_TEXT[need[0]]) % need[1]
