# Porte : un bloc plein que seule une clé de même numéro ouvre. Une fois ouverte, elle le
# reste jusqu'à la fin du niveau, même si le fantôme meurt ensuite.
@tool
extends LevelElement

## Taille de la porte, en cases
@export var size := Vector2i(1, 3)
## Numéro de la porte : la clé du même numéro l'ouvre
@export_range(1, 4) var numero := 1


func element_data() -> Dictionary:
	return {"type": "door", "size": size, "link": numero}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	draw_rect(r, Color(0.35, 0.35, 0.35))
	draw_rect(r, Color.WHITE, false, 1.0)
	var c := r.get_center()
	draw_circle(c + Vector2(0, -1.5), 1.5, Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(c.x - 0.75, c.y - 1, 1.5, 4), Color(0.08, 0.08, 0.08))
	_note(Vector2(2, -2), "porte %d" % numero)
