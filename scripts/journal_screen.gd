# Journal, ouvert depuis le titre : les fragments de l'histoire cachée,
# un par étincelle trouvée, rangés par chapitre. ← → change de chapitre,
# Saut ou Échap pour revenir.
extends CanvasLayer

signal closed

const LevelData = preload("res://scripts/level_data.gd")
const Lore = preload("res://scripts/lore.gd")

var main: Node
var opened_frame := -1
var page := 0
var title: Label
var chapter_label: Label
var body: Label
var footer: Label


func _ready() -> void:
	layer = 3
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.94)
	add_child(dim)
	title = _label(Rect2(0, 12, 480, 20), 14)
	chapter_label = _label(Rect2(0, 36, 480, 16), 10)
	body = _label(Rect2(50, 62, 380, 176), 9)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 1)
	footer = _label(Rect2(0, 248, 480, 16), 9)


func _label(rect: Rect2, size: int) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


# Chapitres : [nom, premier niveau, niveau après le dernier] ; l'épilogue une fois ouvert
func chapters() -> Array:
	var list := []
	for i in main.save.playable_levels():
		var ch: String = LevelData.LEVELS[i].get("chapter", "")
		if list.is_empty() or list[-1][0] != ch:
			list.append([ch, i, i + 1])
		else:
			list[-1][2] = i + 1
	return list


func open() -> void:
	visible = true
	opened_frame = Engine.get_process_frames()
	page = 0
	_draw_page()


func _found(i: int) -> bool:
	if LevelData.is_epilogue(i):
		return main.save.page_read(i)
	return main.save.found_sparks(i).size() > 0


func _draw_page() -> void:
	var found := 0
	for i in LevelData.story_end():
		if _found(i) and Lore.fragment(i) != "":
			found += 1
	title.text = "JOURNAL   ·   %d / %d" % [found, mini(Lore.FRAGMENTS.size(), LevelData.story_end())]
	var chs := chapters()
	var ch: Array = chs[page]
	chapter_label.text = "<   %s   >" % ch[0]
	var parts := PackedStringArray()
	for i in range(ch[1], ch[2]):
		var text := Lore.fragment(i)
		if text == "":
			continue
		if _found(i):
			parts.append("« %s »" % text)
		else:
			# Fragment encore caché : seule une étincelle du niveau le révèle
			parts.append("· · ·   (%s)" % LevelData.LEVELS[i]["name"])
	body.text = "\n\n".join(parts)
	footer.text = "← → chapitre   ·   Saut ou Échap pour revenir"


func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == opened_frame:
		return
	var count := chapters().size()
	if Input.is_action_just_pressed("left"):
		page = posmod(page - 1, count)
		_draw_page()
	elif Input.is_action_just_pressed("right"):
		page = posmod(page + 1, count)
		_draw_page()
	elif Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
		visible = false
		closed.emit()
