# Dessin du fantôme : tête ronde, bas ondulant, deux yeux noirs,
# et l'accessoire choisi dans les options (Settings.look).
# Animé, il respire (la tête gonfle et se soulève doucement), cligne des yeux
# à intervalles irréguliers, et regarde un peu là où il va (gaze).
# Laissé immobile, il regarde autour de lui, puis se tourne vers le joueur avec des points
# d'interrogation, s'assoupit et finit par s'endormir (des « z » s'envolent).
extends Node2D

const BREATH := 1.9         # pulsation du souffle, en radians par seconde
const BLINK := 0.14         # durée d'un clignement
# Repos (secondes d'immobilité) : il regarde le joueur, s'assoupit, puis dort
const ASK_AT := 15.0
const DROWSY_AT := 30.0
const SLEEP_AT := 45.0
# Endormi, il vacille de plus en plus (en piquant du nez de temps en temps), puis à LIE_AT il
# bascule comme un objet qui tombe : il pivote sur le coin de sa base, accélère, rebondit en
# touchant le sol et reste couché sur le flanc
const LIE_AT := 52.0
const SWAY_MAX := 0.22      # amplitude du vacillement juste avant la chute, en radians
const TOPPLE := 16.0        # « gravité » de la chute, en radians par seconde²
const TOPPLE_BOUNCE := 0.35 # part de la vitesse gardée au rebond

var facing := 1
var tint := Color.WHITE
var animated := true
var t := 0.0
# Direction du regard, de -1 à 1 sur chaque axe ; le joueur y met sa vitesse
var gaze := Vector2.ZERO
# Visée du saut chargé (mode Ascension) : direction du saut, les yeux y vont franchement
var aim := Vector2.ZERO
# Temps passé immobile : au repos, le souffle s'approfondit et le regard flâne
var idle := 0.0
var lie := 0.0  # avancée du coucher, de 0 (debout) à 1 (couché)
var fall := 0.0       # angle de la chute vers l'avant (côté où il regarde), en radians
var fall_v := 0.0
var falling := false  # la chute a commencé (elle part de l'angle du vacillement)
var last_sway := 0.0
var blink_in := 0.0
var blink_t := -1.0
var double_blink := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	blink_in = rng.randf_range(1.0, 3.0)


func _process(delta: float) -> void:
	if animated:
		t += delta
		_update_blink(delta)
		_update_fall(delta)
		queue_redraw()


# Vacillement pendant le sommeil : un balancement lent qui s'amplifie, et de temps en temps il
# pique du nez vers l'avant puis se rattrape
func _sway() -> float:
	if idle < SLEEP_AT or idle >= LIE_AT:
		return 0.0
	var k := clampf((idle - SLEEP_AT) / (LIE_AT - SLEEP_AT), 0.0, 1.0)
	var rock := sin(idle * 2.2) * SWAY_MAX * k
	var nod := pow(maxf(0.0, sin(idle * 0.9)), 8.0) * SWAY_MAX * 1.4 * k
	return rock + nod


func _update_fall(delta: float) -> void:
	if idle >= LIE_AT:
		if not falling:
			# La chute part de l'angle où le vacillement l'a laissé
			falling = true
			fall = last_sway + 0.05
			fall_v = 0.0
		# Comme un objet posé qui bascule : plus il penche, plus il tombe vite (un léger biais
		# vers l'avant pour qu'il tombe toujours de ce côté)
		fall_v += TOPPLE * (sin(fall) + 0.3) * delta
		fall += fall_v * delta
		if fall >= PI * 0.5:
			fall = PI * 0.5
			fall_v = -fall_v * TOPPLE_BOUNCE if fall_v > 1.2 else 0.0
	else:
		last_sway = _sway()
		# Réveillé : il se relève d'un bond
		falling = false
		fall_v = 0.0
		fall = move_toward(fall, 0.0, delta * 10.0)
	lie = clampf(fall / (PI * 0.5), 0.0, 1.0)


# Le corps penché ou couché : il pivote sur le coin de sa base, du côté où il tombe (au milieu
# de sa base pour le simple vacillement)
func _lie_transform() -> Transform2D:
	var angle := fall if (falling or fall > 0.0) else _sway()
	if angle == 0.0:
		return Transform2D.IDENTITY
	var side := float(facing)
	# Il pivote sur le coin du côté vers lequel il penche
	var pivot := Vector2(signf(angle) * side * 6.0 * clampf(absf(angle) / 0.4, 0.0, 1.0), 8.0)
	var turn := Transform2D(side * angle, Vector2.ZERO)
	# Couché, il remonte d'un pixel pour reposer sur le sol sans s'y enfoncer
	return Transform2D(0.0, pivot - Vector2(0, lie)) * turn * Transform2D(0.0, -pivot)


