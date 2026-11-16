class_name HelpPanel
extends VBoxContainer
## "How to play" sheet: goal, controls, power-ups, Shift and the Battle zone.

const SCROLL_HEIGHT := 760


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	add_child(UiTheme.label(tr("HELP"), 44, HORIZONTAL_ALIGNMENT_CENTER, 800))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 22)
	scroll.add_child(box)

	_section(box, "HELP_GOAL_T", "HELP_GOAL")
	_section(box, "HELP_CONTROLS_T", "HELP_CONTROLS")
	_section(box, "HELP_POWERUPS_T", "HELP_POWERUPS")
	_section(box, "HELP_SHIFT_T", "HELP_SHIFT")
	_section(box, "HELP_ZONE_T", "HELP_ZONE")


func _section(box: VBoxContainer, title_key: String, body_key: String) -> void:
	var title := UiTheme.label(tr(title_key), 32, HORIZONTAL_ALIGNMENT_LEFT, 800)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)
	var body := UiTheme.label(tr(body_key), 26, HORIZONTAL_ALIGNMENT_LEFT, 500)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 600
	box.add_child(body)
