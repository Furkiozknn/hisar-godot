extends Node
## Headless unit tests for the core rules.
## godot_console --headless --path . --scene res://tests/run_tests.tscn

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _ready() -> void:
	Settings.persist = false
	GameState.persist = false
	var tests: Array[String] = []
	for m: Dictionary in get_method_list():
		var n: String = String(m["name"])
		if n.begins_with("test_"):
			tests.append(n)
	tests.sort()
	for n: String in tests:
		_current = n
		call(n)
	var total: int = _passed + _failed
	if _failed == 0:
		print("TESTS PASSED %d/%d" % [_passed, total])
	else:
		print("TESTS FAILED %d/%d" % [_failed, total])
	get_tree().quit(0 if _failed == 0 else 1)


func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL [%s] %s" % [_current, label])


func near(a: float, b: float, label: String, eps: float = 0.001) -> void:
	check(absf(a - b) <= eps, "%s: expected %s, got %s" % [label, b, a])


func _sim() -> BattleSim:
	return BattleSim.new(GameData.load_default(), MapLayout.get_default(), 99)


# ---------------------------------------------------------------- data
func test_data_loads() -> void:
	var d: GameData = GameData.load_default()
	check(d.towers.size() == 3, "three towers")
	check(d.enemies.size() == 4, "four enemies")
	check(d.config.max_waves == 15, "15 waves")
	check(d.config.start_gold == 180 and d.config.start_lives == 20, "start gold and lives")
	for t: TowerData in d.towers.values():
		check(t.levels() == 3 and t.reach.size() == 3 and t.rate.size() == 3 and t.pivot.size() == 3, "%s has 3 levels" % t.id)
	check((d.enemy(&"ram") as EnemyData).is_boss, "ram is the boss")
	check(d.enemy(&"ram").lives == 6, "ram costs 6 lives")


func test_strings_complete() -> void:
	var table: LocaleTable = load("res://data/strings.tres") as LocaleTable
	for k: Variant in table.tr_text:
		check(table.en_text.has(k), "en has %s" % k)
	for k: Variant in table.en_text:
		check(table.tr_text.has(k), "tr has %s" % k)
	Settings.language = "en"
	check(Loc.t("cleared", {"n": 42}) == "Wave cleared! +42 gold", "placeholder fill en")
	Settings.language = "tr"
	check(Loc.t("play") == "Başla", "turkish text")


# ---------------------------------------------------------------- waves
func test_hp_multiplier() -> void:
	var s: BattleSim = _sim()
	near(s.hp_multiplier(1), 1.0, "wave 1")
	near(s.hp_multiplier(15), 1.0 + 0.18 * 14.0 + 0.022 * 196.0, "wave 15")


func test_wave_composition() -> void:
	var s: BattleSim = _sim()
	var w1: Dictionary = s.wave_counts(1)
	check(int(w1.get(&"raider", 0)) == 6 and w1.size() == 1, "wave 1 is 6 raiders")
	var w3: Dictionary = s.wave_counts(3)
	check(int(w3.get(&"rider", 0)) == 4, "wave 3 has 4 riders")
	var w4: Dictionary = s.wave_counts(4)
	check(int(w4.get(&"raider", 0)) == 5 + 6 + 3 + 4, "wave 4 has two raider groups")
	check(not w4.has(&"ram"), "no ram on wave 4")
	check(int(s.wave_counts(5).get(&"ram", 0)) == 1, "one ram on wave 5")
	check(int(s.wave_counts(10).get(&"ram", 0)) == 2, "two rams on wave 10")
	check(int(s.wave_counts(15).get(&"ram", 0)) == 3, "three rams on wave 15")
	check(int(s.wave_counts(5).get(&"shield", 0)) == 1, "one shieldbearer on wave 5")
	var list: Array[Dictionary] = s.make_wave(7)
	var sorted: bool = true
	for i: int in range(1, list.size()):
		if float(list[i]["t"]) < float(list[i - 1]["t"]):
			sorted = false
	check(sorted, "spawn list sorted by time")
	check(int(list[0]["path"]) != int(list[1]["path"]), "enemies alternate roads")


func test_bonuses() -> void:
	var s: BattleSim = _sim()
	check(s.clear_bonus(1) == 18 and s.clear_bonus(10) == 45, "clear bonus")
	check(s.early_bonus(3) == 14, "early bonus")


