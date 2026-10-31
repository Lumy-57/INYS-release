# Racine du jeu : construit les niveaux depuis level_data.gd, gère la caméra,
# les morts, les checkpoints, les transitions et le HUD.
extends Node2D

const TILE := 16
const VIEW_HALF := Vector2(240, 135)  # demi-écran, en px du monde
const LevelData = preload("res://scripts/level_data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const TilesDrawer = preload("res://scripts/tiles_drawer.gd")
const Crystal = preload("res://scripts/crystal.gd")
const Checkpoint = preload("res://scripts/checkpoint.gd")
const ExitPortal = preload("res://scripts/exit_portal.gd")
const PhaseBlocks = preload("res://scripts/phase_blocks.gd")
const CrumbleBlock = preload("res://scripts/crumble_block.gd")
const Updraft = preload("res://scripts/updraft.gd")
const Spring = preload("res://scripts/spring.gd")
const Mover = preload("res://scripts/mover.gd")
const Rail = preload("res://scripts/rail.gd")
const Bell = preload("res://scripts/bell.gd")
const ToggleBlocks = preload("res://scripts/toggle_blocks.gd")
const TimedBlocks = preload("res://scripts/timed_blocks.gd")
const ShadowChaser = preload("res://scripts/shadow_chaser.gd")
const RisingDark = preload("res://scripts/rising_dark.gd")
const Watchers = preload("res://scripts/watchers.gd")
const MirrorGlass = preload("res://scripts/mirror.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Fx = preload("res://scripts/fx.gd")
const SaveData = preload("res://scripts/save_data.gd")
const EndScreen = preload("res://scripts/end_screen.gd")
const Options = preload("res://scripts/options.gd")
const Looks = preload("res://scripts/looks.gd")
const Music = preload("res://scripts/music.gd")
const Spark = preload("res://scripts/spark.gd")
const TitleMenu = preload("res://scripts/title_menu.gd")
const TitleBackdrop = preload("res://scripts/title_backdrop.gd")
const Stats = preload("res://scripts/stats.gd")
const StatsScreen = preload("res://scripts/stats_screen.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const ChapterIntro = preload("res://scripts/chapter_intro.gd")
const JournalScreen = preload("res://scripts/journal_screen.gd")
const ChapterSelect = preload("res://scripts/chapter_select.gd")
const Lore = preload("res://scripts/lore.gd")
const HintOrb = preload("res://scripts/hint_orb.gd")
const OrbBlocks = preload("res://scripts/orb_blocks.gd")
const FakeWall = preload("res://scripts/fake_wall.gd")
const Palette = preload("res://scripts/palette.gd")
const UpdateCheck = preload("res://scripts/update_check.gd")

const AMBIENT := Color(0.09, 0.09, 0.09)
const RIM := 4.0  # liseré non occultant : les bords des murs captent la lumière

var level_index := 0
var world: Node2D
var level_root: Node2D
var chapter_intro: CanvasLayer
var ambient: CanvasModulate
var chapter_select: CanvasLayer
var music: AudioStreamPlayer
var player: CharacterBody2D
var hint_orb: Node2D  # orbe blanche qui dit les indices
var camera: Camera2D
var respawn_point := Vector2.ZERO
var room_size := Vector2.ZERO
var crystals: Array = []
var crumbles: Array = []
var checkpoints: Array = []
var chimes: Node2D  # blocs de carillon du niveau, s'il y en a
var chaser: Node2D  # ombre poursuivante, s'il y en a une
var dark: Node2D    # marée de ténèbres, s'il y en a une
var watchers: Node2D  # yeux qui regardent, s'il y en a
var orb_blocks: Node2D  # pierres cachées que montre l'orbe, s'il y en a
# Chapitre Miroir : le reflet, contrôlé en même temps que le fantôme, gauche et droite inversées
var reflection: CharacterBody2D
var reflection_respawn := Vector2.ZERO
var arrived := {}         # fantômes déjà entrés dans une sortie
var since_respawn := 0.0  # la caméra se recale après une réapparition
var cam_follow: Node2D    # milieu des deux fantômes, suivi par la caméra
var deaths := 0
var elapsed := 0.0
var shake := 0.0
var busy := false
var finished := false
var on_title := true
var paused := false
var menu_index := 0
var menu_level := 0
var sfx: Node
var fx: Node
var save := SaveData.new()
var end_screen: CanvasLayer
var level_time := 0.0
var level_deaths := 0
var results: Array = []
var run_valid := true
var run_assisted := false
var options: CanvasLayer
var title_menu: Node
var update_check: Node
var stats: Node
var stats_screen: CanvasLayer
var journal_screen: CanvasLayer
var sparks: Array = []
var sparks_taken: Array = []
var secret_taken := false  # le fantôme est sorti par la sortie secrète
var menu_label: Label

var hud_label: Label
var title_label: Label
var center_label: Label
var version_label: Label
var center_bg: StyleBoxFlat
var fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = Sfx.new()
	add_child(sfx)
	fx = Fx.new()
	fx.main = self
	add_child(fx)
	end_screen = EndScreen.new()
	add_child(end_screen)
	options = Options.new()
	options.sfx = sfx
	options.main = self
	options.closed.connect(_draw_menu)
	add_child(options)
	title_menu = TitleMenu.new()
	title_menu.main = self
	title_menu.start_level.connect(_on_title_start)
	title_menu.open_options.connect(func():
		center_label.visible = false
		options.open())
	options.closed.connect(func():
		if on_title:
			center_label.visible = true
			title_menu.redraw())
	add_child(title_menu)
	music = Music.new()
	add_child(music)

	ambient = CanvasModulate.new()
	ambient.color = AMBIENT
	add_child(ambient)

	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_player_died)
	hint_orb = HintOrb.new()
	hint_orb.process_mode = Node.PROCESS_MODE_PAUSABLE
	hint_orb.player = player
	hint_orb.main = self
	add_child(hint_orb)
	player.dashed.connect(func():
		add_shake(2.0)
		fx.on_dashed(player)
		hint_orb.dash_ahead(player.dash_dir)
		sfx.play("dash"))
	player.jumped.connect(func():
		fx.on_jumped(player)
		sfx.play("jump", 0.1))
	player.landed.connect(func():
		fx.on_landed(player)
		sfx.play("land", 0.15))

	# Après le joueur : les statistiques écoutent ses signaux
	stats = Stats.new()
	stats.main = self
	add_child(stats)
	stats_screen = StatsScreen.new()
	stats_screen.main = self
	add_child(stats_screen)
	chapter_intro = ChapterIntro.new()
	add_child(chapter_intro)
	journal_screen = JournalScreen.new()
	journal_screen.main = self
	add_child(journal_screen)
	title_menu.open_journal.connect(func():
		center_label.visible = false
		journal_screen.open())
	journal_screen.closed.connect(func():
		center_label.visible = true
		title_menu.redraw())
	chapter_select = ChapterSelect.new()
	chapter_select.main = self
	add_child(chapter_select)
	title_menu.open_chapters.connect(func(c: int):
		center_label.visible = false
		chapter_select.open(c))
	chapter_select.closed.connect(func():
		center_label.visible = true
		title_menu.opened_frame = Engine.get_process_frames()
		title_menu.redraw())
	chapter_select.chosen.connect(title_menu.start_from_select)
	title_menu.open_stats.connect(func():
		center_label.visible = false
		stats_screen.open())
	stats_screen.closed.connect(func():
		center_label.visible = true
		title_menu.redraw())

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)

	_build_hud()
	_load_level(0)
	_show_title()

	# Nouvelle version sur INYS-release : signalée près du numéro de version et dans le menu titre
	update_check = UpdateCheck.new()
	update_check.found.connect(func(version: String, _url: String):
		version_label.text += "  ·  v%s disponible" % version
		title_menu.update_found())
	add_child(update_check)
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.35, 0.9, length(uv * vec2(1.4, 1.0)));
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.8);
}
"""
	vignette.material = mat
	layer.add_child(vignette)

	hud_label = Label.new()
	hud_label.position = Vector2(8, 4)
	hud_label.add_theme_font_size_override("font_size", 10)
	hud_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	layer.add_child(hud_label)

	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 40
	title_label.offset_bottom = 70
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.modulate.a = 0.0
	layer.add_child(title_label)

	# Fond illustré du titre : au-dessus du niveau et du chrono, sous le texte du menu
	var title_backdrop := TitleBackdrop.new()
	title_backdrop.main = self
	layer.add_child(title_backdrop)

	center_label = Label.new()
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 14)
	center_label.visible = false
	center_bg = StyleBoxFlat.new()
	center_bg.bg_color = Color(0, 0, 0, 0.7)
	center_label.add_theme_stylebox_override("normal", center_bg)
	layer.add_child(center_label)

	# Version du jeu (application/config/version), discrète en bas à droite du menu titre
	version_label = Label.new()
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version_label.offset_left = -240
	version_label.offset_top = -14
	version_label.offset_right = -6
	version_label.offset_bottom = -3
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 8)
	version_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "?"))
	version_label.visible = false
	layer.add_child(version_label)

	menu_label = Label.new()
	menu_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_label.add_theme_font_size_override("font_size", 12)
	menu_label.visible = false
	var menu_bg := StyleBoxFlat.new()
	menu_bg.bg_color = Color(0, 0, 0, 0.75)
	menu_label.add_theme_stylebox_override("normal", menu_bg)
	layer.add_child(menu_label)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0, 0, 0, 1)
	layer.add_child(fade)


func _load_level(index: int) -> void:
	level_index = index
	if level_root:
		# Retiré tout de suite pour que ses collisions ne gênent pas l'apparition
		world.remove_child(level_root)
		level_root.queue_free()
	level_root = Node2D.new()
	world.add_child(level_root)
	crumbles.clear()
	chimes = null
	chaser = null
	dark = null
	watchers = null
	orb_blocks = null
	reflection = null
	arrived.clear()
	since_respawn = 0.0
	crystals.clear()
	checkpoints.clear()
	sparks.clear()
	sparks_taken.clear()
	secret_taken = false
	var found_sparks := save.found_sparks(index)
	level_time = 0.0
	level_deaths = 0

	var data: Dictionary = LevelData.LEVELS[index]
	var colors := Palette.strength(index)
	# Une case peut porter plusieurs éléments (un par calque de la scène) : grid[y][x] est la chaîne
	# de leurs caractères, "" pour une case vide
	var grid := LevelData.grid(index)
	var h := grid.size()
	var w: int = grid[0].size() if h > 0 else 0
	room_size = Vector2(w, h) * TILE

	var is_solid := func(x: int, y: int) -> bool:
		if x < 0 or x >= w or y < 0:
			return true
		if y >= h:
			return false
		return "#" in grid[y][x] or "=" in grid[y][x]

	# Pour le dessin, les fausses parois (et la sortie secrète qu'elles cachent) comptent comme
	# des murs : aucun liseré ne les trahit
	var looks_solid := func(x: int, y: int) -> bool:
		return is_solid.call(x, y) or (x >= 0 and x < w and y >= 0 and y < h and ("%" in grid[y][x] or "e" in grid[y][x]))

	var drawer := TilesDrawer.new()
	drawer.wall = Palette.wall(colors)
	drawer.rim = Palette.rim(colors)
	var phase_runs := {"L": [], "O": [], "X": [], "|": []}
	var mover_cells := {"M": [], "W": []}
	var rail_cells := []
	var chime_cells := {"a": [], "b": [], "B": []}
	var timed_cells := {"1": [], "2": []}
	var has_chaser := false
	var dark_top := -1.0
	var eye_cells := []
	var reflect_start := Vector2.INF
	var glass_cells := []
	var hidden_cells := []
	var fake := FakeWall.new()
	var body := StaticBody2D.new()
	level_root.add_child(body)

	# Collision : rectangles fusionnés
	var used := {}
	for y in h:
		for x in w:
			if not is_solid.call(x, y) or used.has(Vector2i(x, y)):
				continue
			var rw := 1
			while x + rw < w and is_solid.call(x + rw, y) and not used.has(Vector2i(x + rw, y)):
				rw += 1
			var rh := 1
			var can_grow := true
			while can_grow and y + rh < h:
				for i in rw:
					if not is_solid.call(x + i, y + rh) or used.has(Vector2i(x + i, y + rh)):
						can_grow = false
						break
				if can_grow:
					rh += 1
			for j in rh:
				for i in rw:
					used[Vector2i(x + i, y + j)] = true
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(rw, rh) * TILE
			cs.shape = rect
			cs.position = Vector2(x, y) * TILE + rect.size * 0.5
			body.add_child(cs)

	# Rendu, ombres et entités
	var occluders := Node2D.new()
	level_root.add_child(occluders)
	for y in h:
		for x in w:
			var here: String = grid[y][x]
			var cell := Vector2i(x, y)
			var base := Vector2(x, y) * TILE
			# Fausse paroi : dessinée comme un mur ; la sortie secrète est cachée dessous
			if "%" in here or "e" in here:
				fake.cells.append(cell)
				var fake_rims := [cell, not looks_solid.call(x, y - 1), not looks_solid.call(x, y + 1),
					not looks_solid.call(x - 1, y), not looks_solid.call(x + 1, y)]
				if fake_rims.has(true):
					fake.edges.append(fake_rims)
			for c in here:
				match c:
					"#":
						drawer.solids.append(cell)
						var up: bool = not is_solid.call(x, y - 1)
						var down: bool = not is_solid.call(x, y + 1)
						var left: bool = not is_solid.call(x - 1, y)
						var right: bool = not is_solid.call(x + 1, y)
						var rims := [cell, not looks_solid.call(x, y - 1), not looks_solid.call(x, y + 1),
							not looks_solid.call(x - 1, y), not looks_solid.call(x + 1, y)]
						if rims.has(true):
							drawer.edges.append(rims)
						if up or down or left or right:
							var r := Rect2(base, Vector2(TILE, TILE))
							r = r.grow_individual(-RIM if left else 0.0, -RIM if up else 0.0, -RIM if right else 0.0, -RIM if down else 0.0)
							var occ := LightOccluder2D.new()
							var poly := OccluderPolygon2D.new()
							poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
							occ.occluder = poly
							occluders.add_child(occ)
					"^", "v", "<", ">":
						drawer.spikes.append([cell, c])
						_add_spike(base, c)
					"L", "O":
						phase_runs[c].append(cell)
					"X", "|":
						phase_runs[c].append(cell)
					"M", "W":
						mover_cells[c].append(cell)
					"-":
						rail_cells.append(cell)
					"a", "b", "B":
						chime_cells[c].append(cell)
					"1", "2":
						timed_cells[c].append(cell)
					"H":
						has_chaser = true
					"~":
						dark_top = base.y
					"R":
						reflect_start = base + Vector2(8, 16 - 7)
					"=":
						glass_cells.append(cell)
					"i":
						hidden_cells.append(cell)
					"Y", "y":
						eye_cells.append([base + Vector2(8, 8), 0.0 if c == "Y" else 0.5])
					"S":
						var spring := Spring.new()
						spring.position = base + Vector2(8, 16)
						spring.player = player
						spring.launched.connect(func(_s):
							sfx.play("jump", 0.0)
							add_shake(1.5))
						level_root.add_child(spring)
					"P":
						respawn_point = base + Vector2(8, 16 - 7)
					"C":
						var cp := Checkpoint.new()
						cp.position = base + Vector2(8, 16)
						cp.reached.connect(_on_checkpoint)
						level_root.add_child(cp)
						checkpoints.append(cp)
					"D":
						var cr := Crystal.new()
						cr.position = base + Vector2(8, 8)
						cr.touched.connect(_on_crystal)
						level_root.add_child(cr)
						crystals.append(cr)
					"E", "e":
						var ex := ExitPortal.new()
						ex.position = base + Vector2(8, 16)
						ex.secret = c == "e"
						if ex.secret:
							ex.veil = fake
							ex.cell = cell
							fake.secrets.append(cell)
						ex.entered.connect(_on_exit)
						level_root.add_child(ex)
					"*":
						var sp := Spark.new()
						sp.position = base + Vector2(8, 8)
						sp.cell = cell
						sp.known = found_sparks.has(cell)
						sp.collected.connect(_on_spark)
						level_root.add_child(sp)
						sparks.append(sp)
	level_root.add_child(drawer)
	level_root.move_child(drawer, 0)
	var has_fake := not fake.cells.is_empty()
	if has_fake:
		fake.wall = drawer.wall
		fake.rim = drawer.rim
		fake.ghosts = [player]
		fake.discovered.connect(func(): sfx.play("crystal", 0.0))
		level_root.add_child(fake)
	else:
		fake.free()
	_add_movers(mover_cells, rail_cells, grid)
	_add_chimes(chime_cells)
	var tb: Node2D = null
	if not (timed_cells["1"].is_empty() and timed_cells["2"].is_empty()):
		tb = TimedBlocks.new()
		tb.runs_1 = _merge_cells(timed_cells["1"])
		tb.runs_2 = _merge_cells(timed_cells["2"])
		tb.player = player
		level_root.add_child(tb)
	_add_pursuers(has_chaser, dark_top, data.get("companion", false))
	_add_reflection(reflect_start, glass_cells)
	if has_fake and reflection:
		fake.ghosts.append(reflection)
	if not eye_cells.is_empty():
		watchers = Watchers.new()
		watchers.eyes = eye_cells
		watchers.player = player
		level_root.add_child(watchers)
	# Chapitre Compagnie : les pierres cachées n'apparaissent que près de l'orbe
	hint_orb.set_scout(not hidden_cells.is_empty())
	if not hidden_cells.is_empty():
		orb_blocks = OrbBlocks.new()
		orb_blocks.cells = hidden_cells
		orb_blocks.player = player
		orb_blocks.orb = hint_orb
		level_root.add_child(orb_blocks)
	for k in phase_runs:
		if phase_runs[k].is_empty():
			continue
		if k == "X":
			for r in _merge_cells(phase_runs[k]):
				var cb := CrumbleBlock.new()
				cb.rect = r
				cb.player = player
				cb.crumbled.connect(func(_b): sfx.play("land", 0.3))
				level_root.add_child(cb)
				crumbles.append(cb)
			continue
		if k == "|":
			for r in _merge_cells(phase_runs[k]):
				var ud := Updraft.new()
				ud.rect = r
				ud.player = player
				level_root.add_child(ud)
			continue
		var pb := PhaseBlocks.new()
		pb.kind = k
		pb.runs = _merge_cells(phase_runs[k])
		pb.player = player
		level_root.add_child(pb)

	# Les indices ne sont plus écrits sur les murs : l'orbe les dit quand on approche
	var hints := []
	for hint in data.get("hints", []):
		hints.append([hint[0], hint[1], _hint_text(hint[2])])

	_add_dust(colors)
	var backdrop := Backdrop.new()
	level_root.add_child(backdrop)
	backdrop.setup(data.get("chapter", ""), room_size, colors)
	# Épilogue : le noir s'adoucit, la lueur du fantôme se réchauffe, la musique se calme
	ambient.color = Palette.ambient(colors)
	player.light.color = Palette.light(colors)
	# Chaque chapitre a son thème ; l'énergie monte au fil du jeu et au fil du chapitre
	music.set_chapter(data.get("chapter", ""))
	var in_chapter := _chapter_progress(index)
	if LevelData.is_epilogue(index):
		music.set_intensity(0.1 + 0.3 * in_chapter)
	elif LevelData.is_bside(index):
		music.set_intensity(1.0)  # face B : la musique au plus fort
	else:
		var in_game := float(index) / maxf(1.0, LevelData.story_end() - 1.0)
		music.set_intensity(0.7 * in_game + 0.3 * in_chapter)
	music.set_clocks(tb, watchers)

	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room_size.x)
	camera.limit_bottom = int(room_size.y)
	player.respawn(respawn_point)
	camera.reset_smoothing()
	hint_orb.set_hints(hints)
	if not on_title and not LevelData.is_bside(index):
		save.set_last_level(index)

	title_label.text = _level_label(index)
	if on_title:
		return
	var tw := create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(title_label, "modulate:a", 0.0, 0.8)


# « 12 · Clocher », ou « Face B · … » pour une face B
func _level_label(index: int) -> String:
	if LevelData.is_bside(index):
		return "Face B · %s" % LevelData.LEVELS[index]["name"]
	return "%d · %s" % [index + 1, LevelData.LEVELS[index]["name"]]


# Plateformes mobiles : M glisse à l'horizontale, W à la verticale, le long des cases "-"
func _add_movers(mover_cells: Dictionary, rail_cells: Array, grid: Array) -> void:
	if not rail_cells.is_empty():
		var rail := Rail.new()
		rail.cells = rail_cells
		level_root.add_child(rail)
	for k in mover_cells:
		for r in _merge_cells(mover_cells[k]):
			var c0 := Vector2i(r.position / TILE)
			var n := Vector2i(r.size / TILE)
			var mv := Mover.new()
			mv.size = r.size
			mv.start = r.position
			mv.vertical = k == "W"
			var step := Vector2i(0, 1) if mv.vertical else Vector2i(1, 0)
			var before := 0
			while "-" in _cell(grid, c0 - step * (before + 1)):
				before += 1
			var after := 0
			var far := c0 + Vector2i(n.x - 1, n.y - 1)
			while "-" in _cell(grid, far + step * (after + 1)):
				after += 1
			mv.low = -before * TILE
			mv.high = after * TILE
			level_root.add_child(mv)


# Les indices écrivent {jump}, {dash}, {left}, {right} : on y met les touches choisies par le joueur
func _hint_text(t: String) -> String:
	for a in ["jump", "dash", "left", "right"]:
		var names := []
		for k in Controls.keys[a].slice(0, 2):
			names.append(Controls.KEY_NAMES[k] if Controls.KEY_NAMES.has(k) else OS.get_keycode_string(k))
		t = t.replace("{%s}" % a, " / ".join(names) if names else "?")
	return t


# Cloches (B) et blocs de carillon (a solides au repos, b solides une fois sonnés)
func _add_chimes(cells: Dictionary) -> void:
	if cells["a"].is_empty() and cells["b"].is_empty() and cells["B"].is_empty():
		return
	chimes = ToggleBlocks.new()
	chimes.runs_a = _merge_cells(cells["a"])
	chimes.runs_b = _merge_cells(cells["b"])
	chimes.player = player
	level_root.add_child(chimes)
	var bells := []
	for c in cells["B"]:
		var bell := Bell.new()
		bell.position = Vector2(c) * TILE + Vector2(8, 8)
		bell.player = player
		level_root.add_child(bell)
		bells.append(bell)
	for bell in bells:
		bell.rung.connect(func(_b):
			chimes.ring()
			for other in bells:
				other.shake()
			sfx.play("candle", 0.0)
			add_shake(1.0))
	# Chaque bougie mémorise l'état des cloches
	for cp in checkpoints:
		cp.reached.connect(func(_cp, b): if b == player: chimes.save())


# Chapitre Miroir : le reflet part de "R" ; la caméra suit le milieu des deux fantômes
func _add_reflection(start: Vector2, glass_cells: Array) -> void:
	if not glass_cells.is_empty():
		var glass := MirrorGlass.new()
		glass.cells = glass_cells
		level_root.add_child(glass)
	if cam_follow == null:
		cam_follow = Node2D.new()
		world.add_child(cam_follow)
	if start == Vector2.INF:
		if camera.get_parent() != player:
			camera.reparent(player, false)
			camera.position = Vector2.ZERO
		return
	reflection = PlayerScript.new()
	reflection.mirror = true
	# Hérite du monde : s'arrête avec lui sur l'écran titre
	reflection.process_mode = Node.PROCESS_MODE_INHERIT
	level_root.add_child(reflection)
	reflection.modulate = Color(1, 1, 1, 0.7)
	reflection.respawn(start)
	reflection_respawn = start
	# Si l'un meurt, l'autre aussi : ils repartent ensemble
	reflection.died.connect(func():
		if not player.dead:
			player.die())
	cam_follow.global_position = (start + respawn_point) * 0.5
	if camera.get_parent() != cam_follow:
		camera.reparent(cam_follow, false)
		camera.position = Vector2.ZERO


func _freeze_ghost(g: CharacterBody2D, frozen: bool) -> void:
	g.set_physics_process(not frozen)
	g.visual.visible = not frozen
	g.light.visible = not frozen
	g.trail.emitting = not frozen
	if frozen:
		g.velocity = Vector2.ZERO


func _mirror_update() -> void:
	# La caméra vise le milieu des fantômes encore en route
	var pts := []
	for g in [player, reflection]:
		if not arrived.has(g):
			pts.append(g.global_position)
	if pts.size() == 2:
		cam_follow.global_position = (pts[0] + pts[1]) * 0.5
	elif pts.size() == 1:
		cam_follow.global_position = pts[0]
	if player.dead or reflection.dead:
		return
	if reflection.global_position.y > room_size.y + 24:
		_mirror_lost(reflection)
		return
	# Les deux fantômes doivent rester à l'écran : si l'un en sort, les deux meurent
	if since_respawn < 0.6:
		return
	var view := Rect2(camera.get_screen_center_position() - VIEW_HALF, VIEW_HALF * 2.0).grow(6.0)
	for g in [player, reflection]:
		if not arrived.has(g) and not view.has_point(g.global_position):
			_mirror_lost(g)
			return


# Un fantôme tombé ou sorti de l'écran : les deux meurent, ou, invincibles, repartent ensemble
func _mirror_lost(g: CharacterBody2D) -> void:
	if not Settings.invincible:
		g.die()
		return
	arrived.clear()
	_freeze_ghost(player, false)
	_freeze_ghost(reflection, false)
	player.respawn(respawn_point)
	reflection.respawn(reflection_respawn)
	cam_follow.global_position = (respawn_point + reflection_respawn) * 0.5
	camera.reset_smoothing()
	since_respawn = 0.0


# Une bougie touchée par l'un ou l'autre fantôme sert aux deux : chacun repartira de la bougie
# de son côté (les bougies des niveaux du miroir vont par paires, symétriques par rapport à la vitre)
func _mirror_checkpoint(cp) -> void:
	var here: Vector2 = cp.global_position + Vector2(0, -7)
	var there := Vector2(room_size.x - here.x, here.y)
	var left_side := here.x < room_size.x * 0.5
	respawn_point = here if left_side else there
	reflection_respawn = there if left_side else here
	for other in checkpoints:
		if other == cp or other.global_position.distance_to(Vector2(room_size.x - cp.global_position.x, cp.global_position.y)) < 12.0:
			if not other.lit:
				sfx.play("candle", 0.0)
			other.light_up()


# Chapitre Poursuite : l'ombre qui refait le chemin du fantôme, la marée qui monte
func _add_pursuers(has_chaser: bool, dark_top: float, companion: bool) -> void:
	if dark_top >= 0.0:
		dark = RisingDark.new()
		dark.player = player
		dark.width = room_size.x
		dark.start_top = dark_top
		level_root.add_child(dark)
	if has_chaser:
		chaser = ShadowChaser.new()
		chaser.player = player
		chaser.companion = companion
		level_root.add_child(chaser)


func _cell(grid: Array, c: Vector2i) -> String:
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= grid[c.y].size():
		return "#"
	return grid[c.y][c.x]


# Regroupe des tuiles en rectangles (rangées, puis étendues vers le bas)
func _merge_cells(cells: Array) -> Array:
	var todo := {}
	for c in cells:
		todo[c] = true
	var rects := []
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in cells:
		if not todo.has(c):
			continue
		var rw := 1
		while todo.has(c + Vector2i(rw, 0)):
			rw += 1
		var rh := 1
		var grow := true
		while grow:
			for i in rw:
				if not todo.has(c + Vector2i(i, rh)):
					grow = false
					break
			if grow:
				rh += 1
		for j in rh:
			for i in rw:
				todo.erase(c + Vector2i(i, j))
		rects.append(Rect2(Vector2(c) * TILE, Vector2(rw, rh) * TILE))
	return rects


func _add_spike(base: Vector2, kind: String) -> void:
	var r: Rect2
	match kind:
		"^": r = Rect2(base + Vector2(3, 9), Vector2(10, 7))
		"v": r = Rect2(base + Vector2(3, 0), Vector2(10, 7))
		"<": r = Rect2(base + Vector2(9, 3), Vector2(7, 10))
		_: r = Rect2(base + Vector2(0, 3), Vector2(7, 10))
	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	cs.shape = rect
	cs.position = r.get_center()
	area.add_child(cs)
	area.body_entered.connect(func(b):
		if b == player or (reflection and b == reflection):
			b.die())
	level_root.add_child(area)


func _add_dust(colors: float) -> void:
	var dust := CPUParticles2D.new()
	dust.amount = 60
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.position = room_size * 0.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = room_size * 0.5
	dust.direction = Vector2(1, -0.3)
	dust.spread = 60
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3
	dust.initial_velocity_max = 10
	dust.color = Color(Color.WHITE.lerp(Palette.GOLD, colors), 0.35)
	level_root.add_child(dust)


func _on_checkpoint(cp, body) -> void:
	if reflection:
		if (body == player or body == reflection) and not body.dead:
			_mirror_checkpoint(cp)
		return
	if body != player:
		return
	if not cp.lit:
		sfx.play("candle", 0.0)
	cp.light_up()
	respawn_point = cp.global_position + Vector2(0, -7)


func _on_crystal(cr, body) -> void:
	if not (body == player or (reflection and body == reflection)) or not cr.active:
		return
	if body.dashes < PlayerScript.MAX_DASHES:
		body.dashes = PlayerScript.MAX_DASHES
		cr.consume()
		sfx.play("crystal")
		add_shake(1.5)
		_burst(cr.global_position, 10, 0.4)


func _on_spark(sp) -> void:
	sp.take()
	sparks_taken.append(sp.cell)
	sfx.play("crystal", 0.0)
	_burst(sp.global_position, 8, 0.4)


func _on_exit(portal, body) -> void:
	if body == player and portal.secret and not busy:
		secret_taken = true
	if reflection and not busy and (body == player or body == reflection) and not body.dead:
		# Chacun attend l'autre dans sa sortie ; le niveau finit quand les deux y sont
		if not arrived.has(body):
			arrived[body] = true
			_freeze_ghost(body, true)
			sfx.play("candle", 0.0)
			_burst(body.global_position, 12, 0.5)
		if arrived.size() < 2:
			return
		body = player
	if body != player or busy:
		return
	busy = true
	sfx.play("exit", 0.0)
	player.set_physics_process(false)
	# Avec l'assistance, on garde les étincelles mais pas les records
	var record := false
	var previous_best: float = save.best_level_time(level_index)
	var looks_before := Looks.unlocked_ids(save, stats).size()
	if not Settings.assisted():
		record = save.record_level(level_index, level_time, level_deaths)
	# Première étincelle trouvée dans ce niveau : un fragment du journal se révèle
	var new_fragment := not sparks_taken.is_empty() and save.found_sparks(level_index).is_empty()
	save.add_sparks(level_index, sparks_taken)
	stats.level_finished()
	var new_look := Looks.unlocked_ids(save, stats).size() > looks_before
	# Sortie secrète : la face B du chapitre s'ouvre (elle se joue depuis l'écran des chapitres)
	var chapter: String = LevelData.LEVELS[level_index].get("chapter", "")
	var new_bside := secret_taken and LevelData.bside_of(chapter) >= 0 and save.unlock_bside(chapter)
	results.resize(LevelData.LEVELS.size())
	results[level_index] = {"name": LevelData.LEVELS[level_index]["name"], "time": level_time, "deaths": level_deaths, "record": record, "sparks": sparks_taken.size(), "sparks_total": sparks.size()}
	await fx.iris_close(player)
	var card := "%s\n\n%s   ·   %s" % [_level_label(level_index) if LevelData.is_bside(level_index) else LevelData.LEVELS[level_index]["name"], _format_time(level_time), EndScreen.morts(level_deaths)]
	if sparks.size() > 0:
		card += "\nétincelles %d/%d" % [sparks_taken.size(), sparks.size()]
	# Écart avec le record précédent (négatif : plus rapide)
	if previous_best >= 0.0 and not Settings.assisted():
		var gap := level_time - previous_best
		card += "\n%s%s s par rapport au record" % ["−" if gap < 0.0 else "+", ("%.2f" % absf(gap)).replace(".", ",")]
	if record:
		card += "\n\nrecord !"
	if new_look:
		card += "\n\nNouvelle apparence débloquée (Options)"
	if new_bside:
		card += "\n\nUne face cachée s'ouvre : Face B · %s\n(écran des chapitres)" % LevelData.LEVELS[LevelData.bside_of(chapter)]["name"]
	fx.show_card(card)
	await get_tree().create_timer(2.4 if new_bside else 1.2, false).timeout
	fx.hide_card()
	if LevelData.is_bside(level_index):
		# Face B finie : retour à l'écran titre, sur ce chapitre
		_back_to_title()
		fx.iris_open(player)
		return
	if new_fragment:
		await chapter_intro.play_fragment(Lore.fragment(level_index))
	if LevelData.is_epilogue(level_index):
		# Épilogue : une page du journal s'écrit à chaque niveau, puis la dernière carte
		if not save.page_read(level_index):
			save.mark_page(level_index)
			await chapter_intro.play_page(Lore.fragment(level_index))
		if level_index + 1 >= LevelData.bside_start():
			_finish_epilogue()
			return
	# La partie complète s'arrête avant l'épilogue
	var next := level_index + 1
	if next < LevelData.bside_start() and next != LevelData.story_end():
		await chapter_intro.play_if_new(level_index + 1)
		_load_level(level_index + 1)
		player.set_physics_process(true)
		fx.iris_open(player)
		busy = false
	else:
		_show_end()


func _show_end() -> void:
	finished = true
	save.set_last_level(0)
	stats.game_finished()
	var not_ranked := ""
	if not run_valid:
		not_ranked = "partie commencée en cours de route"
	elif run_assisted:
		not_ranked = "partie assistée"
	var run_record := false
	if not_ranked == "":
		run_record = save.record_run(elapsed, deaths)
	end_screen.credits.true_ending = save.total_sparks_found() >= Looks.total_sparks()
	if end_screen.credits.true_ending:
		save.unlock_epilogue()
	end_screen.show_results(results, elapsed, deaths, run_record, save.best_run_time(), not_ranked)


func _on_player_died() -> void:
	if reflection and not reflection.dead:
		reflection.die()
		_burst(reflection.global_position, 20, 0.6)
	deaths += 1
	level_deaths += 1
	sfx.play("death")
	# Arrêt sur image d'abord, puis tout part d'un coup : éclats, secousse et disque rayé
	await fx.on_died(player)
	music.scratch()
	add_shake(4.0)
	_burst(player.global_position, 28, 0.7)
	await get_tree().create_timer(0.45, false).timeout
	for cr in crystals:
		cr.reset()
	for cb in crumbles:
		cb.reset()
	if chimes:
		chimes.reset()
	if chaser:
		chaser.reset()
	if reflection:
		arrived.clear()
		_freeze_ghost(player, false)
		_freeze_ghost(reflection, false)
		reflection.respawn(reflection_respawn)
		since_respawn = 0.0
	if dark:
		dark.reset(respawn_point)
	if watchers:
		watchers.reset()
	if orb_blocks:
		orb_blocks.reset()
	player.respawn(respawn_point)
	hint_orb.snap()
	if reflection:
		cam_follow.global_position = (respawn_point + reflection_respawn) * 0.5
		camera.reset_smoothing()
	music.resume()
	fx.on_respawned(respawn_point)


# Place du niveau dans son chapitre : 0 pour le premier, 1 pour le dernier
func _chapter_progress(index: int) -> float:
	var chapter: String = LevelData.LEVELS[index].get("chapter", "")
	var first := index
	var last := index
	while first > 0 and LevelData.LEVELS[first - 1].get("chapter", "") == chapter and LevelData.is_bside(first - 1) == LevelData.is_bside(index):
		first -= 1
	while last + 1 < LevelData.LEVELS.size() and LevelData.LEVELS[last + 1].get("chapter", "") == chapter and LevelData.is_bside(last + 1) == LevelData.is_bside(index):
		last += 1
	return float(index - first) / maxf(1.0, last - first)


func _burst(pos: Vector2, amount: int, life: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.spread = 180
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40
	p.initial_velocity_max = 140
	p.damping_min = 120
	p.damping_max = 200
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = PlayerScript.fade_gradient(Color.WHITE)
	p.global_position = pos
	level_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


func add_shake(amount: float) -> void:
	if Settings.shake:
		shake = maxf(shake, amount)


func _format_time(t: float) -> String:
	return "%02d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


# Options > Réinitialiser la sauvegarde : efface records, progression, étincelles,
# journal, faces B et statistiques. Les réglages et les touches sont gardés.
func reset_save() -> void:
	save.reset()
	stats.reset()
	if not Looks.unlocked_ids(save, stats).has(Settings.look):
		Settings.look = "none"
		Settings.save()
	title_menu.index = 0
	title_menu.chapter = 0


func _show_title() -> void:
	on_title = true
	player.set_physics_process(false)
	title_label.modulate.a = 0.0
	# Le fond illustré suffit : pas de voile noir sous le menu
	center_bg.bg_color.a = 0.0
	_set_level_running(false)
	center_label.visible = true
	title_menu.open()


# Sur l'écran titre, le niveau caché derrière le fond est figé : ni le fantôme
# (les touches maintenues ne le font plus bouger ni mourir) ni les pièges ne tournent.
func _set_level_running(on: bool) -> void:
	var mode := Node.PROCESS_MODE_PAUSABLE if on else Node.PROCESS_MODE_DISABLED
	world.process_mode = mode
	player.process_mode = mode
	hint_orb.process_mode = mode


func _on_title_start(level: int, from_start: bool) -> void:
	on_title = false
	center_label.visible = false
	center_bg.bg_color.a = 0.7
	_set_level_running(true)
	deaths = 0
	elapsed = 0.0
	results.clear()
	# Seule une partie commencée au niveau 1 peut battre le record global
	run_valid = from_start
	run_assisted = false
	player.set_physics_process(true)
	_load_level(level)
	# Ouverture de chapitre (ou de face B) : le fantôme et le chrono attendent la fin de la carte
	if ChapterIntro.starts_chapter(level) or LevelData.is_bside(level):
		busy = true
		player.set_physics_process(false)
		await chapter_intro.play(level)
		player.set_physics_process(true)
		busy = false


func _start_epilogue() -> void:
	finished = false
	busy = false
	deaths = 0
	elapsed = 0.0
	results.clear()
	run_assisted = false
	fx.iris_open(player)
	_on_title_start(LevelData.story_end(), false)


# Fin du dernier niveau de l'épilogue : une carte qui passe de l'aube au jour, puis le titre,
# avec ce dernier niveau en couleurs derrière
func _finish_epilogue() -> void:
	await chapter_intro.play_ending(Lore.EPILOGUE_END)
	save.set_last_level(0)
	_back_to_title()
	fx.iris_open(player)


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	menu_label.visible = paused
	menu_index = 0
	menu_level = level_index
	_draw_menu()


func _draw_menu() -> void:
	var lvl: Dictionary = LevelData.LEVELS[menu_level]
	var items := [
		"Reprendre",
		"Retour à la bougie",
		"Recommencer le niveau",
		"<  %s  >" % ("Niveau " + _level_label(menu_level) if not LevelData.is_bside(menu_level) else _level_label(menu_level)),
		"Options",
		"Écran titre",
		"Quitter le jeu",
	]
	menu_label.visible = paused
	var text := "PAUSE\n\n"
	for i in items.size():
		text += ("›  %s  ‹" if i == menu_index else "%s") % items[i] + "\n"
	text += "\n" + _level_info(menu_level) + "\n"
	text += "\n↑ ↓ choisir   ← → niveau   Saut valider"
	menu_label.text = text


# Record et étincelles d'un niveau, pour le choix du niveau
func _level_info(index: int) -> String:
	var best := save.best_level_time(index)
	var info := "record %s" % (_format_time(best) if best >= 0.0 else "—")
	var total := LevelData.count(index, "*")
	if total > 0:
		info += "   ·   étincelles %d/%d" % [save.found_sparks(index).size(), total]
	return info


# Depuis la pause : on abandonne la partie en cours, « Continuer » reprendra à ce niveau
func _back_to_title() -> void:
	busy = false
	finished = false
	deaths = 0
	elapsed = 0.0
	results.clear()
	run_valid = true
	run_assisted = false
	_show_title()
	_load_level(level_index)


# Touche « Retour à la bougie » ou menu pause : compte comme une mort, et ramène
# aussi le reflet en Miroir. Invincible, le fantôme est seulement replacé.
func _return_to_checkpoint() -> void:
	if player.dead or busy or finished:
		return
	if reflection:
		_mirror_lost(player)
	elif Settings.invincible:
		player.respawn(respawn_point)
	else:
		player.die()


func _menu_input() -> void:
	if options.visible:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return
	if Input.is_action_just_pressed("up"):
		menu_index = posmod(menu_index - 1, 7)
	elif Input.is_action_just_pressed("down"):
		menu_index = posmod(menu_index + 1, 7)
	elif menu_index == 3 and Input.is_action_just_pressed("left"):
		menu_level = posmod(menu_level - 1, save.playable_levels())
	elif menu_index == 3 and Input.is_action_just_pressed("right"):
		menu_level = posmod(menu_level + 1, save.playable_levels())
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
		match menu_index:
			0:
				_toggle_pause()
			1:
				_toggle_pause()
				_return_to_checkpoint()
			2:
				_toggle_pause()
				_load_level(level_index)
			3:
				# _toggle_pause remet menu_level sur le niveau actuel : on garde le choix avant
				var chosen := menu_level
				_toggle_pause()
				if chosen != level_index:
					run_valid = false
				_load_level(chosen)
			4:
				menu_label.visible = false
				options.open()
			5:
				_toggle_pause()
				_back_to_title()
			6:
				get_tree().quit()
		return
	_draw_menu()


func _process(delta: float) -> void:
	version_label.visible = on_title and center_label.visible
	if paused:
		_menu_input()
		return
	if on_title:
		return
	if Input.is_action_just_pressed("pause") and not busy and not finished:
		_toggle_pause()
		return
	if finished:
		# Bilan, puis épilogue et crédits ; après la carte « Fin », retour au titre
		if Input.is_action_just_pressed("jump") and end_screen.advance():
			# Après la vraie fin, le jour se lève : l'épilogue enchaîne
			if end_screen.credits.true_ending:
				_start_epilogue()
				return
			finished = false
			busy = false
			deaths = 0
			elapsed = 0.0
			results.clear()
			run_valid = true
			run_assisted = false
			_show_title()
			_load_level(0)
			fx.iris_open(player)
		return

	# Le chrono compte en temps réel, même quand le jeu est ralenti
	if not busy:
		elapsed += delta / Engine.time_scale
		level_time += delta / Engine.time_scale
	hud_label.visible = Settings.show_timer
	hud_label.text = "Morts : %d    %s" % [deaths, _format_time(elapsed)]
	if Settings.assisted():
		run_assisted = true
		hud_label.text += "    assistance"
	if Settings.infinite_dash and not player.dead:
		player.dashes = PlayerScript.MAX_DASHES
		if reflection:
			reflection.dashes = PlayerScript.MAX_DASHES

	if Input.is_action_just_pressed("restart"):
		_return_to_checkpoint()

	if reflection:
		since_respawn += delta
		_mirror_update()
	if not player.dead and player.global_position.y > room_size.y + 24:
		if reflection:
			_mirror_lost(player)
		elif Settings.invincible:
			player.respawn(respawn_point)
		else:
			player.die()

	# Décroissance rapide mais visible : un coup sec plutôt qu'un frisson
	shake = shake * exp(-12.0 * delta)
	if shake < 0.25:
		shake = 0.0
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	if Settings.shake:
		camera.offset += fx.kick
