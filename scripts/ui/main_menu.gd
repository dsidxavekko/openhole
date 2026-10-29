extends Control
## Main menu built in code: a live 3D city in the background (the game scene in
## attract mode), logo, mode cards, and bottom buttons for skins, settings, language.

const GAME_SCENE := "res://scenes/game.tscn"

var _bg: Node = null
var _logo: LogoHole
var _cards: VBoxContainer
var _sheet_layer: Control
var _sheet: PanelContainer
var _lang_button: Button


func _ready() -> void:
	theme = UiTheme.make()
	if GameState.autoplay:
		# Smoke test: jump straight into a match.
		var m := "classic"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--mode="):
				m = a.trim_prefix("--mode=")
			if a.begins_with("--seed="):
				GameState.random_seed = false
				GameState.map_seed = a.trim_prefix("--seed=").to_int()
		GameState.daily = m == "daily"
		GameState.mode = GameState.Mode.SOLO if GameState.daily else GameState.MODE_KEYS.find(m)
		var scr: Script = load("res://scripts/game.gd")
		if scr == null or not scr.can_instantiate():
			push_error("game.gd does not compile")
			get_tree().quit(1)
			return
		call_deferred("_start", GameState.mode, GameState.daily)
		return
	_start_background()
	_build()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_take_screenshot(arg.trim_prefix("--screenshot="))


## Dev helper: "-- --screenshot=/path/menu.png [--shot-delay=5] [--shot-sheet=skins]".
func _take_screenshot(path: String) -> void:
	var delay := 5.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-delay="):
			delay = arg.trim_prefix("--shot-delay=").to_float()
		if arg == "--shot-sheet=skins":
			_open_skins()
		if arg == "--shot-sheet=settings":
			_open_settings()
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _sheet_layer and _sheet_layer.visible:
			_close_sheet()
		else:
			get_tree().quit()


# --- Background ------------------------------------------------------------

func _start_background() -> void:
	if _bg:
		_bg.queue_free()
	_bg = load(GAME_SCENE).instantiate()
	_bg.attract = true
	_bg.attract_finished.connect(_start_background, CONNECT_DEFERRED)
	add_child(_bg)
	move_child(_bg, 0)


# --- Layout ----------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		if c != _bg:
			c.queue_free()

	# Darken the city towards the bottom so the cards stay readable.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.06, 0.05, 0.16, 0.25))
	grad.set_color(1, Color(0.06, 0.05, 0.16, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var safe := Control.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	UiTheme.apply_safe_area(safe)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -170
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_make_logo())
	var sub := UiTheme.label(tr("SUBTITLE"), 30, HORIZONTAL_ALIGNMENT_CENTER, 600)
	sub.modulate = Color(1, 1, 1, 0.85)
	box.add_child(sub)
	box.add_child(_spacer(36))

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 20)
	box.add_child(_cards)
	_fill_cards()

	safe.add_child(_make_bottom_bar())

	_sheet_layer = Control.new()
	_sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_layer.visible = false
	add_child(_sheet_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_sheet())
	_sheet_layer.add_child(dim)


func _make_logo() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	# "OPENH" + animated hole as the "O" + "LE".
	var make_text := func(text: String) -> Label:
		var t := UiTheme.label(text, 80, HORIZONTAL_ALIGNMENT_CENTER, 900)
		t.add_theme_color_override("font_color", Color.WHITE)
		t.add_theme_constant_override("outline_size", 20)
		t.add_theme_color_override("font_outline_color", Color("2b1d6b"))
		t.add_theme_constant_override("shadow_offset_y", 8)
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		return t
	row.add_child(make_text.call("OPENH"))
	_logo = LogoHole.new()
	_logo.custom_minimum_size = Vector2(80, 100)
	row.add_child(_logo)
	row.add_child(make_text.call("LE"))
	# Gentle "breathing".
	row.resized.connect(func(): row.pivot_offset = row.size / 2.0)
	var tw := row.create_tween().set_loops()
	tw.tween_property(row, "scale", Vector2(1.04, 1.04), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(row, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)
	return row


func _fill_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	var daily_best := Save.get_record(GameState.daily_key())
	var specs := [
		{"title": tr("DAILY"), "desc": tr("DESC_DAILY"), "color": UiTheme.CARD_DAILY, "icon": "daily",
			"right": tr("BEST_TODAY") % ("%.1f%%" % daily_best) if daily_best > 0 else _today(),
			"go": _start.bind(GameState.Mode.SOLO, true)},
		{"title": tr("MODE_CLASSIC"), "desc": tr("DESC_CLASSIC") % GameState.bot_count, "color": UiTheme.CARD_CLASSIC,
			"icon": "classic", "right": _best("%d" % int(Save.get_record("classic"))),
			"go": _start.bind(GameState.Mode.CLASSIC, false)},
		{"title": tr("MODE_SOLO"), "desc": tr("DESC_SOLO"), "color": UiTheme.CARD_SOLO, "icon": "solo",
			"right": _best("%.1f%%" % Save.get_record("solo")), "go": _start.bind(GameState.Mode.SOLO, false)},
		{"title": tr("MODE_BATTLE"), "desc": tr("DESC_BATTLE"), "color": UiTheme.CARD_BATTLE, "icon": "battle",
			"right": tr("WINS") % int(Save.get_record("battle_wins")), "go": _start.bind(GameState.Mode.BATTLE, false)},
	]
	for i in specs.size():
		var card := _card(specs[i])
		_cards.add_child(card)
		# Cards fly in one after another.
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)


