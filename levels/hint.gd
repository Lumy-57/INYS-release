# Un indice dit par l'orbe quand le fantôme approche. Sa case est celle où le nœud est posé.
# {jump}, {dash}, {left}, {right} sont remplacés par les touches choisies par le joueur.
@tool
extends Node2D

const TILE := 16

@export_multiline var text := "":
	set(v):
		text = v
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


# Seulement dans l'éditeur : la case de l'indice et son texte
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var cell := (position / TILE).floor() * TILE - position
	draw_rect(Rect2(cell, Vector2(TILE, TILE)), Color(1, 1, 1, 0.5), false, 1.0)
	draw_circle(cell + Vector2(8, 8), 3.0, Color(1, 1, 1, 0.9))
	var font := ThemeDB.fallback_font
	draw_string(font, cell + Vector2(TILE + 2, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 0.8))
