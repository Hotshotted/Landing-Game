class_name Save
extends RefCounted
## The best run score, kept in user:// (browser storage on web). Tests switch it off.

const PATH := "user://greaser.cfg"
static var enabled := true

static func load_best() -> int:
	if not enabled:
		return 0
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value("run", "best", 0))

static func store_best(v: int) -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "best", v)
	cfg.save(PATH)
