# Décor de fond propre à chaque chapitre : silhouettes en deux plans de parallaxe
# derrière le niveau, et une petite ambiance de particules. Purement visuel :
# aucune collision, rien n'occulte la lumière.
extends Node2D

const Palette = preload("res://scripts/palette.gd")

const VIEW := Vector2(480, 270)
const FAR := 0.7    # part du mouvement de la caméra suivie par le plan lointain
const NEAR := 0.4   # idem pour le plan proche

var chapter := ""
var colors := 0.0  # épilogue : force des couleurs (palette.gd)
var room := Vector2.ZERO
var t := 0.0
var far: Node2D
var near: Node2D
var rng := RandomNumberGenerator.new()
# Formes tirées une fois pour que le décor reste le même à chaque mort
var shapes_far: Array = []
var shapes_near: Array = []
var drip_players: Array = []


func setup(chapter_name: String, room_size: Vector2, color_strength := 0.0) -> void:
	chapter = chapter_name
	colors = color_strength
	room = room_size
	z_index = -10
	rng.seed = hash(chapter) ^ hash(room)
	far = _layer(_draw_far)
	near = _layer(_draw_near)
	match chapter:
		"Le Seuil": _seuil()
		"Lumière et ombre": _lumiere()
		"Profondeurs": _profondeurs()
		"Clocher": _clocher()
		"Carillon": _carillon()
		"Poursuite": _poursuite()
		"Horloge": _horloge()
		"Dernière lueur": _lueur()
		"Regards": _regards()
		"Miroir": _miroir()
		"Compagnie": _compagnie()
		"Le matin": _matin()
		_: _seuil()
	_particles()
	if shapes_near.any(func(sh): return sh["kind"] == "drip"):
		for i in 3:
			var pl := AudioStreamPlayer.new()
			pl.bus = "SFX"
			pl.stream = _plip_stream()
			add_child(pl)
			drip_players.append(pl)


func _layer(fn: Callable) -> Node2D:
	var n := Node2D.new()
	var mat := CanvasItemMaterial.new()
	# Le fond se devine même hors de la lumière du fantôme
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	n.material = mat
	n.draw.connect(fn.bind(n))
	add_child(n)
	return n


func _process(delta: float) -> void:
	var before := t
	t += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		var off := cam.get_screen_center_position() - room * 0.5
		far.position = off * FAR
		near.position = off * NEAR
		if not drip_players.is_empty():
			_drip_sounds(before, cam.get_screen_center_position())
	far.queue_redraw()
	near.queue_redraw()


# Zone à couvrir dans le repère d'un plan, marge comprise
func _span() -> Rect2:
	return Rect2(-VIEW * 0.5, room + VIEW)


# --- Chapitres -------------------------------------------------------------

# Le Seuil : l'entrée d'une grotte sous la tour. Une voûte de roche, l'ouverture
# au loin d'où vient un peu de jour, de la mousse qui pend, et quelques gouttes
# qui perlent une à une au bout des concrétions, tombent et font des ronds.
# (Profondeurs, plus loin, est une grotte bien plus dense et sans jour.)
func _seuil() -> void:
	var s := _span()
	# Ouvertures sur le dehors, dans la paroi du fond
	var x := s.position.x + rng.randf_range(60, 160)
	while x < s.end.x:
		var w := rng.randf_range(70, 110)
		var h := w * rng.randf_range(0.8, 1.1)
		var base := room.y * rng.randf_range(0.55, 0.7)
		var pts := PackedVector2Array()
		for j in 14:
			var a := PI + PI * j / 13.0
			pts.append(Vector2(x + cos(a) * w * 0.5 * rng.randf_range(0.85, 1.05), base + sin(a) * h * rng.randf_range(0.85, 1.05)))
		pts.append(Vector2(x + w * 0.55, base + 8.0))
		pts.append(Vector2(x - w * 0.55, base + 8.0))
		shapes_far.append({"kind": "mouth", "pts": pts, "c": Vector2(x, base - h * 0.4), "w": w, "h": h, "base": base, "ph": rng.randf() * TAU})
		x += rng.randf_range(360, 520)
	# La voûte et le sol de la grotte, d'un seul tenant, déchiquetés
	var vault_top := PackedVector2Array([Vector2(s.position.x, s.position.y)])
	var floor_pts := PackedVector2Array([Vector2(s.position.x, s.end.y)])
	x = s.position.x
	while x <= s.end.x + 16.0:
		var y := 18.0 + rng.randf_range(-10, 14)
		if rng.randf() < 0.18:
			# Une grosse concrétion qui descend de la voûte
			var w := rng.randf_range(10, 20)
			vault_top.append(Vector2(x, y))
			vault_top.append(Vector2(x + w * 0.5, y + rng.randf_range(24, 56)))
			vault_top.append(Vector2(x + w, y))
			x += w
		else:
			vault_top.append(Vector2(x, y))
		floor_pts.append(Vector2(x, room.y - 10.0 - rng.randf_range(0, 18)))
		x += rng.randf_range(10, 22)
	vault_top.append(Vector2(x, s.position.y))
	floor_pts.append(Vector2(x, s.end.y))
	shapes_far.append({"kind": "vault", "pts": vault_top})
	shapes_far.append({"kind": "vault", "pts": floor_pts})
	# Strates de la roche, à peine marquées
	for i in int(s.get_area() / 16000.0):
		var p := Vector2(rng.randf_range(s.position.x, s.end.x), rng.randf_range(30.0, maxf(40.0, room.y - 30.0)))
		var line := PackedVector2Array()
		for j in 5:
			line.append(p + Vector2(j * rng.randf_range(10, 18), rng.randf_range(-2, 2)))
		shapes_far.append({"kind": "strata", "pts": line})
	# Mousse et racines fines qui pendent de la voûte
	for i in int(s.size.x / 80.0):
		shapes_near.append({"kind": "moss", "x": s.position.x + rng.randf_range(0, s.size.x), "len": rng.randf_range(16, 60), "ph": rng.randf() * TAU})
	# Les gouttes : chacune perle au bout de sa concrétion, à son rythme
	for i in int(s.size.x / 120.0) + 1:
		var top := -20.0
		var ledge := false
		if room.y > 320.0 and rng.randf() < 0.5:
			# Salles hautes : certaines gouttes tombent d'un surplomb à mi-hauteur
			top = rng.randf_range(room.y * 0.25, room.y * 0.65)
			ledge = true
		# Au plafond, la concrétion dépasse sous la voûte du fond
		var tip := top + (rng.randf_range(14, 30) if ledge else rng.randf_range(36, 60))
		var rock := PackedVector2Array()
		if ledge:
			var c := Vector2(0, top)
			for j in 7:
				rock.append(c + Vector2.from_angle(TAU * j / 7.0 + rng.randf_range(-0.3, 0.3)) * Vector2(22, 9) * rng.randf_range(0.7, 1.0))
		shapes_near.append({"kind": "drip", "x": s.position.x + rng.randf_range(0, s.size.x), "top": top, "tip": tip,
			"fall": rng.randf_range(80, 170), "period": rng.randf_range(2.6, 5.5), "ph": rng.randf_range(0, 6),
			"pitch": rng.randf_range(0.8, 1.3), "rock": rock})


