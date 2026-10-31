# Cloche : sonne quand le fantôme la touche et inverse les blocs de carillon ("a" et "b").
# Elle se réarme quand le fantôme en est sorti et s'est posé (ou après un court délai) :
# traverser une cloche en montant puis en redescendant ne la fait sonner qu'une fois.
extends Area2D

signal rung(bell)

const REARM_TIME := 0.8

var player: CharacterBody2D
var armed := true
var since := 0.0
var swing := 0.0
var t := 0.0
var light: PointLight2D


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 14)
	cs.shape = rect
	add_child(cs)
	light = PointLight2D.new()
	light.texture = preload("res://scripts/player.gd").make_light_texture()
	light.texture_scale = 0.3
	light.energy = 0.35
	add_child(light)
	body_entered.connect(_on_enter)


func _on_enter(body) -> void:
	if body != player or player.dead or not armed:
		return
	armed = false
	since = 0.0
	rung.emit(self)


func _physics_process(delta: float) -> void:
	if armed:
		return
	since += delta
	if not overlaps_body(player) and (player.is_on_floor() or since >= REARM_TIME or player.dead):
		armed = true


# Toutes les cloches du niveau bougent ensemble quand l'une d'elles sonne
func shake() -> void:
	swing = 1.0
	light.energy = 1.2


func _process(delta: float) -> void:
	t += delta
	swing = maxf(swing - delta * 1.2, 0.0)
	light.energy = lerpf(light.energy, 0.35, 1.0 - exp(-4.0 * delta))
	rotation = sin(t * 14.0) * 0.45 * swing
	queue_redraw()


func _draw() -> void:
	# Origine au centre de la tuile ; la cloche pend depuis le haut de la tuile
	var c := Color(0.9, 0.9, 0.9)
	draw_line(Vector2(0, -8), Vector2(0, -6), c, 1.0)
	var body := PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(4, -2), Vector2(5, 3), Vector2(7, 5), Vector2(-7, 5), Vector2(-5, 3), Vector2(-4, -2)])
	draw_colored_polygon(body, c)
	draw_line(Vector2(-4, 1), Vector2(4, 1), Color(0.55, 0.55, 0.55), 1.0)
	draw_circle(Vector2(sin(t * 14.0 + 1.0) * 2.0 * swing, 6.5), 1.5, c)
