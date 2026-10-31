# Pierre fissurée : tremble dès que le fantôme la touche, s'effondre, puis revient.
extends StaticBody2D

const SHAKE_TIME := 0.45
const GONE_TIME := 2.0

var rect: Rect2            # en pixels, coordonnées du niveau
var player: CharacterBody2D
var state := "idle"        # idle, shaking, gone
var timer := 0.0
var shape: CollisionShape2D
var t := 0.0

signal crumbled(block)


func _ready() -> void:
	shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.get_center()
	add_child(shape)


func reset() -> void:
	state = "idle"
	timer = 0.0
	shape.set_deferred("disabled", false)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14))
	match state:
		"idle":
			# Un contact par le dessus ou par le côté suffit
			if not player.dead and rect.grow(1.5).intersects(body_rect):
				state = "shaking"
				timer = SHAKE_TIME
		"shaking":
			timer -= delta
			if timer <= 0.0:
				state = "gone"
				timer = GONE_TIME
				shape.set_deferred("disabled", true)
				crumbled.emit(self)
		"gone":
			timer -= delta
			if timer <= 0.0 and not rect.intersects(body_rect.grow(1.0)):
				reset()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if state == "gone":
		var c := Color(0.5, 0.5, 0.5, 0.35)
		var x := rect.position.x
		while x < rect.end.x:
			draw_rect(Rect2(x, rect.position.y, 2, 1), c)
			draw_rect(Rect2(x, rect.end.y - 1, 2, 1), c)
			x += 4.0
		return
	var off := Vector2.ZERO
	if state == "shaking":
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	var r := Rect2(rect.position + off, rect.size)
	draw_rect(r, Color(0.45, 0.45, 0.45))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.95, 0.95, 0.95))
	# Fissures
	var x0 := r.position.x
	while x0 < r.end.x:
		var crack := Color(0.15, 0.15, 0.15)
		draw_line(Vector2(x0 + 5, r.position.y + 2), Vector2(x0 + 8, r.position.y + 8), crack, 1.0)
		draw_line(Vector2(x0 + 8, r.position.y + 8), Vector2(x0 + 6, r.end.y), crack, 1.0)
		draw_line(Vector2(x0 + 8, r.position.y + 8), Vector2(x0 + 12, r.position.y + 11), crack, 1.0)
		x0 += 16.0
