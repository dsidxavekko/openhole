class_name StatsPanel
extends VBoxContainer
## Player profile: lifetime counters and per-mode records.


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


func _row(box: VBoxContainer, text: String) -> void:
	var label := UiTheme.label(text, 28, HORIZONTAL_ALIGNMENT_LEFT, 600)
	box.add_child(label)
