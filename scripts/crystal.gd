# Cristal de dash : recharge le dash du fantôme puis réapparaît.
extends Area2D

signal touched(crystal)

const RESPAWN := 2.5

var active := true
var t := 0.0
var light: PointLight2D


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9
	shape.shape = circle
	add_child(shape)
	light = PointLight2D.new()
	light.texture = preload("res://scripts/player.gd").make_light_texture()
	light.texture_scale = 0.45
	light.energy = 1.1
	add_child(light)
	body_entered.connect(func(b): touched.emit(self, b))


func consume() -> void:
	active = false
	light.visible = false
	queue_redraw()
	get_tree().create_timer(RESPAWN).timeout.connect(reset)


func reset() -> void:
	active = true
	light.visible = true
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(t * 2.5) * 1.5
	if active:
		var d := PackedVector2Array([Vector2(0, -7 + y), Vector2(5, y), Vector2(0, 7 + y), Vector2(-5, y)])
		draw_colored_polygon(d, Color.WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -3 + y), Vector2(2, y), Vector2(0, 3 + y), Vector2(-2, y)]), Color(0.3, 0.3, 0.3))
	else:
		var d := PackedVector2Array([Vector2(0, -7 + y), Vector2(5, y), Vector2(0, 7 + y), Vector2(-5, y), Vector2(0, -7 + y)])
		draw_polyline(d, Color(0.5, 0.5, 0.5, 0.6), 1.0)
