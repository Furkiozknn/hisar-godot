class_name Ui
extends CanvasLayer
## The whole 2D interface, built in code with one warm "glass" theme: the HUD (stats,
## buttons, next-wave box, build / tower panel, boss bar, toasts, red damage vignette)
## and the overlay screens (title, pause, settings, end) with fade and scale transitions.
## It scales itself to the window and switches to a stacked layout on narrow screens.

signal action(name: StringName, arg: Variant)

const INK: Color = Color(0.17, 0.13, 0.09)
const ACCENT: Color = Color(0.96, 0.62, 0.04)
const ACCENT_2: Color = Color(0.98, 0.75, 0.14)
const OK: Color = Color(0.09, 0.64, 0.29)
const DANGER: Color = Color(0.86, 0.15, 0.15)

var sim: BattleSim = null
var screen: String = ""
var compact: bool = false
var speed: int = 1
var selected_pad: int = -1

var root: Control
var _hud: Control
var _stats_panel: PanelContainer
var _btn_panel: PanelContainer
var _gold_lbl: Label
var _lives_lbl: Label
var _wave_lbl: Label
var _gold_chip: Control
var _lives_chip: Control
var _logo_sub: Label
var _speed_btn: Button
var _pause_btn: Button
var _sound_btn: Button
var _lang_btn: Button
var _wavebox: PanelContainer
var _wave_box_inner: BoxContainer
var _next_lbl: Label
var _preview: HBoxContainer
var _wave_btn: Button
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _boss: PanelContainer
var _boss_bar: ProgressBar
var _boss_lbl: Label
var _toasts: VBoxContainer
var _vignette: ColorRect
var _overlay: Control
var _dim: ColorRect
var _card: PanelContainer
var _card_body: VBoxContainer
var _focus_first: Control = null
var _card_inner: float = 480.0

var _last_gold: int = -1
var _last_lives: int = -1
var _last_wave_text: String = ""
var _panel_key: String = ""
var _pulse: Tween
var _scale: float = 1.0
var _vig_mat: ShaderMaterial
var _vig: float = 0.0
var _dirty: bool = false

static var _fonts: Dictionary = {}


static func clear_cache() -> void:
	_fonts.clear()


# ---------------------------------------------------------------- theme
static func bold_font() -> Font:
	if not _fonts.has("bold"):
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 0.7
		_fonts["bold"] = f
	return _fonts["bold"] as Font


static func _box(bg: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if shadow > 0:
		s.shadow_color = Color(0.24, 0.14, 0.04, 0.2)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	var line := Color(0.31, 0.22, 0.12, 0.2)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_font("font", "Button", bold_font())
	t.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.72), 10, line, 1))
	t.set_stylebox("hover", "Button", _box(Color(1, 1, 1, 0.98), 10, line, 1))
	t.set_stylebox("pressed", "Button", _box(Color(0.93, 0.88, 0.8, 1), 10, line, 1))
	t.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.3), 10, Color(line, 0.1), 1))
	var focus := _box(Color(0, 0, 0, 0), 10, ACCENT, 2)
	t.set_stylebox("focus", "Button", focus)
	# primary (amber) buttons
	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", _box(ACCENT_2, 10, Color(0.85, 0.47, 0.02), 1))
	t.set_stylebox("hover", "Primary", _box(Color(0.99, 0.83, 0.3), 10, Color(0.85, 0.47, 0.02), 1))
	t.set_stylebox("pressed", "Primary", _box(ACCENT, 10, Color(0.85, 0.47, 0.02), 1))
	t.set_stylebox("disabled", "Primary", _box(Color(0.98, 0.75, 0.14, 0.35), 10, Color(0.85, 0.47, 0.02, 0.2), 1))
	t.set_color("font_color", "Primary", Color(0.23, 0.14, 0.02))
	# glass panels
	t.set_stylebox("panel", "PanelContainer", _box(Color(1.0, 0.97, 0.92, 0.82), 14, Color(1, 1, 1, 0.65), 1, 12))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", _box(Color(1, 1, 1, 0.58), 10))
	t.set_type_variation("DarkToast", "PanelContainer")
	t.set_stylebox("panel", "DarkToast", _box(Color(0.17, 0.13, 0.09, 0.86), 10, Color(0, 0, 0, 0), 0, 8))
	# sliders and bars
	var track := _box(Color(0.31, 0.22, 0.12, 0.18), 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT_2, 6))
	t.set_stylebox("background", "ProgressBar", _box(Color(0.14, 0.1, 0.07, 0.85), 6))
	t.set_stylebox("fill", "ProgressBar", _box(DANGER, 6))
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_focus_color", "CheckButton", INK)
	return t


