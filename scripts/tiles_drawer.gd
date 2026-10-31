# Dessine les murs (gris, liseré clair sur les bords exposés) et les cristaux (pics).
# Les murs taillés (r roche, t pierre taillée, g givre) arrondissent ou biseautent leurs coins
# saillants et portent un relief discret, dans les mêmes gris que les murs.
# Les pentes (scripts/slopes.gd) sont pleines, avec un liseré le long de leur biais.
extends Node2D

const Slopes = preload("res://scripts/slopes.gd")
const TILE := 16
const RIM_W := 2.0

var solids: Array = []   # Array de Vector2i
var edges: Array = []    # [Vector2i, haut, bas, gauche, droite] exposés
var shaped: Array = []   # [Vector2i, caractère, haut, bas, gauche, droite] exposés
var slopes: Array = []   # [Vector2i, caractère]
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
	for t in shaped:
		_draw_shaped(t)
	for sl in slopes:
		_draw_slope(sl[0], sl[1])
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


# Un mur taillé : liseré en forme, puis le mur en retrait du liseré, puis son relief
func _draw_shaped(t: Array) -> void:
	var cell: Vector2i = t[0]
	var kind: String = t[1]
	var up: bool = t[2]
	var down: bool = t[3]
	var left: bool = t[4]
	var right: bool = t[5]
	var r := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	var radius := 4.0 if kind == "t" else 5.0
	# Coins saillants : haut-gauche, haut-droite, bas-droite, bas-gauche
	var corners := [up and left, up and right, down and right, down and left]
	var bevel := kind == "t"
	if up or down or left or right:
		draw_colored_polygon(_shape(r, corners, radius, bevel), rim)
		var inner := r.grow_individual(-RIM_W if left else 0.0, -RIM_W if up else 0.0,
			-RIM_W if right else 0.0, -RIM_W if down else 0.0)
		draw_colored_polygon(_shape(inner, corners, radius - (1.2 if bevel else RIM_W), bevel), wall)
	else:
		draw_rect(r, wall)
	var h := hash(cell)
	var dark := wall.darkened(0.22)
	var light := wall.lightened(0.1)
	match kind:
		"r":  # roche : quelques grains et, parfois, une fêlure
			for i in 3:
				var g := (h >> (i * 8)) & 0xff
				var px := 4 + (g & 7)
				var py := 4 + ((g >> 3) & 7)
				draw_rect(Rect2(r.position + Vector2(px, py), Vector2(2 if (g & 1) == 1 else 1, 1)), dark)
			if ((h >> 24) & 3) == 0:
				var a := r.position + Vector2(5, 6)
				draw_polyline(PackedVector2Array([a, a + Vector2(3, 2), a + Vector2(4, 5), a + Vector2(7, 6)]), dark, 1.0)
			if up:
				draw_rect(Rect2(r.position + Vector2(5 + (h & 3), 3), Vector2(3, 1)), light)
		"t":  # pierre taillée : des assises de 8 px, joints décalés d'une rangée à l'autre
			var top := r.position.y + (RIM_W if up else 0.0)
			var bottom := r.end.y - (RIM_W if down else 0.0)
			var x0 := r.position.x + (RIM_W + 1.0 if left else 0.0)
			var x1 := r.end.x - (RIM_W + 1.0 if right else 0.0)
			var mid := r.position.y + 8.0
			draw_line(Vector2(x0, mid), Vector2(x1, mid), dark, 1.0)
			# Joints verticaux, décalés d'une assise à l'autre ; au bord de la case, le joint est
			# partagé avec le voisin, et n'existe pas sur une face exposée
			var seams := [8.0, 0.0] if posmod(cell.y, 2) == 0 else [0.0, 8.0]
			for k in 2:
				var sx: float = seams[k]
				if sx == 0.0 and left:
					continue
				var y0 := top if k == 0 else mid + 1.0
				var y1 := mid if k == 0 else bottom
				draw_line(Vector2(r.position.x + sx + 0.5, y0), Vector2(r.position.x + sx + 0.5, y1), dark, 1.0)
		"g":  # givre : une couche de neige sur le dessus, qui coule en gouttes
			if up:
				var x0 := 2.0 if left else 0.0
				var x1 := TILE - (2.0 if right else 0.0)
				draw_rect(Rect2(r.position + Vector2(x0, RIM_W), Vector2(x1 - x0, 1)), rim)
				for i in 4:
					var drop := 1 + ((h >> (i * 3)) & 3)
					if drop < 2:
						continue
					var x := r.position.x + 2.0 + i * 4.0 + float((h >> (12 + i)) & 1)
					if (left and x < r.position.x + 4.0) or (right and x > r.end.x - 5.0):
						continue
					draw_rect(Rect2(Vector2(x, r.position.y + RIM_W + 1.0), Vector2(2, drop)), rim)
					draw_rect(Rect2(Vector2(x + 0.5, r.position.y + RIM_W + 1.0 + drop), Vector2(1, 1)), rim)
			else:
				for i in 2:
					var g := (h >> (i * 10)) & 0xff
					draw_rect(Rect2(r.position + Vector2(4 + (g & 7), 4 + ((g >> 3) & 7)), Vector2(1, 1)), light)


# Rectangle aux coins saillants arrondis (ou biseautés)
func _shape(r: Rect2, corners: Array, radius: float, bevel: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centers := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var inward := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		var c: Vector2 = centers[i]
		if not corners[i] or radius <= 0.0:
			pts.append(c)
			continue
		var o: Vector2 = c + inward[i] * radius
		var start := PI + i * PI * 0.5  # haut-gauche : de 180° à 270°
		var steps := 1 if bevel else 4
		for k in steps + 1:
			var a := start + PI * 0.5 * k / steps
			pts.append(o + Vector2(cos(a), sin(a)) * radius)
	return pts


# Une pente : pleine, et un liseré de la largeur de celui des murs le long du biais
func _draw_slope(cell: Vector2i, c: String) -> void:
	var o := Vector2(cell) * TILE
	var poly := Slopes.shape(c, o)
	draw_colored_polygon(poly, wall)
	var center := Vector2.ZERO
	for p in poly:
		center += p
	center /= poly.size()
	for e in Slopes.slants(c, o):
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := (b - a).orthogonal().normalized()
		if n.dot(center - a) < 0.0:
			n = -n
		var band := PackedVector2Array([a, b, b + n * RIM_W, a + n * RIM_W])
		for piece in Geometry2D.intersect_polygons(band, poly):
			draw_colored_polygon(piece, rim)
