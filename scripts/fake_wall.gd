# Fausses parois ("%") : dessinées exactement comme les murs, avec leurs ombres, mais on passe au travers.
# Seul indice : quand le fantôme s'approche d'une sortie secrète, un mince faisceau de lumière
# traverse la paroi qui la cache. Quand le fantôme y entre, le pan entier s'efface doucement
# et laisse voir ce qu'il cachait. Une fois découvert, un pan reste à demi transparent.
extends Node2D

const TILE := 16
const RIM := 4.0
const BEAM_NEAR := 24.0  # faisceau à son plus vif
const BEAM_FAR := 88.0   # au-delà, rien ne se voit

var cells: Array = []    # Vector2i
var edges: Array = []    # [Vector2i, haut, bas, gauche, droite] comme tiles_drawer.gd
var ghosts: Array = []  # le fantôme, et son reflet en Miroir
var secrets: Array = []  # Vector2i des sorties secrètes ("e") cachées dans les parois
var beams: Array = []    # intensité du faisceau de chaque sortie secrète, 0 → 1
var wall := Color(0.32, 0.32, 0.32)
var rim := Color(0.95, 0.95, 0.95)
var groups: Array = []   # pans d'un seul tenant : listes d'indices dans cells
var group_of: Array = []
var shown: Array = []    # 1 → opaque, baisse quand le pan est découvert
var found: Array = []
var occluders: Array = []  # par pan
var t := 0.0
var revealed := false    # au moins un pan découvert (le son ne joue qu'une fois)

signal discovered


func _ready() -> void:
	beams.resize(secrets.size())
	beams.fill(0.0)
	# Bords exposés de chaque case, pour des ombres taillées comme celles des vrais murs
	var exposed := {}
	for e in edges:
		exposed[e[0]] = e
	var index := {}
	for i in cells.size():
		index[cells[i]] = i
	group_of.resize(cells.size())
	group_of.fill(-1)
	for i in cells.size():
		if group_of[i] >= 0:
			continue
		var g := groups.size()
		var members := []
		var todo := [i]
		group_of[i] = g
		while not todo.is_empty():
			var j: int = todo.pop_back()
			members.append(j)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var k: int = index.get(cells[j] + d, -1)
				if k >= 0 and group_of[k] < 0:
					group_of[k] = g
					todo.append(k)
		groups.append(members)
		shown.append(1.0)
		found.append(false)
		var occ_list := []
		for j in members:
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			var r := Rect2(Vector2(cells[j]) * TILE, Vector2(TILE, TILE))
			var e: Array = exposed.get(cells[j], [null, false, false, false, false])
			r = r.grow_individual(-RIM if e[3] else 0.0, -RIM if e[1] else 0.0, -RIM if e[4] else 0.0, -RIM if e[2] else 0.0)
			poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			occ.occluder = poly
			add_child(occ)
			occ_list.append(occ)
		occluders.append(occ_list)


func is_found(cell: Vector2i) -> bool:
	var i := cells.find(cell)
	return i >= 0 and not group_of.is_empty() and found[group_of[i]]


func _physics_process(_delta: float) -> void:
	for ghost in ghosts:
		if not ghost.dead:
			_reveal_around(Rect2(ghost.global_position - Vector2(5, 7), Vector2(10, 14)))


func _reveal_around(body: Rect2) -> void:
	for i in cells.size():
		var g: int = group_of[i]
		if found[g]:
			continue
		if Rect2(Vector2(cells[i]) * TILE, Vector2(TILE, TILE)).intersects(body):
			found[g] = true
			for occ in occluders[g]:
				occ.visible = false
			if not revealed:
				revealed = true
				discovered.emit()


func _process(delta: float) -> void:
	t += delta
	for g in groups.size():
		shown[g] = move_toward(shown[g], 0.3 if found[g] else 1.0, delta * 2.5)
	for k in secrets.size():
		var target := 0.0
		if not is_found(secrets[k]):
			var center := Vector2(secrets[k]) * TILE + Vector2(TILE, TILE) * 0.5
			for ghost in ghosts:
				if not ghost.dead:
					var d: float = ghost.global_position.distance_to(center)
					target = maxf(target, clampf(1.0 - (d - BEAM_NEAR) / (BEAM_FAR - BEAM_NEAR), 0.0, 1.0))
		beams[k] = move_toward(beams[k], target, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	for i in cells.size():
		var a: float = shown[group_of[i]]
		draw_rect(Rect2(Vector2(cells[i]) * TILE, Vector2(TILE, TILE)), Color(wall, a))
	for e in edges:
		var p: Vector2 = Vector2(e[0]) * TILE
		var c := Color(rim, shown[group_of[cells.find(e[0])]])
		if e[1]: draw_rect(Rect2(p, Vector2(TILE, 2)), c)
		if e[2]: draw_rect(Rect2(p + Vector2(0, TILE - 2), Vector2(TILE, 2)), c)
		if e[3]: draw_rect(Rect2(p, Vector2(2, TILE)), c)
		if e[4]: draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), c)
	for k in secrets.size():
		if beams[k] > 0.01:
			_draw_beam(secrets[k], beams[k])


# Un rai de lumière qui passe à travers la paroi, sur toute la hauteur du pan, dans l'axe de la sortie
func _draw_beam(secret: Vector2i, b: float) -> void:
	var g: int = group_of[cells.find(secret)]
	var x := secret.x * TILE + TILE * 0.5 + sin(t * 1.3) * 0.5
	var flicker := 0.85 + 0.15 * sin(t * 5.0) * sin(t * 2.3)
	for j in groups[g]:
		if cells[j].x != secret.x:
			continue
		var y := float(cells[j].y * TILE)
		draw_rect(Rect2(x - 3.0, y, 6.0, TILE), Color(1, 1, 1, 0.12 * b * flicker))
		draw_rect(Rect2(x - 1.5, y, 3.0, TILE), Color(1, 1, 1, 0.22 * b * flicker))
		draw_rect(Rect2(x - 0.5, y, 1.0, TILE), Color(1, 1, 1, 0.6 * b * flicker))
	# Quelques poussières prises dans le rai
	for i in range(3):
		var k := fmod(t * 0.4 + i * 0.33, 1.0)
		var top := float(secret.y * TILE + TILE) - k * TILE * 2.0
		if cells.has(Vector2i(secret.x, floori(top / TILE))):
			draw_rect(Rect2(x + sin(t * 2.0 + i * 2.1) * 1.5 - 0.5, top, 1, 1), Color(1, 1, 1, b * (1.0 - k) * 0.8))