# ---------------------------------------------------------------- build
func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "Root"
	root.theme = _make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_vignette()
	_build_hud()
	_build_overlay()
	get_viewport().size_changed.connect(_on_resize)
	Loc.language_changed.connect(_retext)
	Settings.changed.connect(func(_k: StringName) -> void: _refresh_sound_btn())
	for c: Control in [_stats_panel, _btn_panel, _wavebox, _panel, _boss, _card]:
		c.minimum_size_changed.connect(func() -> void: _dirty = true)
	_on_resize()


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "DamageVignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float strength = 0.0;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5));\n\tCOLOR = vec4(0.86, 0.1, 0.1, smoothstep(0.3, 0.75, d) * strength);\n}\n"
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = sh
	_vignette.material = _vig_mat
	root.add_child(_vignette)


func _label(text: String, size: int = 16, bold: bool = false, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, act: StringName, arg: Variant = null, primary: bool = false, icon_kind: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.theme_type_variation = "Primary"
	if icon_kind != "":
		var ic: Icon = Icon.make(icon_kind, 18)
		b.add_child(ic)
		ic.position = Vector2(10, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.resized.connect(func() -> void: ic.position = Vector2(10, (b.size.y - 18.0) / 2.0))
		b.add_theme_constant_override("h_separation", 6)
		if text != "":
			b.text = "      " + text
	b.pressed.connect(func() -> void:
		Sound.play("click")
		action.emit(act, arg))
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


func _icon_button(kind: String, act: StringName, tip: String = "") -> Button:
	var b: Button = _button("", act)
	b.custom_minimum_size = Vector2(40, 36)
	b.tooltip_text = tip
	var ic: Icon = Icon.make(kind, 20)
	ic.position = Vector2(10, 8)
	b.add_child(ic)
	b.resized.connect(func() -> void: ic.position = (b.size - Vector2(20, 20)) / 2.0)
	b.set_meta("icon", ic)
	return b


func _chip(kind: String) -> Array:
	var p := PanelContainer.new()
	p.theme_type_variation = "Chip"
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(Icon.make(kind, 20))
	var l: Label = _label("0", 17, true)
	h.add_child(l)
	p.add_child(h)
	return [p, l]


func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "Hud"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_hud)
	# stats (top left)
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "Stats"
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	var logo: Label = _label("Hisar", 21, true)
	sh.add_child(logo)
	_logo_sub = _label("", 13, false, Color(INK, 0.65))
	_logo_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_logo_sub)
	var g: Array = _chip("gold")
	_gold_chip = g[0]
	_gold_lbl = g[1]
	var lv: Array = _chip("lives")
	_lives_chip = lv[0]
	_lives_lbl = lv[1]
	var wv: Array = _chip("wave")
	_wave_lbl = wv[1]
	for c: Control in [_gold_chip, _lives_chip, wv[0] as Control]:
		sh.add_child(c)
	_stats_panel.add_child(sh)
	_hud.add_child(_stats_panel)
	# buttons (top right)
	_btn_panel = PanelContainer.new()
	_btn_panel.name = "Buttons"
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 6)
	_speed_btn = _button("1x", &"speed")
	_speed_btn.custom_minimum_size = Vector2(44, 36)
	_speed_btn.tooltip_text = "F"
	_pause_btn = _icon_button("pause", &"pause", "P / Esc")
	_sound_btn = _icon_button("sound", &"mute")
	_lang_btn = _button("EN", &"lang")
	_lang_btn.custom_minimum_size = Vector2(44, 36)
	for b: Button in [_speed_btn, _pause_btn, _sound_btn, _lang_btn]:
		b.focus_mode = Control.FOCUS_NONE
		bh.add_child(b)
	_btn_panel.add_child(bh)
	_hud.add_child(_btn_panel)
	# boss bar
	_boss = PanelContainer.new()
	_boss.name = "BossBar"
	var bv := VBoxContainer.new()
	var bt := HBoxContainer.new()
	bt.add_child(Icon.make("ram", 22))
	_boss_lbl = _label("", 15, true)
	bt.add_child(_boss_lbl)
	bv.add_child(bt)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(240, 12)
	_boss_bar.max_value = 1.0
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(_boss_bar)
	_boss.add_child(bv)
	_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.visible = false
	_hud.add_child(_boss)
	# toasts
	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	_hud.add_child(_toasts)
	# next wave box
	_wavebox = PanelContainer.new()
	_wavebox.name = "WaveBox"
	_wave_box_inner = BoxContainer.new()
	_wave_box_inner.vertical = true
	_wave_box_inner.add_theme_constant_override("separation", 6)
	_next_lbl = _label("", 12, false, Color(INK, 0.7))
	_wave_box_inner.add_child(_next_lbl)
	_preview = HBoxContainer.new()
	_preview.custom_minimum_size = Vector2(0, 28)
	_preview.add_theme_constant_override("separation", 6)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_box_inner.add_child(_preview)
	_wave_btn = _button("", &"wave", null, true)
	_wave_btn.custom_minimum_size = Vector2(0, 44)
	_wave_btn.add_theme_font_size_override("font_size", 16)
	_wave_btn.focus_mode = Control.FOCUS_NONE
	_wave_box_inner.add_child(_wave_btn)
	_wavebox.add_child(_wave_box_inner)
	_hud.add_child(_wavebox)
	# build / tower panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 8)
	_panel.add_child(_panel_body)
	_panel.visible = false
	_hud.add_child(_panel)
	_hud.visible = false


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.16, 0.1, 0.04, 0.38)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_dim)
	_card = PanelContainer.new()
	_card.name = "Card"
	var sb: StyleBoxFlat = _box(Color(1.0, 0.97, 0.92, 0.9), 18, Color(1, 1, 1, 0.7), 1, 24)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	_card.add_theme_stylebox_override("panel", sb)
	_card_body = VBoxContainer.new()
	_card_body.add_theme_constant_override("separation", 12)
	_card.add_child(_card_body)
	_overlay.add_child(_card)
	_overlay.visible = false


