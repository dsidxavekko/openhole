class_name CityGen
extends RefCounted
## Procedural city layout. Returns plain data (spawn specs), no nodes,
## so the same seed always gives the same city and it is easy to test.
##
## Spec: {k: kind, p: ground position (Vector3, y = 0), r: yaw, s: size, c: Color}

const BLOCK := 30.0
const ROAD := 12.0
const PITCH := BLOCK + ROAD
const SIDEWALK := 3.0

const SIZES := {
	"person": Vector3(0.45, 1.7, 0.45),
	"hydrant": Vector3(0.4, 0.8, 0.4),
	"trash": Vector3(0.6, 1.0, 0.6),
	"cone": Vector3(0.45, 0.7, 0.45),
	"bench": Vector3(1.6, 0.8, 0.6),
	"lamp": Vector3(0.25, 4.0, 0.25),
	"tree": Vector3(1.4, 4.2, 1.4),
	"bush": Vector3(1.1, 0.9, 1.1),
	"car": Vector3(1.8, 1.4, 4.0),
	"bus": Vector3(2.5, 3.0, 9.0),
}

const CAR_COLORS := [Color("e63946"), Color("f1fa8c"), Color("457b9d"), Color("f4a261"),
	Color("2a9d8f"), Color("ffffff"), Color("222222"), Color("8e44ad")]
const BUILDING_COLORS := [Color("d8c3a5"), Color("8e8d8a"), Color("e98074"), Color("a3bcb6"),
	Color("c9ada7"), Color("f2e9e4"), Color("9a8c98"), Color("b5c99a")]
const SHIRT_COLORS := [Color("e76f51"), Color("264653"), Color("e9c46a"), Color("06d6a0"),
	Color("118ab2"), Color("ef476f")]


static func map_extent(blocks: int) -> float:
	return blocks * PITCH + ROAD


static func generate(seed_value: int, blocks: int, theme: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	var half := map_extent(blocks) / 2.0
	for bi in blocks:
		for bj in blocks:
			var bx := -half + ROAD + bi * PITCH
			var bz := -half + ROAD + bj * PITCH
			var center := Vector2(bx + BLOCK / 2.0, bz + BLOCK / 2.0)
			var center_t := 1.0 - clampf(center.length() / half, 0.0, 1.0)
			var park_chance := 0.12 if theme == 0 else 0.22
			if rng.randf() < park_chance:
				_park(rng, out, bx, bz)
			elif theme == 0:
				_city_lots(rng, out, bx, bz, center_t)
			else:
				_suburb_lots(rng, out, bx, bz)
			_sidewalk(rng, out, bx, bz)
	_roads(rng, out, blocks, half)
	return out


static func _add(out: Array, kind: String, x: float, z: float, yaw: float, size: Vector3, color: Color) -> void:
	out.append({"k": kind, "p": Vector3(x, 0.0, z), "r": yaw, "s": size, "c": color})


static func _small(rng: RandomNumberGenerator, out: Array, kind: String, x: float, z: float) -> void:
	var c := Color.WHITE
	match kind:
		"person": c = SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()]
		"hydrant": c = Color("d62828")
		"trash": c = Color("3a5a40")
		"cone": c = Color("ff7b00")
		"bench": c = Color("8d5524")
		"lamp": c = Color("495057")
		"tree": c = Color("2d6a4f")
		"bush": c = Color("40916c")
	_add(out, kind, x, z, rng.randf_range(0, TAU) if kind == "person" else 0.0, SIZES[kind], c)


static func _city_lots(rng: RandomNumberGenerator, out: Array, bx: float, bz: float, center_t: float) -> void:
	var inner := BLOCK - SIDEWALK * 2.0
	var ox := bx + SIDEWALK
	var oz := bz + SIDEWALK
	# Sometimes one big tower fills the block.
	if center_t > 0.55 and rng.randf() < 0.35:
		var f := rng.randf_range(14.0, 20.0)
		var h := lerpf(30.0, 60.0, center_t) * rng.randf_range(0.8, 1.15)
		_add(out, "building", ox + inner / 2.0, oz + inner / 2.0, 0.0, Vector3(f, h, f),
			BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])
		return
	var lot := inner / 2.0
	for li in 2:
		for lj in 2:
			var fx := rng.randf_range(5.5, lot - 1.5)
			var fz := rng.randf_range(5.5, lot - 1.5)
			var h := lerpf(5.0, 34.0, pow(center_t, 1.4)) * rng.randf_range(0.6, 1.25)
			h = maxf(h, 4.0)
			var cx := ox + lot * li + lot / 2.0
			var cz := oz + lot * lj + lot / 2.0
			_add(out, "building", cx, cz, 0.0, Vector3(fx, h, fz),
				BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])
			# Something small next to the building.
			if rng.randf() < 0.5:
				var k: String = ["person", "trash", "bush", "cone"][rng.randi() % 4]
				_small(rng, out, k, cx + (lot / 2.0 - 0.8) * signf(rng.randf() - 0.5),
					cz + rng.randf_range(-lot / 3.0, lot / 3.0))


