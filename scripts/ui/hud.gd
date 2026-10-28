class_name Hud
extends CanvasLayer
## In-game overlay: timer, level bar, power-ups, combo, leaderboard, notices,
## off-screen pointers, pause screen and results panel.

signal play_again
signal to_menu
signal resume

const BOARD_ROWS := 5

var joystick: FloatingJoystick
var _root: Control
var _timer_label: Label
var _level_label: Label
var _level_bar: ProgressBar
var _effects_label: Label
var _combo_label: Label
var _board_labels: Array[Label] = []
var _info_label: Label
var _notice: Label
var _results: PanelContainer
var _results_box: VBoxContainer
var _pause: Control
var _pause_box: VBoxContainer
var _pause_button: Button
var _pointers: PointerLayer
var _notice_time := 0.0
var _fps: Label
var _last_combo := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.make()
	add_child(_root)
	UiTheme.apply_safe_area(_root)

	_pointers = PointerLayer.new()
	_root.add_child(_pointers)

	joystick = FloatingJoystick.new()
	_root.add_child(joystick)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-170, 20)
	top.custom_minimum_size = Vector2(340, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 4)
	_root.add_child(top)
	_timer_label = UiTheme.label("", 58, HORIZONTAL_ALIGNMENT_CENTER, 800)
	top.add_child(_timer_label)
	_level_label = UiTheme.label("", 26, HORIZONTAL_ALIGNMENT_CENTER, 600)
	top.add_child(_level_label)
	_level_bar = ProgressBar.new()
	_level_bar.custom_minimum_size = Vector2(340, 18)
	_level_bar.show_percentage = false
	_level_bar.max_value = 1.0
	_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_level_bar)
	_effects_label = UiTheme.label("", 26, HORIZONTAL_ALIGNMENT_CENTER, 700)
	top.add_child(_effects_label)
	_combo_label = UiTheme.label("", 34, HORIZONTAL_ALIGNMENT_CENTER, 800)
	_combo_label.add_theme_color_override("font_color", Color("ffd60a"))
	top.add_child(_combo_label)

	var board := VBoxContainer.new()
	board.position = Vector2(16, 250)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(board)
	for i in BOARD_ROWS:
		var l := UiTheme.label("", 26, HORIZONTAL_ALIGNMENT_LEFT, 600)
		board.add_child(l)
		_board_labels.append(l)

	_pause_button = Button.new()
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-100, 24)
	_pause_button.custom_minimum_size = Vector2(80, 80)
	_pause_button.size = Vector2(80, 80)
	UiTheme.style_button(_pause_button, UiTheme.round_button(Color(0, 0, 0, 0.35)),
		UiTheme.round_button(Color(0, 0, 0, 0.6)))
	var icon := PauseIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_button.add_child(icon)
	_pause_button.pressed.connect(func():
		if _pause.visible:
			resume.emit()
		else:
			get_parent().pause())
	_root.add_child(_pause_button)
	joystick.blockers.append(_pause_button)

	_info_label = UiTheme.label("", 28, HORIZONTAL_ALIGNMENT_RIGHT, 600)
	_info_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_label.position = Vector2(-280, 120)
	_info_label.custom_minimum_size = Vector2(260, 0)
	_root.add_child(_info_label)

	_notice = UiTheme.label("", 42, HORIZONTAL_ALIGNMENT_CENTER, 800)
	_notice.set_anchors_preset(Control.PRESET_CENTER)
	_notice.position = Vector2(-340, -220)
	_notice.custom_minimum_size = Vector2(680, 0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_notice)

	_fps = UiTheme.label("", 20, HORIZONTAL_ALIGNMENT_LEFT)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps.position = Vector2(12, -36)
	_fps.modulate = Color(1, 1, 1, 0.6)
	_root.add_child(_fps)

	_pause = _overlay()
	_pause_box = _pause.get_meta("box")
	_root.add_child(_pause)

	_results = PanelContainer.new()
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.custom_minimum_size = Vector2(580, 0)
	_results.position = Vector2(-290, -340)
	_results.visible = false
	_root.add_child(_results)
	_results_box = VBoxContainer.new()
	_results_box.add_theme_constant_override("separation", 16)
	_results.add_child(_results_box)


## Dimmed full-screen layer with a centred panel; the panel's VBox is in meta "box".
func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	o.set_meta("box", box)
	return o


func _process(delta: float) -> void:
	_fps.visible = GameState.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			_notice.text = ""


func set_time(seconds: float) -> void:
	var s := int(ceil(maxf(seconds, 0.0)))
	_timer_label.text = "%d:%02d" % [s / 60, s % 60]
	_timer_label.modulate = Color(1, 0.4, 0.4) if s <= 10 else Color.WHITE


func set_level(level: int, progress: float) -> void:
	_level_label.text = tr("LEVEL") % level
	_level_bar.value = progress


