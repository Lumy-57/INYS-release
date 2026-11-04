# Rail discret qui montre la course d'une plateforme mobile : un point par case de sa course.
extends Node2D

var points: Array = []   # Vector2, en pixels


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _draw() -> void:
	for p in points:
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.25))
