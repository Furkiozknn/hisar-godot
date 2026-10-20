class_name World
extends Node3D
## The static battlefield and its ambient life: terrain, sea, roads, build pads, forest,
## rocks, enemy camps, the fortress, boats, flags and camp-fire smoke. Built procedurally
## from MapLayout so the picture always matches the rules.

const PAD_NORMAL: Color = Color(1, 1, 1)
const PAD_HOVER: Color = Color(1.12, 1.06, 0.9)
const PAD_SELECTED: Color = Color(1.25, 1.02, 0.55)
const GREENS: Array[int] = [0x4f7f3a, 0x5e8f40, 0x3f6e35, 0x6c9a45]
const TENT_COLORS: Array[int] = [0x8e3b2e, 0x6d4c33, 0x9a6b3c, 0x7a2f26]

var layout: MapLayout
var pads_mm: MultiMesh
var _rng := RandomNumberGenerator.new()
var _trees: Array[MultiMesh] = []
var _tree_count: int = 0
var _boats: Array[Dictionary] = []
var _flags: Array[Node3D] = []
var _fires: Array[CPUParticles3D] = []
var _time: float = 0.0


func build(map: MapLayout) -> void:
	layout = map
	_rng.seed = 1453
	_build_terrain()
	_build_water()
	_build_roads()
	_build_pads()
	_build_trees()
	_build_rocks()
	_build_camps()
	_build_fortress()
	_build_boats()
	apply_quality()


func apply_quality() -> void:
	var low: bool = Settings.is_low()
	for mm: MultiMesh in _trees:
		mm.visible_instance_count = int(_tree_count * 0.6) if low else -1
	for f: CPUParticles3D in _fires:
		f.amount = 10 if low else 24


func _process(delta: float) -> void:
	_time += delta
	for b: Dictionary in _boats:
		var n: Node3D = b["node"]
		var z: float = float(b["z"]) + float(b["dir"]) * float(b["sp"]) * delta
		if absf(z) > 34.0:
			b["dir"] = -float(b["dir"])
		b["z"] = z
		var x: float = float(b["x"])
		n.position = Vector3(x + sin(_time * 0.3 + x) * 2.0, -0.45 + sin(_time * 1.4 + x) * 0.08, z)
		n.rotation = Vector3(sin(_time * 1.2 + x) * 0.04, 0.0 if float(b["dir"]) > 0.0 else PI, cos(_time * 1.1) * 0.05)


func set_pad_color(pad: int, col: Color) -> void:
	if pad >= 0 and pad < pads_mm.instance_count:
		pads_mm.set_instance_color(pad, col)


# ---------------------------------------------------------------- terrain
func _terrain_color(x: float, z: float, h: float) -> Color:
	var sand: Color = Models.c(0xe6cf9a)
	var grass: Color = Models.c(0x86ad55)
	var grass2: Color = Models.c(0x6f9a46)
	var dry: Color = Models.c(0xb7b062)
	var rock: Color = Models.c(0x9d8f78)
	var peak: Color = Models.c(0xe2d9c6)
	var n: float = MapLayout.vnoise(x * 0.25, z * 0.25)
	if h < -0.25 and x > 34.0:
		return sand
	if h < -0.25:
		return grass2.lerp(dry, 0.25)
	if h > 6.5:
		return rock.lerp(peak, clampf((h - 6.5) / 6.0, 0.0, 0.55) * (0.6 + 0.4 * n))
	if h > 2.6:
		return rock.lerp(grass2, clampf((3.4 - h) / 0.8, 0.0, 1.0))
	var col: Color = grass.lerp(grass2, n)
	if n > 0.72:
		col = col.lerp(dry, 0.5)
	# sun-bleached verges along the roads
	var dr: float = layout.dist_to_road(x, z)
	if dr < 3.6:
		col = col.lerp(dry, (1.0 - dr / 3.6) * 0.35)
	return col


