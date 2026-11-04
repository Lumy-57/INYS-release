# Ressort : posé sur le sol (dans la case juste au-dessus), il propulse le fantôme vers le haut
# et lui rend son dash.
@tool
extends LevelElement

## Vitesse de la propulsion, en px/s (430 = normal)
@export_range(100.0, 1000.0, 10.0) var force := 430.0


func element_data() -> Dictionary:
	return {"type": "spring", "force": force}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(1, 14, 14, 2), Color(0.5, 0.5, 0.5))
	var y := 14.0
	var i := 0
	while y > 11.0:
		var x := 5.0 if i % 2 == 0 else -5.0
		draw_line(Vector2(8 - x, y), Vector2(8 + x, y - 1.5), Color(0.75, 0.75, 0.75), 1.0)
		y -= 1.5
		i += 1
	draw_rect(Rect2(1, 8, 14, 2), Color.WHITE)
	# La hauteur atteinte, à peu près (sans tenir la touche de saut)
	var h := force * force / (2.0 * 950.0)
	draw_line(Vector2(8, 8), Vector2(8, 8 - h), SOFT, 1.0)
	_note(Vector2(10, 8 - h + 3), "%d" % int(force))
