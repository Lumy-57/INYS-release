# « Signaler » dans le menu titre. Deux chemins, sans serveur à maintenir :
# - avec un compte GitHub : une issue préremplie sur INYS-release (modèles dans .github/ISSUE_TEMPLATE) ;
# - sans compte : un formulaire Google prérempli, les réponses arrivent dans un tableau.
# Dans les deux cas : version du jeu, plateforme et dernier niveau joué sont remplis d'avance.
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")
const NEW_ISSUE := "https://github.com/Lumy-57/INYS-release/issues/new"

# Formulaire Google (voir docs/signalements.md) : lien du formulaire, terminé par /viewform,
# et numéros des champs « entry.… » lus dans son lien prérempli : un champ par information,
# ou un seul champ « infos » qui reçoit « niveau · version · plateforme ».
# Tant que FORM_URL est vide, l'entrée « sans compte GitHub » n'apparaît pas.
const FORM_URL := "https://docs.google.com/forms/d/e/1FAIpQLScYBQNDAUbqwGw1TGen7ovSKAO1_1VMtP3Ywvd_S0RA077jtQ/viewform"
const FORM_ENTRIES := {
	"infos": "889481720",
	"niveau": "",
	"version": "",
	"plateforme": "",
}


# kind : "bug" ou "remarque" (nom du modèle d'issue)
static func open(kind: String, last_level: int) -> void:
	var fields := {"template": kind + ".yml"}
	fields.merge(_context(last_level))
	OS.shell_open(NEW_ISSUE + "?" + _query(fields))


static func has_form() -> bool:
	return FORM_URL.begins_with("https://")


static func open_form(last_level: int) -> void:
	var fields := {"usp": "pp_url"}
	var context := _context(last_level)
	context["infos"] = "%s · v%s · %s" % [context.get("niveau", "?"), context["version"], context["plateforme"]]
	for key in context:
		if FORM_ENTRIES.get(key, "") != "":
			fields["entry." + FORM_ENTRIES[key]] = context[key]
	OS.shell_open(FORM_URL + "?" + _query(fields))


static func _context(last_level: int) -> Dictionary:
	var size := DisplayServer.screen_get_size()
	var context := {
		"version": str(ProjectSettings.get_setting("application/config/version", "?")),
		"plateforme": "%s · %d×%d" % [OS.get_name(), size.x, size.y],
	}
	if last_level >= 0 and last_level < LevelData.LEVELS.size():
		var level: Dictionary = LevelData.LEVELS[last_level]
		var text := "%d · %s" % [last_level + 1, level.get("name", "")]
		var chapter: String = level.get("chapter", "")
		if chapter != "":
			text += " (%s)" % chapter
		context["niveau"] = text
	return context


static func _query(fields: Dictionary) -> String:
	var parts := []
	for key in fields:
		parts.append("%s=%s" % [key, str(fields[key]).uri_encode()])
	return "&".join(parts)
