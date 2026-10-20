extends Node
## Audio: Music and SFX buses, synthesised sound effects and a two-stem 9/8 (aksak)
## music loop in the Hicaz mode. The drum stem fades in while a wave is running.

const GAPS: Dictionary = {"bow": 0.06, "hit": 0.05, "coin": 0.07, "boom": 0.08, "impact": 0.08, "lob": 0.1, "splash": 0.1}
const EIGHTH: float = 0.2

var _streams: Dictionary = {}
var _players: Dictionary = {}
var _last: Dictionary = {}
var _music_calm: AudioStreamPlayer
var _music_drums: AudioStreamPlayer
var _drums_on: bool = false
var _drum_tween: Tween
var _rng := RandomNumberGenerator.new()
var music_ready: bool = false
## False while the battle is fast-forwarded, so skipped seconds make no noise.
var enabled: bool = true
## No audio device in headless runs (tests, bot) and Movie Maker captures (it only mixes
## once per recorded frame, so playbacks would outlive the exit): skip playback entirely.
var _headless: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless" or Engine.get_write_movie_path() != ""
	_rng.seed = 7
	_make_buses()
	apply_volumes()
	Settings.changed.connect(func(_k: StringName) -> void: apply_volumes())
	_build_sfx()
	_music_calm = _new_player(&"Music")
	_music_drums = _new_player(&"Music")
	_music_drums.volume_db = -60.0
	# render the music after the first frames so the title appears at once
	_build_music_deferred.call_deferred()


## Stop every player and drop the generated streams so nothing is left at exit.
func _exit_tree() -> void:
	for p: Node in get_children():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()
			(p as AudioStreamPlayer).stream = null
	_streams.clear()
	_players.clear()
	# give the audio thread a moment to drop the stopped playbacks before shutdown
	OS.delay_msec(60)


func _make_buses() -> void:
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")


func apply_volumes() -> void:
	_set_bus("Master", Settings.master_volume)
	_set_bus("Music", Settings.music_volume * 0.8)
	_set_bus("SFX", Settings.sfx_volume)