static func _suburb_lots(rng: RandomNumberGenerator, out: Array, bx: float, bz: float) -> void:
	var inner := BLOCK - SIDEWALK * 2.0
	var ox := bx + SIDEWALK
	var oz := bz + SIDEWALK
	var lot := inner / 3.0
	for li in 3:
		for lj in 3:
			var cx := ox + lot * li + lot / 2.0
			var cz := oz + lot * lj + lot / 2.0
			if li == 1 and lj == 1:
				# Backyard in the middle of the block.
				for n in rng.randi_range(1, 3):
					_small(rng, out, ["tree", "bush", "person"][rng.randi() % 3],
						cx + rng.randf_range(-2.5, 2.5), cz + rng.randf_range(-2.5, 2.5))
				continue
			var f := rng.randf_range(4.5, 6.5)
			_add(out, "house", cx, cz, 0.0, Vector3(f, rng.randf_range(3.5, 5.5), f * rng.randf_range(0.8, 1.0)),
				BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])


static func _park(rng: RandomNumberGenerator, out: Array, bx: float, bz: float) -> void:
	var n := rng.randi_range(14, 24)
	for i in n:
		var x := bx + rng.randf_range(SIDEWALK + 1.0, BLOCK - SIDEWALK - 1.0)
		var z := bz + rng.randf_range(SIDEWALK + 1.0, BLOCK - SIDEWALK - 1.0)
		var roll := rng.randf()
		var k := "tree" if roll < 0.4 else ("bush" if roll < 0.6 else ("bench" if roll < 0.75 else "person"))
		_small(rng, out, k, x, z)


static func _sidewalk(rng: RandomNumberGenerator, out: Array, bx: float, bz: float) -> void:
	var inset := 1.4
	var step := 4.0
	var t := 2.0
	while t < BLOCK - 1.0:
		for side in 4:
			if rng.randf() > 0.55:
				continue
			var x := 0.0
			var z := 0.0
			match side:
				0: x = bx + t; z = bz + inset
				1: x = bx + t; z = bz + BLOCK - inset
				2: x = bx + inset; z = bz + t
				3: x = bx + BLOCK - inset; z = bz + t
			var roll := rng.randf()
			var k := "person"
			if roll < 0.15: k = "lamp"
			elif roll < 0.25: k = "hydrant"
			elif roll < 0.35: k = "trash"
			elif roll < 0.45: k = "bench"
			elif roll < 0.6: k = "tree"
			_small(rng, out, k, x, z)
		t += step


static func _roads(rng: RandomNumberGenerator, out: Array, blocks: int, half: float) -> void:
	for j in blocks + 1:
		var road_c := -half + ROAD / 2.0 + j * PITCH
		for horizontal in [true, false]:
			for lane in [-3.0, 3.0]:
				var t := -half + rng.randf_range(4.0, 14.0)
				while t < half - 4.0:
					var is_bus := rng.randf() < 0.08
					var kind := "bus" if is_bus else "car"
					var color: Color = Color("f4d35e") if is_bus else CAR_COLORS[rng.randi() % CAR_COLORS.size()]
					var yaw := (PI / 2.0 if horizontal else 0.0) + (PI if lane > 0 else 0.0)
					var x: float = t if horizontal else road_c + lane
					var z: float = road_c + lane if horizontal else t
					_add(out, kind, x, z, yaw, SIZES[kind], color)
					t += rng.randf_range(12.0, 28.0) + (9.0 if is_bus else 4.0)
		# People crossing the road.
		for n in rng.randi_range(2, 5):
			var along := rng.randf_range(-half, half)
			_small(rng, out, "person", along, road_c + rng.randf_range(-4.0, 4.0))
