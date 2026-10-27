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
	_check(HoleRules.can_eat_hole(3.0, 1.0, 0.5), "big hole eats small hole on top of it")
	_check(not HoleRules.can_eat_hole(3.0, 2.8, 0.0), "similar sizes do not eat each other")
	_check(not HoleRules.can_eat_hole(3.0, 1.0, 5.0), "far holes do not eat")

	print("CityGen")
	var a := CityGen.generate(42, 5, 0)
	var b := CityGen.generate(42, 5, 0)
	var c := CityGen.generate(43, 5, 0)
	var s := CityGen.generate(42, 5, 1)
	_check(a.size() > 300, "city has many objects (%d)" % a.size())
	_check(_hash(a) == _hash(b), "same seed gives same city")
	_check(_hash(a) != _hash(c), "different seed gives different city")
	_check(_hash(a) != _hash(s), "suburb theme differs from city")
	var half := CityGen.map_extent(5) / 2.0
	var inside := true
	for sp in a:
		if absf(sp.p.x) > half or absf(sp.p.z) > half:
			inside = false
	_check(inside, "everything is inside the map")

	print("FAILED: %d" % _fails if _fails else "ALL PASSED")
	quit(1 if _fails else 0)