func _update_blink(delta: float) -> void:
	if blink_t >= 0.0:
		blink_t += delta
		if blink_t >= BLINK:
			blink_t = -1.0
			# Une fois sur cinq, un second clignement juste après
			if not double_blink and rng.randf() < 0.2:
				double_blink = true
				blink_in = 0.12
			else:
				double_blink = false
				blink_in = rng.randf_range(2.2, 5.0)
		return
	blink_in -= delta
	if blink_in <= 0.0:
		blink_t = 0.0


# 1 yeux grands ouverts, 0 fermés
func _eye_open() -> float:
	if idle >= SLEEP_AT:
		return 0.0
	if idle >= DROWSY_AT:
		# Les paupières tombent, se relèvent un peu, retombent
		var k := (idle - DROWSY_AT) / (SLEEP_AT - DROWSY_AT)
		return clampf(0.6 - 0.6 * k + sin(idle * 5.0) * 0.15 * (1.0 - k), 0.0, 1.0)
	if blink_t < 0.0:
		return 1.0
	return absf(blink_t / BLINK * 2.0 - 1.0)


# Souffle : de 0 à 1, plus ample et plus lent quand le fantôme se repose
func _breath() -> float:
	var deep := clampf((idle - 1.5) / 2.0, 0.0, 1.0)
	# Endormi : un souffle encore plus lent et plus ample
	var sleep := clampf((idle - DROWSY_AT) / (SLEEP_AT - DROWSY_AT), 0.0, 1.0)
	return (sin(t * BREATH * (1.0 - 0.3 * deep - 0.25 * sleep)) * 0.5 + 0.5) * (0.6 + 0.6 * deep + 0.4 * sleep)


func _draw() -> void:
	var lying := _lie_transform() if animated else Transform2D.IDENTITY
	draw_set_transform_matrix(lying)
	# Couché, il ne flotte plus de haut en bas
	var bob := sin(t * 3.0) * 0.8 * (1.0 - lie) if animated else 0.0
	var br := _breath() if animated else 0.0
	# La tête s'élargit et se soulève à l'inspiration ; le bas reste posé
	var rx := 7.0 + br * 0.45
	var ry := 7.0 + br * 0.7
	var pts := PackedVector2Array()
	for i in range(9):
		var a := PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * rx, -4.0 + bob + sin(a) * ry))
	pts.append(Vector2(rx, 5 + bob))
	var n := 6
	for i in range(n + 1):
		var x := rx - 2.0 * rx * i / n
		var y := 5.0 + bob + (2.5 if i % 2 == 0 else 0.0) + sin(t * 9.0 + i) * 0.8
		pts.append(Vector2(x, y))
	draw_colored_polygon(pts, tint)

	var look := _gaze()
	# Quand il regarde le joueur, il se tourne vers l'écran : les yeux reviennent au milieu
	var front := clampf((idle - ASK_AT) * 3.0, 0.0, 1.0) if animated else 0.0
	var ex := 1.5 * facing * (1.0 - front) + look.x
	var ey := -5.0 + bob - br * 0.5 + look.y
	# En dormant, la tête penche un peu
	if animated and idle >= DROWSY_AT:
		ey += clampf(idle - DROWSY_AT, 0.0, 1.0) * 1.0
	var open := _eye_open() if animated else 1.0
	var h := maxf(3.0 * open, 0.7)
	var eye := Color(0, 0, 0, tint.a)
	draw_rect(Rect2(ex - 3.5, ey + (3.0 - h) * 0.5, 2, h), eye)
	draw_rect(Rect2(ex + 1.5, ey + (3.0 - h) * 0.5, 2, h), eye)
	_draw_look(Settings.look, bob - br * 0.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if animated:
		_draw_idle(bob)


# Points d'interrogation tant qu'il regarde le joueur, puis des « z » qui s'envolent
func _draw_idle(bob: float) -> void:
	var font := ThemeDB.fallback_font
	if idle >= ASK_AT and idle < DROWSY_AT:
		var k := idle - ASK_AT
		var spots := [Vector2(-7, -13), Vector2(1, -17), Vector2(8, -13)]
		for i in spots.size():
			var age := k - 0.45 * i
			if age <= 0.0:
				continue
			# Chaque « ? » apparaît en sautillant, puis flotte doucement
			var pop := minf(1.0, age * 5.0)
			var hop := sin(minf(age * 6.0, PI)) * 2.0 + sin(t * 2.5 + i) * 0.8
			var fade := clampf((DROWSY_AT - idle) / 0.6, 0.0, 1.0)
			var at: Vector2 = spots[i] + Vector2(0, bob - hop)
			draw_set_transform(at, 0.0, Vector2.ONE * pop)
			draw_string(font, Vector2(-2.5, 3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, tint.a * fade))
		draw_set_transform(Vector2.ZERO)
	elif idle >= SLEEP_AT:
		var k := idle - SLEEP_AT
		for i in 3:
			var cycle := fmod(k - 0.8 * i, 2.4)
			if k - 0.8 * i < 0.0:
				continue
			var p := cycle / 2.4
			# Les « z » partent de sa tête, qu'il soit assis ou couché sur le côté
			var head := Vector2(5, -9).lerp(Vector2(facing * 20 - 2, -4), lie)
			var at := head + Vector2(p * 9 + sin(p * TAU) * 1.5, -p * 14 + bob)
			var size := int(round(5 + p * 4))
			var alpha := sin(p * PI) * tint.a
			draw_string(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, alpha))


