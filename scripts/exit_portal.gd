# Sortie du niveau : une faille de lumière.
# La sortie secrète ("e") est son envers : une faille d'ombre bordée de lumière, qui ouvre la face B.
extends Area2D

signal entered(portal)

var t := 0.0
var secret := false
var veil: Node2D = null   # la fausse paroi qui cache la sortie secrète
var cell := Vector2i.ZERO
var light: PointLight2D


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 28)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	add_child(shape)
	light = PointLight2D.new()
	light.texture = preload("res://scripts/player.gd").make_light_texture()
	light.texture_scale = 1.0
	light.energy = 0.8 if secret else 1.3
	light.position = Vector2(0, -16)
	light.shadow_enabled = true
	add_child(light)
	body_entered.connect(func(b): entered.emit(self, b))


func _veiled() -> bool:
	return veil != null and not veil.is_found(cell)


func _process(delta: float) -> void:
	t += delta
	# Tant que la paroi n'est pas découverte, la sortie ne luit pas : rien ne la trahit
	light.visible = not _veiled()
	queue_redraw()


func _draw() -> void:
	if _veiled():
		return
	if secret:
		# Le cœur est noir, les bords battent comme une flamme à l'envers
		for i in range(3):
			var w := 4.0 + i * 3.0 + sin(t * 2.0 - i) * 1.5
			draw_rect(Rect2(-w * 0.5, -30, w, 30), Color(1, 1, 1, 0.5 - i * 0.15), false, 1.0)
		draw_rect(Rect2(-2, -29, 4, 28), Color.BLACK)
		for i in range(4):
			var k := fmod(t * 0.6 + i * 0.25, 1.0)
			draw_rect(Rect2(sin(t * 3.0 + i * 2.0) * 5.0 - 0.5, -2.0 - k * 34.0, 1, 1), Color(1, 1, 1, 1.0 - k))
		return
	for i in range(3):
		var w := 3.0 + i * 3.0 + sin(t * 3.0 + i) * 1.0
		var a := 1.0 - i * 0.3
		draw_rect(Rect2(-w * 0.5, -30, w, 30), Color(1, 1, 1, a * 0.6))
	draw_rect(Rect2(-1, -30, 2, 30), Color.WHITE)
