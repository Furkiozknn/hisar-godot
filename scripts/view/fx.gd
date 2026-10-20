class_name Fx
extends Node3D
## Pooled one-shot effects: CPUParticles3D bursts (dust, sparks, explosions, tar, gold
## glitter, blood at the gate) and floating Label3D text. Nothing is allocated per hit.

const POOL: int = 8

## kind -> settings used to build the pool
const KINDS: Dictionary = {
	"dust": {"amount": 22, "life": 0.7, "vel": [2.0, 4.0], "grav": -6.0, "spread": 70.0, "scale": [0.12, 0.22], "cols": [Color(0.8, 0.74, 0.62), Color(0.7, 0.64, 0.52, 0.0)], "puff": false},
	"spark": {"amount": 6, "life": 0.3, "vel": [1.0, 2.2], "grav": -4.0, "spread": 90.0, "scale": [0.06, 0.1], "cols": [Color(1.0, 0.95, 0.8), Color(0.95, 0.88, 0.7, 0.0)], "puff": false},
	"debris": {"amount": 22, "life": 0.65, "vel": [2.5, 5.5], "grav": -12.0, "spread": 60.0, "scale": [0.12, 0.24], "cols": [Color(0.61, 0.54, 0.43), Color(0.5, 0.44, 0.34, 0.0)], "puff": false},
	"fire": {"amount": 10, "life": 0.4, "vel": [1.5, 3.0], "grav": 2.0, "spread": 180.0, "scale": [0.5, 0.9], "cols": [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.45, 0.12, 0.8), Color(0.3, 0.25, 0.22, 0.0)], "puff": true},
	"smoke": {"amount": 8, "life": 1.1, "vel": [0.6, 1.4], "grav": 0.8, "spread": 50.0, "scale": [0.5, 0.9], "cols": [Color(0.92, 0.9, 0.85, 0.75), Color(0.8, 0.78, 0.74, 0.0)], "puff": true},
	"tar": {"amount": 16, "life": 0.55, "vel": [1.5, 3.5], "grav": -10.0, "spread": 70.0, "scale": [0.1, 0.2], "cols": [Color(0.16, 0.1, 0.05), Color(0.12, 0.08, 0.04, 0.0)], "puff": false},
	"gold": {"amount": 18, "life": 0.8, "vel": [1.5, 3.5], "grav": -3.0, "spread": 40.0, "scale": [0.08, 0.16], "cols": [Color(1.0, 0.86, 0.3), Color(1.0, 0.7, 0.1, 0.0)], "puff": false},
	"blood": {"amount": 18, "life": 0.6, "vel": [2.0, 3.5], "grav": -9.0, "spread": 80.0, "scale": [0.1, 0.18], "cols": [Color(0.73, 0.11, 0.11), Color(0.5, 0.05, 0.05, 0.0)], "puff": false},
	"firework": {"amount": 48, "life": 1.3, "vel": [6.0, 9.0], "grav": -5.0, "spread": 180.0, "scale": [0.22, 0.36], "cols": [Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1, 0.0)], "puff": false},
	"blaze": {"amount": 14, "life": 1.6, "vel": [1.0, 2.5], "grav": 2.5, "spread": 30.0, "scale": [1.6, 2.6], "cols": [Color(1.0, 0.8, 0.35, 1.0), Color(0.95, 0.4, 0.1, 0.85), Color(0.25, 0.22, 0.2, 0.7), Color(0.3, 0.28, 0.26, 0.0)], "puff": true},
	"death": {"amount": 12, "life": 0.7, "vel": [1.5, 3.5], "grav": -8.0, "spread": 75.0, "scale": [0.1, 0.2], "cols": [Color(0.85, 0.78, 0.63), Color(0.85, 0.78, 0.63, 0.0)], "puff": false},
}

var enabled: bool = true
var _pools: Dictionary = {}
var _next: Dictionary = {}
var _labels: Array[Label3D] = []
var _label_next: int = 0

static var _res: Dictionary = {}


static func clear_cache() -> void:
	_res.clear()


