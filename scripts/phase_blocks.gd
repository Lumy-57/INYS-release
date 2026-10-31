# Blocs de phase.
# "L" (lumière) : solides seulement quand le fantôme brille, c'est-à-dire quand son dash est disponible.
# "O" (ombre) : solides seulement quand le fantôme est éteint, après avoir utilisé son dash.
# Un bloc qui devrait réapparaître sur le fantôme attend qu'il en sorte : jamais d'écrasement.
extends Node2D

var kind := "L"
var runs: Array = []      # Rect2 en pixels, une par rangée horizontale de tuiles
var player: CharacterBody2D
var shapes: Array = []
var solid: Array = []


func _ready() -> void:
	# Toujours lisibles, même loin de la lumière du fantôme
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	for r in runs:
		var body := StaticBody2D.new()
		if kind == "O":
			body.add_to_group("shadow")
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		cs.shape = rect
		cs.position = r.get_center()
		body.add_child(cs)
		add_child(body)
		shapes.append(cs)
		solid.append(true)
	_update(true)


func _physics_process(_delta: float) -> void:
	_update(false)


func _update(force: bool) -> void:
	var want: bool = player.glowing() if kind == "L" else not player.glowing()
	var body_rect := Rect2(player.global_position - Vector2(5, 7), Vector2(10, 14)).grow(-0.5)
	for i in runs.size():
		var on := want
		if on and not solid[i] and not player.dead and runs[i].intersects(body_rect):
			on = false
		if on != solid[i] or force:
			solid[i] = on
			shapes[i].set_deferred("disabled", not on)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i in runs.size():
		var r: Rect2 = runs[i]
		if kind == "L":
			if solid[i]:
				draw_rect(r, Color(0.8, 0.8, 0.8))
				draw_rect(r.grow(-3), Color(0.55, 0.55, 0.55))
			else:
				_dotted(r, Color(0.6, 0.6, 0.6, 0.5))
		else:
			if solid[i]:
				draw_rect(r, Color(0.12, 0.12, 0.12))
				# Hachures diagonales, tuile par tuile
				var hatch := Color(0.7, 0.7, 0.7)
				var y := r.position.y
				while y < r.end.y:
					var x := r.position.x
					while x < r.end.x:
						draw_line(Vector2(x, y + 16), Vector2(x + 16, y), hatch, 1.0)
						draw_line(Vector2(x, y + 8), Vector2(x + 8, y), hatch, 1.0)
						draw_line(Vector2(x + 8, y + 16), Vector2(x + 16, y + 8), hatch, 1.0)
						x += 16.0
					y += 16.0
				draw_rect(r, Color(0.85, 0.85, 0.85), false, 1.0)
			else:
				_dotted(r, Color(0.45, 0.45, 0.45, 0.4))


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
