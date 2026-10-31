# Les niveaux du jeu, dans l'ordre de levels/list.tres. Chaque niveau est une scène (levels/…/*.tscn)
# peinte dans l'éditeur Godot : voir docs/niveaux.md. Au chargement, chaque scène est relue en
# dictionnaire, au format que main.gd construit :
#  "name", "chapter", "hints" ([x, y, texte] en cases) et "map" (une chaîne par rangée, un caractère
#  par tuile de 16 px), plus "bside" (face B) et sa "line", "epilogue", "colors" (teinte de l'épilogue)
#  et "companion" (l'ombre H marche avec le fantôme sans le toucher) quand ils sont mis.
# Les caractères de la carte (une tuile de la palette levels/tiles.png chacun) :
#  # mur   ^ v < > pics   P départ   C bougie (checkpoint)
#  D cristal de dash   E sortie   . vide
#  L bloc de lumière : solide seulement quand le fantôme brille (dash disponible)
#  O bloc d'ombre : solide seulement quand le fantôme est éteint (dash utilisé)
#  X pierre fissurée : s'effondre peu après qu'on la touche, puis revient
#  | courant d'air spectral : soulève le fantôme
#  * étincelle (objet à collectionner, facultatif)
#  S ressort   M plateforme mobile horizontale   W plateforme mobile verticale
#  - rail : la course des plateformes mobiles
#  B cloche : inverse les blocs de carillon   a solide au repos   b solide une fois sonné
#  1 2 blocs rythmés : 1 solides pendant la première moitié du cycle, 2 pendant la seconde
#  H ombre poursuivante : refait le chemin du fantôme avec un temps de retard
#  ~ marée de ténèbres : sa ligne marque où elle commence, puis elle monte
#  Y y œil qui regarde : Y s'ouvre au début du cycle, y une demi-période plus tard
#  R reflet : contrôlé en même temps que le fantôme, gauche et droite inversées   = vitre
#  i pierre cachée : invisible, n'apparaît et ne porte que près de la petite orbe
#  e sortie secrète : une seule par chapitre, elle ouvre la face B du chapitre
#  % fausse paroi : a l'air d'un mur, mais on passe au travers (cache les sorties secrètes)
#  r t g murs taillés (roche, pierre taillée, givre) : solides comme #, coins arrondis ou biseautés
extends RefCounted

const LIST = preload("res://levels/list.tres")

static var LEVELS: Array = _load_levels()


static func _load_levels() -> Array:
	var out := []
	for scene in LIST.levels:
		var level = scene.instantiate()
		out.append(level.to_data())
		level.free()
	return out


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
