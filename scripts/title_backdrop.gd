# Fond illustré de l'écran titre, à la place du niveau : la nuit sur le marais noyé,
# la grande tour à gauche avec sa lanterne éteinte, les toits du village qui dépassent
# de l'eau, la brume qui passe, et le fantôme à droite, seule lueur, avec son reflet.
# Dessiné dans la couche du HUD, sous le texte du menu ; se fond au noir quand la partie démarre.
extends Node2D

const Illustrations = preload("res://scripts/illustrations.gd")

const W := 480.0
const H := 270.0
const HORIZON := 196.0
const GHOST := Vector2(404, 168)
const SKY_TOP := Color(0.0, 0.0, 0.0)
const SKY_LOW := Color(0.075, 0.075, 0.075)
const FAR := Color(0.11, 0.11, 0.11)       # toits lointains
const NEAR := Color(0.05, 0.05, 0.05)      # tour et roseaux, presque noirs
const WATER := Color(0.025, 0.025, 0.025)
const FADE_SPEED := 3.0

var main: Node
var t := 0.0


func _process(delta: float) -> void:
	var target := 1.0 if main.on_title else 0.0
	modulate.a = move_toward(modulate.a, target, delta * FADE_SPEED)
	visible = modulate.a > 0.0
	if visible:
		t += delta
		queue_redraw()


func _draw() -> void:
	_sky()
	_stars()
	_village()
	_tower()
	_water()
	_mist()
	_reeds()
	_ghost()
	_motes()
	_reading_shade()


# Ciel : du noir en haut à un gris de cendre au ras de l'horizon
func _sky() -> void:
	var bands := 24
	for i in bands:
		var y := HORIZON * i / bands
		draw_rect(Rect2(0, y, W, HORIZON / bands + 1.0), SKY_TOP.lerp(SKY_LOW, pow(float(i) / bands, 2.2)))


func _stars() -> void:
	for i in 40:
		var p := Vector2(fmod(i * 97.0 + 13.0, W), fmod(i * 61.0 + 7.0, HORIZON - 70.0) + 4.0)
		var a := 0.12 + 0.18 * (sin(t * (0.6 + fmod(i * 0.37, 1.0)) + i * 1.7) * 0.5 + 0.5)
		draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, a))


# Le village noyé : des toits pointus et un clocheton qui sortent de l'eau
func _village() -> void:
	var roofs := [[150.0, 14.0, 10.0], [178.0, 18.0, 14.0], [212.0, 12.0, 8.0], [262.0, 16.0, 12.0],
		[296.0, 22.0, 16.0], [334.0, 13.0, 9.0], [452.0, 18.0, 12.0]]
	for r in roofs:
		var x: float = r[0]
		var half: float = r[1] * 0.5
		var h: float = r[2]
		draw_rect(Rect2(x - half, HORIZON - h * 0.45, half * 2.0, h * 0.45), FAR)
		draw_colored_polygon(PackedVector2Array([Vector2(x - half - 2, HORIZON - h * 0.45),
			Vector2(x, HORIZON - h - 4), Vector2(x + half + 2, HORIZON - h * 0.45)]), FAR)
	# Le clocheton de la chapelle, plus haut que le reste
	draw_rect(Rect2(236, HORIZON - 30, 8, 30), FAR)
	draw_colored_polygon(PackedVector2Array([Vector2(234, HORIZON - 30), Vector2(240, HORIZON - 44),
		Vector2(246, HORIZON - 30)]), FAR)
	draw_line(Vector2(240, HORIZON - 44), Vector2(240, HORIZON - 50), FAR, 1.0)


# La grande tour-phare : pierre en assises, lanterne au sommet, éteinte depuis longtemps
func _tower() -> void:
	var x := 30.0
	var w := 50.0
	var top := 52.0
	draw_colored_polygon(PackedVector2Array([Vector2(x, HORIZON + 4), Vector2(x + 6, top),
		Vector2(x + w - 6, top), Vector2(x + w, HORIZON + 4)]), NEAR)
	for y in range(int(top) + 10, int(HORIZON), 9):
		var k := (y - top) / (HORIZON - top)
		draw_line(Vector2(x + 6 - 6 * k, y), Vector2(x + w - 6 + 6 * k, y), Color(0.08, 0.08, 0.08), 1.0)
	# Meurtrière, porte au ras de l'eau
	draw_rect(Rect2(x + w * 0.5 - 1.5, 110, 3, 9), Color(0, 0, 0))
	draw_rect(Rect2(x + w * 0.5 - 6, HORIZON - 14, 12, 18), Color(0, 0, 0))
	draw_circle(Vector2(x + w * 0.5, HORIZON - 14), 6, Color(0, 0, 0))
	# Galerie et lanterne
	draw_rect(Rect2(x + 2, top - 3, w - 4, 3), NEAR)
	draw_rect(Rect2(x + 14, top - 19, w - 28, 16), NEAR)
	draw_rect(Rect2(x + 17, top - 16, w - 34, 11), Color(0.03, 0.03, 0.03))
	for i in 3:
		draw_line(Vector2(x + 17 + i * 5.5, top - 16), Vector2(x + 17 + i * 5.5, top - 5), NEAR, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 11, top - 19), Vector2(x + w * 0.5, top - 31),
		Vector2(x + w - 11, top - 19)]), NEAR)
	# Une braise, à peine : la flamme n'est pas tout à fait morte
	var ember := 0.05 + 0.04 * (sin(t * 0.9) * 0.5 + 0.5)
	draw_circle(Vector2(x + w * 0.5, top - 8), 3.0, Color(1, 1, 1, ember))


