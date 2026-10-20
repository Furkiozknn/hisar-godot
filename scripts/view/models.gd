class_name Models
extends RefCounted
## Every model in the game, built once and cached. Enemies, towers, the fortress and the
## boat come from the generated GLB files in res://assets/models (shared with the browser
## version) when they exist; every procedural MeshKit builder stays as the fallback.

const ACCENT: int = 0xf59e0b
const SKIN: int = 0xe2b48c
const IRON: int = 0x6f747a
const ROOF: int = 0xb3261e

const MODEL_PATH: String = "res://assets/models/%s.glb"
## Turns each model to face +Z (same numbers as MODEL_YAW in the browser version).
const MODEL_YAW: Dictionary = {"raider": -PI / 2.0, "rider": PI, "shield": -PI / 2.0, "fortress": PI, "head-archer": -PI / 2.0, "head-cannon": -PI / 2.0}
## Tower bases: world height per level, footprint width, top platform height as a fraction of the height.
const TOWER_FIT: Dictionary = {
	&"archer": {"h": [5.0, 5.8, 6.6], "w": 3.0, "floor": 0.49},
	&"cannon": {"h": [1.7, 2.2, 2.7], "w": 3.6, "floor": 0.77},
	&"tar": {"h": [2.4, 3.1, 3.8], "w": 2.4, "floor": 0.86},
}
## Largest side of each turret model at level 1.
const HEAD_SIZE: Dictionary = {&"archer": 1.3, &"cannon": 1.5, &"tar": 1.2}
const FORTRESS_SCALE: float = 14.0

## False with --noassets: every model uses its procedural builder.
static var use_assets: bool = true
static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


# ---------------------------------------------------------------- generated models
## A normalised GLB model: {"pos", "uv" (non-indexed triangles, turned to face +Z, base centre
## at the origin), "size", "mat"}. Empty when the file is missing or assets are off.
static func asset(model_name: String) -> Dictionary:
	if not use_assets:
		return {}
	return _cached("glb_" + model_name, func() -> Dictionary: return _load_asset(model_name)) as Dictionary


static func _load_asset(model_name: String) -> Dictionary:
	var path: String = MODEL_PATH % model_name
	if not ResourceLoader.exists(path):
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		return {}
	var root: Node = scene.instantiate()
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var tex: Texture2D = null
	var yaw := Basis(Vector3.UP, float(MODEL_YAW.get(model_name, 0.0)))
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# the node's transform relative to the scene root
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		xf = Transform3D(yaw, Vector3.ZERO) * xf
		for s: int in range(mi.mesh.get_surface_count()):
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i: int in range(verts.size()):
					idx[i] = i
			for i: int in idx:
				pos.append(xf * verts[i])
				uv.append(uvs[i] if i < uvs.size() else Vector2.ZERO)
			var bm := mi.get_active_material(s) as BaseMaterial3D
			if tex == null and bm != null:
				tex = bm.albedo_texture
	root.free()
	if pos.is_empty():
		return {}
	var box := AABB(pos[0], Vector3.ZERO)
	for v: Vector3 in pos:
		box = box.expand(v)
	var shift := Vector3(-(box.position.x + box.end.x) / 2.0, -box.position.y, -(box.position.z + box.end.z) / 2.0)
	for i: int in range(pos.size()):
		pos[i] += shift
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	# white vertex colours carry the per-face shade and the MultiMesh instance tint (hit flash, slow)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.metallic_specular = 0.25
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return {"pos": pos, "uv": uv, "size": box.size, "mat": mat}


## Flat-shaded mesh of a normalised model under xf (per-face normals, like the MeshKit parts).
static func _bake(a: Dictionary, xf: Transform3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: PackedVector3Array = a["pos"]
	var uv: PackedVector2Array = a["uv"]
	for t: int in range(0, pos.size() - 2, 3):
		var p0: Vector3 = xf * pos[t]
		var p1: Vector3 = xf * pos[t + 1]
		var p2: Vector3 = xf * pos[t + 2]
		var n: Vector3 = (p2 - p0).cross(p1 - p0)
		if n.length_squared() < 1e-14:
			continue
		n = n.normalized()
		var shade: float = 0.96 + 0.04 * n.y
		var col := Color(shade, shade, shade)
		for k: int in range(3):
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(uv[t + k])
			st.add_vertex([p0, p1, p2][k])
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, a["mat"] as Material)
	return m


