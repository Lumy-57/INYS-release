# Racine d'une scène de niveau. La carte se peint dans la TileMapLayer « Carte » (une tuile par
# case de 16 px, palette levels/tiles.tres) ; les indices sont des nœuds « Indice » posés sous
# « Indices ». Au lancement, level_data.gd relit chaque scène et en refait la grille de caractères
# que main.gd sait construire : chaque tuile vaut un caractère de CHARS (voir docs/niveaux.md).
@tool
class_name LevelScene
extends Node2D

const TILE := 16
const COLS := 8  # colonnes de levels/tiles.png
# Caractère de chaque tuile de la palette, dans l'ordre de levels/tiles.png (tools/make_tiles.py)
const CHARS := "#%=^v<>-" + "LOX|12ab" + "iMWSB~HR" + "PCDEe*Yy"

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
## L'ombre H marche avec le fantôme sans le toucher
@export var companion := false
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
		var map := _map_layer()
		if map and not map.changed.is_connected(_on_map_changed):
			map.changed.connect(_on_map_changed)


func _on_map_changed() -> void:
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
	var map := _map_layer()
	if map == null:
		out.append("Il manque la TileMapLayer « Carte ».")
		return out
	var counts := {}
	var room := Rect2i(_origin(), _grid_size())
	var outside := false
	for cell in map.get_used_cells():
		var c := _char_at(map, cell)
		counts[c] = counts.get(c, 0) + 1
		outside = outside or not room.has_point(cell)
	if outside:
		out.append("Des tuiles sont hors de la salle (cadre orange) : elles seront ignorées.")
	if counts.get("P", 0) != 1:
		out.append("Il faut exactement un départ (fantôme blanc P).")
	if counts.get("E", 0) == 0:
		out.append("Il n'y a pas de sortie (E).")
	return out


func _map_layer() -> TileMapLayer:
	return get_node_or_null("Carte") as TileMapLayer


func _char_at(map: TileMapLayer, cell: Vector2i) -> String:
	var a := map.get_cell_atlas_coords(cell)
	var i := a.y * COLS + a.x
	return CHARS[i] if a.x >= 0 and i < CHARS.length() else "."


# Coin de la salle : la tuile la plus en haut à gauche, ou « Room Corner ». On peut peindre partout,
# même au-dessus ou à gauche de l'origine du nœud : la carte est recalée en (0, 0) au lancement
func _origin() -> Vector2i:
	if not auto_corner:
		return room_corner
	var map := _map_layer()
	if map == null or map.get_used_cells().is_empty():
		return Vector2i.ZERO
	return map.get_used_rect().position


func _grid_size() -> Vector2i:
	if room_size.x > 0 and room_size.y > 0:
		return room_size
	var map := _map_layer()
	if map == null or map.get_used_cells().is_empty():
		return Vector2i.ZERO
	return (map.get_used_rect().end - _origin()).max(Vector2i.ZERO)


# Le niveau au format de level_data.gd : nom, chapitre, indices [x, y, texte] et carte en texte
func to_data() -> Dictionary:
	var origin := _origin()
	var size := _grid_size()
	var rows := []
	for y in size.y:
		rows.append(".".repeat(size.x))
	var map := _map_layer()
	if map:
		for used in map.get_used_cells():
			var cell: Vector2i = used - origin
			if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
				continue
			var row: String = rows[cell.y]
			row[cell.x] = _char_at(map, used)
			rows[cell.y] = row
	var hints := []
	var holder := get_node_or_null("Indices")
	if holder:
		for h in holder.get_children():
			if h is Node2D and "text" in h:
				var cell := Vector2i((h.position / TILE).floor()) - origin
				hints.append([cell.x, cell.y, h.text])
	var data := {"name": level_name, "chapter": chapter, "hints": hints, "map": rows}
	if bside:
		data["bside"] = true
		data["line"] = line
	if epilogue:
		data["epilogue"] = true
	if colors > 0.0:
		data["colors"] = colors
	if companion:
		data["companion"] = true
	return data
