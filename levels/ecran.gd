# Un écran de caméra du mode Ascension, posé à la main dans la scène du niveau (de préférence
# sous un nœud « Écrans »). Son coin en haut à gauche se cale sur la grille ; « Size » donne sa
# taille en cases. Dans le jeu, la caméra montre l'écran où se trouve le fantôme, zoomée pour
# qu'il tienne en entier dans la fenêtre (480 × 270). Si l'écran n'a pas les proportions de la
# fenêtre, on voit un peu plus que lui sur les côtés ou en haut et en bas (cadre pâle).
# Les écrans peuvent se chevaucher : on reste sur l'écran actuel tant que le fantôme y est.
# Sans aucun écran posé, le niveau est découpé tout seul (réglage « Screen Zoom » du niveau).
@tool
class_name CameraScreen
extends Node2D

const TILE := 16
const VIEW := Vector2(480, 270)

## Taille de l'écran en cases (30 × 17 : un écran sans zoom ; 38 × 21 : zoom 0,8)
@export var size := Vector2i(38, 21):
	set(v):
		size = v.max(Vector2i.ONE)
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		var on_grid := (position / TILE).round() * TILE
		if on_grid != position:
			position = on_grid
		queue_redraw()


func rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * TILE)


# Zoom de la caméra pour que l'écran tienne en entier dans la fenêtre
static func zoom_for(r: Rect2) -> float:
	return minf(VIEW.x / r.size.x, VIEW.y / r.size.y)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := rect()
	var ink := Color(0.4, 0.9, 1.0, 0.8)
	# Ce que la fenêtre montre vraiment autour de l'écran
	var shown := VIEW / zoom_for(r)
	draw_rect(Rect2(r.get_center() - shown * 0.5, shown), Color(ink, 0.25), false, 1.0)
	draw_rect(r, ink, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(6, 18), "%s  (zoom %.2f)" % [name, zoom_for(r)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