# Lumière et ombre : hautes fenêtres ogivales et rais de lumière
func _lumiere() -> void:
	var s := _span()
	var x := s.position.x + 30.0
	while x < s.end.x:
		shapes_far.append({"kind": "window", "x": x, "w": 26.0, "h": room.y * 0.3, "ph": rng.randf() * TAU})
		x += rng.randf_range(110, 150)
	for i in int(s.size.x / 120.0):
		shapes_near.append({"kind": "column", "x": s.position.x + rng.randf_range(0, s.size.x), "w": rng.randf_range(10, 18)})


# Profondeurs : stalactites, stalagmites, une paroi lointaine
func _profondeurs() -> void:
	var s := _span()
	var x := s.position.x
	while x < s.end.x:
		var w := rng.randf_range(10, 26)
		shapes_far.append({"kind": "stalactite", "x": x, "w": w, "len": rng.randf_range(30, 110)})
		shapes_far.append({"kind": "stalagmite", "x": x + rng.randf_range(0, 20), "w": w * 1.2, "len": rng.randf_range(20, 70)})
		x += w + rng.randf_range(4, 30)
	# Blocs de roche épars sur toute la paroi, pour les salles hautes
	for i in int(s.get_area() / 9000.0):
		var c := Vector2(rng.randf_range(s.position.x, s.end.x), rng.randf_range(s.position.y, s.end.y))
		var r := rng.randf_range(8, 26)
		var pts := PackedVector2Array()
		for j in 7:
			pts.append(c + Vector2.from_angle(TAU * j / 7.0 + rng.randf_range(-0.3, 0.3)) * r * rng.randf_range(0.6, 1.0))
		shapes_far.append({"kind": "rock", "pts": pts})
	for i in int(s.size.x / 70.0):
		shapes_near.append({"kind": "root", "x": s.position.x + rng.randf_range(0, s.size.x), "len": rng.randf_range(30, 100), "ph": rng.randf() * TAU})


# Clocher : grande horloge, charpente croisée, cordes qui se balancent
func _clocher() -> void:
	var s := _span()
	shapes_far.append({"kind": "clock", "c": Vector2(room.x * 0.5, room.y * 0.35), "r": 70.0})
	var x := s.position.x
	while x < s.end.x:
		shapes_far.append({"kind": "truss", "x": x, "w": 96.0})
		x += 96.0
	for i in int(s.size.x / 60.0):
		shapes_near.append({"kind": "rope", "x": s.position.x + rng.randf_range(0, s.size.x), "len": rng.randf_range(80, 220), "ph": rng.randf() * TAU})


# Carillon : rangées de cloches suspendues qui oscillent doucement
func _carillon() -> void:
	var s := _span()
	var x := s.position.x + 20.0
	while x < s.end.x:
		shapes_far.append({"kind": "bell", "x": x, "y": 40.0 + rng.randf_range(0, 50), "r": rng.randf_range(10, 22), "ph": rng.randf() * TAU})
		x += rng.randf_range(40, 70)
	x = s.position.x
	while x < s.end.x:
		shapes_near.append({"kind": "beam", "y": 24.0, "x": x})
		x += 400.0
	for i in int(s.size.x / 160.0):
		shapes_near.append({"kind": "bell", "x": s.position.x + rng.randf_range(0, s.size.x), "y": 30.0 + rng.randf_range(20, 90), "r": rng.randf_range(16, 26), "ph": rng.randf() * TAU})


