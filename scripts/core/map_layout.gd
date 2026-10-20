class_name MapLayout
extends RefCounted
## The battlefield: two roads from the western camps that merge at (10, 0) and end at the
## fortress gate (x = 25.5), the build pads along them and the terrain height function.

const ROAD_A: Array[Vector2] = [Vector2(-48, -20), Vector2(-37, -21), Vector2(-28, -14), Vector2(-25, -5), Vector2(-16, -3), Vector2(-10, -12), Vector2(0, -15), Vector2(8, -8), Vector2(10, 0)]
const ROAD_B: Array[Vector2] = [Vector2(-48, 22), Vector2(-37, 23), Vector2(-28, 17), Vector2(-20, 10), Vector2(-10, 14), Vector2(-1, 16), Vector2(6, 9), Vector2(10, 0)]
const ROAD_END: Array[Vector2] = [Vector2(16, 2), Vector2(22, 0), Vector2(25.5, 0)]
const CAMP_FIRES: Array[Vector2] = [Vector2(-44.5, -24.5), Vector2(-44.5, 26)]

const GRID_MIN: Vector2 = Vector2(-60, -46)
const GRID_STEP: float = 1.0
const GRID_W: int = 121
const GRID_H: int = 93
const GRID_FAR: float = 9.0

var paths: Array[GamePath] = []
var pads: Array[Vector2] = []
var _samples: PackedVector2Array = PackedVector2Array()
var _grid: PackedFloat32Array = PackedFloat32Array()

static var _cached: MapLayout = null


static func get_default() -> MapLayout:
	if _cached == null:
		_cached = MapLayout.new()
		_cached._build()
	return _cached


func _build() -> void:
	var a: Array[Vector2] = ROAD_A.duplicate()
	a.append_array(ROAD_END)
	var b: Array[Vector2] = ROAD_B.duplicate()
	b.append_array(ROAD_END)
	paths = [GamePath.from_points(a), GamePath.from_points(b)]
	for p: GamePath in paths:
		for i: int in range(0, GamePath.N + 1, 2):
			_samples.append(p.pos[i])
	_build_grid()
	_build_pads()


func _build_grid() -> void:
	_grid.resize(GRID_W * GRID_H)
	_grid.fill(GRID_FAR)
	var reach: int = ceili(GRID_FAR / GRID_STEP)
	for s: Vector2 in _samples:
		var cx: int = roundi((s.x - GRID_MIN.x) / GRID_STEP)
		var cz: int = roundi((s.y - GRID_MIN.y) / GRID_STEP)
		for gz: int in range(maxi(0, cz - reach), mini(GRID_H, cz + reach + 1)):
			for gx: int in range(maxi(0, cx - reach), mini(GRID_W, cx + reach + 1)):
				var w: Vector2 = GRID_MIN + Vector2(gx, gz) * GRID_STEP
				var d: float = w.distance_to(s)
				var idx: int = gz * GRID_W + gx
				if d < _grid[idx]:
					_grid[idx] = d


func _build_pads() -> void:
	for pi: int in range(paths.size()):
		var path: GamePath = paths[pi]
		var side: float = 1.0 if pi == 0 else -1.0
		var d: float = 9.0
		while d < path.length - 7.0:
			var pt: Vector2 = path.point_at(d)
			var tg: Vector2 = path.tangent_at(d)
			side = -side
			for s: float in [side, -side]:
				var x: float = pt.x - tg.y * s * 3.9
				var z: float = pt.y + tg.x * s * 3.9
				if absf(x) > 44.0 or absf(z) > 31.0 or in_fortress(x, z, 1.0):
					continue
				if exact_dist_to_road(x, z) < 3.4:
					continue
				var crowded: bool = false
				for q: Vector2 in pads:
					if q.distance_to(Vector2(x, z)) < 4.6:
						crowded = true
						break
				if crowded:
					continue
				pads.append(Vector2(x, z))
				break
			d += 6.2


