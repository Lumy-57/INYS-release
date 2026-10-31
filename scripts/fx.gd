# Sensations de jeu : poussière, arrêt sur image et flash à la mort, onde de choc,
# poussée de caméra au dash, et transition en iris centrée sur le fantôme.
extends Node

const PlayerScript = preload("res://scripts/player.gd")

const HITSTOP := 0.12
const HARD_LANDING := 230.0
const KICK := 3.0

var main: Node
var kick := Vector2.ZERO
var hitstops := 0
var layer: CanvasLayer
var flash: ColorRect
var iris: ColorRect
var card: Label


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	layer.add_child(flash)

	iris = ColorRect.new()
	iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;
uniform vec2 center = vec2(0.5);
uniform float radius = 2.0;
uniform float aspect = 1.7778;
void fragment() {
	float d = length((UV - center) * vec2(aspect, 1.0));
	// Un fin liseré de lumière borde le cercle qui se referme
	float ring = step(radius - 0.012, d) * step(d, radius);
	float dark = step(radius, d);
	COLOR = mix(vec4(0.0, 0.0, 0.0, dark), vec4(1.0), ring * step(0.001, radius) * step(radius, 1.2));
}
"""
	iris.material = mat
	layer.add_child(iris)

	card = Label.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size", 12)
	card.modulate.a = 0.0
	layer.add_child(card)


func _process(delta: float) -> void:
	kick = kick.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * delta))


# --- Poussière -------------------------------------------------------------

func on_jumped(player: Node2D) -> void:
	if player.wall_lock > 0.0:
		# Wall jump : la poussière part du mur, à l'opposé de la direction prise
		var side: int = -player.facing
		puff(player.global_position + Vector2(side * 6, 2), Vector2(-side, 0), 5)
	else:
		puff(player.global_position + Vector2(0, 7), Vector2.UP, 5)


func on_landed(player: Node2D) -> void:
	# Plus la chute est rapide, plus la poussière est fournie et part loin
	var force := clampf((player.land_speed - 60.0) / (HARD_LANDING - 60.0), 0.0, 1.0)
	var at: Vector2 = player.global_position + Vector2(0, 7)
	var amount := 2 + int(round(force * 4.0))
	puff(at, Vector2.LEFT, amount, 0.6 + force * 0.8)
	puff(at, Vector2.RIGHT, amount, 0.6 + force * 0.8)
	if player.land_speed >= HARD_LANDING:
		main.add_shake(1.0)


func on_dashed(player: Node2D) -> void:
	var dir := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
	if dir == Vector2.ZERO:
		dir = Vector2(player.facing, 0)
	kick = dir.normalized() * KICK


func puff(pos: Vector2, dir: Vector2, amount: int, force := 1.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.35
	p.direction = dir
	p.spread = 35
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 15 * force
	p.initial_velocity_max = 40 * force
	p.damping_min = 60
	p.damping_max = 90
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = PlayerScript.fade_gradient(Color(0.8, 0.8, 0.8, 0.7))
	_spawn(p, pos, 0.5)


# --- Mort et réapparition --------------------------------------------------

# Le fantôme reste figé, plein blanc, le temps de l'arrêt sur image, puis éclate
func on_died(player: Node2D) -> void:
	player.visual.visible = true
	player.visual.scale = Vector2(1.25, 1.25)
	flash.color.a = 0.25
	# Le fondu du flash suit le temps du jeu : il attend la fin de l'arrêt
	create_tween().tween_property(flash, "color:a", 0.0, 0.25)
	await hitstop(HITSTOP)
	player.visual.visible = false
	_spawn(Ring.new(), player.global_position, 0.5)


# Fige le monde un instant. Jamais tout à fait zéro : les chronos divisent par time_scale.
func hitstop(time: float) -> void:
	hitstops += 1
	Engine.time_scale = 0.02
	await get_tree().create_timer(time, true, false, true).timeout
	hitstops -= 1
	if hitstops == 0:
		Engine.time_scale = Settings.speed()


func on_respawned(pos: Vector2) -> void:
	# Des particules convergent vers le point d'apparition
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.3
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 18
	p.gravity = Vector2.ZERO
	p.radial_accel_min = -260
	p.radial_accel_max = -200
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = PlayerScript.fade_gradient(Color(1, 1, 1, 0.8))
	_spawn(p, pos, 0.5)


func _spawn(node: Node2D, pos: Vector2, life: float) -> void:
	main.level_root.add_child(node)
	node.global_position = pos
	if node is CPUParticles2D:
		node.emitting = true
	get_tree().create_timer(life, false).timeout.connect(node.queue_free)


class Ring extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var p := minf(t / 0.35, 1.0)
		var r := 4.0 + 40.0 * (1.0 - pow(1.0 - p, 3.0))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1, 1, 1, 1.0 - p), 2.0 * (1.0 - p) + 0.5)


# --- Transitions -----------------------------------------------------------

func _iris_target(player: Node2D) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var c: Vector2 = (player.global_position - main.camera.get_screen_center_position()) / vp + Vector2(0.5, 0.5)
	return c.clamp(Vector2(0.05, 0.05), Vector2(0.95, 0.95))


func iris_close(player: Node2D, time := 0.6) -> void:
	var tw := create_tween()
	tw.tween_method(_set_iris.bind(player), 1.2, 0.06, time * 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_interval(time * 0.1)
	tw.tween_method(_set_iris.bind(player), 0.06, 0.0, time * 0.15)
	await tw.finished


func iris_open(player: Node2D, time := 0.6) -> void:
	var tw := create_tween()
	tw.tween_method(_set_iris.bind(player), 0.0, 2.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished


# Le centre suit le fantôme à chaque image, même pendant que la caméra se replace
func _set_iris(r: float, player: Node2D) -> void:
	var mat: ShaderMaterial = iris.material
	mat.set_shader_parameter("radius", r)
	mat.set_shader_parameter("center", _iris_target(player))


func show_card(text: String) -> void:
	card.text = text
	create_tween().tween_property(card, "modulate:a", 1.0, 0.25)


func hide_card() -> void:
	create_tween().tween_property(card, "modulate:a", 0.0, 0.2)
