# Écran d'options, ouvert depuis le menu pause ou l'écran titre. « Touches » ouvre controls_menu.gd. ↑ ↓ choisir, ← → régler, Saut ou Échap pour revenir.
extends CanvasLayer

const ControlsMenu = preload("res://scripts/controls_menu.gd")
const Looks = preload("res://scripts/looks.gd")

signal closed

var index := 0
var opened_frame := -1
var label: Label
var sfx: Node
var main: Node  # pour les apparences débloquées (save et stats)
var controls_menu: CanvasLayer
var confirming_reset := false  # « Réinitialiser la sauvegarde » attend une confirmation


func _ready() -> void:
	layer = 3
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	add_child(dim)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	add_child(label)
	controls_menu = ControlsMenu.new()
	controls_menu.closed.connect(func():
		opened_frame = Engine.get_process_frames()
		_draw())
	add_child(controls_menu)


# Chaque ligne : [titre, clé du réglage, type]. Une clé vide est un séparateur ou « Retour ».
func _items() -> Array:
	var items := [
		["Effets sonores", "sfx_volume", "level"],
		["Musique", "music_volume", "level"],
		["Tremblement d'écran", "shake", "bool"],
		["Plein écran", "fullscreen", "bool"],
		["Chrono affiché", "show_timer", "bool"],
		["Apparence", "look", "look"],
		["Vitesse du jeu", "game_speed", "speed"],
		["Dash infini", "infinite_dash", "bool"],
		["Invincible", "invincible", "bool"],
		["Touches", "", "controls"],
	]
	# Seulement depuis l'écran titre : effacer la sauvegarde en pleine partie la casserait
	if main and main.on_title:
		items.append(["Réinitialiser la sauvegarde", "", "reset"])
	items.append(["Retour", "", "back"])
	return items


func open() -> void:
	index = 0
	confirming_reset = false
	visible = true
	# La touche qui a ouvert l'écran ne doit pas aussi modifier un réglage
	opened_frame = Engine.get_process_frames()
	_draw()


func _value_text(key: String, kind: String) -> String:
	var v = Settings.get(key)
	match kind:
		"level":
			return "%d / 10" % v
		"speed":
			return "%d %%" % (v * 10)
		"bool":
			return "oui" if v else "non"
		"look":
			return "<  %s  >" % Looks.name_of(v)
	return ""


func _draw() -> void:
	if confirming_reset:
		label.text = "RÉINITIALISER LA SAUVEGARDE\n\n" \
			+ "Records, progression, étincelles, journal, faces B\net statistiques seront effacés pour de bon.\n" \
			+ "Les options et les touches sont gardées.\n\n" \
			+ "Saut : tout effacer      Échap : annuler"
		return
	var items := _items()
	var text := "OPTIONS\n"
	for i in items.size():
		var it: Array = items[i]
		if i == 6:
			text += "\n— Assistance —\n"
		var line: String = it[0]
		if it[2] == "reset":
			text += "\n"
		if it[2] != "back" and it[2] != "controls" and it[2] != "reset":
			line += "   %s" % _value_text(it[1], it[2])
		text += ("›  %s  ‹" if i == index else "%s") % line + "\n"
	text += "\n↑ ↓ choisir   ← → régler   Échap retour"
	if _items()[index][2] == "look" and main:
		var hint := Looks.next_hint(main.save, main.stats)
		if hint != "":
			text += "\nProchaine apparence · " + hint
	elif Settings.assisted():
		text += "\nAvec l'assistance, les records ne sont pas enregistrés."
	label.text = text


func _change(dir: int) -> void:
	var it: Array = _items()[index]
	var key: String = it[1]
	match it[2]:
		"level":
			Settings.set(key, clampi(Settings.get(key) + dir, 0, 10))
		"speed":
			Settings.set(key, clampi(Settings.get(key) + dir, 5, 10))
		"bool":
			Settings.set(key, not Settings.get(key))
		"look":
			if not main:
				return
			var ids := Looks.unlocked_ids(main.save, main.stats)
			var i := ids.find(Settings.look)
			Settings.look = ids[posmod(i + dir, ids.size())]
		_:
			return
	Settings.save()
	if sfx:
		sfx.play("land", 0.0)


func _process(_delta: float) -> void:
	if not visible or controls_menu.visible or Engine.get_process_frames() == opened_frame:
		return
	if confirming_reset:
		_confirm_input()
		return
	var n := _items().size()
	if Input.is_action_just_pressed("pause"):
		_close()
		return
	if Input.is_action_just_pressed("up"):
		index = posmod(index - 1, n)
	elif Input.is_action_just_pressed("down"):
		index = posmod(index + 1, n)
	elif Input.is_action_just_pressed("left"):
		_change(-1)
	elif Input.is_action_just_pressed("right"):
		_change(1)
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
		if _items()[index][2] == "back":
			_close()
			return
		if _items()[index][2] == "reset":
			confirming_reset = true
			_draw()
			return
		if _items()[index][2] == "controls":
			controls_menu.sfx = sfx
			controls_menu.open()
			return
		_change(1)
	_draw()


func _confirm_input() -> void:
	if Input.is_action_just_pressed("pause"):
		confirming_reset = false
		_draw()
	elif Input.is_action_just_pressed("jump"):
		confirming_reset = false
		main.reset_save()
		index = 0
		_draw()
		label.text += "\n\nSauvegarde réinitialisée."
		if sfx:
			sfx.play("land", 0.0)


func _close() -> void:
	visible = false
	closed.emit()
