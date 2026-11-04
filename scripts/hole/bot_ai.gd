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
## Seconds left standing still in surprise (the player just shifted nearby).
var _frozen := 0.0
## Hole this bot is diving into while shifted (hard bots only).
var _shift_target: Hole = null
## Hard bots may spend their Shift.
var allow_shift := false


func _init(p_hole: Hole, p_game: Node, p_skill: float, p_chase_start := 15.0,
		p_allow_shift := false) -> void:
	hole = p_hole
	game = p_game
	skill = p_skill
	_no_chase_start = p_chase_start
	allow_shift = p_allow_shift
	target = hole.position


## Stand still for `seconds`, then decide again right away (usually: flee).
func freeze(seconds: float) -> void:
	_frozen = maxf(_frozen, seconds)
	_timer = 0.0


func is_frozen() -> bool:
	return _frozen > 0.0


func update(delta: float) -> void:
	if _frozen > 0.0:
		_frozen -= delta
		hole.move_dir = hole.move_dir.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))
		return
	_age += delta
	_chase_cooldown -= delta
	if allow_shift:
		_maybe_shift()
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
	if hole.is_shifted() and is_instance_valid(_shift_target) and _shift_target.alive:
		# Committed to the dive: run at the victim while the shift lasts.
		state = State.CHASE
		target = _shift_target.position
		return
	_shift_target = null
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


## Hard bots shift too: slip away from a bigger hole, or dive into one head-first.
func _maybe_shift() -> void:
	if not hole.shift_ready():
		return
	# Escape: something that could eat us is right here.
	var threat: Hole = game.find_threat(hole, HoleRules.shift_escape_reach(hole.radius))
	if threat and randf() < skill:
		hole.start_shift()
		game.bot_shifted(hole)
		return
	if _age <= _no_chase_start or _chase_cooldown > 0.0:
		return
	# Assassinate: the closest hole that is too big to eat the usual way.
	var victim: Hole = null
	var best_d := INF
	for o in game.holes:
		if o == hole or not o.alive:
			continue
		var d: float = o.position.distance_to(hole.position)
		if o.can_be_eaten() and HoleRules.can_shift_dive(hole.radius, o.radius, d) and d < best_d:
			best_d = d
			victim = o
	if victim and randf() < skill * 0.7:
		_shift_target = victim
		hole.start_shift()
		game.bot_shifted(hole)