func exact_dist_to_road(x: float, z: float) -> float:
	var m: float = 1e9
	var p: Vector2 = Vector2(x, z)
	for s: Vector2 in _samples:
		m = minf(m, p.distance_squared_to(s))
	return sqrt(m)


## Fast, bilinear distance to the nearest road (capped at GRID_FAR).
func dist_to_road(x: float, z: float) -> float:
	var fx: float = clampf((x - GRID_MIN.x) / GRID_STEP, 0.0, float(GRID_W - 1) - 0.001)
	var fz: float = clampf((z - GRID_MIN.y) / GRID_STEP, 0.0, float(GRID_H - 1) - 0.001)
	var ix: int = floori(fx)
	var iz: int = floori(fz)
	var kx: float = fx - float(ix)
	var kz: float = fz - float(iz)
	var a: float = _grid[iz * GRID_W + ix]
	var b: float = _grid[iz * GRID_W + ix + 1]
	var c: float = _grid[(iz + 1) * GRID_W + ix]
	var d: float = _grid[(iz + 1) * GRID_W + ix + 1]
	return lerpf(lerpf(a, b, kx), lerpf(c, d, kx), kz)


static func in_fortress(x: float, z: float, pad: float = 0.0) -> bool:
	return x > 23.0 - pad and x < 39.0 + pad and absf(z) < 10.0 + pad


# ---------------------------------------------------------------- terrain noise
static func _hash(x: float, z: float) -> float:
	var s: float = sin(x * 127.1 + z * 311.7) * 43758.5453
	return s - floorf(s)


static func vnoise(x: float, z: float) -> float:
	var xi: float = floorf(x)
	var zi: float = floorf(z)
	var xf: float = x - xi
	var zf: float = z - zi
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = zf * zf * (3.0 - 2.0 * zf)
	var a: float = _hash(xi, zi)
	var b: float = _hash(xi + 1.0, zi)
	var c: float = _hash(xi, zi + 1.0)
	var d: float = _hash(xi + 1.0, zi + 1.0)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


static func fbm(x: float, z: float) -> float:
	return vnoise(x * 0.06, z * 0.06) + vnoise(x * 0.13, z * 0.13) * 0.5 + vnoise(x * 0.3, z * 0.3) * 0.2


static func base_height(x: float, z: float) -> float:
	var h: float = (fbm(x + 100.0, z + 100.0) - 0.8) * 3.2
	var edge: float = maxf(0.0, absf(z) - 24.0) / 10.0
	h += minf(7.0, edge * edge * 4.5) * (0.7 + 0.6 * vnoise(x * 0.12, z * 0.12))
	var west: float = maxf(0.0, -x - 45.0) / 6.0
	h += west * 2.2
	var sea: float = smoothstep(39.0, 47.0, x)
	return h * (1.0 - sea) - 3.4 * sea


## Terrain height with roads, pads and the fortress yard flattened.
func height_at(x: float, z: float) -> float:
	var h: float = base_height(x, z)
	var flat: float = 1.0 - smoothstep(2.4, 5.5, dist_to_road(x, z))
	var fd: float = Vector2(maxf(0.0, absf(x - 31.0) - 8.0), maxf(0.0, absf(z) - 10.0)).length()
	flat = maxf(flat, 1.0 - smoothstep(0.0, 4.0, fd))
	for p: Vector2 in pads:
		var d: float = p.distance_to(Vector2(x, z))
		if d < 3.4:
			flat = maxf(flat, 1.0 - smoothstep(1.6, 3.2, d))
	# flattening never lifts the sea floor above water near the fortress
	return h * (1.0 - flat) + minf(0.0, h) * flat * smoothstep(39.0, 44.0, x)


## True when scenery may be placed here (off roads, pads and the fortress, on land).
func clear_of_play(x: float, z: float) -> bool:
	if dist_to_road(x, z) <= 4.6 or in_fortress(x, z, 3.0) or base_height(x, z) <= -0.2:
		return false
	for p: Vector2 in pads:
		if p.distance_to(Vector2(x, z)) < 3.2:
			return false
	return true
