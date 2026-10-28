extends Node
## Match settings shared between the menu and the game scene, plus player options.

enum Mode { CLASSIC, SOLO, BATTLE }
enum MapTheme { CITY, SUBURB }
enum Difficulty { EASY, NORMAL, HARD }

const MODE_KEYS := ["classic", "solo", "battle"]
const DIFFICULTY_KEYS := ["DIFF_EASY", "DIFF_NORMAL", "DIFF_HARD"]
## Bot skill range and how soon bots start hunting other holes, per difficulty.
const BOT_SKILL := [Vector2(0.2, 0.45), Vector2(0.3, 0.7), Vector2(0.6, 0.95)]
const BOT_CHASE_START := [25.0, 15.0, 8.0]
const MIN_BOTS := 3
const MAX_BOTS := 11

var mode: int = Mode.CLASSIC
var map_theme: int = MapTheme.CITY
var random_seed := true
var map_seed := 1
## Daily challenge: Solo on a map that is the same for everyone on that date.
var daily := false
## Set by "-- --autoplay": the player hole is driven by a bot (smoke tests).
var autoplay := false

# Options (saved).
var bot_count := 7
var difficulty: int = Difficulty.NORMAL
var vibration := true
var volume := 0.8
var shake := true
var show_fps := false
var skin := 0


func _ready() -> void:
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	var lang: String = Save.get_setting("lang", "")
	if lang == "":
		lang = "uk" if OS.get_locale_language() == "uk" else "en"
	TranslationServer.set_locale(lang)
	map_theme = Save.get_setting("theme", MapTheme.CITY)
	bot_count = clampi(Save.get_setting("bots", 7), MIN_BOTS, MAX_BOTS)
	difficulty = clampi(Save.get_setting("difficulty", Difficulty.NORMAL), 0, 2)
	vibration = Save.get_setting("vibration", true)
	volume = Save.get_setting("volume", 0.8)
	shake = Save.get_setting("shake", true)
	show_fps = Save.get_setting("fps", false)
	skin = Save.get_setting("skin", 0)
	if not Skins.is_unlocked(skin):
		skin = 0
	apply_volume()


func _exit_tree() -> void:
	UiTheme.clear_cache()


func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
	Save.set_setting("lang", code)


## Changes an option and saves it. `key` is the variable name, `save_key` the config key.
func set_option(key: String, save_key: String, value: Variant) -> void:
	set(key, value)
	Save.set_setting(save_key, value)
	if key == "volume":
		apply_volume()


func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.01)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.01)))


func vibrate(ms: int) -> void:
	if vibration:
		Input.vibrate_handheld(ms)


func mode_key() -> String:
	return MODE_KEYS[mode]


## Key for records: daily runs have their own record per date.
func record_key() -> String:
	return daily_key() if daily else mode_key()


func daily_key() -> String:
	return "daily_%d" % daily_seed()


func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day


func match_time() -> float:
	return 150.0 if mode == Mode.BATTLE else 120.0


func city_blocks() -> int:
	return 5 if mode == Mode.SOLO else 6


func match_theme() -> int:
	return daily_seed() % 2 if daily else map_theme


func resolve_seed() -> int:
	if daily:
		map_seed = daily_seed()
	elif random_seed:
		map_seed = randi() % 1000000
	return map_seed


func bot_skill_range() -> Vector2:
	return BOT_SKILL[difficulty]


func bot_chase_start() -> float:
	return BOT_CHASE_START[difficulty]
