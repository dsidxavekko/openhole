extends Node
## Match settings shared between the menu and the game scene.

enum Mode { CLASSIC, SOLO, BATTLE }
enum MapTheme { CITY, SUBURB }

const MODE_KEYS := ["classic", "solo", "battle"]

var mode: int = Mode.CLASSIC
var map_theme: int = MapTheme.CITY
var random_seed := true
var map_seed := 1
var bot_count := 7
## Set by "-- --autoplay": the player hole is driven by a bot (smoke tests).
var autoplay := false


func _ready() -> void:
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	var lang: String = Save.get_setting("lang", "")
	if lang == "":
		lang = "uk" if OS.get_locale_language() == "uk" else "en"
	TranslationServer.set_locale(lang)
	map_theme = Save.get_setting("theme", MapTheme.CITY)


func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
	Save.set_setting("lang", code)


func mode_key() -> String:
	return MODE_KEYS[mode]


func match_time() -> float:
	return 150.0 if mode == Mode.BATTLE else 120.0


func city_blocks() -> int:
	return 5 if mode == Mode.SOLO else 6


func resolve_seed() -> int:
	if random_seed:
		map_seed = randi() % 1000000
	return map_seed
