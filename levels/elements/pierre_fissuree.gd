# Pierre fissurée : elle tremble dès que le fantôme la touche, s'effondre, puis revient.
@tool
extends LevelElement

## Taille de la pierre, en cases
@export var size := Vector2i(2, 1)
## Secondes de tremblement avant qu'elle tombe (0,45 = normal)
@export_range(0.05, 3.0, 0.05) var tremble := 0.45
## Secondes avant qu'elle revienne (2 = normal)
@export_range(0.2, 10.0, 0.1) var retour := 2.0


func element_data() -> Dictionary:
	return {"type": "crumble", "size": size, "shake": tremble, "gone": retour}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	draw_rect(r, Color(0.45, 0.45, 0.45))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.95, 0.95, 0.95))
	for y in size.y:
		for x in size.x:
			var o := Vector2(x, y) * TILE
			var crack := Color(0.15, 0.15, 0.15)
			draw_line(o + Vector2(5, 2), o + Vector2(8, 8), crack, 1.0)
			draw_line(o + Vector2(8, 8), o + Vector2(6, 16), crack, 1.0)
			draw_line(o + Vector2(8, 8), o + Vector2(12, 11), crack, 1.0)
	_note(Vector2(2, -3), "%ss · %ss" % [snappedf(tremble, 0.05), snappedf(retour, 0.1)])
