# Musique adaptative synthétisée au lancement, un thème par chapitre (partitions dans
# music_themes.gd). Chaque thème est une boucle découpée en huit couches jouées en parfaite
# synchronisation. Plus on avance, plus de couches entrent et plus la musique se tend :
# dans le jeu entier, et aussi d'un niveau à l'autre à l'intérieur d'un chapitre.
# Certains thèmes se calent sur une horloge du niveau (blocs rythmés, yeux de Regards) :
# la musique frappe exactement quand les blocs basculent ou quand le regard s'ouvre.
# À la mort, la musique ralentit comme un disque qu'on freine, puis repart à la réapparition.
# Le calcul se fait dans un thread : le thème du chapitre courant d'abord, puis le suivant
# en avance, pour que le changement de chapitre soit immédiat.
extends AudioStreamPlayer

const Themes = preload("res://scripts/music_themes.gd")
const TimedBlocks = preload("res://scripts/timed_blocks.gd")
const Watchers = preload("res://scripts/watchers.gd")

const RATE := 22050
const CACHE_SIZE := 3

# Couches, dans l'ordre où elles entrent : [nom, seuil d'intensité, volume en dB]
const LAYERS := [
	["nappe", 0.0, 0.0],
	["mélodie", 0.0, 0.0],
	["pouls", 0.1, -2.0],
	["arpège", 0.24, -4.0],
	["basse", 0.36, -1.0],
	["tambour", 0.5, -1.0],
	["charleston", 0.64, -5.0],
	["tension", 0.8, -6.0],
]
const SILENT := -60.0

var thread := Thread.new()
var cache := {}           # chapitre -> {"theme", "loop", "streams"}
var cache_order: Array = []
var wanted := "Le Seuil"  # chapitre demandé par le niveau
var current := ""         # chapitre dont le thème joue
var theme: Dictionary
var loop_len := 16.0
var sync: AudioStreamSynchronized
var swapping := false
var intensity := 0.0
var levels: Array = []    # volume courant de chaque couche, en dB
var speed := 1.0          # vitesse du disque (pitch_scale avant correction de calage)
var target_speed := 1.0
var scratch_player: AudioStreamPlayer
var speed_tween: Tween
var dying := false
# Horloges du niveau courant, et celle que suit le thème joué
var timed_clock: Node
var eyes_clock: Node
var clock: Node
var clock_period := 0.0
var clock_shift := 0.0


func _ready() -> void:
	bus = "Music"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in LAYERS.size():
		levels.append(SILENT)
	scratch_player = AudioStreamPlayer.new()
	scratch_player.bus = "Music"
	scratch_player.volume_db = -8.0
	add_child(scratch_player)


func _process(delta: float) -> void:
	if thread.is_started() and not thread.is_alive():
		_store(thread.wait_to_finish())
	if current != wanted and cache.has(wanted) and not swapping:
		_swap()
	if not thread.is_started():
		var next := _next_job()
		if next != "":
			thread.start(_generate.bind(next, Themes.get_theme(next)))
	if not sync:
		return
	# Les couches entrent et sortent en fondu, sur environ deux secondes
	for i in sync.stream_count:
		var goal := _layer_target(i)
		if levels[i] != goal:
			levels[i] = move_toward(levels[i], goal, 30.0 * delta)
			sync.set_sync_stream_volume(i, levels[i])
	pitch_scale = maxf(speed * _clock_correction(), 0.01)


func _exit_tree() -> void:
	if thread.is_started():
		thread.wait_to_finish()


func _layer_target(i: int) -> float:
	var threshold: float = theme.get("thresholds", {}).get(i, LAYERS[i][1])
	if intensity < threshold:
		return SILENT
	# Une couche qui vient d'entrer reste discrète, puis prend sa place
	var k := clampf((intensity - threshold) / 0.12, 0.35, 1.0)
	return LAYERS[i][2] + linear_to_db(k)


