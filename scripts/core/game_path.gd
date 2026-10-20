class_name GamePath
extends RefCounted
## A road on the XZ plane: a centripetal Catmull-Rom spline through control points,
## resampled into N equal-length steps so sample(d) is cheap and uniform.

const N: int = 800

var length: float = 0.0
var pos: PackedVector2Array = PackedVector2Array()
var tan: PackedVector2Array = PackedVector2Array()


static func from_points(points: Array[Vector2]) -> GamePath:
	var p := GamePath.new()
	p._build(points)
	return p


func _build(points: Array[Vector2]) -> void:
	# dense polyline through the spline
	var ctrl: Array[Vector2] = points.duplicate()
	var first: Vector2 = ctrl[0] * 2.0 - ctrl[1]
	var last: Vector2 = ctrl[ctrl.size() - 1] * 2.0 - ctrl[ctrl.size() - 2]
	ctrl.push_front(first)
	ctrl.push_back(last)
	var dense: PackedVector2Array = PackedVector2Array()
	for i: int in range(1, ctrl.size() - 2):
		var steps: int = 48
		for s: int in range(steps):
			dense.append(_centripetal(ctrl[i - 1], ctrl[i], ctrl[i + 1], ctrl[i + 2], float(s) / float(steps)))
	dense.append(points[points.size() - 1])
	# cumulative length
	var cum: PackedFloat32Array = PackedFloat32Array()
	cum.resize(dense.size())
	cum[0] = 0.0
	for i: int in range(1, dense.size()):
		cum[i] = cum[i - 1] + dense[i].distance_to(dense[i - 1])
	length = cum[cum.size() - 1]
	# resample by arc length
	pos.resize(N + 1)
	var j: int = 0
	for i: int in range(N + 1):
		var target: float = length * float(i) / float(N)
		while j < dense.size() - 2 and cum[j + 1] < target:
			j += 1
		var seg: float = maxf(0.00001, cum[j + 1] - cum[j])
		var k: float = clampf((target - cum[j]) / seg, 0.0, 1.0)
		pos[i] = dense[j].lerp(dense[j + 1], k)
	tan.resize(N + 1)
	for i: int in range(N + 1):
		var a: Vector2 = pos[maxi(0, i - 1)]
		var b: Vector2 = pos[mini(N, i + 1)]
		var t: Vector2 = b - a
		tan[i] = t.normalized() if t.length_squared() > 0.0 else Vector2(1, 0)


static func _centripetal(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Barry-Goldman pyramid with alpha = 0.5
	var t0: float = 0.0
	var t1: float = t0 + maxf(0.0001, sqrt(p0.distance_to(p1)))
	var t2: float = t1 + maxf(0.0001, sqrt(p1.distance_to(p2)))
	var t3: float = t2 + maxf(0.0001, sqrt(p2.distance_to(p3)))
	var tt: float = lerpf(t1, t2, t)
	var a1: Vector2 = p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	var a2: Vector2 = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3: Vector2 = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1: Vector2 = a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	var b2: Vector2 = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


## Position on the road after travelling distance d.
func point_at(d: float) -> Vector2:
	var f: float = clampf(d / length, 0.0, 1.0) * float(N)
	var i: int = mini(N - 1, floori(f))
	return pos[i].lerp(pos[i + 1], f - float(i))


## Unit direction of travel at distance d.
func tangent_at(d: float) -> Vector2:
	var f: float = clampf(d / length, 0.0, 1.0) * float(N)
	var i: int = mini(N - 1, floori(f))
	return tan[i].lerp(tan[i + 1], f - float(i)).normalized()


## Point offset sideways from the road centre by `lane` (positive = right of travel).
func lane_point(d: float, lane: float) -> Vector2:
	var p: Vector2 = point_at(d)
	var t: Vector2 = tangent_at(d)
	return Vector2(p.x - t.y * lane, p.y + t.x * lane)
