# Écran des touches, ouvert depuis les options. ↑ ↓ choisir l'action, ← → clavier ou manette,
# Saut pour changer : la touche suivante (ou le bouton de manette) remplace l'ancienne.
extends CanvasLayer

signal closed

const COLUMNS := ["Clavier", "Manette"]
const TOP := 8.0
const WAIT_MS := 5000

var index := 0
var column := 0
var waiting := false
var wait_start := 0
var skip_frame := -1
var sfx: Node
var names: Label
var cells: Array = []
var footer: Label


func _ready() -> void:
	layer = 4
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 1)
	add_child(dim)
	names = _column_label(20, 150, HORIZONTAL_ALIGNMENT_RIGHT)
	cells = [_column_label(160, 320, HORIZONTAL_ALIGNMENT_CENTER), _column_label(320, 460, HORIZONTAL_ALIGNMENT_CENTER)]
	footer = _column_label(0, 480, HORIZONTAL_ALIGNMENT_CENTER)


func _column_label(x0: float, x1: float, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = Vector2(x0, TOP)
	l.size = Vector2(x1 - x0, 270 - TOP)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 10)
	add_child(l)
	return l


func open() -> void:
	index = 0
	column = 0
	waiting = false
	visible = true
	skip_frame = Engine.get_process_frames()
	_draw()


# Lignes : les actions, puis « Réinitialiser » et « Retour »
func _rows() -> int:
	return Controls.ACTIONS.size() + 2


func _draw() -> void:
	var n_text := "\n\n\n"
	var c_text := ["\n\n%s\n" % COLUMNS[0], "\n\n%s\n" % COLUMNS[1]]
	for i in Controls.ACTIONS.size():
		var action: String = Controls.ACTIONS[i]
		n_text += Controls.NAMES[action] + "\n"
		var values := [Controls.key_text(action), Controls.pad_text(action)]
		for c in 2:
			var v: String = values[c]
			if i == index and c == column:
				v = "› %s ‹" % ("appuie…" if waiting else v)
			c_text[c] += v + "\n"
	names.text = n_text
	cells[0].text = c_text[0]
	cells[1].text = c_text[1]

	var f := "TOUCHES" + "\n".repeat(Controls.ACTIONS.size() + 4)
	var extra := ["Réinitialiser", "Retour"]
	for i in 2:
		var row := Controls.ACTIONS.size() + i
		f += ("›  %s  ‹" if index == row else "%s") % extra[i] + "\n"
	if waiting:
		f += "Appuie sur la nouvelle touche %s (5 s sans rien : annulé)" % ("de la manette" if column == 1 else "du clavier")
	else:
		f += "↑ ↓ choisir   ← → clavier / manette   Saut changer   Échap retour"
	footer.text = f


func _input(event: InputEvent) -> void:
	if not visible or not waiting:
		return
	var action: String = Controls.ACTIONS[index]
	if column == 0 and event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		Controls.rebind(action, code, false)
		_stop_waiting(true)
	elif column == 1 and event is InputEventJoypadButton and event.pressed:
		Controls.rebind(action, event.button_index, true)
		_stop_waiting(true)
	elif (column == 0 and event is InputEventJoypadButton and event.pressed) \
			or (column == 1 and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_stop_waiting(false)
	else:
		return
	get_viewport().set_input_as_handled()


func _stop_waiting(changed: bool) -> void:
	waiting = false
	# La touche qu'on vient d'assigner ne doit pas aussi naviguer dans le menu
	skip_frame = Engine.get_process_frames()
	if changed and sfx:
		sfx.play("land", 0.0)
	_draw()


func _process(_delta: float) -> void:
	if not visible:
		return
	if waiting:
		if Time.get_ticks_msec() - wait_start > WAIT_MS:
			_stop_waiting(false)
		return
	if Engine.get_process_frames() == skip_frame:
		return
	var n := _rows()
	if Input.is_action_just_pressed("pause"):
		_close()
		return
	if Input.is_action_just_pressed("up"):
		index = posmod(index - 1, n)
	elif Input.is_action_just_pressed("down"):
		index = posmod(index + 1, n)
	elif Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right"):
		column = 1 - column
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
		if index < Controls.ACTIONS.size():
			waiting = true
			wait_start = Time.get_ticks_msec()
		elif index == n - 2:
			Controls.reset()
			Controls.save()
			if sfx:
				sfx.play("land", 0.0)
		else:
			_close()
			return
	_draw()


func _close() -> void:
	visible = false
	closed.emit()
