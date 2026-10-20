class_name MeshKit
extends RefCounted
## Builds merged, flat-shaded, vertex-coloured low-poly meshes from simple parts
## (boxes, cylinders, cones, spheres, tori), the way the round-1 models were made.

var _st: SurfaceTool = SurfaceTool.new()
var _empty: bool = true

static var _shared: Dictionary = {}


static func clear_cache() -> void:
	_shared.clear()


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## The one material every merged model uses (colour comes from the vertices).
static func material() -> StandardMaterial3D:
	if _shared.has("mat"):
		return _shared["mat"] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.88
	m.metallic_specular = 0.25
	_shared["mat"] = m
	return m


static func _basis(rot: Vector3, scl: Vector3) -> Basis:
	# XYZ order matches the round-1 Three.js models
	return Basis.from_euler(rot, EULER_ORDER_XYZ) * Basis.from_scale(scl)


func add_mesh(src: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshKit:
	var xf := Transform3D(_basis(rot, scl), pos)
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(verts.size())
		for i: int in range(verts.size()):
			idx[i] = i
	for t: int in range(0, idx.size(), 3):
		var a: Vector3 = xf * verts[idx[t]]
		var b: Vector3 = xf * verts[idx[t + 1]]
		var c: Vector3 = xf * verts[idx[t + 2]]
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		# slight per-face shade variation gives the faceted look some life
		var shade: float = 0.96 + 0.04 * n.y
		var col := Color(color.r * shade, color.g * shade, color.b * shade, color.a)
		for v: Vector3 in [a, b, c]:
			_st.set_color(col)
			_st.set_normal(n)
			_st.add_vertex(v)
	_empty = false
	return self


func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshKit:
	var m := BoxMesh.new()
	m.size = size
	return add_mesh(m, color, pos, rot)


## Cylinder with top radius rt, bottom radius rb (like THREE.CylinderGeometry).
func cyl(rt: float, rb: float, h: float, seg: int, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshKit:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 0
	return add_mesh(m, color, pos, rot, scl)


func cone(r: float, h: float, seg: int, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshKit:
	return cyl(0.0, r, h, seg, color, pos, rot, scl)


func sphere(r: float, color: Color, pos: Vector3 = Vector3.ZERO, seg: int = 7, rings: int = 4, scl: Vector3 = Vector3.ONE) -> MeshKit:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return add_mesh(m, color, pos, Vector3.ZERO, scl)


func torus(r: float, tube: float, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, seg: int = 14) -> MeshKit:
	var m := TorusMesh.new()
	m.inner_radius = r - tube
	m.outer_radius = r + tube
	m.rings = seg
	m.ring_segments = 4
	return add_mesh(m, color, pos, rot)


## Raw triangle with its own colour (used for terrain-like custom shapes).
func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	_st.set_normal(n)
	_st.set_color(ca)
	_st.add_vertex(a)
	_st.set_normal(n)
	_st.set_color(cb)
	_st.add_vertex(b)
	_st.set_normal(n)
	_st.set_color(cc)
	_st.add_vertex(c)
	_empty = false


func commit() -> ArrayMesh:
	var m: ArrayMesh = _st.commit() if not _empty else ArrayMesh.new()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, material())
	return m
