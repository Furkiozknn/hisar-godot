extends Node3D
## Game flow: title -> battle -> end screen. Owns the running BattleSim, routes input
## (Input Map actions, mouse / touch picking, gamepad pad cycling) and UI actions, and
## turns simulation events into sound, toasts and camera shake. `-- --auto` lets the
## AutoBot play; see GameState for the other command-line flags.

const SPEEDS: Array[int] = [1, 2, 3]

var sim: BattleSim = null
var bot: AutoBot = null
var speed: int = 1
var paused: bool = false
var _settings_from: String = "title"
var _press_pos: Vector2 = Vector2.ZERO
var _press_valid: bool = false
var _end_timer: float = -1.0
var _fx_timer: float = 0.0
var _auto_start: float = -1.0
var _pad_order: Array[int] = []
var _rng := RandomNumberGenerator.new()

@onready var world: World = $World
@onready var battle: BattleView = $Battle
@onready var fx: Fx = $Fx
@onready var cam: CameraRig = $CameraRig
@onready var ui: Ui = $Ui
@onready var sun: DirectionalLight3D = $Sun
@onready var env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_rng.randomize()
	world.build(MapLayout.get_default())
	battle.world = world
	battle.fx = fx
	battle.shake_requested.connect(cam.shake)
	ui.action.connect(_on_action)
	Settings.changed.connect(_on_setting)
	_apply_quality()
	for i: int in range(world.layout.pads.size()):
		_pad_order.append(i)
	var pads: Array[Vector2] = world.layout.pads
	_pad_order.sort_custom(func(a: int, b: int) -> bool: return pads[a].x < pads[b].x)
	_to_title()
	if GameState.auto:
		get_window().title = "Hisar (auto)"
		if GameState.shot != "title" and GameState.shot != "settings":
			_auto_start = 0.0 if GameState.sim_seconds > 0.0 else 1.5
		if GameState.shot == "settings":
			_on_action(&"open_settings", null)


## Static caches hold meshes and materials; release them so nothing leaks at exit.
func _exit_tree() -> void:
	_stop_battle()
	Models.clear_cache()
	MeshKit.clear_cache()
	Fx.clear_cache()
	Ui.clear_cache()


# ---------------------------------------------------------------- flow
func _to_title() -> void:
	_stop_battle()
	GameState.screen = "title"
	ui.show_hud(false)
	cam.cinematic = true
	var snap: Variant = GameState.saved_run()
	var cont: int = int((snap as Dictionary).get("wave", 0)) if snap is Dictionary else 0
	ui.show_screen("title", {"best": GameState.best_wave, "continue_wave": cont})
	Sound.set_battle_music(false)


func _stop_battle() -> void:
	get_tree().paused = false
	paused = false
	battle.unbind()
	ui.bind(null)
	sim = null
	bot = null
	GameState.sim = null
	_end_timer = -1.0


func new_game(snapshot: Variant = null) -> void:
	_stop_battle()
	var seed_value: int = 20261019 if GameState.auto else _rng.randi()
	sim = BattleSim.new(GameData.load_default(), MapLayout.get_default(), seed_value)
	if snapshot is Dictionary:
		sim.load_snapshot(snapshot as Dictionary)
	GameState.sim = sim
	GameState.screen = "playing"
	GameState.count_game()
	sim.wave_started.connect(_on_wave_started)
	sim.wave_cleared.connect(_on_wave_cleared)
	sim.early_bonus_paid.connect(func(n: int) -> void: ui.toast(Loc.t("early", {"n": n})))
	sim.lives_changed.connect(_on_lives_changed)
	sim.denied.connect(func(_r: StringName) -> void:
		Sound.play("deny")
		ui.toast(Loc.t("noGold")))
	sim.tower_built.connect(func(t: BattleSim.Tower) -> void:
		Sound.play("build")
		if not GameState.auto:
			ui.toast(Loc.t("built", {"name": Loc.t(t.data.name_key)})))
	sim.tower_upgraded.connect(func(t: BattleSim.Tower) -> void:
		Sound.play("upgrade")
		ui.toast(Loc.t("upgraded", {"name": Loc.t(t.data.name_key)})))
	sim.tower_sold.connect(func(_t: BattleSim.Tower, r: int) -> void:
		Sound.play("coin")
		ui.toast(Loc.t("sold", {"n": r})))
	sim.game_ended.connect(_on_game_ended)
	battle.bind(sim)
	ui.bind(sim)
	ui.show_hud(true)
	ui.hide_screen()
	cam.cinematic = false
	cam.preset(GameState.cam_arg)
	_set_speed(GameState.start_speed if GameState.auto and GameState.start_speed > 0 else 1)
	Sound.play("horn")
	if GameState.auto:
		bot = AutoBot.new(sim)
	else:
		ui.toast(Loc.t("hint"))
	if sim.wave > 0:
		ui.toast(Loc.t("continue", {"n": sim.wave + 1}))


