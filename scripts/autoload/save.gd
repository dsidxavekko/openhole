extends Node
## Settings and records stored in user://save.cfg.

const PATH := "user://save.cfg"

var cfg := ConfigFile.new()


func _ready() -> void:
	cfg.load(PATH)


func get_setting(key: String, default: Variant) -> Variant:
	return cfg.get_value("settings", key, default)


func set_setting(key: String, value: Variant) -> void:
	cfg.set_value("settings", key, value)
	cfg.save(PATH)


func get_record(key: String) -> float:
	return cfg.get_value("records", key, 0)


## Returns true when `value` beats the stored record.
func submit_record(key: String, value: float) -> bool:
	if value <= get_record(key):
		return false
	cfg.set_value("records", key, value)
	cfg.save(PATH)
	return true


func add_counter(key: String, amount := 1) -> void:
	cfg.set_value("records", key, get_record(key) + amount)
	cfg.save(PATH)
