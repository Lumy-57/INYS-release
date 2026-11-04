# Vent : une zone qui pousse le fantôme tant qu'il est dedans. Vers le haut, il le soulève ;
# vers le bas, il le plaque plus vite qu'une chute ; de côté, il l'emporte au sol comme en l'air.
# Le dash passe à travers sans être dévié.
@tool
extends LevelElement

const DIRS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

## Taille de la zone, en cases
@export var size := Vector2i(2, 4)
## Sens du vent
@export_enum("Haut", "Bas", "Gauche", "Droite") var direction := 0
## Force du vent : 1 = normal (vers le haut, il monte à 170 px/s ; vers le bas, 300 px/s ;
## de côté, il ajoute 110 px/s). 2 = deux fois plus fort, 0,5 = moitié moins.
@export_range(0.1, 3.0, 0.05) var force := 1.0


func element_data() -> Dictionary:
	return {"type": "vent", "size": size, "dir": direction, "force": force}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	draw_rect(r, Color(0.7, 0.85, 1.0, 0.08))
	_dotted(r, SOFT)
	var flow: Vector2 = DIRS[direction]
	# Une flèche par case, plus longue quand le vent est fort
	var arrow_len := clampf(4.0 + 4.0 * force, 5.0, 14.0)
	for y in size.y:
		for x in size.x:
			var c := Vector2(x, y) * TILE + Vector2(8, 8)
			_arrow(c - flow * arrow_len * 0.5, c + flow * arrow_len * 0.5, INK)
	_note(Vector2(2, -3), "vent ×%s" % snappedf(force, 0.05))
