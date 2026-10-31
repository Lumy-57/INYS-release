# Rail discret qui montre la course d'une plateforme mobile.
extends Node2D

var cells: Array = []


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _draw() -> void:
	for c in cells:
		var center := Vector2(c) * 16.0 + Vector2(8, 8)
		draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.25))