## Model scaled so its largest side is `size`.
static func _sized(a: Dictionary, size: float, offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var sz: Vector3 = a["size"]
	var s: float = size / maxf(sz.x, maxf(sz.y, sz.z))
	return _bake(a, Transform3D(Basis.from_scale(Vector3.ONE * s), offset))


## Height of the turret mount above the pad: the platform of the generated tower, or
## `fallback` (the data pivot) for the procedural one. Visual only: the sim keeps TowerData.pivot.
static func head_mount(type: StringName, level: int, fallback: float) -> float:
	if asset("tower-" + type).is_empty():
		return fallback
	var f: Dictionary = TOWER_FIT[type]
	return float(f["h"][clampi(level, 0, 2)]) * float(f["floor"])


## Top of the tower including its turret, for picking.
static func tower_top(type: StringName, level: int, fallback: float) -> float:
	if asset("tower-" + type).is_empty():
		return fallback
	var h: float = float((TOWER_FIT[type] as Dictionary)["h"][clampi(level, 0, 2)])
	return maxf(h, head_mount(type, level, 0.0) + float(HEAD_SIZE[type]) * (1.0 + 0.07 * float(level)))


static func c(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff)


static func _cached(key: String, build: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


# ---------------------------------------------------------------- enemies
static func enemy(type: StringName) -> ArrayMesh:
	return _cached("enemy_%s" % type, func() -> ArrayMesh: return _enemy_model(type)) as ArrayMesh


## The generated enemy keeps the procedural model's height, but is never much longer than it.
static func _enemy_model(type: StringName) -> ArrayMesh:
	var proc: ArrayMesh = _enemy(type)
	var a: Dictionary = asset(String(type))
	if a.is_empty():
		return proc
	var old: Vector3 = proc.get_aabb().size
	var sz: Vector3 = a["size"]
	var s: float = minf(old.y / sz.y, old.z / sz.z * 1.15)
	return _bake(a, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO))


static func _enemy(type: StringName) -> ArrayMesh:
	var k := MeshKit.new()
	match type:
		&"raider":
			k.cyl(0.26, 0.34, 0.85, 7, c(0xb5452f), Vector3(0, 0.6, 0))
			k.box(Vector3(0.16, 0.36, 0.18), c(0x4a3424), Vector3(0.12, 0.18, 0))
			k.box(Vector3(0.16, 0.36, 0.18), c(0x4a3424), Vector3(-0.12, 0.18, 0))
			k.cyl(0.3, 0.3, 0.08, 7, c(0x4a3424), Vector3(0, 0.62, 0))  # belt
			k.sphere(0.2, c(SKIN), Vector3(0, 1.18, 0))
			k.cone(0.22, 0.26, 7, c(IRON), Vector3(0, 1.38, 0))
			k.box(Vector3(0.05, 1.5, 0.05), c(0x7a5a3a), Vector3(0.34, 0.85, 0.1))
			k.cone(0.07, 0.22, 4, c(IRON), Vector3(0.34, 1.68, 0.1))
		&"rider":
			k.box(Vector3(0.5, 0.5, 1.3), c(0x7a4e2d), Vector3(0, 0.85, 0))
			k.box(Vector3(0.24, 0.5, 0.5), c(0x7a4e2d), Vector3(0, 1.2, 0.72), Vector3(-0.6, 0, 0))
			k.box(Vector3(0.2, 0.25, 0.4), c(0x5c3a20), Vector3(0, 1.4, 0.98), Vector3(-0.2, 0, 0))
			for p: Vector2 in [Vector2(-0.18, -0.45), Vector2(0.18, -0.45), Vector2(-0.18, 0.45), Vector2(0.18, 0.45)]:
				k.box(Vector3(0.12, 0.6, 0.12), c(0x5c3a20), Vector3(p.x, 0.3, p.y))
			k.box(Vector3(0.08, 0.35, 0.08), c(0x2b1d12), Vector3(0, 0.9, -0.7), Vector3(0.5, 0, 0))  # tail
			k.box(Vector3(0.52, 0.1, 0.6), c(0xc9a227), Vector3(0, 1.12, 0))
			k.cyl(0.18, 0.22, 0.6, 6, c(0x8a2b2b), Vector3(0, 1.45, -0.05))
			k.sphere(0.17, c(SKIN), Vector3(0, 1.88, -0.05))
			k.cone(0.19, 0.24, 6, c(IRON), Vector3(0, 2.05, -0.05))
			k.box(Vector3(0.04, 0.04, 1.4), c(0x7a5a3a), Vector3(0.28, 1.5, 0.3))  # lance
		&"shield":
			k.cyl(0.33, 0.4, 0.95, 7, c(0x5a6170), Vector3(0, 0.65, 0))
			k.box(Vector3(0.2, 0.36, 0.2), c(0x3b3f47), Vector3(0.14, 0.18, 0))
			k.box(Vector3(0.2, 0.36, 0.2), c(0x3b3f47), Vector3(-0.14, 0.18, 0))
			k.sphere(0.21, c(SKIN), Vector3(0, 1.3, 0))
			k.cyl(0.23, 0.24, 0.22, 7, c(IRON), Vector3(0, 1.43, 0))
			k.cone(0.06, 0.18, 4, c(IRON), Vector3(0, 1.62, 0))
			k.box(Vector3(0.9, 1.05, 0.1), c(0x8a5a2b), Vector3(0, 0.75, 0.45))
			k.box(Vector3(0.98, 0.1, 0.12), c(IRON), Vector3(0, 1.26, 0.45))
			k.box(Vector3(0.98, 0.1, 0.12), c(IRON), Vector3(0, 0.26, 0.45))
			k.box(Vector3(0.2, 0.2, 0.06), c(0xc9a227), Vector3(0, 0.8, 0.52))
		_:  # ram
			k.box(Vector3(1.5, 0.75, 2.6), c(0x6e4b2a), Vector3(0, 0.95, 0))
			k.cyl(0.95, 0.95, 2.7, 3, c(0x4e3b28), Vector3(0, 1.75, 0), Vector3(PI / 2, 0, PI / 2), Vector3(1, 1, 0.9))
			k.cyl(0.22, 0.26, 3.6, 7, c(0x5a3d22), Vector3(0, 0.95, 0.5), Vector3(PI / 2, 0, 0))
			k.cone(0.32, 0.6, 7, c(0x7d8288), Vector3(0, 0.95, 2.55), Vector3(PI / 2, 0, 0))
			k.box(Vector3(1.56, 0.12, 0.12), c(IRON), Vector3(0, 1.3, 1.1))
			k.box(Vector3(1.56, 0.12, 0.12), c(IRON), Vector3(0, 1.3, -1.1))
			for p: Vector2 in [Vector2(-0.85, -0.8), Vector2(0.85, -0.8), Vector2(-0.85, 0.8), Vector2(0.85, 0.8)]:
				k.cyl(0.42, 0.42, 0.18, 10, c(0x3b2a1b), Vector3(p.x, 0.42, p.y), Vector3(0, 0, PI / 2))
				k.cyl(0.12, 0.12, 0.22, 6, c(IRON), Vector3(p.x, 0.42, p.y), Vector3(0, 0, PI / 2))
	return k.commit()


# ---------------------------------------------------------------- towers
## Returns the tower body mesh for type and level (0..2).
static func tower_base(type: StringName, level: int) -> ArrayMesh:
	return _cached("tb_%s_%d" % [type, level], func() -> ArrayMesh: return _tower_model(type, level)) as ArrayMesh


## Generated tower base, a little taller and wider per level, plus the level trims
## (pennant from level 2, gold band at level 3) as a second, vertex-coloured surface.
static func _tower_model(type: StringName, level: int) -> ArrayMesh:
	var a: Dictionary = asset("tower-" + type)
	if a.is_empty():
		return _tower_base(type, level)
	var f: Dictionary = TOWER_FIT[type]
	var h: float = float(f["h"][level])
	var sz: Vector3 = a["size"]
	var sxz: float = float(f["w"]) * (1.0 + 0.06 * float(level)) / maxf(sz.x, sz.z)
	var xf := Transform3D(Basis.from_scale(Vector3(sxz, h / sz.y, sxz)), Vector3.ZERO)
	var mesh: ArrayMesh = _bake(a, xf)
	if level < 1:
		return mesh
	var pos: PackedVector3Array = a["pos"]
	# widest point of the scaled model in a height band, to fit the trims around it
	var radius_at := func(y0: float, y1: float) -> float:
		var r: float = 0.0
		for v: Vector3 in pos:
			var q: Vector3 = xf * v
			if q.y >= y0 and q.y <= y1:
				r = maxf(r, Vector2(q.x, q.z).length())
		return r
	var k := MeshKit.new()
	var fx: float = 0.0 if type == &"archer" else float(radius_at.call(h * 0.8, h)) * 0.62
	var top: float = h - 0.15 if type == &"archer" else h
	k.cyl(0.035, 0.035, 1.3, 4, c(0x5a3d22), Vector3(fx, top + 0.6, 0))
	k.box(Vector3(0.05, 0.42, 0.75), c(ACCENT), Vector3(fx, top + 1.0, 0.4))
	if level >= 2:
		var y: float = h * (0.45 if type == &"cannon" else 0.32)
		var r: float = radius_at.call(y - h * 0.06, y + h * 0.06)
		if type == &"tar":
			k.box(Vector3(r * 1.42 + 0.1, 0.16, r * 1.42 + 0.1), c(ACCENT), Vector3(0, y, 0))
		else:
			k.torus(r * 0.98, 0.1, c(ACCENT), Vector3(0, y, 0), Vector3.ZERO, 20)
	var trim: ArrayMesh = k.commit()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trim.surface_get_arrays(0))
	mesh.surface_set_material(1, MeshKit.material())
	return mesh


