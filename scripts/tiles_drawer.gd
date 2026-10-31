# Dessine les murs (gris, liseré clair sur les bords exposés) et les pics.
# Les murs taillés (r roche, t pierre taillée, g givre) arrondissent ou biseautent leurs coins
# saillants et portent un relief discret, dans les mêmes gris que les murs.
extends Node2D

const TILE := 16
const RIM_W := 2.0

var solids: Array = []   # Array de Vector2i
var edges: Array = []    # [Vector2i, haut, bas, gauche, droite] exposés
var shaped: Array = []   # [Vector2i, caractère, haut, bas, gauche, droite] exposés
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
