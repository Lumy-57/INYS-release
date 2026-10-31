# Carte d'ouverture de chapitre : écran noir, vignette illustrée du chapitre
# (illustrations.gd), numéro et nom du chapitre, une phrase d'histoire.
# Jouée quand on arrive sur le premier niveau d'un chapitre. En venant du chapitre
# d'avant, sa vignette se referme comme un rideau avant que la nouvelle s'ouvre.
# Le chrono ne tourne pas pendant la carte ; Saut la passe.
extends CanvasLayer

const LevelData = preload("res://scripts/level_data.gd")
const Palette = preload("res://scripts/palette.gd")
const Illustrations = preload("res://scripts/illustrations.gd")

# Une phrase par chapitre : le fil de l'histoire du fantôme
const STORY := {
	"Le Seuil": "Au pied d'une grande tour, une toute petite flamme s'éveille.",
	"Lumière et ombre": "Sa lueur ouvre des passages. Son ombre en ouvre d'autres.",
	"Profondeurs": "Plus bas, on entend enfin sa propre voix.",
	"Clocher": "Là-haut, les cloches disent à chacun où se ranger.",
	"Carillon": "Chaque cloche réveille ce qui dormait.",
	"Horloge": "Ici, on attend toujours « plus tard ».",
	"Dernière lueur": "La sortie n'est plus loin. Sa lumière tremble.",
	"Poursuite": "Une ombre le suit pas à pas. Elle a sa forme, mais pas son visage.",
	"Regards": "Ici, tout ce qui a des yeux le regarde.",
	"Miroir": "Pour la première fois, il se regarde. Et ce qu'il voit bouge avec lui.",
	"Compagnie": "Ici, le sol se cache dans le noir. La petite lueur, elle, sait où il est.",
	"Le matin": "La nuit est finie. Pour la première fois, la tour a des couleurs, et personne ne lui dit lesquelles.",
}

# Fond des cartes de l'épilogue : un noir qui rosit, comme avant le lever du jour
const DAWN_BG := Color(0.16, 0.09, 0.12)

const HOLD := 3.0
const PIC := Rect2(130, 18, 220, 110)

var bg: ColorRect
var pic: Node2D
var pic_chapter := ""
var pic_reveal := 0.0
var pic_zoom := 1.0
var pic_t := 0.0
var zoom_tw: Tween
var number: Label
var title: Label
var line: Label
var playing := false
var skipped := false


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	add_child(bg)

	pic = Node2D.new()
	pic.visible = false
	pic.draw.connect(func():
		Illustrations.draw(pic, pic_chapter, PIC, pic_t, pic_reveal, pic_zoom, bg.color))
	add_child(pic)

	number = _label(9, 92)
	title = _label(22, 108)
	line = _label(10, 158)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.offset_left = 60
	line.offset_right = -60