static func _tower_base(type: StringName, level: int) -> ArrayMesh:
	var k := MeshKit.new()
	var stone: Color = c(0xcfc4ae)
	var stone2: Color = c(0xb3a78f)
	var wood: Color = c(0x8b5e34)
	var lf: float = float(level)
	match type:
		&"archer":
			var h: float = 2.2 + lf * 0.8
			k.cyl(1.25, 1.4, 0.7, 8, stone2, Vector3(0, 0.35, 0))
			k.cyl(0.95, 1.1, h, 8, stone, Vector3(0, 0.7 + h / 2.0, 0))
			k.cyl(1.35, 1.2, 0.3, 8, wood, Vector3(0, 0.85 + h, 0))
			for i: int in range(4):
				var a: float = float(i) * PI / 2.0 + PI / 4.0
				k.box(Vector3(0.14, 1.3, 0.14), c(0x6e4a2a), Vector3(cos(a) * 1.1, 1.65 + h, sin(a) * 1.1))
			k.cone(1.75, 1.3, 8, c(ROOF), Vector3(0, 2.95 + h, 0))
			for i: int in range(3):
				var a: float = float(i) * 2.1
				k.box(Vector3(0.12, 0.3, 0.4), c(0x3a2a1b), Vector3(cos(a) * 0.97, 0.9 + h * 0.55, sin(a) * 0.97), Vector3(0, -a, 0))
			if level >= 1:
				k.cyl(0.03, 0.03, 1.1, 4, c(0x5a3d22), Vector3(0, 4.15 + h, 0))
				k.box(Vector3(0.04, 0.4, 0.7), c(ACCENT), Vector3(0, 4.5 + h, 0.36))
			if level >= 2:
				k.torus(1.02, 0.08, c(ACCENT), Vector3(0, 0.7 + h * 0.82, 0))
		&"cannon":
			var h: float = 1.3 + lf * 0.5
			k.cyl(1.55, 1.75, h, 10, stone, Vector3(0, h / 2.0, 0))
			k.cyl(1.62, 1.62, 0.18, 10, stone2, Vector3(0, h + 0.09, 0))
			for i: int in range(8):
				var a: float = float(i) / 8.0 * TAU
				k.box(Vector3(0.45, 0.45, 0.35), stone2, Vector3(cos(a) * 1.45, h + 0.4, sin(a) * 1.45), Vector3(0, -a, 0))
			if level >= 1:
				for i: int in range(4):
					var a: float = float(i) * PI / 2.0 + 0.4
					k.box(Vector3(0.5, h * 0.9, 0.6), stone2, Vector3(cos(a) * 1.65, h * 0.45, sin(a) * 1.65), Vector3(0, -a, 0))
			if level >= 2:
				k.torus(1.66, 0.09, c(ACCENT), Vector3(0, h * 0.7, 0), Vector3.ZERO, 20)
			# a little pyramid of spare cannonballs
			for p: Vector3 in [Vector3(1.0, 0, 1.25), Vector3(1.3, 0, 1.0), Vector3(1.15, 0.2, 1.12)]:
				k.sphere(0.16, c(0x26282b), Vector3(p.x, 0.16 + p.y, p.z), 6, 3)
		_:
			var h: float = 1.5 + lf * 0.7
			k.box(Vector3(2.1, h, 2.1), c(0xb0a58f), Vector3(0, h / 2.0, 0))
			k.box(Vector3(2.3, 0.2, 2.3), stone2, Vector3(0, h + 0.1, 0))
			for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				k.box(Vector3(0.3, 0.6, 0.3), stone2, Vector3(p.x, h + 0.5, p.y))
			for i: int in range(3):
				var a: float = float(i) / 3.0 * TAU
				k.box(Vector3(0.1, 1.9, 0.1), c(0x5a3d22), Vector3(cos(a) * 0.55, h + 1.05, sin(a) * 0.55), Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3))
			# firewood stack
			for i: int in range(3):
				k.cyl(0.1, 0.1, 0.9, 5, c(0x6e4a2a), Vector3(-1.35, 0.12 + float(i % 2) * 0.18, -0.4 + float(i) * 0.25), Vector3(0, 0, PI / 2))
			if level >= 1:
				k.box(Vector3(0.05, 0.9, 0.6), c(ROOF), Vector3(1.16, h * 0.6, 0))
			if level >= 2:
				k.box(Vector3(2.16, 0.14, 2.16), c(ACCENT), Vector3(0, h * 0.75, 0))
	return k.commit()


