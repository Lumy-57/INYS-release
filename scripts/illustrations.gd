# Vignettes illustrées des chapitres : une petite gravure en gris sur noir par chapitre,
# avec le fantôme quelque part dedans. Partagées par la carte d'ouverture de chapitre
# (chapter_intro.gd) et l'écran de choix du chapitre (chapter_select.gd).
# Tout est dessiné dans un cadre de SIZE unités, mis à l'échelle du rectangle demandé.
extends RefCounted

const Palette = preload("res://scripts/palette.gd")

const SIZE := Vector2(200, 100)
const INK := Color(0.42, 0.42, 0.42)     # traits
const DIM := Color(0.2, 0.2, 0.2)        # aplats lointains
const DEEP := Color(0.1, 0.1, 0.1)       # aplats proches
const PAPER := Color(0.035, 0.035, 0.035)


# Dessine la vignette du chapitre dans rect (repère de ci).
# reveal : 0 rideau fermé, 1 grand ouvert. zoom : léger travelling avant.
# mask : couleur du fond autour du cadre, qui cache ce qui déborde au zoom.
static func draw(ci: CanvasItem, chapter: String, rect: Rect2, t: float, reveal := 1.0,
		zoom := 1.0, mask := Color.BLACK, frame_alpha := 1.0) -> void:
	var k := rect.size / SIZE
	ci.draw_rect(rect, PAPER)
	var c := SIZE * 0.5
	# Le contenu zoome autour du centre de la vignette
	ci.draw_set_transform(rect.position + (c * (1.0 - zoom)) * k, 0.0, k * zoom)
	_scene(ci, chapter, t)
	ci.draw_set_transform(rect.position, 0.0, k)
	if zoom > 1.0:
		var m := 12.0
		ci.draw_rect(Rect2(-m, -m, SIZE.x + 2 * m, m), mask)
		ci.draw_rect(Rect2(-m, SIZE.y, SIZE.x + 2 * m, m), mask)
		ci.draw_rect(Rect2(-m, 0, m, SIZE.y), mask)
		ci.draw_rect(Rect2(SIZE.x, 0, m, SIZE.y), mask)
	# Rideau : deux battants noirs qui s'écartent depuis le milieu
	if reveal < 1.0:
		var half := SIZE.x * 0.5 * (1.0 - clampf(reveal, 0.0, 1.0))
		ci.draw_rect(Rect2(0, 0, half, SIZE.y), PAPER)
		ci.draw_rect(Rect2(SIZE.x - half, 0, half, SIZE.y), PAPER)
		if half > 0.5:
			ci.draw_line(Vector2(half, 0), Vector2(half, SIZE.y), Color(1, 1, 1, 0.5), -1.0)
			ci.draw_line(Vector2(SIZE.x - half, 0), Vector2(SIZE.x - half, SIZE.y), Color(1, 1, 1, 0.5), -1.0)
	_frame(ci, frame_alpha)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Double filet, petits losanges aux coins
static func _frame(ci: CanvasItem, a: float) -> void:
	var col := Color(0.8, 0.8, 0.8, a)
	ci.draw_rect(Rect2(Vector2.ZERO, SIZE), col, false, 1.0)
	ci.draw_rect(Rect2(Vector2(3, 3), SIZE - Vector2(6, 6)), Color(0.45, 0.45, 0.45, a), false, 0.6)
	for p in [Vector2(0, 0), Vector2(SIZE.x, 0), Vector2(0, SIZE.y), SIZE]:
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0),
			p + Vector2(0, 3), p + Vector2(-3, 0)]), col)


static func _scene(ci: CanvasItem, chapter: String, t: float) -> void:
	match chapter:
		"Le Seuil": _seuil(ci, t)
		"Lumière et ombre": _lumiere(ci, t)
		"Profondeurs": _profondeurs(ci, t)
		"Clocher": _clocher(ci, t)
		"Carillon": _carillon(ci, t)
		"Horloge": _horloge(ci, t)
		"Dernière lueur": _lueur(ci, t)
		"Poursuite": _poursuite(ci, t)
		"Regards": _regards(ci, t)
		"Miroir": _miroir(ci, t)
		"Compagnie": _compagnie(ci, t)
		"Le matin": _matin(ci, t)
		_: _seuil(ci, t)


