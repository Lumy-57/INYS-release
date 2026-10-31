# Blocs rythmés, sur un métronome commun à tout le niveau.
# "1" : solides pendant la première moitié du cycle. "2" : pendant la seconde.
# Un bloc clignote juste avant de disparaître ; un bloc absent se remplit à mesure qu'il revient.
# Comme les blocs de phase, un bloc qui devrait réapparaître sur le fantôme attend qu'il en sorte.
extends Node2D

const PERIOD := 2.4       # un cycle complet, en secondes
const WARN := 0.4         # durée du clignotement avant disparition

var runs_1: Array = []    # Rect2 en pixels
var runs_2: Array = []
var player: CharacterBody2D
var t := 0.0
var blocks: Array = []    # [rect, phase, shape, solid]


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	for pair in [[runs_1, 0], [runs_2, 1]]:
		for r in pair[0]:
			var body := StaticBody2D.new()
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = r.size
			cs.shape = rect
			cs.position = r.get_center()
			body.add_child(cs)
			add_child(body)
			blocks.append([r, pair[1], cs, true])
	_update(true)


# Phase active (0 ou 1) et temps écoulé dans la demi-période
func _phase() -> int:
	return int(fmod(t, PERIOD) / (PERIOD * 0.5))


func _in_half() -> float:
	return fmod(t, PERIOD * 0.5)


func _physics_process(delta: float) -> void:
	t += delta
	_update(false)


func _update(force: bool) -> void:
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14)).grow(-0.5)
	var phase := _phase()
	for b in blocks:
		var on: bool = b[1] == phase
		if on and not b[3] and not force and not player.dead and b[0].intersects(body_rect):
			on = false
		if on != b[3] or force:
			b[3] = on
			b[2].set_deferred("disabled", not on)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var half := PERIOD * 0.5
	var u := _in_half()
	var warn := u > half - WARN and fmod(u * 10.0, 1.0) < 0.5
	for b in blocks:
		var r: Rect2 = b[0]
		var light: bool = b[1] == 0
		if b[3]:
			var fill := Color(0.75, 0.75, 0.75) if light else Color(0.4, 0.4, 0.4)
			if warn:
				fill = fill.lerp(Color(0.1, 0.1, 0.1), 0.6)
			draw_rect(r, fill)
			draw_rect(r, Color(0.95, 0.95, 0.95), false, 1.0)
			_clock_marks(r, light, u / half)
		else:
			_dotted(r, Color(0.7, 0.7, 0.7, 0.45))
			# Le bloc absent se remplit par le bas jusqu'à son retour
			var k := u / half
			var h := r.size.y * k
			draw_rect(Rect2(r.position.x + 1, r.end.y - h, r.size.x - 2, h), Color(1, 1, 1, 0.08))


# Un petit cadran par tuile, dont l'aiguille fait un tour par demi-période
func _clock_marks(r: Rect2, light: bool, k: float) -> void:
	var ink := Color(0.3, 0.3, 0.3) if light else Color(0.85, 0.85, 0.85)
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			var c := Vector2(x + 8, y + 8)
			draw_arc(c, 4.0, 0.0, TAU, 12, ink, 1.0)
			draw_line(c, c + Vector2.UP.rotated(k * TAU) * 3.0, ink, 1.0)
			x += 16.0
		y += 16.0


func _dotted(r: Rect2, c: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, 2, 1), c)
		draw_rect(Rect2(x, r.end.y - 1, 2, 1), c)
		x += 4.0
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(r.position.x, y, 1, 2), c)
		draw_rect(Rect2(r.end.x - 1, y, 1, 2), c)
		y += 4.0
