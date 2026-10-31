# Bougie : point de réapparition. Elle s'allume quand le fantôme la touche.
extends Area2D

signal reached(checkpoint)

var lit := false
var t := 0.0
var light: PointLight2D


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 32)
	shape.shape = rect
	shape.position = Vector2(0, -16)
	add_child(shape)
	light = PointLight2D.new()
	light.texture = preload("res://scripts/player.gd").make_light_texture()
	light.texture_scale = 0.35
	light.energy = 0.5
	light.position = Vector2(0, -16)
	light.shadow_enabled = true
	add_child(light)
	body_entered.connect(func(b): reached.emit(self, b))


func light_up() -> void:
	if lit:
		return
	lit = true
	var tw := create_tween()
	tw.tween_property(light, "texture_scale", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(light, "energy", 1.2, 0.4)


func _process(delta: float) -> void:
	t += delta
	if lit:
		light.energy = 1.1 + sin(t * 11.0) * 0.08 + sin(t * 4.3) * 0.06
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-3, -12, 6, 10), Color(0.85, 0.85, 0.85))
	draw_rect(Rect2(-5, -2, 10, 2), Color(0.6, 0.6, 0.6))
	draw_line(Vector2(0, -12), Vector2(0, -14), Color(0.2, 0.2, 0.2), 1.0)
	if lit:
		var f := sin(t * 13.0) * 0.6
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -16), Vector2(f, -22), Vector2(2, -16), Vector2(0, -14)]), Color.WHITE)
