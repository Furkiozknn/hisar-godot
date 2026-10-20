class_name Icon
extends Control
## UI pictograms: the painted PNG icons from res://assets/ui/icons (shared with the browser
## version) where one exists, otherwise a small vector drawing, so the UI never needs an
## emoji font. kind: gold, lives, wave, pause, play, speed, sound, mute, close, trophy,
## fire, gear, target, upgrade, fortress, archer, cannon, tar, raider, rider, shield, ram.

## Icon kinds with a painted PNG (kind -> file name).
const PNG: Dictionary = {
	"gold": "gold", "lives": "lives", "wave": "wave", "archer": "archer", "cannon": "cannon", "tar": "tar",
	"raider": "raider", "rider": "rider", "shield": "shield", "ram": "ram", "upgrade": "upgrade",
	"target": "target", "trophy": "trophy", "sound": "sound-on", "mute": "sound-off", "fortress": "fortress",
}

## False with --noassets: always draw the vector versions.
static var use_png: bool = true
static var _tex: Dictionary = {}

var kind: String = "gold":
	set(v):
		kind = v
		queue_redraw()
var tint: Color = Color(0.17, 0.13, 0.09)


static func make(k: String, px: float = 20.0) -> Icon:
	var i := Icon.new()
	i.kind = k
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return i


static func clear_cache() -> void:
	_tex.clear()