# ---------------------------------------------------------------- layout
func _on_resize() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	if s.x >= s.y:
		_scale = clampf(minf(s.x / 1150.0, s.y / 680.0), 0.6, 2.5)
	else:
		_scale = clampf(s.x / 430.0, 0.6, 2.5)
	scale = Vector2(_scale, _scale)
	var v: Vector2 = s / _scale
	root.position = Vector2.ZERO
	root.size = v
	compact = v.x < 760.0
	_layout(v)


func _layout(v: Vector2) -> void:
	var m: float = 10.0
	_logo_sub.visible = not compact
	_stats_panel.reset_size()
	_btn_panel.reset_size()
	_stats_panel.position = Vector2(m, m)
	if compact:
		_stats_panel.size.x = v.x - 2.0 * m
		_btn_panel.position = Vector2(v.x - m - _btn_panel.size.x, m + _stats_panel.size.y + 6.0)
	else:
		_btn_panel.position = Vector2(v.x - m - _btn_panel.size.x, m)
	var top_bottom: float = _btn_panel.position.y + _btn_panel.size.y if compact else _stats_panel.position.y + _stats_panel.size.y
	_toasts.position = Vector2(m, top_bottom + 10.0)
	_toasts.size = Vector2(v.x - 2.0 * m, 10)
	_boss.reset_size()
	_boss.position = Vector2((v.x - _boss.size.x) / 2.0, top_bottom + (54.0 if compact else 10.0))
	_wave_box_inner.vertical = not compact
	_next_lbl.visible = not compact
	_wavebox.reset_size()
	if compact:
		_wave_btn.custom_minimum_size = Vector2(170, 44)
		_wavebox.size = Vector2(v.x - 2.0 * m, 0)
		_wavebox.reset_size()
		_wavebox.size.x = v.x - 2.0 * m
		_wavebox.position = Vector2(m, v.y - m - _wavebox.size.y)
	else:
		_wave_btn.custom_minimum_size = Vector2(0, 44)
		_wavebox.size = Vector2(260, 0)
		_wavebox.reset_size()
		_wavebox.size.x = 260
		_wavebox.position = Vector2(v.x - m - 260.0, v.y - m - _wavebox.size.y)
	_layout_panel(v)
	_layout_card(v)