# Poursuite : des miroirs brisés où l'ombre s'est échappée, des volutes qui montent du bas
func _poursuite() -> void:
	var s := _span()
	var x := s.position.x + 20.0
	while x < s.end.x:
		var w := rng.randf_range(34, 50)
		var h := w * rng.randf_range(1.6, 2.2)
		var y := rng.randf_range(s.position.y + 20.0, maxf(s.position.y + 30.0, room.y * 0.5 - h * 0.5))
		var cracks: Array = []
		var o := Vector2(rng.randf_range(0.3, 0.7) * w, rng.randf_range(0.3, 0.6) * h)
		for i in 5:
			cracks.append(o + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(w * 0.4, h * 0.6))
		shapes_far.append({"kind": "mirror", "pos": Vector2(x, y), "w": w, "h": h, "o": o, "cracks": cracks, "ph": rng.randf() * TAU})
		x += w + rng.randf_range(60, 110)
	for i in int(s.size.x / 50.0):
		shapes_near.append({"kind": "wisp", "x": s.position.x + rng.randf_range(0, s.size.x), "len": rng.randf_range(60, 180), "ph": rng.randf() * TAU})


# Horloge : engrenages qui tournent, balancier, aiguilles géantes
func _horloge() -> void:
	var s := _span()
	var x := s.position.x + 40.0
	var dir := 1.0
	while x < s.end.x:
		var r := rng.randf_range(24, 48)
		shapes_far.append({"kind": "gear", "c": Vector2(x, rng.randf_range(room.y * 0.15, room.y * 0.75)), "r": r, "teeth": int(r / 4.0), "spin": dir * 12.0 / r})
		dir = -dir
		x += r * 2.0 + rng.randf_range(20, 80)
	for i in maxi(1, int(s.size.x / 320.0)):
		shapes_near.append({"kind": "pendulum", "x": s.position.x + (i + 0.5) * s.size.x / maxi(1, int(s.size.x / 320.0)), "len": room.y * 0.55, "ph": rng.randf() * TAU})


# Dernière lueur : la sortie, une grande clarté au loin, des murs qui se fissurent
func _lueur() -> void:
	var s := _span()
	shapes_far.append({"kind": "dawn", "c": Vector2(room.x * 0.5, -room.y * 0.15)})
	for i in int(s.size.x / 50.0):
		var x := s.position.x + rng.randf_range(0, s.size.x)
		var pts := PackedVector2Array([Vector2(x, s.end.y)])
		var y := s.end.y
		while y > room.y * 0.2:
			y -= rng.randf_range(12, 30)
			x += rng.randf_range(-10, 10)
			pts.append(Vector2(x, y))
		shapes_far.append({"kind": "crack", "pts": pts, "ph": rng.randf() * TAU})
	for i in int(s.size.x / 140.0):
		shapes_near.append({"kind": "ruin", "x": s.position.x + rng.randf_range(0, s.size.x), "w": rng.randf_range(14, 30), "h": rng.randf_range(room.y * 0.2, room.y * 0.6)})


# Regards : des gradins de silhouettes qui observent, derrière de hautes fenêtres.
# Pas d'yeux dans le fond, pour ne jamais confondre avec les yeux du jeu.
func _regards() -> void:
	var s := _span()
	var x := s.position.x
	while x < s.end.x:
		shapes_far.append({"kind": "window_frame", "x": x, "w": 70.0, "top": room.y * 0.1, "h": room.y * 0.55})
		x += 96.0
	for row in 3:
		var y := room.y * (0.35 + row * 0.12)
		x = s.position.x + rng.randf_range(0, 12)
		while x < s.end.x:
			shapes_far.append({"kind": "watcher", "x": x, "y": y, "s": rng.randf_range(0.85, 1.15), "ph": rng.randf() * TAU})
			x += rng.randf_range(14, 22)
	for i in int(s.size.x / 120.0):
		shapes_near.append({"kind": "curtain", "x": s.position.x + rng.randf_range(0, s.size.x), "w": rng.randf_range(20, 40), "ph": rng.randf() * TAU})


# Miroir : des cadres de miroir disposés en symétrie autour du milieu de la salle,
# et des éclats qui flottent
func _miroir() -> void:
	var s := _span()
	var mid := room.x * 0.5
	var d := 30.0
	while mid + d < s.end.x:
		var w := rng.randf_range(30, 46)
		var h := w * rng.randf_range(1.6, 2.3)
		var y := rng.randf_range(room.y * 0.08, maxf(room.y * 0.1, room.y * 0.55 - h))
		for side in [-1.0, 1.0]:
			shapes_far.append({"kind": "frame", "pos": Vector2(mid + side * d - (w if side < 0.0 else 0.0), y), "w": w, "h": h, "ph": rng.randf() * TAU})
		d += w + rng.randf_range(40, 80)
	shapes_far.append({"kind": "axis", "x": mid})
	for i in int(s.get_area() / 14000.0):
		var c := Vector2(rng.randf_range(s.position.x, s.end.x), rng.randf_range(s.position.y, s.end.y))
		shapes_near.append({"kind": "shard", "c": c, "r": rng.randf_range(3, 8), "ph": rng.randf() * TAU})