func _set_bus(bus: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func _new_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## Play a named effect, rate-limited so dense battles do not turn into noise.
func play(sfx_name: String, pitch_jitter: float = 0.06) -> void:
	if not enabled or _headless or not _streams.has(sfx_name):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var gap: float = float(GAPS.get(sfx_name, 0.03))
	if _last.has(sfx_name) and now - float(_last[sfx_name]) < gap:
		return
	_last[sfx_name] = now
	var p: AudioStreamPlayer = _players[sfx_name]
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func set_battle_music(on: bool) -> void:
	if on == _drums_on:
		return
	_drums_on = on
	if _drum_tween != null and _drum_tween.is_valid():
		_drum_tween.kill()
	_drum_tween = create_tween()
	_drum_tween.tween_property(_music_drums, "volume_db", -3.0 if on else -60.0, 1.5 if on else 3.0)


# ---------------------------------------------------------------- sound effects
func _build_sfx() -> void:
	var r := _rng
	var defs: Dictionary = {}
	var b: PackedFloat32Array
	b = Synth.buffer(0.15); Synth.noise(b, 0, 0.08, 0.12, 2800, &"bandpass", 2, r); Synth.tone(b, 0, 0.07, 420, 180, &"triangle", 0.05); defs["bow"] = b
	b = Synth.buffer(0.1); Synth.noise(b, 0, 0.05, 0.08, 1200, &"bandpass", 3, r); defs["hit"] = b
	b = Synth.buffer(0.5); Synth.noise(b, 0, 0.4, 0.5, 420, &"lowpass", 1, r); Synth.tone(b, 0, 0.35, 110, 40, &"sine", 0.4); defs["boom"] = b
	b = Synth.buffer(0.4); Synth.noise(b, 0, 0.3, 0.3, 700, &"lowpass", 1, r); Synth.tone(b, 0, 0.25, 80, 35, &"sine", 0.25); defs["impact"] = b
	b = Synth.buffer(0.2); Synth.tone(b, 0, 0.16, 260, 140, &"triangle", 0.08); defs["lob"] = b
	b = Synth.buffer(0.3); Synth.noise(b, 0, 0.22, 0.18, 500, &"lowpass", 4, r); defs["splash"] = b
	b = Synth.buffer(0.2); Synth.tone(b, 0, 0.06, 1320, 0, &"square", 0.04); Synth.tone(b, 0.05, 0.09, 1760, 0, &"square", 0.04); defs["coin"] = b
	b = Synth.buffer(0.3); Synth.noise(b, 0, 0.15, 0.2, 300, &"lowpass", 1, r); Synth.tone(b, 0.02, 0.12, 196, 0, &"triangle", 0.15); Synth.tone(b, 0.1, 0.15, 294, 0, &"triangle", 0.12); defs["build"] = b
	b = Synth.buffer(0.45); Synth.noise(b, 0, 0.12, 0.15, 400, &"lowpass", 1, r)
	for i: int in range(3):
		Synth.tone(b, 0.05 + i * 0.08, 0.2, [392.0, 523.0, 659.0][i], 0, &"triangle", 0.12)
	defs["upgrade"] = b
	b = Synth.buffer(0.08); Synth.tone(b, 0, 0.04, 660, 0, &"triangle", 0.06); defs["click"] = b
	b = Synth.buffer(0.2); Synth.tone(b, 0, 0.15, 180, 140, &"square", 0.06); defs["deny"] = b
	b = Synth.buffer(0.45); Synth.noise(b, 0, 0.35, 0.35, 260, &"lowpass", 1, r); Synth.tone(b, 0, 0.3, 150, 70, &"saw", 0.12); defs["hurt"] = b
	b = Synth.buffer(1.0)
	for i: int in range(3):
		var f: float = [146.8, 220.0, 293.7][i]
		Synth.tone(b, i * 0.03, 0.9, f, f * 0.98, &"saw", 0.06)
	defs["horn"] = b
	b = Synth.buffer(0.6)
	for i: int in range(3):
		Synth.tone(b, i * 0.1, 0.25, [523.0, 659.0, 784.0][i], 0, &"triangle", 0.1)
	defs["clear"] = b
	b = Synth.buffer(1.2)
	for i: int in range(4):
		Synth.tone(b, i * 0.16, 0.5, [523.0, 659.0, 784.0, 1046.0][i], 0, &"triangle", 0.12)
	defs["win"] = b
	b = Synth.buffer(1.3)
	for i: int in range(4):
		Synth.tone(b, i * 0.22, 0.5, [392.0, 330.0, 262.0, 196.0][i], 0, &"saw", 0.07)
	defs["lose"] = b
	b = Synth.buffer(1.6)
	Synth.tone(b, 0, 1.5, 98, 92, &"saw", 0.08); Synth.tone(b, 0, 1.5, 147, 140, &"saw", 0.06); Synth.tone(b, 0.25, 1.2, 196, 190, &"saw", 0.05)
	defs["boss"] = b
	for k: String in defs:
		var buf: PackedFloat32Array = defs[k]
		for i: int in range(buf.size()):
			buf[i] *= 2.4  # Web Audio master gain was 0.32 of a louder graph
		_streams[k] = Synth.to_wav(buf)
		var p: AudioStreamPlayer = _new_player(&"SFX")
		p.stream = _streams[k]
		p.max_polyphony = 4
		_players[k] = p


# ---------------------------------------------------------------- music
const D4: float = 293.66
# [start eighth, length in eighths, semitones from D4]; 8 bars of 9/8 (2+2+2+3)
const MELODY: Array = [
	[0, 2, 7], [2, 2, 8], [4, 2, 7], [6, 3, 5],
	[9, 2, 4], [11, 2, 5], [13, 1, 4], [14, 1, 1], [15, 3, 0],
	[18, 2, 0], [20, 2, 1], [22, 2, 4], [24, 3, 5],
	[27, 2, 7], [29, 2, 5], [31, 2, 4], [33, 3, 7],
	[36, 2, 12], [38, 2, 10], [40, 2, 8], [42, 3, 7],
	[45, 2, 8], [47, 2, 7], [49, 2, 5], [51, 3, 4],
	[54, 2, 5], [56, 2, 4], [58, 2, 1], [60, 3, 4],
	[63, 2, 1], [65, 2, 0], [67, 5, 0],
]
const BASS: Array = [0, 0, -5, 0, 5, 1, -2, 0]


func _build_music_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var t0: int = Time.get_ticks_msec()
	var r := RandomNumberGenerator.new()
	r.seed = 1453
	var bars: int = 8
	var length: float = bars * 9 * EIGHTH
	var calm: PackedFloat32Array = Synth.buffer(length)
	# drone: D3 + A3 from a harmonic wavetable, slow swell
	var table := PackedFloat32Array()
	table.resize(1024)
	for i: int in range(1024):
		var ph: float = float(i) / 1024.0 * TAU
		table[i] = sin(ph) + 0.45 * sin(2.0 * ph) + 0.22 * sin(3.0 * ph) + 0.1 * sin(4.0 * ph)
	var p1: float = 0.0
	var p2: float = 0.0
	for i: int in range(calm.size()):
		var t: float = float(i) / Synth.RATE
		var swell: float = 0.75 + 0.25 * sin(t * TAU / (length / 2.0))
		p1 += 146.83 * (1.0 + 0.002 * sin(t * 5.0)) / Synth.RATE
		p2 += 220.0 / Synth.RATE
		calm[i] = (table[int((p1 - floorf(p1)) * 1023.0)] * 0.05 + table[int((p2 - floorf(p2)) * 1023.0)] * 0.025) * swell
	for n: Array in MELODY:
		var f: float = D4 * pow(2.0, float(n[2]) / 12.0)
		Synth.pluck(calm, float(n[0]) * EIGHTH, float(n[1]) * EIGHTH + 0.35, f, 0.32, r, 0.9965)
		Synth.pluck(calm, float(n[0]) * EIGHTH + 0.012, float(n[1]) * EIGHTH + 0.2, f * 2.0, 0.07, r, 0.993)
	for bar: int in range(bars):
		var f: float = D4 * 0.25 * pow(2.0, float(BASS[bar]) / 12.0)
		Synth.pluck(calm, bar * 9 * EIGHTH, 9 * EIGHTH, f, 0.4, r, 0.998)
		Synth.pluck(calm, (bar * 9 + 6) * EIGHTH, 3 * EIGHTH, f * 1.5, 0.18, r, 0.997)
	Synth.normalize(calm, 0.7)
	var drums: PackedFloat32Array = Synth.buffer(length)
	for bar: int in range(bars):
		var o: float = bar * 9 * EIGHTH
		for e: int in [0, 4]:  # DÜM
			Synth.tone(drums, o + e * EIGHTH, 0.32, 95, 48, &"sine", 0.7)
			Synth.noise(drums, o + e * EIGHTH, 0.08, 0.25, 180, &"lowpass", 1, r)
		for e: int in [2, 6, 7, 8]:  # tek
			Synth.noise(drums, o + e * EIGHTH, 0.06, 0.32 if e != 8 else 0.18, 3200, &"bandpass", 2.5, r)
			Synth.tone(drums, o + e * EIGHTH, 0.05, 640, 520, &"triangle", 0.08)
		if bar % 2 == 1:
			Synth.noise(drums, o + 8 * EIGHTH, 0.5, 0.12, 7000, &"bandpass", 1.2, r)  # zil
	Synth.normalize(drums, 0.65)
	_music_calm.stream = Synth.to_wav(calm, true)
	_music_drums.stream = Synth.to_wav(drums, true)
	if not _headless:
		_music_calm.play()
		_music_drums.play()
	music_ready = true
	print_verbose("music rendered in %d ms" % (Time.get_ticks_msec() - t0))
