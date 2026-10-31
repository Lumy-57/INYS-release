# Réglages du joueur (autoload « Settings ») : son, confort et assistance façon Celeste.
# Gardés dans user://save/settings.cfg, séparés des records.
extends Node

const SaveDir = preload("res://scripts/save_dir.gd")
var PATH := SaveDir.path("settings.cfg")

var sfx_volume := 8  # sur 10
var music_volume := 6
var shake := true
var fullscreen := false
var show_timer := true
var look := "none"  # apparence du fantôme (looks.gd)
# Assistance : une partie assistée ne bat pas de record
var game_speed := 10  # en dixièmes : 5 = 50 %
var infinite_dash := false
var invincible := false


func _ready() -> void:
	for bus in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in _keys():
			set(key, cfg.get_value("settings", key, get(key)))
	apply()


func _keys() -> Array:
	return ["sfx_volume", "music_volume", "shake", "fullscreen", "show_timer", "look", "game_speed", "infinite_dash", "invincible"]


func assisted() -> bool:
	return game_speed < 10 or infinite_dash or invincible


func speed() -> float:
	return game_speed / 10.0


func apply() -> void:
	_set_volume("SFX", sfx_volume)
	_set_volume("Music", music_volume)
	Engine.time_scale = speed()
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save() -> void:
	apply()
	var cfg := ConfigFile.new()
	for key in _keys():
		cfg.set_value("settings", key, get(key))
	cfg.save(PATH)


func _set_volume(bus: String, level: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, level <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(level / 10.0))
