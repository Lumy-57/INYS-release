# Chapitre Compagnie : pierres cachées ("i").
# Invisibles et traversables dans le noir. Quand la petite orbe passe près d'elles,
# elles apparaissent et portent le fantôme, puis s'effacent peu après son départ.
# Une pierre déjà vue garde un contour très pâle : on se souvient d'où elle était.
# Le fantôme seul n'en devine qu'autour de ses pieds : c'est l'orbe qui voit loin.
# On les traverse par en dessous (on ne s'y cogne jamais la tête) et, comme les blocs
# de phase, une pierre ne réapparaît jamais sur le fantôme.
extends Node2D

const TILE := 16
const REACH := 40.0  # distance orbe-pierre à laquelle la pierre apparaît
const REACH_GHOST := 22.0  # idem autour du fantôme
const GRACE := 0.9   # durée pendant laquelle elle reste après le passage de l'orbe

var cells: Array = []  # Vector2i
var player: CharacterBody2D
var orb: Node2D
var rects: Array = []
var shapes: Array = []
var solid: Array = []
var left: Array = []   # temps restant avant de s'effacer
var shown: Array = []  # 0 → 1, pour le fondu
var seen: Array = []
var t := 0.0


func _ready() -> void:
	# Lisibles même hors de la lumière du fantôme : c'est l'orbe qui les montre
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	for c in cells:
		var r := Rect2(Vector2(c) * TILE, Vector2(TILE, TILE))
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		cs.shape = rect
		cs.position = r.get_center()
		cs.disabled = true
		cs.one_way_collision = true
		body.add_child(cs)
		add_child(body)
		rects.append(r)
		shapes.append(cs)
		solid.append(false)
		left.append(0.0)
		shown.append(0.0)
		seen.append(false)


func reset() -> void:
	for i in rects.size():
		left[i] = 0.0


func _physics_process(delta: float) -> void:
	var lights: Array = orb.lit_points() if orb else []
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14)).grow(-0.5)
	for i in rects.size():
		var r: Rect2 = rects[i]
		for j in lights.size():
			var p: Vector2 = lights[j]
			var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			if q.distance_to(p) < (REACH if j == 0 else REACH_GHOST):
				left[i] = GRACE
				seen[i] = true
				break
		left[i] = maxf(left[i] - delta, 0.0)
		var on: bool = left[i] > 0.0
		if on and not solid[i] and not player.dead and r.intersects(body_rect):
			on = false
		if on != solid[i]:
			solid[i] = on
			shapes[i].set_deferred("disabled", not on)


func _process(delta: float) -> void:
	t += delta
	for i in rects.size():
		shown[i] = move_toward(shown[i], 1.0 if solid[i] else 0.0, delta * (6.0 if solid[i] else 2.5))
	queue_redraw()


func _draw() -> void:
	for i in rects.size():
		var r: Rect2 = rects[i]
		var k: float = shown[i]
		if k > 0.0:
			draw_rect(r, Color(0.92, 0.92, 0.95, 0.85 * k))
			draw_rect(r.grow(-3), Color(0.7, 0.7, 0.76, 0.85 * k))
			# Un petit éclat qui court sur la pierre
			var x := r.position.x + fposmod(t * 18.0 + r.position.y * 0.7, TILE)
			draw_rect(Rect2(x, r.position.y + 1, 1, 2), Color(1, 1, 1, 0.9 * k))
		elif seen[i]:
			_dotted(r, Color(0.7, 0.7, 0.75, 0.22))
		if seen[i] and k > 0.0 and k < 1.0:
			_dotted(r, Color(0.7, 0.7, 0.75, 0.22 * (1.0 - k)))


func _dotted(r: Rect2, c: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, 2, 1), c)
		x += 4.0