# Compagnie : des arches effondrées au loin, et des grappes de petites lueurs
# qui flottent ensemble, jamais seules
func _compagnie() -> void:
	var s := _span()
	var x := s.position.x
	while x < s.end.x:
		shapes_far.append({"kind": "ruin", "x": x, "w": rng.randf_range(16, 28), "h": rng.randf_range(room.y * 0.25, room.y * 0.7)})
		x += rng.randf_range(70, 130)
	for i in maxi(int(s.get_area() / 30000.0), 3):
		var c := Vector2(rng.randf_range(s.position.x, s.end.x), rng.randf_range(s.position.y, s.end.y))
		var dots := []
		for j in rng.randi_range(3, 5):
			dots.append(Vector2(rng.randf_range(-9, 9), rng.randf_range(-6, 6)))
		shapes_near.append({"kind": "glow", "c": c, "dots": dots, "ph": rng.randf() * TAU})
# Le matin (épilogue) : les fenêtres de Regards devenues vitraux, des rais de soleil,
# et du lierre qui a poussé pendant la nuit
func _matin() -> void:
	var s := _span()
	var x := s.position.x + rng.randf_range(0, 30)
	var k := 0
	while x < s.end.x:
		var w := rng.randf_range(44, 60)
		shapes_far.append({"kind": "stained", "x": x, "w": w, "top": room.y * 0.12 + rng.randf_range(-8, 8), "h": room.y * rng.randf_range(0.4, 0.55), "k": k, "ph": rng.randf() * TAU})
		x += w + rng.randf_range(50, 90)
		k += 3
	for i in int(s.size.x / 110.0):
		shapes_near.append({"kind": "sunray", "x": s.position.x + rng.randf_range(0, s.size.x), "w": rng.randf_range(18, 40), "ph": rng.randf() * TAU})
	for i in int(s.size.x / 70.0):
		shapes_near.append({"kind": "ivy", "x": s.position.x + rng.randf_range(0, s.size.x), "len": rng.randf_range(30, 110), "ph": rng.randf() * TAU})


# --- Dessin ----------------------------------------------------------------

# Toujours plus sombre que les murs, pour que le niveau reste lisible
const FAR_COL := Color(0.075, 0.075, 0.075)
const NEAR_COL := Color(0.055, 0.055, 0.055)


func _draw_far(n: Node2D) -> void:
	for sh in shapes_far:
		_shape(n, sh, FAR_COL)


func _draw_near(n: Node2D) -> void:
	for sh in shapes_near:
		_shape(n, sh, NEAR_COL)


