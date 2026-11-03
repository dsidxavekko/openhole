class_name Hole
extends Node3D
## A hole: moves on the ground, grows by levels. Things that fall into it stop
## colliding with the ground and drop through (see Game._start_fall).

signal leveled_up(level: int)

const WELL_DEPTH := 10.0
const WELL_SHADER := preload("res://scripts/hole/well.gdshader")
const COMBO_WINDOW := 1.0

var hole_name := ""
var color := Color.WHITE
var is_player := false
var points := 0
var level := 1
var radius := HoleRules.BASE_RADIUS
var target_radius := HoleRules.BASE_RADIUS
var move_dir := Vector2.ZERO
var alive := true
var respawn_timer := 0.0
var out_of_zone := 0.0
## Active power-ups: Powerup.Kind -> seconds left.
var effects := {}
var powerups_taken := 0
## Seconds until Shift is ready again (counts down only while not shifted).
var shift_cooldown := 0.0
var shifts_used := 0
var holes_eaten_shifted := 0
## Seconds left of a quick resize (Shift start and end are near-instant).
var _fast_resize := 0.0
## Rim pattern id for the ground shader (Skins.Pattern).
var pattern := 0
## Eating streak: things eaten less than COMBO_WINDOW apart.
var combo := 0
var _combo_timer := 0.0
var controller: RefCounted = null

var _well_mesh: MeshInstance3D
var _label: Label3D
var _ring: MeshInstance3D
## Second, outer ring shown only while shifted.
var _ring2: MeshInstance3D


func setup(p_name: String, p_color: Color, p_player: bool, p_pattern := 0) -> void:
	hole_name = p_name
	color = p_color
	is_player = p_player
	pattern = p_pattern


func _ready() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 40
	cyl.rings = 1
	cyl.cap_top = false
	var mat := ShaderMaterial.new()
	mat.shader = WELL_SHADER
	_well_mesh = MeshInstance3D.new()
	_well_mesh.mesh = cyl
	_well_mesh.material_override = mat
	_well_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_well_mesh)

	_label = Label3D.new()
	_label.text = hole_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 64
	_label.outline_size = 16
	_label.modulate = color.lightened(0.3)
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	add_child(_label)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(color, 0.55)
	ring_mat.no_depth_test = true
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_ring2 = MeshInstance3D.new()
	_ring2.mesh = torus
	_ring2.material_override = ring_mat.duplicate()
	_ring2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring2.visible = false
	add_child(_ring2)
	_apply_radius()


func set_points(p: int) -> void:
	points = p
	level = HoleRules.level_for_points(points)
	target_radius = _wanted_radius()


func add_points(p: int) -> void:
	points += p
	var nl := HoleRules.level_for_points(points)
	if nl != level:
		level = nl
		target_radius = _wanted_radius()
		leveled_up.emit(level)


## Points for eating something worth `p`, with the streak bonus.
func combo_points(p: int) -> int:
	combo = combo + 1 if _combo_timer > 0.0 else 1
	_combo_timer = COMBO_WINDOW
	return int(round(p * HoleRules.combo_multiplier(combo)))


## Points with the current streak bonus, without growing the streak.
func streak_points(p: int) -> int:
	if _combo_timer > 0.0:
		_combo_timer = COMBO_WINDOW
	return int(round(p * HoleRules.combo_multiplier(combo)))


## Radius without Shift (Giant included).
func _base_radius() -> float:
	return HoleRules.radius_for_level(level + (Powerup.GROW_LEVELS if has_effect(Powerup.Kind.GROW) else 0))


func _wanted_radius() -> float:
	var r := _base_radius()
	return HoleRules.shifted_radius(r) if is_shifted() else r


func speed() -> float:
	if is_shifted():
		# Based on the normal size, so shrinking does not slow the hole down.
		return HoleRules.shifted_speed(7.0 + _base_radius() * 0.45)
	var s := 7.0 + radius * 0.45
	return s * Powerup.SPEED_FACTOR if has_effect(Powerup.Kind.SPEED) else s


func step(delta: float, bound: float) -> void:
	var dir := move_dir.limit_length(1.0)
	position.x = clampf(position.x + dir.x * speed() * delta, -bound, bound)
	position.z = clampf(position.z + dir.y * speed() * delta, -bound, bound)
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
	if shift_cooldown > 0.0 and not is_shifted():
		shift_cooldown -= delta
	if not effects.is_empty():
		var shifted := is_shifted()
		for k in effects.keys():
			# Shift pauses the other power-ups: their time stands still.
			if shifted and k != Powerup.Kind.SHIFT:
				continue
			effects[k] -= delta
			if effects[k] <= 0.0:
				effects.erase(k)
				if k == Powerup.Kind.SHIFT:
					shift_cooldown = HoleRules.SHIFT_COOLDOWN
					_fast_resize = 0.25
		target_radius = _wanted_radius()
		_update_ring()
	if not is_equal_approx(radius, target_radius):
		var rate := maxf(1.0, target_radius * 0.8)
		if _fast_resize > 0.0:
			_fast_resize -= delta
			rate = maxf(rate, absf(radius - target_radius) / maxf(_fast_resize, delta))
		radius = move_toward(radius, target_radius, delta * rate)
		_apply_radius()


