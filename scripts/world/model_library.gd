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

var _cache := {}


func has_kind(kind: String) -> bool:
	return MODELS.has(kind)


## Deterministic pick (depends on position, so the same seed looks the same).
func pick(kind: String, p: Vector3) -> Dictionary:
	var list: Array = MODELS[kind]
	var idx := absi(int(p.x * 73.1) * 31 + int(p.z * 131.7)) % list.size()
	return _load(list[idx])


func _load(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var scene: PackedScene = load(ROOT + path + ".glb")
	var probe := scene.instantiate()
	var acc: Array = [null]
	_merge_aabb(probe, Transform3D.IDENTITY, acc)
	_fix_materials(probe)
	probe.free()
	var info := {"scene": scene, "aabb": acc[0] if acc[0] != null else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)}
	_cache[path] = info
	return info


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
