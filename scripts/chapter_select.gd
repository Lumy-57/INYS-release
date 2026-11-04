# Écran de choix du chapitre, ouvert depuis le titre : la vignette illustrée du chapitre
# en grand, sa phrase d'histoire, ses niveaux avec record et étincelles, et en bas
# une frise de petites vignettes pour tous les chapitres.
# Sous les niveaux, la face B du chapitre une fois sa sortie secrète trouvée.
# ← → change de chapitre, ↑ ↓ choisit le niveau, Saut lance, Échap ou Dash revient.
extends CanvasLayer

signal chosen(level: int)
signal closed

const LevelData = preload("res://scripts/level_data.gd")
const Illustrations = preload("res://scripts/illustrations.gd")
const ChapterIntro = preload("res://scripts/chapter_intro.gd")
const EndScreen = preload("res://scripts/end_screen.gd")

const BIG := Rect2(24, 30, 240, 120)
const THUMB := Vector2(40, 20)
const STRIP_Y := 214.0
const SHOWN := 9           # vignettes visibles dans la frise
const BG := Color(0, 0, 0, 0.94)

var main: Node
var opened_frame := -1
var chapter := 0
var level := 0             # rang du niveau dans le chapitre
var t := 0.0
var reveal := 1.0
var strip_pos := 0.0       # défilement de la frise, suit le chapitre en douceur
var canvas: Node2D
var number: Label
var title: Label
var story: Label
var levels: Label
var footer: Label


func _ready() -> void:
	layer = 3
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = BG
	add_child(dim)
	canvas = Node2D.new()
	canvas.draw.connect(_draw_canvas)
	add_child(canvas)
	var head := _label(Rect2(0, 8, 480, 16), 12, HORIZONTAL_ALIGNMENT_CENTER)
	head.text = "C H A P I T R E S"
	number = _label(Rect2(280, 32, 180, 12), 9, HORIZONTAL_ALIGNMENT_LEFT)
	title = _label(Rect2(280, 44, 190, 20), 15, HORIZONTAL_ALIGNMENT_LEFT)
	story = _label(Rect2(280, 68, 180, 50), 9, HORIZONTAL_ALIGNMENT_LEFT)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.modulate = Color(0.75, 0.75, 0.75)
	levels = _label(Rect2(280, 118, 190, 60), 9, HORIZONTAL_ALIGNMENT_LEFT)
	levels.add_theme_constant_override("line_spacing", -1)
	footer = _label(Rect2(0, 252, 480, 14), 8, HORIZONTAL_ALIGNMENT_CENTER)
	footer.modulate = Color(0.6, 0.6, 0.6)