## The rotating turret part: archer, cannon barrel, or the tar cauldron.
static func tower_head(type: StringName, level: int) -> ArrayMesh:
	return _cached("th_%s_%d" % [type, level], func() -> ArrayMesh:
		var a: Dictionary = asset("head-" + type)
		if a.is_empty():
			return _tower_head(type, level)
		return _sized(a, float(HEAD_SIZE[type]) * (1.0 + 0.07 * float(level)))) as ArrayMesh


static func _tower_head(type: StringName, level: int) -> ArrayMesh:
	var k := MeshKit.new()
	var lf: float = float(level)
	match type:
		&"archer":
			k.cyl(0.17, 0.22, 0.55, 6, c(0x1e40af if level >= 2 else 0x2f5f8a), Vector3(0, 0.3, 0))
			k.sphere(0.16, c(SKIN), Vector3(0, 0.72, 0))
			k.cone(0.17, 0.22, 6, c(IRON), Vector3(0, 0.88, 0))
			k.torus(0.3, 0.03, c(0x5a3d22), Vector3(0, 0.45, 0.25), Vector3(0, 0, PI / 2), 10)
			if level >= 1:
				# a second archer
				k.cyl(0.15, 0.2, 0.5, 6, c(0x2f5f8a), Vector3(0.45, 0.27, -0.25))
				k.sphere(0.14, c(SKIN), Vector3(0.45, 0.65, -0.25))
				k.cone(0.15, 0.2, 6, c(IRON), Vector3(0.45, 0.8, -0.25))
		&"cannon":
			k.box(Vector3(0.8, 0.35, 1.0), c(0x6e4a2a), Vector3(0, 0.2, 0))
			k.cyl(0.32, 0.32, 0.12, 10, c(0x3b2a1b), Vector3(0.45, 0.22, -0.2), Vector3(0, 0, PI / 2))
			k.cyl(0.32, 0.32, 0.12, 10, c(0x3b2a1b), Vector3(-0.45, 0.22, -0.2), Vector3(0, 0, PI / 2))
			k.cyl(0.17 + lf * 0.03, 0.25 + lf * 0.03, 1.4 + lf * 0.2, 10, c(0x30343a), Vector3(0, 0.55, 0.35), Vector3(PI / 2 - 0.25, 0, 0))
			k.torus(0.2 + lf * 0.03, 0.04, c(0x55595e), Vector3(0, 0.72, 0.98 + lf * 0.1), Vector3(PI / 2 - 0.25, 0, 0), 10)
		_:
			k.cyl(0.55, 0.4, 0.6, 10, c(0x2a2a2a), Vector3(0, 0.75, 0))
			k.cyl(0.5, 0.5, 0.04, 10, c(0x140d08), Vector3(0, 1.04, 0))
			k.torus(0.55, 0.05, c(0x55595e), Vector3(0, 1.05, 0), Vector3.ZERO, 12)
			k.cone(0.32, 0.5, 6, c(0xff8a2a), Vector3(0, 0.26, 0))
			k.cone(0.18, 0.35, 5, c(0xffd166), Vector3(0, 0.22, 0))
	return k.commit()


