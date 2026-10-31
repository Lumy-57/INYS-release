# Dessine les murs (gris, liseré clair sur les bords exposés) et les pics.
extends Node2D

const TILE := 16

var solids: Array = []   # Array de Vector2i
var edges: Array = []    # [Vector2i, haut, bas, gauche, droite] exposés
var spikes: Array = []   # [Vector2i, char]
var wall := Color(0.32, 0.32, 0.32)  # teintés dans l'épilogue (palette.gd)
var rim := Color(0.95, 0.95, 0.95)


func _draw() -> void:
	for c in solids:
		draw_rect(Rect2(c * TILE, Vector2(TILE, TILE)), wall)
	for e in edges:
		var p: Vector2 = Vector2(e[0]) * TILE
		if e[1]: draw_rect(Rect2(p, Vector2(TILE, 2)), rim)
		if e[2]: draw_rect(Rect2(p + Vector2(0, TILE - 2), Vector2(TILE, 2)), rim)
		if e[3]: draw_rect(Rect2(p, Vector2(2, TILE)), rim)
		if e[4]: draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), rim)
	for s in spikes:
		_draw_spikes(Vector2(s[0]) * TILE, s[1])


func _draw_spikes(p: Vector2, kind: String) -> void:
	# Deux dents par tuile
	for i in range(2):
		var o := i * 8.0
		var tri: PackedVector2Array
		match kind:
			"^": tri = [p + Vector2(o, 16), p + Vector2(o + 4, 7), p + Vector2(o + 8, 16)]
			"v": tri = [p + Vector2(o, 0), p + Vector2(o + 8, 0), p + Vector2(o + 4, 9)]
			"<": tri = [p + Vector2(16, o), p + Vector2(16, o + 8), p + Vector2(7, o + 4)]
			_: tri = [p + Vector2(0, o), p + Vector2(9, o + 4), p + Vector2(0, o + 8)]
		draw_colored_polygon(tri, Color(0.9, 0.9, 0.9))
