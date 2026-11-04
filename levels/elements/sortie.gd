# Sortie : la faille de lumière qui finit le niveau, comme la tuile E, mais réglable. Debout, elle
# se pose sur le sol (dans la case juste au-dessus) et on y entre par le côté ; couchée, elle
# s'étend à l'horizontale sur « Largeur » cases, par exemple dans un trou du plafond pour une
# sortie vers le haut (ou dans le sol, pour une sortie vers le bas).
@tool
extends LevelElement

## Debout (on y entre par le côté) ou couchée (on y entre par en haut ou par en bas)
@export_enum("Debout", "Couchée") var orientation := 1
## Largeur de la sortie couchée, en cases (elle part de la case du nœud vers la droite)
@export_range(1, 8, 1) var largeur := 2


func element_data() -> Dictionary:
	return {"type": "exit", "flat": orientation == 1, "width": largeur}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if orientation == 1:
		var w := largeur * TILE
		draw_rect(Rect2(1, 4, w - 2, 8), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(1, 7, w - 2, 2), Color.WHITE)
		_note(Vector2(2, -3), "sortie")
	else:
		draw_rect(Rect2(4, -14, 8, 30), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(7, -14, 2, 30), Color.WHITE)
		_note(Vector2(2, -17), "sortie")
