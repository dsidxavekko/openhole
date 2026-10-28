class_name UiTheme
extends RefCounted
## Shared big, touch-friendly theme built in code, plus reusable style boxes.

const FONT_PATH := "res://assets/fonts/Rubik.ttf"

const ACCENT := Color("80ffdb")
const BUTTON := Color("5e60ce")
const BUTTON_PRESSED := Color("48bfe3")
const PANEL := Color(0.08, 0.08, 0.16, 0.94)
const CARD_CLASSIC := Color("1fb5a8")
const CARD_SOLO := Color("f4a300")
const CARD_BATTLE := Color("e5383b")
const CARD_DAILY := Color("7b4fd6")

static var _font_cache := {}


## Rubik at the given weight (400 regular .. 900 black). Null if the font is missing.
static func font(weight := 500) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var f: Font = null
	if ResourceLoader.exists(FONT_PATH):
		var base: FontFile = load(FONT_PATH)
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = v
	_font_cache[weight] = f
	return f


static func clear_cache() -> void:
	_font_cache.clear()


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 32
	var f := font(500)
	if f:
		t.default_font = f
		t.set_font("font", "Button", font(700))

	var btn := rounded(BUTTON, 22)
	btn.border_width_bottom = 6
	btn.border_color = BUTTON.darkened(0.35)
	btn.content_margin_left = 24
	btn.content_margin_right = 24
	btn.content_margin_top = 16
	btn.content_margin_bottom = 16
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = BUTTON.lightened(0.08)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = BUTTON_PRESSED
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 20
	pressed.content_margin_bottom = 12
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", btn)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 34)

	var panel := rounded(PANEL, 28)
	panel.set_content_margin_all(32)
	t.set_stylebox("panel", "PanelContainer", panel)

	var bar_bg := rounded(Color(0, 0, 0, 0.45), 9)
	var bar_fill := rounded(ACCENT, 9)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var edit := rounded(Color(1, 1, 1, 0.12), 14)
	edit.set_content_margin_all(14)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit)
	t.set_stylebox("read_only", "LineEdit", rounded(Color(1, 1, 1, 0.05), 14))

	var slider := rounded(Color(1, 1, 1, 0.18), 6)
	slider.content_margin_top = 6
	slider.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider)
	var fill := rounded(ACCENT, 6)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot_texture(44, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(44, ACCENT.lightened(0.5)))

	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	return t


static func rounded(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


## Big coloured card with a darker "3D" bottom edge.
static func card(color: Color, pressed := false) -> StyleBoxFlat:
	var s := rounded(color.darkened(0.1) if pressed else color, 30)
	s.border_width_bottom = 3 if pressed else 10
	s.border_color = color.darkened(0.4)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 22 + (7 if pressed else 0)
	s.content_margin_bottom = 22 - (7 if pressed else 0) + 8
	return s


## Round icon button background.
static func round_button(color: Color) -> StyleBoxFlat:
	var s := rounded(color, 999)
	s.border_width_bottom = 6
	s.border_color = color.darkened(0.4)
	return s


## Panel sliding in from the bottom of the screen.
static func sheet() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.18, 0.98)
	s.corner_radius_top_left = 36
	s.corner_radius_top_right = 36
	s.anti_aliasing = true
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 36
	s.content_margin_bottom = 48
	return s


## Applies a style box to all button states (with a darker pressed state).
static func style_button(b: Button, normal: StyleBox, pressed: StyleBox = null) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", pressed if pressed else normal)
	b.add_theme_stylebox_override("hover_pressed", pressed if pressed else normal)


static func _dot_texture(size: int, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


## Labels with outline, used all over the HUD and menu.
static func label(text: String, size: int, align := HORIZONTAL_ALIGNMENT_CENTER, weight := 500) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	var f := font(weight)
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Keeps a full-rect control out of the phone's camera cut-out and gesture bar.
static func apply_safe_area(c: Control) -> void:
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0 or safe.size.y <= 0:
		return
	var k := c.get_viewport().get_visible_rect().size.y / float(win.y)
	c.offset_top = safe.position.y * k
	c.offset_bottom = -(win.y - safe.end.y) * k


## Small press "spring" animation, used by cards and buttons.
static func bounce(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.94, 0.94), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