func _build_terrain() -> void:
	# the grid reaches well past the playfield so the fog, not a void, ends the world
	var w: int = 150
	var d: int = 140
	var hs: PackedFloat32Array = PackedFloat32Array()
	var cs: Array[Color] = []
	hs.resize((w + 1) * (d + 1))
	cs.resize((w + 1) * (d + 1))
	for iz: int in range(d + 1):
		for ix: int in range(w + 1):
			var x: float = -90.0 + float(ix)
			var z: float = -70.0 + float(iz)
			var h: float = layout.height_at(x, z)
			hs[iz * (w + 1) + ix] = h
			cs[iz * (w + 1) + ix] = _terrain_color(x, z, h)
	var k := MeshKit.new()
	for iz: int in range(d):
		for ix: int in range(w):
			var i00: int = iz * (w + 1) + ix
			var i10: int = i00 + 1
			var i01: int = i00 + w + 1
			var i11: int = i01 + 1
			var x: float = -90.0 + float(ix)
			var z: float = -70.0 + float(iz)
			var p00 := Vector3(x, hs[i00], z)
			var p10 := Vector3(x + 1.0, hs[i10], z)
			var p01 := Vector3(x, hs[i01], z + 1.0)
			var p11 := Vector3(x + 1.0, hs[i11], z + 1.0)
			# clockwise seen from above (Godot front faces)
			k.tri(p00, p10, p01, cs[i00], cs[i00], cs[i00])
			k.tri(p10, p11, p01, cs[i11], cs[i11], cs[i11])
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = k.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 300)
	pm.subdivide_width = 60
	pm.subdivide_depth = 100
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader") as Shader
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = pm
	mi.position = Vector3(118, -0.55, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_roads() -> void:
	var k := MeshKit.new()
	var road: Color = Models.c(0xcfa86b)
	var edge: Color = Models.c(0xa9834f)
	for pi: int in range(layout.paths.size()):
		var path: GamePath = layout.paths[pi]
		var y: float = 0.04 + float(pi) * 0.012
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var prev_el := Vector3.ZERO
		var prev_er := Vector3.ZERO
		var dist: float = 0.0
		var first: bool = true
		while dist <= path.length + 0.001:
			var p: Vector2 = path.point_at(dist)
			var t: Vector2 = path.tangent_at(dist)
			var nrm := Vector2(-t.y, t.x)
			var l := Vector3(p.x + nrm.x * 1.35, y, p.y + nrm.y * 1.35)
			var r := Vector3(p.x - nrm.x * 1.35, y, p.y - nrm.y * 1.35)
			var el := Vector3(p.x + nrm.x * 1.65, y - 0.02, p.y + nrm.y * 1.65)
			var er := Vector3(p.x - nrm.x * 1.65, y - 0.02, p.y - nrm.y * 1.65)
			if not first:
				_quad_up(k, prev_l, prev_r, l, r, road)
				_quad_up(k, prev_el, prev_l, el, l, edge)
				_quad_up(k, prev_r, prev_er, r, er, edge)
			prev_l = l
			prev_r = r
			prev_el = el
			prev_er = er
			first = false
			dist += 0.6
	var mi := MeshInstance3D.new()
	mi.name = "Roads"
	mi.mesh = k.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Adds a quad and makes sure both triangles face up.
func _quad_up(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for t: Array in [[a, b, c], [b, d, c]]:
		var p0: Vector3 = t[0]
		var p1: Vector3 = t[1]
		var p2: Vector3 = t[2]
		if (p2 - p0).cross(p1 - p0).y < 0.0:
			k.tri(p0, p2, p1, col, col, col)
		else:
			k.tri(p0, p1, p2, col, col, col)


func _multimesh(mesh: Mesh, count: int, colors: bool, node_name: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	add_child(mmi)
	return mm


func _build_pads() -> void:
	pads_mm = _multimesh(Models.pad(), layout.pads.size(), true, "Pads")
	for i: int in range(layout.pads.size()):
		var p: Vector2 = layout.pads[i]
		pads_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, 0.0, p.y)))
		pads_mm.set_instance_color(i, PAD_NORMAL)


func _scatter(count: int, test: Callable) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var tries: int = 0
	while out.size() < count and tries < count * 30:
		tries += 1
		var x: float = -50.0 + _rng.randf() * 92.0
		var z: float = -38.0 + _rng.randf() * 76.0
		if test.call(x, z):
			out.append(Vector2(x, z))
	return out


func _build_trees() -> void:
	var spots: Array[Vector2] = _scatter(300, func(x: float, z: float) -> bool:
		return layout.clear_of_play(x, z) and not (x < -40.0 and absf(absf(z) - 21.0) < 7.0) and MapLayout.base_height(x, z) < 7.5)
	_tree_count = spots.size()
	var trunks: MultiMesh = _multimesh(Models.tree_trunk(), spots.size(), false, "TreeTrunks")
	var crowns: MultiMesh = _multimesh(Models.tree_crown(), spots.size(), true, "TreeCrowns")
	for i: int in range(spots.size()):
		var p: Vector2 = spots[i]
		var s: float = 0.75 + _rng.randf() * 0.7
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, layout.height_at(p.x, p.y) - 0.05, p.y))
		trunks.set_instance_transform(i, xf)
		crowns.set_instance_transform(i, xf)
		crowns.set_instance_color(i, Models.c(GREENS[_rng.randi() % GREENS.size()]))
	_trees = [trunks, crowns]


