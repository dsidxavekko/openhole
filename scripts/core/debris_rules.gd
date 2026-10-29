class_name DebrisRules
extends RefCounted
## Pure rules for breaking things into chunks (see Demolition).


static func breakable_kind(kind: String, size: Vector3) -> bool:
	match kind:
		"building", "house", "bus", "rock":
			return true
		"tree":
			return size.y >= 4.0
	return false


static func piece_count(kind: String, size: Vector3) -> int:
	match kind:
		"building":
			return clampi(roundi(pow(size.x * size.y * size.z, 1.0 / 3.0) * 0.85), 8, 16)
		"house":
			return 8
		"tree":
			return 3
	return 4


## Who holds up whom: a chunk supports the ones resting on it (just above it
## and overlapping from above). Chunks on the ground are grounded.
static func link_supports(pieces: Array[Edible]) -> void:
	for d in pieces:
		d.grounded = d.position.y - d.height * 0.5 < 0.4
	for a in pieces:
		for c in pieces:
			if a == c or a.position.y >= c.position.y:
				continue
			var a_top := a.position.y + a.height * 0.5
			var c_bottom := c.position.y - c.height * 0.5
			var flat := Vector2(a.position.x - c.position.x, a.position.z - c.position.z).length()
			if a_top > c_bottom - 0.3 and flat < (a.extent + c.extent) * 0.5:
				a.supports.append(c)
				c.supporters += 1
	for d in pieces:
		# Nothing below it at all (an overhang): the building holds it.
		if not d.grounded and d.supporters == 0:
			d.grounded = true