## effects: Powerup.Kind -> seconds left.
func set_effects(effects: Dictionary) -> void:
	var parts: PackedStringArray = []
	var strongest := -1
	for k in effects:
		parts.append("%s %d" % [tr(Powerup.NAMES[k]), int(ceil(effects[k]))])
		strongest = k
	_effects_label.text = "  ·  ".join(parts)
	if strongest >= 0:
		_effects_label.add_theme_color_override("font_color", (Powerup.COLORS[strongest] as Color).lightened(0.3))


func set_combo(combo: int) -> void:
	if combo < 5:
		_combo_label.text = ""
		_last_combo = 0
		return
	_combo_label.text = tr("COMBO") % [combo, HoleRules.combo_multiplier(combo)]
	if combo / 5 != _last_combo / 5:
		UiTheme.bounce(_combo_label)
	_last_combo = combo


func set_info(text: String) -> void:
	_info_label.text = text


func set_board(rows: Array) -> void:
	# rows: [{place, name, points, color, me}]
	for i in BOARD_ROWS:
		var l := _board_labels[i]
		l.visible = i < rows.size()
		if not l.visible:
			continue
		var r: Dictionary = rows[i]
		l.text = "%d. %s  %d" % [r.place, r.name, r.points]
		l.modulate = (r.color as Color).lightened(0.35)
		l.add_theme_font_size_override("font_size", 31 if r.me else 26)


## pointers: [{p: Vector2 screen position, a: angle, c: Color}]
func set_pointers(pointers: Array) -> void:
	_pointers.pointers = pointers
	_pointers.queue_redraw()


func notice(text: String, seconds := 2.5) -> void:
	_notice.text = text
	_notice_time = seconds
	_notice.pivot_offset = _notice.size / 2.0
	_notice.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_notice, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_paused() -> bool:
	return _pause.visible


func has_results() -> bool:
	return _results.visible


func show_pause() -> void:
	joystick.release()
	joystick.enabled = false
	_fill_pause(false)
	_pause.visible = true


func hide_pause() -> void:
	_pause.visible = false
	joystick.enabled = true


func _fill_pause(with_settings: bool) -> void:
	for c in _pause_box.get_children():
		c.queue_free()
	if with_settings:
		_pause_box.add_child(SettingsPanel.new(false))
		_pause_box.add_child(_button(tr("BACK"), func(): _fill_pause(false)))
		return
	_pause_box.add_child(UiTheme.label(tr("PAUSE"), 56, HORIZONTAL_ALIGNMENT_CENTER, 800))
	_pause_box.add_child(_button(tr("CONTINUE"), func(): resume.emit()))
	_pause_box.add_child(_button(tr("SETTINGS"), func(): _fill_pause(true)))
	_pause_box.add_child(_button(tr("MENU"), func(): to_menu.emit()))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 96
	b.pressed.connect(func():
		Sfx.play("ui")
		action.call())
	return b


func show_results(title: String, lines: Array) -> void:
	joystick.release()
	joystick.enabled = false
	_pause.visible = false
	_pause_button.visible = false
	_notice.text = ""
	_combo_label.text = ""
	_pointers.pointers = []
	_pointers.queue_redraw()
	for c in _results_box.get_children():
		c.queue_free()
	var t := UiTheme.label(title, 56, HORIZONTAL_ALIGNMENT_CENTER, 800)
	t.add_theme_color_override("font_color", UiTheme.ACCENT)
	_results_box.add_child(t)
	for line in lines:
		var l := UiTheme.label(line, 30, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_results_box.add_child(l)
	_results_box.add_child(_button(tr("PLAY_AGAIN"), func(): play_again.emit()))
	_results_box.add_child(_button(tr("MENU"), func(): to_menu.emit()))
	_results.visible = true
	_results.pivot_offset = _results.size / 2.0
	_results.scale = Vector2(0.8, 0.8)
	_results.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_results, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_results, "modulate:a", 1.0, 0.2)


## Two bars of a pause icon.
class PauseIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		for dx in [-11.0, 11.0]:
			draw_rect(Rect2(c.x + dx - 5.0, c.y - 16.0, 10.0, 32.0), Color.WHITE)


## Triangles on the screen edge pointing at holes outside the view.
class PointerLayer extends Control:
	var pointers: Array = []

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for ptr in pointers:
			var p: Vector2 = ptr.p - global_position
			var a: float = ptr.a
			var c: Color = ptr.c
			var tip := p + Vector2.from_angle(a) * 22.0
			var l := p + Vector2.from_angle(a + 2.4) * 18.0
			var r := p + Vector2.from_angle(a - 2.4) * 18.0
			draw_colored_polygon(PackedVector2Array([tip, l, r]), c)
			draw_polyline(PackedVector2Array([tip, l, r, tip]), Color(0, 0, 0, 0.6), 3.0, true)