func _build_rocks() -> void:
	var spots: Array[Vector2] = _scatter(70, func(x: float, z: float) -> bool:
		return layout.clear_of_play(x, z) and (absf(z) > 20.0 or _rng.randf() < 0.25))
	var mm: MultiMesh = _multimesh(Models.rock(), spots.size(), false, "Rocks")
	for i: int in range(spots.size()):
		var p: Vector2 = spots[i]
		var s: float = 0.5 + _rng.randf() * 1.4
		var b := Basis.from_euler(Vector3(_rng.randf() * 3.0, _rng.randf() * 3.0, _rng.randf() * 3.0)).scaled(Vector3(s, s * 0.7, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, layout.height_at(p.x, p.y) + s * 0.25, p.y)))


func _build_camps() -> void:
	var spots: Array[Vector2] = []
	for cpos: Vector2 in [Vector2(-45, -20), Vector2(-45, 22)]:
		for i: int in range(6):
			var a: float = float(i) / 6.0 * TAU + 0.4
			var r: float = 5.0 + float(i % 2) * 1.6
			var x: float = cpos.x + cos(a) * r * 0.8
			var z: float = cpos.y + sin(a) * r
			if layout.dist_to_road(x, z) > 2.4:
				spots.append(Vector2(x, z))
	var mm: MultiMesh = _multimesh(Models.tent(), spots.size(), true, "Tents")
	for i: int in range(spots.size()):
		var p: Vector2 = spots[i]
		var b := Basis(Vector3.UP, _rng.randf() * 6.0).scaled(Vector3(1, 0.9 + _rng.randf() * 0.3, 1))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, layout.height_at(p.x, p.y), p.y)))
		mm.set_instance_color(i, Models.c(TENT_COLORS[i % TENT_COLORS.size()]))
	var k := MeshKit.new()
	for f: Vector2 in MapLayout.CAMP_FIRES:
		var y: float = layout.height_at(f.x, f.y)
		k.cyl(0.6, 0.7, 0.25, 8, Models.c(0x4a3b2c), Vector3(f.x, y + 0.12, f.y))
		for j: int in range(5):
			var a: float = float(j) * 1.25
			k.cyl(0.08, 0.08, 0.9, 4, Models.c(0x5a3d22), Vector3(f.x + cos(a) * 0.2, y + 0.35, f.y + sin(a) * 0.2), Vector3(0, -a, 1.2))
		_fires.append(_campfire(Vector3(f.x, y + 0.3, f.y)))
	var mi := MeshInstance3D.new()
	mi.name = "FirePits"
	mi.mesh = k.commit()
	add_child(mi)


func _campfire(pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "CampSmoke"
	p.position = pos
	p.amount = 24
	p.lifetime = 3.2
	p.mesh = Fx.puff_mesh()
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.35, 0.5, 0.1)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.scale_amount_curve = Fx.grow_curve()
	p.color_ramp = Fx.ramp([Color(1.0, 0.62, 0.24, 0.95), Color(0.56, 0.54, 0.52, 0.55), Color(0.62, 0.6, 0.58, 0.0)], [0.0, 0.15, 1.0])
	add_child(p)
	return p


func _build_fortress() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Fortress"
	mi.mesh = Models.fortress()
	add_child(mi)
	for p: Vector3 in [Vector3(25, 9.5, -8), Vector3(25, 9.5, 8), Vector3(37, 9.5, -8), Vector3(37, 9.5, 8), Vector3(32, 11.9, 0)]:
		var f := MeshInstance3D.new()
		f.name = "Flag%d" % _flags.size()
		f.mesh = Models.flag()
		f.position = p
		f.scale = Vector3.ONE * (1.0 if p.y > 10.0 else 0.65)
		add_child(f)
		_flags.append(f)
	_animate_flags()


## The banners flutter on a looping AnimationPlayer clip, each with its own phase.
func _animate_flags() -> void:
	var anim := Animation.new()
	anim.length = 2.4
	anim.loop_mode = Animation.LOOP_LINEAR
	for i: int in range(_flags.size()):
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath("%s:rotation:y" % _flags[i].name))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for k: int in range(5):
			var t: float = float(k) * 0.6
			anim.track_insert_key(track, t, sin(t / 2.4 * TAU + float(i) * 1.7) * 0.35)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"flutter", anim)
	var ap := AnimationPlayer.new()
	ap.name = "FlagAnimation"
	add_child(ap)
	ap.add_animation_library(&"", lib)
	ap.play(&"flutter")


func _build_boats() -> void:
	for i: int in range(2):
		var mi := MeshInstance3D.new()
		mi.name = "Boat"
		mi.mesh = Models.boat()
		add_child(mi)
		_boats.append({"node": mi, "x": 52.0 + float(i) * 9.0, "z": 18.0 if i == 1 else -22.0, "dir": -1.0 if i == 1 else 1.0, "sp": 1.2 + float(i) * 0.5})
