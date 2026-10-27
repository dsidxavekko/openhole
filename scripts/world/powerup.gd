class_name Powerup
extends Node3D
## Floating magnet icon. Picked up by any hole passing over it.

const DURATION := 8.0

var _t := randf() * TAU


func _ready() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("e63946")
	red.emission_enabled = true
	red.emission = Color("e63946")
	red.emission_energy_multiplier = 0.4
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f1faee")
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	# U shape: bottom bar and two arms with white tips.
	_part(box, red, Vector3(1.6, 0.4, 0.4), Vector3(0, -0.6, 0))
	_part(box, red, Vector3(0.4, 1.1, 0.4), Vector3(-0.6, 0.1, 0))
	_part(box, red, Vector3(0.4, 1.1, 0.4), Vector3(0.6, 0.1, 0))
	_part(box, white, Vector3(0.42, 0.35, 0.42), Vector3(-0.6, 0.75, 0))
	_part(box, white, Vector3(0.42, 0.35, 0.42), Vector3(0.6, 0.75, 0))


func _part(mesh: Mesh, mat: Material, sc: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = sc
	mi.position = pos
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	rotation.y = _t * 1.8
	position.y = 1.6 + sin(_t * 3.0) * 0.3
