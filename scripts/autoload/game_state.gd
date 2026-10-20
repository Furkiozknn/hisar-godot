extends Node
## Session state shared by every scene: command-line flags, the running battle, the save
## file (best wave + the run in progress, written after each cleared wave) and a JSON
## state dump for tests and debugging.

const SAVE_PATH: String = "user://hisar_save.cfg"

## "title", "playing", "paused", "over"
var screen: String = "title"
var sim: BattleSim = null
var best_wave: int = 0

# command-line flags (pass after "--": godot --path . -- --auto --sim=300)
var auto: bool = false
var sim_seconds: float = 0.0
var start_speed: int = 0
var shot: String = ""
var cam_arg: String = ""
var quit_on_end: bool = false
var persist: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--sim="):
			sim_seconds = maxf(0.0, a.trim_prefix("--sim=").to_float())
		elif a.begins_with("--speed="):
			start_speed = clampi(a.trim_prefix("--speed=").to_int(), 1, 50)
		elif a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
		elif a.begins_with("--cam="):
			cam_arg = a.trim_prefix("--cam=")
		elif a == "--quit-on-end":
			quit_on_end = true
		elif a == "--no-save":
			persist = false
		elif a == "--noassets":
			# the procedural models and vector icons, as before the asset remaster
			Models.use_assets = false
			Icon.use_png = false
	if auto:
		persist = false
	load_save()


func load_save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_wave = int(cfg.get_value("stats", "best_wave", 0))


func _write(run: Variant) -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("stats", "best_wave", best_wave)
	if cfg.has_section_key("stats", "games_played"):
		cfg.erase_section_key("stats", "games_played")
	if run == null:
		if cfg.has_section("run"):
			cfg.erase_section("run")
	else:
		cfg.set_value("run", "snapshot", run)
	cfg.save(SAVE_PATH)


## Returns true when this is a new record. Called after every cleared wave and at the end.
func record_wave(w: int) -> bool:
	if w > best_wave:
		best_wave = w
		_write(saved_run() if persist else null)
		return true
	return false


func save_run(s: BattleSim) -> void:
	_write(s.to_snapshot())


func clear_run() -> void:
	_write(null)


func saved_run() -> Variant:
	if not persist:
		return null
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section_key("run", "snapshot"):
		return null
	var snap: Variant = cfg.get_value("run", "snapshot")
	if snap is Dictionary and int((snap as Dictionary).get("version", 0)) == 1:
		return snap
	return null


## Current state as JSON (screen, wave, gold, lives, towers, enemies...).
func get_state_text() -> String:
	var d: Dictionary = {"screen": screen, "lang": Settings.language, "quality": Settings.quality, "best_wave": best_wave, "auto": auto}
	if sim != null:
		var tw: Array = []
		for t: BattleSim.Tower in sim.towers:
			tw.append({"type": String(t.type), "level": t.level + 1, "pad": t.pad, "mode": String(t.mode), "kills": t.kills})
		var en: Dictionary = {}
		for e: BattleSim.Enemy in sim.enemies:
			en[String(e.type)] = int(en.get(String(e.type), 0)) + 1
		var b: BattleSim.Enemy = sim.boss()
		d.merge({
			"wave": sim.wave, "max_waves": sim.data.config.max_waves, "phase": String(sim.phase),
			"gold": sim.gold, "lives": sim.lives, "kills": sim.kills, "gold_earned": sim.gold_earned,
			"towers_built": sim.built, "towers": tw, "enemies": en, "enemies_alive": sim.enemies.size(),
			"queued": sim.queue.size(), "projectiles": sim.arrows.size() + sim.shells.size(),
			"boss_hp": (b.hp / b.max_hp) if b != null else -1.0,
			"over": sim.over, "won": sim.won, "endless": sim.endless, "time": snappedf(sim.time, 0.01),
		})
	return JSON.stringify(d)