# ---------------------------------------------------------------- props
static func pad() -> ArrayMesh:
	return _cached("pad", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.cyl(1.5, 1.65, 0.3, 10, c(0xc9bfac), Vector3(0, 0.15, 0))
		k.cyl(1.2, 1.2, 0.04, 10, c(0xb1a690), Vector3(0, 0.32, 0))
		return k.commit()) as ArrayMesh


static func tree_trunk() -> ArrayMesh:
	return _cached("trunk", func() -> ArrayMesh:
		return MeshKit.new().cyl(0.12, 0.18, 0.9, 5, c(0x6b4a2b), Vector3(0, 0.45, 0)).commit()) as ArrayMesh


## White crown, tinted per instance.
static func tree_crown() -> ArrayMesh:
	return _cached("crown", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.cone(0.95, 1.6, 7, Color.WHITE, Vector3(0, 1.5, 0))
		k.cone(0.7, 1.3, 7, Color.WHITE, Vector3(0, 2.3, 0))
		k.cone(0.42, 0.9, 7, Color.WHITE, Vector3(0, 2.95, 0))
		return k.commit()) as ArrayMesh


static func rock() -> ArrayMesh:
	return _cached("rock", func() -> ArrayMesh:
		return MeshKit.new().sphere(0.8, c(0xa79b86), Vector3.ZERO, 5, 3).commit()) as ArrayMesh


