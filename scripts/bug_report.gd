# « Signaler » dans le menu titre : ouvre dans le navigateur une issue préremplie sur
# INYS-release (modèles dans .github/ISSUE_TEMPLATE), avec la version du jeu,
# la plateforme et le dernier niveau joué. Aucun serveur : c'est GitHub qui reçoit.
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")
const NEW_ISSUE := "https://github.com/Lumy-57/INYS-release/issues/new"


# kind : "bug" ou "remarque" (nom du modèle d'issue)
static func open(kind: String, last_level: int) -> void:
	var fields := {
		"template": kind + ".yml",
		"version": str(ProjectSettings.get_setting("application/config/version", "?")),
		"plateforme": _platform(),
	}
	if last_level >= 0 and last_level < LevelData.LEVELS.size():
		var level: Dictionary = LevelData.LEVELS[last_level]
		var text := "%d · %s" % [last_level + 1, level.get("name", "")]
		var chapter: String = level.get("chapter", "")
		if chapter != "":
			text += " (%s)" % chapter
		fields["niveau"] = text
	var query := []
	for key in fields:
		query.append("%s=%s" % [key, str(fields[key]).uri_encode()])
	OS.shell_open(NEW_ISSUE + "?" + "&".join(query))


static func _platform() -> String:
	var size := DisplayServer.screen_get_size()
	return "%s · %d×%d" % [OS.get_name(), size.x, size.y]
