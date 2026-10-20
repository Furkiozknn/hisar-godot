class_name BattleView
extends Node3D
## Draws a BattleSim: enemies and projectiles as MultiMeshes rebuilt every frame from the
## simulation state, towers as small node pairs (body + rotating head), plus every
## visual reaction to sim events (bursts, floating text, falling bodies, camera shake).

signal shake_requested(amount: float)

const MAX_ENEMIES: int = 300
const MAX_SHOTS: int = 260

var sim: BattleSim
var world: World
var fx: Fx
var hover_pad: int = -1
var selected_pad: int = -1

var _enemy_mm: Dictionary = {}  # type -> MultiMesh
var _bars: MultiMesh
var _arrows: MultiMesh
var _balls: MultiMesh
var _tars: MultiMesh
var _puddles: MultiMesh
var _towers: Dictionary = {}  # uid -> Dictionary {root, base, head}
var _ring: MeshInstance3D
var _disc: MeshInstance3D
var _ring_radius: float = 1.0
var _time: float = 0.0
var _corpses: int = 0


func _ready() -> void:
	for type: StringName in GameData.ENEMY_ORDER:
		_enemy_mm[type] = _mm(Models.enemy(type), MAX_ENEMIES, true, "Enemies_%s" % type)
	var bar := QuadMesh.new()
	bar.size = Vector2(1.0, 0.2)
	var bar_mat := ShaderMaterial.new()
	bar_mat.shader = load("res://shaders/health_bar.gdshader") as Shader
	bar_mat.render_priority = 10
	bar.material = bar_mat
	_bars = _mm(bar, MAX_ENEMIES, false, "HealthBars", true)
	_arrows = _mm(Models.arrow(), MAX_SHOTS, false, "Arrows")
	_balls = _mm(Models.ball(), 120, false, "Cannonballs")
	_tars = _mm(Models.tar_blob(), 100, false, "TarShots")
	var pm := CylinderMesh.new()
	pm.top_radius = 1.0
	pm.bottom_radius = 1.0
	pm.height = 0.02
	pm.radial_segments = 18
	pm.rings = 0
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.14, 0.09, 0.05, 0.85)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.roughness = 0.15
	pmat.metallic_specular = 0.8
	pm.material = pmat
	_puddles = _mm(pm, 48, false, "TarPuddles")
	_build_ring()


func _mm(mesh: Mesh, count: int, colors: bool, node_name: String, overlay: bool = false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	# instances move all over the map; skip culling against the stale AABB
	mmi.custom_aabb = AABB(Vector3(-80, -10, -60), Vector3(160, 40, 120))
	if overlay:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _build_ring() -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.96
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 3
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.98, 0.75, 0.14, 0.95)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.material = rm
	_ring = MeshInstance3D.new()
	_ring.name = "RangeRing"
	_ring.mesh = tm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	var dm := CylinderMesh.new()
	dm.top_radius = 1.0
	dm.bottom_radius = 1.0
	dm.height = 0.01
	dm.radial_segments = 48
	dm.rings = 0
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(1.0, 0.85, 0.4, 0.14)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	dm.material = dmat
	_disc = MeshInstance3D.new()
	_disc.name = "RangeDisc"
	_disc.mesh = dm
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.visible = false
	add_child(_disc)


# ---------------------------------------------------------------- binding
func bind(battle: BattleSim) -> void:
	unbind()
	sim = battle
	sim.tower_built.connect(_on_built)
	sim.tower_upgraded.connect(_on_upgraded)
	sim.tower_sold.connect(_on_sold)
	sim.tower_fired.connect(_on_fired)
	sim.arrow_hit.connect(_on_arrow_hit)
	sim.shell_landed.connect(_on_shell_landed)
	sim.enemy_killed.connect(_on_killed)
	sim.enemy_leaked.connect(_on_leaked)
	for t: BattleSim.Tower in sim.towers:
		_make_tower(t, false)


func unbind() -> void:
	for uid: int in _towers:
		((_towers[uid] as Dictionary)["root"] as Node3D).queue_free()
	_towers.clear()
	sim = null
	for mm: MultiMesh in _enemy_mm.values():
		mm.visible_instance_count = 0
	for mm: MultiMesh in [_bars, _arrows, _balls, _tars, _puddles]:
		mm.visible_instance_count = 0
	_ring.visible = false
	_disc.visible = false
	if world != null:
		for i: int in range(world.layout.pads.size()):
			world.set_pad_color(i, World.PAD_NORMAL)


# ---------------------------------------------------------------- towers
func _make_tower(t: BattleSim.Tower, pop: bool) -> void:
	var p: Vector2 = sim.layout.pads[t.pad]
	var root := Node3D.new()
	root.name = "Tower_%s_%d" % [t.type, t.uid]
	root.position = Vector3(p.x, BattleSim.PAD_BASE, p.y)
	var base := MeshInstance3D.new()
	base.name = "Body"
	var head := MeshInstance3D.new()
	head.name = "Head"
	root.add_child(base)
	root.add_child(head)
	add_child(root)
	_towers[t.uid] = {"root": root, "base": base, "head": head, "tower": t}
	_apply_level(t)
	if pop:
		_pop(root)


