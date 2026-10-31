# Ressort : propulse le fantôme vers le haut et lui rend son dash.
extends Area2D

const LAUNCH_SPEED := 430.0

var player: CharacterBody2D
var squash := 0.0

signal launched(spring)


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 6)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	# Le fantôme ou son reflet (chapitre Miroir)
	if not (body is CharacterBody2D and body.has_method("launch")) or body.dead or body.velocity.y < -50.0:
		return
	body.launch(Vector2(body.velocity.x, -LAUNCH_SPEED))
	squash = 1.0
	launched.emit(self)


func _process(delta: float) -> void:
	squash = move_toward(squash, 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	# Origine = bas de la tuile. Base, spirale puis plateau.
	var top := -6.0 + squash * 3.0
	draw_rect(Rect2(-7, -2, 14, 2), Color(0.5, 0.5, 0.5))
	var y := -2.0
	var i := 0
	while y > top + 1.0:
		var x := 5.0 if i % 2 == 0 else -5.0
		draw_line(Vector2(-x, y), Vector2(x, y - 1.5), Color(0.75, 0.75, 0.75), 1.0)
		y -= 1.5
		i += 1
	draw_rect(Rect2(-7, top - 2, 14, 2), Color.WHITE)