# Choisit le thème du chapitre ; il entre au prochain changement prêt
func set_chapter(chapter: String) -> void:
	if chapter in Themes.ORDER:
		wanted = chapter


# Règle l'énergie : 0 au tout début du jeu, 1 tout à la fin (ou en face B)
func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	_update_speed()


# Horloges du niveau qui vient de se charger (null s'il n'y en a pas)
func set_clocks(timed: Node, eyes: Node) -> void:
	timed_clock = timed
	eyes_clock = eyes
	_pick_clock()
	_update_speed()


# Mort : le disque freine et descend dans les graves
func scratch() -> void:
	dying = true
	if scratch_player.stream:
		scratch_player.play()
	_tween_speed(0.25, 0.4).set_ease(Tween.EASE_IN)


# Réapparition : le disque repart d'un coup
func resume() -> void:
	dying = false
	_tween_speed(target_speed, 0.25).set_ease(Tween.EASE_OUT)


func _update_speed() -> void:
	# Un peu plus vite et plus haut vers la fin, sauf quand la musique suit une horloge
	var rise: float = Themes.get_theme(wanted)["rise"]
	target_speed = 1.0 if clock else 1.0 + rise * intensity
	if not dying:
		_tween_speed(target_speed, 1.5)


func _tween_speed(to: float, time: float) -> Tween:
	if speed_tween:
		speed_tween.kill()
	speed_tween = create_tween()
	speed_tween.tween_property(self, "speed", to, time).set_trans(Tween.TRANS_QUAD)
	return speed_tween


# --- Changement de thème -----------------------------------------------------

func _next_job() -> String:
	if not cache.has(wanted):
		return wanted
	var i: int = Themes.ORDER.find(wanted)
	if i >= 0 and i + 1 < Themes.ORDER.size() and not cache.has(Themes.ORDER[i + 1]):
		return Themes.ORDER[i + 1]
	return ""


func _store(res: Dictionary) -> void:
	if not scratch_player.stream:
		scratch_player.stream = res["scratch"]
	cache[res["chapter"]] = res
	cache_order.erase(res["chapter"])
	cache_order.append(res["chapter"])
	# On garde le thème joué, le thème voulu et le plus récent
	var k := 0
	while cache.size() > CACHE_SIZE and k < cache_order.size():
		var c: String = cache_order[k]
		if c != current and c != wanted and c != res["chapter"]:
			cache.erase(c)
			cache_order.remove_at(k)
		else:
			k += 1


func _swap() -> void:
	if not sync:
		_start_theme(wanted)
		return
	# Fondu au noir, nouveau thème, retour du volume
	swapping = true
	var tw := create_tween()
	tw.tween_property(self, "volume_db", -30.0, 0.5)
	tw.tween_callback(func(): _start_theme(wanted))
	tw.tween_property(self, "volume_db", 0.0, 0.8)
	tw.tween_callback(func(): swapping = false)


func _start_theme(chapter: String) -> void:
	var res: Dictionary = cache[chapter]
	current = chapter
	theme = res["theme"]
	loop_len = res["loop"]
	var streams: Array = res["streams"]
	sync = AudioStreamSynchronized.new()
	sync.stream_count = streams.size()
	for i in sync.stream_count:
		sync.set_sync_stream(i, streams[i])
		levels[i] = _layer_target(i)
		sync.set_sync_stream_volume(i, levels[i])
	stream = sync
	_pick_clock()
	_update_speed()
	pitch_scale = speed
	play(_clock_target() if clock else 0.0)


# --- Calage sur une horloge du niveau ------------------------------------------

func _pick_clock() -> void:
	clock = null
	var mode: String = theme.get("sync", "")
	if mode == "timed" and is_instance_valid(timed_clock):
		clock = timed_clock
		clock_period = TimedBlocks.PERIOD
		clock_shift = 0.0
	elif mode == "eyes" and is_instance_valid(eyes_clock):
		clock = eyes_clock
		clock_period = Watchers.PERIOD
		# On suit le premier œil « Y » (début de cycle) s'il y en a un, sinon un « y »
		clock_shift = 0.5 * Watchers.PERIOD
		for e in eyes_clock.eyes:
			if e[1] == 0.0:
				clock_shift = 0.0


