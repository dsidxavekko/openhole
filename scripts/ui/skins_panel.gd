class_name SkinsPanel
extends VBoxContainer
## Grid of hole skins. Tap an unlocked one to wear it; locked ones show their condition.

signal changed

var _grid: GridContainer
var _name: Label
var _status: Label
var _shown := 0


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	add_child(UiTheme.label(tr("SKINS"), 44, HORIZONTAL_ALIGNMENT_CENTER, 800))
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_grid)
	_name = UiTheme.label("", 38, HORIZONTAL_ALIGNMENT_CENTER, 800)
	add_child(_name)
	_status = UiTheme.label("", 28, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_shown = GameState.skin
	_build_grid()


func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for i in Skins.count():
		var b := Button.new()
		b.custom_minimum_size = Vector2(108, 108)
		var selected := i == GameState.skin
		var bg := UiTheme.rounded(Color(1, 1, 1, 0.16 if i == _shown else 0.06), 24)
		if selected:
			bg.border_color = UiTheme.ACCENT
			bg.set_border_width_all(5)
		UiTheme.style_button(b, bg)
		var prev := SkinPreview.new()
		prev.skin = i
		prev.locked = not Skins.is_unlocked(i)
		prev.set_anchors_preset(Control.PRESET_FULL_RECT)
		prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(prev)
		b.pressed.connect(_pick.bind(i))
		_grid.add_child(b)
	_update_info()


func _pick(i: int) -> void:
	_shown = i
	if Skins.is_unlocked(i):
		GameState.set_option("skin", "skin", i)
		Sfx.play("powerup", 1.4, -6.0)
		changed.emit()
	else:
		Sfx.play("ui", 0.7)
	_build_grid()


func _update_info() -> void:
	var sk := Skins.get_skin(_shown)
	_name.text = tr(sk.name)
	_name.add_theme_color_override("font_color", (sk.color as Color).lightened(0.2))
	if not Skins.is_unlocked(_shown):
		_status.text = Skins.need_text(_shown)
		_status.modulate = Color(1, 1, 1, 0.7)
	else:
		_status.text = tr("SELECTED") if _shown == GameState.skin else ""
		_status.modulate = Color.WHITE


## A hole seen from above with the skin's rim, roughly matching ground.gdshader.
class SkinPreview extends Control:
	var skin := 0
	var locked := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var p: int = Skins.get_skin(skin).pattern
		if p != Skins.Pattern.SOLID and p != Skins.Pattern.DOTS:
			queue_redraw()

	func _draw() -> void:
		var sk := Skins.get_skin(skin)
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.36
		var col: Color = sk.color
		draw_circle(c, r + 2.0, Color(0, 0, 0, 0.35))
		var seg := 48
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var am := (a0 + a1) / 2.0
			var k := col
			match sk.pattern:
				Skins.Pattern.STRIPES:
					var x := fposmod(am / TAU * 16.0 + _t * 0.25, 1.0)
					k = col.darkened(0.65) if x < 0.25 else col
				Skins.Pattern.DOTS:
					k = col.darkened(0.5) if i % 3 != 0 else col.lightened(0.35)
				Skins.Pattern.RAINBOW:
					k = Color.from_hsv(fposmod(am / TAU + _t * 0.15, 1.0), 0.85, 1.0)
				Skins.Pattern.PULSE:
					k = col.darkened(0.55).lerp(col.lightened(0.3), 0.5 + 0.5 * sin(_t * 5.0))
				Skins.Pattern.SHIMMER:
					k = col.lerp(Color.WHITE, smoothstep(0.8, 1.0, cos(am - _t * 2.5)) * 0.85)
			draw_arc(c, r, a0, a1 + 0.02, 3, k, r * 0.28, true)
		draw_circle(c, r * 0.86, Color(0.03, 0.02, 0.06))
		draw_circle(c, r * 0.55, Color(0, 0, 0))
		if locked:
			draw_circle(c, r * 1.2, Color(0.05, 0.05, 0.12, 0.6))
			# Padlock.
			var w := r * 0.7
			draw_arc(c + Vector2(0, -r * 0.12), w * 0.36, PI, TAU, 16, Color.WHITE, 5.0, true)
			draw_rect(Rect2(c.x - w / 2.0, c.y - r * 0.1, w, w * 0.75), Color.WHITE)
