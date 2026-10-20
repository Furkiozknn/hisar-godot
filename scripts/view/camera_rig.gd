class_name CameraRig
extends Node3D
## Orbit camera with smoothing and shake. Mouse: left-drag pans, right-drag rotates,
## wheel zooms. Touch: one finger pans, two fingers pinch-zoom and twist. Keyboard and
## gamepad use the cam_* actions. A slow cinematic orbit runs on the title screen.

const MIN_DIST: float = 20.0
const MAX_DIST: float = 100.0
const MIN_PITCH: float = 0.42  # radians above the horizon
const MAX_PITCH: float = 1.27
const BOUNDS: Rect2 = Rect2(-50, -36, 92, 72)

var target: Vector3 = Vector3(-2, 0, 0)
var yaw: float = -0.08
var pitch: float = 0.8
var dist: float = 74.0
var cinematic: bool = false
var input_enabled: bool = true

var _t_target: Vector3 = target
var _t_yaw: float = yaw
var _t_pitch: float = pitch
var _t_dist: float = dist
var _shake: float = 0.0
var _touches: Dictionary = {}
var _pinch_dist: float = 0.0
var _pinch_angle: float = 0.0
var _cine_t: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_aspect)
	_fit_aspect()
	_apply()


func portrait() -> bool:
	var s: Vector2 = get_viewport().get_visible_rect().size
	return s.y > s.x


## Portrait screens keep the horizontal field of view so the whole map stays visible.
func _fit_aspect() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	if s.y > s.x:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 62.0
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 42.0


func preset(name_id: String) -> void:
	match name_id:
		"close":
			set_view(Vector3(2, 0, 2), 0.5, 0.62, 34.0)
		"fort":
			set_view(Vector3(22, 0, 0), -0.6, 0.6, 30.0)
		"camp":
			set_view(Vector3(-38, 0, 0), 0.3, 0.7, 40.0)
		"top":
			set_view(Vector3(-2, 0, 0), 0.0, 1.25, 84.0)
		_:
			if portrait():
				# portrait: look along the roads so they run down the screen to the fortress
				set_view(Vector3(-4, 0, 0), PI / 2.0, 1.05, 60.0)
			else:
				set_view(Vector3(-2, 0, 0), -0.08, 0.8, 74.0)


func set_view(t: Vector3, y: float, p: float, d: float, snap: bool = false) -> void:
	_t_target = t
	_t_yaw = y
	_t_pitch = p
	_t_dist = d
	if snap:
		target = t
		yaw = y
		pitch = p
		dist = d
		_apply()


func focus(point: Vector3) -> void:
	_t_target = Vector3(point.x, 0, point.z)


func shake(amount: float) -> void:
	if Settings.is_low():
		amount *= 0.6
	_shake = minf(1.2, maxf(_shake, amount))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or cinematic:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[1]
			var d: float = a.distance_to(b)
			var ang: float = (b - a).angle()
			if _pinch_dist > 0.0:
				_t_dist = clampf(_t_dist * _pinch_dist / maxf(d, 1.0), MIN_DIST, MAX_DIST)
				_t_yaw -= wrapf(ang - _pinch_angle, -PI, PI)
			_pinch_dist = d
			_pinch_angle = ang
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _touches.size() >= 2:
			return
		if Input.is_action_pressed("cam_rotate_drag"):
			_t_yaw -= mm.relative.x * 0.006
			_t_pitch = clampf(_t_pitch + mm.relative.y * 0.004, MIN_PITCH, MAX_PITCH)
		elif Input.is_action_pressed("cam_pan_drag"):
			_pan(-mm.relative * dist * 0.0016)
	elif event.is_action_pressed("cam_zoom_in"):
		_t_dist = clampf(_t_dist * 0.9, MIN_DIST, MAX_DIST)
	elif event.is_action_pressed("cam_zoom_out"):
		_t_dist = clampf(_t_dist * 1.1, MIN_DIST, MAX_DIST)


## Screen-space pan on the ground plane.
func _pan(screen: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	_t_target += right * screen.x - fwd * screen.y
	_t_target.x = clampf(_t_target.x, BOUNDS.position.x, BOUNDS.end.x)
	_t_target.z = clampf(_t_target.z, BOUNDS.position.y, BOUNDS.end.y)


func _process(delta: float) -> void:
	if cinematic:
		_cine_t += delta
		_t_yaw += delta * 0.05
		_t_pitch = 0.78 + sin(_cine_t * 0.2) * 0.06
		_t_dist = 82.0
		_t_target = Vector3(0, 0, 0)
	elif input_enabled:
		var mv := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_forward", "cam_back"))
		if mv.length_squared() > 0.0:
			_pan(mv * delta * dist * 0.9)
		var rot: float = Input.get_axis("cam_rotate_left", "cam_rotate_right")
		_t_yaw += rot * delta * 1.6
		var zoom: float = Input.get_axis("cam_zoom_in_hold", "cam_zoom_out_hold")
		if zoom != 0.0:
			_t_dist = clampf(_t_dist * (1.0 + zoom * delta * 1.2), MIN_DIST, MAX_DIST)
	var k: float = 1.0 - exp(-delta * 8.0)
	target = target.lerp(_t_target, k)
	yaw = lerp_angle(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	dist = lerpf(dist, _t_dist, k)
	_shake = maxf(0.0, _shake - delta * 2.2)
	_apply()


func _apply() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var pos: Vector3 = target + offset
	if _shake > 0.0:
		var s: float = _shake * _shake * 1.4
		pos += Vector3(_rng.randf_range(-s, s), _rng.randf_range(-s, s), _rng.randf_range(-s, s))
	camera.global_position = pos
	camera.look_at(target, Vector3.UP)
