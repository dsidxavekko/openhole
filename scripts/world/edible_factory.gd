class_name EdibleFactory
extends RefCounted
## Builds Edible bodies from CityGen specs. Uses Kenney models when the kind has
## one (see ModelLibrary), otherwise simple shared primitives. Collider size,
## extent and points come from the real (scaled) model size.

const GROUND_LAYER := 1
const EDIBLE_LAYER := 2
const SMALL_VIS_RANGE := 70.0

var library := ModelLibrary.new()
var _materials := {}
var _shapes := {}
var _box := BoxMesh.new()
var _cyl := CylinderMesh.new()
var _sphere := SphereMesh.new()


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


func _part(body: Node3D, mesh: Mesh, scale: Vector3, offset: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = scale
	mi.position = offset
	mi.material_override = material(color)
	body.add_child(mi)


func build(spec: Dictionary) -> Edible:
	var kind: String = spec.k
	var s: Vector3 = spec.s
	var e := Edible.new()
	e.kind = kind

	var model_kind := kind
	if kind == "building" and s.y > 26.0:
		model_kind = "skyscraper"
	var size := s
	if library.has_kind(model_kind):
		size = _add_model(e, model_kind, kind, s, spec.p)
	else:
		_add_primitive(e, kind, s, spec.c)

	e.extent = maxf(size.x, size.z)
	e.height = size.y
	e.points = HoleRules.points_for_size(size)
	e.mass = clampf(size.x * size.y * size.z * 25.0, 1.0, 4000.0)
	e.collision_layer = EDIBLE_LAYER
	e.collision_mask = GROUND_LAYER | EDIBLE_LAYER
	e.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	e.freeze = true
	e.position = spec.p + Vector3(0, size.y / 2.0, 0)
	e.rotation.y = spec.r
	var col := CollisionShape3D.new()
	col.shape = _box_shape(size)
	e.add_child(col)

	if e.extent < 1.0 and size.y < 2.5:
		_make_cheap(e)
	return e


## Adds the model under `e`, centred on the body origin. Returns the real size.
func _add_model(e: Edible, model_kind: String, kind: String, s: Vector3, p: Vector3) -> Vector3:
	var info := library.pick(model_kind, p)
	var a: AABB = info.aabb
	var rot90 := false
	var sc := Vector3.ONE
	if kind in ModelLibrary.FIT_HEIGHT:
		sc = Vector3.ONE * (s.y / a.size.y)
	else:
		# Line up the longest horizontal sides of the model and the spec.
		if absf(s.x - s.z) > 0.3 and (a.size.x > a.size.z) != (s.x > s.z):
			rot90 = true
		var ax := a.size.z if rot90 else a.size.x
		var az := a.size.x if rot90 else a.size.z
		var k := minf(s.x / ax, s.z / az)
		sc = Vector3(k, k, k)
		if kind == "building":
			sc.y = k * clampf(s.y / (a.size.y * k), 0.75, 1.6)

	var holder := Node3D.new()
	holder.rotation.y = PI / 2.0 if rot90 else 0.0
	holder.scale = sc
	e.add_child(holder)
	var inst: Node3D = info.scene.instantiate()
	inst.position = -a.get_center()
	holder.add_child(inst)
	if kind == "person":
		_pose_idle(inst)

	var size := Vector3(a.size.x * sc.x, a.size.y * sc.y, a.size.z * sc.z)
	if rot90:
		size = Vector3(size.z, size.y, size.x)
	if kind == "person":
		# The bind pose has arms out; the collider should match the idle body.
		size.x = 0.55
		size.z = 0.55
	return size


## Characters come with 30+ animations: freeze them in the idle pose and drop the player.
func _pose_idle(n: Node) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	if ap.has_animation("idle"):
		ap.play("idle")
		ap.seek(0.0, true)
		ap.advance(0.0)
	ap.stop(true)
	ap.get_parent().remove_child(ap)
	ap.free()


func _make_cheap(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.visibility_range_end = SMALL_VIS_RANGE
		_make_cheap(c)


func _add_primitive(e: Edible, kind: String, s: Vector3, c: Color) -> void:
	match kind:
		"mailbox":
			_part(e, _cyl, Vector3(0.12, s.y * 0.7, 0.12), Vector3(0, -s.y * 0.15, 0), Color("495057"))
			_part(e, _box, Vector3(s.x, s.y * 0.3, s.z), Vector3(0, s.y * 0.35, 0), c)
		"bike":
			_part(e, _cyl, Vector3(s.y * 0.6, 0.06, s.y * 0.6), Vector3(0, -s.y * 0.2, s.z * 0.3), Color("222222"))
			_part(e, _cyl, Vector3(s.y * 0.6, 0.06, s.y * 0.6), Vector3(0, -s.y * 0.2, -s.z * 0.3), Color("222222"))
			_part(e, _box, Vector3(0.08, 0.08, s.z * 0.7), Vector3(0, s.y * 0.1, 0), c)
			for w in e.get_children():
				if w is MeshInstance3D and w.scale.y < 0.1:
					w.rotation.z = PI / 2.0
		_:
			# hydrant, trash and anything else round.
			_part(e, _cyl, s, Vector3.ZERO, c)
