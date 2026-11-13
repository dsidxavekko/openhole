class_name ModelLibrary
extends RefCounted
## Kenney (CC0) models per object kind. Each model is loaded once and its
## bounding box cached; kinds without models fall back to primitives.

const ROOT := "res://assets/kenney/"

const MODELS := {
	"building": ["commercial/building-a", "commercial/building-b", "commercial/building-c",
		"commercial/building-d", "commercial/building-e", "commercial/building-f",
		"commercial/building-g", "commercial/building-h", "commercial/building-i",
		"commercial/building-j", "commercial/building-k", "commercial/building-l",
		"commercial/building-m", "commercial/building-n"],
	"skyscraper": ["commercial/building-skyscraper-a", "commercial/building-skyscraper-b",
		"commercial/building-skyscraper-c", "commercial/building-skyscraper-d",
		"commercial/building-skyscraper-e"],
	"house": ["suburban/building-type-a", "suburban/building-type-b", "suburban/building-type-c",
		"suburban/building-type-d", "suburban/building-type-e", "suburban/building-type-f",
		"suburban/building-type-g", "suburban/building-type-h", "suburban/building-type-i",
		"suburban/building-type-j", "suburban/building-type-k", "suburban/building-type-l",
		"suburban/building-type-m", "suburban/building-type-n", "suburban/building-type-o",
		"suburban/building-type-p", "suburban/building-type-q", "suburban/building-type-r",
		"suburban/building-type-s", "suburban/building-type-t", "suburban/building-type-u"],
	"car": ["cars/sedan", "cars/sedan-sports", "cars/hatchback-sports", "cars/suv",
		"cars/suv-luxury", "cars/taxi", "cars/police", "cars/van", "cars/truck"],
	"bus": ["cars/delivery", "cars/garbage-truck", "cars/firetruck", "cars/ambulance"],
	"person": ["chars/character-female-a", "chars/character-female-b", "chars/character-female-c",
		"chars/character-female-d", "chars/character-female-e", "chars/character-female-f",
		"chars/character-male-a", "chars/character-male-b", "chars/character-male-c",
		"chars/character-male-d", "chars/character-male-e", "chars/character-male-f"],
	"tree": ["nature/tree_default", "nature/tree_oak", "nature/tree_detailed", "nature/tree_fat",
		"nature/tree_simple", "nature/tree_cone", "nature/tree_small", "suburban/tree-large"],
	"bush": ["nature/plant_bush", "nature/plant_bushLarge", "nature/plant_bushDetailed",
		"nature/plant_bushSmall"],
	"rock": ["nature/rock_largeA", "nature/rock_largeB", "nature/rock_largeC"],
	"flower": ["nature/flower_redA", "nature/flower_yellowA"],
	"lamp": ["roads/light-square", "roads/light-curved"],
	"cone": ["roads/construction-cone"],
	"barrier": ["roads/construction-barrier"],
	"sign": ["roads/road-sign-stop", "roads/road-sign-warning", "roads/road-sign-street"],
	"tlight": ["roads/traffic-light"],
	"bin": ["roads/dumpster"],
	"bench": ["furniture/bench", "furniture/benchCushion"],
	"crate": ["cars/box", "furniture/cardboardBoxClosed"],
	"pot": ["furniture/pottedPlant", "suburban/planter"],
}

## Kinds scaled by height (thin things); everything else is fitted to its footprint.
const FIT_HEIGHT := ["person", "tree", "lamp", "sign", "tlight", "cone", "pot", "flower"]
## How far a building may be stretched vertically after the height fit.
const BUILDING_STRETCH := Vector2(0.85, 1.35)
## How many close-fitting models pick_fit() keeps for the variety hash.
const FIT_CHOICES := 4

var _cache := {}
var _aabbs := {}
static var _shared: ModelLibrary = null


## One library per process: tinted scenes are packed once and survive a match,
## otherwise every match start pays the packing again (a hitch on phones).
static func shared() -> ModelLibrary:
	if _shared == null:
		_shared = ModelLibrary.new()
	return _shared


func has_kind(kind: String) -> bool:
	return MODELS.has(kind)


