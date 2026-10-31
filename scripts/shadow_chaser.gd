# Ombre poursuivante : elle refait exactement le chemin du fantôme, avec un temps de retard.
# Elle s'éveille dès que le fantôme quitte son point d'apparition ; la toucher, c'est mourir.
# S'arrêter trop longtemps, c'est la laisser vous rattraper.
# Dans l'épilogue (companion), elle ne fait plus de mal : elle marche avec le fantôme,
# s'arrête à côté de lui quand il s'arrête, et n'est plus toute noire.
extends Node2D

const GhostVisual = preload("res://scripts/ghost_visual.gd")

const DELAY := 66          # retard, en images de physique (~1,1 s)
const WAKE := 30           # elle est entièrement levée WAKE images avant de partir
const HIT := 8.0           # distance de contact
const BESIDE := 14.0       # la compagne s'arrête à cette distance

var player: CharacterBody2D
var companion := false     # à régler avant add_child
var trail: Array = []      # [position, facing]
var anchor := Vector2.INF  # point d'apparition du fantôme
var awake := false
var idx := 0
var t := 0.0
var rim: Node2D
var body: Node2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	rim = GhostVisual.new()
	rim.tint = Color(0.85, 0.85, 0.85, 0.8)
	rim.scale = Vector2(1.2, 1.15)
	rim.use_parent_material = true
	rim.show_behind_parent = true
	add_child(rim)
	body = GhostVisual.new()
	body.tint = Color(0.03, 0.03, 0.03)
	if companion:
		rim.tint = Color(1.0, 0.85, 0.75, 0.8)
		body.tint = Color(0.22, 0.17, 0.3)
	body.use_parent_material = true
	body.show_behind_parent = true
	add_child(body)
	z_index = 5
	reset()


func reset() -> void:
	trail.clear()
	awake = false
	idx = 0
	anchor = Vector2.INF
	visible = false
	modulate.a = 0.15


func _physics_process(_delta: float) -> void:
	# Pendant la carte de fin de niveau, tout s'arrête
	if player.dead or not player.is_physics_processing():
		return
	if anchor == Vector2.INF:
		anchor = player.global_position
		return
	if not awake:
		if player.global_position.distance_to(anchor) < 2.0:
			return
		awake = true
		trail.append([anchor, player.facing])
	trail.append([player.global_position, player.facing])
	if companion:
		_walk_along()
		return
	var i := trail.size() - 1 - DELAY
	visible = true
	if i < 0:
		# Elle se lève là où le fantôme est apparu
		_place(trail[0])
		modulate.a = clampf(float(trail.size()) / float(DELAY - WAKE), 0.15, 1.0)
		return
	modulate.a = 1.0
	_place(trail[i])
	# On ne garde que ce qui reste à parcourir
	if i > 256:
		trail = trail.slice(i)
	if global_position.distance_to(player.global_position) < HIT:
		player.die()


# La compagne avance sur le chemin du fantôme, un pas par image (deux si elle traîne),
# et attend à côté de lui au lieu de le rejoindre
func _walk_along() -> void:
	visible = true
	modulate.a = minf(modulate.a + 0.03, 1.0)
	if global_position.distance_to(player.global_position) > BESIDE:
		var behind := trail.size() - 1 - idx
		idx = mini(idx + (2 if behind > DELAY else 1), trail.size() - 1)
	_place(trail[idx])
	if idx > 256:
		trail = trail.slice(idx)
		idx = 0


func _place(p: Array) -> void:
	global_position = p[0]
	rim.facing = p[1]
	body.facing = p[1]


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# Deux yeux blancs, et une traîne de fumée noire
	var f: int = body.facing
	var bob := sin(body.t * 3.0) * 0.8
	var ex := 1.5 * f
	draw_rect(Rect2(ex - 3.5, -5 + bob, 2, 3), Color(1, 1, 1))
	draw_rect(Rect2(ex + 1.5, -5 + bob, 2, 3), Color(1, 1, 1))