# Position de la boucle qui tombe juste sur l'horloge, en tenant compte de la latence
func _clock_target() -> float:
	return fposmod(clock.t + clock_shift + AudioServer.get_output_latency(), clock_period)


# Petit écart : on accélère ou ralentit d'un poil. Gros écart (pause, mort) : on saute.
func _clock_correction() -> float:
	if not clock or not is_instance_valid(clock) or dying or swapping or not playing_now():
		return 1.0
	if get_tree().paused or clock_period <= 0.0:
		return 1.0
	var pos := get_playback_position() + AudioServer.get_time_since_last_mix() * pitch_scale
	var err := wrapf(fposmod(pos, clock_period) - _clock_target(), -clock_period * 0.5, clock_period * 0.5)
	if absf(err) > 0.1:
		seek(fposmod(pos - err, loop_len))
		return 1.0
	return clampf(1.0 - err, 0.97, 1.03)


func playing_now() -> bool:
	return current != "" and is_playing()


# --- Synthèse ----------------------------------------------------------------

func _generate(chapter: String, th: Dictionary) -> Dictionary:
	var beat: float = th["beat"]
	var bar_len: float = beat * th["bar"]
	var loop: float = bar_len * th["bars"]
	var n := int(round(loop * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var streams: Array = []
	for layer in LAYERS:
		var buf := PackedFloat32Array()
		buf.resize(n)
		match layer[0]:
			"nappe": _drone(buf, th, loop)
			"mélodie": _melody(buf, th)
			"pouls": _pulse(buf, th, loop)
			"arpège": _arp(buf, th, loop)
			"basse": _bass(buf, th, loop)
			"tambour": _drums(buf, th, loop, rng)
			"charleston": _hats(buf, th, loop, rng)
			"tension": _tension(buf, th, loop)
		streams.append(_to_wav(buf, true))
	return {"chapter": chapter, "theme": th, "loop": loop, "streams": streams,
		"scratch": _to_wav(_scratch_sound(rng), false)}


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# Fréquence arrondie pour tomber juste sur la boucle (nombre entier de périodes)
static func _fit(f: float, loop: float) -> float:
	return maxf(1.0, round(f * loop)) / loop


func _drone(buf: PackedFloat32Array, th: Dictionary, loop: float) -> void:
	var freqs: Array = []
	for m in th["drone"]:
		freqs.append(_fit(_hz(m), loop))
	var gaze: bool = th["pulse"] == "gaze"
	var bar_len: float = th["beat"] * th["bar"]
	for i in buf.size():
		var t := float(i) / RATE
		# Le bourdon gonfle et retombe deux fois par boucle
		var breath := 0.6 + 0.4 * sin(TAU * t / (loop * 0.5))
		if gaze:
			# Regards : il enfle pendant l'éveil de la paupière et tient tout le regard
			breath = 0.45 + 0.8 * _gaze_env(fmod(t, bar_len))
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t + k) * (0.5 / (k + 1))
		buf[i] = v * breath * 0.22
	if gaze:
		# Un éclat de verre dissonant à l'instant exact où le regard s'ouvre
		var root := _hz(th["tension"][0])
		for b in int(th["bars"]):
			_note(buf, b * bar_len + Watchers.CLOSED + Watchers.WAKING, 1.4, func(t: float) -> float:
				var env := exp(-t * 3.0) * minf(t * 300.0, 1.0)
				return (sin(TAU * root * t) + sin(TAU * root * 1.0595 * t) + 0.5 * sin(TAU * root * 1.5 * t)) * env * 0.08)


# 0 paupière close, monte pendant l'éveil, 1 pendant tout le regard
static func _gaze_env(u: float) -> float:
	var wake := Watchers.CLOSED
	var open := Watchers.CLOSED + Watchers.WAKING
	if u < wake:
		return 0.0
	if u < open:
		return smoothstep(wake, open, u)
	return 1.0 - smoothstep(Watchers.PERIOD - 0.08, Watchers.PERIOD, u)


func _melody(buf: PackedFloat32Array, th: Dictionary) -> void:
	var beat: float = th["beat"]
	var gain: float = th["melody_gain"]
	var canon: float = th["canon"]
	for m in th["melody"]:
		var g: float = gain * (m[2] if m.size() > 2 else 1.0)
		_voice(buf, th, m[0] * beat, _hz(m[1]), g)
		if canon > 0.0:
			# La seconde voix suit, une octave plus bas
			_voice(buf, th, (m[0] + canon) * beat, _hz(m[1] - 12), g * 0.55)


func _voice(buf: PackedFloat32Array, th: Dictionary, start: float, f: float, g: float) -> void:
	match th["voice"]:
		"verre":
			_note(buf, start, 3.0, func(t: float) -> float:
				var env := exp(-t * 2.2) * minf(t * 400.0, 1.0)
				return (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.76 * t) * exp(-t * 4.0) + 0.1 * sin(TAU * f * 5.4 * t) * exp(-t * 8.0)) * env * 0.11 * g)
		"orgue":
			var hold: float = th["beat"] * 1.5
			_note(buf, start, hold + 0.6, func(t: float) -> float:
				var env := minf(t * 20.0, 1.0) * (1.0 if t < hold else exp(-(t - hold) * 7.0))
				return (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.25 * sin(TAU * f * 3.0 * t) + 0.3 * sin(TAU * f * 4.0 * t)) * env * 0.06 * g)
		"pincé":
			_note(buf, start, 1.2, func(t: float) -> float:
				var env := exp(-t * 5.0) * minf(t * 500.0, 1.0)
				return (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0) + 0.2 * sin(TAU * f * 3.0 * t) * exp(-t * 10.0)) * env * 0.15 * g)
		"goutte":
			# La hauteur remonte d'un coup, comme une goutte qui touche l'eau
			_note(buf, start, 1.0, func(t: float) -> float:
				var ph := TAU * f * (t + 0.3 * (t - (1.0 - exp(-30.0 * t)) / 30.0))
				return sin(ph) * exp(-t * 6.0) * minf(t * 500.0, 1.0) * 0.14 * g)
		"carillon":
			# Partiels d'une vraie cloche : bourdon, fondamentale, tierce mineure, quinte, nominale
			_note(buf, start, 2.8, func(t: float) -> float:
				var v := 0.5 * sin(TAU * f * 0.5 * t) * exp(-t * 0.8) + sin(TAU * f * t) * exp(-t * 1.4) \
					+ 0.45 * sin(TAU * f * 1.2 * t) * exp(-t * 1.8) + 0.25 * sin(TAU * f * 1.5 * t) * exp(-t * 2.5) \
					+ 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 3.0)
				return v * minf(t * 300.0, 1.0) * 0.1 * g)
		_:
			_note(buf, start, 3.5, func(t: float) -> float:
				var env := exp(-t * 1.6) * minf(t * 200.0, 1.0)
				return (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) + 0.15 * sin(TAU * f * 3.01 * t)) * env * 0.12 * g)


