class_name CityGen
extends RefCounted
## Procedural city layout. Returns plain data (spawn specs), no nodes,
## so the same seed always gives the same city and it is easy to test.
##
## Spec: {k: kind, p: ground position (Vector3, y = 0), r: yaw, s: target size, c: Color}
## The factory may replace `s` with the real size of the chosen model.

const BLOCK := 30.0
const ROAD := 12.0
const PITCH := BLOCK + ROAD
const SIDEWALK := 3.0

const SIZES := {
	"person": Vector3(0.45, 1.7, 0.45),
	"hydrant": Vector3(0.4, 0.8, 0.4),
	"trash": Vector3(0.6, 1.0, 0.6),
	"cone": Vector3(0.45, 0.7, 0.45),
	"flower": Vector3(0.4, 0.6, 0.4),
	"pot": Vector3(0.6, 1.1, 0.6),
	"crate": Vector3(0.8, 0.8, 0.8),
	"mailbox": Vector3(0.5, 1.2, 0.4),
	"sign": Vector3(0.5, 2.6, 0.5),
	"bike": Vector3(0.4, 1.0, 1.7),
	"bench": Vector3(1.6, 0.9, 0.7),
	"barrier": Vector3(1.4, 1.0, 0.8),
	"lamp": Vector3(0.4, 4.5, 0.4),
	"tlight": Vector3(0.5, 4.5, 0.5),
	"bush": Vector3(1.3, 0.9, 1.3),
	"rock": Vector3(1.6, 0.8, 1.6),
	"bin": Vector3(1.0, 1.4, 1.8),
	"tree": Vector3(1.8, 4.5, 1.8),
	"car": Vector3(1.8, 1.4, 4.0),
	"bus": Vector3(2.5, 3.0, 7.0),
}

const SMALL_STREET := ["person", "person", "person", "person", "lamp", "hydrant", "trash", "bench",
	"tree", "tree", "mailbox", "bike", "sign", "pot", "crate", "flower", "cone"]
const SMALL_YARD := ["person", "person", "bush", "bush", "crate", "pot", "flower", "bike", "trash",
	"bin", "cone", "barrier"]
const SMALL_PARK := ["tree", "tree", "tree", "bush", "bush", "bench", "person", "person", "person",
	"rock", "flower", "flower", "lamp", "trash"]

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
		"mailbox": c = Color("1d4ed8")
		"bike": c = CAR_COLORS[rng.randi() % CAR_COLORS.size()]
	var size: Vector3 = SIZES[kind]
	if kind == "tree":
		size *= rng.randf_range(0.8, 1.3)
	var yaw := rng.randf_range(0, TAU) if kind in ["person", "bike", "rock", "crate", "barrier"] else 0.0
	_add(out, kind, x, z, yaw, size, c)


static func _pick(rng: RandomNumberGenerator, list: Array) -> String:
	return list[rng.randi() % list.size()]


## Small things scattered in a rectangle, with a crude minimum spacing.
static func _scatter(rng: RandomNumberGenerator, out: Array, list: Array, count: int,
		x0: float, z0: float, x1: float, z1: float) -> void:
	var placed: Array[Vector2] = []
	for i in count:
		for attempt in 4:
			var p := Vector2(rng.randf_range(x0, x1), rng.randf_range(z0, z1))
			var ok := true
			for q in placed:
				if p.distance_squared_to(q) < 1.6:
					ok = false
					break
			if ok:
				placed.append(p)
				_small(rng, out, _pick(rng, list), p.x, p.y)
				break


