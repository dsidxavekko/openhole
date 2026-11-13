class_name ThemePalettes
extends RefCounted
## Per-theme colour palettes: pure data with one lookup, no nodes and no
## autoloads, so it stays testable headless (like the rest of scripts/core).
## CityGen picks spec colours from here; EdibleFactory turns them into model
## tints (a tint MULTIPLIES the model's own colours, so Color.WHITE keeps the
## stock Kenney look). Palette lists may be any size: CityGen maps a fixed
## number of rng draws onto them, so the layout for a given seed never depends
## on the palette contents.

## City: muted pastels over the neutral commercial colormap.
const BUILDING_CITY := [Color("d8c3a5"), Color("8e8d8a"), Color("e98074"), Color("a3bcb6"),
	Color("c9ada7"), Color("f2e9e4"), Color("9a8c98"), Color("b5c99a")]
## Suburban houses are colourful out of the box: stock white, no tint.
const HOUSE_STOCK := [Color.WHITE]
## Street vehicles: bikes are primitives coloured directly; the drawn colour
## of cars is dead (their models take the car_tint wash instead).
const CAR_CITY := [Color("e63946"), Color("f1fa8c"), Color("457b9d"), Color("f4a261"),
	Color("2a9d8f"), Color("ffffff"), Color("222222"), Color("8e44ad")]
## Drawn for rng parity only; person models use person_tint.
const SHIRT_CITY := [Color("e76f51"), Color("264653"), Color("e9c46a"), Color("06d6a0"),
	Color("118ab2"), Color("ef476f")]

## Mexico City: sand, terracotta and ochre, plus a warm dust wash on everything.
const BUILDING_MEXICO := [Color("f2c193"), Color("e8a97d"), Color("f0d6b0"), Color("d99a70"),
	Color("efcaa0"), Color("e0b48c")]
const CAR_MEXICO := [Color("c25b3a"), Color("d9a45b"), Color("8a9a6b"), Color("e8d5b0"),
	Color("5d4a3a"), Color("b8b0a0"), Color("a34a2e"), Color("e0c9a0")]

const CITY := {
	"building": BUILDING_CITY,
	"house": HOUSE_STOCK,
	"car": CAR_CITY,
	"shirt": SHIRT_CITY,
	"car_tint": Color.WHITE,
	"person_tint": Color.WHITE,
	"prop_tint": Color.WHITE,
	"hydrant": Color("d62828"),
	"trash": Color("3a5a40"),
	"mailbox": Color("1d4ed8"),
}
## The suburb layout does the work there, the dim light does it at night:
## both keep the city palette.
const SUBURB := CITY
const NIGHT := CITY
const MEXICO := {
	"building": BUILDING_MEXICO,
	"car": CAR_MEXICO,
	"shirt": SHIRT_CITY,
	"car_tint": Color(1.0, 0.84, 0.62),
	"person_tint": Color(1.0, 0.88, 0.68),
	"prop_tint": Color(1.0, 0.93, 0.78),
	"hydrant": Color("d62828"),
	"trash": Color("3a5a40"),
	"mailbox": Color("b3541e"),
}


## `theme` is a GameState.MapTheme value (kept as int so core stays autoload-free).
static func for_theme(theme: int) -> Dictionary:
	match theme:
		1: return SUBURB
		2: return NIGHT
		3: return MEXICO
		_: return CITY


## A double-sided copy of `m` with the palette tint applied; the source is
## never changed. Debris chunks use this so a painted building does not pop
## back to the stock Kenney colours when it breaks.
static func chunk_material(m: Material, tint: Color) -> Material:
	if m == null:
		return null
	var c := m.duplicate() as Material
	if c is BaseMaterial3D:
		(c as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		if tint != Color.WHITE:
			(c as BaseMaterial3D).albedo_color = (c as BaseMaterial3D).albedo_color * tint
	return c
