class_name StatsPanel
extends VBoxContainer
## Player profile: lifetime counters, per-mode records and achievements.


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	add_child(UiTheme.label(tr("STATS"), 44, HORIZONTAL_ALIGNMENT_CENTER, 800))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_row(box, tr("STATS_MATCHES") % int(Save.get_record("matches")))
	_row(box, tr("STATS_CITY") % int(Save.get_record("total_eaten")))
	_row(box, tr("STATS_SHIFT_KILLS") % int(Save.get_record("shift_kills")))
	_row(box, tr("STATS_BATTLE_WINS") % int(Save.get_record("battle_wins")))
	_row(box, tr("STATS_BEST_CLASSIC") % int(Save.get_record("classic")))
	_row(box, tr("STATS_BEST_SOLO") % Save.get_record("solo"))
	_row(box, tr("STATS_STREAK") % GameState.daily_streak())
	var played := int(Save.get_record("time_played"))
	_row(box, tr("STATS_TIME") % [played / 3600, (played % 3600) / 60])

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size.y = 2
	add_child(line)
	add_child(UiTheme.label(tr("STATS_ACHIEVEMENTS"), 32, HORIZONTAL_ALIGNMENT_CENTER, 800))

	var stats := Achievements.current_stats()
	var earned := Achievements.earned_set(stats)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for i in Achievements.count():
		var got := earned.has(i)
		var text := ("✓  " if got else "•  ") + Achievements.name_of(i)
		if not got:
			text += "   " + Achievements.progress_text(i, stats)
		var row := UiTheme.label(text, 24, HORIZONTAL_ALIGNMENT_LEFT, 600 if got else 500)
		row.modulate = Color.WHITE if got else Color(1, 1, 1, 0.55)
		list.add_child(row)


func _row(box: VBoxContainer, text: String) -> void:
	var label := UiTheme.label(text, 28, HORIZONTAL_ALIGNMENT_LEFT, 600)
	box.add_child(label)
