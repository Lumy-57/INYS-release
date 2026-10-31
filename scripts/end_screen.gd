# Écran de fin : bilan de la partie niveau par niveau, avec les records,
# puis l'épilogue et les crédits (credits.gd).
extends CanvasLayer

const Credits = preload("res://scripts/credits.gd")

var bg: ColorRect
var title: Label
var table: Label
var footer: Label
var credits: CanvasLayer
var run_deaths := 0
var run_sparks := 0
var run_sparks_total := 0


func _ready() -> void:
	layer = 6
	visible = false

	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	add_child(bg)

	title = _label(16, 24)
	title.text = "Le fantôme a retrouvé la lumière."
	table = _label(10, 62)
	footer = _label(10, 250)

	credits = Credits.new()
	add_child(credits)


func _label(size: int, top: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


# results : tableau de {name, time, deaths, record, sparks, sparks_total} ; not_ranked
# explique pourquoi le temps total n'est pas comparé au record (vide sinon).
func show_results(results: Array, total: float, deaths: int, run_record: bool, best_total: float, not_ranked: String) -> void:
	var lines := PackedStringArray()
	run_deaths = deaths
	run_sparks = 0
	run_sparks_total = 0
	for i in results.size():
		# Les niveaux sautés depuis le menu pause restent vides
		if results[i] == null:
			continue
		var r: Dictionary = results[i]
		run_sparks += r["sparks"]
		run_sparks_total += r["sparks_total"]
		var sparks := ""
		if r["sparks_total"] > 0:
			sparks = "   étincelles %d/%d" % [r["sparks"], r["sparks_total"]]
		lines.append("%d · %s   %s   %s%s%s" % [i + 1, r["name"], fmt(r["time"]), morts(r["deaths"]), sparks, "   record !" if r["record"] else ""])
	lines.append("")
	lines.append("Total   %s   %s" % [fmt(total), morts(deaths)])
	if not_ranked != "":
		lines.append("(%s : pas de record global)" % not_ranked)
	elif run_record:
		lines.append("Nouveau meilleur temps !")
	elif best_total >= 0.0:
		lines.append("Meilleur temps : %s" % fmt(best_total))
	table.text = "\n".join(lines)
	# Avec beaucoup de niveaux, le tableau se resserre pour laisser la place au bas d'écran
	table.add_theme_font_size_override("font_size", 10 if lines.size() <= 11 else 8)
	footer.text = "Saut pour continuer"
	visible = true
	for n in [title, table, footer]:
		n.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.6)
	tw.tween_property(table, "modulate:a", 1.0, 0.6)
	tw.tween_property(footer, "modulate:a", 1.0, 0.4)


# Appelé à chaque appui sur Saut une fois la partie finie : lance l'épilogue,
# le passe, et renvoie true quand le joueur quitte la carte « Fin ».
func advance() -> bool:
	if credits.done():
		credits.close()
		visible = false
		return true
	if credits.running():
		credits.skip()
	else:
		credits.start(run_deaths, run_sparks, run_sparks_total)
	return false


static func fmt(t: float) -> String:
	return "%02d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


static func morts(n: int) -> String:
	return "%d mort%s" % [n, "s" if n > 1 else ""]
