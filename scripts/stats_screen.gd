# Écran Statistiques, ouvert depuis le titre : les compteurs de stats.gd à gauche,
# le record et les étincelles de chaque niveau à droite. Saut ou Échap pour revenir.
extends CanvasLayer

signal closed

const LevelData = preload("res://scripts/level_data.gd")
const EndScreen = preload("res://scripts/end_screen.gd")

var main: Node
var opened_frame := -1
var title: Label
var left: Label
var names: Label
var times: Label
var marks: Label
var footer: Label


func _ready() -> void:
	layer = 3
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.92)
	add_child(dim)
	title = _label(Rect2(0, 12, 480, 20), 14, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "STATISTIQUES"
	left = _label(Rect2(24, 48, 170, 190), 10, HORIZONTAL_ALIGNMENT_LEFT)
	# Trois colonnes alignées : niveau, record, étincelle
	names = _label(Rect2(220, 44, 120, 196), 9, HORIZONTAL_ALIGNMENT_LEFT)
	times = _label(Rect2(330, 44, 60, 196), 9, HORIZONTAL_ALIGNMENT_RIGHT)
	marks = _label(Rect2(400, 44, 60, 196), 9, HORIZONTAL_ALIGNMENT_LEFT)
	footer = _label(Rect2(0, 248, 480, 16), 9, HORIZONTAL_ALIGNMENT_CENTER)
	footer.text = "Saut ou Échap pour revenir"


func _label(rect: Rect2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


func open() -> void:
	visible = true
	opened_frame = Engine.get_process_frames()
	var st: Node = main.stats
	var save: RefCounted = main.save
	var total_sparks := 0
	var col_names := PackedStringArray()
	var col_times := PackedStringArray()
	var col_marks := PackedStringArray()
	for i in save.playable_levels():
		var lvl: Dictionary = LevelData.LEVELS[i]
		var n := 0
		for row in lvl["map"]:
			n += row.count("*")
		total_sparks += n
		var best: float = save.best_level_time(i)
		col_names.append("%d · %s" % [i + 1, lvl["name"]])
		col_times.append(EndScreen.fmt(best) if best >= 0.0 else "—")
		col_marks.append("" if n == 0 else ("étincelle" if save.found_sparks(i).size() >= n else "·"))
	# Le tableau se resserre quand les niveaux s'ajoutent, pour tenir au-dessus du bas d'écran
	var count: int = save.playable_levels()
	for l in [names, times, marks]:
		l.add_theme_font_size_override("font_size", 9 if count <= 12 else (8 if count <= 15 else 7))
		l.add_theme_constant_override("line_spacing", 0 if count <= 15 else -2)
	names.text = "\n".join(col_names)
	times.text = "\n".join(col_times)
	marks.text = "\n".join(col_marks)

	var best_run: float = save.best_run_time()
	left.text = "\n".join([
		"Temps de jeu   %s" % st.duration(st.play_time),
		"Morts   %d" % st.deaths,
		"Sauts   %d" % st.jumps,
		"Dashs   %d" % st.dashes,
		"",
		"Niveaux finis   %d" % st.levels_finished,
		"Parties finies   %d" % st.games_finished,
		"Meilleure partie   %s" % (EndScreen.fmt(best_run) if best_run >= 0.0 else "—"),
		"",
		"Étincelles   %d / %d" % [save.total_sparks_found(), total_sparks],
	])
	# Les faces B n'apparaissent qu'une fois la première trouvée
	if save.bsides_unlocked() > 0:
		left.text += "\n" + "Faces B   %d / %d   (finies %d)" % [save.bsides_unlocked(),
			LevelData.LEVELS.size() - LevelData.bside_start(), save.bsides_finished()]


func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == opened_frame:
		return
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
		visible = false
		closed.emit()
