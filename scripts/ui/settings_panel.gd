class_name SettingsPanel
extends VBoxContainer
## Options list. In the menu it also shows match options (bots, difficulty, map);
## in the pause screen only things that can change mid-match.

signal changed

var in_menu := true


func _init(p_in_menu := true) -> void:
	in_menu = p_in_menu


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	add_child(UiTheme.label(tr("SETTINGS"), 44, HORIZONTAL_ALIGNMENT_CENTER, 800))

	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = GameState.volume
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.custom_minimum_size.y = 56
	vol.value_changed.connect(func(v: float): GameState.set_option("volume", "volume", v))
	vol.drag_ended.connect(func(_c: bool): Sfx.play("ui"))
	_row(tr("SOUND"), vol)

	_toggle(tr("VIBRATION"), "vibration", "vibration")
	_toggle(tr("CAMERA_SHAKE"), "shake", "shake")
	_toggle(tr("SHOW_FPS"), "show_fps", "fps")

	if not in_menu:
		return
	add_child(_separator())
	_row(tr("DIFFICULTY"), _cycler(func(): return tr(GameState.DIFFICULTY_KEYS[GameState.difficulty]),
		func(dir: int): GameState.set_option("difficulty", "difficulty", posmod(GameState.difficulty + dir, 3))))
	_row(tr("BOTS"), _cycler(func(): return str(GameState.bot_count),
		func(dir: int): GameState.set_option("bot_count", "bots",
			clampi(GameState.bot_count + dir, GameState.MIN_BOTS, GameState.MAX_BOTS))))
	_row(tr("MAP_THEME"), _cycler(
		func(): return tr("THEME_CITY" if GameState.map_theme == GameState.MapTheme.CITY else "THEME_SUBURB"),
		func(_dir: int): GameState.set_option("map_theme", "theme", 1 - GameState.map_theme)))

	var seed_edit := LineEdit.new()
	seed_edit.text = str(GameState.map_seed)
	seed_edit.custom_minimum_size = Vector2(200, 0)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_edit.editable = not GameState.random_seed
	seed_edit.text_changed.connect(func(t: String):
		if t.is_valid_int():
			GameState.map_seed = t.to_int())
	var random := CheckButton.new()
	random.button_pressed = GameState.random_seed
	random.toggled.connect(func(on: bool):
		GameState.random_seed = on
		seed_edit.editable = not on
		Sfx.play("ui"))
	_row(tr("RANDOM_MAP"), random)
	_row(tr("SEED"), seed_edit)


func _row(text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(text, 30, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if control is HSlider:
		control.custom_minimum_size.x = 260
		control.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(control)
	add_child(row)


func _toggle(text: String, var_name: String, save_key: String) -> void:
	var cb := CheckButton.new()
	cb.button_pressed = GameState.get(var_name)
	cb.toggled.connect(func(on: bool):
		GameState.set_option(var_name, save_key, on)
		Sfx.play("ui")
		if on and var_name == "vibration":
			GameState.vibrate(30)
		changed.emit())
	_row(text, cb)


## "‹ value ›" selector. `get_text` returns the label, `step` is called with -1/+1.
func _cycler(get_text: Callable, step: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var value := UiTheme.label(get_text.call(), 30, HORIZONTAL_ALIGNMENT_CENTER, 700)
	value.custom_minimum_size.x = 190
	for dir in [-1, 1]:
		var b := Button.new()
		b.text = "‹" if dir < 0 else "›"
		b.custom_minimum_size = Vector2(68, 68)
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(func():
			step.call(dir)
			value.text = get_text.call()
			Sfx.play("ui")
			changed.emit())
		box.add_child(b)
		if dir < 0:
			box.add_child(value)
	return box


func _separator() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.1)
	c.custom_minimum_size.y = 2
	return c
