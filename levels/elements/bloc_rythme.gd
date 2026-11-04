# Bloc rythmé, sur le métronome commun à tout le niveau (un cycle de 2,4 s, que la musique suit) :
# solide pendant la première moitié du cycle, ou pendant la seconde. Il clignote juste avant de
# disparaître.
@tool
extends LevelElement

## Taille du bloc, en cases
@export var size := Vector2i(3, 1)
## Premier temps : solide pendant la première moitié du cycle. Second temps : pendant la seconde.
@export_enum("Premier temps", "Second temps") var temps := 0


func element_data() -> Dictionary:
	return {"type": "timed", "size": size, "phase": temps}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	var light := temps == 0
	draw_rect(r, Color(0.75, 0.75, 0.75) if light else Color(0.4, 0.4, 0.4))
	draw_rect(r, Color(0.95, 0.95, 0.95), false, 1.0)
	var ink := Color(0.3, 0.3, 0.3) if light else Color(0.85, 0.85, 0.85)
	for y in size.y:
		for x in size.x:
			var c := Vector2(x, y) * TILE + Vector2(8, 8)
			draw_arc(c, 4.0, 0.0, TAU, 12, ink, 1.0)
			draw_line(c, c + (Vector2.UP if light else Vector2.DOWN) * 3.0, ink, 1.0)
	_note(Vector2(2, -3), "1er temps" if light else "2e temps")
