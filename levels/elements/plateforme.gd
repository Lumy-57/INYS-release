# Plateforme mobile : elle fait l'aller-retour entre deux bouts, A (là où le nœud est posé) et B
# (A + « Course »), en ligne droite : à l'horizontale, à la verticale ou en diagonale. Le rail
# qui montre sa course est dessiné tout seul.
@tool
extends LevelElement

## Taille de la plateforme, en cases
@export var size := Vector2i(3, 1)
## Le bout B, en cases depuis le bout A : (6, 0) = 6 cases à droite, (0, -4) = 4 cases plus haut
@export var course := Vector2i(6, 0)
## Vitesse, en px/s (60 = normal ; une case = 16 px)
@export_range(5.0, 400.0, 5.0) var vitesse := 60.0
## Secondes d'arrêt à chaque bout (0,4 = normal)
@export_range(0.0, 5.0, 0.05) var pause := 0.4
## Où elle se trouve au lancement : 0 = au bout A, 1 = au bout B. Elle part vers B (vers A si elle
## commence en B).
@export_range(0.0, 1.0, 0.01) var depart := 0.0


func element_data() -> Dictionary:
	return {"type": "mover", "size": size, "course": course, "speed": vitesse, "pause": pause, "start": depart}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	var b := Vector2(course) * TILE
	# La course, le bout B en pointillé, puis la plateforme là où elle part
	draw_line(r.get_center(), r.get_center() + b, SOFT, 1.0)
	_dotted(Rect2(b, r.size), INK)
	draw_rect(r, Color(0.75, 0.75, 0.75, 0.6))
	var start := Rect2(b * depart, r.size)
	draw_rect(start, Color(0.75, 0.75, 0.75))
	draw_rect(Rect2(start.position + Vector2(2, 3), start.size - Vector2(4, 5)), Color(0.3, 0.3, 0.3))
	_note(Vector2(2, -3), "A")
	_note(b + Vector2(2, -3), "B · %d px/s" % int(vitesse))
