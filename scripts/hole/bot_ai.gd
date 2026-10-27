class_name BotAI
extends RefCounted
## Simple state machine: flee bigger holes, chase smaller ones,
## otherwise go for the most valuable food nearby, otherwise wander.

enum State { WANDER, FOOD, CHASE, FLEE }

var hole: Hole
var game: Node
var state: int = State.WANDER
var target := Vector3.ZERO
var skill := 0.7
var _timer := 0.0


func _init(p_hole: Hole, p_game: Node, p_skill: float) -> void:
	hole = p_hole
	game = p_game
	skill = p_skill
	target = hole.position


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.25, 0.45) / maxf(skill, 0.3)
		_decide()
	var to := target - hole.position
	var desired := Vector2(to.x, to.z)
	if desired.length() < 0.4:
		desired = Vector2.ZERO
		_timer = minf(_timer, 0.05)
	else:
		desired = desired.normalized()
	hole.move_dir = hole.move_dir.lerp(desired, clampf(delta * 6.0, 0.0, 1.0))


func _decide() -> void:
	var r := hole.radius
	var threat: Hole = game.find_threat(hole, 5.0 + r * 3.0 * skill)
	if threat:
		state = State.FLEE
		var away := hole.position - threat.position
		away.y = 0.0
		target = game.clamp_to_play_area(hole.position + away.normalized() * (12.0 + r * 2.0))
		return
	if randf() < skill:
		var prey: Hole = game.find_prey(hole, 6.0 + r * 3.0)
		if prey:
			state = State.CHASE
			target = prey.position
			return
	var food: Variant = game.find_food(hole, 10.0 + r * 2.5)
	if food != null:
		state = State.FOOD
		target = food
		return
	if state != State.WANDER or hole.position.distance_to(target) < 2.0:
		state = State.WANDER
		var a := randf() * TAU
		target = game.clamp_to_play_area(hole.position + Vector3(cos(a), 0, sin(a)) * 20.0)
