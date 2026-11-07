# Racine d'une scène de niveau. La carte se peint dans la TileMapLayer « Carte » (une tuile par
# case de 16 px, palette levels/tiles.tres), et dans d'autres TileMapLayer enfants du niveau pour
# poser plusieurs tuiles sur une même case. Les éléments réglables (vent, plateformes mobiles,
# marée…, levels/elements/) sont posés sous « Éléments », les indices sous « Indices ». Au
# lancement, level_data.gd relit chaque scène et en refait une grille de caractères par calque,
# que main.gd sait construire : chaque tuile vaut un caractère de CHARS (voir docs/niveaux.md).
@tool
class_name LevelScene
extends Node2D

const TILE := 16
const COLS := 8  # colonnes de levels/tiles.png
# Caractère de chaque tuile de la palette, dans l'ordre de levels/tiles.png (tools/make_tiles.py).
# Les icônes - L O X | 1 2 a b M W S ~ H Y y _ ( ) 0 ne sont plus des tuiles (elles sont devenues
# des éléments réglables, levels/elements/) : elles restent dans l'image pour ne rien décaler.
const CHARS := "#%=^v<>-" + "LOX|12ab" + "iMWSB~HR" + "PCDEe*Yy" + "_()0p"
# Source 1 de la palette (levels/murs.png, tools/make_murs.py) : les murs taillés, une rangée par
# style, peints avec les terrains pour que l'éditeur choisisse les bords tout seul
const SHAPED := "rtg"
# Dernière rangée de cette source : les pentes (scripts/slopes.gd), raides puis douces
const SLOPE_CHARS := "jkun" + "cdfh" + "lmos"

## Nom affiché du niveau. Il sert aussi de clé à la sauvegarde : le changer remet ses records à zéro.
@export var level_name := "":
	set(v):
		level_name = v
		update_configuration_warnings()
## Chapitre du niveau (musique, carte d'ouverture, écran des chapitres). Un nouveau chapitre
## s'ajoute à cette liste dans levels/level.gd.
@export_enum("Le Seuil", "Lumière et ombre", "Profondeurs", "Clocher", "Carillon", "Horloge", "Dernière lueur", "Poursuite", "Regards", "Miroir", "Compagnie", "Le matin") var chapter := "Le Seuil"
## Face B du chapitre : ouverte par sa sortie secrète, rangée après l'épilogue dans la liste
@export var bside := false
## Face B : la phrase de sa carte d'ouverture
@export var line := ""
## Niveau de l'épilogue (après la vraie fin)
@export var epilogue := false
## Teinte de l'épilogue, de 0 (noir et blanc) à 1 (couleurs)
@export_range(0.0, 1.0, 0.05) var colors := 0.0
@export_group("Salle")
## Coché : la salle commence à la tuile peinte la plus en haut à gauche. Décoché : elle commence
## à « Room Corner »
@export var auto_corner := true:
	set(v):
		auto_corner = v
		_room_changed()
## Case du coin en haut à gauche de la salle (quand « Auto Corner » est décoché), en cases de la Carte
@export var room_corner := Vector2i.ZERO:
	set(v):
		room_corner = v
		_room_changed()
## Taille de la salle en cases, depuis son coin ; (0, 0) : jusqu'aux dernières tuiles peintes
@export var room_size := Vector2i.ZERO:
	set(v):
		room_size = v
		_room_changed()


func _ready() -> void:
	if Engine.is_editor_hint():
		child_order_changed.connect(_watch_layers)
		_watch_layers()


# Le cadre et les avertissements suivent les calques, même ajoutés après coup
func _watch_layers() -> void:
	if not is_inside_tree():
		return
	for map in _layers():
		if not map.changed.is_connected(_room_changed):
			map.changed.connect(_room_changed)
	_room_changed()


func _room_changed() -> void:
	queue_redraw()
	update_configuration_warnings()


