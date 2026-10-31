# Touches du joueur (autoload « Controls ») : chaque action a ses touches clavier
# et ses boutons de manette, modifiables dans Options > Touches.
# Gardées dans user://save/controls.cfg. Le stick gauche déplace toujours le fantôme.
extends Node

const SaveDir = preload("res://scripts/save_dir.gd")
var PATH := SaveDir.path("controls.cfg")

# Dans l'ordre de l'écran des touches
const ACTIONS := ["jump", "dash", "left", "right", "up", "down", "restart", "pause"]
const NAMES := {
	"jump": "Saut",
	"dash": "Dash",
	"left": "Gauche",
	"right": "Droite",
	"up": "Haut",
	"down": "Bas",
	"restart": "Retour bougie",
	"pause": "Pause",
}
const DEFAULT_KEYS := {
	"jump": [KEY_C, KEY_SPACE, KEY_K],
	"dash": [KEY_X, KEY_SHIFT, KEY_J],
	"left": [KEY_LEFT, KEY_Q, KEY_A],
	"right": [KEY_RIGHT, KEY_D],
	"up": [KEY_UP, KEY_Z, KEY_W],
	"down": [KEY_DOWN, KEY_S],
	"restart": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P, KEY_ENTER],
}
const DEFAULT_PAD := {
	"jump": [JOY_BUTTON_A],
	"dash": [JOY_BUTTON_X, JOY_BUTTON_B],
	"left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_DPAD_UP],
	"down": [JOY_BUTTON_DPAD_DOWN],
	"restart": [JOY_BUTTON_Y],
	"pause": [JOY_BUTTON_START],
}
const STICK := {
	"left": [JOY_AXIS_LEFT_X, -1.0],
	"right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0],
	"down": [JOY_AXIS_LEFT_Y, 1.0],
}
const KEY_NAMES := {
	KEY_SPACE: "Espace",
	KEY_SHIFT: "Maj",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_ENTER: "Entrée",
	KEY_KP_ENTER: "Entrée",
	KEY_ESCAPE: "Échap",
	KEY_TAB: "Tab",
	KEY_BACKSPACE: "Retour arr.",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_DPAD_LEFT: "Croix ←",
	JOY_BUTTON_DPAD_RIGHT: "Croix →",
	JOY_BUTTON_DPAD_UP: "Croix ↑",
	JOY_BUTTON_DPAD_DOWN: "Croix ↓",
}

var keys := {}
var pad := {}


func _ready() -> void:
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for action in ACTIONS:
			keys[action] = cfg.get_value("keys", action, keys[action])
			pad[action] = cfg.get_value("pad", action, pad[action])
	apply()


func reset() -> void:
	for action in ACTIONS:
		keys[action] = DEFAULT_KEYS[action].duplicate()
		pad[action] = DEFAULT_PAD[action].duplicate()


# Reconstruit l'InputMap à partir des touches choisies
func apply() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.4)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(action, ev)
		for b in pad[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)
		if STICK.has(action):
			var ev := InputEventJoypadMotion.new()
			ev.axis = STICK[action][0]
			ev.axis_value = STICK[action][1]
			InputMap.action_add_event(action, ev)


func save() -> void:
	apply()
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		cfg.set_value("keys", action, keys[action])
		cfg.set_value("pad", action, pad[action])
	cfg.save(PATH)


# Donne une seule touche (ou bouton) à l'action. Si une autre action l'utilisait,
# elle la perd ; et s'il ne lui reste plus rien, elle récupère l'ancienne touche.
func rebind(action: String, code: int, on_pad: bool) -> void:
	var table: Dictionary = pad if on_pad else keys
	var old: Array = table[action]
	for other in ACTIONS:
		if other != action and code in table[other]:
			table[other].erase(code)
			if table[other].is_empty():
				table[other] = old.filter(func(c): return c != code)
	table[action] = [code]
	save()


func key_text(action: String) -> String:
	var names := []
	for k in keys[action]:
		names.append(KEY_NAMES[k] if KEY_NAMES.has(k) else OS.get_keycode_string(k))
	return " / ".join(names) if names else "—"


func pad_text(action: String) -> String:
	var names := []
	for b in pad[action]:
		names.append(PAD_NAMES[b] if PAD_NAMES.has(b) else "Bouton %d" % b)
	return " / ".join(names) if names else "—"