func _label(size: int, top: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


# Vrai si le niveau est le premier de son chapitre
static func starts_chapter(index: int) -> bool:
	if index < 0 or index >= LevelData.LEVELS.size():
		return false
	var ch: String = LevelData.LEVELS[index].get("chapter", "")
	if ch == "" or LevelData.is_bside(index):
		return false
	return index == 0 or LevelData.LEVELS[index - 1].get("chapter", "") != ch


# Numéro du chapitre, dans l'ordre où les chapitres apparaissent
static func chapter_number(index: int) -> int:
	var n := 0
	var last := ""
	for i in index + 1:
		var ch: String = LevelData.LEVELS[i].get("chapter", "")
		if ch != last:
			n += 1
			last = ch
	return n


func _process(delta: float) -> void:
	if playing and Input.is_action_just_pressed("jump"):
		skipped = true
	if pic.visible:
		pic_t += delta
		pic.queue_redraw()


# Joue la carte si le niveau ouvre un chapitre ; à attendre avec await.
# Appelée en sortant d'un niveau : la vignette du chapitre fini se referme d'abord.
func play_if_new(index: int) -> void:
	if starts_chapter(index):
		await play(index, true)


func play(index: int, from_previous := false) -> void:
	var ch: String = LevelData.LEVELS[index]["chapter"]
	var epilogue := LevelData.is_epilogue(index)
	var tint := DAWN_BG if epilogue else Color.BLACK
	var prev := ""
	if from_previous and index > 0 and not LevelData.is_bside(index):
		prev = LevelData.LEVELS[index - 1].get("chapter", "")
	_place_labels(true)
	bg.color = tint
	visible = true
	playing = true
	skipped = false
	bg.modulate.a = 1.0
	for l in [number, title, line]:
		l.modulate.a = 0.0
	pic.visible = true
	pic.modulate.a = 1.0
	pic_zoom = 1.0
	pic_t = 0.0
	if prev != "" and prev != ch:
		# L'ancienne vignette, un instant, puis le rideau se ferme dessus
		pic_chapter = prev
		pic_reveal = 1.0
		await _wait(0.6)
		if not skipped:
			var close := create_tween()
			close.tween_property(self, "pic_reveal", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
			await close.finished
	else:
		pic_reveal = 0.0
	pic_chapter = ch
	pic_t = 0.0
	if skipped:
		pic_reveal = 1.0
	if LevelData.is_bside(index):
		# Face B : la vignette du chapitre, et une phrase qui en montre l'envers
		await _show("F A C E   B   ·   %s" % ch.to_upper(), LevelData.LEVELS[index]["name"],
			LevelData.LEVELS[index].get("line", ""), HOLD, tint, true)
	elif epilogue:
		await _show("É P I L O G U E", ch, STORY.get(ch, ""), HOLD + 0.6, tint, true)
	else:
		await _show("C H A P I T R E   %d" % chapter_number(index), ch, STORY.get(ch, ""), HOLD, tint, true)


# Fragment du journal, révélé par une étincelle trouvée pour la première fois
func play_fragment(text: String) -> void:
	if text == "":
		return
	_no_pic()
	await _show("J O U R N A L", "", "« %s »" % text, 3.0 + text.length() * 0.03)


# Page du journal écrite dans l'épilogue, sur fond d'aube
func play_page(text: String) -> void:
	if text == "":
		return
	_no_pic()
	await _show("J O U R N A L", "", "« %s »" % text, 3.0 + text.length() * 0.03, DAWN_BG)


# Dernière carte de l'épilogue : le texte, et le fond qui passe de l'aube au jour
func play_ending(lines: Array) -> void:
	var text := "\n".join(lines)
	_no_pic()
	var day := create_tween()
	day.tween_interval(0.6)
	day.tween_property(bg, "color", Palette.ambient(1.0).lerp(Palette.DAWN, 0.35), 6.0)
	await _show("", "", text, 5.0 + text.length() * 0.03, DAWN_BG)
	day.kill()


# Sous la vignette pour un chapitre, au milieu de l'écran pour le journal
func _place_labels(with_pic: bool) -> void:
	number.offset_top = 140 if with_pic else 92
	title.offset_top = 154 if with_pic else 108
	line.offset_top = 192 if with_pic else 158


func _no_pic() -> void:
	_place_labels(false)
	pic.visible = false


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


func _show(top: String, middle: String, bottom: String, hold: float, tint := Color.BLACK,
		with_pic := false) -> void:
	number.text = top
	title.text = middle
	line.text = bottom
	bg.color = tint
	visible = true
	playing = true
	bg.modulate.a = 1.0
	for l in [number, title, line]:
		l.modulate.a = 0.0

	var tw := create_tween()
	if with_pic:
		# Le rideau s'ouvre, puis l'image avance doucement pendant toute la carte
		tw.tween_property(self, "pic_reveal", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if zoom_tw:
			zoom_tw.kill()
		zoom_tw = create_tween()
		zoom_tw.tween_property(self, "pic_zoom", 1.08, hold + 1.0)
	tw.tween_property(number, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(title, "modulate:a", 1.0, 0.6)
	tw.tween_property(line, "modulate:a", 1.0, 0.6)
	var t := 0.0
	while t < hold and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
	tw.kill()

	playing = false
	skipped = false
	var out := create_tween()
	out.set_parallel(true)
	for n in [bg, pic, number, title, line]:
		out.tween_property(n, "modulate:a", 0.0, 0.5)
	await out.finished
	visible = false
	pic.visible = false
