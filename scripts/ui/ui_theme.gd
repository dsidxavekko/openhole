class_name UiTheme
extends RefCounted
## Shared big, touch-friendly theme built in code.


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 32

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("5e60ce")
	btn.set_corner_radius_all(18)
	btn.content_margin_left = 24
	btn.content_margin_right = 24
	btn.content_margin_top = 18
	btn.content_margin_bottom = 18
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color("6930c3")
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("48bfe3")
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 36)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.08, 0.14, 0.92)
	panel.set_corner_radius_all(24)
	panel.set_content_margin_all(32)
	t.set_stylebox("panel", "PanelContainer", panel)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.4)
	bar_bg.set_corner_radius_all(9)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("80ffdb")
	bar_fill.set_corner_radius_all(9)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(1, 1, 1, 0.12)
	edit.set_corner_radius_all(12)
	edit.set_content_margin_all(12)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit)
	return t
