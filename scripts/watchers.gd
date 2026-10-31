# Yeux qui regardent. Chacun s'ouvre et se ferme sur un cycle commun à tout le niveau :
# "Y" au début du cycle, "y" décalé d'un demi-cycle. Ouvert, son regard balaie la salle
# jusqu'aux murs (les blocs solides cachent aussi). Rester dans un regard fait monter
# l'exposition ; pleine, elle tue. À l'abri, elle retombe.
extends Node2D

const CLOSED := 1.8       # secondes paupière fermée
const WAKING := 0.5       # la paupière s'entrouvre : avertissement, pas encore de regard
const OPEN := 1.6         # regard actif
const PERIOD := CLOSED + WAKING + OPEN
const RANGE := 150.0      # portée du regard, en px
const EXPOSE_TIME := 0.55 # secondes de regard continu avant de mourir
const RECOVER := 1.5      # l'exposition retombe 1,5 fois plus vite qu'elle ne monte
const RAYS := 72

var eyes: Array = []      # [position, décalage] ; rempli par main avant _ready
var player: CharacterBody2D
var t := 0.0
var exposure := 0.0
var fans: Array = []      # polygone du regard de chaque œil (vide si fermé)
var seen := false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	z_index = 3
	fans.resize(eyes.size())
	for i in fans.size():
		fans[i] = PackedVector2Array()


func reset() -> void:
	exposure = 0.0


# Temps écoulé dans le cycle de l'œil i
func _local(i: int) -> float:
	return fmod(t + eyes[i][1] * PERIOD, PERIOD)


func is_open(i: int) -> bool:
	return _local(i) >= CLOSED + WAKING


func _physics_process(delta: float) -> void:
	t += delta
	var space := get_world_2d().direct_space_state
	var exclude := [player.get_rid()]
	seen = false
	for i in eyes.size():
		var pos: Vector2 = eyes[i][0]
		if not is_open(i):
			fans[i] = PackedVector2Array()
			continue
		fans[i] = _fan(space, pos, exclude)
		if player.dead or not player.is_physics_processing():
			continue
		var to: Vector2 = player.global_position
		if pos.distance_to(to) > RANGE:
			continue
		var q := PhysicsRayQueryParameters2D.create(pos, to)
		q.exclude = exclude
		if space.intersect_ray(q).is_empty():
			seen = true
	if player.dead:
		exposure = 0.0
		return
	if seen:
		exposure += delta / EXPOSE_TIME
		if exposure >= 1.0:
			exposure = 0.0
			player.die()
	else:
		exposure = maxf(exposure - delta * RECOVER / EXPOSE_TIME, 0.0)


func _fan(space: PhysicsDirectSpaceState2D, pos: Vector2, exclude: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in RAYS:
		var to := pos + Vector2.from_angle(TAU * k / RAYS) * RANGE
		var q := PhysicsRayQueryParameters2D.create(pos, to)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		pts.append(hit["position"] if not hit.is_empty() else to)
	return pts


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i in eyes.size():
		var pos: Vector2 = eyes[i][0]
		var u := _local(i)
		if fans[i].size() > 2:
			# Le regard : un éventail pâle qui s'arrête aux murs
			var fade := clampf((u - CLOSED - WAKING) / 0.15, 0.0, 1.0) * clampf((PERIOD - u) / 0.15, 0.0, 1.0)
			draw_colored_polygon(fans[i], Color(1, 1, 1, 0.07 * fade))
			var edge: PackedVector2Array = fans[i].duplicate()
			edge.append(edge[0])
			draw_polyline(edge, Color(1, 1, 1, 0.18 * fade), 1.0)
		_eye(pos, u)
	# L'exposition : des cils qui se referment autour du fantôme
	if exposure > 0.01 and not player.dead:
		var c := player.global_position
		var r := lerpf(16.0, 8.0, exposure)
		var n := 10
		for k in n:
			var a := TAU * k / n + t * 0.8
			var p := c + Vector2.from_angle(a) * r
			draw_line(p, p + Vector2.from_angle(a) * 4.0, Color(1, 1, 1, 0.3 + 0.6 * exposure), 1.0)
		draw_arc(c, r, 0.0, TAU, 24, Color(1, 1, 1, 0.15 + 0.5 * exposure), 1.0)


# Un œil en amande ; la paupière s'ouvre pendant l'avertissement, la pupille suit le fantôme
func _eye(c: Vector2, u: float) -> void:
	var open := 0.0
	if u >= CLOSED and u < CLOSED + WAKING:
		open = (u - CLOSED) / WAKING * 0.35
	elif u >= CLOSED + WAKING:
		open = minf(1.0, 0.35 + (u - CLOSED - WAKING) / 0.1)
		if u > PERIOD - 0.15:
			open = (PERIOD - u) / 0.15
	var w := 7.0
	var h := 4.5 * open
	draw_circle(c, 9.0, Color(0.06, 0.06, 0.06))
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for k in 9:
		var x := lerpf(-w, w, k / 8.0)
		var y := (1.0 - pow(x / w, 2.0))
		top.append(c + Vector2(x, -y * (1.0 + h)))
		bot.append(c + Vector2(x, y * (1.0 + h * 0.6)))
	var shape := top.duplicate()
	for k in range(bot.size() - 1, -1, -1):
		shape.append(bot[k])
	draw_colored_polygon(shape, Color(0.92, 0.92, 0.92) if open > 0.0 else Color(0.35, 0.35, 0.35))
	if open > 0.0:
		var d := (player.global_position - c).limit_length(1.0) * minf(w - 3.0, 4.0)
		var look := Vector2(clampf(d.x, -3.0, 3.0), clampf(d.y, -h * 0.5, h * 0.5))
		draw_circle(c + look, 2.2 * minf(open * 1.5, 1.0), Color.BLACK)
	else:
		# Paupière close : un trait de cils
		draw_polyline(top, Color(0.85, 0.85, 0.85), 1.0)
		for k in [2, 4, 6]:
			draw_line(top[k], top[k] + Vector2(0, 2.5), Color(0.85, 0.85, 0.85), 1.0)