# --- Éléments communs --------------------------------------------------------

# Le fantôme, en petit : respire et cligne comme celui du jeu
static func ghost(ci: CanvasItem, pos: Vector2, s: float, t: float, facing := 1.0,
		body := Color.WHITE, glow := true, eyes := true, blink_seed := -1.0) -> void:
	if glow:
		halo(ci, pos, 16.0 * s, 0.10)
	var br := sin(t * 1.9) * 0.5 + 0.5
	var bob := sin(t * 3.0) * 0.6
	var rx := (7.0 + br * 0.45) * s
	var ry := (7.0 + br * 0.7) * s
	var o := pos + Vector2(0, bob * s)
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(o + Vector2(cos(a) * rx, -4.0 * s + sin(a) * ry))
	for i in 7:
		var x := rx - 2.0 * rx * i / 6.0
		pts.append(o + Vector2(x, (5.0 + (2.5 if i % 2 == 0 else 0.0) + sin(t * 9.0 + i) * 0.8) * s))
	ci.draw_colored_polygon(pts, body)
	if eyes:
		var blink := fmod(t + (pos.x if blink_seed < 0.0 else blink_seed) * 0.37, 3.7) < 0.14
		var h := (0.7 if blink else 3.0) * s
		var ey := o.y + (-5.0 - br * 0.5) * s + (3.0 * s - h) * 0.5
		var ex := o.x + 1.5 * s * facing
		var col := Color(0, 0, 0, body.a)
		ci.draw_rect(Rect2(ex - 3.5 * s, ey, 2.0 * s, h), col)
		ci.draw_rect(Rect2(ex + 1.5 * s, ey, 2.0 * s, h), col)


# Lueur douce : disques concentriques presque transparents
static func halo(ci: CanvasItem, pos: Vector2, r: float, a: float) -> void:
	for i in 5:
		ci.draw_circle(pos, r * (1.0 - i * 0.18), Color(1, 1, 1, a))


static func flame(ci: CanvasItem, pos: Vector2, s: float, t: float) -> void:
	var f := sin(t * 11.0) * 0.4 + sin(t * 7.3) * 0.3
	halo(ci, pos + Vector2(0, -3 * s), 12.0 * s, 0.08)
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-2.2 * s, 0), pos + Vector2(f * s, -7.5 * s),
		pos + Vector2(2.2 * s, 0), pos + Vector2(0, 1.5 * s)]), Color(1, 1, 1, 0.95))


static func bell(ci: CanvasItem, top: Vector2, r: float, angle: float, col: Color) -> void:
	var dir := Vector2.from_angle(PI * 0.5 + angle)
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		top + side * r * 0.35, top + dir * r * 0.4 + side * r * 0.55,
		top + dir * r * 1.1 + side * r * 0.95, top + dir * r * 1.1 - side * r * 0.95,
		top + dir * r * 0.4 - side * r * 0.55, top - side * r * 0.35])
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(top + dir * r * 1.2, r * 0.18, col)


static func ground(ci: CanvasItem, y: float, col := DEEP) -> void:
	ci.draw_rect(Rect2(0, y, SIZE.x, SIZE.y - y), col)


# --- Chapitres ---------------------------------------------------------------

