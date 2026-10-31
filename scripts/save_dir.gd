# Dossier où vivent toutes les sauvegardes : user://save/.
# Les anciennes versions écrivaient à la racine de user:// : un fichier laissé là
# est déplacé dans le dossier la première fois qu'on le demande.
extends RefCounted

const DIR := "user://save/"


static func path(file: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var old := "user://" + file
	var new := DIR + file
	if FileAccess.file_exists(old) and not FileAccess.file_exists(new):
		DirAccess.rename_absolute(old, new)
	return new
