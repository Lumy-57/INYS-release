# Chapitre Miroir : les vitres ("=") qui séparent le fantôme de son reflet.
# Solides comme des murs, mais elles laissent passer la lumière : chacun éclaire l'autre côté.
extends Node2D

var cells: Array = []     # Vector2i des vitres
var t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	for c in cells:
		var r := Rect2(Vector2(c) * 16.0, Vector2(16, 16))
		draw_rect(r, Color(0.16, 0.16, 0.16))
		draw_rect(Rect2(r.position.x + 7, r.position.y, 2, 16), Color(0.55, 0.55, 0.55))
		# Un reflet qui glisse lentement le long de la vitre
		var y := fmod(c.y * 16.0 - t * 40.0, 320.0)
		if y < 0.0:
			y += 320.0
		var k := clampf(1.0 - absf(y - 160.0) / 160.0, 0.0, 1.0)
		draw_line(r.position + Vector2(3, 13), r.position + Vector2(13, 3), Color(1, 1, 1, 0.08 + 0.3 * k), 1.0)
