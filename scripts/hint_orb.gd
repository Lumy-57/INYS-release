# Petite orbe blanche qui tourne autour du fantôme. Quand il approche d'un indice
# du niveau, elle se pose près de lui et le lui dit, puis repart tourner.
# Les indices sont donnés par main (déjà passés dans _hint_text) au chargement du niveau.
# Chapitre Compagnie : elle montre les pierres cachées (orb_blocks.gd) et, quand le
# fantôme dash, elle file devant lui dans la même direction pour éclairer la suite.
extends Node2D

const TILE := 16
const ORBIT := Vector2(15, 6)   # ellipse autour du fantôme
const PERCH := Vector2(11, -17) # où elle se pose pour parler
const REACH := Vector2(120, 72) # distance à laquelle un indice se déclenche
const TRAIL := 6
const WRAP := 200.0  # largeur max de la bulle avant retour à la ligne
const FLARE_DIST := 84.0  # jusqu'où elle file devant le fantôme quand il dash
const FLARE_TIME := 0.5   # temps passé devant avant de revenir

var player: Node2D
var main: Node  # sur l'écran titre, l'orbe tourne mais se tait
var groups: Array = []  # [{"pos": Vector2, "text": String}]
var current := -1
var t := 0.0
var speak := 0.0  # 0 : tourne ; 1 : posée et parle
var trail: Array = []
var light: PointLight2D
var bubble: Label
var scout := false  # chapitre Compagnie : elle éclaire les pierres cachées
var flare := 0.0
var flare_from := Vector2.ZERO
var flare_dir := Vector2.ZERO


func _ready() -> void:
	z_index = 5
	light = PointLight2D.new()
	light.texture = preload("res://scripts/player.gd").make_light_texture()
	light.texture_scale = 0.22
	light.energy = 0.6
	add_child(light)

	# Le texte reste lisible dans le noir : il ne dépend pas de la lumière
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	bubble = Label.new()
	bubble.material = unshaded
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bubble.add_theme_font_size_override("font_size", 9)
	bubble.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	bubble.add_theme_constant_override("outline_size", 4)
	bubble.top_level = true
	bubble.z_as_relative = false
	bubble.z_index = 6
	bubble.modulate.a = 0.0
	add_child(bubble)


