# Plateforme mobile (élément levels/elements/plateforme.gd) : fait l'aller-retour en ligne droite
# entre ses deux bouts, A et B, avec un arrêt à chaque bout. L'aller et le retour ont chacun leur
# vitesse moyenne et leur accélération ; elle peut attendre que le fantôme monte dessus pour
# partir. Elle tient à jour sa vitesse (motion), que le fantôme garde en la quittant.
extends AnimatableBody2D

enum { ALWAYS, ON_BOARD, ON_BOARD_BOTH_ENDS }
enum { LINEAR, SMOOTH_BOTH, SMOOTH_START, SMOOTH_END }

var size := Vector2.ZERO
var start := Vector2.ZERO     # bout A (coin haut gauche), en pixels
var course := Vector2.ZERO    # de A à B, en pixels
var speed := 60.0             # vitesse moyenne de l'aller (A → B), px/s
var speed_back := 60.0        # vitesse moyenne du retour (B → A), px/s
var ease_out := LINEAR        # accélération de l'aller
var ease_back := LINEAR       # accélération du retour
var pause := 0.4              # secondes d'arrêt à chaque bout
var start_at := 0.0           # position de départ : 0 = en A, 1 = en B
var trigger := ALWAYS         # quand elle part (toujours, ou quand le fantôme est dessus)
var player: CharacterBody2D
var motion := Vector2.ZERO    # vitesse de la dernière image, px/s
var leg := 1                  # 1 = aller (A → B), -1 = retour (B → A)
var t := 0.0                  # secondes écoulées dans le trajet en cours
var wait := 0.0
var hold := false             # attend que le fantôme monte dessus


func _ready() -> void:
	sync_to_physics = true
	# Toujours lisible, même loin de la lumière du fantôme
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size * 0.5
	add_child(cs)
	if start_at >= 1.0:
		leg = -1
		position = start + course
	else:
		leg = 1
		t = clampf(start_at, 0.0, 1.0) * _duration()
		position = start + course * _ease(t / _duration(), ease_out) if _duration() > 0.0 else start
	hold = _holds()


func _duration() -> float:
	var v := speed if leg > 0 else speed_back
	return course.length() / maxf(v, 1.0)


# Part parcourue (0 → 1) après une part p (0 → 1) du temps du trajet
static func _ease(p: float, kind: int) -> float:
	match kind:
		SMOOTH_BOTH:
			return 0.5 - 0.5 * cos(PI * p)
		SMOOTH_START:
			return 1.0 - cos(PI * 0.5 * p)
		SMOOTH_END:
			return sin(PI * 0.5 * p)
	return p


# Attend-elle le fantôme avant le trajet qui vient ?
func _holds() -> bool:
	return trigger == ON_BOARD_BOTH_ENDS or (trigger == ON_BOARD and leg > 0)


func _player_on() -> bool:
	return player != null and player.get("floor_body") == self


func _physics_process(delta: float) -> void:
	var prev := position
	_step(delta)
	motion = (position - prev) / delta if delta > 0.0 else Vector2.ZERO


func _step(delta: float) -> void:
	var dur := _duration()
	if dur <= 0.0:
		return
	if wait > 0.0:
		wait -= delta
		return
	if hold:
		if not _player_on():
			return
		hold = false
	t += delta
	var p := minf(t / dur, 1.0)
	var f := _ease(p, ease_out if leg > 0 else ease_back)
	position = start + course * (f if leg > 0 else 1.0 - f)
	if p >= 1.0:
		leg = -leg
		t = 0.0
		wait = pause
		hold = _holds()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.75, 0.75))
	draw_rect(Rect2(Vector2(2, 3), size - Vector2(4, 5)), Color(0.3, 0.3, 0.3))
	var x := 4.0
	while x < size.x - 2.0:
		draw_rect(Rect2(x, 6, 2, 2), Color(0.85, 0.85, 0.85))
		x += 8.0
