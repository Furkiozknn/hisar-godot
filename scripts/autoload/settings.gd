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
## M and X keys: music / sound effects switched off (the volumes are kept).
var music_muted: bool = false
var sfx_muted: bool = false
## Master volume to restore when the HUD sound button unmutes.
var _unmute_volume: float = 0.8
## False while the bot or tests run, so they never overwrite the player's file.
var persist: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--auto") or args.has("--no-save"):
		persist = false
	# first run: language from the OS, Low quality on phones and tablets
	language = "tr" if OS.get_locale_language() == "tr" else "en"
	quality = "low" if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") else "high"
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
	music_muted = bool(cfg.get_value("audio", "music_muted", false))
	sfx_muted = bool(cfg.get_value("audio", "sfx_muted", false))
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
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.set_value("audio", "sfx_muted", sfx_muted)
	cfg.set_value("game", "language", language)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


## Changes one setting and tells listeners; `save` false defers the file write (slider drags).
func set_value(key: StringName, value: Variant, save: bool = true) -> void:
	match key:
		&"master_volume":
			master_volume = clampf(float(value), 0.0, 1.0)
		&"music_volume":
			music_volume = clampf(float(value), 0.0, 1.0)
		&"sfx_volume":
			sfx_volume = clampf(float(value), 0.0, 1.0)
		&"music_muted":
			music_muted = bool(value)
		&"sfx_muted":
			sfx_muted = bool(value)
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
	if save:
		save_settings()
	changed.emit(key)


## HUD sound button: mute, or bring back the volume from before the mute.
func toggle_mute() -> void:
	if master_volume > 0.001:
		_unmute_volume = master_volume
		set_value(&"master_volume", 0.0)
	else:
		set_value(&"master_volume", _unmute_volume if _unmute_volume > 0.001 else 0.8)


func is_low() -> bool:
	return quality == "low"


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
