# Base des éléments réglables d'un niveau (vent, plateforme mobile, marée…). Un élément se pose
# dans la scène du niveau, de préférence sous le nœud « Éléments », en glissant sa scène depuis
# levels/elements/. Il se cale tout seul sur la grille de 16 px : son coin en haut à gauche est
# une case de la Carte. Ses réglages sont dans l'Inspecteur ; dans le jeu, level.gd les relit
# avec element_data() et main.gd construit l'élément (voir docs/niveaux.md).
@tool
class_name LevelElement
extends Node2D

const TILE := 16
# Couleurs de l'aperçu dans l'éditeur
const INK := Color(1, 1, 1, 0.9)
const SOFT := Color(1, 1, 1, 0.35)
const NOTE := Color(1, 1, 0.8)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
	else:
		set_process(false)


# Dans l'éditeur, l'aperçu suit les réglages au fur et à mesure qu'on les change
func _process(_delta: float) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		# Calé sur la grille : on peut le glisser à la souris sans viser la case au pixel près
		var on_grid := (position / TILE).round() * TILE
		if on_grid != position:
			position = on_grid
		queue_redraw()


# Ce que l'élément devient dans le jeu : un dictionnaire avec au moins "type" ; main.gd y ajoute
# sa case ("cell", relative au coin de la salle) avant de le construire
func element_data() -> Dictionary:
	return {}


# Une zone de cases, en pixels, relative au nœud
func _zone(cells: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(cells.max(Vector2i.ONE)) * TILE)


func _note(at: Vector2, text: String, color := NOTE) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _dotted(r: Rect2, c: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, 2, 1), c)
		draw_rect(Rect2(x, r.end.y - 1, 2, 1), c)
		x += 4.0
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(r.position.x, y, 1, 2), c)
		draw_rect(Rect2(r.end.x - 1, y, 1, 2), c)
		y += 4.0


func _arrow(from: Vector2, to: Vector2, c: Color) -> void:
	draw_line(from, to, c, 1.0)
	var d := (to - from).normalized()
	if d == Vector2.ZERO:
		return
	draw_line(to, to - d.rotated(0.5) * 4.0, c, 1.0)
	draw_line(to, to - d.rotated(-0.5) * 4.0, c, 1.0)
