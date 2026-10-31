# Menu de l'écran titre : continuer, nouvelle partie, choix du niveau, statistiques, crédits, options,
# signaler (un bug ou une remarque, voir bug_report.gd), nouvelle version (si update_check.gd en a trouvé une), quitter.
# Les niveaux sont regroupés par chapitres : les niveaux consécutifs de même clé "chapter".
extends Node

signal start_level(index: int, from_start: bool)
signal open_options
signal open_stats
signal open_journal
signal open_chapters(chapter: int)

const LevelData = preload("res://scripts/level_data.gd")
const Looks = preload("res://scripts/looks.gd")
const Credits = preload("res://scripts/credits.gd")
const Lore = preload("res://scripts/lore.gd")
const BugReport = preload("res://scripts/bug_report.gd")

var main: Node
var index := 0
var chapter := 0
var active := false
var watching_credits := false
var report_open := false  # « Signaler » déplié en « un bug » / « une remarque »
var opened_frame := -1
var credits: CanvasLayer


# Chaque chapitre : [nom, premier niveau, niveau après le dernier]
func chapters() -> Array:
	var list := []
	for i in main.save.playable_levels():
		var name: String = LevelData.LEVELS[i].get("chapter", "")
		if name == "":
			name = "#%d" % (i / 3)  # niveaux sans chapitre : groupés par trois
		if list.is_empty() or list[-1][0] != name:
			list.append([name, i, i + 1])
		else:
			list[-1][2] = i + 1
	return list


func chapter_of(level: int) -> int:
	var list := chapters()
	for c in list.size():
		# Une face B appartient au chapitre de même nom
		if LevelData.is_bside(level):
			if list[c][0] == LevelData.LEVELS[level].get("chapter", ""):
				return c
		elif level < list[c][2]:
			return c
	return 0


func chapter_name(c: int) -> String:
	var name: String = chapters()[c][0]
	if name.begins_with("#"):
		return "Chapitre %d" % (c + 1)
	return "Chapitre %d · %s" % [c + 1, name]


func _items() -> Array:
	var items := []
	var last: int = main.save.last_level()
	if last > 0:
		items.append(["continue", "Continuer · niveau %d · %s" % [last + 1, LevelData.LEVELS[last]["name"]]])
	items.append(["new", "Nouvelle partie"])
	# Ouvre l'écran des chapitres sur le chapitre en cours ; on y choisit chapitre et niveau
	items.append(["chapter", "Choix du niveau"])
	items.append(["journal", "Journal"])
	items.append(["stats", "Statistiques"])
	items.append(["credits", "Crédits"])
	items.append(["options", "Options"])
	if report_open:
		items.append(["report_bug", "Signaler · un bug"])
		items.append(["report_note", "Signaler · une remarque"])
	else:
		items.append(["report", "Signaler un bug / une remarque"])
	if main.update_check and main.update_check.latest != "":
		items.append(["update", "Nouvelle version · v%s" % main.update_check.latest])
	items.append(["quit", "Quitter"])
	return items


func open() -> void:
	active = true
	# Depuis la pause, la touche qui ramène au titre ne doit pas aussi lancer une partie
	opened_frame = Engine.get_process_frames()
	index = 0
	report_open = false
	chapter = chapter_of(main.save.last_level())
	redraw()


func redraw() -> void:
	var text := "%s\n%s\n" % [Lore.TITLE, Lore.TAGLINE]
	var items := _items()
	for i in items.size():
		text += ("›  %s  ‹" if i == index else "%s") % items[i][1] + "\n"
	text += "\n"
	var best: float = main.save.best_run_time()
	if best >= 0.0:
		text += "Meilleure partie complète : %s\n" % main._format_time(best)
	main.center_label.text = text


func _process(_delta: float) -> void:
	if not active or main.options.visible or main.stats_screen.visible or main.journal_screen.visible \
			or main.chapter_select.visible:
		return
	if Engine.get_process_frames() == opened_frame:
		return
	if watching_credits:
		_credits_input()
		return
	var items := _items()
	var kind: String = items[index][0]
	if Input.is_action_just_pressed("up"):
		index = posmod(index - 1, items.size())
		_fold_report()
	elif Input.is_action_just_pressed("down"):
		index = posmod(index + 1, items.size())
		_fold_report()
	elif Input.is_action_just_pressed("pause") and report_open:
		_fold_report(true)
	elif Input.is_action_just_pressed("jump"):
		match kind:
			"continue":
				_start(main.save.last_level(), false)
			"new":
				_start(0, true)
			"chapter":
				open_chapters.emit(chapter)
			"journal":
				open_journal.emit()
			"stats":
				open_stats.emit()
			"credits":
				_play_credits()
			"options":
				open_options.emit()
			"report":
				report_open = true
			"report_bug":
				BugReport.open("bug", main.save.last_level())
			"report_note":
				BugReport.open("remarque", main.save.last_level())
			"update":
				main.update_check.open_page()
			"quit":
				get_tree().quit()
		return
	else:
		return
	main.sfx.play("land", 0.0)
	redraw()


# Quitter les deux entrées « Signaler · … » (ou Échap) les replie en une seule
func _fold_report(force := false) -> void:
	if not report_open:
		return
	var kind: String = _items()[index][0]
	if not force and kind.begins_with("report_"):
		return
	var first := 0
	for i in _items().size():
		if _items()[i][0] == "report_bug":
			first = i
			break
	report_open = false
	if force or index > first + 1:
		index = first if force else index - 1


# La réponse de GitHub arrive après l'ouverture du menu : l'entrée « Nouvelle version »
# s'insère avant « Quitter », le curseur reste sur la même entrée.
func update_found() -> void:
	if index == _items().size() - 2:
		index += 1
	if active and main.center_label.visible and not watching_credits:
		redraw()


# Depuis l'écran des chapitres : la partie ne compte pour le record que depuis le niveau 1
func start_from_select(level: int) -> void:
	chapter = chapter_of(level)
	_start(level, level == 0)


func _start(level: int, from_start: bool) -> void:
	active = false
	start_level.emit(level, from_start)


# Les crédits de fin (credits.gd), rejoués depuis le titre avec les compteurs cumulés.
# Instance à part : celle de l'écran de fin est cachée avec lui.
func _play_credits() -> void:
	if not credits:
		credits = Credits.new()
		add_child(credits)
	watching_credits = true
	main.center_label.visible = false
	credits.start(main.stats.deaths, main.save.total_sparks_found(), Looks.total_sparks())


func _credits_input() -> void:
	if Input.is_action_just_pressed("pause") or (Input.is_action_just_pressed("jump") and credits.done()):
		credits.close()
		watching_credits = false
		main.center_label.visible = true
		redraw()
	elif Input.is_action_just_pressed("jump") and credits.running():
		credits.skip()
