extends Node
## Sound effects synthesised in code at startup (no audio files, no licences).
## Sfx.play("gulp", pitch) from anywhere.

const RATE := 22050
const VOICES := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["gulp"] = _sweep(0.14, 520.0, 160.0, 0.0, 0.55)
	_streams["gulp_big"] = _sweep(0.42, 230.0, 55.0, 0.35, 0.8)
	_streams["powerup"] = _sweep(0.3, 300.0, 1400.0, 0.0, 0.45, 18.0)
	_streams["eat_hole"] = _sweep(0.65, 420.0, 70.0, 0.5, 0.8)
	_streams["level"] = _notes([523.0, 659.0, 784.0, 1047.0], 0.075, 0.22, 0.4)
	_streams["eaten"] = _notes([392.0, 330.0, 262.0], 0.14, 0.3, 0.45)
	_streams["end"] = _notes([523.0, 659.0, 784.0, 1047.0], 0.11, 0.5, 0.45)
	_streams["tick"] = _sweep(0.035, 1500.0, 1400.0, 0.0, 0.3)
	_streams["ui"] = _sweep(0.06, 700.0, 1100.0, 0.0, 0.35)
	_streams["crumble"] = _crumble(1.0, 0.8)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null


## `min_gap_ms` drops the sound if the same one played less than that ago.
func play(sound: String, pitch := 1.0, volume_db := 0.0, min_gap_ms := 0) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if min_gap_ms > 0 and now - int(_last.get(sound, -100000)) < min_gap_ms:
		return
	_last[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Exponential pitch sweep with a soft attack and an exponential decay.
## `noise` mixes in a low rumble, `vibrato` is in Hz.
func _sweep(dur: float, f0: float, f1: float, noise: float, gain: float, vibrato := 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		if vibrato > 0.0:
			f *= 1.0 + 0.03 * sin(TAU * vibrato * i / RATE)
		phase += TAU * f / RATE
		var s := sin(phase) + 0.25 * sin(phase * 2.0)
		if noise > 0.0:
			lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)
			s = lerpf(s, lp * 3.0, noise)
		var env := minf(1.0, t * dur / 0.006) * pow(1.0 - t, 1.6)
		out[i] = s * env * gain
	return _to_wav(out)


## Collapse: low filtered rumble with random cracks of rubble on top.
func _crumble(dur: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var crack := 0.0
	for i in n:
		var t := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.04)
		lp2 = lerpf(lp2, lp, 0.2)
		if randf() < 0.0025 * (1.0 - t):
			crack = randf_range(0.4, 1.0)
		crack *= 0.993
		var s := lp2 * 5.0 + randf_range(-1.0, 1.0) * crack * 0.6
		var env := minf(1.0, t * dur / 0.02) * pow(1.0 - t, 1.4)
		out[i] = clampf(s, -1.0, 1.0) * env * gain
	return _to_wav(out)


## Short note sequence (triangle-ish), the last note rings for `tail` seconds.
func _notes(freqs: Array, step: float, tail: float, gain: float) -> AudioStreamWAV:
	var total := step * (freqs.size() - 1) + tail
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var start := int(k * step * RATE)
		var length := int((tail if k == freqs.size() - 1 else step * 1.6) * RATE)
		var f: float = freqs[k]
		for i in length:
			if start + i >= n:
				break
			var t := float(i) / length
			var ph := TAU * f * i / RATE
			var s := sin(ph) + 0.3 * sin(ph * 3.0) / 3.0
			var env := minf(1.0, i / (0.004 * RATE)) * pow(1.0 - t, 1.3)
			out[start + i] += s * env * gain
	return _to_wav(out)
