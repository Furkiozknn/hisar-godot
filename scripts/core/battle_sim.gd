class_name BattleSim
extends RefCounted
## The complete tower-defense rules, with no rendering. The view, audio and UI only
## listen to the signals and read the public state, so tests and the fast-forward bot
## run exactly the same code as the game.

signal wave_started(wave: int, has_boss: bool)
signal wave_cleared(wave: int, bonus: int)
signal early_bonus_paid(amount: int)
signal enemy_spawned(e: Enemy)
signal enemy_killed(e: Enemy)
signal enemy_leaked(e: Enemy)
signal tower_built(t: Tower)
signal tower_upgraded(t: Tower)
signal tower_sold(t: Tower, refund: int)
signal tower_fired(t: Tower, target: Enemy)
signal arrow_hit(at: Vector3)
signal shell_landed(kind: StringName, at: Vector2, radius: float)
signal gold_changed(gold: int)
signal lives_changed(lives: int, lost: int)
signal denied(reason: StringName)
signal game_ended(won: bool)

const STEP: float = 0.025
const ARROW_SPEED: float = 32.0
const MODES: Array[StringName] = [&"first", &"strong", &"near"]
const PAD_BASE: float = 0.3


class Enemy:
	extends RefCounted
	var uid: int = 0
	var type: StringName
	var data: EnemyData
	var path: GamePath
	var path_idx: int = 0
	var d: float = 0.0
	var lane: float = 0.0
	var hp: float = 1.0
	var max_hp: float = 1.0
	var speed: float = 1.0
	var gold: int = 0
	var alive: bool = true
	var pos: Vector2 = Vector2.ZERO
	var yaw: float = 0.0
	var slow_t: float = 0.0
	var slow_f: float = 1.0
	var dot_t: float = 0.0
	var dot_dps: float = 0.0
	var dot_tower: Tower = null
	var flash: float = 0.0
	var bob: float = 0.0

	func current_speed() -> float:
		return speed * (slow_f if slow_t > 0.0 else 1.0)

	func progress() -> float:
		return d / path.length


class Tower:
	extends RefCounted
	var uid: int = 0
	var type: StringName
	var data: TowerData
	var level: int = 0
	var pad: int = 0
	var cd: float = 0.3
	var kills: int = 0
	var spent: int = 0
	var mode: StringName = &"first"
	var yaw: float = 0.0
	var recoil: float = 0.0


class Arrow:
	extends RefCounted
	var pos: Vector3
	var dir: Vector3 = Vector3.FORWARD
	var target: Enemy
	var aim: Vector2
	var damage: float
	var tower: Tower
	var life: float = 2.0


class Shell:
	extends RefCounted
	var kind: StringName
	var from: Vector3
	var to: Vector2
	var flight: float
	var t: float = 0.0
	var arc: float
	var tower: Tower

	func position() -> Vector3:
		var k: float = clampf(t / flight, 0.0, 1.0)
		return Vector3(lerpf(from.x, to.x, k), lerpf(from.y, 0.3, k) + 4.0 * arc * k * (1.0 - k), lerpf(from.z, to.y, k))


class Puddle:
	extends RefCounted
	var pos: Vector2
	var radius: float
	var life: float = 3.0
	var max_life: float = 3.0
	var slow: float = 1.0


var data: GameData
var layout: MapLayout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var gold: int = 0
var lives: int = 0
var wave: int = 0
var phase: StringName = &"build"
var endless: bool = false
var over: bool = false
var won: bool = false
var time: float = 0.0
var wave_time: float = 0.0
var pending_bonus: int = 0
var kills: int = 0
var gold_earned: int = 0
var built: int = 0

var queue: Array[Dictionary] = []
var enemies: Array[Enemy] = []
var towers: Array[Tower] = []
var pad_towers: Array[Tower] = []
var arrows: Array[Arrow] = []
var shells: Array[Shell] = []
var puddles: Array[Puddle] = []

