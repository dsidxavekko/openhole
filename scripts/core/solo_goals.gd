class_name SoloGoals
extends RefCounted
## Solo goals: the share of the city (by value) needed for each medal.

const TIERS := [
	{"key": "GOAL_BRONZE", "pct": 25.0},
	{"key": "GOAL_SILVER", "pct": 45.0},
	{"key": "GOAL_GOLD", "pct": 65.0},
]


## -1 below the first goal, otherwise the index of the best reached medal.
static func tier_for(pct: float) -> int:
	var best := -1
	for i in TIERS.size():
		if pct >= float(TIERS[i].pct):
			best = i
	return best


static func tier_name(pct: float) -> String:
	var i := tier_for(pct)
	return TranslationServer.translate(TIERS[i].key) if i >= 0 else ""


## One line for the results screen: the medal earned and the next goal.
static func progress_line(pct: float) -> String:
	var i := tier_for(pct)
	if i >= TIERS.size() - 1:
		return TranslationServer.translate("SOLO_GOAL_DONE") % TranslationServer.translate(TIERS[i].key)
	if i < 0:
		return TranslationServer.translate("SOLO_NEXT") % [
			TranslationServer.translate(TIERS[0].key), int(TIERS[0].pct)]
	var next: Dictionary = TIERS[i + 1]
	return TranslationServer.translate("SOLO_GOAL") % [
		TranslationServer.translate(TIERS[i].key),
		TranslationServer.translate(next.key), int(next.pct)]
