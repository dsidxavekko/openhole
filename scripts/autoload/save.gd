extends Node
## Settings and records stored in user://save.cfg.
##
## Writes are coalesced (many setters in one frame cost one disk write) and
## atomic (temp file, then rename), and a file that fails to parse is kept as
## save.cfg.bak instead of being overwritten with an empty one.

const PATH := "user://save.cfg"
const TMP_PATH := "user://save.cfg.tmp"
const BAK_PATH := "user://save.cfg.bak"

var cfg := ConfigFile.new()
var _dirty := false


func _ready() -> void:
	var err := cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		# Unreadable file: keep it for recovery and start clean.
		DirAccess.copy_absolute(PATH, BAK_PATH)
		cfg = ConfigFile.new()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PREDELETE]:
		flush()


func _queue_save() -> void:
	if _dirty:
		return
	_dirty = true
	flush.call_deferred()


## Writes pending changes now.
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	if cfg.save(TMP_PATH) == OK:
		DirAccess.rename_absolute(TMP_PATH, PATH)


func get_setting(key: String, default: Variant) -> Variant:
	return cfg.get_value("settings", key, default)


func set_setting(key: String, value: Variant) -> void:
	cfg.set_value("settings", key, value)
	_queue_save()


func get_record(key: String) -> float:
	return cfg.get_value("records", key, 0)


## Returns true when `value` beats the stored record.
func submit_record(key: String, value: float) -> bool:
	if value <= get_record(key):
		return false
	cfg.set_value("records", key, value)
	_queue_save()
	return true


func add_counter(key: String, amount := 1) -> void:
	cfg.set_value("records", key, get_record(key) + amount)
	_queue_save()