# ---------------------------------------------------------------- map
func test_paths_end_at_gate() -> void:
	var m: MapLayout = MapLayout.get_default()
	check(m.paths.size() == 2, "two roads")
	for p: GamePath in m.paths:
		check(p.length > 60.0, "road is long")
		check(p.point_at(p.length).distance_to(Vector2(25.5, 0)) < 0.01, "road ends at the gate")
		check(p.point_at(0).distance_to(Vector2(-48, p.point_at(0).y)) < 0.01, "road starts in the west")
		near(p.tangent_at(10.0).length(), 1.0, "unit tangent")


func test_pads_are_valid() -> void:
	var m: MapLayout = MapLayout.get_default()
	check(m.pads.size() >= 16, "enough pads (%d)" % m.pads.size())
	var ok_road: bool = true
	var ok_gap: bool = true
	var ok_fort: bool = true
	for i: int in range(m.pads.size()):
		var p: Vector2 = m.pads[i]
		if m.exact_dist_to_road(p.x, p.y) < 3.4:
			ok_road = false
		if MapLayout.in_fortress(p.x, p.y, 1.0):
			ok_fort = false
		for j: int in range(i + 1, m.pads.size()):
			if p.distance_to(m.pads[j]) < 4.6:
				ok_gap = false
	check(ok_road, "pads keep off the road")
	check(ok_gap, "pads keep their spacing")
	check(ok_fort, "no pad inside the fortress")
	near(m.dist_to_road(m.pads[0].x, m.pads[0].y), m.exact_dist_to_road(m.pads[0].x, m.pads[0].y), "grid distance close to exact", 0.6)
	check(absf(m.height_at(m.pads[0].x, m.pads[0].y)) < 0.3, "pads stand on flat ground")


# ---------------------------------------------------------------- towers
func test_build_upgrade_sell() -> void:
	var s: BattleSim = _sim()
	var t: BattleSim.Tower = s.build(0, &"archer")
	check(t != null and s.gold == 120, "build costs 60")
	check(s.build(0, &"cannon") == null, "pad already taken")
	check(s.upgrade(t) and s.gold == 30 and t.level == 1, "upgrade costs 90")
	check(not s.upgrade(t) and t.level == 1, "cannot afford level 3")
	s.gold = 1000
	check(s.upgrade(t) and t.level == 2, "level 3")
	check(not s.upgrade(t), "max level")
	check(s.upgrade_cost(t) == -1, "no further cost")
	var before: int = s.gold
	var r: int = s.sell(t)
	check(r == floori((60 + 90 + 140) * 0.7), "70% refund")
	check(s.gold == before + r and s.tower_on_pad(0) == null, "pad free after sale")
	check(s.built == 1, "built counter")


func test_build_denied_without_gold() -> void:
	var s: BattleSim = _sim()
	s.gold = 50
	var denied: Array[StringName] = []
	s.denied.connect(func(reason: StringName) -> void: denied.append(reason))
	check(s.build(1, &"archer") == null, "not enough gold")
	check(denied.size() == 1 and denied[0] == &"gold", "denied signal")
	check(s.gold == 50, "gold unchanged")


func test_armour() -> void:
	near(BattleSim.armored_damage(15.0, 0.55, &"arrow"), 6.75, "arrow vs shield")
	near(BattleSim.armored_damage(40.0, 0.55, &"ball"), 40.0 * (1.0 - 0.275), "ball vs shield")
	near(BattleSim.armored_damage(8.0, 0.55, &"dot"), 8.0, "burn ignores armour")


func test_target_modes() -> void:
	var s: BattleSim = _sim()
	s.wave = 1
	var t: BattleSim.Tower = s.build(0, &"archer")
	var p: Vector2 = s.layout.pads[0]
	var a: BattleSim.Enemy = s.spawn(&"raider", 0)
	var b: BattleSim.Enemy = s.spawn(&"shield", 0)
	a.pos = p + Vector2(2, 0)
	a.d = 50.0
	b.pos = p + Vector2(6, 0)
	b.d = 10.0
	check(s.find_target(t) == a, "first = furthest along the road")
	s.cycle_mode(t)
	check(t.mode == &"strong" and s.find_target(t) == b, "strongest = most hp")
	s.cycle_mode(t)
	b.pos = p + Vector2(1, 0)
	check(t.mode == &"near" and s.find_target(t) == b, "nearest")
	b.pos = p + Vector2(40, 0)
	a.pos = p + Vector2(40, 0)
	check(s.find_target(t) == null, "nothing in range")