# Battement sourd sur chaque temps, comme un cœur : la fondamentale de l'accord.
# « clock » : un tic par temps, un toc sur chaque bascule des blocs, un cliquetis pendant
# leur clignotement. « gaze » : le cœur s'emballe tant que le regard est ouvert.
func _pulse(buf: PackedFloat32Array, th: Dictionary, loop: float) -> void:
	var beat: float = th["beat"]
	var style: String = th["pulse"]
	var beats := int(round(loop / beat))
	if style != "clock":
		for k in beats:
			var start := k * beat
			var f: float = _hz(_chord(th, k)[0]) * 2.0
			_note(buf, start, 0.4, func(t: float) -> float:
				return sin(TAU * f * t) * exp(-t * 9.0) * minf(t * 400.0, 1.0) * 0.22)
	if style == "gaze":
		var bar_len: float = beat * th["bar"]
		for b in int(th["bars"]):
			var u := Watchers.CLOSED + Watchers.WAKING + 0.27
			while u < Watchers.PERIOD - 0.1:
				var f: float = _hz(_chord(th, b * th["bar"])[0]) * 2.0
				_note(buf, b * bar_len + u, 0.3, func(t: float) -> float:
					return sin(TAU * f * t) * exp(-t * 12.0) * minf(t * 400.0, 1.0) * 0.16)
				u += beat * 0.5
	if style == "clock" or style == "clock_soft":
		var g := 1.0 if style == "clock" else 0.5
		var half := TimedBlocks.PERIOD * 0.5
		if style == "clock":
			for k in beats:
				_note(buf, k * beat, 0.05, func(t: float) -> float:
					return sin(TAU * 2600.0 * t) * exp(-t * 90.0) * 0.12)
		var switches := int(round(loop / half))
		for s in switches:
			var at := s * half
			# Toc boisé sur la bascule : le bloc « 1 » apparaît sur les toc graves
			var f := 620.0 if s % 2 == 0 else 820.0
			_note(buf, at, 0.12, func(t: float) -> float:
				return (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.3 * t)) * exp(-t * 40.0) * 0.2 * g)
			# Cliquetis qui monte pendant que les blocs clignotent
			for r in 4:
				var rf := 1800.0 + r * 300.0
				_note(buf, at + half - TimedBlocks.WARN + r * 0.1, 0.04, func(t: float) -> float:
					return sin(TAU * rf * t) * exp(-t * 110.0) * (0.05 + r * 0.02) * g)