static func tent() -> ArrayMesh:
	return _cached("tent", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.cone(1.5, 2.2, 6, Color.WHITE, Vector3(0, 1.1, 0))
		k.cyl(0.04, 0.04, 0.8, 4, c(0x4b3621), Vector3(0, 2.5, 0))
		return k.commit()) as ArrayMesh


static func boat() -> ArrayMesh:
	return _cached("boat", func() -> ArrayMesh:
		var a: Dictionary = asset("boat")
		if not a.is_empty():
			# the mast is the largest side, as tall as the procedural one
			return _sized(a, 3.6, Vector3(0, -0.3, 0))
		var k := MeshKit.new()
		k.box(Vector3(1.2, 0.5, 3.2), c(0x7a5232), Vector3(0, 0.25, 0))
		k.box(Vector3(0.9, 0.2, 2.6), c(0x9c6f45), Vector3(0, 0.55, 0))
		k.cyl(0.06, 0.06, 3, 4, c(0x5a3d22), Vector3(0, 2, 0.2))
		k.box(Vector3(0.04, 2.2, 1.8), c(0xf5ead2), Vector3(0, 2.2, 0.25))
		k.box(Vector3(0.05, 0.3, 0.5), c(ROOF), Vector3(0, 3.6, 0.45))
		return k.commit()) as ArrayMesh


