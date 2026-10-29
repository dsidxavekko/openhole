class_name Demolition
extends Node
## Breaks buildings and other big things into chunks (cut by Fracture).
##  - collapse(): the whole thing fits the hole -> it falls apart into it.
##  - fracture(): the hole is too small for the whole thing but big enough for
##    a chunk -> it is swapped for frozen chunks in place; the hole swallows
##    the chunks above it, and chunks left without support fall after them.
## Chunks are ordinary Edibles of kind "debris" in the game's spatial grid.

const VARIANTS := 2
## Chunk hulls are shrunk a bit so neighbours do not start out overlapping
## (the physics would fling them apart).
const SHRINK := 0.88
## Live (unfrozen, awake) chunks; past this the farthest settled ones freeze.
const MAX_DEBRIS := 200
const CAP_COLOR := Color("9a948c")
const DUST_POOL := 6
const DUST_GAP := 0.3

const GROUND_LAYER := 1
const EDIBLE_LAYER := 2

var game: Node
var fractured := 0
var debris_peak := 0

var _models := {}       # model path -> Fracture.extract() result
var _raw := {}          # piece key -> Array of Fracture pieces (filled by workers)
var _built := {}        # piece key -> Array of {mesh, hull, centre, vol}
var _queued := {}       # piece key -> true
var _tasks: Array[int] = []
var _mutex := Mutex.new()
var _mats := {}         # source material id -> double-sided copy
var _cap_mat: StandardMaterial3D
var _live := {}         # unfrozen chunk -> true
var _dust: Array[CPUParticles3D] = []
var _dust_next := 0
var _last_dust := {}    # source id -> time of the last cascade puff


func _ready() -> void:
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.vertex_color_use_as_albedo = true
	_cap_mat.roughness = 1.0
	_cap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in DUST_POOL:
		_dust.append(_make_dust())


func _exit_tree() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


# --- Chunk shapes ----------------------------------------------------------

func _key(e: Edible) -> String:
	if e.has_meta("frac_key"):
		return e.get_meta("frac_key")
	var variant := absi(int(e.position.x * 7.0) + int(e.position.z * 13.0)) % VARIANTS
	return "%s|%d|%d" % [e.model_path, DebrisRules.piece_count(e.kind, e.size), variant]


func _model(path: String) -> Dictionary:
	if not _models.has(path):
		var inst: Node = (load(path) as PackedScene).instantiate()
		_models[path] = Fracture.extract(inst)
		inst.free()
	return _models[path]


## Starts cutting the chunks of `e`'s model on a worker thread, once per key.
func prepare(e: Edible) -> void:
	if not e.breakable:
		return
	var key := _key(e)
	e.set_meta("frac_key", key)
	if _queued.has(key):
		return
	_queued[key] = true
	var soups: Array = _model(e.model_path).soups
	var count := DebrisRules.piece_count(e.kind, e.size)
	_tasks.append(WorkerThreadPool.add_task(_work.bind(key, soups, count, key.hash())))


func _work(key: String, soups: Array, count: int, seed_value: int) -> void:
	var pieces := Fracture.split(soups, count, seed_value)
	_mutex.lock()
	_raw[key] = pieces
	_mutex.unlock()


func _pieces(e: Edible) -> Array:
	var key := _key(e)
	if _built.has(key):
		return _built[key]
	_mutex.lock()
	var raw: Variant = _raw.get(key)
	_mutex.unlock()
	if raw == null:
		# Not cut yet (or never queued): do it now.
		raw = Fracture.split(_model(e.model_path).soups, DebrisRules.piece_count(e.kind, e.size), key.hash())
	var mats: Array = _model(e.model_path).mats
	var out := []
	for pc: Dictionary in raw:
		var mesh := _build_mesh(pc, mats)
		if mesh == null:
			continue
		var hull: PackedVector3Array = pc.hull
		if hull.size() < 4:
			continue
		var box: AABB = pc.aabb
		out.append({"mesh": mesh, "hull": hull, "centre": box.get_center(),
			"vol": maxf(box.size.x * box.size.y * box.size.z, 0.001)})
	_built[key] = out
	return out


func _build_mesh(pc: Dictionary, mats: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in pc.soups.size():
		var s: Dictionary = pc.soups[i]
		if s.p.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.p
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _double_sided(mats[i]))
	if not pc.cap.p.is_empty():
		var cols := PackedColorArray()
		cols.resize(pc.cap.p.size())
		for t in range(0, cols.size(), 3):
			var c := CAP_COLOR.darkened(randf_range(0.0, 0.25))
			cols[t] = c
			cols[t + 1] = c
			cols[t + 2] = c
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pc.cap.p
		arr[Mesh.ARRAY_NORMAL] = pc.cap.n
		arr[Mesh.ARRAY_COLOR] = cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _cap_mat)
	return mesh if mesh.get_surface_count() > 0 else null


