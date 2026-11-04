# Vent (élément levels/elements/vent.gd) : une zone qui pousse le fantôme tant qu'il est dedans,
# vers le haut, le bas, la gauche ou la droite, plus ou moins fort.
extends Node2D

const DIRS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

var rect: Rect2
var player: CharacterBody2D
var dir := 0  # index dans DIRS
var force := 1.0  # 1 = vent normal


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	var flow: Vector2 = DIRS[dir]
	var vertical := flow.x == 0.0
	# Longueur parcourue par les volutes, et largeur du bord d'où elles partent
	var length := rect.size.y if vertical else rect.size.x
	var width := rect.size.x if vertical else rect.size.y
	var wisps := CPUParticles2D.new()
	wisps.material = mat
	wisps.amount = int(clampf(rect.size.x * rect.size.y / 300.0, 8, 80))
	# Elles naissent sur le bord d'où vient le vent
	wisps.position = rect.get_center() - flow * length * 0.5
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wisps.emission_rect_extents = Vector2(width * 0.5, 2) if vertical else Vector2(2, width * 0.5)
	wisps.direction = flow
	wisps.spread = 2
	wisps.gravity = Vector2.ZERO
	wisps.lifetime = length / (90.0 * force)
	wisps.initial_velocity_min = 80 * force
	wisps.initial_velocity_max = 100 * force
	wisps.scale_amount_min = 1
	wisps.scale_amount_max = 2
	wisps.color_ramp = preload("res://scripts/player.gd").fade_gradient(Color(1, 1, 1, 0.6))
	wisps.preprocess = wisps.lifetime
	add_child(wisps)


func _physics_process(_delta: float) -> void:
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14))
	if not player.dead and rect.intersects(body_rect):
		player.wind_frames[dir] = Engine.get_physics_frames()
		player.wind_power[dir] = force


func _draw() -> void:
	# Bords discrets du couloir, le long du vent
	var c := Color(1, 1, 1, 0.12)
	if dir < 2:
		draw_rect(Rect2(rect.position, Vector2(1, rect.size.y)), c)
		draw_rect(Rect2(Vector2(rect.end.x - 1, rect.position.y), Vector2(1, rect.size.y)), c)
	else:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), c)
		draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 1), Vector2(rect.size.x, 1)), c)