static func flag_pole() -> ArrayMesh:
	return _cached("flag_pole", func() -> ArrayMesh:
		return MeshKit.new().cyl(0.06, 0.06, 2.6, 4, c(0x6e4a2a), Vector3(0, 1.3, 0)).commit()) as ArrayMesh


static func arrow() -> ArrayMesh:
	return _cached("arrow", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.box(Vector3(0.06, 0.06, 0.8), c(0x3b2a1b))
		k.cone(0.07, 0.18, 4, c(0x9aa0a6), Vector3(0, 0, 0.45), Vector3(PI / 2, 0, 0))
		k.box(Vector3(0.18, 0.02, 0.16), c(0xf1e3c4), Vector3(0, 0, -0.34))
		return k.commit()) as ArrayMesh


static func ball() -> ArrayMesh:
	return _cached("ball", func() -> ArrayMesh:
		return MeshKit.new().sphere(0.24, c(0x26282b), Vector3.ZERO, 8, 5).commit()) as ArrayMesh


static func tar_blob() -> ArrayMesh:
	return _cached("tarb", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.sphere(0.27, c(0x1b120b), Vector3.ZERO, 8, 5)
		k.sphere(0.16, c(0xff8a2a), Vector3(0, 0.12, 0), 6, 3)
		return k.commit()) as ArrayMesh


static func flag() -> ArrayMesh:
	return _cached("flag", func() -> ArrayMesh:
		var k := MeshKit.new()
		k.box(Vector3(0.05, 0.8, 1.4), c(ACCENT), Vector3(0, 0, 0.72))
		k.box(Vector3(0.06, 0.18, 0.5), c(ROOF), Vector3(0, 0.0, 0.72))
		return k.commit()) as ArrayMesh


# ---------------------------------------------------------------- fortress
## The generated fortress at its world scale (gate side facing -X), or null.
static func fortress_model() -> ArrayMesh:
	return _cached("fortress_glb", func() -> Variant:
		var a: Dictionary = asset("fortress")
		if a.is_empty():
			return null
		return _bake(a, Transform3D(Basis.from_scale(Vector3.ONE * FORTRESS_SCALE), Vector3.ZERO))) as ArrayMesh


## Where the generated fortress stands: its gate wall on x = 25, where the roads end.
static func fortress_origin() -> Vector3:
	var a: Dictionary = asset("fortress")
	var sx: float = (a["size"] as Vector3).x if not a.is_empty() else 0.0
	return Vector3(25.0 + sx * FORTRESS_SCALE / 2.0 - 0.3, 0.0, 0.0)


static func fortress() -> ArrayMesh:
	return _cached("fortress", _fortress) as ArrayMesh


