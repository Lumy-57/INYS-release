# Ombres poursuivantes : elles refont exactement le chemin du fantôme, chacune avec son retard.
# Elles partent du point d'apparition du fantôme (l'endroit où l'élément est posé ne compte pas).
# Les toucher, c'est mourir ; s'arrêter trop longtemps, c'est les laisser vous rattraper.
@tool
extends LevelElement

## Nombre d'ombres
@export_range(1, 8) var nombre := 1
## Retard de la première ombre sur le fantôme, en secondes (1,1 = normal)
@export_range(0.2, 6.0, 0.05) var retard := 1.1
## Retard en plus de chaque ombre sur la précédente, en secondes
@export_range(0.1, 6.0, 0.05) var ecart := 0.6
## Vitesse : 1 = au même pas que le fantôme. Plus vite, elles le rattrapent peu à peu ; moins
## vite, elles se laissent distancer.
@export_range(0.25, 2.0, 0.05) var vitesse := 1.0
## Compagne (épilogue) : elle marche avec le fantôme sans le toucher, et n'est plus toute noire
@export var compagne := false


func element_data() -> Dictionary:
	return {"type": "chaser", "count": nombre, "delay": retard, "gap": ecart, "speed": vitesse, "companion": compagne}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for i in nombre:
		var c := Vector2(8 - i * 10, 8)
		var tint := Color(0.22, 0.17, 0.3) if compagne else Color(0.03, 0.03, 0.03)
		draw_circle(c, 6.5, Color(0.85, 0.85, 0.85, 0.8))
		draw_circle(c, 5.5, tint)
		draw_rect(Rect2(c + Vector2(-3, -2), Vector2(2, 3)), Color.WHITE)
		draw_rect(Rect2(c + Vector2(1, -2), Vector2(2, 3)), Color.WHITE)
	var what := "compagne" if compagne else "%d ombre%s" % [nombre, "s" if nombre > 1 else ""]
	_note(Vector2(18, 6), "%s · %ss · ×%s" % [what, snappedf(retard, 0.05), snappedf(vitesse, 0.05)])
