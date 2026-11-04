# Plateforme mobile (élément levels/elements/plateforme.gd) : fait l'aller-retour en ligne droite
# entre ses deux bouts, A et B, avec un arrêt à chaque bout.
extends AnimatableBody2D

var size := Vector2.ZERO
var start := Vector2.ZERO     # bout A (coin haut gauche), en pixels
var course := Vector2.ZERO    # de A à B, en pixels
var speed := 60.0             # px/s
var pause := 0.4              # secondes d'arrêt à chaque bout
var start_at := 0.0           # position de départ : 0 = en A, 1 = en B
var offset := 0.0             # distance parcourue depuis A
var dir := 1.0
var wait := 0.0


func _ready() -> void:
	sync_to_physics = true
	# Toujours lisible, même loin de la lumière du fantôme
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size * 0.5
	add_child(cs)
	offset = clampf(start_at, 0.0, 1.0) * course.length()
	if start_at >= 1.0:
		dir = -1.0
	position = _at(offset)


func _at(d: float) -> Vector2:
	var length := course.length()
	return start + (course * (d / length) if length > 0.0 else Vector2.ZERO)


func _physics_process(delta: float) -> void:
	var length := course.length()
	if length <= 0.0:
		return
	if wait > 0.0:
		wait -= delta
		return
	offset += dir * speed * delta
	if offset >= length:
		offset = length
		dir = -1.0
		wait = pause
	elif offset <= 0.0:
		offset = 0.0
		dir = 1.0
		wait = pause
	position = _at(offset)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.75, 0.75))
	draw_rect(Rect2(Vector2(2, 3), size - Vector2(4, 5)), Color(0.3, 0.3, 0.3))
	var x := 4.0
	while x < size.x - 2.0:
		draw_rect(Rect2(x, 6, 2, 2), Color(0.85, 0.85, 0.85))
		x += 8.0