var _next_uid: int = 1
var _carry: float = 0.0


func _init(game_data: GameData = null, map: MapLayout = null, seed_value: int = 20261019) -> void:
	data = game_data if game_data != null else GameData.load_default()
	layout = map if map != null else MapLayout.get_default()
	rng.seed = seed_value
	gold = data.config.start_gold
	lives = data.config.start_lives
	pad_towers.resize(layout.pads.size())


# ---------------------------------------------------------------- wave rules
func hp_multiplier(w: int) -> float:
	var k: float = float(w - 1)
	return 1.0 + data.config.hp_linear * k + data.config.hp_quadratic * k * k


## Spawn list for wave w: [{t, type, path}] sorted by time; enemies alternate roads.
func make_wave(w: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var tm: float = 0.0
	var n: int = 0
	for rule: WaveRule in data.waves.rules:
		if not rule.applies(w):
			continue
		var count: int = rule.count_for(w)
		var gap: float = rule.gap_for(w)
		for i: int in range(count):
			list.append({"t": tm, "type": rule.enemy, "path": n % 2})
			n += 1
			tm += gap
		tm += data.waves.group_pause
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return list


func wave_counts(w: int) -> Dictionary:
	var c: Dictionary = {}
	for s: Dictionary in make_wave(w):
		c[s["type"]] = int(c.get(s["type"], 0)) + 1
	return c


func clear_bonus(w: int) -> int:
	return data.config.clear_bonus_base + data.config.clear_bonus_per_wave * w


func early_bonus(w: int) -> int:
	return data.config.early_bonus_base + data.config.early_bonus_per_wave * w


func has_more_waves() -> bool:
	return endless or wave < data.config.max_waves


func can_call_wave() -> bool:
	return not over and queue.is_empty() and has_more_waves()


func start_wave() -> bool:
	if not can_call_wave():
		return false
	if phase == &"wave" and not enemies.is_empty():
		var b: int = early_bonus(wave)
		_add_gold(b)
		early_bonus_paid.emit(b)
	wave += 1
	phase = &"wave"
	wave_time = 0.0
	queue = make_wave(wave)
	pending_bonus += clear_bonus(wave)
	var boss: bool = false
	for s: Dictionary in queue:
		if (data.enemy(s["type"]) as EnemyData).is_boss:
			boss = true
			break
	wave_started.emit(wave, boss)
	return true


func continue_endless() -> void:
	if won:
		over = false
		endless = true


# ---------------------------------------------------------------- towers
func tower_on_pad(pad: int) -> Tower:
	if pad < 0 or pad >= pad_towers.size():
		return null
	return pad_towers[pad]


func build_cost(type: StringName) -> int:
	return data.tower(type).cost[0]


func upgrade_cost(t: Tower) -> int:
	if t.level >= t.data.levels() - 1:
		return -1
	return t.data.cost[t.level + 1]


func refund(t: Tower) -> int:
	return floori(float(t.spent) * data.config.sell_refund)


func build(pad: int, type: StringName) -> Tower:
	if over or pad < 0 or pad >= pad_towers.size() or pad_towers[pad] != null:
		return null
	var cost: int = build_cost(type)
	if gold < cost:
		denied.emit(&"gold")
		return null
	gold -= cost
	var t := Tower.new()
	t.uid = _next_uid
	_next_uid += 1
	t.type = type
	t.data = data.tower(type)
	t.pad = pad
	t.spent = cost
	pad_towers[pad] = t
	towers.append(t)
	built += 1
	gold_changed.emit(gold)
	tower_built.emit(t)
	return t


func upgrade(t: Tower) -> bool:
	if t == null or over or not towers.has(t):
		return false
	var cost: int = upgrade_cost(t)
	if cost < 0:
		return false
	if gold < cost:
		denied.emit(&"gold")
		return false
	gold -= cost
	t.spent += cost
	t.level += 1
	gold_changed.emit(gold)
	tower_upgraded.emit(t)
	return true


func sell(t: Tower) -> int:
	if t == null or not towers.has(t):
		return 0
	var r: int = refund(t)
	towers.erase(t)
	pad_towers[t.pad] = null
	gold += r  # a refund is not income, so gold_earned is untouched
	gold_changed.emit(gold)
	tower_sold.emit(t, r)
	return r


func cycle_mode(t: Tower) -> void:
	if t == null:
		return
	t.mode = MODES[(MODES.find(t.mode) + 1) % MODES.size()]


func tower_range(t: Tower) -> float:
	return t.data.stat(t.data.reach, t.level)


func muzzle(t: Tower) -> Vector3:
	var p: Vector2 = layout.pads[t.pad]
	return Vector3(p.x, PAD_BASE + t.data.stat(t.data.pivot, t.level) + 0.7, p.y)


# ---------------------------------------------------------------- damage
## Damage after armour: arrows are fully reduced by armour, cannonballs by half of it.
static func armored_damage(amount: float, armor: float, kind: StringName) -> float:
	if kind == &"arrow":
		return amount * (1.0 - armor)
	if kind == &"ball":
		return amount * (1.0 - armor * 0.5)
	return amount


func damage(e: Enemy, amount: float, by: Tower, kind: StringName) -> void:
	if not e.alive:
		return
	e.hp -= armored_damage(amount, e.data.armor, kind)
	if kind != &"dot":
		e.flash = 0.12
	if e.hp <= 0.0:
		_kill(e, by)


func _kill(e: Enemy, by: Tower) -> void:
	e.alive = false
	kills += 1
	if by != null:
		by.kills += 1
	_add_gold(e.gold)
	enemy_killed.emit(e)


func _add_gold(n: int) -> void:
	gold += n
	gold_earned += n
	gold_changed.emit(gold)


func spawn(type: StringName, path_idx: int) -> Enemy:
	var ed: EnemyData = data.enemy(type)
	var e := Enemy.new()
	e.uid = _next_uid
	_next_uid += 1
	e.type = type
	e.data = ed
	e.path_idx = path_idx
	e.path = layout.paths[path_idx]
	e.lane = (rng.randf() - 0.5) * 1.4
	e.hp = ed.hp * hp_multiplier(wave)
	e.max_hp = e.hp
	e.speed = ed.speed * (0.92 + rng.randf() * 0.16)
	e.gold = ed.gold + floori(float(wave) / float(data.config.gold_bonus_every))
	e.bob = rng.randf() * 6.0
	_place(e)
	enemies.append(e)
	enemy_spawned.emit(e)
	return e


func _place(e: Enemy) -> void:
	e.pos = e.path.lane_point(e.d, e.lane)
	var t: Vector2 = e.path.tangent_at(e.d)
	e.yaw = atan2(t.x, t.y)


func _leak(e: Enemy) -> void:
	e.alive = false
	var lost: int = mini(lives, e.data.lives)
	lives = maxi(0, lives - e.data.lives)
	lives_changed.emit(lives, lost)
	enemy_leaked.emit(e)
	if lives <= 0:
		_end(false)


func _end(victory: bool) -> void:
	if over:
		return
	over = true
	won = victory
	game_ended.emit(victory)


# ---------------------------------------------------------------- simulation
## Advance the battle by dt seconds in fixed sub-steps (deterministic).
func advance(dt: float) -> void:
	_carry += dt
	while _carry >= STEP and not over:
		_carry -= STEP
		_tick(STEP)
	if over:
		_carry = 0.0


func _tick(dt: float) -> void:
	time += dt
	# spawning
	if not queue.is_empty():
		wave_time += dt
		while not queue.is_empty() and float(queue[0]["t"]) <= wave_time:
			var s: Dictionary = queue.pop_front()
			spawn(s["type"], int(s["path"]))
	# enemies
	for e: Enemy in enemies:
		if not e.alive:
			continue
		if e.slow_t > 0.0:
			e.slow_t -= dt
		else:
			e.slow_f = 1.0
		if e.dot_t > 0.0:
			e.dot_t -= dt
			damage(e, e.dot_dps * dt, e.dot_tower, &"dot")
			if not e.alive:
				continue
		if e.flash > 0.0:
			e.flash -= dt
		e.d += e.current_speed() * dt
		e.bob += dt * e.speed * 3.0
		if e.d >= e.path.length:
			_leak(e)
			if over:
				return
			continue
		_place(e)
	# towers
	for t: Tower in towers:
		t.cd -= dt
		if t.recoil > 0.0:
			t.recoil = maxf(0.0, t.recoil - dt * 4.0)
		var target: Enemy = find_target(t)
		if target != null:
			var p: Vector2 = layout.pads[t.pad]
			var want: float = atan2(target.pos.x - p.x, target.pos.y - p.y)
			t.yaw += wrapf(want - t.yaw, -PI, PI) * minf(1.0, dt * 10.0)
			if t.cd <= 0.0:
				_fire(t, target)
				t.cd = t.data.stat(t.data.rate, t.level)
	_update_arrows(dt)
	_update_shells(dt)
	_update_puddles(dt)
	# cleanup and wave end
	var i: int = enemies.size() - 1
	while i >= 0:
		if not enemies[i].alive:
			enemies.remove_at(i)
		i -= 1
	if phase == &"wave" and queue.is_empty() and enemies.is_empty():
		phase = &"build"
		var b: int = pending_bonus
		pending_bonus = 0
		_add_gold(b)
		wave_cleared.emit(wave, b)
		if wave >= data.config.max_waves and not endless:
			_end(true)


func find_target(t: Tower) -> Enemy:
	var r: float = tower_range(t)
	var r2: float = r * r
	var p: Vector2 = layout.pads[t.pad]
	var best: Enemy = null
	var best_v: float = -INF
	for e: Enemy in enemies:
		if not e.alive:
			continue
		var d2: float = e.pos.distance_squared_to(p)
		if d2 > r2:
			continue
		var v: float
		match t.mode:
			&"strong":
				v = e.hp
			&"near":
				v = -d2
			_:
				v = e.progress()
		if v > best_v:
			best_v = v
			best = e
	return best


func _fire(t: Tower, e: Enemy) -> void:
	t.recoil = 1.0
	var o: Vector3 = muzzle(t)
	if t.data.projectile == &"arrow":
		var a := Arrow.new()
		a.pos = o
		a.target = e
		a.aim = e.pos
		a.damage = t.data.stat(t.data.damage, t.level)
		a.tower = t
		arrows.append(a)
	else:
		# ballistic shot aimed at where the enemy will be when it lands
		var flight: float = t.data.flight_time
		var land: Vector2 = e.path.lane_point(minf(e.path.length, e.d + e.current_speed() * flight), e.lane)
		var s := Shell.new()
		s.kind = t.data.projectile
		s.from = o
		s.to = land
		s.flight = flight
		s.tower = t
		s.arc = 3.0 + Vector2(o.x, o.z).distance_to(land) * 0.18
		shells.append(s)
	tower_fired.emit(t, e)


func _update_arrows(dt: float) -> void:
	var i: int = arrows.size() - 1
	while i >= 0:
		var a: Arrow = arrows[i]
		if a.target.alive:
			a.aim = a.target.pos
		var to: Vector3 = Vector3(a.aim.x, 0.9, a.aim.y) - a.pos
		var dist: float = to.length()
		var step: float = ARROW_SPEED * dt
		a.life -= dt
		if dist <= step + 0.3:
			if a.target.alive:
				damage(a.target, a.damage, a.tower, &"arrow")
				arrow_hit.emit(Vector3(a.aim.x, 0.9, a.aim.y))
			a.life = 0.0
		else:
			a.dir = to / dist
			a.pos += a.dir * step
		if a.life <= 0.0:
			arrows.remove_at(i)
		i -= 1


func _update_shells(dt: float) -> void:
	var i: int = shells.size() - 1
	while i >= 0:
		var s: Shell = shells[i]
		s.t += dt
		if s.t >= s.flight:
			_land(s)
			shells.remove_at(i)
		i -= 1


func _land(s: Shell) -> void:
	var t: Tower = s.tower
	var r: float = t.data.stat(t.data.splash, t.level)
	for e: Enemy in enemies:
		if not e.alive:
			continue
		var d: float = e.pos.distance_to(s.to)
		if d > r:
			continue
		if s.kind == &"ball":
			damage(e, t.data.stat(t.data.damage, t.level) * (1.0 - 0.45 * d / r), t, &"ball")
		else:
			e.dot_dps = maxf(e.dot_dps if e.dot_t > 0.0 else 0.0, t.data.stat(t.data.burn_dps, t.level))
			e.dot_t = 3.0
			e.dot_tower = t
			e.slow_t = 2.6
			e.slow_f = minf(e.slow_f, t.data.stat(t.data.slow, t.level))
	if s.kind == &"tar" and puddles.size() < data.config.max_puddles:
		var p := Puddle.new()
		p.pos = s.to
		p.radius = r
		p.slow = t.data.stat(t.data.slow, t.level)
		puddles.append(p)
	shell_landed.emit(s.kind, s.to, r)


func _update_puddles(dt: float) -> void:
	var i: int = puddles.size() - 1
	while i >= 0:
		var p: Puddle = puddles[i]
		p.life -= dt
		for e: Enemy in enemies:
			if e.alive and e.pos.distance_to(p.pos) < p.radius:
				e.slow_t = maxf(e.slow_t, 0.3)
				e.slow_f = minf(e.slow_f, p.slow)
		if p.life <= 0.0:
			puddles.remove_at(i)
		i -= 1


func boss() -> Enemy:
	for e: Enemy in enemies:
		if e.alive and e.data.is_boss:
			return e
	return null


# ---------------------------------------------------------------- save / load
## Snapshot taken between waves (the queue is empty and no enemy is alive).
func to_snapshot() -> Dictionary:
	var tw: Array = []
	for t: Tower in towers:
		tw.append({"pad": t.pad, "type": String(t.type), "level": t.level, "mode": String(t.mode), "spent": t.spent, "kills": t.kills, "yaw": t.yaw})
	return {
		"version": 1, "wave": wave, "gold": gold, "lives": lives, "endless": endless,
		"kills": kills, "gold_earned": gold_earned, "built": built, "towers": tw,
	}


func load_snapshot(s: Dictionary) -> bool:
	if int(s.get("version", 0)) != 1:
		return false
	wave = int(s.get("wave", 0))
	gold = int(s.get("gold", gold))
	lives = int(s.get("lives", lives))
	endless = bool(s.get("endless", false))
	kills = int(s.get("kills", 0))
	gold_earned = int(s.get("gold_earned", 0))
	built = int(s.get("built", 0))
	phase = &"build"
	for raw: Variant in s.get("towers", []):
		var d: Dictionary = raw as Dictionary
		var pad: int = int(d.get("pad", -1))
		var type: StringName = StringName(String(d.get("type", "")))
		if pad < 0 or pad >= pad_towers.size() or pad_towers[pad] != null or not data.towers.has(type):
			continue
		var t := Tower.new()
		t.uid = _next_uid
		_next_uid += 1
		t.type = type
		t.data = data.tower(type)
		t.pad = pad
		t.level = clampi(int(d.get("level", 0)), 0, t.data.levels() - 1)
		t.mode = StringName(String(d.get("mode", "first")))
		if not MODES.has(t.mode):
			t.mode = &"first"
		t.spent = int(d.get("spent", t.data.cost[0]))
		t.kills = int(d.get("kills", 0))
		t.yaw = float(d.get("yaw", 0.0))
		pad_towers[pad] = t
		towers.append(t)
	return true
