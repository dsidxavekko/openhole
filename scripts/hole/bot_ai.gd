class_name BotAI
extends RefCounted
## Simple state machine: flee bigger holes, sometimes chase smaller ones,
## otherwise go for the most valuable food (or a magnet) nearby, otherwise wander.

enum State { WANDER, FOOD, CHASE, FLEE }

const CHASE_LIMIT := 3.0
const CHASE_COOLDOWN := 5.0

var hole: Hole
var game: Node
var state: int = State.WANDER
var target := Vector3.ZERO
var skill := 0.7
var _timer := 0.0
var _age := 0.0
var _chase_time := 0.0
var _chase_cooldown := 0.0
## Seconds into the match before this bot starts hunting other holes.
var _no_chase_start := 15.0


func _init(p_hole: Hole, p_game: Node, p_skill: float, p_chase_start := 15.0) -> void:
	hole = p_hole
	game = p_game
	skill = p_skill
	_no_chase_start = p_chase_start
	target = hole.position


func update(delta: float) -> void:
	_age += delta
	_chase_cooldown -= delta
	if state == State.CHASE:
		_chase_time += delta
		if _chase_time > CHASE_LIMIT:
			# Give up for a while.
			_chase_cooldown = CHASE_COOLDOWN
			_chase_time = 0.0
			_timer = 0.0
	else:
		_chase_time = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.32, 0.6) / maxf(skill, 0.3)
		_decide()
	var to := target - hole.position
	var desired := Vector2(to.x, to.z)
	if desired.length() < 0.4:
		desired = Vector2.ZERO
		_timer = minf(_timer, 0.05)
	else:
		desired = desired.normalized()
	hole.move_dir = hole.move_dir.lerp(desired, clampf(delta * 4.0, 0.0, 1.0))


func _decide() -> void:
	var r := hole.radius
	var threat: Hole = game.find_threat(hole, 5.0 + r * 3.0 * skill)
	if threat:
		state = State.FLEE
		var away := hole.position - threat.position
		away.y = 0.0
		target = game.clamp_to_play_area(hole.position + away.normalized() * (12.0 + r * 2.0))
		return
	if _age > _no_chase_start and _chase_cooldown <= 0.0 and randf() < skill:
		var prey: Hole = game.find_prey(hole, 4.0 + r * 2.0)
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