# ---------------------------------------------------------------- battle flow
func test_wave_flow_and_bonus() -> void:
	var s: BattleSim = _sim()
	var cleared: Array[int] = []
	s.wave_cleared.connect(func(w: int, _b: int) -> void: cleared.append(w))
	check(s.start_wave(), "start wave 1")
	check(not s.start_wave(), "cannot call while spawning")
	# kill every enemy as soon as it spawns
	var guard: int = 0
	while s.phase == &"wave" and guard < 4000:
		s.advance(0.1)
		for e: BattleSim.Enemy in s.enemies:
			s.damage(e, 9999.0, null, &"dot")
		guard += 1
	check(cleared == [1], "wave 1 cleared")
	check(s.kills == 6, "six kills")
	check(s.gold == 180 + 6 * 5 + 18, "kill gold + clear bonus")
	check(s.lives == 20, "no lives lost")


func test_early_call_bonus() -> void:
	var s: BattleSim = _sim()
	s.start_wave()
	while not s.queue.is_empty():
		s.advance(0.2)
	var g: int = s.gold
	check(not s.enemies.is_empty(), "enemies still marching")
	check(s.start_wave() and s.wave == 2, "early call")
	check(s.gold == g + s.early_bonus(1), "early bonus paid")
	check(s.pending_bonus == s.clear_bonus(1) + s.clear_bonus(2), "clear bonuses stack")


func test_leak_costs_lives_and_ends_game() -> void:
	var s: BattleSim = _sim()
	s.wave = 1
	var ended: Array[bool] = []
	s.game_ended.connect(func(w: bool) -> void: ended.append(w))
	var ram: BattleSim.Enemy = s.spawn(&"ram", 0)
	ram.d = ram.path.length - 0.01
	s.advance(0.05)
	check(s.lives == 14, "ram costs 6 lives")
	s.lives = 1
	var r: BattleSim.Enemy = s.spawn(&"raider", 1)
	r.d = r.path.length - 0.01
	s.advance(0.05)
	check(s.lives == 0 and s.over and not s.won, "game over at 0 lives")
	check(ended == [false], "game_ended(false) once")


func test_cannon_splash() -> void:
	var s: BattleSim = _sim()
	s.wave = 1
	var t: BattleSim.Tower = s.build(0, &"cannon")
	var e1: BattleSim.Enemy = s.spawn(&"raider", 0)
	var e2: BattleSim.Enemy = s.spawn(&"raider", 0)
	var sh := BattleSim.Shell.new()
	sh.kind = &"ball"
	sh.tower = t
	sh.to = Vector2(0, 0)
	e1.pos = Vector2(0, 0)
	e2.pos = Vector2(1.2, 0)
	s._land(sh)
	near(e1.max_hp - e1.hp, 40.0, "full damage at the centre")
	near(e2.max_hp - e2.hp, 40.0 * (1.0 - 0.45 * 1.2 / 2.4), "falloff with distance")


func test_tar_slows_and_burns() -> void:
	var s: BattleSim = _sim()
	s.wave = 1
	var t: BattleSim.Tower = s.build(0, &"tar")
	var e: BattleSim.Enemy = s.spawn(&"raider", 0)
	var sh := BattleSim.Shell.new()
	sh.kind = &"tar"
	sh.tower = t
	sh.to = e.pos
	s._land(sh)
	near(e.slow_f, 0.55, "slowed to 55%")
	check(e.dot_t > 0.0 and e.dot_dps == 8.0, "burning")
	check(s.puddles.size() == 1, "tar puddle left on the road")
	near(e.current_speed(), e.speed * 0.55, "moves slower")


func test_projectiles_hit() -> void:
	var s: BattleSim = _sim()
	s.wave = 1
	var t: BattleSim.Tower = s.build(0, &"archer")
	var e: BattleSim.Enemy = s.spawn(&"raider", 0)
	e.speed = 0.0
	e.d = 0.0
	var pad: Vector2 = s.layout.pads[0]
	# park the raider next to the tower by moving its road position by hand
	s.towers[0].cd = 0.0
	e.pos = pad + Vector2(3, 0)
	s._fire(t, e)
	check(s.arrows.size() == 1, "arrow in flight")
	for i: int in range(40):
		s._update_arrows(0.025)
	check(s.arrows.is_empty(), "arrow landed")
	near(e.max_hp - e.hp, 15.0, "arrow damage")