# L'eau du marais : rides qui scintillent, reflets de la tour et du fantôme
func _water() -> void:
	draw_rect(Rect2(0, HORIZON, W, H - HORIZON), WATER)
	# Reflet de la tour, déformé par les rides
	for i in 16:
		var y := HORIZON + 2 + i * 3.0
		var wob := sin(t * 1.4 + i * 0.9) * (1.0 + i * 0.12)
		draw_line(Vector2(36 + wob, y), Vector2(74 + wob, y), Color(0.05, 0.05, 0.05, 1.0 - i / 18.0), 2.0)
	# Reflet du fantôme : une colonne de traits lumineux qui tremble
	for i in 14:
		var y := HORIZON + 4 + i * 4.5
		var wob := sin(t * 2.2 + i * 1.3) * (1.0 + i * 0.25)
		var w := 10.0 - i * 0.4 + sin(t * 3.0 + i) * 1.5
		draw_line(Vector2(GHOST.x - w * 0.5 + wob, y), Vector2(GHOST.x + w * 0.5 + wob, y),
			Color(1, 1, 1, 0.22 * (1.0 - i / 14.0)), 1.0)
	# Rides de surface
	for i in 26:
		var y := HORIZON + 3 + fmod(i * 23.0, H - HORIZON - 6)
		var x := fmod(i * 71.0 + t * (6.0 + i % 4), W + 40.0) - 20.0
		var a := 0.05 + 0.05 * sin(t * 1.5 + i)
		draw_line(Vector2(x, y), Vector2(x + 6 + (i % 3) * 4, y), Color(1, 1, 1, maxf(a, 0.0)), 1.0)
	draw_line(Vector2(0, HORIZON), Vector2(W, HORIZON), Color(1, 1, 1, 0.06), 1.0)


# Bancs de brume qui glissent lentement au ras de l'eau
func _mist() -> void:
	for i in 6:
		var speed := 3.0 + i * 1.3
		var x := fmod(i * 131.0 + t * speed, W + 200.0) - 100.0
		var y := HORIZON - 10 + (i % 3) * 7.0
		for k in 4:
			var r := Vector2(60.0 - k * 12.0, 5.0 - k * 1.0)
			_ellipse(Vector2(x, y), r, Color(1, 1, 1, 0.012))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


# Roseaux noirs au premier plan, dans les deux coins
func _reeds() -> void:
	for i in 26:
		var left := i < 13
		var x := (4.0 + i * 7.0) if left else (W - 4.0 - (i - 13) * 6.5)
		var base := H + 2.0
		var hgt := 34.0 + fmod(i * 17.0, 30.0)
		var sway := sin(t * 1.1 + i * 0.8) * 3.0
		draw_line(Vector2(x, base), Vector2(x + sway, base - hgt), Color(0, 0, 0), 2.0)
		if i % 3 == 0:
			draw_rect(Rect2(x + sway - 1.5, base - hgt - 8, 3, 9), Color(0, 0, 0))


# Le lumignon : seule vraie lumière du tableau
func _ghost() -> void:
	var p := GHOST + Vector2(sin(t * 0.5) * 3.0, sin(t * 0.8) * 2.0)
	Illustrations.halo(self, p, 46.0, 0.035)
	Illustrations.halo(self, p, 22.0, 0.06)
	Illustrations.ghost(self, p, 1.4, t, -1.0, Color.WHITE, false)


# Poussières de lumière qui montent autour du fantôme
func _motes() -> void:
	for i in 12:
		var life := fmod(t * 0.25 + i * 0.37, 1.0)
		var x := GHOST.x + sin(i * 2.3 + t * 0.7) * (14.0 + i * 2.0)
		var y := GHOST.y + 18.0 - life * 70.0
		draw_rect(Rect2(x, y, 1, 1), Color(1, 1, 1, 0.5 * sin(life * PI)))


# Une ombre douce derrière le texte du menu pour qu'il reste lisible
func _reading_shade() -> void:
	for i in 6:
		var k := float(i) / 6.0
		draw_rect(Rect2(110 + k * 30.0, 6 + k * 6.0, W - 220 - k * 60.0, H - 12 - k * 12.0),
			Color(0, 0, 0, 0.09))
