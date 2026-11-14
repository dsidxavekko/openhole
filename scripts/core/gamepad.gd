class_name Gamepad
extends RefCounted
## Gamepad and keyboard bindings added to the input map from code, plus the
## left-stick movement vector. Menu navigation uses Godot's built-in `ui_*`
## actions, which already include the D-pad, the left stick and the A button.

const DEADZONE := 0.25


## Adds the joypad events to `shift_button` and creates `pause_button`.
## Safe to call more than once.
static func setup_actions() -> void:
	_bind("shift_button", [_button(JOY_BUTTON_X), _button(JOY_BUTTON_RIGHT_SHOULDER), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	if not InputMap.has_action("pause_button"):
		InputMap.add_action("pause_button", 0.5)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	var pkey := InputEventKey.new()
	pkey.physical_keycode = KEY_P
	_bind("pause_button", [esc, pkey, _button(JOY_BUTTON_START)])


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


static func _bind(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for e: InputEvent in events:
		var present := false
		for old in InputMap.action_get_events(action):
			if old.is_match(e, true):
				present = true
				break
		if not present:
			InputMap.action_add_event(action, e)


## Radial dead zone that rescales so the output still reaches 1 at full tilt.
static func apply_deadzone(v: Vector2, deadzone := DEADZONE) -> Vector2:
	var mag := v.length()
	if mag <= deadzone:
		return Vector2.ZERO
	return v.normalized() * minf((mag - deadzone) / (1.0 - deadzone), 1.0)


## Left stick (or D-pad) of any connected pad; zero when nothing is pushed.
static func move_vector() -> Vector2:
	var best := Vector2.ZERO
	for id in Input.get_connected_joypads():
		var v := apply_deadzone(Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X), Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)))
		var pad := Vector2(
			float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP)))
		if pad != Vector2.ZERO:
			v = pad.normalized()
		if v.length() > best.length():
			best = v
	return best
