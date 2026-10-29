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
## Rim pattern id for the ground shader (Skins.Pattern).
var pattern := 0
## Eating streak: things eaten less than COMBO_WINDOW apart.
var combo := 0
var _combo_timer := 0.0
var controller: RefCounted = null

var _well_mesh: MeshInstance3D
var _label: Label3D
var _ring: MeshInstance3D


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


func _wanted_radius() -> float:
	return HoleRules.radius_for_level(level + (Powerup.GROW_LEVELS if has_effect(Powerup.Kind.GROW) else 0))


func speed() -> float:
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
	if not effects.is_empty():
		for k in effects.keys():
			effects[k] -= delta
			if effects[k] <= 0.0:
				effects.erase(k)
		target_radius = _wanted_radius()
		_update_ring()
	if not is_equal_approx(radius, target_radius):
		radius = move_toward(radius, target_radius, delta * maxf(1.0, target_radius * 0.8))
		_apply_radius()


## Ring around the hole showing the strongest active power-up.
func _update_ring() -> void:
	_ring.visible = not effects.is_empty()
	if not _ring.visible:
		return
	var kind := -1
	for k in [Powerup.Kind.SHIELD, Powerup.Kind.GROW, Powerup.Kind.SPEED, Powerup.Kind.MAGNET]:
		if has_effect(k):
			kind = k
			break
	var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.012)
	var rr := (magnet_radius() if kind == Powerup.Kind.MAGNET else radius + 0.5) * pulse
	_ring.scale = Vector3(rr, rr * 0.4, rr)
	_ring.position.y = 0.15
	var mat := _ring.material_override as StandardMaterial3D
	var c: Color = Powerup.COLORS[kind]
	# Blink during the last two seconds.
	var a := 0.6 if effects[kind] > 2.0 or int(effects[kind] * 6.0) % 2 == 0 else 0.15
	mat.albedo_color = Color(c, a)


func has_effect(kind: int) -> bool:
	return effects.get(kind, 0.0) > 0.0


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
	if not value:
		effects.clear()
		combo = 0
		_ring.visible = false


func _apply_radius() -> void:
	_well_mesh.scale = Vector3(radius * 2.0, WELL_DEPTH, radius * 2.0)
	_well_mesh.position.y = -WELL_DEPTH / 2.0 - 0.01
	_label.position = Vector3(0, 1.2 + radius * 0.4, 0)
	_label.pixel_size = 0.006 * (1.0 + radius * 0.35)
