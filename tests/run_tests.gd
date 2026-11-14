extends SceneTree
## Headless logic tests: godot --headless -s tests/run_tests.gd

var _fails := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		_fails += 1


func _hash(specs: Array) -> int:
	var s := ""
	for sp in specs:
		s += "%s%.2f%.2f%.2f%.2f;" % [sp.k, sp.p.x, sp.p.z, sp.s.y, sp.r]
	return s.hash()


## First surface material in the tree, for model tint checks.
func _first_material(n: Node) -> BaseMaterial3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh \
			and (n as MeshInstance3D).mesh.get_surface_count() > 0:
		return (n as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	for c in n.get_children():
		var m := _first_material(c)
		if m:
			return m
	return null


func _area(soups: Array) -> float:
	var a := 0.0
	for s in soups:
		for i in range(0, s.p.size(), 3):
			a += (s.p[i + 1] - s.p[i]).cross(s.p[i + 2] - s.p[i]).length() * 0.5
	return a


func _init() -> void:
	print("HoleRules")
	_check(HoleRules.points_for_level(1) == 0, "level 1 needs 0 points")
	var monotonic := true
	for l in range(2, HoleRules.MAX_LEVEL + 1):
		if HoleRules.points_for_level(l) <= HoleRules.points_for_level(l - 1):
			monotonic = false
		if HoleRules.radius_for_level(l) <= HoleRules.radius_for_level(l - 1):
			monotonic = false
	_check(monotonic, "points and radius grow every level")
	for l in range(1, HoleRules.MAX_LEVEL + 1):
		if HoleRules.level_for_points(HoleRules.points_for_level(l)) != l:
			_check(false, "level_for_points round-trip at %d" % l)
	_check(HoleRules.level_for_points(10_000_000) == HoleRules.MAX_LEVEL, "level is capped")
	_check(HoleRules.fits(0.45, HoleRules.BASE_RADIUS), "a person fits a new hole")
	_check(not HoleRules.fits(4.0, HoleRules.BASE_RADIUS), "a car does not fit a new hole")
	_check(HoleRules.fits(4.0, HoleRules.radius_for_level(6)), "a car fits at level 6")
	var tower := HoleRules.fit_size(6.0, 40.0)
	_check(not HoleRules.fits(tower, HoleRules.radius_for_level(6)), "a 6x40 m tower does not fit at level 6")
	_check(HoleRules.fits(tower, HoleRules.radius_for_level(11)), "a 6x40 m tower fits at level 11")
	_check(HoleRules.fits(HoleRules.fit_size(0.4, 4.5), HoleRules.BASE_RADIUS), "a lamp post fits a new hole")
	_check(HoleRules.can_eat_hole(3.0, 1.0, 0.5), "big hole eats small hole on top of it")
	_check(not HoleRules.can_eat_hole(3.0, 2.8, 0.0), "similar sizes do not eat each other")
	_check(not HoleRules.can_eat_hole(3.0, 1.0, 5.0), "far holes do not eat")

	_check(is_equal_approx(HoleRules.combo_multiplier(1), 1.0), "no combo bonus for a single item")
	_check(HoleRules.combo_multiplier(5) > 1.0, "combo grows")
	_check(is_equal_approx(HoleRules.combo_multiplier(1000), 1.5), "combo bonus is capped at +50 %")

	print("Skins")
	_check(Skins.unlocked_with({}, 0) and Skins.unlocked_with({}, 1), "first skins are free")
	_check(not Skins.unlocked_with({}, Skins.count() - 1), "last skin starts locked")
	var all := {"classic": 1e9, "solo": 100, "battle_wins": 1e9, "total_eaten": 1e9, "shift_kills": 1e9}
	_check(Skins.unlocked_set(all).size() == Skins.count(), "every skin can be unlocked")
	var phase := -1
	for i in Skins.count():
		if Skins.get_skin(i).name == "SKIN_PHASE":
			phase = i
	_check(phase >= 0, "the shift-kill skin exists")
	_check(not Skins.unlocked_with({}, phase), "the shift-kill skin starts locked")
	_check(Skins.unlocked_with({"shift_kills": 3}, phase), "three shift kills unlock the skin")
	var patterns_ok := true
	for i in Skins.count():
		if Skins.get_skin(i).pattern < 0 or Skins.get_skin(i).pattern > Skins.Pattern.SHIMMER:
			patterns_ok = false
	_check(patterns_ok, "skin patterns are known to the shader")

	print("Powerup")
	var no_shield := true
	for i in 300:
		if Powerup.random_kind(false) == Powerup.Kind.SHIELD:
			no_shield = false
	_check(no_shield, "solo never spawns a shield")

	print("Shift")
	var base := HoleRules.BASE_RADIUS
	var top := HoleRules.radius_for_level(HoleRules.MAX_LEVEL)
	_check(HoleRules.shifted_radius(base) < base, "shift makes a new hole smaller")
	_check(HoleRules.shifted_radius(top) >= base and HoleRules.shifted_radius(top) < top, "a max hole shrinks but stays above base size")
	_check(HoleRules.shifted_speed(10.0) > 10.0, "shift is faster")
	_check(HoleRules.can_shift_eat(1.0, 10.0, 2.0), "shifted hole eats a much bigger one it dives into")
	_check(HoleRules.can_shift_eat(1.0, top, top * 0.3), "no size limit for a shifted hole")
	_check(not HoleRules.can_shift_eat(1.0, 10.0, 6.0), "a shifted hole must dive into the inner half")
	_check(not HoleRules.can_shift_eat(1.0, 10.0, 9.5), "shifted hole on the rim does not eat yet")
	_check(not HoleRules.can_shift_eat(1.0, 0.5, 9.0), "far holes are not eaten")
	_check(HoleRules.chain_bonus(10, 1) == 0, "the first shift kill has no chain bonus")
	_check(HoleRules.chain_bonus(10, 2) == 5, "the second shift kill pays +50 %")
	_check(HoleRules.chain_bonus(9, 3) == 9, "the third shift kill pays +100 %")
	_check(HoleRules.SHIFT_CHAIN_WINDOW > HoleRules.SHIFT_COOLDOWN + Powerup.DURATIONS[Powerup.Kind.SHIFT],
		"the chain window allows back-to-back shifts")
	var k := Powerup.Kind.SHIFT
	_check(Powerup.DURATIONS.has(k) and Powerup.COLORS.has(k) and Powerup.NAMES.has(k), "SHIFT has duration, colour and name")
	_check(Powerup.WEIGHTS.get(k, 0) == 0, "SHIFT has no spawn weight")
	var never_shift := true
	for i in 1000:
		if Powerup.random_kind(true) == k:
			never_shift = false
	_check(never_shift, "SHIFT is never spawned on the map")

	var hole := Hole.new()
	hole._ready()
	hole.set_points(HoleRules.points_for_level(8))
	hole.snap_radius()
	var normal_r := hole.radius
	var normal_speed := hole.speed()
	hole.give_effect(Powerup.Kind.SPEED, 6.0)
	_check(hole.shift_ready() and hole.start_shift(), "shift starts when ready")
	_check(hole.is_shifted() and not hole.can_be_eaten(), "shifted hole cannot be eaten")
	_check(not hole.has_effect(Powerup.Kind.SPEED), "other power-ups are paused while shifted")
	_check(hole.speed() > normal_speed and hole.target_radius < normal_r, "shifted hole is faster and smaller")
	_check(not hole.start_shift(), "shift cannot start twice")
	hole.step(1.0, 100.0)
	_check(is_equal_approx(hole.effects[Powerup.Kind.SPEED], 6.0), "paused power-up time stands still")
	hole.step(Powerup.DURATIONS[Powerup.Kind.SHIFT], 100.0)
	_check(not hole.is_shifted() and hole.has_effect(Powerup.Kind.SPEED), "shift ends, power-ups resume")
	_check(not hole.shift_ready() and hole.shift_cooldown > 0.0, "cooldown starts after shift ends")
	hole.step(HoleRules.SHIFT_COOLDOWN + 0.1, 100.0)
	_check(hole.shift_ready(), "shift is ready after the cooldown")
	hole.start_shift()
	hole.set_alive(false)
	hole.set_alive(true)
	_check(hole.shift_ready() and not hole.is_shifted(), "respawn clears shift and its cooldown")
	hole.give_effect(Powerup.Kind.SHIELD, 5.0)
	_check(not hole.can_be_eaten(), "shield still protects")
	hole.free()

	print("Bot shift rules")
	_check(HoleRules.shift_escape_reach(2.0) > HoleRules.shift_escape_reach(1.0),
		"bigger holes keep a wider escape berth")
	_check(HoleRules.can_shift_dive(1.0, 3.0, 12.0), "a bot dives at a bigger hole it can reach")
	_check(not HoleRules.can_shift_dive(1.0, 3.0, 60.0), "a far bigger hole is not worth the dive")
	_check(not HoleRules.can_shift_dive(4.0, 4.5, 1.0), "no dive at a hole it could eat the usual way")

	print("CityGen")
	var a := CityGen.generate(42, 5, 0)
	var b := CityGen.generate(42, 5, 0)
	var c := CityGen.generate(43, 5, 0)
	var s := CityGen.generate(42, 5, 1)
	_check(a.size() > 2800, "city is dense (%d objects)" % a.size())
	_check(_hash(a) == _hash(b), "same seed gives same city")
	_check(_hash(a) != _hash(c), "different seed gives different city")
	_check(_hash(a) != _hash(s), "suburb theme differs from city")
	# Pinned layout fingerprints: a change to the rng draw order in CityGen would
	# silently rebuild every old seed, so it has to fail loudly instead.
	_check(_hash(a) == 3394065743, "city seed 42 layout is pinned")
	_check(_hash(s) == 2573031902, "suburb seed 42 layout is pinned")
	var mex := CityGen.generate(42, 5, 3)
	_check(_hash(mex) != _hash(a) and _hash(mex) != _hash(s), "mexico theme differs from city and suburb")
	var mex_houses := 0
	var mex_builds := 0
	var mex_tallest := 0.0
	for sp in mex:
		if sp.k == "house":
			mex_houses += 1
		elif sp.k == "building":
			mex_builds += 1
			mex_tallest = maxf(mex_tallest, sp.s.y)
	_check(mex_houses == 0 and mex_builds > 100,
		"mexico is all low blocks (%d blocks, %d houses)" % [mex_builds, mex_houses])
	_check(mex_tallest < 20.0, "mexico stays low-rise (%.1f)" % mex_tallest)
	_check(CityGen.generate(7, 2, 0).size() > 300, "menu background city has enough objects")
	var half := CityGen.map_extent(5) / 2.0
	var inside := true
	for sp in a:
		if absf(sp.p.x) > half or absf(sp.p.z) > half:
			inside = false
	_check(inside, "everything is inside the map")
	var in_crossing := 0
	for sp in a + s + mex:
		if sp.k != "person":
			continue
		var mx := fposmod(sp.p.x + half, CityGen.PITCH)
		var mz := fposmod(sp.p.z + half, CityGen.PITCH)
		if mx < CityGen.ROAD and mz < CityGen.ROAD:
			in_crossing += 1
	_check(in_crossing == 0, "nobody stands inside a crossing (%d)" % in_crossing)
	var pal_a := CityGen.generate(42, 5, 0)
	var colored := 0
	for sp in pal_a:
		if sp.k == "building" and sp.c != Color.WHITE:
			colored += 1
	_check(colored > 40, "city buildings carry palette colours (%d)" % colored)
	var stock_house := true
	for sp in s:
		if sp.k == "house" and sp.c != Color.WHITE:
			stock_house = false
	_check(stock_house, "suburb houses keep the stock look")

	print("ThemePalettes")
	var pal_city := ThemePalettes.for_theme(0)
	var pal_mexico := ThemePalettes.for_theme(3)
	_check(pal_city.building.size() >= 6, "city palette has building colours")
	_check(pal_mexico.building.size() >= 4, "mexico palette has building colours")
	_check(pal_mexico.car_tint != Color.WHITE and pal_mexico.prop_tint != Color.WHITE, "mexico washes models")
	_check(ThemePalettes.for_theme(2) == pal_city, "night keeps the city palette")
	var keys_mexico := ["building", "car", "shirt", "car_tint", "person_tint", "prop_tint"]
	for key in keys_mexico:
		if not pal_mexico.has(key):
			_check(false, "mexico palette has %s" % key)
	_check(not pal_mexico.has("house"), "mexico palette has no house colours")

	print("ModelLibrary")
	var lib := ModelLibrary.new()
	var stock_car: Dictionary = lib.pick("car", Vector3(3, 0, 7))
	var warm_car: Dictionary = lib.pick("car", Vector3(3, 0, 7), Color(1.0, 0.9, 0.7))
	_check(stock_car.scene != warm_car.scene, "a tinted model packs its own scene")
	_check(lib.pick("car", Vector3(3, 0, 7), Color(1.0, 0.9, 0.7)).scene == warm_car.scene, "tinted scenes are cached")
	var stock_inst: Node = (stock_car.scene as PackedScene).instantiate()
	var warm_inst: Node = (warm_car.scene as PackedScene).instantiate()
	var m_stock := _first_material(stock_inst)
	var m_warm := _first_material(warm_inst)
	var tinted := m_stock != null and m_warm != null \
		and m_warm.albedo_color.is_equal_approx(m_stock.albedo_color * Color(1.0, 0.9, 0.7))
	_check(tinted, "tint multiplies the albedo")
	var stock_untouched := m_stock != null and m_stock.albedo_color.is_equal_approx(Color.WHITE)
	_check(stock_untouched, "stock materials stay untouched")
	stock_inst.free()
	warm_inst.free()
	var fitted: Dictionary = lib.pick_fit("building", Vector3(1, 0, 2), Vector3(9, 12, 9))
	var ff: float = ModelLibrary.fit_spec(fitted.aabb, Vector3(9, 12, 9)).f
	_check(absf(log(ff)) < 0.6, "picked building needs little stretch (%.2f)" % ff)
	_check(lib.pick_fit("building", Vector3(1, 0, 2), Vector3(9, 12, 9)).scene == fitted.scene,
		"fit pick is deterministic")

	print("Debris tint")
	var src := StandardMaterial3D.new()
	src.albedo_color = Color(0.8, 0.8, 0.8)
	var warm := ThemePalettes.chunk_material(src, Color(1.0, 0.5, 0.5)) as BaseMaterial3D
	var stock := ThemePalettes.chunk_material(src, Color.WHITE) as BaseMaterial3D
	_check(warm.albedo_color.is_equal_approx(Color(0.8, 0.4, 0.4)), "chunk materials take the tint")
	_check(src.albedo_color.is_equal_approx(Color(0.8, 0.8, 0.8)), "chunk source material stays untouched")
	_check(warm.cull_mode == BaseMaterial3D.CULL_DISABLED and stock != warm, "chunks stay double-sided per tint")

	print("Fracture")
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(2, 6, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	var model := Fracture.extract(mi)
	mi.free()
	var whole := Fracture.soup_aabb(model.soups)
	var pieces := Fracture.split(model.soups, 8, 42)
	_check(pieces.size() == 8, "a box splits into 8 pieces (%d)" % pieces.size())
	var area := 0.0
	var inside_box := true
	var capped := true
	for pc in pieces:
		area += _area(pc.soups)
		if not whole.grow(0.001).encloses(pc.aabb):
			inside_box = false
		if pc.cap.p.is_empty() or pc.hull.size() < 4:
			capped = false
	_check(inside_box, "pieces stay inside the model")
	_check(capped, "every piece has a cap and a hull")
	var full := _area(model.soups)
	_check(absf(area - full) < full * 0.001, "cutting keeps the surface area (%.2f of %.2f)" % [area, full])
	var again := Fracture.split(model.soups, 8, 42)
	var same := again.size() == pieces.size()
	for i in mini(again.size(), pieces.size()):
		if not again[i].aabb.is_equal_approx(pieces[i].aabb):
			same = false
	_check(same, "same seed gives the same pieces")
	var inst: Node = (load("res://assets/kenney/commercial/building-a.glb") as PackedScene).instantiate()
	var real := Fracture.split(Fracture.extract(inst).soups, 10, 7)
	inst.free()
	_check(real.size() == 10, "a real building splits into 10 pieces (%d)" % real.size())

	print("DebrisRules")
	var stack: Array[Edible] = []
	for y in 3:
		var chunk := Edible.new()
		chunk.position = Vector3(0, 1.0 + y * 2.0, 0)
		chunk.height = 2.0
		chunk.extent = 2.0
		stack.append(chunk)
	var aside := Edible.new()
	aside.position = Vector3(8, 1.0, 0)
	aside.height = 2.0
	aside.extent = 2.0
	stack.append(aside)
	DebrisRules.link_supports(stack)
	_check(stack[0].grounded and not stack[1].grounded and not stack[2].grounded, "only the bottom chunk is grounded")
	_check(stack[0].supports.has(stack[1]) and stack[1].supports.has(stack[2]), "each chunk holds up the one above")
	_check(not stack[0].supports.has(aside) and aside.supporters == 0, "a chunk aside is not held up")
	for chunk in stack:
		chunk.free()
	_check(DebrisRules.breakable_kind("building", Vector3(10, 30, 10)), "buildings break")
	_check(not DebrisRules.breakable_kind("person", Vector3.ONE), "people do not break")
	_check(not DebrisRules.breakable_kind("tree", Vector3(2, 3, 2)), "small trees do not break")

	# A chunk hanging high above another one must not be linked as resting on it.
	var loose: Array[Edible] = []
	var floor_chunk := Edible.new()
	floor_chunk.position = Vector3(0, 0.5, 0)
	floor_chunk.height = 1.0
	floor_chunk.extent = 1.0
	loose.append(floor_chunk)
	var high := Edible.new()
	high.position = Vector3(0, 12.0, 0)
	high.height = 1.0
	high.extent = 1.0
	loose.append(high)
	DebrisRules.link_supports(loose)
	_check(not floor_chunk.supports.has(high), "a chunk hanging high above is not held up by a lower one")
	for chunk in loose:
		chunk.free()

	# Chunks that touch each other's faces (no vertical overlap) still stack up.
	var touching: Array[Edible] = []
	var lower := Edible.new()
	lower.position = Vector3(0, 0.5, 0)
	lower.height = 1.0
	lower.extent = 1.0
	touching.append(lower)
	var upper := Edible.new()
	upper.position = Vector3(0, 1.55, 0)
	upper.height = 1.0
	upper.extent = 1.0
	touching.append(upper)
	DebrisRules.link_supports(touching)
	_check(lower.supports.has(upper) and upper.supporters == 1, "face-to-face neighbours stack up")
	_check(not upper.grounded, "the upper face-to-face chunk is not grounded")
	for chunk in touching:
		chunk.free()

	print("Debris weight")
	var chunk := Edible.new()
	_check(is_equal_approx(chunk.weight, 1.0), "a normal item weighs one city object")
	chunk.free()

	print("FAILED: %d" % _fails if _fails else "ALL PASSED")
	quit(1 if _fails else 0)