func _best(value: String) -> String:
	return tr("BEST") % value if value != "0" and value != "0.0%" else ""


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%02d.%02d" % [d.day, d.month]


func _card(spec: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size.y = 150
	UiTheme.style_button(b, UiTheme.card(spec.color), UiTheme.card(spec.color, true))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -24
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := ModeIcon.new()
	icon.kind = spec.icon
	icon.custom_minimum_size = Vector2(96, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var title := UiTheme.label(spec.title, 44, HORIZONTAL_ALIGNMENT_LEFT, 800)
	texts.add_child(title)
	var desc := UiTheme.label(spec.desc, 22, HORIZONTAL_ALIGNMENT_LEFT, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_constant_override("outline_size", 4)
	desc.modulate = Color(1, 1, 1, 0.9)
	texts.add_child(desc)
	if spec.right != "":
		var right := UiTheme.label(spec.right, 24, HORIZONTAL_ALIGNMENT_RIGHT, 700)
		right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		right.custom_minimum_size.y = 40
		texts.add_child(right)
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		right.modulate = Color(1, 1, 1, 0.75)
	var go: Callable = spec.go
	b.pressed.connect(func():
		Sfx.play("ui")
		UiTheme.bounce(b)
		get_tree().create_timer(0.15).timeout.connect(go))
	return b


func _make_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 40)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -40
	bar.add_child(_round_button("skins", _open_skins))
	bar.add_child(_round_button("settings", _open_settings))
	_lang_button = _round_button("", _toggle_language)
	_lang_button.text = "UA" if TranslationServer.get_locale().begins_with("uk") else "EN"
	bar.add_child(_lang_button)
	return bar


func _round_button(icon_kind: String, action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 112)
	b.add_theme_font_size_override("font_size", 36)
	UiTheme.style_button(b, UiTheme.round_button(UiTheme.BUTTON), UiTheme.round_button(UiTheme.BUTTON_PRESSED))
	if icon_kind != "":
		var icon := BarIcon.new()
		icon.kind = icon_kind
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
	b.pressed.connect(func():
		Sfx.play("ui")
		UiTheme.bounce(b)
		action.call())
	return b


func _toggle_language() -> void:
	GameState.set_language("en" if TranslationServer.get_locale().begins_with("uk") else "uk")
	_build()


# --- Bottom sheets ---------------------------------------------------------

func _open_skins() -> void:
	var p := SkinsPanel.new()
	p.changed.connect(func(): _logo.queue_redraw())
	_open_sheet(p)


func _open_settings() -> void:
	var p := SettingsPanel.new(true)
	p.changed.connect(_fill_cards)
	_open_sheet(p)


func _open_sheet(content: Control) -> void:
	if _sheet:
		_sheet.queue_free()
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UiTheme.sheet())
	_sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	_sheet.add_child(box)
	box.add_child(content)
	var close := Button.new()
	close.text = tr("CLOSE")
	close.custom_minimum_size.y = 96
	close.pressed.connect(func():
		Sfx.play("ui")
		_close_sheet())
	box.add_child(close)
	_sheet_layer.add_child(_sheet)
	_sheet_layer.visible = true
	_sheet_layer.modulate.a = 0.0
	# Slide up from below the screen.
	await get_tree().process_frame
	if not is_instance_valid(_sheet):
		return
	var h := _sheet.size.y
	_sheet.position.y = size.y
	var tw := create_tween().set_parallel()
	tw.tween_property(_sheet_layer, "modulate:a", 1.0, 0.15)
	tw.tween_property(_sheet, "position:y", size.y - h, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close_sheet() -> void:
	if _sheet == null:
		return
	var s := _sheet
	_sheet = null
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "position:y", size.y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_sheet_layer, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(func():
		s.queue_free()
		if _sheet == null:
			_sheet_layer.visible = false)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _start(m: int, daily: bool) -> void:
	GameState.mode = m
	GameState.daily = daily
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK and GameState.autoplay:
		push_error("Game scene failed to load: %d" % err)
		get_tree().quit(1)


# --- Drawn icons -----------------------------------------------------------

## The "O" of the logo: a hole with the current skin's rim.
class LogoHole extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var sk := Skins.get_skin(GameState.skin)
		var c := Vector2(size.x / 2.0, size.y * 0.55)
		var r := minf(size.x, size.y) * 0.42
		var rim: Color = sk.color
		if sk.pattern == Skins.Pattern.RAINBOW:
			rim = Color.from_hsv(fposmod(_t * 0.15, 1.0), 0.8, 1.0)
		draw_circle(c + Vector2(0, 8), r + 10.0, Color(0, 0, 0, 0.45))
		draw_circle(c, r + 10.0, Color("2b1d6b"))
		draw_circle(c, r + 3.0, rim.lightened(0.15 + 0.1 * sin(_t * 3.0)))
		draw_circle(c, r - 4.0, Color(0.05, 0.03, 0.1))
		draw_circle(c + Vector2(0, r * 0.15), r * 0.62, Color(0, 0, 0))


## Mode card icons drawn with primitives.
class ModeIcon extends Control:
	var kind := ""

	func _draw() -> void:
		var c := size / 2.0
		var ink := Color(1, 1, 1, 0.95)
		var hole := Color(0.05, 0.03, 0.1)
		match kind:
			"classic":
				for spec in [[Vector2(-18, 12), 22.0], [Vector2(22, -6), 15.0], [Vector2(8, 30), 9.0]]:
					draw_circle(c + spec[0], spec[1] + 4.0, ink)
					draw_circle(c + spec[0], spec[1], hole)
			"solo":
				draw_rect(Rect2(c.x - 6, c.y - 34, 26, 40), ink)
				for y in 3:
					draw_rect(Rect2(c.x - 1, c.y - 28 + y * 12, 6, 6), Color(0, 0, 0, 0.3))
					draw_rect(Rect2(c.x + 9, c.y - 28 + y * 12, 6, 6), Color(0, 0, 0, 0.3))
				draw_circle(c + Vector2(-8, 22), 26.0, ink)
				draw_circle(c + Vector2(-8, 22), 22.0, hole)
			"battle":
				for i in 16:
					var a := TAU * i / 16.0
					draw_arc(c, 40.0, a, a + TAU / 32.0, 4, ink, 5.0, true)
				draw_circle(c, 22.0, ink)
				draw_circle(c, 18.0, hole)
			"daily":
				var r := Rect2(c.x - 34, c.y - 30, 68, 64)
				draw_rect(r, ink)
				draw_rect(Rect2(r.position, Vector2(r.size.x, 18)), Color(0, 0, 0, 0.35))
				for dx in [-18.0, 18.0]:
					draw_rect(Rect2(c.x + dx - 3, c.y - 38, 6, 14), ink)
				var f := get_theme_default_font()
				var day := str(Time.get_date_dict_from_system().day)
				var fs := 32
				var w := f.get_string_size(day, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2(c.x - w / 2.0, c.y + 26), day, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					UiTheme.CARD_DAILY.darkened(0.2))


## Icons of the round buttons at the bottom.
class BarIcon extends Control:
	var kind := ""

	func _draw() -> void:
		var c := size / 2.0
		match kind:
			"skins":
				draw_circle(c, 30.0, Color("ffd60a"))
				draw_arc(c, 30.0, 0.0, PI * 0.66, 12, Color("f72585"), 9.0, true)
				draw_arc(c, 30.0, PI * 0.66, PI * 1.33, 12, Color("4cc9f0"), 9.0, true)
				draw_arc(c, 30.0, PI * 1.33, TAU, 12, Color("80ed99"), 9.0, true)
				draw_circle(c, 22.0, Color(0.05, 0.03, 0.1))
			"settings":
				for i in 8:
					var a := TAU * i / 8.0
					var d := Vector2.from_angle(a)
					var n := d.orthogonal()
					var p := c + d * 26.0
					draw_colored_polygon(PackedVector2Array([p + n * 7 - d * 4, p - n * 7 - d * 4,
						p - n * 5 + d * 8, p + n * 5 + d * 8]), Color.WHITE)
				draw_circle(c, 24.0, Color.WHITE)
				draw_circle(c, 10.0, UiTheme.BUTTON)
