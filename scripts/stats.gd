# Statistiques cumulées de toutes les parties, gardées dans user://save/stats.cfg.
extends Node

const SaveDir = preload("res://scripts/save_dir.gd")
var PATH := SaveDir.path("stats.cfg")
const KEYS := ["play_time", "deaths", "jumps", "dashes", "levels_finished", "games_finished"]

var main: Node
var play_time := 0.0  # en secondes réelles, hors titre, pause et écran de fin
var deaths := 0
var jumps := 0
var dashes := 0
var levels_finished := 0
var games_finished := 0
var dirty := 0.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in KEYS:
			set(key, cfg.get_value("stats", key, get(key)))
	main.player.died.connect(func(): deaths += 1)
	main.player.jumped.connect(func(): jumps += 1)
	main.player.dashed.connect(func(): dashes += 1)


func _process(delta: float) -> void:
	if main.on_title or main.paused or main.finished:
		return
	play_time += delta / Engine.time_scale
	# Sauvegarde toutes les 10 s de jeu, pour ne presque rien perdre si le jeu est fermé
	dirty += delta
	if dirty > 10.0:
		save()


func level_finished() -> void:
	levels_finished += 1
	save()


func game_finished() -> void:
	games_finished += 1
	save()


func reset() -> void:
	for key in KEYS:
		set(key, 0.0 if key == "play_time" else 0)
	save()


func save() -> void:
	dirty = 0.0
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("stats", key, get(key))
	cfg.save(PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save()


static func duration(t: float) -> String:
	var s := int(t)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s / 60) % 60]
	return "%d min %02d s" % [s / 60, s % 60]
