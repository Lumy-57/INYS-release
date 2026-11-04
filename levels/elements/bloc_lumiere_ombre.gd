# Bloc de lumière ou d'ombre. Lumière : solide seulement quand le fantôme brille (dash disponible).
# Ombre : solide seulement quand il est éteint (dash utilisé). Un bloc qui devrait réapparaître
# sur le fantôme attend qu'il en sorte.
@tool
extends LevelElement

## Taille du bloc, en cases
@export var size := Vector2i(3, 1)
## Lumière : solide quand le fantôme brille. Ombre : solide quand il est éteint.
@export_enum("Lumière", "Ombre") var mode := 0


func element_data() -> Dictionary:
	return {"type": "phase", "size": size, "kind": "LO"[mode]}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	if mode == 0:
		draw_rect(r, Color(0.8, 0.8, 0.8))
		draw_rect(r.grow(-3), Color(0.55, 0.55, 0.55))
	else:
		draw_rect(r, Color(0.12, 0.12, 0.12))
		var hatch := Color(0.7, 0.7, 0.7)
		for y in size.y:
			for x in size.x:
				var o := Vector2(x, y) * TILE
				draw_line(o + Vector2(0, 16), o + Vector2(16, 0), hatch, 1.0)
				draw_line(o + Vector2(0, 8), o + Vector2(8, 0), hatch, 1.0)
				draw_line(o + Vector2(8, 16), o + Vector2(16, 8), hatch, 1.0)
		draw_rect(r, Color(0.85, 0.85, 0.85), false, 1.0)