func _apply_level(t: BattleSim.Tower) -> void:
	var d: Dictionary = _towers[t.uid]
	(d["base"] as MeshInstance3D).mesh = Models.tower_base(t.type, t.level)
	(d["head"] as MeshInstance3D).mesh = Models.tower_head(t.type, t.level)


func _pop(n: Node3D) -> void:
	n.scale = Vector3(0.5, 0.2, 0.5)
	var tw: Tween = n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_built(t: BattleSim.Tower) -> void:
	_make_tower(t, true)
	var p: Vector2 = sim.layout.pads[t.pad]
	fx.burst("dust", Vector3(p.x, 0.6, p.y), 1.2)
	shake_requested.emit(0.08)


func _on_upgraded(t: BattleSim.Tower) -> void:
	if not _towers.has(t.uid):
		return
	_apply_level(t)
	_pop((_towers[t.uid] as Dictionary)["root"] as Node3D)
	var p: Vector2 = sim.layout.pads[t.pad]
	fx.burst("gold", Vector3(p.x, 2.5, p.y), 1.5)
	fx.burst("dust", Vector3(p.x, 0.6, p.y))


func _on_sold(t: BattleSim.Tower, refund: int) -> void:
	if not _towers.has(t.uid):
		return
	var root: Node3D = (_towers[t.uid] as Dictionary)["root"]
	_towers.erase(t.uid)
	var tw: Tween = root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.2, 0.01, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	var p: Vector2 = sim.layout.pads[t.pad]
	fx.burst("dust", Vector3(p.x, 1.0, p.y), 1.0)
	fx.float_text("+%d" % refund, Vector3(p.x, 2.5, p.y))


func _on_fired(t: BattleSim.Tower, _target: BattleSim.Enemy) -> void:
	match t.data.projectile:
		&"arrow":
			Sound.play("bow")
		&"ball":
			Sound.play("boom")
			var o: Vector3 = sim.muzzle(t)
			var fwd := Vector3(sin(t.yaw), 0, cos(t.yaw))
			fx.burst("smoke", o + fwd * 1.2 + Vector3(0, -0.1, 0), 0.8)
			fx.burst("fire", o + fwd * 1.1, 0.4)
			shake_requested.emit(0.04)
		_:
			Sound.play("lob")


func _on_arrow_hit(at: Vector3) -> void:
	fx.burst("spark", at)
	Sound.play("hit")


func _on_shell_landed(kind: StringName, at: Vector2, radius: float) -> void:
	var p := Vector3(at.x, 0.4, at.y)
	if kind == &"ball":
		fx.burst("debris", p, 1.0)
		fx.burst("fire", p, 1.0)
		fx.burst("smoke", p + Vector3(0, 0.4, 0), 1.0)
		Sound.play("impact")
		shake_requested.emit(0.18)
	else:
		fx.burst("tar", p, radius / 2.2)
		Sound.play("splash")


func _on_killed(e: BattleSim.Enemy) -> void:
	var p := Vector3(e.pos.x, 0.9, e.pos.y)
	var big: bool = e.data.is_boss
	fx.burst("death", p, 3.0 if big else 1.0)
	if big:
		fx.burst("debris", p, 2.0)
		fx.burst("smoke", p, 2.0)
		shake_requested.emit(0.5)
	fx.float_text("+%d" % e.gold, Vector3(e.pos.x, e.data.height * e.data.model_scale * 0.6 + 0.8, e.pos.y))
	Sound.play("coin")
	_corpse(e)


## A short-lived copy of the enemy model that tips over and sinks into the ground.
func _corpse(e: BattleSim.Enemy) -> void:
	if not fx.enabled or _corpses >= 24:
		return
	_corpses += 1
	var m := MeshInstance3D.new()
	m.name = "Fallen"
	m.mesh = Models.enemy(e.type)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = Vector3(e.pos.x, 0, e.pos.y)
	m.rotation = Vector3(0, e.yaw, 0)
	m.scale = Vector3.ONE * e.data.model_scale
	var side: float = 1.0 if (e.uid % 2) == 0 else -1.0
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "rotation:z", side * PI * 0.48, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "position:y", -1.6, 0.9).set_delay(0.5)
	tw.tween_callback(func() -> void:
		_corpses -= 1
		m.queue_free())


func _on_leaked(e: BattleSim.Enemy) -> void:
	fx.burst("blood", Vector3(25.0, 1.5, e.pos.y * 0.3), 1.0 + float(e.data.lives) * 0.3)
	fx.burst("debris", Vector3(25.0, 1.0, 0), 0.6)
	fx.float_text("-%d" % e.data.lives, Vector3(24.0, 5.0, 0), Color(1.0, 0.45, 0.4), 1.3)
	shake_requested.emit(0.35 + float(e.data.lives) * 0.05)


# ---------------------------------------------------------------- selection visuals
func show_range(pad: int, radius: float) -> void:
	if pad < 0:
		_ring.visible = false
		_disc.visible = false
		return
	var p: Vector2 = sim.layout.pads[pad]
	_ring.position = Vector3(p.x, 0.38, p.y)
	_disc.position = Vector3(p.x, 0.36, p.y)
	_ring_radius = radius
	_ring.visible = true
	_disc.visible = true