static func _city_lots(rng: RandomNumberGenerator, out: Array, bx: float, bz: float, center_t: float) -> void:
	var inner := BLOCK - SIDEWALK * 2.0
	var ox := bx + SIDEWALK
	var oz := bz + SIDEWALK
	# Sometimes one big tower fills the block.
	if center_t > 0.55 and rng.randf() < 0.35:
		var f := rng.randf_range(13.0, 17.0)
		var h := lerpf(30.0, 60.0, center_t) * rng.randf_range(0.8, 1.15)
		_add(out, "building", ox + inner / 2.0, oz + inner / 2.0, 0.0, Vector3(f, h, f),
			BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])
		# Plaza corners around the tower.
		for corner in 4:
			var cx := ox + (1.5 if corner % 2 == 0 else inner - 1.5)
			var cz := oz + (1.5 if corner < 2 else inner - 1.5)
			_scatter(rng, out, SMALL_YARD, rng.randi_range(2, 4), cx - 1.0, cz - 1.0, cx + 1.0, cz + 1.0)
		return
	var lot := inner / 2.0
	for li in 2:
		for lj in 2:
			var fx := rng.randf_range(5.5, lot - 3.0)
			var fz := rng.randf_range(5.5, lot - 3.0)
			var h := lerpf(5.0, 34.0, pow(center_t, 1.4)) * rng.randf_range(0.6, 1.25)
			h = maxf(h, 4.0)
			var cx := ox + lot * li + lot / 2.0
			var cz := oz + lot * lj + lot / 2.0
			_add(out, "building", cx, cz, 0.0, Vector3(fx, h, fz),
				BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])
			# Things in the gap between the building and the lot edge.
			var gx := lot / 2.0 - 0.7
			for n in rng.randi_range(2, 5):
				var side := rng.randi() % 4
				var t := rng.randf_range(-gx, gx)
				var px := cx + (t if side < 2 else (gx if side == 2 else -gx))
				var pz := cz + (t if side >= 2 else (gx if side == 0 else -gx))
				_small(rng, out, _pick(rng, SMALL_YARD), px, pz)


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
				_scatter(rng, out, SMALL_PARK, rng.randi_range(4, 7), cx - 3.0, cz - 3.0, cx + 3.0, cz + 3.0)
				continue
			var f := rng.randf_range(4.5, 5.5)
			_add(out, "house", cx, cz, 0.0, Vector3(f, rng.randf_range(3.5, 5.5), f * rng.randf_range(0.8, 1.0)),
				BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])
			for n in rng.randi_range(1, 3):
				var a := rng.randf() * TAU
				_small(rng, out, _pick(rng, SMALL_YARD), cx + cos(a) * 3.3, cz + sin(a) * 3.3)


static func _park(rng: RandomNumberGenerator, out: Array, bx: float, bz: float) -> void:
	var m := SIDEWALK + 1.0
	_scatter(rng, out, SMALL_PARK, rng.randi_range(30, 45), bx + m, bz + m, bx + BLOCK - m, bz + BLOCK - m)


static func _sidewalk(rng: RandomNumberGenerator, out: Array, bx: float, bz: float) -> void:
	var inset := 1.4
	var step := 2.5
	var t := 1.5
	while t < BLOCK - 1.0:
		for side in 4:
			if rng.randf() > 0.8:
				continue
			var x := 0.0
			var z := 0.0
			match side:
				0: x = bx + t; z = bz + inset
				1: x = bx + t; z = bz + BLOCK - inset
				2: x = bx + inset; z = bz + t
				3: x = bx + BLOCK - inset; z = bz + t
			var k := _pick(rng, SMALL_STREET)
			_small(rng, out, k, x, z)
			# Sometimes a little crowd.
			if k == "person" and rng.randf() < 0.25:
				for n in rng.randi_range(1, 3):
					_small(rng, out, "person", x + rng.randf_range(-0.9, 0.9), z + rng.randf_range(-0.9, 0.9))
		t += step
	# Traffic lights on the block corners.
	for corner in 4:
		if rng.randf() < 0.6:
			var cx := bx + (0.6 if corner % 2 == 0 else BLOCK - 0.6)
			var cz := bz + (0.6 if corner < 2 else BLOCK - 0.6)
			_small(rng, out, "tlight", cx, cz)


static func _roads(rng: RandomNumberGenerator, out: Array, blocks: int, half: float) -> void:
	for j in blocks + 1:
		var road_c := -half + ROAD / 2.0 + j * PITCH
		for horizontal in [true, false]:
			# Driving lanes (+-3) and parking lanes along the kerbs (+-5).
			for lane in [-3.0, 3.0, -4.9, 4.9]:
				var parked: bool = absf(lane) > 4.0
				var t := -half + rng.randf_range(2.0, 10.0)
				while t < half - 4.0:
					# Leave crossings free.
					var m := fposmod(t + half, PITCH)
					if m < ROAD + 1.0:
						t += ROAD + 1.0 - m
						continue
					var is_bus := not parked and rng.randf() < 0.1
					var kind := "bus" if is_bus else "car"
					var color: Color = Color("f4d35e") if is_bus else CAR_COLORS[rng.randi() % CAR_COLORS.size()]
					var yaw := (PI / 2.0 if horizontal else 0.0) + (PI if lane > 0 else 0.0)
					var x: float = t if horizontal else road_c + lane
					var z: float = road_c + lane if horizontal else t
					if not parked or rng.randf() < 0.65:
						_add(out, kind, x, z, yaw, SIZES[kind], color)
					t += (rng.randf_range(1.5, 3.0) if parked else rng.randf_range(4.0, 10.0)) + (7.5 if is_bus else 4.0)
		# People crossing the road.
		for n in rng.randi_range(3, 6):
			_small(rng, out, "person", rng.randf_range(-half, half), road_c + rng.randf_range(-1.5, 1.5))