# Décalage des yeux : vers la direction du mouvement, ou un coup d'œil au repos
func _gaze() -> Vector2:
	var g := gaze
	if aim != Vector2.ZERO:
		return (aim * 2.0).round()
	if idle >= ASK_AT:
		# Il regarde le joueur, droit devant, un peu vers le bas
		g = Vector2(0.0, 0.4)
	elif idle > 3.0:
		# Il regarde autour de lui, un côté puis l'autre, en marquant des pauses
		var phase := fmod(idle - 3.0, 6.0)
		if phase < 1.5:
			g = Vector2(1.0, -0.3)
		elif phase > 3.0 and phase < 4.5:
			g = Vector2(-1.0, -0.3)
		else:
			g = Vector2.ZERO
		g.x *= facing
	return Vector2(clampf(g.x, -1.0, 1.0) * 0.8, clampf(g.y, -1.0, 1.0) * 0.8).round()


func _draw_look(look: String, bob: float) -> void:
	var dark := Color(0.08, 0.08, 0.08, tint.a)
	var mid := Color(0.55, 0.55, 0.55, tint.a)
	var f := float(facing)
	match look:
		"scarf":
			# Bande au cou, et un pan qui flotte derrière le fantôme
			draw_rect(Rect2(-7, 0.5 + bob, 14, 2.5), mid)
			var wave := sin(t * 8.0) * 1.2
			draw_colored_polygon(PackedVector2Array([
				Vector2(-f * 4, 0.5 + bob), Vector2(-f * 12, 1 + bob + wave),
				Vector2(-f * 11, 4 + bob + wave), Vector2(-f * 4, 3 + bob)]), mid)
		"hat":
			draw_rect(Rect2(-6.5, -11.5 + bob, 13, 1.5), dark)
			draw_rect(Rect2(-4, -18 + bob, 8, 6.5), dark)
			draw_rect(Rect2(-4, -13.5 + bob, 8, 1), mid)
		"lantern":
			# Tenue devant le fantôme, elle se balance un peu
			var sway := sin(t * 2.5) * 1.0
			var top := Vector2(f * 9 + sway, -1 + bob)
			draw_line(Vector2(f * 6, -1 + bob), top, mid, 1.0)
			draw_rect(Rect2(top.x - 2, top.y + 1, 4, 5), mid)
			draw_rect(Rect2(top.x - 1, top.y + 2, 2, 3), Color(1, 1, 1, tint.a))
		"halo":
			var pts := PackedVector2Array()
			for i in 17:
				var a := TAU * i / 16.0
				pts.append(Vector2(cos(a) * 5.0, -14.0 + bob + sin(a) * 1.6))
			draw_polyline(pts, Color(1, 1, 1, tint.a * 0.9), 1.0)
		"crown":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -10 + bob), Vector2(-5, -15 + bob), Vector2(-2.5, -12.5 + bob),
				Vector2(0, -16 + bob), Vector2(2.5, -12.5 + bob), Vector2(5, -15 + bob),
				Vector2(5, -10 + bob)]), mid)
