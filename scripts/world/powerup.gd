class_name Powerup
extends Node3D
## Floating power-up icon. Picked up by any hole passing over it.

## SHIFT is the player's Shift button, never spawned on the map (no weight).
enum Kind { MAGNET, SPEED, GROW, SHIELD, SHIFT, TIME, FREEZE }

const DURATIONS := {Kind.MAGNET: 8.0, Kind.SPEED: 6.0, Kind.GROW: 8.0, Kind.SHIELD: 8.0,
	Kind.SHIFT: 3.5}
const COLORS := {Kind.MAGNET: Color("e63946"), Kind.SPEED: Color("ffd60a"),
	Kind.GROW: Color("38b000"), Kind.SHIELD: Color("4cc9f0"), Kind.SHIFT: Color("e0aaff"),
	Kind.TIME: Color("ffb703"), Kind.FREEZE: Color("a8dadc")}
const NAMES := {Kind.MAGNET: "PU_MAGNET", Kind.SPEED: "PU_SPEED", Kind.GROW: "PU_GROW",
	Kind.SHIELD: "PU_SHIELD", Kind.SHIFT: "PU_SHIFT", Kind.TIME: "PU_TIME", Kind.FREEZE: "PU_FREEZE"}
## Spawn weights; the shield is useless alone, so Solo never spawns it.
const WEIGHTS := {Kind.MAGNET: 35, Kind.SPEED: 25, Kind.GROW: 20, Kind.SHIELD: 20,
	Kind.TIME: 10, Kind.FREEZE: 12}
## Instant bonuses act once when the player takes them (bots never do).
const TIME_BONUS := 10.0
const FREEZE_SECONDS := 3.0
const SPEED_FACTOR := 1.5
const GROW_LEVELS := 2

var kind: int = Kind.MAGNET
var _t := randf() * TAU
var _box := BoxMesh.new()


static func is_instant(kind: int) -> bool:
	return kind == Kind.TIME or kind == Kind.FREEZE


## Whether `kind` may spawn: the shield and the freeze need rivals, and extra
## time would stretch the Battle zone schedule, so Battle has none.
static func can_spawn(kind: int, rivals: bool, timed: bool) -> bool:
	if kind == Kind.SHIELD or kind == Kind.FREEZE:
		return rivals
	if kind == Kind.TIME:
		return timed
	return true


static func random_kind(rivals: bool, timed: bool) -> int:
	var total := 0
	for k in WEIGHTS:
		if can_spawn(k, rivals, timed):
			total += WEIGHTS[k]
	var r := randi() % total
	for k in WEIGHTS:
		if not can_spawn(k, rivals, timed):
			continue
		r -= WEIGHTS[k]
		if r < 0:
			return k
	return Kind.MAGNET


func _ready() -> void:
	var main := _mat(COLORS[kind], 0.45)
	var white := _mat(Color("f1faee"), 0.0)
	_box.size = Vector3.ONE
	match kind:
		Kind.MAGNET:
			# U shape: bottom bar and two arms with white tips.
			_part(_box, main, Vector3(1.6, 0.4, 0.4), Vector3(0, -0.6, 0))
			_part(_box, main, Vector3(0.4, 1.1, 0.4), Vector3(-0.6, 0.1, 0))
			_part(_box, main, Vector3(0.4, 1.1, 0.4), Vector3(0.6, 0.1, 0))
			_part(_box, white, Vector3(0.42, 0.35, 0.42), Vector3(-0.6, 0.75, 0))
			_part(_box, white, Vector3(0.42, 0.35, 0.42), Vector3(0.6, 0.75, 0))
		Kind.SPEED:
			# Lightning bolt: two slanted bars with an offset.
			_part(_box, main, Vector3(0.35, 1.0, 0.35), Vector3(0.15, 0.45, 0), Vector3(0, 0, 0.45))
			_part(_box, main, Vector3(0.9, 0.3, 0.35), Vector3(0, 0, 0))
			_part(_box, main, Vector3(0.35, 1.0, 0.35), Vector3(-0.15, -0.45, 0), Vector3(0, 0, 0.45))
		Kind.GROW:
			# Up arrow: shaft and a cone head.
			_part(_box, main, Vector3(0.45, 0.9, 0.45), Vector3(0, -0.4, 0))
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.75
			cone.height = 0.8
			cone.radial_segments = 4
			_part(cone, main, Vector3.ONE, Vector3(0, 0.45, 0), Vector3(0, PI / 4.0, 0))
		Kind.SHIELD:
			# Round shield facing sideways with a white cross.
			var disc := CylinderMesh.new()
			disc.top_radius = 0.8
			disc.bottom_radius = 0.8
			disc.height = 0.25
			disc.radial_segments = 20
			_part(disc, main, Vector3.ONE, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
			_part(_box, white, Vector3(0.22, 1.0, 0.3), Vector3.ZERO)
			_part(_box, white, Vector3(1.0, 0.22, 0.3), Vector3(0, 0.1, 0))
		Kind.TIME:
			# Clock face with two hands.
			var face := CylinderMesh.new()
			face.top_radius = 0.8
			face.bottom_radius = 0.8
			face.height = 0.25
			face.radial_segments = 20
			_part(face, main, Vector3.ONE, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
			_part(_box, white, Vector3(0.16, 0.65, 0.3), Vector3(0, 0.25, 0))
			_part(_box, white, Vector3(0.5, 0.16, 0.3), Vector3(0.22, 0, 0))
		Kind.FREEZE:
			# Snowflake: three crossed bars.
			for ang in [0.0, PI / 3.0, -PI / 3.0]:
				_part(_box, main, Vector3(0.22, 1.7, 0.22), Vector3.ZERO, Vector3(0, 0, ang))
			_part(_box, white, Vector3(0.4, 0.4, 0.4), Vector3.ZERO)


func _mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _part(mesh: Mesh, mat: Material, sc: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = sc
	mi.position = pos
	mi.rotation = rot
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	rotation.y = _t * 1.8
	position.y = 1.6 + sin(_t * 3.0) * 0.3
