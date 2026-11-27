class_name ShareCode
extends RefCounted
## A short text a player can paste to a friend: "OH1-C-123456-4159" means
## Classic on map seed 123456 with 4159 points. Solo scores are tenths of a
## percent of the city (652 = 65.2 %). Daily runs use mode D and the date as seed.

const PREFIX := "OH1"
const MODES := ["C", "S", "B", "D"]


static func encode(mode_letter: String, map_seed: int, score: int) -> String:
	return "%s-%s-%d-%d" % [PREFIX, mode_letter, map_seed, score]


## {mode, seed, score} or an empty dictionary when `text` is not a valid code.
static func decode(text: String) -> Dictionary:
	var parts := text.strip_edges().to_upper().split("-")
	if parts.size() != 4 or parts[0] != PREFIX or not MODES.has(parts[1]):
		return {}
	if not parts[2].is_valid_int() or not parts[3].is_valid_int():
		return {}
	var s := parts[2].to_int()
	var score := parts[3].to_int()
	if s < 0 or score < 0:
		return {}
	return {"mode": parts[1], "seed": s, "score": score}


## Letter for a game mode name (GameState.MODE_KEYS) and the Daily flag.
static func letter_for(mode_key: String, daily: bool) -> String:
	if daily:
		return "D"
	match mode_key:
		"solo":
			return "S"
		"battle":
			return "B"
	return "C"


## Human-readable score for the message that goes with the code.
static func score_text(mode_letter: String, score: int) -> String:
	if mode_letter == "S" or mode_letter == "D":
		return "%.1f%%" % (score / 10.0)
	return "%d" % score