static func _fortress() -> ArrayMesh:
	var k := MeshKit.new()
	var stone: Color = c(0xd8ccb4)
	var stone2: Color = c(0xc4b79c)
	var roof: Color = c(ROOF)
	var wood: Color = c(0x6e4a2a)
	var x0: float = 25.0
	var x1: float = 37.0
	var z0: float = -8.0
	var z1: float = 8.0
	var h: float = 3.4
	var th: float = 1.2
	var wall := func(ax: float, az: float, bx: float, bz: float) -> void:
		var l: float = Vector2(bx - ax, bz - az).length()
		var a: float = atan2(bx - ax, bz - az)
		k.box(Vector3(th, h, l), stone, Vector3((ax + bx) / 2.0, h / 2.0, (az + bz) / 2.0), Vector3(0, a, 0))
		k.box(Vector3(th + 0.3, 0.25, l), stone2, Vector3((ax + bx) / 2.0, 0.12, (az + bz) / 2.0), Vector3(0, a, 0))
		var s: float = 0.7
		while s < l - 0.3:
			var f: float = s / l
			k.box(Vector3(th + 0.1, 0.6, 0.7), stone2, Vector3(lerpf(ax, bx, f), h + 0.3, lerpf(az, bz, f)), Vector3(0, a, 0))
			s += 1.4
	wall.call(x1, z0, x1, z1)
	wall.call(x0, z1, x1, z1)
	wall.call(x0, z0, x1, z0)
	wall.call(x0, z0, x0, -1.7)
	wall.call(x0, 1.7, x0, z1)
	k.box(Vector3(th, 1.2, 3.4), stone2, Vector3(x0, h, 0))  # lintel over the gate
	k.box(Vector3(0.3, 2.3, 3.2), c(0x3a2a1b), Vector3(x0 - 0.2, 1.15, 0))  # gate doors
	k.box(Vector3(0.34, 0.12, 3.2), c(IRON), Vector3(x0 - 0.2, 0.6, 0))
	k.box(Vector3(0.34, 0.12, 3.2), c(IRON), Vector3(x0 - 0.2, 1.7, 0))
	for p: Vector2 in [Vector2(x0, z0), Vector2(x0, z1), Vector2(x1, z0), Vector2(x1, z1)]:
		k.cyl(1.9, 2.1, 5.2, 10, stone, Vector3(p.x, 2.6, p.y))
		k.cyl(2.15, 2.15, 0.5, 10, stone2, Vector3(p.x, 5.4, p.y))
		k.cone(2.3, 2.6, 10, roof, Vector3(p.x, 6.95, p.y))
		k.cyl(0.05, 0.05, 1.6, 4, wood, Vector3(p.x, 8.9, p.y))
		k.box(Vector3(0.04, 0.55, 0.9), roof, Vector3(p.x, 9.4, p.y + 0.47))
		for i: int in range(3):
			var a: float = float(i) * 2.0 + 0.6
			k.box(Vector3(0.15, 0.6, 0.35), c(0x2b2118), Vector3(p.x + cos(a) * 1.95, 3.6, p.y + sin(a) * 1.95), Vector3(0, -a, 0))
	for z: float in [-2.7, 2.7]:
		k.cyl(1.3, 1.4, 4.6, 8, stone, Vector3(x0, 2.3, z))
		k.cone(1.6, 2.0, 8, roof, Vector3(x0, 5.6, z))
	k.box(Vector3(11.5, 0.15, 15.5), c(0xd9c39a), Vector3(31, 0.07, 0))  # courtyard
	k.box(Vector3(5, 6.4, 5), stone, Vector3(32, 3.2, 0))  # keep
	k.box(Vector3(5.4, 0.5, 5.4), stone2, Vector3(32, 6.6, 0))
	k.cone(4.0, 3.0, 4, roof, Vector3(32, 8.35, 0), Vector3(0, PI / 4, 0))
	k.cyl(0.06, 0.06, 2.6, 4, wood, Vector3(32, 11, 0))
	for i: int in range(6):
		k.box(Vector3(0.6, 0.9, 0.15), c(0x2b2118), Vector3(32.0 + float(i % 3 - 1) * 1.4, 2.0 + floorf(float(i) / 3.0) * 2.0, -2.55))
		k.box(Vector3(0.15, 0.9, 0.6), c(0x2b2118), Vector3(29.45, 2.0 + floorf(float(i) / 3.0) * 2.0, float(i % 3 - 1) * 1.4))
	# courtyard life: a well, crates, a market awning
	k.cyl(0.7, 0.75, 0.7, 8, stone2, Vector3(28.5, 0.35, -5.0))
	k.cyl(0.55, 0.55, 0.05, 8, c(0x2f6f8f), Vector3(28.5, 0.68, -5.0))
	for p: Vector3 in [Vector3(35.2, 0.3, 5.6), Vector3(35.9, 0.3, 5.0), Vector3(35.5, 0.85, 5.3)]:
		k.box(Vector3(0.6, 0.6, 0.6), c(0x9c6f45), p, Vector3(0, p.x, 0))
	k.box(Vector3(2.4, 0.08, 1.6), c(0xd97706), Vector3(28.6, 1.9, 5.4), Vector3(0.2, 0, 0))
	for p: Vector2 in [Vector2(27.5, 4.8), Vector2(29.7, 4.8), Vector2(27.5, 6.0), Vector2(29.7, 6.0)]:
		k.cyl(0.05, 0.05, 1.9, 4, wood, Vector3(p.x, 0.95, p.y))
	return k.commit()
