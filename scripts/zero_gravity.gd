# Zone de zéro gravité : le fantôme y flotte sur son élan, et son dash s'y recharge sans cesse.
extends Node2D

var rect: Rect2
var player: CharacterBody2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	# Poussières en suspension, qui dérivent lentement dans tous les sens
	var motes := CPUParticles2D.new()
	motes.material = mat
	motes.amount = int(clampf(rect.size.x * rect.size.y / 400.0, 6, 60))
	motes.lifetime = 3.0
	motes.position = rect.get_center()
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = rect.size * 0.5 - Vector2(2, 2)
	motes.direction = Vector2.UP
	motes.spread = 180
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 2
	motes.initial_velocity_max = 8
	motes.scale_amount_min = 1
	motes.scale_amount_max = 2
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.5, Color(1, 1, 1, 0.5))
	motes.color_ramp = grad
	motes.preprocess = motes.lifetime
	add_child(motes)


func _physics_process(_delta: float) -> void:
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14))
	if not player.dead and rect.intersects(body_rect):
		player.zero_g_frame = Engine.get_physics_frames()


func _draw() -> void:
	# Un voile à peine visible et un contour pointillé
	draw_rect(rect, Color(1, 1, 1, 0.04))
	var c := Color(1, 1, 1, 0.18)
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y, 2, 1), c)
		draw_rect(Rect2(x, rect.end.y - 1, 2, 1), c)
		x += 4
	var y := rect.position.y
	while y < rect.end.y:
		draw_rect(Rect2(rect.position.x, y, 1, 2), c)
		draw_rect(Rect2(rect.end.x - 1, y, 1, 2), c)
		y += 4
