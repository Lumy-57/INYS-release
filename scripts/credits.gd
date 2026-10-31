# Fin du jeu : court épilogue du fantôme, puis crédits qui défilent.
# Saut passe à la fin à tout moment ; à la carte « Fin », Saut revient au titre.
extends CanvasLayer

const GhostVisual = preload("res://scripts/ghost_visual.gd")
const LevelData = preload("res://scripts/level_data.gd")
const Lore = preload("res://scripts/lore.gd")

const SCROLL_SPEED := 22.0
const VIEW := Vector2(480, 270)

enum { HIDDEN, EPILOGUE, SCROLL, DONE }

var state := HIDDEN
var bg: ColorRect
var ghost: Node2D
var epilogue: Label
var scroll: Label
var fin: Label
var tween: Tween
# Vraie fin : toutes les étincelles du jeu trouvées (réglé par main avant start)
var true_ending := false


func _ready() -> void:
	layer = 7
	visible = false

	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	add_child(bg)

	ghost = GhostVisual.new()
	ghost.scale = Vector2(2, 2)
	add_child(ghost)

	epilogue = Label.new()
	epilogue.set_anchors_preset(Control.PRESET_FULL_RECT)
	epilogue.offset_top = 40
	epilogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epilogue.add_theme_font_size_override("font_size", 10)
	epilogue.add_theme_constant_override("line_spacing", 6)
	add_child(epilogue)

	scroll = Label.new()
	scroll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.add_theme_font_size_override("font_size", 10)
	scroll.size.x = VIEW.x
	add_child(scroll)

	fin = Label.new()
	fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fin.add_theme_font_size_override("font_size", 12)
	add_child(fin)


func running() -> bool:
	return state == EPILOGUE or state == SCROLL


func done() -> bool:
	return state == DONE


# deaths : morts de la partie ; sparks / sparks_total : étincelles ramassées pendant la partie
func start(deaths: int, sparks: int, sparks_total: int) -> void:
	state = EPILOGUE
	visible = true
	scroll.visible = false
	fin.visible = false
	epilogue.visible = true
	ghost.visible = true
	ghost.modulate.a = 0.0
	ghost.position = Vector2(VIEW.x / 2, 228)
	bg.modulate.a = 0.0
	scroll.text = _credits_text()
	# Après la vraie fin, la nuit n'est pas tout à fait finie : main lance l'épilogue
	fin.text = "F I N\n\n\n\n%s" % ("Saut pour continuer" if true_ending else "Saut pour revenir au titre")

	var full := true_ending or (sparks_total > 0 and sparks >= sparks_total)
	var lines := _epilogue_lines(deaths, sparks, sparks_total, full)
	epilogue.text = "\n".join(lines)
	epilogue.add_theme_font_size_override("font_size", 10 if lines.size() <= 9 else 9)
	epilogue.visible_ratio = 0.0

	tween = create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 1.0)
	tween.tween_property(ghost, "modulate:a", 1.0, 0.8)
	# Les lignes apparaissent une par une, comme écrites à la main
	var total_chars := float(epilogue.get_total_character_count())
	var shown := 0
	for line in lines:
		shown += line.length() + 1
		var ratio := minf(shown / maxf(total_chars, 1.0), 1.0)
		tween.tween_property(epilogue, "visible_ratio", ratio, 0.04 * line.length() + 0.1)
		tween.tween_interval(0.9 if line != "" else 0.2)
	tween.tween_interval(1.2)
	# Le fantôme s'élève et s'efface dans la lumière, le texte avec lui
	tween.tween_property(ghost, "position:y", -20.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 2.6)
	tween.parallel().tween_property(epilogue, "modulate:a", 0.0, 1.6)
	tween.tween_callback(_start_scroll)


func _start_scroll() -> void:
	state = SCROLL
	epilogue.visible = false
	ghost.visible = false
	scroll.visible = true
	scroll.size = Vector2(VIEW.x, 0)
	var h := scroll.get_combined_minimum_size().y
	scroll.position = Vector2(0, VIEW.y)
	tween = create_tween()
	tween.tween_property(scroll, "position:y", -h, (VIEW.y + h) / SCROLL_SPEED)
	tween.tween_callback(_show_fin)


func skip() -> void:
	if running():
		_show_fin()


func _show_fin() -> void:
	if tween:
		tween.kill()
	state = DONE
	bg.modulate.a = 1.0
	epilogue.visible = false
	ghost.visible = false
	scroll.visible = false
	fin.visible = true
	fin.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(fin, "modulate:a", 1.0, 1.0)


func close() -> void:
	if tween:
		tween.kill()
	state = HIDDEN
	visible = false
	epilogue.modulate.a = 1.0


static func _epilogue_lines(deaths: int, sparks: int, sparks_total: int, full := false) -> PackedStringArray:
	var lines := PackedStringArray([
		"Le fantôme s'arrête au bord de la faille.",
		"Derrière lui, la vieille tour retombe dans le noir.",
		"",
	])
	if deaths == 0:
		lines.append("Il n'est pas tombé une seule fois.")
	else:
		lines.append("Il est tombé %d fois. Il s'est relevé %d fois." % [deaths, deaths])
	if sparks_total > 0 and sparks == sparks_total:
		lines.append("Il emporte toutes les étincelles de la tour.")
	elif sparks > 0:
		lines.append("Il emporte %d étincelle%s." % [sparks, "s" if sparks > 1 else ""])
	if full:
		# Toutes les étincelles : le journal est complet
		lines.append_array(PackedStringArray(Lore.TRUE_ENDING))
		return lines
	lines.append("")
	lines.append("Pour la première fois, la lumière ne vient pas de lui.")
	lines.append("Elle l'attendait dehors.")
	return lines


static func _credits_text() -> String:
	var chapters := PackedStringArray()
	# L'épilogue reste un secret, même dans les crédits
	for i in LevelData.story_end():
		chapters.append("%d · %s" % [i + 1, LevelData.LEVELS[i]["name"]])
	var parts := [
		Lore.TITLE,
		Lore.TAGLINE,
		"\n\n",
		"UN JEU DE",
		"Lumy",
		"\n",
		"CONCEPTION ET NIVEAUX",
		"Lumy",
		"\n",
		"PROGRAMMATION",
		"Lumy",
		"\n",
		"MUSIQUE ET SONS",
		"Synthétisés par le jeu, note après note",
		"\n",
		"LES NIVEAUX",
		"\n".join(chapters),
		"\n",
		"MOTEUR",
		"Godot Engine 4",
		"\n",
		"INSPIRÉ PAR",
		"Celeste",
		"prototype INYS",
		"\n\n\n",
		"Merci d'avoir joué.",
	]
	return "\n".join(parts)