func _layout_panel(v: Vector2) -> void:
	if not _panel.visible:
		return
	var m: float = 10.0
	var w: float = v.x - 2.0 * m if compact else minf(580.0, v.x - 300.0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.size.x = w
	var bottom: float = (_wavebox.position.y - 8.0) if compact else (v.y - m)
	_panel.position = Vector2((v.x - w) / 2.0 if not compact else m, bottom - _panel.size.y)


func _layout_card(v: Vector2) -> void:
	if not _overlay.visible:
		return
	var w: float = minf(540.0, v.x - 32.0)
	_card.custom_minimum_size = Vector2(w, 0)
	_card.size = Vector2(w, 0)
	_card.reset_size()
	_card.position = (v - _card.size) / 2.0
	_card.pivot_offset = _card.size / 2.0


# ---------------------------------------------------------------- HUD
func show_hud(on: bool) -> void:
	_hud.visible = on
	if on:
		_last_gold = -1
		_last_lives = -1
		_last_wave_text = ""
		_retext()


func bind(battle: BattleSim) -> void:
	sim = battle
	close_panel()
	for c: Node in _toasts.get_children():
		c.queue_free()
	_last_gold = -1
	_last_lives = -1
	_last_wave_text = ""


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_layout(root.size)
	if sim == null or not _hud.visible:
		return
	if sim.gold != _last_gold:
		if _last_gold >= 0:
			_bump(_gold_chip, Color(1, 1, 1))
		_last_gold = sim.gold
		_gold_lbl.text = str(sim.gold)
		_refresh_panel()
	if sim.lives != _last_lives:
		if _last_lives >= 0 and sim.lives < _last_lives:
			_bump(_lives_chip, Color(1.3, 0.6, 0.6))
		_last_lives = sim.lives
		_lives_lbl.text = str(sim.lives)
	var wt: String = "%s %d/%s" % [Loc.t("wave"), sim.wave, _infinity() if sim.endless else str(sim.data.config.max_waves)]
	if wt != _last_wave_text:
		_last_wave_text = wt
		_wave_lbl.text = wt
		_refresh_wave_box()
	_update_wave_button()
	var b: BattleSim.Enemy = sim.boss()
	_boss.visible = b != null and not sim.over
	_wavebox.visible = not sim.over
	if b != null:
		_boss_bar.value = lerpf(_boss_bar.value, b.hp / b.max_hp, 1.0 - exp(-delta * 10.0))
	if _vig > 0.0:
		_vig = maxf(0.0, _vig - delta * 1.4)
		_vig_mat.set_shader_parameter("strength", _vig)


func _bump(c: Control, flash: Color) -> void:
	c.pivot_offset = c.size / 2.0
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(c, "modulate", flash, 0.12)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate", Color.WHITE, 0.3)


func damage_flash(amount: float) -> void:
	_vig = clampf(amount, 0.0, 1.0)
	_vig_mat.set_shader_parameter("strength", _vig)


func _update_wave_button() -> void:
	var can: bool = sim.can_call_wave()
	var txt: String
	if not sim.queue.is_empty():
		txt = Loc.t("waveRunning", {"n": sim.wave})
	elif can:
		txt = Loc.t("callEarly" if sim.phase == &"wave" else "startWave", {"n": sim.wave + 1})
	else:
		txt = "-"
	if _wave_btn.text != txt:
		_wave_btn.text = txt
		_refresh_wave_box()
	_wave_btn.disabled = not can
	var want_pulse: bool = can and sim.phase == &"build"
	if want_pulse and (_pulse == null or not _pulse.is_valid()):
		_pulse = _wave_btn.create_tween().set_loops()
		_pulse.tween_property(_wave_btn, "modulate", Color(1.12, 1.05, 0.9), 0.7).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_wave_btn, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
	elif not want_pulse and _pulse != null and _pulse.is_valid():
		_pulse.kill()
		_wave_btn.modulate = Color.WHITE


func _refresh_wave_box() -> void:
	for c: Node in _preview.get_children():
		c.queue_free()
	if sim == null:
		return
	var next: int = sim.wave + 1
	if sim.has_more_waves():
		var counts: Dictionary = sim.wave_counts(next)
		for type: StringName in GameData.ENEMY_ORDER:
			if not counts.has(type):
				continue
			var chip := PanelContainer.new()
			chip.theme_type_variation = "Chip"
			chip.tooltip_text = Loc.t(String(type))
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 4)
			h.add_child(Icon.make(String(type), 18))
			h.add_child(_label(str(counts[type]), 14, true))
			chip.add_child(h)
			_preview.add_child(chip)
	_next_lbl.text = Loc.t("next")
	_dirty = true