## Ring around the hole showing the strongest active power-up.
func _update_ring() -> void:
	_ring.visible = not effects.is_empty()
	_ring2.visible = _ring.visible and is_shifted()
	if not _ring.visible:
		return
	var kind := -1
	for k in [Powerup.Kind.SHIFT, Powerup.Kind.SHIELD, Powerup.Kind.GROW, Powerup.Kind.SPEED, Powerup.Kind.MAGNET]:
		if has_effect(k):
			kind = k
			break
	var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.012)
	var rr := (magnet_radius() if kind == Powerup.Kind.MAGNET else radius + 0.5) * pulse
	_ring.scale = Vector3(rr, rr * 0.4, rr)
	_ring.position.y = 0.15
	var mat := _ring.material_override as StandardMaterial3D
	var c: Color = Powerup.COLORS[kind]
	# Blink during the last two seconds (the short Shift: the last 0.7 s).
	var warn := 0.7 if kind == Powerup.Kind.SHIFT else 2.0
	var a := 0.6 if effects[kind] > warn or int(effects[kind] * 6.0) % 2 == 0 else 0.15
	mat.albedo_color = Color(c, a)
	if _ring2.visible:
		# Outer ring pulses outwards, out of phase with the inner one.
		var t := fposmod(Time.get_ticks_msec() * 0.0025, 1.0)
		var r2 := (radius + 0.8) * (1.15 + t * 0.6)
		_ring2.scale = Vector3(r2, r2 * 0.4, r2)
		_ring2.position.y = 0.15
		(_ring2.material_override as StandardMaterial3D).albedo_color = Color(c, 0.7 * (1.0 - t))


func has_effect(kind: int) -> bool:
	# While shifted, the other power-ups are paused and do nothing.
	if kind != Powerup.Kind.SHIFT and is_shifted():
		return false
	return effects.get(kind, 0.0) > 0.0


func is_shifted() -> bool:
	return effects.get(Powerup.Kind.SHIFT, 0.0) > 0.0


func shift_ready() -> bool:
	return alive and not is_shifted() and shift_cooldown <= 0.0 and HoleRules.can_be_shifted(level)


## Starts the Shift role swap. Returns false when it is not ready.
func start_shift() -> bool:
	if not shift_ready():
		return false
	effects[Powerup.Kind.SHIFT] = Powerup.DURATIONS[Powerup.Kind.SHIFT]
	shifts_used += 1
	_fast_resize = 0.25
	target_radius = _wanted_radius()
	_update_ring()
	return true


## Shielded and shifted holes cannot be eaten.
func can_be_eaten() -> bool:
	return not has_effect(Powerup.Kind.SHIELD) and not is_shifted()


func give_effect(kind: int, seconds: float) -> void:
	effects[kind] = seconds
	powerups_taken += 1
	target_radius = _wanted_radius()
	_update_ring()


## Weak permanent pull, much stronger while a magnet bonus is active.
## The reach beyond the rim is capped: a level-16 hole would otherwise scan
## half the map every tick.
func magnet_radius() -> float:
	if has_effect(Powerup.Kind.MAGNET):
		return radius + minf(radius * 1.5 + 8.0, 20.0)
	return radius + minf(radius * 0.6 + 1.5, 8.0)


func magnet_strength() -> float:
	return 18.0 if has_effect(Powerup.Kind.MAGNET) else 6.0


## How far past the rim a falling thing still counts as "in this hole".
func lip_width() -> float:
	return radius * 2.0 + 2.0


func snap_radius() -> void:
	target_radius = _wanted_radius()
	radius = target_radius
	_apply_radius()


func set_alive(value: bool) -> void:
	alive = value
	visible = value
	# Shift is ready again after a respawn.
	shift_cooldown = 0.0
	if not value:
		effects.clear()
		combo = 0
		_ring.visible = false
		_ring2.visible = false


func _apply_radius() -> void:
	_well_mesh.scale = Vector3(radius * 2.0, WELL_DEPTH, radius * 2.0)
	_well_mesh.position.y = -WELL_DEPTH / 2.0 - 0.01
	_label.position = Vector3(0, 1.2 + radius * 0.4, 0)
	_label.pixel_size = 0.006 * (1.0 + radius * 0.35)