func refresh_pads() -> void:
	if world == null:
		return
	for i: int in range(world.layout.pads.size()):
		var col: Color = World.PAD_NORMAL
		if i == selected_pad:
			col = World.PAD_SELECTED
		elif i == hover_pad and (sim == null or sim.tower_on_pad(i) == null):
			col = World.PAD_HOVER
		world.set_pad_color(i, col)


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	_time += delta
	if _ring.visible:
		var k: float = _ring_radius * (1.0 + sin(_time * 4.0) * 0.012)
		_ring.scale = Vector3(k, 1, k)
		_disc.scale = Vector3(_ring_radius, 1, _ring_radius)
	if sim == null:
		return
	_draw_enemies()
	_draw_towers()
	_draw_shots()


func _draw_enemies() -> void:
	var counts: Dictionary = {}
	for type: StringName in _enemy_mm:
		counts[type] = 0
	var bars: int = 0
	for e: BattleSim.Enemy in sim.enemies:
		if not e.alive:
			continue
		var mm: MultiMesh = _enemy_mm[e.type]
		var i: int = counts[e.type]
		if i >= MAX_ENEMIES:
			continue
		counts[e.type] = i + 1
		var s: float = e.data.model_scale
		var boss: bool = e.data.is_boss
		var bob: float = 0.0 if boss else absf(sin(e.bob)) * 0.08
		var sway: float = 0.0 if boss else sin(e.bob) * 0.06
		# grow in when leaving the camp
		var grow: float = clampf(e.d / 1.5, 0.25, 1.0)
		var b := Basis.from_euler(Vector3(0, e.yaw, sway)).scaled(Vector3.ONE * s * grow)
		mm.set_instance_transform(i, Transform3D(b, Vector3(e.pos.x, bob, e.pos.y)))
		var col := Color(1, 1, 1)
		if e.flash > 0.0:
			col = Color(1.8, 0.75, 0.6)
		elif e.dot_t > 0.0 and e.slow_t > 0.0:
			col = Color(0.62, 0.55, 0.62)
		elif e.slow_t > 0.0:
			col = Color(0.55, 0.62, 0.82)
		mm.set_instance_color(i, col)
		if e.hp < e.max_hp and bars < MAX_ENEMIES:
			var frac: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
			var w: float = 2.8 if boss else 1.4
			var y: float = e.data.height * s * 0.95 + 0.2
			# the flat quad has no depth, so its z scale carries the HP fraction to the shader
			_bars.set_instance_transform(bars, Transform3D(Basis.from_scale(Vector3(w, 1, maxf(frac, 0.001))), Vector3(e.pos.x, y, e.pos.y)))
			bars += 1
	for type: StringName in _enemy_mm:
		(_enemy_mm[type] as MultiMesh).visible_instance_count = int(counts[type])
	_bars.visible_instance_count = bars


func _draw_towers() -> void:
	for uid: int in _towers:
		var d: Dictionary = _towers[uid]
		var t: BattleSim.Tower = d["tower"]
		var head: MeshInstance3D = d["head"]
		var pivot: float = Models.head_mount(t.type, t.level, t.data.stat(t.data.pivot, t.level))
		var r: float = t.recoil * 0.18
		head.rotation.y = t.yaw
		var lift: float = t.recoil * 0.15 if t.type == &"tar" else 0.0
		head.position = Vector3(-sin(t.yaw) * r, pivot + lift, -cos(t.yaw) * r)


func _draw_shots() -> void:
	var n: int = 0
	for a: BattleSim.Arrow in sim.arrows:
		if n >= MAX_SHOTS:
			break
		var dir: Vector3 = a.dir if a.dir.length_squared() > 0.0 else Vector3.FORWARD
		var b := Basis.looking_at(-dir, Vector3.UP) if absf(dir.y) < 0.99 else Basis.IDENTITY
		_arrows.set_instance_transform(n, Transform3D(b, a.pos))
		n += 1
	_arrows.visible_instance_count = n
	var nb: int = 0
	var nt: int = 0
	for s: BattleSim.Shell in sim.shells:
		var xf := Transform3D(Basis.IDENTITY, s.position())
		if s.kind == &"ball":
			if nb < _balls.instance_count:
				_balls.set_instance_transform(nb, xf)
				nb += 1
		elif nt < _tars.instance_count:
			_tars.set_instance_transform(nt, xf)
			nt += 1
	_balls.visible_instance_count = nb
	_tars.visible_instance_count = nt
	var np: int = 0
	for p: BattleSim.Puddle in sim.puddles:
		if np >= _puddles.instance_count:
			break
		var s: float = p.radius * 0.75 * minf(1.0, p.life / 0.6) * minf(1.0, (p.max_life - p.life) * 6.0 + 0.3)
		_puddles.set_instance_transform(np, Transform3D(Basis.from_scale(Vector3(s, 1, s)), Vector3(p.pos.x, 0.07 + float(np) * 0.001, p.pos.y)))
		np += 1
	_puddles.visible_instance_count = np