func clear_toasts() -> void:
	_clear(_toasts)


func toast(msg: String) -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = "DarkToast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l: Label = _label(msg, 15, true, Color(1.0, 0.97, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate = Color(1, 1, 1, 0)
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- build / tower panel
func open_pad(pad: int) -> void:
	selected_pad = pad
	_panel_key = ""
	_refresh_panel()


func close_panel() -> void:
	selected_pad = -1
	_panel_key = ""
	_panel.visible = false


func panel_open() -> bool:
	return _panel.visible


func _clear(c: Node) -> void:
	for n: Node in c.get_children():
		c.remove_child(n)
		n.queue_free()


func _refresh_panel() -> void:
	if sim == null or selected_pad < 0:
		_panel.visible = false
		return
	var t: BattleSim.Tower = sim.tower_on_pad(selected_pad)
	var key: String = "build" if t == null else "tower_%d_%d_%s" % [t.uid, t.level, t.mode]
	var first: bool = not _panel.visible
	if key == _panel_key:
		_update_affordability()
		return
	_panel_key = key
	_clear(_panel_body)
	if t == null:
		_fill_build()
	else:
		_fill_tower(t)
	_panel.visible = true
	_layout_panel(root.size)
	if first:
		_panel.modulate = Color(1, 1, 1, 0)
		var y: float = _panel.position.y
		_panel.position.y = y + 16.0
		var tw: Tween = _panel.create_tween().set_parallel(true)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
		tw.tween_property(_panel, "position:y", y, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_affordability()


func _header(text: String, icon_kind: String, level: int = -1) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon_kind != "":
		h.add_child(Icon.make(icon_kind, 24))
	h.add_child(_label(text, 17, true))
	if level >= 0:
		var dots := HBoxContainer.new()
		dots.add_theme_constant_override("separation", 3)
		dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for i: int in range(3):
			var d := Panel.new()
			d.custom_minimum_size = Vector2(10, 10)
			d.add_theme_stylebox_override("panel", _box(ACCENT if i <= level else Color(0, 0, 0, 0.15), 5))
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dots.add_child(d)
		h.add_child(dots)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	var x: Button = _icon_button("close", &"close_panel", "Esc")
	x.custom_minimum_size = Vector2(32, 30)
	x.focus_mode = Control.FOCUS_NONE
	h.add_child(x)
	return h


func _fill_build() -> void:
	_panel_body.add_child(_header(Loc.t("build"), ""))
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	var i: int = 0
	for type: StringName in GameData.TOWER_ORDER:
		i += 1
		var td: TowerData = sim.data.tower(type)
		var b: Button = _button("", &"build", type)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("cost", td.cost[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58 if compact else 118)
		b.tooltip_text = "%s (%d)" % [Loc.t(td.name_key), i]
		var mc := MarginContainer.new()
		mc.set_anchors_preset(Control.PRESET_FULL_RECT)
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side: String in ["left", "right", "top", "bottom"]:
			mc.add_theme_constant_override("margin_" + side, 8)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(Icon.make(String(type), 24))
		top.add_child(_label(Loc.t(td.name_key), 15, true))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(sp)
		if compact:
			top.add_child(Icon.make("gold", 16))
			top.add_child(_label(str(td.cost[0]), 15, true))
		top.add_child(_label(str(i), 11, false, Color(INK, 0.5)))
		v.add_child(top)
		var desc: Label = _label(Loc.t(td.desc_key), 12, false, Color(INK, 0.75))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(desc)
		if not compact:
			var cost := HBoxContainer.new()
			cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost.add_child(Icon.make("gold", 16))
			cost.add_child(_label(str(td.cost[0]), 15, true))
			v.add_child(cost)
		mc.add_child(v)
		b.add_child(mc)
		b.mouse_entered.connect(func() -> void: action.emit(&"preview_range", td.stat(td.reach, 0)))
		b.mouse_exited.connect(func() -> void: action.emit(&"preview_range", -1.0))
		grid.add_child(b)
	_panel_body.add_child(grid)


static func _infinity() -> String:
	return "∞" if ThemeDB.fallback_font.has_char(0x221E) else "-"


static func _fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.1f" % v


func _fill_tower(t: BattleSim.Tower) -> void:
	var td: TowerData = t.data
	_panel_body.add_child(_header(Loc.t(td.name_key), String(t.type), t.level))
	var box := BoxContainer.new()
	box.vertical = compact
	box.add_theme_constant_override("separation", 14)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv: int = t.level
	var nx: int = lv + 1 if lv < td.levels() - 1 else -1
	var rows: Array = [["range", td.reach, func(x: float) -> String: return _fmt(x)]]
	if t.type == &"tar":
		rows.append(["dps", td.burn_dps, func(x: float) -> String: return _fmt(x)])
		rows.append(["slow", td.slow, func(x: float) -> String: return "%d%%" % roundi((1.0 - x) * 100.0)])
	else:
		rows.append(["dmg", td.damage, func(x: float) -> String: return _fmt(x)])
	rows.append(["rate", td.rate, func(x: float) -> String: return _fmt(snappedf(1.0 / x, 0.1))])
	if not td.splash.is_empty():
		rows.append(["splash", td.splash, func(x: float) -> String: return _fmt(x)])
	for r: Array in rows:
		var vals: PackedFloat32Array = r[1]
		var f: Callable = r[2]
		var cur: String = f.call(td.stat(vals, lv))
		var h := HBoxContainer.new()
		h.add_child(_label(Loc.t(String(r[0])), 13, false, Color(INK, 0.8)))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		h.add_child(_label(cur, 13, true))
		if nx >= 0:
			var nv: String = f.call(td.stat(vals, nx))
			if nv != cur:
				h.add_child(_label(" » " + nv, 13, true, OK))
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(h)
	var kh := HBoxContainer.new()
	kh.add_child(_label(Loc.t("kills"), 13, false, Color(INK, 0.8)))
	var ksp := Control.new()
	ksp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(ksp)
	kh.add_child(_label(str(t.kills), 13, true))
	kh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(kh)
	box.add_child(grid)
	var btns := BoxContainer.new()
	btns.vertical = not compact
	btns.add_theme_constant_override("separation", 6)
	btns.custom_minimum_size = Vector2(0 if compact else 170, 0)
	var up_cost: int = sim.upgrade_cost(t)
	var up: Button = _button(Loc.t("maxed") if up_cost < 0 else "%s  %d" % [Loc.t("upgrade"), up_cost], &"upgrade", null, true)
	up.tooltip_text = "U"
	up.set_meta("cost", up_cost)
	up.disabled = up_cost < 0
	var mode_key: String = {&"first": "mFirst", &"strong": "mStrong", &"near": "mNear"}[t.mode]
	var mode: Button = _button("%s: %s" % [Loc.t("target"), Loc.t(mode_key)], &"mode")
	mode.tooltip_text = "T"
	var sell: Button = _button("%s  +%d" % [Loc.t("sell"), sim.refund(t)], &"sell")
	sell.tooltip_text = "S"
	for b: Button in [up, mode, sell]:
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(b)
	box.add_child(btns)
	_panel_body.add_child(box)


func _update_affordability() -> void:
	if sim == null:
		return
	var stack: Array[Node] = [_panel_body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.has_meta("cost"):
			var c: int = int(n.get_meta("cost"))
			(n as Button).disabled = c < 0 or sim.gold < c or sim.over
		stack.append_array(n.get_children())


# ---------------------------------------------------------------- overlay screens
func show_screen(name_id: String, data: Dictionary = {}) -> void:
	var was: bool = _overlay.visible
	screen = name_id
	_card_inner = minf(540.0, root.size.x - 32.0) - 52.0
	_clear(_card_body)
	_focus_first = null
	match name_id:
		"title":
			_fill_title(data)
		"pause":
			_fill_pause()
		"settings":
			_fill_settings()
		"over":
			_fill_over(data)
	_overlay.visible = true
	_layout_card(root.size)
	if _focus_first != null:
		_grab_later.call_deferred(_focus_first)
	var tw: Tween = _card.create_tween().set_parallel(true)
	if not was:
		_overlay.modulate = Color(1, 1, 1, 0)
		tw.tween_property(_overlay, "modulate:a", 1.0, 0.25)
	_card.scale = Vector2(0.93, 0.93)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _grab_later(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
		c.grab_focus()


func hide_screen() -> void:
	if not _overlay.visible:
		return
	screen = ""
	var tw: Tween = _overlay.create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if screen == "":
			_overlay.visible = false)


func overlay_open() -> bool:
	return _overlay.visible and screen != ""


func _centered(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _para(text: String, size: int = 15, col: Color = INK) -> Label:
	var l: Label = _label(text, size, false, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(_card_inner, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	return l


func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.alignment = FlowContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("h_separation", 8)
	r.add_theme_constant_override("v_separation", 8)
	return r


func _fill_title(data: Dictionary) -> void:
	var title: Label = _label("Hisar", 64 if not compact else 52, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(1, 0.9, 0.7))
	title.add_theme_constant_override("outline_size", 6)
	_card_body.add_child(title)
	var sub: Label = _label(Loc.t("sub").to_upper(), 15, false, Color(INK, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_body.add_child(sub)
	_card_body.add_child(_para(Loc.t("intro")))
	var r: HFlowContainer = _row()
	var play: Button = _button(Loc.t("play"), &"play", null, true, "play")
	play.custom_minimum_size = Vector2(150, 50)
	play.add_theme_font_size_override("font_size", 19)
	r.add_child(play)
	_focus_first = play
	var cont: int = int(data.get("continue_wave", 0))
	if cont > 0:
		var cb: Button = _button(Loc.t("continue", {"n": cont + 1}), &"continue")
		cb.custom_minimum_size = Vector2(0, 50)
		r.add_child(cb)
	_card_body.add_child(r)
	var r2: HFlowContainer = _row()
	var sb: Button = _button(Loc.t("settings"), &"open_settings", null, false, "gear")
	sb.custom_minimum_size = Vector2(0, 38)
	r2.add_child(sb)
	var lb: Button = _button("English" if Settings.language == "tr" else "Türkçe", &"lang")
	lb.custom_minimum_size = Vector2(110, 38)
	r2.add_child(lb)
	_card_body.add_child(r2)
	var touch: bool = DisplayServer.is_touchscreen_available() and compact
	_card_body.add_child(_para(Loc.t("controlsTouch" if touch else "controls"), 12, Color(INK, 0.72)))
	var best: int = int(data.get("best", 0))
	if best > 0:
		var bh := HBoxContainer.new()
		bh.alignment = BoxContainer.ALIGNMENT_CENTER
		bh.add_child(Icon.make("trophy", 18))
		bh.add_child(_label(Loc.t("best", {"n": best}), 13, true, Color(INK, 0.75)))
		_card_body.add_child(bh)
	_card_body.add_child(_para(Loc.t("credits"), 11, Color(INK, 0.5)))


func _fill_pause() -> void:
	var h: Label = _label(Loc.t("paused"), 34, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_body.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var resume: Button = _button(Loc.t("resume"), &"resume", null, true, "play")
	_focus_first = resume
	for b: Button in [resume, _button(Loc.t("settings"), &"open_settings", null, false, "gear"), _button(Loc.t("restart"), &"restart"), _button(Loc.t("mainMenu"), &"main_menu")]:
		b.custom_minimum_size = Vector2(260, 42)
		v.add_child(b)
	_card_body.add_child(_centered(v))


func _slider_row(key: String, setting: StringName, value: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l: Label = _label(Loc.t(key), 15)
	l.custom_minimum_size = Vector2(130, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(120, 24)
	var pct: Label = _label("%d%%" % roundi(value * 100.0), 14, true)
	pct.custom_minimum_size = Vector2(46, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(x: float) -> void:
		pct.text = "%d%%" % roundi(x * 100.0)
		Settings.set_value(setting, x)
		if setting == &"sfx_volume":
			Sound.play("coin"))
	h.add_child(s)
	h.add_child(pct)
	if _focus_first == null:
		_focus_first = s
	return h


func _choice_row(key: String, options: Array, current: String, setting: StringName) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l: Label = _label(Loc.t(key), 15)
	l.custom_minimum_size = Vector2(130, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for o: Array in options:
		var val: String = o[0]
		var b: Button = _button(String(o[1]), &"setting", [setting, val], val == current)
		b.custom_minimum_size = Vector2(92, 36)
		h.add_child(b)
	return h


func _fill_settings() -> void:
	var h: Label = _label(Loc.t("settings"), 30, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_body.add_child(h)
	_card_body.add_child(_slider_row("master", &"master_volume", Settings.master_volume))
	_card_body.add_child(_slider_row("music", &"music_volume", Settings.music_volume))
	_card_body.add_child(_slider_row("sfx", &"sfx_volume", Settings.sfx_volume))
	_card_body.add_child(_choice_row("language", [["tr", "Türkçe"], ["en", "English"]], Settings.language, &"language"))
	_card_body.add_child(_choice_row("quality", [["low", Loc.t("qLow")], ["high", Loc.t("qHigh")]], Settings.quality, &"quality"))
	_card_body.add_child(_choice_row("fullscreen", [["off", Loc.t("off")], ["on", Loc.t("on")]], "on" if Settings.fullscreen else "off", &"fullscreen"))
	var back: Button = _button(Loc.t("back"), &"settings_back", null, true)
	back.custom_minimum_size = Vector2(200, 42)
	_card_body.add_child(_centered(back))


func _fill_over(data: Dictionary) -> void:
	var won: bool = bool(data.get("won", false))
	var hh := HBoxContainer.new()
	hh.alignment = BoxContainer.ALIGNMENT_CENTER
	hh.add_theme_constant_override("separation", 10)
	hh.add_child(Icon.make("trophy" if won else "fire", 40))
	hh.add_child(_label(Loc.t("winTitle" if won else "lostTitle"), 40 if not compact else 32, true))
	_card_body.add_child(hh)
	_card_body.add_child(_para(Loc.t("winText") if won else Loc.t("lostText", {"n": int(data.get("wave", 0))})))
	if bool(data.get("new_best", false)):
		var nb: Label = _label(Loc.t("newBest"), 18, true, Color(0.85, 0.47, 0.02))
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_body.add_child(nb)
		nb.pivot_offset = Vector2(120, 12)
		var tw: Tween = nb.create_tween().set_loops()
		tw.tween_property(nb, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(nb, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	var grid := GridContainer.new()
	grid.columns = 2 if compact else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for s: Array in [["statWave", data.get("wave", 0)], ["statKills", data.get("kills", 0)], ["statGold", data.get("gold", 0)], ["statTowers", data.get("towers", 0)]]:
		var p := PanelContainer.new()
		p.theme_type_variation = "Chip"
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		var big: Label = _label(str(s[1]), 26, true)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		var small: Label = _label(Loc.t(String(s[0])), 12, false, Color(INK, 0.7))
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(small)
		p.add_child(v)
		grid.add_child(p)
	_card_body.add_child(grid)
	var r: HFlowContainer = _row()
	var again: Button = _button(Loc.t("again"), &"restart", null, true)
	again.custom_minimum_size = Vector2(160, 46)
	_focus_first = again
	r.add_child(again)
	if won:
		var eb: Button = _button(Loc.t("endless"), &"endless")
		eb.custom_minimum_size = Vector2(0, 46)
		r.add_child(eb)
	var mm: Button = _button(Loc.t("mainMenu"), &"main_menu")
	mm.custom_minimum_size = Vector2(0, 46)
	r.add_child(mm)
	_card_body.add_child(r)


# ---------------------------------------------------------------- texts
func set_speed(s: int) -> void:
	speed = s
	_speed_btn.text = "%dx" % s


func set_paused(on: bool) -> void:
	(_pause_btn.get_meta("icon") as Icon).kind = "play" if on else "pause"


func _refresh_sound_btn() -> void:
	(_sound_btn.get_meta("icon") as Icon).kind = "mute" if Settings.master_volume <= 0.001 else "sound"


func _retext() -> void:
	_logo_sub.text = Loc.t("sub")
	_lang_btn.text = "EN" if Settings.language == "tr" else "TR"
	_boss_lbl.text = Loc.t("bossLabel")
	_gold_chip.tooltip_text = Loc.t("gold")
	_lives_chip.tooltip_text = Loc.t("lives")
	_last_wave_text = ""
	_panel_key = ""
	_refresh_sound_btn()
	if sim != null:
		_refresh_panel()
		_refresh_wave_box()
	_dirty = true
