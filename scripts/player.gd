# Le fantôme : déplacements serrés façon Celeste.
# Coyote time, buffer de saut, saut variable, apex adouci, wall jump et dash 8 directions.
extends CharacterBody2D

signal died
signal dashed
signal jumped
signal landed

const GhostVisual = preload("res://scripts/ghost_visual.gd")

const RUN_SPEED := 130.0
const GROUND_ACCEL := 1100.0
const GROUND_DECEL := 1400.0
const AIR_ACCEL := 800.0
const AIR_DECEL := 600.0
const OVERSPEED_DECEL := 300.0
const GRAVITY := 950.0
const APEX_GRAVITY_MULT := 0.5
const APEX_THRESHOLD := 40.0
const MAX_FALL := 260.0
const FAST_FALL := 360.0
const JUMP_VELOCITY := -330.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const WALL_SLIDE_MAX := 70.0
const WALL_JUMP_X := 170.0
const WALL_JUMP_Y := -310.0
const WALL_JUMP_LOCK := 0.13
const WALL_CHECK := 3.0
const DASH_SPEED := 380.0
const DASH_TIME := 0.15
const DASH_FREEZE := 0.05
const DASH_END_MULT := 0.55
const MAX_DASHES := 1
const UPDRAFT_SPEED := 170.0
const UPDRAFT_ACCEL := 1500.0

var facing := 1
var dashes := MAX_DASHES
var coyote := 0.0
var jump_buffer := 0.0
var wall_lock := 0.0
var dash_timer := 0.0
var dash_dir := Vector2.ZERO
var dash_pending := false
var freeze := 0.0
var jumping := false
var was_on_floor := false
# Vitesse de chute au moment de toucher le sol : dose la poussière d'atterrissage
var land_speed := 0.0
var dead := false
var mirror := false  # reflet du chapitre Miroir : gauche et droite inversées
var in_updraft_frame := -10  # posé par les courants d'air (updraft.gd)
var afterimage_timer := 0.0

var visual: Node2D
var light: PointLight2D
var trail: CPUParticles2D


func _ready() -> void:
	# Pentes (scripts/slopes.gd) : on y court à vitesse constante et on reste collé en descente ;
	# 45° compte encore comme du sol
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_snap_length = 5.0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 14)
	shape.shape = rect
	add_child(shape)

	visual = GhostVisual.new()
	visual.position = Vector2(0, -1)
	add_child(visual)

	light = PointLight2D.new()
	light.texture = make_light_texture()
	light.texture_scale = 2.0
	light.energy = 1.6
	light.shadow_enabled = true
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 1.5
	add_child(light)

	trail = CPUParticles2D.new()
	trail.amount = 16
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	trail.emission_rect_extents = Vector2(5, 2)
	trail.position = Vector2(0, 6)
	trail.direction = Vector2(0, -1)
	trail.spread = 30
	trail.gravity = Vector2(0, -20)
	trail.initial_velocity_min = 5
	trail.initial_velocity_max = 15
	trail.scale_amount_min = 1
	trail.scale_amount_max = 2
	trail.color_ramp = fade_gradient(Color(1, 1, 1, 0.5))
	add_child(trail)