func test_snapshot_roundtrip() -> void:
	var s: BattleSim = _sim()
	s.gold = 900
	var t: BattleSim.Tower = s.build(2, &"cannon")
	s.upgrade(t)
	s.cycle_mode(t)
	s.wave = 6
	s.kills = 77
	var snap: Dictionary = s.to_snapshot()
	var json: String = JSON.stringify(snap)
	var back: Dictionary = JSON.parse_string(json) as Dictionary
	var s2: BattleSim = _sim()
	check(s2.load_snapshot(back), "snapshot loads")
	check(s2.wave == 6 and s2.gold == s.gold and s2.kills == 77, "numbers restored")
	var t2: BattleSim.Tower = s2.tower_on_pad(2)
	check(t2 != null and t2.type == &"cannon" and t2.level == 1 and t2.mode == &"strong", "tower restored")
	check(not s2.load_snapshot({"version": 99}), "unknown version rejected")


func test_state_text_is_json() -> void:
	var s: BattleSim = _sim()
	GameState.sim = s
	var d: Variant = JSON.parse_string(GameState.get_state_text())
	check(d is Dictionary, "valid JSON")
	if d is Dictionary:
		var dict: Dictionary = d
		check(dict.has("gold") and dict.has("lives") and dict.has("wave") and dict.has("screen"), "has core keys")
	GameState.sim = null


func test_synth_wav() -> void:
	var b: PackedFloat32Array = Synth.buffer(0.1)
	Synth.tone(b, 0, 0.1, 440, 0, &"sine", 0.5)
	var w: AudioStreamWAV = Synth.to_wav(b)
	check(w.data.size() == b.size() * 2, "16-bit mono data")
	check(absf(w.get_length() - 0.1) < 0.01, "length 0.1 s")


# ---------------------------------------------------------------- view helpers
func test_models_build() -> void:
	for type: StringName in GameData.ENEMY_ORDER:
		check(Models.enemy(type).get_surface_count() == 1, "enemy model %s" % type)
	for type: StringName in GameData.TOWER_ORDER:
		for lv: int in range(3):
			var base: ArrayMesh = Models.tower_base(type, lv)
			check(base.get_surface_count() == 1 and Models.tower_head(type, lv).get_surface_count() == 1, "tower model %s L%d" % [type, lv + 1])
	var l1: int = (Models.tower_base(&"archer", 0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var l3: int = (Models.tower_base(&"archer", 2).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	check(l3 > l1, "higher levels add detail")
	check(Models.enemy(&"raider") == Models.enemy(&"raider"), "models are cached")
	Models.clear_cache()
	MeshKit.clear_cache()


func test_mesh_kit_faces_up() -> void:
	var k := MeshKit.new()
	k.tri(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Color.WHITE, Color.WHITE, Color.WHITE)
	var m: ArrayMesh = k.commit()
	var n: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(n.size() == 3 and n[0].y > 0.99, "clockwise-from-above triangle faces up")
	var box: ArrayMesh = MeshKit.new().box(Vector3.ONE, Color.RED).commit()
	var verts: PackedVector3Array = box.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = box.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var outward: bool = true
	for i: int in range(verts.size()):
		if verts[i].dot(normals[i]) <= 0.0:
			outward = false
	check(verts.size() == 36 and outward, "box faces point outward")
	MeshKit.clear_cache()


func test_ui_number_format() -> void:
	check(Ui._fmt(7.0) == "7" and Ui._fmt(7.5) == "7.5" and Ui._fmt(1.0 / 0.45) == "2.2", "stat formatting")


func test_zz_bot_plays_full_game() -> void:
	var s: BattleSim = _sim()
	var bot := AutoBot.new(s)
	var t: float = 0.0
	while not s.over and t < 3000.0:
		bot.update(0.1)
		s.advance(0.1)
		t += 0.1
	print("BOT (unit test): wave %d, lives %d, won %s, towers %d, sim time %.0f s" % [s.wave, s.lives, s.won, s.towers.size(), s.time])
	check(s.over, "game finished")
	check(s.wave >= 10, "bot reaches at least wave 10")