# Le Seuil : dans la grotte au pied de la grande tour. Par l'ouverture on voit la tour,
# une goutte tombe dans une flaque, une toute petite flamme s'éveille à côté
static func _seuil(ci: CanvasItem, t: float) -> void:
	# Dehors, par l'entrée : un peu de ciel, quelques étoiles, la tour
	var mouth := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		mouth.append(Vector2(132 + cos(a) * 40.0 + sin(i * 2.3) * 2.0, 84 + sin(a) * 62.0 + cos(i * 1.7) * 2.0))
	mouth.append(Vector2(172, 90))
	mouth.append(Vector2(92, 90))
	ci.draw_colored_polygon(mouth, Color(0.13, 0.13, 0.13))
	for i in 7:
		var p := Vector2(104 + fmod(i * 37.0, 56.0), 30 + fmod(i * 23.0, 26.0))
		ci.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.25 + 0.2 * sin(t * 2.0 + i)))
	ci.draw_rect(Rect2(140, 34, 14, 54), DIM)
	ci.draw_rect(Rect2(146, 40, 2, 3), Color(1, 1, 1, 0.3 + 0.15 * sin(t * 1.3)))
	# La voûte de la grotte et ses concrétions
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 100),
		Vector2(174, 100), Vector2(172, 40), Vector2(160, 18), Vector2(132, 16), Vector2(104, 18), Vector2(92, 40),
		Vector2(90, 100), Vector2(0, 100)]), DEEP)
	for x in [24.0, 52.0, 70.0, 120.0, 150.0, 186.0]:
		var l := 8.0 + fmod(x * 0.37, 12.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 0), Vector2(x + 4, 0), Vector2(x, 14 + l)]), DIM)
	# Le voile de jour qui entre
	ci.draw_colored_polygon(PackedVector2Array([Vector2(98, 60), Vector2(166, 60), Vector2(150, 100), Vector2(60, 100)]),
		Color(1, 1, 1, 0.035 + 0.01 * sin(t * 0.8)))
	ground(ci, 90)
	# La goutte : elle perle, tombe, et fait des ronds dans la flaque
	var x0 := 52.0
	var tip := 14.0 + fmod(52.0 * 0.37, 12.0) + 8.0
	ci.draw_line(Vector2(36, 90), Vector2(68, 90), Color(0.3, 0.3, 0.3), 0.8)
	var u := fmod(t, 2.4)
	if u < 1.8:
		ci.draw_circle(Vector2(x0, tip + u * 0.6), 0.3 + u * 0.5, Color(1, 1, 1, 0.8))
	else:
		var y := tip + 1.0 + 0.5 * 340.0 * pow(u - 1.8, 2.0)
		ci.draw_line(Vector2(x0, y - 3.0), Vector2(x0, minf(y, 89.0)), Color(1, 1, 1, 0.8), 1.0)
	# Ronds aplatis, tracés à la main (le repère de la vignette est déjà mis à l'échelle)
	for i in 2:
		var r := u * 8.0 - i * 3.0
		if r > 0.0 and u < 1.5:
			var ring := PackedVector2Array()
			for j in 17:
				var a := TAU * j / 16.0
				ring.append(Vector2(x0 + cos(a) * r, 90.0 + sin(a) * r * 0.25))
			ci.draw_polyline(ring, Color(1, 1, 1, 0.3 * (1.0 - u / 1.5)), 0.6)
	ghost(ci, Vector2(100, 80), 0.9, t)


# Lumière et ombre : un rai de lumière tombe d'une fenêtre ; le fantôme dedans, son ombre longue
static func _lumiere(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(22, 8, 16, 26), DIM)
	ci.draw_circle(Vector2(30, 8), 8, DIM)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(22, 10), Vector2(38, 10),
		Vector2(120, 88), Vector2(70, 88)]), Color(1, 1, 1, 0.07 + 0.01 * sin(t * 2.0)))
	ground(ci, 88)
	# L'ombre part à l'opposé de la fenêtre, étirée
	ci.draw_colored_polygon(PackedVector2Array([Vector2(90, 88), Vector2(186, 80),
		Vector2(190, 86), Vector2(98, 90)]), Color(0, 0, 0, 0.95))
	for x in [150.0, 176.0]:
		ci.draw_rect(Rect2(x, 0, 10, 88), DEEP)
	ghost(ci, Vector2(94, 79), 0.9, t)