func _fast_forward(seconds: float) -> void:
	fx.enabled = false
	Sound.enabled = false
	var t: float = 0.0
	while t < seconds and not sim.over:
		if bot != null:
			bot.update(0.1)
		sim.advance(0.1)
		t += 0.1
	fx.enabled = true
	Sound.enabled = true
	ui.clear_toasts()
	ui.damage_flash(0.0)
	print("fast-forwarded %.0f s: wave %d, gold %d, lives %d, towers %d" % [t, sim.wave, sim.gold, sim.lives, sim.towers.size()])


func _set_speed(s: int) -> void:
	speed = s
	ui.set_speed(s)


func set_paused(on: bool) -> void:
	if sim == null or sim.over:
		return
	paused = on
	get_tree().paused = on
	GameState.screen = "paused" if on else "playing"
	ui.set_paused(on)
	if on:
		ui.show_screen("pause")
	else:
		ui.hide_screen()


func _process(delta: float) -> void:
	if _auto_start >= 0.0:
		_auto_start -= delta
		if _auto_start < 0.0:
			new_game()
			if GameState.sim_seconds > 0.0:
				_fast_forward(GameState.sim_seconds)
			_apply_shot()
	if sim == null:
		return
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer < 0.0:
			_show_end()
	if sim.over:
		_end_fx(delta)
	if paused:
		return
	var dt: float = delta * float(speed)
	if bot != null and not sim.over:
		bot.update(dt)
	sim.advance(dt)
	Sound.set_battle_music(sim.phase == &"wave" and not sim.over)


func _apply_shot() -> void:
	match GameState.shot:
		"pause":
			set_paused(true)
		"build":
			var best: int = -1
			for p: int in _pad_order:
				if sim.tower_on_pad(p) == null and (best < 0 or world.layout.pads[p].distance_to(Vector2(5, 0)) < world.layout.pads[best].distance_to(Vector2(5, 0))):
					best = p
			_select(best, true)
		"tower":
			if not sim.towers.is_empty():
				_select(sim.towers[sim.towers.size() - 1].pad, true)
		"win":
			sim.wave = sim.data.config.max_waves
			sim._end(true)
		"lose":
			sim._end(false)


# ---------------------------------------------------------------- sim events
func _on_wave_started(w: int, has_boss: bool) -> void:
	Sound.play("horn")
	if has_boss:
		Sound.play("boss")
		ui.toast(Loc.t("ramComing"))
		cam.shake(0.3)
	else:
		ui.toast("%s %d" % [Loc.t("wave"), w])


func _on_wave_cleared(_w: int, bonus: int) -> void:
	Sound.play("clear")
	ui.toast(Loc.t("cleared", {"n": bonus}))
	if not sim.over:
		GameState.save_run(sim)
	if GameState.auto:
		print("wave %d cleared: gold %d, lives %d, towers %d, kills %d" % [sim.wave, sim.gold, sim.lives, sim.towers.size(), sim.kills])


func _on_lives_changed(_lives: int, lost: int) -> void:
	if lost <= 0:
		return
	Sound.play("hurt")
	ui.damage_flash(0.5 + float(lost) * 0.1)


func _on_game_ended(won: bool) -> void:
	Sound.set_battle_music(false)
	Sound.play("win" if won else "lose")
	ui.close_panel()
	battle.show_range(-1, 0.0)
	_end_timer = 1.4
	var reached: int = sim.wave if won else sim.wave - 1
	var record: bool = GameState.record_wave(maxi(0, reached))
	GameState.clear_run()
	sim.set_meta("new_best", record)
	if GameState.auto:
		print("AUTO RESULT: %s at wave %d/%d, lives %d, kills %d, gold earned %d, towers built %d, sim time %.0f s" % [
			"WIN" if won else "LOSS", sim.wave, sim.data.config.max_waves, sim.lives, sim.kills, sim.gold_earned, sim.built, sim.time])