# Arpège sur les notes de l'accord
func _arp(buf: PackedFloat32Array, th: Dictionary, loop: float) -> void:
	var beat: float = th["beat"]
	var step: float = beat / th["arp_div"]
	var pattern: Array = th["arp"]
	var decay := 2.25 / step
	for k in int(round(loop / step)):
		var notes: Array = _chord(th, k * step / beat)[1]
		var f: float = _hz(notes[pattern[k % pattern.size()]])
		_note(buf, k * step, minf(step * 1.6, 0.5), func(t: float) -> float:
			# Onde triangulaire douce
			var ph := fmod(f * t, 1.0)
			var tri := 4.0 * absf(ph - 0.5) - 1.0
			return tri * exp(-t * decay) * minf(t * 300.0, 1.0) * 0.07)


# Basse un peu grasse (quelques harmoniques), suivant le motif du thème
func _bass(buf: PackedFloat32Array, th: Dictionary, loop: float) -> void:
	var beat: float = th["beat"]
	var step: float = beat / th["bass_div"]
	var pattern: String = th["bass"]
	var length := clampf(step * 0.96, 0.08, 0.6)
	var decay := 1.7 / length
	for k in int(round(loop / step)):
		var c := pattern[k % pattern.length()]
		if c == ".":
			continue
		var f: float = _hz(_chord(th, k * step / beat)[0]) * (2.0 if c == "o" else 1.0)
		var accent := 1.0 if c == "X" else 0.65
		_note(buf, k * step, length, func(t: float) -> float:
			var v := sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.25 * sin(TAU * f * 3.0 * t)
			return v * exp(-t * decay) * minf(t * 300.0, 1.0) * 0.16 * accent)