## The painted texture for a kind, or null.
static func texture(k: String) -> Texture2D:
	if not use_png or not PNG.has(k):
		return null
	if not _tex.has(k):
		var path: String = "res://assets/ui/icons/%s.png" % PNG[k]
		_tex[k] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[k] as Texture2D


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	var tex: Texture2D = texture(kind)
	if tex != null:
		draw_texture_rect(tex, Rect2(o, Vector2(s, s)), false)
		return
	var c := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match kind:
		"gold":
			draw_circle(c.call(0.5, 0.5), s * 0.44, Color(0.85, 0.55, 0.05))
			draw_circle(c.call(0.5, 0.47), s * 0.38, Color(0.99, 0.78, 0.2))
			draw_circle(c.call(0.5, 0.47), s * 0.22, Color(0.95, 0.66, 0.1))
		"lives":
			var red := Color(0.86, 0.15, 0.15)
			draw_circle(c.call(0.32, 0.36), s * 0.21, red)
			draw_circle(c.call(0.68, 0.36), s * 0.21, red)
			draw_colored_polygon(PackedVector2Array([c.call(0.12, 0.44), c.call(0.88, 0.44), c.call(0.5, 0.9)]), red)
			draw_circle(c.call(0.3, 0.32), s * 0.07, Color(1, 1, 1, 0.5))
		"wave":
			var steel := Color(0.42, 0.45, 0.5)
			draw_line(c.call(0.15, 0.15), c.call(0.82, 0.82), steel, s * 0.11)
			draw_line(c.call(0.85, 0.15), c.call(0.18, 0.82), steel, s * 0.11)
			draw_line(c.call(0.62, 0.78), c.call(0.82, 0.58), Color(0.55, 0.35, 0.15), s * 0.12)
			draw_line(c.call(0.38, 0.78), c.call(0.18, 0.58), Color(0.55, 0.35, 0.15), s * 0.12)
		"pause":
			draw_rect(Rect2(c.call(0.24, 0.18), Vector2(s * 0.17, s * 0.64)), tint)
			draw_rect(Rect2(c.call(0.59, 0.18), Vector2(s * 0.17, s * 0.64)), tint)
		"play":
			draw_colored_polygon(PackedVector2Array([c.call(0.28, 0.16), c.call(0.84, 0.5), c.call(0.28, 0.84)]), tint)
		"speed":
			draw_colored_polygon(PackedVector2Array([c.call(0.1, 0.2), c.call(0.5, 0.5), c.call(0.1, 0.8)]), tint)
			draw_colored_polygon(PackedVector2Array([c.call(0.48, 0.2), c.call(0.88, 0.5), c.call(0.48, 0.8)]), tint)
		"sound", "mute":
			draw_colored_polygon(PackedVector2Array([c.call(0.1, 0.36), c.call(0.3, 0.36), c.call(0.55, 0.14), c.call(0.55, 0.86), c.call(0.3, 0.64), c.call(0.1, 0.64)]), tint)
			if kind == "sound":
				draw_arc(c.call(0.55, 0.5), s * 0.2, -0.9, 0.9, 8, tint, s * 0.07)
				draw_arc(c.call(0.55, 0.5), s * 0.36, -0.9, 0.9, 10, tint, s * 0.07)
			else:
				draw_line(c.call(0.66, 0.34), c.call(0.92, 0.66), Color(0.86, 0.15, 0.15), s * 0.09)
				draw_line(c.call(0.92, 0.34), c.call(0.66, 0.66), Color(0.86, 0.15, 0.15), s * 0.09)
		"close":
			draw_line(c.call(0.22, 0.22), c.call(0.78, 0.78), tint, s * 0.12)
			draw_line(c.call(0.78, 0.22), c.call(0.22, 0.78), tint, s * 0.12)
		"trophy":
			var g := Color(0.96, 0.62, 0.04)
			draw_colored_polygon(PackedVector2Array([c.call(0.22, 0.12), c.call(0.78, 0.12), c.call(0.7, 0.5), c.call(0.5, 0.62), c.call(0.3, 0.5)]), g)
			draw_arc(c.call(0.22, 0.3), s * 0.13, PI * 0.5, PI * 1.5, 8, g, s * 0.06)
			draw_arc(c.call(0.78, 0.3), s * 0.13, -PI * 0.5, PI * 0.5, 8, g, s * 0.06)
			draw_rect(Rect2(c.call(0.45, 0.6), Vector2(s * 0.1, s * 0.18)), g)
			draw_rect(Rect2(c.call(0.3, 0.78), Vector2(s * 0.4, s * 0.1)), Color(0.55, 0.35, 0.15))
		"fire":
			draw_colored_polygon(PackedVector2Array([c.call(0.5, 0.06), c.call(0.82, 0.55), c.call(0.72, 0.85), c.call(0.28, 0.85), c.call(0.18, 0.55)]), Color(0.95, 0.4, 0.08))
			draw_colored_polygon(PackedVector2Array([c.call(0.5, 0.4), c.call(0.66, 0.68), c.call(0.6, 0.85), c.call(0.4, 0.85), c.call(0.34, 0.68)]), Color(1.0, 0.82, 0.3))
		"gear":
			for i: int in range(8):
				var a: float = float(i) / 8.0 * TAU
				draw_line(c.call(0.5, 0.5), c.call(0.5, 0.5) + Vector2(cos(a), sin(a)) * s * 0.42, tint, s * 0.16)
			draw_circle(c.call(0.5, 0.5), s * 0.3, tint)
			draw_circle(c.call(0.5, 0.5), s * 0.12, Color(1, 0.97, 0.9))
		"target":
			draw_arc(c.call(0.5, 0.5), s * 0.38, 0, TAU, 20, Color(0.86, 0.15, 0.15), s * 0.08)
			draw_arc(c.call(0.5, 0.5), s * 0.2, 0, TAU, 14, Color(0.86, 0.15, 0.15), s * 0.08)
			draw_circle(c.call(0.5, 0.5), s * 0.06, Color(0.86, 0.15, 0.15))
		"archer":
			draw_rect(Rect2(c.call(0.3, 0.42), Vector2(s * 0.4, s * 0.5)), Color(0.81, 0.77, 0.68))
			draw_rect(Rect2(c.call(0.24, 0.38), Vector2(s * 0.52, s * 0.08)), Color(0.55, 0.37, 0.2))
			draw_colored_polygon(PackedVector2Array([c.call(0.14, 0.4), c.call(0.86, 0.4), c.call(0.5, 0.06)]), Color(0.7, 0.15, 0.12))
			draw_rect(Rect2(c.call(0.45, 0.55), Vector2(s * 0.1, s * 0.16)), Color(0.23, 0.16, 0.1))
		"cannon":
			draw_circle(c.call(0.38, 0.66), s * 0.2, Color(0.23, 0.16, 0.1))
			draw_line(c.call(0.32, 0.58), c.call(0.86, 0.26), Color(0.19, 0.2, 0.23), s * 0.2)
			draw_circle(c.call(0.38, 0.66), s * 0.09, Color(0.55, 0.37, 0.2))
		"tar":
			draw_colored_polygon(PackedVector2Array([c.call(0.14, 0.3), c.call(0.86, 0.3), c.call(0.74, 0.74), c.call(0.26, 0.74)]), Color(0.17, 0.17, 0.17))
			draw_rect(Rect2(c.call(0.18, 0.27), Vector2(s * 0.64, s * 0.06)), Color(0.33, 0.35, 0.37))
			draw_colored_polygon(PackedVector2Array([c.call(0.5, 0.74), c.call(0.66, 0.96), c.call(0.34, 0.96)]), Color(1.0, 0.54, 0.16))
			draw_circle(c.call(0.6, 0.18), s * 0.07, Color(0.3, 0.2, 0.12))
		"raider":
			draw_rect(Rect2(c.call(0.32, 0.42), Vector2(s * 0.36, s * 0.48)), Color(0.71, 0.27, 0.18))
			draw_circle(c.call(0.5, 0.3), s * 0.15, Color(0.89, 0.71, 0.55))
			draw_colored_polygon(PackedVector2Array([c.call(0.32, 0.24), c.call(0.68, 0.24), c.call(0.5, 0.04)]), Color(0.44, 0.45, 0.48))
			draw_line(c.call(0.8, 0.1), c.call(0.8, 0.92), Color(0.48, 0.35, 0.23), s * 0.06)
		"rider":
			draw_rect(Rect2(c.call(0.12, 0.45), Vector2(s * 0.62, s * 0.24)), Color(0.48, 0.31, 0.18))
			draw_line(c.call(0.7, 0.5), c.call(0.86, 0.3), Color(0.48, 0.31, 0.18), s * 0.14)
			for x: float in [0.18, 0.3, 0.56, 0.68]:
				draw_line(c.call(x, 0.66), c.call(x, 0.9), Color(0.36, 0.23, 0.13), s * 0.07)
			draw_rect(Rect2(c.call(0.36, 0.2), Vector2(s * 0.16, s * 0.26)), Color(0.54, 0.17, 0.17))
			draw_circle(c.call(0.44, 0.14), s * 0.1, Color(0.89, 0.71, 0.55))
		"shield":
			draw_rect(Rect2(c.call(0.28, 0.4), Vector2(s * 0.44, s * 0.5)), Color(0.35, 0.38, 0.44))
			draw_circle(c.call(0.5, 0.28), s * 0.14, Color(0.89, 0.71, 0.55))
			draw_rect(Rect2(c.call(0.18, 0.45), Vector2(s * 0.5, s * 0.46)), Color(0.54, 0.35, 0.17))
			draw_rect(Rect2(c.call(0.38, 0.62), Vector2(s * 0.1, s * 0.1)), Color(0.79, 0.64, 0.15))
		"ram":
			draw_rect(Rect2(c.call(0.1, 0.45), Vector2(s * 0.7, s * 0.28)), Color(0.43, 0.29, 0.16))
			draw_colored_polygon(PackedVector2Array([c.call(0.1, 0.45), c.call(0.8, 0.45), c.call(0.45, 0.16)]), Color(0.3, 0.23, 0.16))
			draw_line(c.call(0.6, 0.6), c.call(0.96, 0.6), Color(0.49, 0.51, 0.53), s * 0.1)
			draw_circle(c.call(0.24, 0.8), s * 0.1, Color(0.23, 0.16, 0.1))
			draw_circle(c.call(0.66, 0.8), s * 0.1, Color(0.23, 0.16, 0.1))
		"upgrade":
			var g := Color(0.96, 0.62, 0.04)
			draw_colored_polygon(PackedVector2Array([c.call(0.5, 0.1), c.call(0.86, 0.5), c.call(0.62, 0.5), c.call(0.62, 0.88), c.call(0.38, 0.88), c.call(0.38, 0.5), c.call(0.14, 0.5)]), g)
		"fortress":
			var st := Color(0.81, 0.77, 0.68)
			draw_rect(Rect2(c.call(0.18, 0.42), Vector2(s * 0.64, s * 0.48)), st)
			for x: float in [0.18, 0.43, 0.68]:
				draw_rect(Rect2(c.call(x, 0.3), Vector2(s * 0.14, s * 0.14)), st)
			draw_rect(Rect2(c.call(0.42, 0.64), Vector2(s * 0.16, s * 0.26)), Color(0.23, 0.16, 0.1))
		_:
			draw_circle(c.call(0.5, 0.5), s * 0.3, tint)
