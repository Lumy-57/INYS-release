# Apparences du fantôme, débloquées avec les étincelles et la fin du jeu.
# Le choix est gardé dans Settings.look ; ghost_visual.gd dessine l'accessoire.
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

# [identifiant, nom, condition] : nombre d'étincelles, "fin" (finir le jeu) ou "toutes"
const LOOKS := [
	["none", "Aucune", 0],
	["scarf", "Écharpe", 3],
	["hat", "Chapeau", 8],
	["lantern", "Lanterne", 15],
	["halo", "Auréole", "fin"],
	["crown", "Couronne", "toutes"],
]


static func total_sparks() -> int:
	var n := 0
	for i in LevelData.LEVELS.size():
		n += LevelData.count(i, "*")
	return n


static func is_unlocked(look: Array, save: RefCounted, stats: Node) -> bool:
	var need = look[2]
	if need is String:
		if need == "fin":
			return stats.games_finished > 0
		return save.total_sparks_found() >= total_sparks()
	return save.total_sparks_found() >= need


static func unlocked_ids(save: RefCounted, stats: Node) -> Array:
	var ids := []
	for look in LOOKS:
		if is_unlocked(look, save, stats):
			ids.append(look[0])
	return ids


static func name_of(id: String) -> String:
	for look in LOOKS:
		if look[0] == id:
			return look[1]
	return LOOKS[0][1]


# Ce qu'il reste à faire pour la prochaine apparence verrouillée
static func next_hint(save: RefCounted, stats: Node) -> String:
	for look in LOOKS:
		if is_unlocked(look, save, stats):
			continue
		var need = look[2]
		if need is String:
			return "%s : %s" % [look[1], "finir le jeu" if need == "fin" else "toutes les étincelles"]
		return "%s : %d étincelles" % [look[1], need]
	return ""