## After the battle: fireworks over the keep on a victory, smoke and fire on a defeat.
func _end_fx(delta: float) -> void:
	_fx_timer -= delta
	if _fx_timer > 0.0:
		return
	var p := Vector3(_rng.randf_range(26.0, 37.0), 0.0, _rng.randf_range(-8.0, 8.0))
	if sim.won:
		_fx_timer = 0.45
		fx.burst("firework", p + Vector3(0, _rng.randf_range(14.0, 20.0), 0), 1.0, Color.from_hsv(_rng.randf(), 0.75, 1.0))
		if _rng.randf() < 0.5:
			Sound.play("boom", 0.3)
	else:
		_fx_timer = 0.3
		fx.burst("blaze", p + Vector3(0, _rng.randf_range(3.0, 7.0), 0), 1.0)


func _show_end() -> void:
	GameState.screen = "over"
	ui.show_screen("over", {"won": sim.won, "wave": sim.wave, "kills": sim.kills, "gold": sim.gold_earned, "towers": sim.built, "new_best": bool(sim.get_meta("new_best", false))})
	if GameState.auto and GameState.quit_on_end:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(0))


# ---------------------------------------------------------------- UI actions
func _on_action(act: StringName, arg: Variant) -> void:
	match act:
		&"play":
			new_game()
		&"continue":
			new_game(GameState.saved_run())
		&"open_settings":
			_settings_from = ui.screen if ui.screen != "" else "title"
			ui.show_screen("settings")
		&"settings_back":
			_back_from_settings()
		&"setting":
			var pair: Array = arg
			var key: StringName = pair[0]
			var val: String = pair[1]
			if key == &"fullscreen":
				Settings.set_value(key, val == "on")
			else:
				Settings.set_value(key, val)
			ui.show_screen("settings")
		&"lang":
			Loc.toggle()
			_reshow()
		&"pause":
			set_paused(not paused)
		&"resume":
			set_paused(false)
		&"restart":
			new_game()
		&"main_menu":
			_to_title()
		&"endless":
			if sim != null and sim.won:
				sim.continue_endless()
				_end_timer = -1.0
				GameState.screen = "playing"
				ui.hide_screen()
				ui.toast(Loc.t("endlessOn"))
		&"wave":
			_start_wave()
		&"speed":
			_set_speed(SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()] if SPEEDS.has(speed) else 1)
		&"mute":
			Settings.set_value(&"master_volume", 0.8 if Settings.master_volume <= 0.001 else 0.0)
		&"build":
			_build(arg as StringName)
		&"upgrade":
			_upgrade()
		&"sell":
			_sell()
		&"mode":
			_cycle_mode()
		&"close_panel":
			_deselect()
		&"preview_range":
			if sim != null and ui.selected_pad >= 0 and sim.tower_on_pad(ui.selected_pad) == null:
				battle.show_range(ui.selected_pad if float(arg) > 0.0 else -1, float(arg))


func _back_from_settings() -> void:
	if _settings_from == "pause" and sim != null:
		ui.show_screen("pause")
	else:
		_to_title()


func _reshow() -> void:
	match ui.screen:
		"title":
			_to_title()
		"settings":
			ui.show_screen("settings")
		"pause":
			ui.show_screen("pause")
		"over":
			_show_end()


func _on_setting(key: StringName) -> void:
	if key == &"quality":
		_apply_quality()


func _apply_quality() -> void:
	var low: bool = Settings.is_low()
	sun.shadow_enabled = not low
	var vp: Viewport = get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	vp.scaling_3d_scale = 0.75 if low else 1.0
	env.environment.glow_enabled = not low
	world.apply_quality()


# ---------------------------------------------------------------- gameplay commands
func _playing() -> bool:
	return sim != null and not sim.over and not paused and not ui.overlay_open()


func _start_wave() -> void:
	if _playing():
		sim.start_wave()


func _build(type: StringName) -> void:
	if not _playing() or ui.selected_pad < 0:
		return
	if sim.tower_on_pad(ui.selected_pad) != null:
		return
	if sim.build(ui.selected_pad, type) != null:
		_select(ui.selected_pad)


func _selected_tower() -> BattleSim.Tower:
	if sim == null or ui.selected_pad < 0:
		return null
	return sim.tower_on_pad(ui.selected_pad)


func _upgrade() -> void:
	var t: BattleSim.Tower = _selected_tower()
	if _playing() and t != null and sim.upgrade(t):
		_select(t.pad)


func _sell() -> void:
	var t: BattleSim.Tower = _selected_tower()
	if _playing() and t != null:
		sim.sell(t)
		_select(t.pad)