func _ready() -> void:
	for kind: String in KINDS:
		var list: Array[CPUParticles3D] = []
		for i: int in range(POOL):
			var p: CPUParticles3D = _make(KINDS[kind] as Dictionary)
			p.name = "%s_%d" % [kind, i]
			add_child(p)
			list.append(p)
		_pools[kind] = list
		_next[kind] = 0
	for i: int in range(28):
		var l := Label3D.new()
		l.name = "FloatText%d" % i
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.012
		l.font_size = 64
		l.outline_size = 14
		l.outline_modulate = Color(0.42, 0.24, 0.02)
		l.modulate = Color(0.99, 0.9, 0.54)
		l.font = Ui.bold_font()
		l.visible = false
		add_child(l)
		_labels.append(l)


func _make(d: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(d["amount"])
	p.lifetime = float(d["life"])
	p.local_coords = false
	var v: Array = d["vel"]
	p.initial_velocity_min = float(v[0])
	p.initial_velocity_max = float(v[1])
	p.direction = Vector3.UP
	p.spread = float(d["spread"])
	p.gravity = Vector3(0, float(d["grav"]), 0)
	var s: Array = d["scale"]
	p.scale_amount_min = float(s[0])
	p.scale_amount_max = float(s[1])
	var cols: Array = d["cols"]
	var stops: Array = []
	for i: int in range(cols.size()):
		stops.append(float(i) / float(cols.size() - 1))
	p.color_ramp = ramp(cols, stops)
	if bool(d["puff"]):
		p.mesh = puff_mesh()
		p.scale_amount_curve = grow_curve()
	else:
		p.mesh = chip_mesh()
		p.angle_max = 180.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.damping_min = 0.5
		p.damping_max = 1.5
	return p


## Fire a burst of `kind` at pos. amount_scale lets big hits look bigger.
func burst(kind: String, pos: Vector3, amount_scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	if not enabled or not _pools.has(kind):
		return
	var list: Array = _pools[kind]
	var i: int = int(_next[kind])
	_next[kind] = (i + 1) % list.size()
	var p: CPUParticles3D = list[i]
	var base: int = int((KINDS[kind] as Dictionary)["amount"])
	var low: float = 0.5 if Settings.is_low() else 1.0
	p.amount = maxi(2, int(float(base) * amount_scale * low))
	p.global_position = pos
	p.color = tint
	p.restart()


func float_text(text: String, pos: Vector3, col: Color = Color(0.99, 0.9, 0.54), size: float = 1.0) -> void:
	if not enabled:
		return
	var l: Label3D = _labels[_label_next]
	_label_next = (_label_next + 1) % _labels.size()
	if l.has_meta("tween"):
		var old: Tween = l.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
	l.text = text
	l.modulate = col
	l.outline_modulate = Color(col.r * 0.35, col.g * 0.25, col.b * 0.1, 1.0)
	l.position = pos
	l.scale = Vector3.ONE * 0.4 * size
	l.visible = true
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * size, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", pos + Vector3(0, 1.8, 0), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(func() -> void: l.visible = false)
	l.set_meta("tween", tw)


# ---------------------------------------------------------------- shared resources
static func ramp(cols: Array, stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops)
	g.colors = PackedColorArray(cols)
	return g


static func grow_curve() -> Curve:
	if _res.has("grow"):
		return _res["grow"] as Curve
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(0.3, 0.9))
	c.add_point(Vector2(1.0, 1.4))
	c.max_value = 1.5
	_res["grow"] = c
	return c


## Soft round billboard quad for smoke and fire.
static func puff_mesh() -> QuadMesh:
	if _res.has("puff"):
		return _res["puff"] as QuadMesh
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = ramp([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)], [0.0, 0.5, 1.0])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = m
	_res["puff"] = q
	return q


## Small lit chip for debris, sparks and drops.
static func chip_mesh() -> BoxMesh:
	if _res.has("chip"):
		return _res["chip"] as BoxMesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.8
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	b.material = m
	_res["chip"] = b
	return b
