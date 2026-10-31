# Dessin du fantôme : tête ronde, bas ondulant, deux yeux noirs,
# et l'accessoire choisi dans les options (Settings.look).
# Animé, il respire (la tête gonfle et se soulève doucement), cligne des yeux
# à intervalles irréguliers, et regarde un peu là où il va (gaze).
extends Node2D

const BREATH := 1.9         # pulsation du souffle, en radians par seconde
const BLINK := 0.14         # durée d'un clignement

var facing := 1
var tint := Color.WHITE
var animated := true
var t := 0.0
# Direction du regard, de -1 à 1 sur chaque axe ; le joueur y met sa vitesse
var gaze := Vector2.ZERO
# Temps passé immobile : au repos, le souffle s'approfondit et le regard flâne
var idle := 0.0
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
		queue_redraw()


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
	if blink_t < 0.0:
		return 1.0
	return absf(blink_t / BLINK * 2.0 - 1.0)


# Souffle : de 0 à 1, plus ample et plus lent quand le fantôme se repose
func _breath() -> float:
	var deep := clampf((idle - 1.5) / 2.0, 0.0, 1.0)
	return (sin(t * BREATH * (1.0 - 0.3 * deep)) * 0.5 + 0.5) * (0.6 + 0.6 * deep)


func _draw() -> void:
	var bob := sin(t * 3.0) * 0.8 if animated else 0.0
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
	var ex := 1.5 * facing + look.x
	var ey := -5.0 + bob - br * 0.5 + look.y
	var open := _eye_open() if animated else 1.0
	var h := maxf(3.0 * open, 0.7)
	var eye := Color(0, 0, 0, tint.a)
	draw_rect(Rect2(ex - 3.5, ey + (3.0 - h) * 0.5, 2, h), eye)
	draw_rect(Rect2(ex + 1.5, ey + (3.0 - h) * 0.5, 2, h), eye)
	_draw_look(Settings.look, bob - br * 0.5)


# Décalage des yeux : vers la direction du mouvement, ou un coup d'œil au repos
func _gaze() -> Vector2:
	var g := gaze
	if idle > 3.0:
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
