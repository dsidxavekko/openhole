extends SceneTree
## Prints the AABB of every Kenney model: godot --headless -s tests/inspect_models.gd

func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_aabb(c, t, acc)

func _init() -> void:
	for dir in DirAccess.get_directories_at("res://assets/kenney"):
		for f in DirAccess.get_files_at("res://assets/kenney/" + dir):
			if not f.ends_with(".glb"):
				continue
			var scn: PackedScene = load("res://assets/kenney/%s/%s" % [dir, f])
			var n := scn.instantiate()
			var acc := [null]
			_aabb(n, Transform3D.IDENTITY, acc)
			var a: AABB = acc[0]
			print("%s/%s size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f)" % [dir, f, a.size.x, a.size.y, a.size.z, a.position.x, a.position.y, a.position.z])
			n.free()
	quit()
