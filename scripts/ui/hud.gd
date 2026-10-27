class_name Hud
extends CanvasLayer
## In-game overlay: timer, level bar, leaderboard, notices and results panel.

signal play_again
signal to_menu

var joystick: FloatingJoystick
var _timer_label: Label
var _level_label: Label
var _level_bar: ProgressBar
var _board: VBoxContainer
var _info_label: Label
var _notice: Label
var _results: PanelContainer
var _results_box: VBoxContainer
var _notice_time := 0.0
var _fps: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)

	joystick = FloatingJoystick.new()
	root.add_child(joystick)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-160, 24)
	top.custom_minimum_size = Vector2(320, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_timer_label = _label(54, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_timer_label)
	_level_label = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_level_label)
	_level_bar = ProgressBar.new()
	_level_bar.custom_minimum_size = Vector2(320, 18)
	_level_bar.show_percentage = false
	_level_bar.max_value = 1.0
	_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_level_bar)

	_board = VBoxContainer.new()
	_board.position = Vector2(16, 170)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_board)

	_info_label = _label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	_info_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_label.position = Vector2(-260, 170)
	_info_label.custom_minimum_size = Vector2(244, 0)
	root.add_child(_info_label)

	_notice = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_notice.set_anchors_preset(Control.PRESET_CENTER)
	_notice.position = Vector2(-340, -200)
	_notice.custom_minimum_size = Vector2(680, 0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_notice)

	_fps = _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps.position = Vector2(12, -36)
	_fps.modulate = Color(1, 1, 1, 0.6)
	root.add_child(_fps)

	_results = PanelContainer.new()
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.custom_minimum_size = Vector2(560, 0)
	_results.position = Vector2(-280, -300)
	_results.visible = false
	root.add_child(_results)
	_results_box = VBoxContainer.new()
	_results_box.add_theme_constant_override("separation", 18)
	_results.add_child(_results_box)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
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


func set_info(text: String) -> void:
	_info_label.text = text


func set_board(rows: Array) -> void:
	# rows: [{name, points, color, me}]
	for c in _board.get_children():
		c.queue_free()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var l := _label(26, HORIZONTAL_ALIGNMENT_LEFT)
		l.text = "%d. %s  %d" % [r.place, r.name, r.points]
		l.modulate = (r.color as Color).lightened(0.35)
		if r.me:
			l.add_theme_font_size_override("font_size", 30)
		_board.add_child(l)


func notice(text: String, seconds := 2.5) -> void:
	_notice.text = text
	_notice_time = seconds


func show_results(title: String, lines: Array) -> void:
	joystick.enabled = false
	_notice.text = ""
	for c in _results_box.get_children():
		c.queue_free()
	var t := _label(48, HORIZONTAL_ALIGNMENT_CENTER)
	t.text = title
	_results_box.add_child(t)
	for line in lines:
		var l := _label(30, HORIZONTAL_ALIGNMENT_CENTER)
		l.text = line
		_results_box.add_child(l)
	var again := Button.new()
	again.text = tr("PLAY_AGAIN")
	again.pressed.connect(func(): play_again.emit())
	_results_box.add_child(again)
	var menu := Button.new()
	menu.text = tr("MENU")
	menu.pressed.connect(func(): to_menu.emit())
	_results_box.add_child(menu)
	_results.visible = true
