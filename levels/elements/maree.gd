# Marée de ténèbres : elle part de la rangée où l'élément est posé et monte dès que le fantôme
# bouge, sur toute la largeur de la salle. Y plonger, c'est mourir. Trop loin derrière le
# fantôme, elle accélère pour revenir à portée. Après une mort, elle repart sous la bougie.
@tool
extends LevelElement

## Vitesse de montée, en px/s (26 = normal ; une case = 16 px)
@export_range(1.0, 200.0, 1.0) var vitesse := 26.0
## Écart sous le fantôme au-delà duquel elle accélère, en px (150 = normal)
@export_range(16.0, 600.0, 2.0) var portee := 150.0
## Accélération quand elle est trop loin : px/s de plus par pixel d'écart en trop (1,6 = normal)
@export_range(0.0, 10.0, 0.1) var rattrapage := 1.6
## Après une mort, elle repart à cet écart sous la bougie, en px (96 = normal)
@export_range(0.0, 400.0, 2.0) var sous_bougie := 96.0


func element_data() -> Dictionary:
	return {"type": "tide", "speed": vitesse, "reach": portee, "catch_up": rattrapage, "below": sous_bougie}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Sa ligne de départ, et une flèche vers le haut
	var pts := PackedVector2Array()
	var x := -48.0
	while x <= 64.0:
		pts.append(Vector2(x, sin(x * 0.2) * 2.0))
		x += 4.0
	draw_polyline(pts, INK, 1.0)
	draw_rect(Rect2(-48, 3, 112, 8), Color(0, 0, 0, 0.6))
	_arrow(Vector2(8, 0), Vector2(8, -18), INK)
	_note(Vector2(14, -8), "marée · %d px/s" % int(vitesse))