# Grosse caisse et caisse claire de bruit
func _drums(buf: PackedFloat32Array, th: Dictionary, loop: float, rng: RandomNumberGenerator) -> void:
	var step: float = th["beat"] / th["drum_div"]
	var kick: String = th["kick"]
	var snare: String = th["snare"]
	for k in int(round(loop / step)):
		var kc := kick[k % kick.length()]
		var sc := snare[k % snare.length()]
		if kc != ".":
			var a := 1.0 if kc == "X" else 0.75
			_note(buf, k * step, 0.35, func(t: float) -> float:
				# La fréquence plonge de 140 à 45 Hz
				var ph := TAU * (45.0 * t + 95.0 / 22.0 * (1.0 - exp(-22.0 * t)))
				return sin(ph) * exp(-t * 9.0) * 0.5 * a)
		if sc != ".":
			var noise := _noise(int(0.2 * RATE), rng)
			_note(buf, k * step, 0.2, func(t: float) -> float:
				var j := mini(int(t * RATE), noise.size() - 1)
				return (noise[j] * 0.7 + 0.3 * sin(TAU * 190.0 * t)) * exp(-t * 22.0) * 0.28)


# Charleston : bruit aigu très court, plus appuyé sur les X
func _hats(buf: PackedFloat32Array, th: Dictionary, loop: float, rng: RandomNumberGenerator) -> void:
	var step: float = th["beat"] / th["hat_div"]
	var pattern: String = th["hats"]
	for k in int(round(loop / step)):
		var c := pattern[k % pattern.length()]
		if c == ".":
			continue
		var noise := _noise(int(0.06 * RATE), rng)
		var accent := 1.0 if c == "X" else 0.55
		_note(buf, k * step, 0.06, func(t: float) -> float:
			var j := mini(int(t * RATE), noise.size() - 2)
			# Différence de deux échantillons : ne garde que les aigus
			return (noise[j + 1] - noise[j]) * exp(-t * 70.0) * 0.12 * accent)


# Nappe dissonante qui tremble : seconde mineure au-dessus de la tonique, trémolo rapide
func _tension(buf: PackedFloat32Array, th: Dictionary, loop: float) -> void:
	var freqs: Array = []
	for m in th["tension"]:
		freqs.append(_fit(_hz(m), loop))
	var trem_f := _fit(8.0, loop)
	var gaze: bool = th["pulse"] == "gaze"
	var bar_len: float = th["beat"] * th["bar"]
	for i in buf.size():
		var t := float(i) / RATE
		var trem := 0.55 + 0.45 * sin(TAU * trem_f * t)
		var swell := 0.5 + 0.5 * sin(TAU * t / loop - PI / 2)
		if gaze:
			swell = _gaze_env(fmod(t, bar_len))
		var v := sin(TAU * freqs[0] * t) + sin(TAU * freqs[1] * t) + 0.6 * sin(TAU * freqs[2] * t)
		buf[i] = v * trem * (0.4 + 0.6 * swell) * 0.05


# Bruit de disque qu'on freine : un frottement qui descend
func _scratch_sound(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count := int(0.45 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var ph := 0.0
	var last := 0.0
	for i in count:
		var t := float(i) / RATE
		var k := t / 0.45
		ph += TAU * lerpf(900.0, 120.0, k) / RATE
		# Bruit filtré (passe-bas grossier) modulé par une oscillation qui ralentit
		last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.25)
		buf[i] = (last * 0.8 + 0.3 * sin(ph)) * (1.0 - k) * minf(t * 200.0, 1.0) * 0.5
	return buf


# Ajoute une note qui commence à start (s) ; elle déborde sur le début de la boucle si besoin
func _note(buf: PackedFloat32Array, start: float, length: float, voice: Callable) -> void:
	var n := buf.size()
	var s := int(round(start * RATE))
	for j in int(length * RATE):
		buf[posmod(s + j, n)] += voice.call(float(j) / RATE)


# Accord en cours au temps donné (compté depuis le début de la boucle)
static func _chord(th: Dictionary, at_beat: float) -> Array:
	var per: float = th["bar"] * th["chord_bars"]
	var chords: Array = th["chords"]
	return chords[int(at_beat / per + 0.001) % chords.size()]


func _noise(count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(count)
	for i in count:
		a[i] = rng.randf_range(-1.0, 1.0)
	return a


func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav
