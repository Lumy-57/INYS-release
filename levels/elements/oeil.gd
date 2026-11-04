# Œil qui regarde : il s'ouvre et se ferme sur un cycle commun à tout le niveau (3,9 s, que la
# musique suit). Ouvert, son regard balaie la salle jusqu'aux murs ; y rester trop longtemps tue.
@tool
extends LevelElement

## Moment où il s'ouvre dans le cycle : 0 = en même temps que les autres yeux à 0, 0,5 = une
## demi-période plus tard (l'ancien « y »)
@export_range(0.0, 1.0, 0.05) var decalage := 0.0
## Portée du regard, en px (150 = normal ; un écran fait 480 × 270)
@export_range(16.0, 600.0, 2.0) var portee := 150.0


func element_data() -> Dictionary:
	return {"type": "eye", "offset": decalage, "range": portee}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Vector2(8, 8)
	draw_arc(c, portee, 0.0, TAU, 64, Color(1, 1, 1, 0.15), 1.0)
	draw_circle(c, 7.0, Color(0.06, 0.06, 0.06))
	draw_arc(c, 6.0, PI * 1.15, PI * 1.85, 8, INK, 1.0)
	draw_arc(c, 6.0, PI * 0.15, PI * 0.85, 8, INK, 1.0)
	draw_circle(c, 2.0, INK)
	_note(Vector2(16, 6), "décalage %s" % snappedf(decalage, 0.05))
