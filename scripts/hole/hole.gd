class_name Hole
extends Node3D
## A hole: moves on the ground, grows by levels, has a physical "well"
## (ring of wall colliders) that falling objects tumble into.

signal leveled_up(level: int)

const WELL_LAYER := 4
const SEGMENTS := 20
const LIP_SEGMENTS := 24
const WELL_DEPTH := 10.0
const WELL_SHADER := preload("res://scripts/hole/well.gdshader")

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
var magnet_time := 0.0
var magnets_taken := 0
var controller: RefCounted = null

var _well_body: AnimatableBody3D
var _segments: Array[CollisionShape3D] = []
var _lip: Array[CollisionShape3D] = []
var _well_mesh: MeshInstance3D
var _label: Label3D
var _shape_radius := -1.0
var _ring: MeshInstance3D


func setup(p_name: String, p_color: Color, p_player: bool) -> void:
	hole_name = p_name
	color = p_color
	is_player = p_player


func _ready() -> void:
	_well_body = AnimatableBody3D.new()
	_well_body.sync_to_physics = true
	_well_body.collision_layer = WELL_LAYER
	_well_body.collision_mask = 0
	add_child(_well_body)
	for i in SEGMENTS:
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		_well_body.add_child(cs)
		_segments.append(cs)
	# The "lip": solid ground around the hole that only falling objects collide with,
	# so they rest on it and tip over the edge instead of dropping straight down.
	for i in LIP_SEGMENTS:
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		_well_body.add_child(cs)
		_lip.append(cs)

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
	target_radius = HoleRules.radius_for_level(level)


func add_points(p: int) -> void:
	points += p
	var nl := HoleRules.level_for_points(points)
	if nl != level:
		level = nl
		target_radius = HoleRules.radius_for_level(level)
		leveled_up.emit(level)


func speed() -> float:
	return 7.0 + radius * 0.45


func step(delta: float, bound: float) -> void:
	var dir := move_dir.limit_length(1.0)
	position.x = clampf(position.x + dir.x * speed() * delta, -bound, bound)
	position.z = clampf(position.z + dir.y * speed() * delta, -bound, bound)
	if magnet_time > 0.0:
		magnet_time -= delta
		var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		var rr := magnet_radius() * pulse
		_ring.scale = Vector3(rr, rr * 0.4, rr)
		_ring.position.y = 0.15
		_ring.visible = magnet_time > 0.0
	if not is_equal_approx(radius, target_radius):
		radius = move_toward(radius, target_radius, delta * maxf(1.0, target_radius * 0.8))
		_apply_radius()


## Weak permanent pull, much stronger while a magnet bonus is active.
func magnet_radius() -> float:
	return radius * 2.5 + 8.0 if magnet_time > 0.0 else radius * 1.6 + 1.5


func magnet_strength() -> float:
	return 18.0 if magnet_time > 0.0 else 6.0


func give_magnet(seconds: float) -> void:
	magnet_time = seconds
	magnets_taken += 1


func lip_width() -> float:
	return radius * 2.0 + 2.0


func snap_radius() -> void:
	radius = target_radius
	_apply_radius()


func set_alive(value: bool) -> void:
	alive = value
	visible = value
	if not value:
		magnet_time = 0.0
		_ring.visible = false
	_well_body.collision_layer = WELL_LAYER if value else 0


func _apply_radius() -> void:
	_well_mesh.scale = Vector3(radius * 2.0, WELL_DEPTH, radius * 2.0)
	_well_mesh.position.y = -WELL_DEPTH / 2.0 - 0.01
	_label.position = Vector3(0, 1.2 + radius * 0.4, 0)
	_label.pixel_size = 0.006 * (1.0 + radius * 0.35)
	# Rebuilding wall colliders is cheap but not free: only when size changed enough.
	if absf(radius - _shape_radius) < 0.05:
		return
	_shape_radius = radius
	var thickness := 0.6
	var ring_r := radius + thickness / 2.0
	var seg_w := TAU * ring_r / SEGMENTS * 1.15
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var cs := _segments[i]
		(cs.shape as BoxShape3D).size = Vector3(seg_w, WELL_DEPTH, thickness)
		cs.position = Vector3(sin(a) * ring_r, -WELL_DEPTH / 2.0, cos(a) * ring_r)
		cs.rotation = Vector3(0, a, 0)
	var lw := lip_width()
	var mid := radius + lw / 2.0
	var outer := radius + lw
	var lip_w := TAU * outer / LIP_SEGMENTS * 1.05
	for i in LIP_SEGMENTS:
		var a := TAU * (i + 0.5) / LIP_SEGMENTS
		var cs := _lip[i]
		(cs.shape as BoxShape3D).size = Vector3(lip_w, 0.5, lw)
		cs.position = Vector3(sin(a) * mid, -0.25, cos(a) * mid)
		cs.rotation = Vector3(0, a, 0)