static func make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(0, 0, 0, 0))
	grad.add_point(0.25, Color(0.8, 0.8, 0.8, 1))
	grad.add_point(0.6, Color(0.25, 0.25, 0.25, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


static func fade_gradient(start: Color) -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, start)
	grad.set_color(1, Color(start.r, start.g, start.b, 0))
	return grad


func _physics_process(delta: float) -> void:
	if dead:
		return
	if freeze > 0.001:
		freeze -= delta
		return

	var ix := _axis_x()
	var iy := Input.get_axis("up", "down")
	var on_floor := is_on_floor()

	if on_floor:
		coyote = COYOTE_TIME
		if dash_timer <= 0.0 and _on_solid_ground():
			dashes = MAX_DASHES
	else:
		coyote -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer -= delta
	wall_lock -= delta

	if Input.is_action_just_pressed("dash") and dashes > 0 and dash_timer <= 0.0:
		_start_dash(ix, iy)
		return

	if dash_timer > 0.0:
		_update_dash(delta, on_floor)
		return

	# Course horizontale
	if wall_lock <= 0.0:
		var accel: float
		if on_floor:
			accel = GROUND_ACCEL if ix != 0.0 else GROUND_DECEL
		else:
			accel = AIR_ACCEL if ix != 0.0 else AIR_DECEL
		# On garde l'élan d'un dash si on pousse dans le même sens
		if absf(velocity.x) > RUN_SPEED and signf(velocity.x) == signf(ix):
			accel = OVERSPEED_DECEL
		velocity.x = move_toward(velocity.x, ix * RUN_SPEED, accel * delta)
	if ix != 0.0:
		facing = int(signf(ix))

	var wall_dir := 0 if on_floor else _wall_dir()

	# Gravité, avec un apex plus doux quand on maintient saut
	var g := GRAVITY
	if absf(velocity.y) < APEX_THRESHOLD and Input.is_action_pressed("jump"):
		g *= APEX_GRAVITY_MULT
	var max_fall := FAST_FALL if iy > 0.0 else MAX_FALL
	if wall_dir != 0 and int(signf(ix)) == wall_dir and velocity.y > 0.0:
		max_fall = WALL_SLIDE_MAX
	if Engine.get_physics_frames() - in_updraft_frame <= 1:
		# Courant d'air : on monte, sans couper le saut
		velocity.y = move_toward(velocity.y, -UPDRAFT_SPEED, UPDRAFT_ACCEL * delta)
		jumping = false
	else:
		velocity.y = move_toward(velocity.y, max_fall, g * delta)

	# Saut variable : relâcher coupe la montée
	if jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT
		jumping = false
	if velocity.y >= 0.0:
		jumping = false

	if jump_buffer > 0.0:
		if coyote > 0.0:
			_jump()
		elif wall_dir != 0:
			_wall_jump(wall_dir)

	var fall := velocity.y
	move_and_slide()
	_after_move(fall)


func _axis_x() -> float:
	var x := Input.get_axis("left", "right")
	return -x if mirror else x


func _update_dash(delta: float, on_floor: bool) -> void:
	# Comme dans Celeste, la direction est lue à la fin du gel : on peut la corriger au dernier moment
	if dash_pending:
		dash_pending = false
		var dir := Vector2(_axis_x(), Input.get_axis("up", "down"))
		if dir != Vector2.ZERO:
			dash_dir = dir.normalized()
	dash_timer -= delta
	velocity = dash_dir * DASH_SPEED
	afterimage_timer -= delta
	if afterimage_timer <= 0.0:
		afterimage_timer = 0.03
		_spawn_afterimage()
	# Sauter pendant un dash au sol garde la vitesse (petit "hyper")
	if jump_buffer > 0.0 and on_floor:
		dash_timer = 0.0
		_jump()
	elif dash_timer <= 0.0:
		velocity *= DASH_END_MULT
	var fall := velocity.y
	move_and_slide()
	_after_move(fall)


func _start_dash(ix: float, iy: float) -> void:
	var dir := Vector2(ix, iy)
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	dash_dir = dir.normalized()
	dash_pending = true
	dashes -= 1
	dash_timer = DASH_TIME
	freeze = DASH_FREEZE
	velocity = Vector2.ZERO
	jumping = false
	afterimage_timer = 0.0
	visual.scale = Vector2(1.3, 0.75) if absf(dash_dir.x) > absf(dash_dir.y) else Vector2(0.75, 1.3)
	dashed.emit()


func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer = 0.0
	coyote = 0.0
	jumping = true
	visual.scale = Vector2(0.7, 1.35)
	jumped.emit()


func _wall_jump(wall_dir: int) -> void:
	velocity = Vector2(-wall_dir * WALL_JUMP_X, WALL_JUMP_Y)
	wall_lock = WALL_JUMP_LOCK
	facing = -wall_dir
	jump_buffer = 0.0
	jumping = true
	visual.scale = Vector2(0.7, 1.35)
	jumped.emit()


# Seule une paroi verticale compte comme mur : une pente ne se grimpe pas en wall jump
func _wall_dir() -> int:
	for d: int in [1, -1]:
		var hit := move_and_collide(Vector2(WALL_CHECK * d, 0), true)
		if hit and absf(hit.get_normal().x) > 0.9:
			return d
	return 0


# Le fantôme brille tant que son dash est disponible (blocs de lumière et d'ombre)
func glowing() -> bool:
	return dead or dashes > 0


# Vrai si au moins une partie du sol touché n'est pas un bloc d'ombre :
# l'ombre porte le fantôme mais ne recharge pas son dash.
func _on_solid_ground() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7:
			var other := c.get_collider() as Node
			if other and not other.is_in_group("shadow"):
				return true
	return false


func _after_move(fall: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		land_speed = fall
		visual.scale = Vector2(1.35, 0.7)
		landed.emit()
	was_on_floor = on_floor


func _spawn_afterimage() -> void:
	var ghost := GhostVisual.new()
	ghost.animated = false
	ghost.facing = facing
	ghost.global_position = visual.global_position
	ghost.scale = visual.scale
	ghost.tint = Color(1, 1, 1, 0.5)
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


func _process(delta: float) -> void:
	visual.scale = visual.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	# Sur une pente, la boîte du fantôme ne touche que par un coin : on descend le dessin
	# d'autant pour qu'il pose bien sur le biais
	var sink := 0.0
	if is_on_floor() and not dead:
		var n := get_floor_normal()
		if absf(n.y) > 0.1:
			sink = 5.0 * absf(n.x / n.y)
	visual.position.y = lerpf(visual.position.y, -1.0 + sink, 1.0 - exp(-25.0 * delta))
	visual.facing = facing
	visual.gaze = velocity / 180.0
	visual.idle = visual.idle + delta if velocity.length() < 1.0 and not dead else 0.0
	# Le fantôme pâlit quand son dash est épuisé : la lumière en dit autant
	var has_dash := dashes > 0 or dash_timer > 0.0
	var target_energy := 1.6 if has_dash else 0.8
	light.energy = lerpf(light.energy, target_energy, 1.0 - exp(-10.0 * delta))
	visual.tint = Color.WHITE if has_dash else Color(0.55, 0.55, 0.55)


func die() -> void:
	if dead or Settings.invincible:
		return
	dead = true
	velocity = Vector2.ZERO
	visual.visible = false
	light.visible = false
	trail.emitting = false
	died.emit()


# Propulsion par un ressort : rend le dash et annule le dash en cours
func launch(v: Vector2) -> void:
	velocity = v
	dashes = MAX_DASHES
	dash_timer = 0.0
	freeze = 0.0
	coyote = 0.0
	jump_buffer = 0.0
	jumping = false
	visual.scale = Vector2(0.65, 1.4)


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	dead = false
	dashes = MAX_DASHES
	dash_timer = 0.0
	freeze = 0.0
	jump_buffer = 0.0
	coyote = 0.0
	wall_lock = 0.0
	jumping = false
	visual.visible = true
	visual.scale = Vector2(0.6, 1.4)
	light.visible = true
	trail.emitting = true