# Profondeurs : grotte, gouttes, le fantôme qui descend et entend son écho
static func _profondeurs(ci: CanvasItem, t: float) -> void:
	for i in 12:
		var x := i * 18.0 + 4.0
		var l := 10.0 + fmod(i * 23.0, 26.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 0), Vector2(x + 6, 0), Vector2(x, l)]), DIM)
		var g := 6.0 + fmod(i * 17.0, 14.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 3, 100), Vector2(x + 15, 100), Vector2(x + 9, 100 - g)]), DEEP)
	for i in 3:
		var x := 30.0 + i * 64.0
		var y := fmod(t * 40.0 + i * 31.0, 70.0) + 20.0
		ci.draw_rect(Rect2(x, y, 1, 2), Color(1, 1, 1, 0.4))
	var c := Vector2(100, 54)
	for i in 3:
		var r := fmod(t * 14.0 + i * 12.0, 36.0) + 10.0
		ci.draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.25 * (1.0 - r / 46.0)), 0.6)
	ghost(ci, c + Vector2(0, sin(t * 0.8) * 2.0), 1.0, t)


# Clocher : une grosse cloche qui se balance, le fantôme tout petit en dessous
static func _clocher(ci: CanvasItem, t: float) -> void:
	ci.draw_line(Vector2(20, 0), Vector2(100, 30), DIM, 2.0)
	ci.draw_line(Vector2(180, 0), Vector2(100, 30), DIM, 2.0)
	ci.draw_rect(Rect2(10, 10, 180, 4), DIM)
	var a := sin(t * 1.4) * 0.35
	bell(ci, Vector2(100, 14), 26.0, a, INK)
	var tip := Vector2(100, 14) + Vector2.from_angle(PI * 0.5 + a) * 34.0
	ci.draw_line(tip, tip + Vector2(0, 30), DIM, 0.8)
	ground(ci, 90)
	ghost(ci, Vector2(100, 84), 0.7, t, 1.0, Color.WHITE, true)


# Carillon : une rangée de cloches ; celle qui sonne s'allume et fait des ondes
static func _carillon(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(0, 14, SIZE.x, 3), DIM)
	var ringing := int(t / 0.9) % 5
	for i in 5:
		var top := Vector2(24 + i * 38, 17 + (i % 2) * 10)
		ci.draw_line(Vector2(top.x, 17), top, DIM, 0.8)
		var lit := i == ringing
		var a := sin(t * 6.0) * 0.25 if lit else sin(t * 1.2 + i) * 0.05
		bell(ci, top, 12.0, a, Color(0.75, 0.75, 0.75) if lit else DIM)
		if lit:
			var ph := fmod(t, 0.9) / 0.9
			ci.draw_arc(top + Vector2(0, 14), 10 + ph * 18, 0.3, PI - 0.3, 16, Color(1, 1, 1, 0.4 * (1.0 - ph)), 0.6)
	ground(ci, 88)
	ghost(ci, Vector2(24 + ringing * 38, 80), 0.8, t)


# Horloge : un grand cadran qui tourne, le fantôme assis à attendre sur le rebord
static func _horloge(ci: CanvasItem, t: float) -> void:
	var c := Vector2(100, 44)
	ci.draw_circle(c, 36, DIM)
	ci.draw_circle(c, 32, PAPER)
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0)
		ci.draw_line(c + d * 27, c + d * 31, INK, 1.0)
	ci.draw_line(c, c + Vector2.from_angle(t * 0.6 - PI * 0.5) * 26, INK, 1.2)
	ci.draw_line(c, c + Vector2.from_angle(t * 0.05 - PI * 0.5) * 16, INK, 2.0)
	ci.draw_circle(c, 2, INK)
	var sw := sin(t * 2.6) * 0.4
	var bob := c + Vector2(0, 36) + Vector2.from_angle(PI * 0.5 + sw) * 18
	ci.draw_line(c + Vector2(0, 36), bob, DIM, 1.0)
	ci.draw_circle(bob, 4, DIM)
	ci.draw_rect(Rect2(40, 86, 120, 3), DIM)
	ghost(ci, Vector2(150, 79), 0.8, t, -1.0)


