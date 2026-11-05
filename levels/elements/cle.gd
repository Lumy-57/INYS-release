# Clé : le fantôme la ramasse en passant, elle le suit, et ouvre la première porte de même
# numéro qu'il touche. S'il meurt avant, elle retourne à sa place.
@tool
extends LevelElement

## Numéro de la clé : elle ouvre les portes qui portent le même numéro
@export_range(1, 4) var numero := 1


func element_data() -> Dictionary:
	return {"type": "key", "link": numero}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_arc(Vector2(5, 8), 3.0, 0.0, TAU, 12, Color.WHITE, 1.5)
	draw_rect(Rect2(8, 7.5, 6, 1.5), Color.WHITE)
	draw_rect(Rect2(11, 9, 1.5, 2), Color.WHITE)
	draw_rect(Rect2(13, 9, 1.5, 3), Color.WHITE)
	_note(Vector2(2, -2), "clé %d" % numero)
