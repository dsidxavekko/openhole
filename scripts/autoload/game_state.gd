extends Node
## Match settings shared between the menu and the game scene, plus player options.

signal graphics_changed

enum Mode { CLASSIC, SOLO, BATTLE }
enum MapTheme { CITY, SUBURB, NIGHT, MEXICO, WINTER }
enum Difficulty { EASY, NORMAL, HARD }

## tr() keys per MapTheme value, in order.
const THEME_KEYS := ["THEME_CITY", "THEME_SUBURB", "THEME_NIGHT", "THEME_MEXICO", "THEME_WINTER"]

const MODE_KEYS := ["classic", "solo", "battle"]
const DIFFICULTY_KEYS := ["DIFF_EASY", "DIFF_NORMAL", "DIFF_HARD"]
## Bot skill range and how soon bots start hunting other holes, per difficulty.
const BOT_SKILL := [Vector2(0.2, 0.45), Vector2(0.3, 0.7), Vector2(0.6, 0.95)]
const BOT_CHASE_START := [25.0, 15.0, 8.0]
## Minimum seconds between a bot's Shift uses, per difficulty (0 = whenever).
## Easy bots never shift; Normal ones shift sparingly; Hard ones freely.
const BOT_SHIFT_GAP := [9999.0, 30.0, 0.0]
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
var graphics := 2
var left_handed := false
var flashes := true
var joystick_size := JoystickPrefs.DEFAULT
var joystick_gain := JoystickPrefs.DEFAULT
## Achievements unlocked in the last match, shown as a toast in the menu.
var pending_achievements: Array[String] = []


func _ready() -> void:
	Gamepad.setup_actions()
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	var lang: String = Save.get_setting("lang", "")
	if lang == "":
		lang = "uk" if OS.get_locale_language() == "uk" else "en"
	# Dev helper for screenshots: "-- --lang=en" overrides the language without saving it.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			lang = arg.trim_prefix("--lang=")
	TranslationServer.set_locale(lang)
	map_theme = clampi(Save.get_setting("theme", MapTheme.CITY), 0, THEME_KEYS.size() - 1)
	# Dev helper for screenshots: "-- --theme=city|suburb|night|mexico|winter" overrides the theme without saving.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			map_theme = clampi(["city", "suburb", "night", "mexico", "winter"].find(arg.trim_prefix("--theme=").to_lower()), 0, THEME_KEYS.size() - 1)
	bot_count = clampi(Save.get_setting("bots", 7), MIN_BOTS, MAX_BOTS)
	difficulty = clampi(Save.get_setting("difficulty", Difficulty.NORMAL), 0, 2)
	vibration = Save.get_setting("vibration", true)
	volume = Save.get_setting("volume", 0.8)
	shake = Save.get_setting("shake", true)
	show_fps = Save.get_setting("fps", false)
	skin = clampi(Save.get_setting("skin", 0), 0, Skins.count() - 1)
	graphics = clampi(Save.get_setting("graphics", GraphicsQuality.Level.HIGH), 0, GraphicsQuality.KEYS.size() - 1)
	left_handed = Save.get_setting("left_handed", false)
	flashes = Save.get_setting("flashes", true)
	joystick_size = JoystickPrefs.clamp_index(Save.get_setting("joystick_size", JoystickPrefs.DEFAULT))
	joystick_gain = JoystickPrefs.clamp_index(Save.get_setting("joystick_gain", JoystickPrefs.DEFAULT))
	# Dev helper for screenshots: "-- --quality=low|medium|high".
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			graphics = clampi(["low", "medium", "high"].find(arg.trim_prefix("--quality=").to_lower()), 0, 2)
	# Dev helper for screenshots: "-- --left-handed" previews the mirrored HUD.
	if "--left-handed" in OS.get_cmdline_user_args():
		left_handed = true
	if not Skins.is_unlocked(skin):
		skin = 0
	apply_volume()
	apply_graphics()


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
	elif key == "graphics":
		apply_graphics()


## Applies the chosen quality preset to rendering and notifies the live scene.
func apply_graphics() -> void:
	var p := GraphicsQuality.preset(graphics)
	Engine.max_fps = int(p["fps"])
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(p["soft"]))
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.msaa_3d = int(p["msaa"])
		tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		tree.root.scaling_3d_scale = float(p["scale"])
	graphics_changed.emit()


func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	# Dev runs from the editor binary are silent; exported builds (even
	# debug-signed ones) keep sound.
	AudioServer.set_bus_mute(bus, volume <= 0.01 or OS.has_feature("editor"))
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


## Shift uses accumulated in today's Daily runs.
func daily_shifts_key() -> String:
	return "daily_shifts_%d" % daily_seed()


func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day


## Day key `days` before today (1 = yesterday). Noon avoids DST edges.
func daily_seed_offset(days: int) -> int:
	var d := Time.get_date_dict_from_system()
	var noon := {"year": d.year, "month": d.month, "day": d.day, "hour": 12}
	var p := Time.get_date_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(noon) - days * 86400)
	return p.year * 10000 + p.month * 100 + p.day


## Days in a row with a finished Daily; 0 once the streak is broken.
func daily_streak() -> int:
	var last := int(Save.get_setting("daily_last", 0))
	if last != daily_seed() and last != daily_seed_offset(1):
		return 0
	return int(Save.get_setting("daily_streak", 0))


## Today's Daily twist, or NONE outside the Daily.
func daily_mod() -> int:
	return DailyMods.for_seed(daily_seed()) if daily and mode == Mode.SOLO else DailyMods.Kind.NONE


## Bitmask of today's finished missions (0 on a new day).
func missions_mask() -> int:
	if int(Save.get_setting("missions_day", 0)) != daily_seed():
		return 0
	return int(Save.get_setting("missions_mask", 0))


func match_time() -> float:
	return DailyMods.match_time(150.0 if mode == Mode.BATTLE else 120.0, daily_mod())


func city_blocks() -> int:
	return 5 if mode == Mode.SOLO else 6


func match_theme() -> int:
	return daily_seed() % THEME_KEYS.size() if daily else map_theme


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


func bot_shift_gap() -> float:
	return BOT_SHIFT_GAP[difficulty]


## The focus ring only shows while the player navigates with keys or a pad;
## touches and the mouse hide it.
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		UiTheme.set_nav_visible(true)
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		UiTheme.set_nav_visible(false)
