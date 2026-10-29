class_name Fracture
extends RefCounted
## Cuts a model into irregular chunks with random planes. Pure math on triangle
## lists, so it can run on a worker thread; meshes and shapes are built later.
##
## A "soup" is {p: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array},
## three entries per triangle. A model is an Array of soups (one per material).
## A piece is {soups: Array (same order as the model), cap: {p, n}, aabb: AABB}.

const MAX_TILT := 0.45          # radians, ~25 degrees off the longest axis
const MAX_SHIFT := 0.2          # share of the extent the cut may move off-centre
const MIN_TRIS := 4
const TRIES := 6
const QUANT := 1000.0           # cap welding precision (1 mm in model units)
## Height counts less when picking the axis to cut: a hole takes a chunk by its
## width (see HoleRules.fit_size), so tall things split into columns first.
const HEIGHT_WEIGHT := 0.35


## Flattens every MeshInstance3D under `root` into one soup per material.
## Positions are in the space of `root`. Returns {soups: Array, mats: Array}.
static func extract(root: Node) -> Dictionary:
	var out := {"soups": [], "mats": []}
	_extract(root, Transform3D.IDENTITY, out, true)
	return out


static func _extract(n: Node, xf: Transform3D, out: Dictionary, is_root: bool) -> void:
	var t := xf
	if n is Node3D and not is_root:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var idx: int = out.mats.find(mat)
			if idx < 0:
				idx = out.mats.size()
				out.mats.append(mat)
				out.soups.append({"p": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()})
			var a: Array = mesh.surface_get_arrays(s)
			var vp: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var vn: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var vu: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ix.is_empty():
				ix.resize(vp.size())
				for i in vp.size():
					ix[i] = i
			var soup: Dictionary = out.soups[idx]
			var nb := t.basis.inverse().transposed()
			for i in ix:
				soup.p.append(t * vp[i])
				soup.n.append((nb * vn[i]).normalized() if vn.size() > i else Vector3.UP)
				soup.uv.append(vu[i] if vu.size() > i else Vector2.ZERO)
	for c in n.get_children():
		_extract(c, t, out, false)


static func soup_aabb(soups: Array) -> AABB:
	var have := false
	var box := AABB()
	for s in soups:
		for p: Vector3 in s.p:
			if not have:
				box = AABB(p, Vector3.ZERO)
				have = true
			else:
				box = box.expand(p)
	return box