# hints : [x, y, texte] en cases, textes déjà prêts. Les lignes qui se suivent
# (même endroit, ligne d'en dessous) forment un seul indice.
func set_hints(hints: Array) -> void:
	groups.clear()
	var font := ThemeDB.fallback_font
	var last := Vector2(-999, -999)
	for h in hints:
		var cell := Vector2(h[0], h[1])
		var w := font.get_string_size(h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var center := cell * TILE + Vector2(w / 2.0, 8)
		var d := cell - last
		if not groups.is_empty() and absf(d.y) <= 1 and absf(d.x) <= 16:
			var g: Dictionary = groups[-1]
			g["text"] += "\n" + h[2]
			g["sum"] += center
			g["n"] += 1
		else:
			groups.append({"text": h[2], "sum": center, "n": 1})
		last = cell
	for g in groups:
		g["pos"] = g["sum"] / g["n"]
	current = -1
	speak = 0.0
	bubble.modulate.a = 0.0
	snap()


# Revient d'un coup près du fantôme (nouveau niveau, réapparition)
func snap() -> void:
	flare = 0.0
	trail.clear()
	if player:
		position = player.global_position + Vector2(0, -12)


func set_scout(on: bool) -> void:
	scout = on
	light.texture_scale = 0.55 if on else 0.22


# Le fantôme vient de dasher : elle part devant, dans la même direction
func dash_ahead(dir: Vector2) -> void:
	if not scout or dir == Vector2.ZERO:
		return
	flare = FLARE_TIME
	flare_from = player.global_position
	flare_dir = dir.normalized()


# Points qui révèlent les pierres cachées : l'orbe d'abord, puis le fantôme qu'elle entoure
func lit_points() -> Array:
	if not scout or player == null or player.dead:
		return []
	return [global_position, player.global_position]


func _nearest() -> int:
	var best := -1
	var best_d := 1.0
	for i in groups.size():
		var d: Vector2 = (groups[i]["pos"] - player.global_position) / REACH
		var k := d.length()
		# Un indice déjà dit reste un peu plus longtemps
		if i == current:
			k *= 0.75
		if k < best_d:
			best_d = k
			best = i
	return best


func _process(delta: float) -> void:
	if player == null:
		return
	t += delta
	var target := -1 if main and main.on_title else _nearest()
	if target != current:
		# Change d'indice : la bulle s'efface d'abord
		bubble.modulate.a = move_toward(bubble.modulate.a, 0.0, delta * 5.0)
		if bubble.modulate.a <= 0.0:
			current = target
			if current >= 0:
				_set_text(groups[current]["text"])
				bubble.visible_ratio = 0.0
	speak = move_toward(speak, 1.0 if current >= 0 and target == current else 0.0, delta * 2.5)

	# Tourne autour du fantôme ; se pose sur son épaule pour parler
	var p := player.global_position
	var a := t * 2.4
	var orbit := Vector2(cos(a) * ORBIT.x, sin(a) * ORBIT.y - 6)
	var perch := PERCH + Vector2(0, sin(t * 2.0) * 1.5)
	var goal := p + orbit.lerp(perch, ease(speak, -2.0))
	var follow := 9.0
	if flare > 0.0:
		flare -= delta
		# La direction du dash peut encore être corrigée pendant le petit gel
		if player.dash_timer > 0.0:
			flare_dir = player.dash_dir
		goal = flare_from + flare_dir * FLARE_DIST + Vector2(0, sin(t * 8.0) * 1.5)
		follow = 16.0
	position = position.lerp(goal, 1.0 - exp(-delta * follow))

	trail.push_front(position)
	if trail.size() > TRAIL:
		trail.pop_back()
	light.energy = 0.55 + 0.15 * sin(t * 5.0) + speak * 0.2 + (0.35 if scout else 0.0)

	if current >= 0 and target == current:
		bubble.modulate.a = move_toward(bubble.modulate.a, 1.0, delta * 4.0)
		var n := maxi(bubble.get_total_character_count(), 1)
		bubble.visible_ratio = minf(bubble.visible_ratio + delta * 40.0 / n, 1.0)
	_place_bubble()
	queue_redraw()


func _set_text(text: String) -> void:
	bubble.text = text
	bubble.autowrap_mode = TextServer.AUTOWRAP_OFF
	bubble.custom_minimum_size = Vector2.ZERO
	bubble.size = Vector2.ZERO
	if bubble.get_combined_minimum_size().x > WRAP:
		bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble.custom_minimum_size.x = WRAP


# La bulle se tient au-dessus de l'orbe, sans sortir de l'écran
func _place_bubble() -> void:
	var sz := bubble.get_combined_minimum_size()
	bubble.size = sz
	var pos := global_position + Vector2(-sz.x / 2.0, -sz.y - 6)
	var cam := get_viewport().get_camera_2d()
	if cam:
		var c := cam.get_screen_center_position()
		var half := get_viewport_rect().size / cam.zoom / 2.0
		pos.x = clampf(pos.x, c.x - half.x + 4, c.x + half.x - sz.x - 4)
		pos.y = clampf(pos.y, c.y - half.y + 18, c.y + half.y - sz.y - 4)
	bubble.global_position = pos.round()


func _draw() -> void:
	for i in range(trail.size() - 1, 0, -1):
		var k := 1.0 - float(i) / TRAIL
		draw_circle(to_local(trail[i]), 1.6 * k, Color(1, 1, 1, 0.25 * k))
	var r := 2.4 + sin(t * 6.0) * 0.3
	draw_circle(Vector2.ZERO, r + 2.0, Color(1, 1, 1, 0.12 + speak * 0.1))
	draw_circle(Vector2.ZERO, r, Color.WHITE)
