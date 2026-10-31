# Blocs de carillon.
# "a" : solides au repos. "b" : solides une fois les cloches sonnées. Chaque cloche inverse les deux.
# Comme les blocs de phase, un bloc qui devrait réapparaître sur le fantôme attend qu'il en sorte.
# L'état est mémorisé à chaque bougie : après une mort, on repart de l'état de la dernière bougie.
extends Node2D

var runs_a: Array = []    # Rect2 en pixels
var runs_b: Array = []
var player: CharacterBody2D
var rung := false         # false : "a" solides, true : "b" solides
var saved := false
var blocks: Array = []    # [rect, kind, shape, solid]
var flash := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	for pair in [[runs_a, "a"], [runs_b, "b"]]:
		for r in pair[0]:
			var body := StaticBody2D.new()
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = r.size
			cs.shape = rect
			cs.position = r.get_center()
			body.add_child(cs)
			add_child(body)
			blocks.append([r, pair[1], cs, true])
	_update(true)


func ring() -> void:
	rung = not rung
	flash = 1.0


func save() -> void:
	saved = rung


func reset() -> void:
	rung = saved
	_update(true)


func _physics_process(_delta: float) -> void:
	_update(false)


func _update(force: bool) -> void:
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14)).grow(-0.5)
	for b in blocks:
		var on: bool = (b[1] == "b") == rung
		if on and not b[3] and not force and not player.dead and b[0].intersects(body_rect):
			on = false
		if on != b[3] or force:
			b[3] = on
			b[2].set_deferred("disabled", not on)


func _process(delta: float) -> void:
	flash = maxf(flash - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	for b in blocks:
		var r: Rect2 = b[0]
		var light: bool = b[1] == "a"
		if b[3]:
			var fill := Color(0.78, 0.78, 0.78) if light else Color(0.32, 0.32, 0.32)
			draw_rect(r, fill.lerp(Color.WHITE, flash * 0.5))
			draw_rect(r, Color(0.95, 0.95, 0.95), false, 1.0)
			# Une petite cloche par tuile : pleine pour "a", évidée pour "b"
			var y := r.position.y
			while y < r.end.y:
				var x := r.position.x
				while x < r.end.x:
					_bell_mark(Vector2(x + 8, y + 8), light)
					x += 16.0
				y += 16.0
		else:
			_dotted(r, Color(0.7, 0.7, 0.7, 0.45))


func _bell_mark(c: Vector2, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(-1.5, -4), c + Vector2(1.5, -4), c + Vector2(3, 0), c + Vector2(4, 3), c + Vector2(-4, 3), c + Vector2(-3, 0)])
	if filled:
		draw_colored_polygon(pts, Color(0.35, 0.35, 0.35))
	else:
		pts.append(pts[0])
		draw_polyline(pts, Color(0.85, 0.85, 0.85), 1.0)
	draw_rect(Rect2(c + Vector2(-1, 3), Vector2(2, 2)), Color(0.35, 0.35, 0.35) if filled else Color(0.85, 0.85, 0.85))


func _dotted(r: Rect2, c: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, 2, 1), c)
		draw_rect(Rect2(x, r.end.y - 1, 2, 1), c)
		x += 4.0
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(r.position.x, y, 1, 2), c)
		draw_rect(Rect2(r.end.x - 1, y, 1, 2), c)
		y += 4.0