## Deterministic pick (depends on position, so the same seed looks the same).
## `tint` multiplies the model's own colours; Color.WHITE keeps stock materials.
func pick(kind: String, p: Vector3, tint: Color = Color.WHITE) -> Dictionary:
	var list: Array = MODELS[kind]
	var idx := absi(int(p.x * 73.1) * 31 + int(p.z * 131.7)) % list.size()
	return _load(list[idx], tint)


## Like pick(), but prefers models whose height fits `s` without much vertical
## stretching (buildings): the FIT_CHOICES closest models are kept and the
## position hash chooses among them, so neighbouring lots still vary.
func pick_fit(kind: String, p: Vector3, s: Vector3, tint: Color = Color.WHITE) -> Dictionary:
	var list: Array = MODELS[kind]
	var costs: Array[float] = []
	for path: String in list:
		costs.append(_height_cost(_load(path, Color.WHITE).aabb, s))
	var order := range(list.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return costs[a] < costs[b] if costs[a] != costs[b] else a < b)
	var shortlist: Array = []
	for i in mini(FIT_CHOICES, order.size()):
		shortlist.append(list[order[i]])
	var idx := absi(int(p.x * 73.1) * 31 + int(p.z * 131.7)) % shortlist.size()
	return _load(shortlist[idx], tint)


## |log| of the vertical stretch the footprint fit would apply (0 = perfect).
static func _height_cost(a: AABB, s: Vector3) -> float:
	return absf(log(clampf(fit_spec(a, s).f, 0.25, 4.0)))


## Footprint fit of a model AABB to a target size, shared by the picker above
## and EdibleFactory._add_model so the two can never drift apart.
## k is the uniform scale; f the extra vertical factor for buildings.
static func fit_spec(a: AABB, s: Vector3) -> Dictionary:
	var rot90: bool = absf(s.x - s.z) > 0.3 and (a.size.x > a.size.z) != (s.x > s.z)
	var ax: float = a.size.z if rot90 else a.size.x
	var az: float = a.size.x if rot90 else a.size.z
	var k: float = minf(s.x / maxf(ax, 0.001), s.z / maxf(az, 0.001))
	var f: float = s.y / maxf(a.size.y * k, 0.001)
	return {"rot90": rot90, "k": k, "f": f}


func _load(path: String, tint: Color) -> Dictionary:
	var key := path + "|" + tint.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var scene: PackedScene = load(ROOT + path + ".glb")
	if not _aabbs.has(path):
		var probe := scene.instantiate()
		var acc: Array = [null]
		_merge_aabb(probe, Transform3D.IDENTITY, acc)
		_fix_materials(probe)
		probe.free()
		_aabbs[path] = acc[0] if acc[0] != null else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	if tint != Color.WHITE:
		# A tinted copy must not touch the shared stock materials: duplicate
		# every mesh and material on a throwaway instance, then pack it.
		var probe := scene.instantiate()
		_apply_tint(probe, tint)
		var packed := PackedScene.new()
		if packed.pack(probe) == OK:
			scene = packed
		else:
			push_warning("Could not pack the tinted model %s, using stock colours" % path)
		probe.free()
	var info := {"path": ROOT + path + ".glb", "scene": scene, "aabb": _aabbs[path]}
	_cache[key] = info
	return info


## Multiplies the albedo of every material under `n` by `tint`. Meshes and
## materials are duplicated first (shared per call, not per mesh), so the stock
## resources used by other themes stay untouched.
static func _apply_tint(n: Node, tint: Color) -> void:
	var seen := {}
	_apply_tint_rec(n, tint, seen)


static func _apply_tint_rec(n: Node, tint: Color, seen: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh.duplicate() as Mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			if not seen.has(mat):
				var dup := mat.duplicate() as BaseMaterial3D
				dup.albedo_color = mat.albedo_color * tint
				seen[mat] = dup
			mesh.surface_set_material(i, seen[mat])
		mi.mesh = mesh
	for c in n.get_children():
		_apply_tint_rec(c, tint, seen)


static func _merge_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_merge_aabb(c, t, acc)


## Some Kenney kits (nature, furniture) export metallic = 1, which renders black
## without a sky to reflect. Materials are shared resources, so fixing them once
## fixes every instance.
static func _fix_materials(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat and mat.metallic > 0.0:
				mat.metallic = 0.0
				mat.roughness = 0.9
	for c in n.get_children():
		_fix_materials(c)