# Dernière lueur : un long couloir vers une grande clarté
static func _lueur(ci: CanvasItem, t: float) -> void:
	var v := Vector2(160, 50)
	var flick := 0.9 + 0.1 * sin(t * 13.0) * sin(t * 3.1)
	halo(ci, v, 42.0 * flick, 0.07)
	ci.draw_rect(Rect2(152, 34, 16, 32), Color(1, 1, 1, 0.8 * flick))
	for i in 6:
		var x := 10.0 + i * 24.0
		var k := (x - 10.0) / 150.0
		var top := lerpf(0.0, 34.0, k)
		var bottom := lerpf(100.0, 66.0, k)
		ci.draw_line(Vector2(x, top), Vector2(x, bottom), DIM, 1.0 + 2.0 * (1.0 - k))
	ci.draw_line(Vector2(0, 0), v + Vector2(-8, -16), DIM, 1.0)
	ci.draw_line(Vector2(0, 100), v + Vector2(-8, 16), DIM, 1.0)
	ghost(ci, Vector2(70, 72), 0.9, t)


# Poursuite : le fantôme file à gauche ; derrière lui, son ombre, même forme, sans visage
static func _poursuite(ci: CanvasItem, t: float) -> void:
	ground(ci, 86)
	for i in 6:
		var x := fmod(-t * 30.0 + i * 40.0, 220.0) - 10.0
		ci.draw_line(Vector2(x, 86), Vector2(x - 6, 86), INK, 0.6)
	var g := Vector2(64, 74)
	ghost(ci, g, 1.0, t, -1.0)
	var s := Vector2(136, 74) + Vector2(sin(t * 1.7) * 3.0, 0)
	ghost(ci, s, 1.12, t + 0.4, -1.0, Color(0.7, 0.7, 0.7, 0.8), false, false)
	ghost(ci, s, 1.0, t + 0.4, -1.0, Color(0.02, 0.02, 0.02), false, false)


# Regards : des yeux qui s'ouvrent dans le noir tout autour du fantôme
static func _regards(ci: CanvasItem, t: float) -> void:
	for i in 11:
		var p := Vector2(fmod(i * 67.0, 180.0) + 10.0, fmod(i * 41.0, 70.0) + 10.0)
		if p.distance_to(Vector2(100, 60)) < 26.0:
			continue
		var open := clampf(sin(t * 0.9 + i * 1.7) * 1.5, 0.0, 1.0)
		var w := 7.0
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(0, -3.0 * open - 0.3),
			p + Vector2(w, 0), p + Vector2(0, 3.0 * open + 0.3)]), INK)
		if open > 0.3:
			var look := (Vector2(100, 60) - p).normalized() * 2.0
			ci.draw_circle(p + look, 1.6 * open, PAPER)
	ground(ci, 88)
	ghost(ci, Vector2(100, 78), 0.9, t)


# Miroir : un grand cadre au milieu ; le fantôme d'un côté, son reflet de l'autre
static func _miroir(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(80, 12, 40, 76), DIM, false, 3.0)
	ci.draw_rect(Rect2(82, 14, 36, 72), Color(1, 1, 1, 0.04))
	ci.draw_line(Vector2(100, 14), Vector2(100, 86), Color(1, 1, 1, 0.18), 0.6)
	ground(ci, 88)
	var d := 18.0 + sin(t * 0.7) * 3.0
	ghost(ci, Vector2(100 - d, 78), 0.9, t, 1.0, Color.WHITE, true, true, 1.0)
	ghost(ci, Vector2(100 + d, 78), 0.9, t, -1.0, Color(0.7, 0.7, 0.7), false, true, 1.0)