func _shape(n: Node2D, sh: Dictionary, col: Color) -> void:
	var s := _span()
	match sh["kind"]:
		"mouth":
			# Le jour qui entre, très atténué : un halo, puis l'ouverture elle-même
			var c: Vector2 = sh["c"]
			var a := 0.012 + 0.004 * sin(t * 0.4 + sh["ph"])
			for i in 6:
				n.draw_circle(c, sh["w"] * (0.5 + i * 0.22), Color(1, 1, 1, a))
			n.draw_colored_polygon(sh["pts"], Color(0.115, 0.115, 0.115))
			# Au loin, dehors : la silhouette de la tour
			var bx: float = c.x + sh["w"] * 0.12
			var base: float = sh["base"]
			n.draw_rect(Rect2(bx - 5, base - sh["h"] * 0.75, 10, sh["h"] * 0.75 + 8), Color(0.085, 0.085, 0.085))
			n.draw_rect(Rect2(bx - 1, base - sh["h"] * 0.68, 2, 2), Color(1, 1, 1, 0.06 + 0.04 * sin(t * 1.3 + sh["ph"])))
			# Un voile de jour qui descend dans la grotte
			n.draw_polygon(
				PackedVector2Array([Vector2(c.x - sh["w"] * 0.4, base), Vector2(c.x + sh["w"] * 0.4, base), Vector2(c.x + sh["w"] * 0.9, s.end.y), Vector2(c.x - sh["w"] * 0.6, s.end.y)]),
				PackedColorArray([Color(1, 1, 1, a * 2.5), Color(1, 1, 1, a * 2.5), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
		"vault":
			n.draw_colored_polygon(sh["pts"], col)
		"strata":
			n.draw_polyline(sh["pts"], Color(0.06, 0.06, 0.06), 1.0)
		"moss":
			var pts := PackedVector2Array()
			for i in 6:
				var k := i / 5.0
				pts.append(Vector2(sh["x"] + sin(k * 4.0 + sh["ph"]) * 2.0 + sin(t * 0.7 + sh["ph"]) * 1.5 * k, -20.0 + k * sh["len"]))
			n.draw_polyline(pts, col, 1.0)
			for i in range(1, 6):
				n.draw_line(pts[i], pts[i] + Vector2(2.5 if i % 2 == 0 else -2.5, -2), col, 1.0)
		"drip":
			_drip(n, sh, col)
		"window":
			var x: float = sh["x"]
			var w: float = sh["w"]
			var h: float = sh["h"]
			var top := room.y * 0.12
			var glow := 0.1 + 0.02 * sin(t * 0.7 + sh["ph"])
			var pane := Color(glow, glow, glow)
			n.draw_rect(Rect2(x, top + w * 0.5, w, h), pane)
			n.draw_colored_polygon(PackedVector2Array([Vector2(x, top + w * 0.5), Vector2(x + w * 0.5, top - w * 0.3), Vector2(x + w, top + w * 0.5)]), pane)
			n.draw_line(Vector2(x + w * 0.5, top), Vector2(x + w * 0.5, top + h + w * 0.5), Color.BLACK, 2.0)
			n.draw_line(Vector2(x, top + w * 0.5 + h * 0.45), Vector2(x + w, top + w * 0.5 + h * 0.45), Color.BLACK, 2.0)
			# Rai de lumière qui descend en biais
			var a := 0.05 + 0.02 * sin(t * 0.5 + sh["ph"])
			var base := top + w * 0.5 + h
			var drop := s.end.y - base
			n.draw_polygon(
				PackedVector2Array([Vector2(x, base), Vector2(x + w, base), Vector2(x + w + drop * 0.45, s.end.y), Vector2(x + drop * 0.35, s.end.y)]),
				PackedColorArray([Color(1, 1, 1, a), Color(1, 1, 1, a), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
		"column":
			n.draw_rect(Rect2(sh["x"], s.position.y, sh["w"], s.size.y), col)
		"stalactite":
			n.draw_colored_polygon(PackedVector2Array([Vector2(sh["x"], s.position.y), Vector2(sh["x"] + sh["w"], s.position.y), Vector2(sh["x"] + sh["w"] * 0.5, sh["len"])]), col)
		"stalagmite":
			n.draw_colored_polygon(PackedVector2Array([Vector2(sh["x"], s.end.y), Vector2(sh["x"] + sh["w"] * 0.5, room.y - sh["len"]), Vector2(sh["x"] + sh["w"], s.end.y)]), col)
		"rock":
			n.draw_colored_polygon(sh["pts"], col)
		"root":
			var pts := PackedVector2Array()
			for i in 8:
				var k := i / 7.0
				pts.append(Vector2(sh["x"] + sin(k * 5.0 + sh["ph"]) * 4.0 + sin(t * 0.6 + sh["ph"]) * 2.0 * k, -20.0 + k * sh["len"]))
			n.draw_polyline(pts, col, 2.0)
		"clock":
			var c: Vector2 = sh["c"]
			var r: float = sh["r"]
			n.draw_circle(c, r + 6, col)
			n.draw_circle(c, r, Color(0.05, 0.05, 0.05))
			for i in 12:
				var a := TAU * i / 12.0
				n.draw_line(c + Vector2.from_angle(a) * (r - 10), c + Vector2.from_angle(a) * (r - 3), col, 3.0)
			# Les aiguilles tournent, lentement
			n.draw_line(c, c + Vector2.from_angle(t * 0.05 - PI / 2) * r * 0.55, col, 4.0)
			n.draw_line(c, c + Vector2.from_angle(t * 0.6 - PI / 2) * r * 0.8, col, 2.0)
		"truss":
			var x: float = sh["x"]
			var w: float = sh["w"]
			var y0 := 24.0
			var y1 := s.end.y
			n.draw_line(Vector2(x, y0), Vector2(x, y1), col, 6.0)
			n.draw_line(Vector2(x - 3, y0), Vector2(x + w + 3, y0), col, 6.0)
			n.draw_line(Vector2(x, y0), Vector2(x + w, y0 + w), col, 3.0)
			n.draw_line(Vector2(x + w, y0), Vector2(x, y0 + w), col, 3.0)
		"rope":
			var sway := sin(t * 0.6 + sh["ph"]) * 6.0
			var pts := PackedVector2Array()
			for i in 10:
				var k := i / 9.0
				pts.append(Vector2(sh["x"] + sway * k * k, s.position.y + k * (sh["len"] - s.position.y)))
			n.draw_polyline(pts, col, 2.0)
			var end := pts[pts.size() - 1]
			n.draw_circle(end + Vector2(0, 3), 3.0, col)
		"bell":
			var top := Vector2(sh["x"], sh["y"])
			n.draw_line(Vector2(top.x, s.position.y), top, col, 2.0)
			var ang := sin(t * 0.9 + sh["ph"]) * 0.12
			n.draw_set_transform(top, ang)
			_bell(n, sh["r"], col)
			n.draw_set_transform(Vector2.ZERO)
		"beam":
			n.draw_rect(Rect2(sh["x"], sh["y"] - 6, 400, 8), col)
		"gear":
			var c: Vector2 = sh["c"]
			var r: float = sh["r"]
			var rot: float = t * sh["spin"]
			var n_teeth: int = sh["teeth"]
			var pts := PackedVector2Array()
			for i in n_teeth * 2:
				var a := rot + TAU * i / (n_teeth * 2.0)
				var rr := r if i % 2 == 0 else r * 0.85
				pts.append(c + Vector2.from_angle(a - 0.08) * rr)
				pts.append(c + Vector2.from_angle(a + 0.08) * rr)
			n.draw_colored_polygon(pts, col)
			n.draw_circle(c, r * 0.55, Color.BLACK)
			for i in 4:
				var a := rot + TAU * i / 4.0
				n.draw_line(c, c + Vector2.from_angle(a) * r * 0.6, col, 3.0)
			n.draw_circle(c, r * 0.12, col)
		"pendulum":
			var ang := sin(t * 1.6 + sh["ph"]) * 0.35
			var top := Vector2(sh["x"], -10.0)
			var bob: Vector2 = top + Vector2.from_angle(PI / 2 - ang) * sh["len"]
			n.draw_line(top, bob, col, 2.0)
			n.draw_circle(bob, 12.0, col)
		"dawn":
			# Clarté douce qui pulse lentement, plus forte au centre
			var c: Vector2 = sh["c"]
			var pulse := 1.0 + 0.05 * sin(t * 0.6)
			for i in 14:
				var r := (40.0 + i * 22.0) * pulse
				n.draw_circle(c, r, Color(1, 1, 1, 0.012))
		"crack":
			var a := 0.05 + 0.04 * maxf(0.0, sin(t * 0.8 + sh["ph"]))
			n.draw_polyline(sh["pts"], Color(1, 1, 1, a), 1.0)
		"ruin":
			n.draw_rect(Rect2(sh["x"], s.end.y - sh["h"], sh["w"], sh["h"] + 10), col)
			n.draw_colored_polygon(PackedVector2Array([Vector2(sh["x"], s.end.y - sh["h"]), Vector2(sh["x"] + sh["w"] * 0.4, s.end.y - sh["h"] - 10), Vector2(sh["x"] + sh["w"], s.end.y - sh["h"] + 4)]), col)
		"window_frame":
			var r := Rect2(sh["x"], sh["top"], sh["w"], sh["h"])
			n.draw_rect(r.grow(5), col)
			n.draw_rect(r, Color(0.035, 0.035, 0.035))
			n.draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.end.y), col, 3.0)
		"watcher":
			# Tête et épaules, qui se tournent très lentement
			var p := Vector2(sh["x"] + sin(t * 0.3 + sh["ph"]) * 1.5, sh["y"])
			var k: float = sh["s"]
			var dark := Color(0.02, 0.02, 0.02)
			n.draw_circle(p + Vector2(0, -9) * k, 4.0 * k, dark)
			n.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 4) * k, p + Vector2(-5, -4) * k, p + Vector2(5, -4) * k, p + Vector2(7, 4) * k]), dark)
		"curtain":
			var pts := PackedVector2Array()
			var w: float = sh["w"]
			for i in 9:
				var k := i / 8.0
				pts.append(Vector2(sh["x"] + sin(k * 6.0 + t * 0.4 + sh["ph"]) * 3.0, s.position.y + k * s.size.y))
			for i in range(8, -1, -1):
				var k := i / 8.0
				pts.append(Vector2(sh["x"] + w + sin(k * 6.0 + t * 0.4 + sh["ph"] + 1.0) * 3.0, s.position.y + k * s.size.y))
			n.draw_colored_polygon(pts, col)
		"frame":
			var r := Rect2(sh["pos"], Vector2(sh["w"], sh["h"]))
			var glint := 0.08 + 0.02 * sin(t * 0.7 + sh["ph"])
			n.draw_rect(r.grow(4), col)
			n.draw_rect(r, Color(glint, glint, glint))
			# Reflet oblique qui glisse sur le verre
			var y := fposmod(t * 18.0 + sh["ph"] * 30.0, r.size.y + 30.0) - 15.0
			n.draw_line(Vector2(r.position.x + 3, r.position.y + clampf(y + 10.0, 0.0, r.size.y)), Vector2(r.end.x - 3, r.position.y + clampf(y - 10.0, 0.0, r.size.y)), Color(1, 1, 1, 0.06), 2.0)
		"axis":
			n.draw_line(Vector2(sh["x"], s.position.y), Vector2(sh["x"], s.end.y), Color(1, 1, 1, 0.03), 1.0)
		"shard":
			var c: Vector2 = sh["c"] + Vector2(0, sin(t * 0.5 + sh["ph"]) * 3.0)
			var r: float = sh["r"]
			var a: float = t * 0.3 + sh["ph"]
			n.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + 2.2) * r * 0.6, c + Vector2.from_angle(a + 3.9) * r * 0.8]), Color(1, 1, 1, 0.05 + 0.04 * maxf(0.0, sin(t + sh["ph"]))))
		"mirror":
			var r := Rect2(sh["pos"], Vector2(sh["w"], sh["h"]))
			var glint := 0.1 + 0.025 * sin(t * 0.8 + sh["ph"])
			n.draw_rect(r.grow(4), col)
			n.draw_rect(r, Color(glint, glint, glint))
			# Une silhouette vide au milieu du verre : son reflet est parti
			var c := r.position + r.size * Vector2(0.5, 0.55)
			n.draw_circle(c - Vector2(0, 6), 7.0, Color.BLACK)
			n.draw_rect(Rect2(c - Vector2(7, 6), Vector2(14, 12)), Color.BLACK)
			var o: Vector2 = r.position + sh["o"]
			for p in sh["cracks"]:
				n.draw_line(o, (r.position + p).clamp(r.position, r.end), Color.BLACK, 1.0)
		"glow":
			var c: Vector2 = sh["c"] + Vector2(sin(t * 0.3 + sh["ph"]) * 6.0, sin(t * 0.5 + sh["ph"]) * 4.0)
			var dots: Array = sh["dots"]
			for j in dots.size():
				var p: Vector2 = c + dots[j] + Vector2.from_angle(t * 0.8 + j * 2.1 + sh["ph"]) * 2.0
				var a := 0.06 + 0.04 * sin(t * 1.3 + j + sh["ph"])
				n.draw_circle(p, 3.0, Color(1, 1, 1, a * 0.5))
				n.draw_circle(p, 1.2, Color(1, 1, 1, a * 1.6))
		"stained":
			# Vitrail en plein cintre : des carreaux de couleur, assombris pour rester derrière les murs
			var x: float = sh["x"]
			var w: float = sh["w"]
			var h: float = sh["h"]
			var top: float = sh["top"]
			n.draw_rect(Rect2(x - 5, top - 5, w + 10, h + 10), col)
			n.draw_circle(Vector2(x + w * 0.5, top), w * 0.5 + 5, col)
			var rows := 4
			var ph: float = sh["ph"]
			for j in rows:
				for i in 3:
					var glow := 0.16 + 0.04 * sin(t * 0.5 + ph + i + j * 1.7)
					var c := Palette.glass(sh["k"] + i + j * 2, colors) * glow
					c.a = 1.0
					n.draw_rect(Rect2(x + i * w / 3.0 + 1, top + j * h / rows + 1, w / 3.0 - 2, h / rows - 2), c)
			n.draw_circle(Vector2(x + w * 0.5, top), w * 0.5 - 1, Palette.glass(sh["k"] + 4, colors) * 0.22)
			n.draw_circle(Vector2(x + w * 0.5, top), w * 0.18, Palette.glass(sh["k"] + 2, colors) * 0.3)
		"sunray":
			var a := (0.03 + 0.015 * sin(t * 0.4 + sh["ph"])) * (0.4 + colors)
			var sun := Palette.GOLD
			var x: float = sh["x"]
			var w: float = sh["w"]
			n.draw_polygon(
				PackedVector2Array([Vector2(x, s.position.y), Vector2(x + w, s.position.y), Vector2(x + w + s.size.y * 0.35, s.end.y), Vector2(x + s.size.y * 0.3, s.end.y)]),
				PackedColorArray([Color(sun, a), Color(sun, a), Color(sun, 0), Color(sun, 0)]))
		"ivy":
			var leaf := Color(0.07, 0.07, 0.07).lerp(Color(0.1, 0.17, 0.11), colors)
			var pts := PackedVector2Array()
			for i in 8:
				var k := i / 7.0
				pts.append(Vector2(sh["x"] + sin(k * 5.0 + sh["ph"]) * 4.0 + sin(t * 0.5 + sh["ph"]) * 1.5 * k, -20.0 + k * sh["len"]))
			n.draw_polyline(pts, leaf, 2.0)
			for i in range(1, 8, 2):
				n.draw_circle(pts[i] + Vector2(3 if i % 4 == 1 else -3, 0), 2.5, leaf)
		"wisp":
			var pts := PackedVector2Array()
			for i in 10:
				var k := i / 9.0
				pts.append(Vector2(sh["x"] + sin(k * 4.0 + t * 0.9 + sh["ph"]) * 6.0 * k, s.end.y - k * sh["len"]))
			n.draw_polyline(pts, col, 3.0)