func _cycle_mode() -> void:
	var t: BattleSim.Tower = _selected_tower()
	if _playing() and t != null:
		sim.cycle_mode(t)
		Sound.play("click")
		ui.open_pad(t.pad)


func _select(pad: int, focus_camera: bool = false) -> void:
	if sim == null or pad < 0:
		_deselect()
		return
	ui.open_pad(pad)
	battle.selected_pad = pad
	var t: BattleSim.Tower = sim.tower_on_pad(pad)
	battle.show_range(pad if t != null else -1, sim.tower_range(t) if t != null else 0.0)
	battle.refresh_pads()
	if focus_camera:
		var p: Vector2 = world.layout.pads[pad]
		cam.focus(Vector3(p.x, 0, p.y))


func _deselect() -> void:
	ui.close_panel()
	battle.selected_pad = -1
	battle.show_range(-1, 0.0)
	battle.refresh_pads()


func _cycle_pad(step: int) -> void:
	if not _playing():
		return
	var i: int = _pad_order.find(ui.selected_pad)
	i = (i + step + _pad_order.size()) % _pad_order.size() if i >= 0 else (0 if step > 0 else _pad_order.size() - 1)
	Sound.play("click")
	_select(_pad_order[i], true)


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if ui.screen == "settings":
			_back_from_settings()
		elif ui.panel_open() and not paused:
			_deselect()
		elif sim != null and not sim.over and (ui.screen == "" or ui.screen == "pause"):
			set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_language"):
		_on_action(&"lang", null)
		return
	if sim == null or ui.overlay_open():
		return
	if event is InputEventMouseMotion:
		_hover((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_handle_pointer(event)
		return
	if event.is_action_pressed("start_wave"):
		_start_wave()
	elif event.is_action_pressed("speed_toggle"):
		_on_action(&"speed", null)
	elif event.is_action_pressed("cancel"):
		_deselect()
	elif event.is_action_pressed("select"):
		# gamepad: pick the pad nearest the camera's focus point
		_select(_nearest_pad(Vector2(cam.target.x, cam.target.z), 8.0), true)
	elif event.is_action_pressed("pad_next"):
		_cycle_pad(1)
	elif event.is_action_pressed("pad_prev"):
		_cycle_pad(-1)
	elif event.is_action_pressed("upgrade"):
		_upgrade()
	elif event.is_action_pressed("sell"):
		_sell()
	elif event.is_action_pressed("target_mode"):
		_cycle_mode()
	else:
		for i: int in range(3):
			if event.is_action_pressed("build_%d" % (i + 1)):
				_build(GameData.TOWER_ORDER[i])


func _handle_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_pos = mb.position
			_press_valid = true
		elif _press_valid:
			_press_valid = false
			if mb.position.distance_to(_press_pos) < 8.0 and _playing():
				var pad: int = _pick_pad(mb.position)
				if pad >= 0:
					Sound.play("click")
					_select(pad)
				else:
					_deselect()


func _hover(pos: Vector2) -> void:
	var pad: int = _pick_pad(pos) if _playing() else -1
	if pad != battle.hover_pad:
		battle.hover_pad = pad
		battle.refresh_pads()
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if pad >= 0 else Input.CURSOR_ARROW)


## Pad under the screen point: the ray is tested against a short cylinder per pad,
## tall enough to include the tower standing on it.
func _pick_pad(screen_pos: Vector2) -> int:
	var c: Camera3D = cam.camera
	var o: Vector3 = c.project_ray_origin(screen_pos)
	var d: Vector3 = c.project_ray_normal(screen_pos)
	if d.y >= -0.001:
		return -1
	var best: int = -1
	var best_t: float = INF
	for i: int in range(world.layout.pads.size()):
		var p: Vector2 = world.layout.pads[i]
		var top: float = 0.4
		var t: BattleSim.Tower = sim.tower_on_pad(i)
		if t != null:
			top = BattleSim.PAD_BASE + t.data.stat(t.data.pivot, t.level) + 1.2
		var h: float = top
		while h >= 0.0:
			var k: float = (h - o.y) / d.y
			if k > 0.0:
				var q: Vector3 = o + d * k
				if Vector2(q.x, q.z).distance_to(p) < (1.7 if h < 0.5 else 1.3):
					if k < best_t:
						best_t = k
						best = i
					break
			h -= 0.5
	return best


func _nearest_pad(p: Vector2, max_dist: float) -> int:
	var best: int = -1
	var bd: float = max_dist
	for i: int in range(world.layout.pads.size()):
		var d: float = world.layout.pads[i].distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best
