# Zéro gravité : dedans, le fantôme ne tombe plus et flotte sur son élan, qui s'éteint doucement.
# Son dash peut s'y recharger dès qu'il est fini, même en l'air.
@tool
extends LevelElement

## Taille de la zone, en cases
@export var size := Vector2i(4, 4)
## Freinage de l'élan vertical, en px/s² (200 = normal ; 0 = il ne s'éteint jamais)
@export_range(0.0, 1000.0, 10.0) var freinage := 200.0
## Le dash se recharge dès qu'il est fini, même en l'air
@export var recharge_dash := true


func element_data() -> Dictionary:
	return {"type": "zero_g", "size": size, "drag": freinage, "refill": recharge_dash}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	draw_rect(r, Color(1, 1, 1, 0.05))
	_dotted(r, INK)
	_note(Vector2(2, -3), "zéro gravité" + (" · dash" if recharge_dash else ""))
