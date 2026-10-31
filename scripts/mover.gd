# Plateforme mobile : fait l'aller-retour le long de son rail (cases "-" de la carte).
extends AnimatableBody2D

const SPEED := 60.0
const PAUSE := 0.4

var size := Vector2.ZERO
var start := Vector2.ZERO     # position de départ (coin haut gauche)
var low := 0.0                # décalage minimal le long de l'axe, en pixels
var high := 0.0               # décalage maximal
var vertical := false
var offset := 0.0
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
	position = start
	if high <= 0.0:
		dir = -1.0


func _physics_process(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
		return
	offset += dir * SPEED * delta
	if offset >= high:
		offset = high
		dir = -1.0
		wait = PAUSE
	elif offset <= low:
		offset = low
		dir = 1.0
		wait = PAUSE
	position = start + (Vector2(0, offset) if vertical else Vector2(offset, 0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.75, 0.75))
	draw_rect(Rect2(Vector2(2, 3), size - Vector2(4, 5)), Color(0.3, 0.3, 0.3))
	var x := 4.0
	while x < size.x - 2.0:
		draw_rect(Rect2(x, 6, 2, 2), Color(0.85, 0.85, 0.85))
		x += 8.0