# Dans l'éditeur : le contour de la salle et la taille d'un écran (480 × 270) depuis son coin
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var corner := Vector2(_origin()) * TILE
	var size := Vector2(_grid_size()) * TILE
	draw_rect(Rect2(corner, size), Color(1, 0.8, 0.3, 0.9), false, 2.0)
	draw_rect(Rect2(corner, Vector2(480, 270)), Color(1, 1, 1, 0.25), false, 1.0)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if level_name.strip_edges() == "":
		out.append("Donne un nom au niveau (level_name).")
	var layers := _layers()
	if layers.is_empty():
		out.append("Il manque la TileMapLayer « Carte ».")
		return out
	var counts := {}
	var room := Rect2i(_origin(), _grid_size())
	var outside := false
	var moved := false
	for map in layers:
		moved = moved or map.position != Vector2.ZERO
		for cell in map.get_used_cells():
			var c := _char_at(map, cell)
			counts[c] = counts.get(c, 0) + 1
			outside = outside or not room.has_point(cell)
	if outside:
		out.append("Des tuiles sont hors de la salle (cadre orange) : elles seront ignorées.")
	for e in _elements(self):
		if not room.has_point(Vector2i((_offset_of(e) / TILE).round())):
			out.append("L'élément « %s » est hors de la salle (cadre orange)." % e.name)
	if moved:
		out.append("Un calque de tuiles a été déplacé : remets sa position à (0, 0), sinon le jeu ne le place pas où on le voit.")
	if counts.get("P", 0) != 1:
		out.append("Il faut exactement un départ (fantôme blanc P).")
	var exits: int = counts.get("E", 0)
	for e in _elements(self):
		if e.element_data().get("type") == "exit":
			exits += 1
	if exits == 0:
		out.append("Il n'y a pas de sortie (tuile E ou élément Sortie).")
	return out


# Les calques de tuiles du niveau : « Carte » et toutes les autres TileMapLayer enfants, dans l'ordre
func _layers() -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for child in get_children():
		if child is TileMapLayer:
			out.append(child)
	return out


func _char_at(map: TileMapLayer, cell: Vector2i) -> String:
	var a := map.get_cell_atlas_coords(cell)
	if map.get_cell_source_id(cell) == 1:
		if a.y == SHAPED.length():
			return SLOPE_CHARS[a.x] if a.x >= 0 and a.x < SLOPE_CHARS.length() else "."
		return SHAPED[a.y] if a.y >= 0 and a.y < SHAPED.length() else "."
	var i := a.y * COLS + a.x
	return CHARS[i] if a.x >= 0 and i < CHARS.length() else "."


# Toutes les tuiles peintes, tous calques confondus
func _used_rect() -> Rect2i:
	var rect := Rect2i()
	var first := true
	for map in _layers():
		if map.get_used_cells().is_empty():
			continue
		rect = map.get_used_rect() if first else rect.merge(map.get_used_rect())
		first = false
	return rect


# Coin de la salle : la tuile la plus en haut à gauche, ou « Room Corner ». On peut peindre partout,
# même au-dessus ou à gauche de l'origine du nœud : la carte est recalée en (0, 0) au lancement
func _origin() -> Vector2i:
	return _used_rect().position if auto_corner else room_corner


func _grid_size() -> Vector2i:
	if room_size.x > 0 and room_size.y > 0:
		return room_size
	var rect := _used_rect()
	if rect.size == Vector2i.ZERO:
		return Vector2i.ZERO
	return (rect.end - _origin()).max(Vector2i.ZERO)


# Le niveau au format de level_data.gd : nom, chapitre, indices [x, y, texte] et un calque de
# carte en texte par TileMapLayer (toutes de la même taille, "." pour une case vide)
func to_data() -> Dictionary:
	var origin := _origin()
	var size := _grid_size()
	var layers := []
	for map in _layers():
		var rows := []
		for y in size.y:
			rows.append(".".repeat(size.x))
		for used in map.get_used_cells():
			var cell: Vector2i = used - origin
			if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
				continue
			var row: String = rows[cell.y]
			row[cell.x] = _char_at(map, used)
			rows[cell.y] = row
		layers.append(rows)
	var hints := []
	var holder := get_node_or_null("Indices")
	if holder:
		for h in holder.get_children():
			if h is Node2D and "text" in h:
				var cell := Vector2i((h.position / TILE).floor()) - origin
				hints.append([cell.x, cell.y, h.text])
	# Les éléments réglables : leurs réglages, et leur case depuis le coin de la salle
	var elements := []
	for e in _elements(self):
		var d: Dictionary = e.element_data()
		if d.is_empty():
			continue
		d["cell"] = Vector2i((_offset_of(e) / TILE).round()) - origin
		elements.append(d)
	var data := {"name": level_name, "chapter": chapter, "hints": hints, "layers": layers, "elements": elements}
	if bside:
		data["bside"] = true
		data["line"] = line
	if epilogue:
		data["epilogue"] = true
	if colors > 0.0:
		data["colors"] = colors
	return data


# Tous les éléments réglables de la scène, où qu'ils soient rangés
func _elements(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c.has_method("element_data"):
			out.append(c)
		elif not c is TileMapLayer:
			out.append_array(_elements(c))
	return out


# Position d'un nœud dans le repère du niveau (sans passer par l'arbre de scène : au lancement,
# le niveau est relu avant d'y être ajouté)
func _offset_of(node: Node2D) -> Vector2:
	var at := node.position
	var p: Node = node.get_parent()
	while p != self and p is Node2D:
		at = (p as Node2D).position + at
		p = p.get_parent()
	return at
