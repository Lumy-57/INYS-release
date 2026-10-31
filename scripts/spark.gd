# Étincelle : objet caché, facultatif, à ramasser une fois par niveau.
# Une étincelle déjà trouvée lors d'une partie précédente apparaît en creux.
extends Area2D

signal collected(spark)

var cell := Vector2i.ZERO
var known := false  # déjà trouvée avant
var taken := false
var t := 0.0
var light: PointLight2D


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7
	shape.shape = circle
	add_child(shape)
	light = PointLight2D.new()
	light.texture = preload("res://scripts/player.gd").make_light_texture()
	light.texture_scale = 0.3
	light.energy = 0.5 if known else 0.9
	add_child(light)
	body_entered.connect(func(b):
		if not taken:
			collected.emit(self))


func take() -> void:
	taken = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(light, "energy", 0.0, 0.25)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(t * 3.0) * 1.5
	var r := 5.0 + sin(t * 6.0) * 0.6
	var pts := PackedVector2Array()
	for i in 8:
		var a := t * 1.5 + i * TAU / 8.0
		var d := r if i % 2 == 0 else r * 0.35
		pts.append(Vector2(cos(a), sin(a) * 1.0) * d + Vector2(0, y))
	if known:
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.6), 1.0)
	else:
		draw_colored_polygon(pts, Color.WHITE)