## Kenney models are open shells: a chunk shows its inside, so draw both sides.
func _double_sided(m: Material) -> Material:
	if m == null:
		return null
	var id := m.get_instance_id()
	if not _mats.has(id):
		var c := m.duplicate() as Material
		if c is BaseMaterial3D:
			(c as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[id] = c
	return _mats[id]


# --- Breaking --------------------------------------------------------------

## Swaps `e` for its chunks, placed where they are in the model.
func _spawn(e: Edible, frozen: bool) -> Array[Edible]:
	var out: Array[Edible] = []
	var pieces := _pieces(e)
	if pieces.is_empty():
		return out
	var body_xf := e.global_transform
	var b := e.model_basis
	var ac := e.model_center
	var total := 0.0
	for pc in pieces:
		total += pc.vol
	var left := e.points
	var biggest: Edible = null
	var biggest_vol := 0.0
	for pc in pieces:
		var c_local: Vector3 = b * (pc.centre - ac)
		var d := Edible.new()
		d.kind = "debris"
		d.magnetic = not frozen
		d.whole_points = e.points
		d.model_path = e.model_path
		d.transform = body_xf * Transform3D(Basis.IDENTITY, c_local)
		var mi := MeshInstance3D.new()
		mi.mesh = pc.mesh
		mi.transform = Transform3D(b, -(b * ac) - c_local)
		d.add_child(mi)
		var pts := PackedVector3Array()
		var box := AABB()
		for i in pc.hull.size():
			var p: Vector3 = b * (pc.hull[i] - ac) - c_local
			box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
			pts.append(p * SHRINK)
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var col := CollisionShape3D.new()
		col.shape = shape
		d.add_child(col)
		var size := box.size
		d.size = size
		d.extent = maxf(size.x, size.z)
		d.height = size.y
		d.fit_size = HoleRules.fit_size(d.extent, size.y)
		var vol: float = pc.vol * absf(b.determinant())
		d.mass = clampf(vol * 25.0, 1.0, 4000.0)
		d.points = maxi(1, int(e.points * pc.vol / total))
		left -= d.points
		if pc.vol > biggest_vol:
			biggest_vol = pc.vol
			biggest = d
		d.collision_layer = EDIBLE_LAYER
		d.collision_mask = GROUND_LAYER | EDIBLE_LAYER
		d.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		d.freeze = frozen
		if d.extent < 1.0 and size.y < 2.5:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = EdibleFactory.SMALL_VIS_RANGE
		d.set_meta("home", d.transform.origin)
		d.set_meta("src", e.get_instance_id())
		game.world.add_child(d)
		game._grid_add(d)
		out.append(d)
	if biggest and left > 0:
		biggest.points += left
	game.total_count += out.size() - 1
	fractured += 1
	_remove(e)
	return out


func _remove(e: Edible) -> void:
	game._grid_remove(e)
	game.awake.erase(e)
	game.movers.erase(e)
	e.queue_free()


## The whole thing fits: it falls apart into the hole.
func collapse(e: Edible, h: Hole) -> void:
	var vel := e.linear_velocity
	var origin := e.position
	var pts := e.points
	var big := e.size
	var pieces := _spawn(e, false)
	if pieces.is_empty():
		e.falling_into = null
		game._start_fall(e, h)
		return
	for d in pieces:
		var out := d.position - origin
		out.y = 0.0
		d.linear_velocity = vel + out.normalized() * randf_range(0.2, 1.0) + Vector3.DOWN * randf_range(0.0, 1.5)
		d.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 1.2
		_live[d] = true
		var dist := Vector2(d.position.x - h.position.x, d.position.z - h.position.z).length()
		if dist < h.radius + d.extent * 0.3:
			game._start_fall(d, h)
		else:
			game.awake[d] = true
	debris_peak = maxi(debris_peak, _live.size())
	_feedback(origin, big, pts, h, 1.0)


## The hole is under it but too small for all of it: break it up in place.
func fracture(e: Edible, h: Hole) -> void:
	var origin := e.position
	var big := e.size
	var pts := e.points
	var pieces := _spawn(e, true)
	DebrisRules.link_supports(pieces)
	_feedback(origin, big, pts, h, 0.35)


## Should `e` (which does not fit `h`) be broken up so `h` can eat part of it?
func can_fracture(e: Edible, h: Hole, dist: float) -> bool:
	if not e.breakable or not e.freeze or e.moving:
		return false
	if dist > h.radius + e.extent * 0.3:
		return false
	# Cheap guess first, then the real smallest chunk of this very building.
	var guess := e.fit_size / pow(DebrisRules.piece_count(e.kind, e.size), 1.0 / 3.0)
	if not HoleRules.fits(guess * 0.6, h.radius):
		return false
	return HoleRules.fits(_smallest_chunk(e), h.radius)


func _smallest_chunk(e: Edible) -> float:
	if e.has_meta("chunk_fit"):
		return e.get_meta("chunk_fit")
	var best := INF
	for pc in _pieces(e):
		var box := AABB()
		for i in pc.hull.size():
			var p: Vector3 = e.model_basis * pc.hull[i]
			box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
		best = minf(best, HoleRules.fit_size(maxf(box.size.x, box.size.z), box.size.y))
	e.set_meta("chunk_fit", best)
	return best


## A chunk leaves its place (falls in, gets eaten or knocked off): whatever
## it held up and nothing else holds up comes down too.
func release(d: Edible) -> void:
	if d.supports.is_empty():
		return
	var list := d.supports.duplicate()
	d.supports.clear()
	var dropped := 0
	for item in list:
		if not is_instance_valid(item):
			continue
		var c: Edible = item
		c.supporters -= 1
		if c.supporters <= 0 and not c.grounded and c.freeze and c.falling_into == null:
			game._wake(c)
			c.magnetic = true
			_live[c] = true
			dropped += 1
			release(c)
	if dropped > 0 and is_instance_valid(d):
		var src: int = d.get_meta("src", 0)
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(_last_dust.get(src, -10.0)) > DUST_GAP:
			_last_dust[src] = now
			_puff(d.position, d.extent * 1.5, 12)
			if _visible(d.position):
				Sfx.play("crumble", randf_range(1.2, 1.5), -6.0, 200)
				game._add_shake(0.08)


func forget(d: Edible) -> void:
	_live.erase(d)


## Every half second: chunks that settled on the ground freeze like the rest
## of the city; over the limit, the farthest awake ones freeze too.
func tick() -> void:
	for item in _live.keys():
		if not is_instance_valid(item):
			_live.erase(item)
			continue
		var d: Edible = item
		if d.falling_into == null and d.sleeping:
			_settle(d)
		elif d.falling_into == null and not d.supports.is_empty() \
				and d.position.distance_to(d.get_meta("home", d.position)) > 0.6:
			release(d)
	debris_peak = maxi(debris_peak, _live.size())
	if _live.size() <= MAX_DEBRIS:
		return
	var focus: Vector3 = game.player.position
	var list := _live.keys().filter(func(d: Edible) -> bool: return d.falling_into == null)
	list.sort_custom(func(a: Edible, b: Edible) -> bool:
		return a.position.distance_squared_to(focus) > b.position.distance_squared_to(focus))
	for i in mini(_live.size() - MAX_DEBRIS, list.size()):
		_settle(list[i])


func _settle(d: Edible) -> void:
	_live.erase(d)
	if d.position.distance_to(d.get_meta("home", d.position)) > 0.6:
		release(d)
	d.set_meta("home", d.position)
	d.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	d.freeze = true
	game.awake.erase(d)


# --- Effects ---------------------------------------------------------------

func _visible(p: Vector3) -> bool:
	if game.attract:
		return false
	return p.distance_to(game.player.position) < 45.0 + game.player.radius * 4.0


func _feedback(origin: Vector3, size: Vector3, points: int, h: Hole, strength: float) -> void:
	var r := maxf(size.x, size.z) * 0.6 + size.y * 0.15
	_puff(origin - Vector3(0, size.y * 0.5, 0), r, int(clampf(10.0 + r * 3.0, 12.0, 48.0) * strength))
	if not (game._me(h) or _visible(origin)):
		return
	var pitch := clampf(1.3 - size.y * 0.012, 0.6, 1.3) * randf_range(0.93, 1.07)
	Sfx.play("crumble", pitch, -1.0 if strength >= 1.0 else -5.0, 150)
	game._add_shake(clampf(points / 200.0, 0.2, 0.7) * strength)
	if strength >= 1.0 and points >= 40:
		GameState.vibrate(clampi(20 + points / 20, 20, 80))


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 1.6
	p.amount = 48
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.74, 0.68, 0.55))
	ramp.set_color(1, Color(0.78, 0.74, 0.68, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dust_texture()
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _dust_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


func _puff(at: Vector3, radius: float, amount: int) -> void:
	if game.attract and not _visible_menu(at):
		return
	var p := _dust[_dust_next]
	_dust_next = (_dust_next + 1) % _dust.size()
	p.emitting = false
	p.global_position = Vector3(at.x, maxf(at.y, 0.0) + 0.5, at.z)
	p.emission_sphere_radius = maxf(radius * 0.5, 0.5)
	p.amount = clampi(amount, 6, 64)
	p.scale_amount_min = 0.6 + radius * 0.12
	p.scale_amount_max = 1.2 + radius * 0.22
	p.restart()
	p.emitting = true


func _visible_menu(at: Vector3) -> bool:
	return at.distance_to(game.player.position) < 60.0
