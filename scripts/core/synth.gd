class_name Synth
extends RefCounted
## Tiny offline synthesiser: every sound and the music are rendered into AudioStreamWAV
## buffers at start-up, so the game ships no audio files.

const RATE: int = 22050


static func buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


static func _wave(kind: StringName, phase: float) -> float:
	var p: float = phase - floorf(phase)
	match kind:
		&"square":
			return 1.0 if p < 0.5 else -1.0
		&"saw":
			return 2.0 * p - 1.0
		&"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		_:
			return sin(p * TAU)


## Oscillator with an exponential pitch sweep and an exponential fade (like Web Audio ramps).
static func tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, kind: StringName, vol: float) -> void:
	var i0: int = int(start * RATE)
	var n: int = int(dur * RATE)
	var phase: float = 0.0
	var ratio: float = f1 / f0 if f1 > 0.0 else 1.0
	var attack: float = 0.01
	var fall: float = log(0.0001 / maxf(vol, 0.0002))
	for i: int in range(n):
		var idx: int = i0 + i
		if idx >= b.size():
			break
		var t: float = float(i) / RATE
		var f: float = f0 * pow(ratio, t / dur)
		phase += f / RATE
		var env: float
		if t < attack:
			env = vol * t / attack
		else:
			env = vol * exp(fall * (t - attack) / maxf(0.001, dur - attack))
		b[idx] += _wave(kind, phase) * env


## Filtered white noise (RBJ biquad), fading out exponentially.
static func noise(b: PackedFloat32Array, start: float, dur: float, vol: float, freq: float, mode: StringName, q: float, rng: RandomNumberGenerator) -> void:
	var w0: float = TAU * freq / RATE
	var alpha: float = sin(w0) / (2.0 * q)
	var cw: float = cos(w0)
	var b0: float
	var b1: float
	var b2: float
	if mode == &"bandpass":
		b0 = alpha
		b1 = 0.0
		b2 = -alpha
	else:
		b0 = (1.0 - cw) / 2.0
		b1 = 1.0 - cw
		b2 = (1.0 - cw) / 2.0
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	b0 /= a0
	b1 /= a0
	b2 /= a0
	a1 /= a0
	a2 /= a0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var i0: int = int(start * RATE)
	var n: int = int(dur * RATE)
	var fall: float = log(0.0001 / maxf(vol, 0.0002))
	for i: int in range(n):
		var idx: int = i0 + i
		if idx >= b.size():
			break
		var x: float = rng.randf() * 2.0 - 1.0
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var t: float = float(i) / RATE
		b[idx] += y * vol * exp(fall * t / dur)


## Karplus-Strong plucked string (a saz-like voice).
static func pluck(b: PackedFloat32Array, start: float, dur: float, freq: float, vol: float, rng: RandomNumberGenerator, damping: float = 0.996) -> void:
	var period: int = maxi(2, int(float(RATE) / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i: int in range(period):
		ring[i] = rng.randf() * 2.0 - 1.0
	var i0: int = int(start * RATE)
	var n: int = int(dur * RATE)
	var pos: int = 0
	var tail: int = int(0.04 * RATE)
	for i: int in range(n):
		var idx: int = i0 + i
		if idx >= b.size():
			break
		var nxt: int = (pos + 1) % period
		var out: float = ring[pos]
		ring[pos] = damping * 0.5 * (ring[pos] + ring[nxt])
		pos = nxt
		var fade: float = 1.0 if i < n - tail else float(n - i) / float(tail)
		b[idx] += out * vol * fade


static func normalize(b: PackedFloat32Array, peak: float) -> void:
	var m: float = 0.0001
	for v: float in b:
		m = maxf(m, absf(v))
	var k: float = peak / m
	for i: int in range(b.size()):
		b[i] *= k


static func to_wav(b: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i: int in range(b.size()):
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w
