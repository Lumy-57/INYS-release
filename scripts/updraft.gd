# Courant d'air spectral : une colonne qui soulève le fantôme tant qu'il est dedans.
extends Node2D

var rect: Rect2
var player: CharacterBody2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	var wisps := CPUParticles2D.new()
	wisps.material = mat
	wisps.amount = int(clampf(rect.size.x * rect.size.y / 300.0, 8, 80))
	wisps.lifetime = rect.size.y / 90.0
	wisps.position = Vector2(rect.get_center().x, rect.end.y)
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wisps.emission_rect_extents = Vector2(rect.size.x * 0.5, 2)
	wisps.direction = Vector2(0, -1)
	wisps.spread = 2
	wisps.gravity = Vector2.ZERO
	wisps.initial_velocity_min = 80
	wisps.initial_velocity_max = 100
	wisps.scale_amount_min = 1
	wisps.scale_amount_max = 2
	wisps.color_ramp = preload("res://scripts/player.gd").fade_gradient(Color(1, 1, 1, 0.6))
	wisps.preprocess = wisps.lifetime
	add_child(wisps)


func _physics_process(_delta: float) -> void:
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14))
	if not player.dead and rect.intersects(body_rect):
		player.in_updraft_frame = Engine.get_physics_frames()


func _draw() -> void:
	# Bords discrets de la colonne
	var c := Color(1, 1, 1, 0.12)
	draw_rect(Rect2(rect.position, Vector2(1, rect.size.y)), c)
	draw_rect(Rect2(Vector2(rect.end.x - 1, rect.position.y), Vector2(1, rect.size.y)), c)
