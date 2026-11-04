# Dessine les murs (gris, liseré clair sur les bords exposés) et les cristaux (pics).
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


# Gabarits de grappes de cristaux, dessinés « vers le haut » dans une case
# de 16 px (socle en y = 16) : [centre x, demi-largeur, hauteur, penchant].
# Les plus hauts sont dessinés en dernier, donc devant.
const CLUSTERS := [
	[[4.0, 2.2, 6.0, -2.0], [12.5, 2.0, 5.0, 1.5], [8.0, 3.0, 10.0, 0.0]],
	[[14.5, 1.3, 3.5, 1.0], [11.0, 2.4, 7.0, 1.5], [5.5, 2.6, 9.0, -1.0]],
	[[3.0, 1.6, 4.0, -1.5], [11.5, 1.8, 5.5, 2.0], [8.0, 3.8, 9.0, 0.5]],
	[[3.5, 2.0, 6.0, -1.0], [12.5, 2.0, 7.0, 1.0], [8.0, 2.2, 8.5, 0.0]],
	[[2.5, 1.5, 4.0, -1.0], [12.0, 2.0, 6.0, 2.5], [7.0, 3.0, 10.0, 2.0]],
	[[6.0, 1.6, 5.0, -2.5], [13.0, 1.6, 4.5, 2.0], [9.5, 2.6, 8.0, -0.5], [4.0, 2.0, 7.5, -1.5]],
]
const LIGHT := Color(0.93, 0.93, 0.93)
const SHADE := Color(0.58, 0.58, 0.58)


func _draw_spikes(p: Vector2, kind: String) -> void:
	# Grappe de cristaux : gabarit et sens choisis d'après la case, pour que
	# deux cases voisines ne se ressemblent pas mais que rien ne bouge.
	var cell := Vector2i(p / TILE)
	var h := absi(cell.x * 73856093 ^ cell.y * 19349663 ^ kind.unicode_at(0) * 83492791)
	var shards: Array = CLUSTERS[h % CLUSTERS.size()]
	var flip := (h >> 4) & 1 == 1
	var rot := 0.0
	match kind:
		"v": rot = PI
		"<": rot = -PI / 2
		">": rot = PI / 2
	var center := p + Vector2(TILE, TILE) * 0.5
	draw_set_transform(center, rot, Vector2(-1 if flip else 1, 1))
	for sh in shards:
		_draw_shard(sh[0] - 8.0, sh[1], sh[2], sh[3])
	draw_set_transform(Vector2.ZERO)


func _draw_shard(x: float, w: float, h: float, lean: float) -> void:
	# Prisme pointu vu de face : une facette claire, une ombrée.
	var y := 8.0
	var shoulder := y - h * 0.4
	var tip := Vector2(x + lean, y - h)
	var bl := Vector2(x - w, y)
	var br := Vector2(x + w, y)
	var sl := Vector2(x - w + lean * 0.4, shoulder)
	var sr := Vector2(x + w + lean * 0.4, shoulder)
	var mid := Vector2(x + w * 0.2, y)
	var ridge := Vector2(x + w * 0.2 + lean * 0.4, shoulder)
	draw_colored_polygon(PackedVector2Array([bl, sl, tip, ridge, mid]), LIGHT)
	draw_colored_polygon(PackedVector2Array([mid, ridge, tip, sr, br]), SHADE)
