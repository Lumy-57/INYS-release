# Bloc de carillon : chaque cloche (tuile B) qu'on touche inverse tous les blocs de carillon du
# niveau. L'état est mémorisé à chaque bougie.
@tool
extends LevelElement

## Taille du bloc, en cases
@export var size := Vector2i(3, 1)
## Solide au repos (avant la première cloche), ou solide une fois les cloches sonnées
@export_enum("Solide au repos", "Solide une fois sonné") var etat := 0


func element_data() -> Dictionary:
	return {"type": "chime", "size": size, "kind": "ab"[etat]}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	if etat == 0:
		draw_rect(r, Color(0.7, 0.7, 0.7))
		draw_rect(r, Color(0.95, 0.95, 0.95), false, 1.0)
	else:
		draw_rect(r, Color(0.7, 0.7, 0.7, 0.15))
		_dotted(r, INK)
	# Une petite cloche par case
	var ink := Color(0.2, 0.2, 0.2) if etat == 0 else INK
	for y in size.y:
		for x in size.x:
			var c := Vector2(x, y) * TILE + Vector2(8, 8)
			draw_arc(c + Vector2(0, 1), 3.5, PI, TAU, 8, ink, 1.0)
			draw_line(c + Vector2(-4, 2), c + Vector2(4, 2), ink, 1.0)
	_note(Vector2(2, -3), "au repos" if etat == 0 else "sonné")
