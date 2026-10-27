class_name EdibleFactory
extends RefCounted
## Builds Edible bodies from CityGen specs. Meshes and materials are shared
## (unit meshes scaled per object) to keep memory and draw state low.

const GROUND_LAYER := 1
const EDIBLE_LAYER := 2

var _materials := {}
var _shapes := {}
var _box := BoxMesh.new()
var _cyl := CylinderMesh.new()
var _sphere := SphereMesh.new()
var _capsule := CapsuleMesh.new()
var _prism := PrismMesh.new()


func _init() -> void:
	_box.size = Vector3.ONE
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 12
	_cyl.rings = 1
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 12
	_sphere.rings = 6
	_capsule.radius = 0.5
	_capsule.height = 2.0
	_capsule.radial_segments = 10
	_capsule.rings = 3
	_prism.size = Vector3.ONE


func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[key] = m
	return _materials[key]


func _box_shape(size: Vector3) -> BoxShape3D:
	var key := "%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if not _shapes.has(key):
		var s := BoxShape3D.new()
		s.size = size
		_shapes[key] = s
	return _shapes[key]


func _part(body: Node3D, mesh: Mesh, scale: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = scale
	mi.position = offset
	mi.material_override = material(color)
	body.add_child(mi)
	return mi


func build(spec: Dictionary) -> Edible:
	var kind: String = spec.k
	var s: Vector3 = spec.s
	var c: Color = spec.c
	var e := Edible.new()
	e.kind = kind
	e.extent = maxf(s.x, s.z)
	e.height = s.y
	e.points = HoleRules.points_for_size(s)
	e.mass = clampf(s.x * s.y * s.z * 25.0, 1.0, 4000.0)
	e.collision_layer = EDIBLE_LAYER
	e.collision_mask = GROUND_LAYER | EDIBLE_LAYER
	e.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	e.freeze = true
	e.position = spec.p + Vector3(0, s.y / 2.0, 0)
	e.rotation.y = spec.r

	var col := CollisionShape3D.new()
	col.shape = _box_shape(s)
	e.add_child(col)

	var vis_end := 0.0
	match kind:
		"person":
			_part(e, _capsule, Vector3(0.38, 0.33, 0.38), Vector3(0, -0.15, 0), c)
			_part(e, _sphere, Vector3.ONE * 0.36, Vector3(0, 0.62, 0), Color("f1c27d"))
			vis_end = 90.0
		"car":
			_part(e, _box, Vector3(s.x, s.y * 0.55, s.z), Vector3(0, -s.y * 0.2, 0), c)
			_part(e, _box, Vector3(s.x * 0.85, s.y * 0.45, s.z * 0.5), Vector3(0, s.y * 0.28, -s.z * 0.05), c.darkened(0.25))
		"bus":
			_part(e, _box, s, Vector3.ZERO, c)
			_part(e, _box, Vector3(s.x * 1.02, s.y * 0.25, s.z * 0.9), Vector3(0, s.y * 0.18, 0), Color("1d3557"))
		"building":
			_part(e, _box, s, Vector3.ZERO, c)
			_part(e, _box, Vector3(s.x * 1.04, 0.6, s.z * 1.04), Vector3(0, s.y / 2.0, 0), c.darkened(0.3))
		"house":
			_part(e, _box, Vector3(s.x, s.y * 0.65, s.z), Vector3(0, -s.y * 0.175, 0), c)
			_part(e, _prism, Vector3(s.x * 1.1, s.y * 0.35, s.z * 1.05), Vector3(0, s.y * 0.325, 0), Color("9d0208"))
		"tree":
			_part(e, _cyl, Vector3(0.35, s.y * 0.45, 0.35), Vector3(0, -s.y * 0.275, 0), Color("6f4518"))
			_part(e, _sphere, Vector3(s.x, s.y * 0.6, s.x), Vector3(0, s.y * 0.2, 0), c)
		"bush":
			_part(e, _sphere, s, Vector3.ZERO, c)
			vis_end = 90.0
		"lamp":
			_part(e, _cyl, s, Vector3.ZERO, c)
			_part(e, _sphere, Vector3.ONE * 0.5, Vector3(0, s.y / 2.0, 0), Color("fff3b0"))
		"hydrant", "trash", "cone":
			_part(e, _cyl, s, Vector3.ZERO, c)
			vis_end = 80.0
		_:
			_part(e, _box, s, Vector3.ZERO, c)
	if vis_end > 0.0:
		for child in e.get_children():
			if child is MeshInstance3D:
				child.visibility_range_end = vis_end
	return e
