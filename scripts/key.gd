# Clé : posée dans le niveau, elle suit le fantôme dès qu'il la touche et ouvre la première porte
# de même numéro qu'il touche (Door.cs). S'il meurt en la portant, elle retourne à sa place.
extends Node2D

signal picked(key)
signal used(key)

enum State { HOME, CARRIED, USED }

var link := 1
var home := Vector2.ZERO
var player: CharacterBody2D
var doors: Array = []
var state := State.HOME
var t := 0.0
var light: PointLight2D


func _ready() -> void:
	position = home
	light = PointLight2D.new()
	light.texture = preload("res://scripts/glow.gd").make_light_texture()
	light.texture_scale = 0.35
	light.energy = 0.9
	add_child(light)


func _physics_process(delta: float) -> void:
	if state == State.USED or player.Dead:
		return
	var body: Rect2 = player.BodyRect()
	if state == State.HOME:
		if body.grow(4.0).has_point(global_position):
			state = State.CARRIED
			picked.emit(self)
		return
	# Portée : elle flotte derrière le fantôme, un peu au-dessus
	var target: Vector2 = player.global_position + Vector2(-player.Facing * 11.0, -10.0)
	global_position = global_position.lerp(target, 1.0 - exp(-12.0 * delta))
	for d in doors:
		if d.Link == link and d.Touches(body):
			d.Open()
			state = State.USED
			used.emit(self)
			var tw := create_tween()
			tw.tween_property(self, "global_position", d.Rect.get_center(), 0.2)
			tw.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
			return


# Après une mort : une clé portée mais pas encore utilisée revient à sa place
func reset() -> void:
	if state == State.CARRIED:
		state = State.HOME
		position = home


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(t * 2.5) * 1.5 if state == State.HOME else 0.0
	var o := Vector2(-4, y)
	draw_arc(o, 3.0, 0.0, TAU, 12, Color.WHITE, 1.5)
	draw_rect(Rect2(o.x + 3, o.y - 0.75, 7, 1.5), Color.WHITE)
	draw_rect(Rect2(o.x + 6, o.y + 0.75, 1.5, 2), Color.WHITE)
	draw_rect(Rect2(o.x + 8.5, o.y + 0.75, 1.5, 3), Color.WHITE)
	# Le numéro, en petits points sous la clé
	for i in link:
		draw_rect(Rect2(-link * 1.5 + i * 3.0 + 0.5, y + 5.0, 2.0, 2.0), Color.WHITE)