# Une goutte : elle perle au bout de la concrétion, se détache, tombe, éclabousse
# une petite flaque et y fait des ronds
const DRIP_G := 320.0


func _drip(n: Node2D, sh: Dictionary, col: Color) -> void:
	var x: float = sh["x"]
	var tip: float = sh["tip"]
	var floor_y: float = tip + sh["fall"]
	if sh["rock"].size() > 0:
		n.draw_set_transform(Vector2(x, 0))
		n.draw_colored_polygon(sh["rock"], col)
		n.draw_set_transform(Vector2.ZERO)
	n.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, sh["top"]), Vector2(x + 4, sh["top"]), Vector2(x, tip)]), col)
	n.draw_line(Vector2(x - 7, floor_y), Vector2(x + 7, floor_y), Color(0.11, 0.11, 0.11), 1.0)
	var drop_col := Color(0.85, 0.85, 0.85, 0.75)
	var fall_t := sqrt(2.0 * sh["fall"] / DRIP_G)
	var swell: float = sh["period"] - fall_t
	var u := fposmod(t + sh["ph"], sh["period"])
	if u < swell:
		# La goutte grossit, puis tremble avant de lâcher
		var k := u / swell
		n.draw_circle(Vector2(x, tip + k * 1.5), 0.4 + k * 1.2, drop_col)
	else:
		var d := u - swell
		var y := tip + 1.5 + 0.5 * DRIP_G * d * d
		n.draw_line(Vector2(x, y - minf(DRIP_G * d * 0.03, 4.0)), Vector2(x, y), drop_col, 1.0)
		n.draw_circle(Vector2(x, y), 1.0, drop_col)
	# Ronds et éclaboussures de la goutte précédente
	# La goutte précédente a touché le fond au début du cycle
	var since := u
	if since < 1.4:
		for i in 2:
			var r := since * 16.0 - i * 5.0
			if r > 0.0:
				var a := 0.35 * (1.0 - since / 1.4)
				n.draw_set_transform(Vector2(x, floor_y), 0.0, Vector2(1, 0.28))
				n.draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(1, 1, 1, a), 1.0)
				n.draw_set_transform(Vector2.ZERO)
		if since < 0.35:
			for side in [-1.0, 1.0]:
				var p := Vector2(x + side * since * 22.0, floor_y - since * 30.0 + 0.5 * DRIP_G * since * since)
				n.draw_rect(Rect2(p, Vector2.ONE), drop_col)


