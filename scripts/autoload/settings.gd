extends Node
## Player settings (volume, language, quality, fullscreen), stored in user://settings.cfg.

signal changed(key: StringName)

const PATH: String = "user://settings.cfg"

var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8
var language: String = "tr"
var quality: String = "high"
var fullscreen: bool = false
## False while the bot or tests run, so they never overwrite the player's file.
var persist: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--auto") or args.has("--no-save"):
		persist = false
	if persist:
		load_settings()
	for a: String in args:
		if a.begins_with("--lang="):
			language = "en" if a.trim_prefix("--lang=") == "en" else "tr"
		elif a == "--low":
			quality = "low"
	apply_window()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	var l: String = String(cfg.get_value("game", "language", language))
	language = "en" if l == "en" else "tr"
	quality = "low" if String(cfg.get_value("video", "quality", quality)) == "low" else "high"
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))


func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "language", language)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


func set_value(key: StringName, value: Variant) -> void:
	match key:
		&"master_volume":
			master_volume = clampf(float(value), 0.0, 1.0)
		&"music_volume":
			music_volume = clampf(float(value), 0.0, 1.0)
		&"sfx_volume":
			sfx_volume = clampf(float(value), 0.0, 1.0)
		&"language":
			language = "en" if String(value) == "en" else "tr"
		&"quality":
			quality = "low" if String(value) == "low" else "high"
		&"fullscreen":
			fullscreen = bool(value)
			apply_window()
		_:
			push_warning("Unknown setting %s" % key)
			return
	save_settings()
	changed.emit(key)


func is_low() -> bool:
	return quality == "low"


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