# Compagnie : des pierres cachées dans le noir ; la petite orbe tourne et les fait paraître
static func _compagnie(ci: CanvasItem, t: float) -> void:
	var orb := Vector2(100, 56) + Vector2(cos(t * 1.3) * 62.0, sin(t * 2.6) * 14.0)
	halo(ci, orb, 26.0, 0.05)
	var stones := [Vector2(24, 80), Vector2(52, 66), Vector2(84, 74), Vector2(116, 62), Vector2(146, 70), Vector2(174, 56)]
	for p in stones:
		var lit := clampf(1.0 - (p.distance_to(orb) - 18.0) / 26.0, 0.0, 1.0)
		var r := Rect2(p - Vector2(10, 0), Vector2(20, 6))
		if lit > 0.0:
			ci.draw_rect(r, Color(0.5, 0.5, 0.5, lit))
		ci.draw_rect(r, Color(1, 1, 1, 0.08 + 0.3 * lit), false, 0.6)
	ghost(ci, Vector2(84, 67), 0.8, t, 1.0 if orb.x > 84.0 else -1.0)
	for i in 5:
		var q := Vector2(100, 56) + Vector2(cos((t - i * 0.05) * 1.3) * 62.0, sin((t - i * 0.05) * 2.6) * 14.0)
		ci.draw_circle(q, 1.2 * (1.0 - i / 5.0), Color(1, 1, 1, 0.3 * (1.0 - i / 5.0)))
	ci.draw_circle(orb, 3.2, Color(1, 1, 1, 0.15))
	ci.draw_circle(orb, 2.2, Color.WHITE)


# Le matin : le jour se lève derrière la tour ; ses vitraux ont pris des couleurs.
# Le fantôme marche avec son ombre devenue compagne, à côté de lui et non plus derrière.
static func _matin(ci: CanvasItem, t: float) -> void:
	# Ciel en bandes, du rose d'aube près de l'horizon au mauve plus haut
	for i in 8:
		var k := i / 7.0
		var col := Color(0.12, 0.08, 0.14).lerp(Palette.DAWN * Color(0.75, 0.6, 0.55), k)
		ci.draw_rect(Rect2(0, i * 10.0, SIZE.x, 10), col)
	var sun := Vector2(48, 74 - minf(t, 6.0) * 1.5)
	halo(ci, sun, 34.0, 0.06)
	ci.draw_circle(sun, 9, Palette.GOLD * Color(1, 1, 1, 0.85))
	# La tour et ses vitraux
	ci.draw_rect(Rect2(116, -2, 48, 82), Color(0.2, 0.15, 0.22))
	for j in 3:
		var w := Rect2(126 + j * 10, 14 + (j % 2) * 18, 6, 12)
		var glass: Color = Palette.GLASS[(j * 2) % Palette.GLASS.size()]
		ci.draw_rect(w, glass * Color(1, 1, 1, 0.55 + 0.1 * sin(t * 1.5 + j)))
		ci.draw_circle(Vector2(w.position.x + 3, w.position.y), 3, glass * Color(1, 1, 1, 0.55))
	# Herbe et petites fleurs de couleur au premier plan
	ci.draw_rect(Rect2(0, 80, SIZE.x, 20), Color(0.16, 0.2, 0.17))
	for i in 22:
		var x := 4.0 + i * 9.0
		var sway := sin(t * 1.4 + i) * 1.2
		ci.draw_line(Vector2(x, 84), Vector2(x + sway, 77 + fmod(i * 5.0, 4.0)), Palette.LEAF * Color(0.45, 0.5, 0.45), 1.0)
		if i % 4 == 1:
			ci.draw_circle(Vector2(x + sway, 76 + fmod(i * 5.0, 4.0)), 1.2, Palette.GLASS[i % Palette.GLASS.size()])
	ghost(ci, Vector2(80, 72), 0.85, t, 1.0, Color.WHITE, true, true, 2.0)
	ghost(ci, Vector2(98, 72), 0.9, t + 0.3, -1.0, Color(1.0, 0.85, 0.75, 0.6), false, false)
	ghost(ci, Vector2(98, 72), 0.8, t + 0.3, -1.0, Color(0.32, 0.25, 0.42), false, true, 2.3)
