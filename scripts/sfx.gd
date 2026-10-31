# Effets sonores synthétisés au lancement : aucun fichier audio à importer.
extends Node

const RATE := 22050

var streams := {}
var players: Array = []


func _ready() -> void:
	streams["jump"] = _make(0.09, func(t, p): return _square(lerpf(330.0, 660.0, p), t) * (1.0 - p) * 0.35)
	streams["land"] = _make(0.06, func(t, p): return _noise() * pow(1.0 - p, 3.0) * 0.3)
	streams["dash"] = _make(0.18, func(t, p): return (_noise() * 0.6 + _sine(lerpf(900.0, 300.0, p), t) * 0.4) * pow(1.0 - p, 1.5) * 0.45)
	streams["death"] = _make(0.45, func(t, p): return (_square(lerpf(440.0, 55.0, p), t) * 0.6 + _noise() * 0.4) * (1.0 - p) * 0.4)
	streams["crystal"] = _make(0.35, func(t, p): return (_sine(1318.5, t) + _sine(1975.5, t) * 0.5) * pow(1.0 - p, 2.0) * 0.3)
	streams["candle"] = _make(0.6, func(t, p): return (_sine(523.25, t) + _sine(784.0, t) * 0.4) * pow(1.0 - p, 2.5) * 0.35)
	streams["exit"] = _make(0.9, func(t, p): return (_sine(392.0 * (1.0 + floorf(p * 3.0) * 0.25), t)) * (1.0 - p) * 0.35)
	for i in 6:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		players.append(pl)


func play(name: String, pitch_jitter := 0.05) -> void:
	if not streams.has(name):
		return
	for pl in players:
		if not pl.playing:
			pl.stream = streams[name]
			pl.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			pl.play()
			return


func _make(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(gen.call(t, float(i) / n), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _sine(freq: float, t: float) -> float:
	return sin(TAU * freq * t)


func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(freq * t, 1.0) < 0.5 else -1.0


func _noise() -> float:
	return randf_range(-1.0, 1.0)
