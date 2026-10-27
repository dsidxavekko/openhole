class_name FloatingJoystick
extends Control
## Touch anywhere and drag. The base stays where the finger first touched;
## the knob is clamped to the base circle.
## Mouse works too via "emulate touch from mouse".

var vector := Vector2.ZERO
var enabled := true
var max_dist := 90.0

var _touch := -1
var _origin := Vector2.ZERO
var _pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func release() -> void:
	_touch = -1
	vector = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled:
		if _touch != -1:
			release()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_origin = event.position
			_pos = _origin
			vector = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == _touch:
			release()
	elif event is InputEventScreenDrag and event.index == _touch:
		var d: Vector2 = (event.position - _origin).limit_length(max_dist)
		_pos = _origin + d
		vector = d / max_dist
		if vector.length() < 0.12:
			vector = Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	if _touch == -1:
		return
	draw_circle(_origin, max_dist, Color(1, 1, 1, 0.12))
	draw_arc(_origin, max_dist, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_pos, 34.0, Color(1, 1, 1, 0.55))