func _label(rect: Rect2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


func open(start_chapter: int) -> void:
	visible = true
	opened_frame = Engine.get_process_frames()
	chapter = start_chapter
	level = 0
	strip_pos = _strip_target()
	reveal = 0.0
	_open_curtain()
	_refresh()


func _chapters() -> Array:
	return main.title_menu.chapters()


func _open_curtain() -> void:
	var tw := create_tween()
	tw.tween_property(self, "reveal", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var ch: Array = _chapters()[chapter]
	var name: String = ch[0]
	number.text = "É P I L O G U E" if LevelData.is_epilogue(ch[1]) else "C H A P I T R E   %d" % (chapter + 1)
	title.text = name if not name.begins_with("#") else "Chapitre %d" % (chapter + 1)
	story.text = ChapterIntro.STORY.get(name, "")
	var lines := PackedStringArray()
	var count: int = _entries(ch)
	level = clampi(level, 0, count - 1)
	for i in count:
		var idx: int = _level_at(ch, i)
		if LevelData.is_bside(idx):
			var bbest: float = main.save.best_level_time(idx)
			lines.append("%sB · %s   %s" % ["› " if i == level else "   ", LevelData.LEVELS[idx]["name"],
				EndScreen.fmt(bbest) if bbest >= 0.0 else "—"])
			continue
		var lvl: Dictionary = LevelData.LEVELS[idx]
		var best: float = main.save.best_level_time(idx)
		var total := LevelData.count(idx, "*")
		var mark := ""
		if total > 0:
			mark = "   étincelle" if main.save.found_sparks(idx).size() >= total else "   ·"
		lines.append("%s%d · %s   %s%s" % ["› " if i == level else "   ", idx + 1, lvl["name"],
			EndScreen.fmt(best) if best >= 0.0 else "—", mark])
	# Face B encore cachée : juste une trace, une fois qu'on sait que les faces B existent
	var b := LevelData.bside_of(name)
	if b >= 0 and not main.save.bside_unlocked(name) and main.save.bsides_unlocked() > 0:
		lines.append("   B · · ·")
	levels.text = "\n".join(lines)
	footer.text = "← →  chapitre      ↑ ↓  niveau      Saut  jouer      Échap  retour"


# Niveaux du chapitre, plus sa face B si elle est ouverte
func _entries(ch: Array) -> int:
	var count: int = ch[2] - ch[1]
	if LevelData.bside_of(ch[0]) >= 0 and main.save.bside_unlocked(ch[0]):
		count += 1
	return count


func _level_at(ch: Array, i: int) -> int:
	if i >= ch[2] - ch[1]:
		return LevelData.bside_of(ch[0])
	return ch[1] + i


func _strip_target() -> float:
	var n: int = _chapters().size()
	return clampf(chapter - SHOWN / 2, 0.0, maxf(0.0, n - SHOWN))


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	strip_pos = lerpf(strip_pos, _strip_target(), 1.0 - exp(-10.0 * delta))
	canvas.queue_redraw()
	if Engine.get_process_frames() == opened_frame:
		return
	var n: int = _chapters().size()
	if Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right"):
		chapter = posmod(chapter + (1 if Input.is_action_just_pressed("right") else -1), n)
		level = 0
		# Petit rideau à chaque changement de vignette
		reveal = 0.15
		_open_curtain()
	elif Input.is_action_just_pressed("up"):
		level -= 1
	elif Input.is_action_just_pressed("down"):
		level += 1
	elif Input.is_action_just_pressed("jump"):
		visible = false
		chosen.emit(_level_at(_chapters()[chapter], level))
		return
	elif Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("dash"):
		visible = false
		closed.emit()
		return
	else:
		return
	var ch: Array = _chapters()[chapter]
	level = posmod(level, _entries(ch))
	main.sfx.play("land", 0.0)
	_refresh()


func _draw_canvas() -> void:
	var list := _chapters()
	Illustrations.draw(canvas, list[chapter][0], BIG, t, reveal, 1.0 + 0.02 * sin(t * 0.4), BG)
	# Frise : la vignette choisie un peu plus grande, les autres en retrait
	var step := THUMB.x + 8.0
	var x0 := 240.0 - SHOWN * step * 0.5 + 4.0
	for i in list.size():
		var x := x0 + (i - strip_pos) * step
		if x < -THUMB.x or x > 480.0:
			continue
		var sel := i == chapter
		var size := THUMB * (1.2 if sel else 1.0)
		var r := Rect2(Vector2(x + (THUMB.x - size.x) * 0.5, STRIP_Y - (size.y - THUMB.y) * 0.5), size)
		Illustrations.draw(canvas, list[i][0], r, t if sel else 0.0, 1.0, 1.0, BG, 1.0 if sel else 0.35)
		if not sel:
			canvas.draw_rect(r, Color(0, 0, 0, 0.55))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y + 9), str(i + 1),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 7, Color(1, 1, 1, 0.9 if sel else 0.4))
	# Petites flèches de part et d'autre de la grande vignette
	var a := 0.4 + 0.3 * sin(t * 3.0)
	var cy := BIG.get_center().y
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(16, cy), Vector2(20, cy - 4), Vector2(20, cy + 4)]), Color(1, 1, 1, a))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(272, cy), Vector2(268, cy - 4), Vector2(268, cy + 4)]), Color(1, 1, 1, a))
