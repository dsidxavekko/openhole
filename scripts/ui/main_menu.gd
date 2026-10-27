extends Control
## Main menu built in code: modes, map options, language, records.

var _seed_edit: LineEdit
var _random_check: CheckButton


func _ready() -> void:
	theme = UiTheme.make()
	if GameState.autoplay:
		# Smoke test: jump straight into a match.
		var m := "classic"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--mode="):
				m = a.trim_prefix("--mode=")
		GameState.mode = GameState.MODE_KEYS.find(m)
		call_deferred("_start", GameState.mode)
		return
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("1b1b3a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)

	var title := Label.new()
	title.text = "HOLEDIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color("80ffdb"))
	box.add_child(title)
	var sub := Label.new()
	sub.text = tr("SUBTITLE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.7)
	box.add_child(sub)
	box.add_child(_spacer(30))

	for m in [GameState.Mode.CLASSIC, GameState.Mode.SOLO, GameState.Mode.BATTLE]:
		var b := Button.new()
		b.text = tr("MODE_" + GameState.MODE_KEYS[m].to_upper())
		b.custom_minimum_size.y = 110
		b.pressed.connect(_start.bind(m))
		box.add_child(b)
		var d := Label.new()
		d.text = tr("DESC_" + GameState.MODE_KEYS[m].to_upper())
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 24)
		d.modulate = Color(1, 1, 1, 0.6)
		box.add_child(d)

	box.add_child(_spacer(20))
	var theme_btn := Button.new()
	theme_btn.text = tr("MAP") % tr("THEME_CITY" if GameState.map_theme == GameState.MapTheme.CITY else "THEME_SUBURB")
	theme_btn.pressed.connect(func():
		GameState.map_theme = 1 - GameState.map_theme
		Save.set_setting("theme", GameState.map_theme)
		_build())
	box.add_child(theme_btn)

	_random_check = CheckButton.new()
	_random_check.text = tr("RANDOM_MAP")
	_random_check.button_pressed = GameState.random_seed
	box.add_child(_random_check)
	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = tr("SEED")
	seed_row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(GameState.map_seed)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_seed_edit.editable = not GameState.random_seed
	seed_row.add_child(_seed_edit)
	box.add_child(seed_row)
	_random_check.toggled.connect(func(on: bool): _seed_edit.editable = not on)

	var lang := Button.new()
	lang.text = tr("LANGUAGE")
	lang.pressed.connect(func():
		GameState.set_language("en" if TranslationServer.get_locale().begins_with("uk") else "uk")
		_build())
	box.add_child(lang)

	box.add_child(_spacer(20))
	var rec := Label.new()
	rec.text = "%s\n%s\n%s\n%s" % [
		tr("RECORDS"),
		tr("RECORD_CLASSIC") % int(Save.get_record("classic")),
		tr("RECORD_SOLO") % Save.get_record("solo"),
		tr("RECORD_BATTLE") % [int(Save.get_record("battle_wins")), int(Save.get_record("battle"))],
	]
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rec.add_theme_font_size_override("font_size", 26)
	box.add_child(rec)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _start(m: int) -> void:
	GameState.mode = m
	if _random_check:
		GameState.random_seed = _random_check.button_pressed
		if not GameState.random_seed and _seed_edit.text.is_valid_int():
			GameState.map_seed = _seed_edit.text.to_int()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
