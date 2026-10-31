# Meilleurs temps : par niveau et pour la partie complète, gardés dans user://save/save.cfg.
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

const SaveDir = preload("res://scripts/save_dir.gd")
var PATH := SaveDir.path("save.cfg")

var cfg := ConfigFile.new()

# Ordre des niveaux avant l'ajout des niveaux intermédiaires : les sauvegardes sans
# "progress/level_names" ont été écrites avec cet ordre.
const LEGACY_NAMES := [
	"Éveil", "Souffle", "Cendres", "Reflets", "Ombres", "Aube",
	"Fissures", "Courants", "Abysse", "Rebonds", "Passeurs", "Clocher",
	"Glas", "Volée", "Carillon", "Tic", "Tac", "Minuit",
	"Épreuve", "Vertige", "Dernière lueur", "Reflet noir", "Contre-jour", "Marée",
	"Paupières", "Vitrine", "À découvert", "Vis-à-vis", "Dédoublement", "Face à face",
	"Confiance", "Éclaircie", "Cortège", "Rosée", "Vitraux", "Ensemble",
]


func _init() -> void:
	if cfg.load(PATH) == OK:
		_migrate()
	else:
		cfg.set_value("progress", "level_names", _names())


# Efface toute la progression : records, étincelles, journal, épilogue, faces B
func reset() -> void:
	cfg.clear()
	cfg.set_value("progress", "level_names", _names())
	cfg.save(PATH)


func _names() -> Array:
	var names := []
	for lvl in LevelData.LEVELS:
		names.append(lvl["name"])
	return names


# Les clés sont rangées par numéro de niveau : quand l'ordre des niveaux change,
# on les renumérote d'après le nom du niveau pour garder records et étincelles.
func _migrate() -> void:
	var names := _names()
	var old: Array = cfg.get_value("progress", "level_names", LEGACY_NAMES)
	if old == names:
		return
	var moves := {}
	for i in old.size():
		var j := names.find(old[i])
		if j >= 0:
			moves[i] = j
	for entry in [["levels", "time_%d"], ["levels", "deaths_%d"], ["sparks", "level_%d"], ["journal", "page_%d"]]:
		var saved := {}
		for i in moves:
			var key: String = entry[1] % i
			if cfg.has_section_key(entry[0], key):
				saved[moves[i]] = cfg.get_value(entry[0], key)
				cfg.erase_section_key(entry[0], key)
		for j in saved:
			cfg.set_value(entry[0], entry[1] % j, saved[j])
	if cfg.has_section_key("progress", "last_level"):
		cfg.set_value("progress", "last_level", moves.get(last_level(), 0))
	cfg.set_value("progress", "level_names", names)
	cfg.save(PATH)


func best_level_time(index: int) -> float:
	return cfg.get_value("levels", "time_%d" % index, -1.0)


func best_level_deaths(index: int) -> int:
	return cfg.get_value("levels", "deaths_%d" % index, -1)


func best_run_time() -> float:
	return cfg.get_value("run", "time", -1.0)


func best_run_deaths() -> int:
	return cfg.get_value("run", "deaths", -1)


# Renvoie vrai si le temps bat le record du niveau
func record_level(index: int, time: float, deaths: int) -> bool:
	var is_record := _better(time, best_level_time(index))
	if is_record:
		cfg.set_value("levels", "time_%d" % index, time)
	var bd := best_level_deaths(index)
	if bd < 0 or deaths < bd:
		cfg.set_value("levels", "deaths_%d" % index, deaths)
	cfg.save(PATH)
	return is_record


func record_run(time: float, deaths: int) -> bool:
	var is_record := _better(time, best_run_time())
	if is_record:
		cfg.set_value("run", "time", time)
	var bd := best_run_deaths()
	if bd < 0 or deaths < bd:
		cfg.set_value("run", "deaths", deaths)
	cfg.save(PATH)
	return is_record


func _better(time: float, best: float) -> bool:
	return best < 0.0 or time < best


# Étincelles trouvées, par niveau : la liste de leurs cases
func found_sparks(index: int) -> Array:
	return cfg.get_value("sparks", "level_%d" % index, [])


func add_sparks(index: int, cells: Array) -> void:
	var found := found_sparks(index)
	for c in cells:
		if not found.has(c):
			found.append(c)
	cfg.set_value("sparks", "level_%d" % index, found)
	cfg.save(PATH)


func total_sparks_found() -> int:
	if not cfg.has_section("sparks"):
		return 0
	var n := 0
	for key in cfg.get_section_keys("sparks"):
		n += cfg.get_value("sparks", key).size()
	return n


# Dernier niveau atteint, pour « Continuer » sur l'écran titre
func last_level() -> int:
	return cfg.get_value("progress", "last_level", 0)


func set_last_level(index: int) -> void:
	if index != last_level():
		cfg.set_value("progress", "last_level", index)
		cfg.save(PATH)


# Épilogue « Le matin » : ouvert par la vraie fin
func epilogue_unlocked() -> bool:
	return cfg.get_value("progress", "epilogue", false)


func unlock_epilogue() -> void:
	if not epilogue_unlocked():
		cfg.set_value("progress", "epilogue", true)
		cfg.save(PATH)


# Pages du journal écrites en finissant un niveau de l'épilogue
func page_read(index: int) -> bool:
	return cfg.get_value("journal", "page_%d" % index, false)


func mark_page(index: int) -> void:
	cfg.set_value("journal", "page_%d" % index, true)
	cfg.save(PATH)


# Faces B : ouvertes une par une, par la sortie secrète de leur chapitre
func bside_unlocked(chapter: String) -> bool:
	return cfg.get_value("bsides", chapter, false)


# Renvoie vrai si la face B vient de s'ouvrir
func unlock_bside(chapter: String) -> bool:
	if bside_unlocked(chapter):
		return false
	cfg.set_value("bsides", chapter, true)
	cfg.save(PATH)
	return true


func bsides_unlocked() -> int:
	return cfg.get_section_keys("bsides").size() if cfg.has_section("bsides") else 0


func bsides_finished() -> int:
	var n := 0
	for i in range(LevelData.bside_start(), LevelData.LEVELS.size()):
		if best_level_time(i) >= 0.0:
			n += 1
	return n


# Niveaux qu'on peut choisir : l'épilogue n'apparaît qu'une fois ouvert, les faces B
# seulement depuis l'écran des chapitres
func playable_levels() -> int:
	return LevelData.bside_start() if epilogue_unlocked() else LevelData.story_end()