## Splits the model into up to `count` pieces. Deterministic for a given seed.
static func split(soups: Array, count: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var first := {"soups": soups, "cap": {"p": PackedVector3Array(), "n": PackedVector3Array()}}
	first.aabb = _piece_aabb(first)
	var pieces: Array = [first]
	var stuck := 0
	while pieces.size() < count and stuck < count:
		# Always cut the biggest piece: chunks end up of similar size.
		var bi := 0
		for i in pieces.size():
			if _volume(pieces[i].aabb) > _volume(pieces[bi].aabb):
				bi = i
		var res := _cut_piece(pieces[bi], rng)
		if res.is_empty():
			stuck += 1
			continue
		pieces.remove_at(bi)
		pieces.append_array(res)
	for pc in pieces:
		pc.hull = hull_points(pc)
	return pieces


static func _volume(b: AABB) -> float:
	return maxf(b.size.x, 0.01) * maxf(b.size.y, 0.01) * maxf(b.size.z, 0.01)


static func _piece_aabb(piece: Dictionary) -> AABB:
	var all: Array = piece.soups.duplicate()
	all.append(piece.cap)
	return soup_aabb(all)


static func tri_count(piece: Dictionary) -> int:
	var n := 0
	for s in piece.soups:
		n += s.p.size() / 3
	return n


## Tries a few random planes; returns [front, back] or [] if every try left a side empty.
static func _cut_piece(piece: Dictionary, rng: RandomNumberGenerator) -> Array:
	var box: AABB = piece.aabb
	var axis := Vector3.RIGHT
	var ext := box.size.x
	var best := box.size.x
	if box.size.y * HEIGHT_WEIGHT > best:
		axis = Vector3.UP
		ext = box.size.y
		best = box.size.y * HEIGHT_WEIGHT
	if box.size.z > best:
		axis = Vector3.BACK
		ext = box.size.z
	for _t in TRIES:
		var tilt_axis := axis.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
		var normal := axis
		if tilt_axis.length_squared() > 0.5:
			normal = axis.rotated(tilt_axis, rng.randf_range(-MAX_TILT, MAX_TILT))
		var point := box.get_center() + axis * ext * rng.randf_range(-MAX_SHIFT, MAX_SHIFT)
		var res := cut(piece, Plane(normal, point))
		if tri_count(res[0]) >= MIN_TRIS and tri_count(res[1]) >= MIN_TRIS:
			return res
	return []


## Cuts one piece by `plane`. Returns [front (above the plane), back].
static func cut(piece: Dictionary, plane: Plane) -> Array:
	var front := {"soups": [], "cap": {"p": PackedVector3Array(), "n": PackedVector3Array()}}
	var back := {"soups": [], "cap": {"p": PackedVector3Array(), "n": PackedVector3Array()}}
	var segs := PackedVector3Array()
	for s in piece.soups:
		var f := {"p": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
		var b := {"p": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
		_cut_soup(s, plane, f, b, segs)
		front.soups.append(f)
		back.soups.append(b)
	# The old cap is cut too (it has no UVs: give it a dummy channel).
	var old_cap: Dictionary = piece.cap
	if not old_cap.p.is_empty():
		var cap_soup := {"p": old_cap.p, "n": old_cap.n, "uv": PackedVector2Array()}
		cap_soup.uv.resize(old_cap.p.size())
		var cf := {"p": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
		var cb := {"p": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
		_cut_soup(cap_soup, plane, cf, cb, segs)
		front.cap.p.append_array(cf.p)
		front.cap.n.append_array(cf.n)
		back.cap.p.append_array(cb.p)
		back.cap.n.append_array(cb.n)
	_add_caps(segs, plane, front.cap, back.cap)
	front.aabb = _piece_aabb(front)
	back.aabb = _piece_aabb(back)
	return [front, back]


static func _cut_soup(s: Dictionary, plane: Plane, f: Dictionary, b: Dictionary, segs: PackedVector3Array) -> void:
	var p: PackedVector3Array = s.p
	var n: PackedVector3Array = s.n
	var uv: PackedVector2Array = s.uv
	var i := 0
	while i + 2 < p.size():
		var d0 := plane.distance_to(p[i])
		var d1 := plane.distance_to(p[i + 1])
		var d2 := plane.distance_to(p[i + 2])
		var s0 := d0 >= 0.0
		var s1 := d1 >= 0.0
		var s2 := d2 >= 0.0
		if s0 == s1 and s1 == s2:
			var dst := f if s0 else b
			for k in 3:
				dst.p.append(p[i + k])
				dst.n.append(n[i + k])
				dst.uv.append(uv[i + k])
		else:
			_split_tri(p, n, uv, i, [d0, d1, d2], f, b, segs)
		i += 3


## One triangle crosses the plane: the lone vertex gives one triangle on its
## side, the other two give a quad (two triangles). Winding is kept.
static func _split_tri(p: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array,
		i: int, d: Array, f: Dictionary, b: Dictionary, segs: PackedVector3Array) -> void:
	# Find the vertex alone on its side.
	var lone := 0
	if (d[0] >= 0.0) == (d[1] >= 0.0):
		lone = 2
	elif (d[0] >= 0.0) == (d[2] >= 0.0):
		lone = 1
	var a := i + lone
	var bi := i + (lone + 1) % 3
	var c := i + (lone + 2) % 3
	var da: float = d[lone]
	var db: float = d[(lone + 1) % 3]
	var dc: float = d[(lone + 2) % 3]
	var tab := da / (da - db)
	var tac := da / (da - dc)
	var pab := p[a].lerp(p[bi], tab)
	var pac := p[a].lerp(p[c], tac)
	var nab := n[a].lerp(n[bi], tab).normalized()
	var nac := n[a].lerp(n[c], tac).normalized()
	var uab := uv[a].lerp(uv[bi], tab)
	var uac := uv[a].lerp(uv[c], tac)
	var lone_side := f if da >= 0.0 else b
	var pair_side := b if da >= 0.0 else f
	_tri(lone_side, p[a], n[a], uv[a], pab, nab, uab, pac, nac, uac)
	_tri(pair_side, pab, nab, uab, p[bi], n[bi], uv[bi], p[c], n[c], uv[c])
	_tri(pair_side, pab, nab, uab, p[c], n[c], uv[c], pac, nac, uac)
	segs.append(pab)
	segs.append(pac)


static func _tri(dst: Dictionary, p0: Vector3, n0: Vector3, u0: Vector2, p1: Vector3, n1: Vector3,
		u1: Vector2, p2: Vector3, n2: Vector3, u2: Vector2) -> void:
	dst.p.append(p0)
	dst.p.append(p1)
	dst.p.append(p2)
	dst.n.append(n0)
	dst.n.append(n1)
	dst.n.append(n2)
	dst.uv.append(u0)
	dst.uv.append(u1)
	dst.uv.append(u2)


## Fills the cut: segments are grouped into connected outlines (a tree cut
## through trunk and crown gives two), each fanned from its centre.
static func _add_caps(segs: PackedVector3Array, plane: Plane, front: Dictionary, back: Dictionary) -> void:
	if segs.size() < 6:
		return
	var parent := {}
	var keys := PackedStringArray()
	keys.resize(segs.size())
	for i in segs.size():
		var q := segs[i] * QUANT
		var k := "%d,%d,%d" % [roundi(q.x), roundi(q.y), roundi(q.z)]
		keys[i] = k
		if not parent.has(k):
			parent[k] = k
	for i in range(0, segs.size(), 2):
		_union(parent, keys[i], keys[i + 1])
	var groups := {}
	for i in range(0, segs.size(), 2):
		var r := _find(parent, keys[i])
		if not groups.has(r):
			groups[r] = []
		groups[r].append(i)
	for r in groups:
		var list: Array = groups[r]
		if list.size() < 3:
			continue
		var centre := Vector3.ZERO
		for i: int in list:
			centre += segs[i] + segs[i + 1]
		centre /= list.size() * 2.0
		for i: int in list:
			var a := segs[i]
			var b := segs[i + 1]
			# Front piece lies above the plane: its cap faces down the normal.
			var facing := (a - centre).cross(b - centre).dot(plane.normal)
			if facing > 0.0:
				_cap_tri(back, centre, a, b, plane.normal)
				_cap_tri(front, centre, b, a, -plane.normal)
			else:
				_cap_tri(back, centre, b, a, plane.normal)
				_cap_tri(front, centre, a, b, -plane.normal)


static func _cap_tri(dst: Dictionary, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	dst.p.append(a)
	dst.p.append(b)
	dst.p.append(c)
	dst.n.append(nrm)
	dst.n.append(nrm)
	dst.n.append(nrm)


static func _find(parent: Dictionary, k: String) -> String:
	var r := k
	while parent[r] != r:
		r = parent[r]
	while parent[k] != r:
		var nx: String = parent[k]
		parent[k] = r
		k = nx
	return r


static func _union(parent: Dictionary, a: String, b: String) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


## A few extreme points of the piece (the furthest vertex along 26 directions):
## enough for a convex collision hull and much cheaper than a full one.
static func hull_points(piece: Dictionary) -> PackedVector3Array:
	var pts := piece_points(piece)
	var out := PackedVector3Array()
	if pts.is_empty():
		return out
	var dirs: Array[Vector3] = []
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x != 0 or y != 0 or z != 0:
					dirs.append(Vector3(x, y, z).normalized())
	for dir in dirs:
		var best := pts[0]
		var best_d := best.dot(dir)
		for p in pts:
			var dd := p.dot(dir)
			if dd > best_d:
				best_d = dd
				best = p
		if not out.has(best):
			out.append(best)
	return out


## Vertex positions of a piece (surface and cap), for a collision hull.
static func piece_points(piece: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in piece.soups:
		out.append_array(s.p)
	out.append_array(piece.cap.p)
	return out
