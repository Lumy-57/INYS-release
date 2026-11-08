# Les niveaux du jeu, dans l'ordre de levels/list.tres. Chaque niveau est une scène (levels/…/*.tscn)
# peinte dans l'éditeur Godot : voir docs/niveaux.md. Au chargement, chaque scène est relue en
# dictionnaire, au format que main.gd construit :
#  "name", "chapter", "hints" ([x, y, texte] en cases), "layers" (un calque par TileMapLayer de la
#  scène : une chaîne par rangée, un caractère par tuile de 16 px, "." pour une case vide ; plusieurs
#  calques permettent plusieurs tuiles sur une même case) et "elements" (les éléments réglables :
#  "type", "cell" et leurs réglages, voir levels/elements/), plus "bside" (face B) et sa "line",
#  "epilogue" et "colors" (teinte de l'épilogue) quand ils sont mis.
# Les caractères de la carte (une tuile de la palette levels/tiles.png chacun) :
#  # mur   ^ v < > pics   P départ   C bougie (checkpoint)
#  D cristal de dash   E sortie   . vide
#  * étincelle (objet à collectionner, facultatif)
#  B cloche : inverse les blocs de carillon (éléments BlocCarillon)
#  R reflet : contrôlé en même temps que le fantôme, gauche et droite inversées   = vitre
#  i pierre cachée : invisible, n'apparaît et ne porte que près de la petite orbe
#  e sortie secrète : une seule par chapitre, elle ouvre la face B du chapitre
#  % fausse paroi : a l'air d'un mur, mais on passe au travers (cache les sorties secrètes)
#  r t g murs taillés (roche, pierre taillée, givre) : solides comme #, coins arrondis ou biseautés
#  p pont : une planche qu'on traverse par en dessous (collision à sens unique)
#  j k u n pentes raides, c d f h pentes douces au sol, l m o s au plafond (scripts/slopes.gd)
# Vent, zéro gravité, blocs de lumière et d'ombre, pierres fissurées, ressorts, plateformes
# mobiles, blocs de carillon, blocs rythmés, yeux, marée et ombres poursuivantes sont des éléments.
extends RefCounted

const LIST = preload("res://levels/list.tres")
# Les niveaux du mode Ascension (levels/ascension/list.tres) : à part, ils ne comptent ni dans la
# partie, ni dans les chapitres, ni dans la sauvegarde des niveaux
const ASCENT_LIST = preload("res://levels/ascension/list.tres")

static var LEVELS: Array = _load_levels(LIST)
static var ASCENT: Array = _load_levels(ASCENT_LIST)


static func _load_levels(list: Resource) -> Array:
	var out := []
	for scene in list.levels:
		var level = scene.instantiate()
		out.append(level.to_data())
		level.free()
	return out


# Les cases du niveau, calques réunis : grid[y][x] est la chaîne des caractères de la case
# ("" si elle est vide, "-^" pour des pics posés sur un rail…)
static func grid(index: int) -> Array:
	return grid_of(LEVELS[index])


static func grid_of(data: Dictionary) -> Array:
	var layers: Array = data["layers"]
	var out := []
	for y in (layers[0].size() if layers else 0):
		var row := []
		for x in layers[0][y].length():
			var here := ""
			for rows in layers:
				var c: String = rows[y][x]
				if c != ".":
					here += c
			row.append(here)
		out.append(row)
	return out


# Nombre de tuiles d'une sorte dans un niveau, tous calques confondus (les étincelles "*"…)
static func count(index: int, c: String) -> int:
	var n := 0
	for rows in LEVELS[index]["layers"]:
		for row in rows:
			n += row.count(c)
	return n


# Premier niveau de l'épilogue : la partie complète s'arrête juste avant
static func story_end() -> int:
	for i in LEVELS.size():
		if LEVELS[i].get("epilogue", false):
			return i
	return LEVELS.size()


static func is_epilogue(index: int) -> bool:
	return index >= 0 and index < LEVELS.size() and LEVELS[index].get("epilogue", false)


# Les faces B sont rangées tout au bout, après l'épilogue : elles ne comptent ni dans la partie,
# ni dans les chapitres, ni dans le journal
static func bside_start() -> int:
	for i in LEVELS.size():
		if LEVELS[i].get("bside", false):
			return i
	return LEVELS.size()


static func is_bside(index: int) -> bool:
	return index >= 0 and index < LEVELS.size() and LEVELS[index].get("bside", false)


# Face B d'un chapitre, ou -1
static func bside_of(chapter: String) -> int:
	for i in range(bside_start(), LEVELS.size()):
		if LEVELS[i].get("chapter", "") == chapter:
			return i
	return -1