# Le petit « plic » quand une goutte proche touche le fond : plus doux de loin,
# muet hors de l'écran
func _drip_sounds(before: float, cam_center: Vector2) -> void:
	for sh in shapes_near:
		if sh["kind"] != "drip":
			continue
		var p: float = sh["period"]
		if floorf((before + sh["ph"]) / p) == floorf((t + sh["ph"]) / p):
			continue
		var d := near.to_global(Vector2(sh["x"], sh["tip"] + sh["fall"])).distance_to(cam_center)
		if d > 220.0:
			continue
		for pl in drip_players:
			if not pl.playing:
				pl.pitch_scale = sh["pitch"]
				pl.volume_db = -12.0 - d / 220.0 * 14.0
				pl.play()
				break


# « Plic » synthétisé une seule fois : une note qui glisse vers l'aigu et s'éteint vite
static var _plip: AudioStreamWAV


func _plip_stream() -> AudioStreamWAV:
	if _plip:
		return _plip
	var rate := 22050
	var n := int(0.16 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(700.0, 1700.0, sqrt(k)) / rate
		var v := sin(phase) * pow(1.0 - k, 3.0) * minf(1.0, i / 40.0) * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	_plip = AudioStreamWAV.new()
	_plip.format = AudioStreamWAV.FORMAT_16_BITS
	_plip.mix_rate = rate
	_plip.data = data
	return _plip


# Cloche vue de face, attachée à l'origine
func _bell(n: Node2D, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * r * 0.6, r * 0.6 + sin(a) * r * 0.6))
	pts.append(Vector2(r * 0.7, r * 1.3))
	pts.append(Vector2(r, r * 1.6))
	pts.append(Vector2(-r, r * 1.6))
	pts.append(Vector2(-r * 0.7, r * 1.3))
	n.draw_colored_polygon(pts, col)
	n.draw_circle(Vector2(0, r * 1.7), r * 0.18, col)


