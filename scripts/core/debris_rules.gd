class_name DebrisRules
extends RefCounted
## Pure rules for breaking things into chunks (see Demolition).

## Downward slack (m) allowed between two chunks that still count as stacked:
## Voronoi chunks of one building pile up loosely and touch faces, so the top of
## a lower chunk may sit slightly under the bottom of the one above it. It must
## stay small: a big value links chunks that are far apart in the pile.
const GAP_SLACK := 0.45


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
			if a == c or not _is_below(a, c):
				continue
			var lo_top := a.position.y + a.height * 0.5
			var c_bottom := c.position.y - c.height * 0.5
			var flat := Vector2(a.position.x - c.position.x, a.position.z - c.position.z).length()
			# Neighbours that are not quite touching still count: Voronoi chunks of
			# one building pile up loosely and only touch faces. The slack is small,
			# so a chunk hanging high above a lower one is not mistaken for resting
			# on it (that was the reason whole upper floors stayed up in mid-air).
			if flat >= (a.extent + c.extent) * 0.5:
				continue
			if lo_top > c_bottom - GAP_SLACK:
				a.supports.append(c)
				c.supporters += 1
	for d in pieces:
		# Nothing below it at all (an overhang): the building holds it.
		if not d.grounded and d.supporters == 0:
			d.grounded = true


## True when `a` sits below `c`; chunks at the same height never hold each other.
static func _is_below(a: Edible, c: Edible) -> bool:
	if is_equal_approx(a.position.y, c.position.y):
		return false
	return a.position.y < c.position.y
