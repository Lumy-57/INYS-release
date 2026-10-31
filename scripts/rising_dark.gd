# Marée de ténèbres : elle monte du fond du niveau dès que le fantôme bouge.
# Y plonger, c'est mourir. Trop loin derrière, elle accélère pour revenir à portée.
# Après une mort, elle repart un peu en dessous de la bougie.
extends Node2D

const SPEED := 26.0        # px/s
const REACH := 150.0       # au-delà de cet écart sous le fantôme, elle rattrape
const CATCH_UP := 1.6      # px/s de plus par pixel d'écart en trop
const BELOW_RESPAWN := 96.0

var player: CharacterBody2D
var width := 480.0
var start_top := 0.0       # ligne de départ, donnée par "~"
var top := 0.0
var moving := false
var anchor := Vector2.INF
var t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	z_index = 4
	top = start_top


func reset(respawn: Vector2) -> void:
	top = maxf(start_top, respawn.y + BELOW_RESPAWN)
	moving = false
	anchor = Vector2.INF


func _physics_process(delta: float) -> void:
	if player.dead or not player.is_physics_processing():
		return
	if anchor == Vector2.INF:
		anchor = player.global_position
	if not moving:
		moving = player.global_position.distance_to(anchor) > 2.0
		return
	var feet := player.global_position.y + 7.0
	var speed := SPEED + maxf(top - feet - REACH, 0.0) * CATCH_UP
	top -= speed * delta
	if feet > top + 3.0:
		player.die()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= width:
		pts.append(Vector2(x, top + sin(x * 0.07 + t * 3.0) * 2.0 + sin(x * 0.19 - t * 5.0) * 1.0))
		x += 6.0
	var edge := pts.duplicate()
	pts.append(Vector2(width, top + 2000.0))
	pts.append(Vector2(0, top + 2000.0))
	draw_colored_polygon(pts, Color(0, 0, 0))
	# Bord blanc qui frémit, et quelques lueurs prises dans la masse
	draw_polyline(edge, Color(0.95, 0.95, 0.95, 0.7 + 0.3 * sin(t * 11.0)), 1.0)
	for i in 14:
		var px := fmod(i * 37.0 + t * (8.0 + i), width)
		var py := top + 10.0 + fmod(i * 23.0 + t * 6.0, 60.0)
		draw_rect(Rect2(px, py, 1, 1), Color(1, 1, 1, 0.35))