# --- Particules d'ambiance ---------------------------------------------------

func _particles() -> void:
	var p := CPUParticles2D.new()
	p.position = room * 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = room * 0.5
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.gravity = Vector2.ZERO
	match chapter:
		"Le Seuil":
			# Un peu d'humidité qui flotte dans le jour de l'entrée
			p.amount = 18
			p.direction = Vector2(1, -0.2)
			p.spread = 60
			p.initial_velocity_min = 1
			p.initial_velocity_max = 3
			p.color = Color(1, 1, 1, 0.22)
		"Lumière et ombre":
			# Grains de lumière qui montent dans les rais
			p.amount = 40
			p.direction = Vector2.UP
			p.spread = 25
			p.initial_velocity_min = 2
			p.initial_velocity_max = 6
			p.color = Color(1, 1, 1, 0.5)
		"Profondeurs":
			# Gouttes qui tombent du plafond
			p.amount = 14
			p.position = Vector2(room.x * 0.5, 0)
			p.emission_rect_extents = Vector2(room.x * 0.5, 1)
			p.lifetime = 2.5
			p.preprocess = 2.5
			p.gravity = Vector2(0, 160)
			p.direction = Vector2.DOWN
			p.spread = 0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.5
			p.color = Color(0.85, 0.85, 0.85, 0.6)
		"Poursuite":
			# Cendres pâles qui montent, comme aspirées vers le haut
			p.amount = 26
			p.direction = Vector2.UP
			p.spread = 15
			p.initial_velocity_min = 4
			p.initial_velocity_max = 9
			p.color = Color(0.75, 0.75, 0.75, 0.35)
		"Dernière lueur":
			# Braises de lumière qui montent vers la sortie
			p.amount = 50
			p.direction = Vector2.UP
			p.spread = 15
			p.initial_velocity_min = 6
			p.initial_velocity_max = 14
			p.color = Color(1, 1, 1, 0.6)
		"Compagnie":
			# Quelques grains clairs qui flottent sans se presser
			p.amount = 24
			p.direction = Vector2.UP
			p.spread = 180
			p.initial_velocity_min = 1
			p.initial_velocity_max = 4
			p.color = Color(1, 1, 1, 0.4)
		"Le matin":
			# Pétales et pollen de toutes les couleurs, qui descendent sans se presser
			p.amount = 36
			p.direction = Vector2(0.4, 1)
			p.spread = 30
			p.gravity = Vector2(0, 3)
			p.initial_velocity_min = 3
			p.initial_velocity_max = 8
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.color = Color(Color.WHITE.lerp(Palette.DAWN, colors), 0.55)
			p.hue_variation_min = -0.5 * colors
			p.hue_variation_max = 0.5 * colors
		"Clocher", "Carillon", "Horloge":
			# Poussière de charpente qui retombe lentement
			p.amount = 30
			p.direction = Vector2.DOWN
			p.spread = 40
			p.gravity = Vector2(0, 2)
			p.initial_velocity_min = 2
			p.initial_velocity_max = 5
			p.color = Color(0.8, 0.8, 0.8, 0.35)
		_:
			return
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
