# Racine du jeu : construit les niveaux depuis level_data.gd, gère la caméra,
# les morts, les checkpoints, les transitions et le HUD.
extends Node2D

const TILE := 16
const VIEW_HALF := Vector2(240, 135)  # demi-écran, en px du monde
const LevelData = preload("res://scripts/level_data.gd")
const PlayerScript = preload("res://scripts/physique/Player.cs")
const Glow = preload("res://scripts/glow.gd")
const TilesDrawer = preload("res://scripts/tiles_drawer.gd")
const Crystal = preload("res://scripts/crystal.gd")
const Checkpoint = preload("res://scripts/checkpoint.gd")
const ExitPortal = preload("res://scripts/exit_portal.gd")
const PhaseBlocks = preload("res://scripts/physique/PhaseBlocks.cs")
const CrumbleBlock = preload("res://scripts/physique/CrumbleBlock.cs")
const Door = preload("res://scripts/physique/Door.cs")
const KeyItem = preload("res://scripts/key.gd")
const Updraft = preload("res://scripts/updraft.gd")
const ZeroGravity = preload("res://scripts/zero_gravity.gd")
const Spring = preload("res://scripts/spring.gd")
const Mover = preload("res://scripts/physique/Mover.cs")
const Rail = preload("res://scripts/rail.gd")
const Bell = preload("res://scripts/bell.gd")
const ToggleBlocks = preload("res://scripts/physique/ToggleBlocks.cs")
const TimedBlocks = preload("res://scripts/physique/TimedBlocks.cs")
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
const OrbBlocks = preload("res://scripts/physique/OrbBlocks.cs")
const FakeWall = preload("res://scripts/fake_wall.gd")
const Palette = preload("res://scripts/palette.gd")
const Slopes = preload("res://scripts/slopes.gd")
const UpdateCheck = preload("res://scripts/update_check.gd")

const AMBIENT := Color(0.09, 0.09, 0.09)
const RIM := 4.0  # liseré non occultant : les bords des murs captent la lumière
# Cases pleines : mur, vitre, et murs taillés (r roche, t pierre taillée, g givre)
const SOLID_CHARS := ["#", "=", "r", "t", "g"]

var level_index := 0
# Mode Ascension : les niveaux de levels/ascension/, la physique du saut chargé (Player.cs), pas de
# mort en tombant (les niveaux ont un fond) ; level_index compte alors dans LevelData.ASCENT
var ascent := false
# Niveau lancé depuis l'éditeur (F6 sur sa scène, voir levels/level.gd) : pas de records
var testing := false
# Rechargement à chaud (jeu lancé depuis l'éditeur) : la scène du niveau en cours et sa date
# de modification ; sauvegarder la scène dans l'éditeur reconstruit le niveau sans s'arrêter
const HOT_RELOAD_EVERY := 0.4
var hot_path := ""
var hot_time := 0
var hot_wait := 0.0
var falls := 0  # grandes chutes du niveau en cours (mode Ascension)
const BIG_FALL := 6 * TILE
# Le fantôme qui s'endort (ghost_visual.gd) : à partir de SLEEP_ZOOM_AT s d'immobilité,
# la caméra s'approche doucement de lui, jusqu'à SLEEP_ZOOM ; elle recule vite au réveil
const SLEEP_ZOOM_AT := 35
const SLEEP_ZOOM := 4.0
const SLEEP_ZOOM_TIME := 20.0
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
var keys: Array = []  # clés du niveau (key.gd) : elles reviennent à leur place après une mort
var checkpoints: Array = []
var chimes: Node2D  # blocs de carillon du niveau, s'il y en a
var chasers: Array = []  # ombres poursuivantes, s'il y en a
var dark: Node2D    # marée de ténèbres, s'il y en a une
var watchers: Node2D  # yeux qui regardent, s'il y en a
var orb_blocks: Node2D  # pierres cachées que montre l'orbe, s'il y en a
# Chapitre Miroir : le reflet, contrôlé en même temps que le fantôme, gauche et droite inversées
var reflection: CharacterBody2D
var reflection_respawn := Vector2.ZERO
var arrived := {}         # fantômes déjà entrés dans une sortie
var since_respawn := 0.0  # la caméra se recale après une réapparition
var cam_follow: Node2D    # milieu des deux fantômes, suivi par la caméra
var ascent_screen := Vector2i(-1, -1)  # Ascension : écran fixe où se trouve le fantôme
var ascent_screens := []  # Ascension : écrans posés à la main (Rect2, nœuds Ecran du niveau)
var ascent_auto_zoom := 0.8  # Ascension sans écrans posés : recul du découpage automatique
var ascent_zoom := 0.8  # zoom de l'écran actuel
# Ascension : éléments animés ou éclairés, avec la zone qu'ils occupent. Seuls ceux près de
# l'écran actuel restent visibles : les autres ne se redessinent plus et leur lumière s'éteint.
var ascent_cullables: Array = []  # [CanvasItem, Rect2]
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
	player.connect("Died", _on_player_died)
	hint_orb = HintOrb.new()
	hint_orb.process_mode = Node.PROCESS_MODE_PAUSABLE
	hint_orb.player = player
	hint_orb.main = self
	add_child(hint_orb)
	player.connect("Dashed", func():
		add_shake(2.0)
		fx.on_dashed(player)
		hint_orb.dash_ahead(player.DashDir)
		Settings.rumble(0.35, 0.0, 0.08)
		sfx.play("dash"))
	player.connect("Jumped", func():
		fx.on_jumped(player)
		sfx.play("jump", 0.1))
	player.connect("Landed", func():
		fx.on_landed(player)
		sfx.play("land", 0.15)
		# Ascension : une grande chute se sent et se compte
		if ascent and player.LastDrop > BIG_FALL:
			falls += 1
			add_shake(minf(6.0, 2.0 + player.LastDrop / 64.0))
			# La poussière gicle de chaque côté, plus fort quand la chute est haute
			_burst(player.global_position + Vector2(0, 7), int(10 + 30 * player.Splat), 0.35 + 0.35 * player.Splat)
			Settings.rumble(0.5, 0.3, 0.15)
			sfx.play("death", 0.1))
	player.connect("Bonked", func():
		add_shake(1.5)
		Settings.rumble(0.3, 0.0, 0.06)
		sfx.play("land", 0.1))

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
	if LevelScene.test_path != "":
		_start_test.call_deferred()


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
	keys.clear()
	chimes = null
	chasers.clear()
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
	var found_sparks := [] if ascent else save.found_sparks(index)
	level_time = 0.0
	level_deaths = 0
	falls = 0
	player.Ascent = ascent

	var data: Dictionary = _level_data(index)
	hot_path = _level_path(index) if OS.has_feature("editor") else ""
	hot_time = FileAccess.get_modified_time(hot_path) if hot_path != "" else 0
	ascent_screens = data.get("screens", [])
	ascent_auto_zoom = data.get("screen_zoom", 0.8)
	ascent_zoom = ascent_auto_zoom
	var colors := 0.0 if ascent else Palette.strength(index)
	# Une case peut porter plusieurs éléments (un par calque de la scène) : grid[y][x] est la chaîne
	# de leurs caractères, "" pour une case vide
	var grid := LevelData.grid_of(data)
	var h := grid.size()
	var w: int = grid[0].size() if h > 0 else 0
	room_size = Vector2(w, h) * TILE

	var is_solid := func(x: int, y: int) -> bool:
		if x < 0 or x >= w or y < 0:
			return true
		if y >= h:
			return false
		return _has_any(grid[y][x], SOLID_CHARS)

	# Pour le dessin, les fausses parois (et la sortie secrète qu'elles cachent) comptent comme
	# des murs : aucun liseré ne les trahit
	var looks_solid := func(x: int, y: int) -> bool:
		return is_solid.call(x, y) or (x >= 0 and x < w and y >= 0 and y < h and _has_any(grid[y][x], ["%", "e"]))
	# Un voisin cache le bord d'un mur s'il est plein, ou si c'est une pente pleine de ce côté
	# (side : le côté du voisin tourné vers le mur, t b l r)
	var covers := func(x: int, y: int, side: String) -> bool:
		if looks_solid.call(x, y):
			return true
		if x < 0 or x >= w or y < 0 or y >= h:
			return false
		for n in grid[y][x]:
			if Slopes.is_slope(n) and side in Slopes.COVERS[n]:
				return true
		return false

	var drawer := TilesDrawer.new()
	drawer.wall = Palette.wall(colors)
	drawer.rim = Palette.rim(colors)
	var bell_cells := []
	var reflect_start := Vector2.INF
	var glass_cells := []
	var hidden_cells := []
	var bridge_cells := {}
	var fake := FakeWall.new()
	var body := StaticBody2D.new()
	level_root.add_child(body)

	# Le givre glisse : ses cases ont leur propre corps, dans le groupe « ice », que le fantôme
	# reconnaît sous ses pieds (Player.cs)
	var ice_body := StaticBody2D.new()
	ice_body.add_to_group("ice")
	level_root.add_child(ice_body)
	var is_ice := func(x: int, y: int) -> bool:
		return x >= 0 and x < w and y >= 0 and y < h and "g" in grid[y][x]

	# Collision : rectangles fusionnés, le givre à part
	var used := {}
	for y in h:
		for x in w:
			if not is_solid.call(x, y) or used.has(Vector2i(x, y)):
				continue
			var ice: bool = is_ice.call(x, y)
			var same := func(cx: int, cy: int) -> bool:
				return is_solid.call(cx, cy) and is_ice.call(cx, cy) == ice and not used.has(Vector2i(cx, cy))
			var rw := 1
			while x + rw < w and same.call(x + rw, y):
				rw += 1
			var rh := 1
			var can_grow := true
			while can_grow and y + rh < h:
				for i in rw:
					if not same.call(x + i, y + rh):
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
			(ice_body if ice else body).add_child(cs)

	# Rendu, ombres et entités
	var occluders := Node2D.new()
	level_root.add_child(occluders)
	var occ_rects := {}  # case de bord de mur -> son ombre, fusionnées après la boucle
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
					"#", "r", "t", "g":
						var up: bool = not is_solid.call(x, y - 1)
						var down: bool = not is_solid.call(x, y + 1)
						var left: bool = not is_solid.call(x - 1, y)
						var right: bool = not is_solid.call(x + 1, y)
						var rims := [cell, not covers.call(x, y - 1, "b"), not covers.call(x, y + 1, "t"),
							not covers.call(x - 1, y, "r"), not covers.call(x + 1, y, "l")]
						if c == "#":
							drawer.solids.append(cell)
							if rims.has(true):
								drawer.edges.append(rims)
						else:  # murs taillés : coins arrondis ou biseautés (tiles_drawer.gd)
							drawer.shaped.append([cell, c] + rims.slice(1))
						if up or down or left or right:
							var r := Rect2(base, Vector2(TILE, TILE))
							r = r.grow_individual(-RIM if left else 0.0, -RIM if up else 0.0, -RIM if right else 0.0, -RIM if down else 0.0)
							occ_rects[cell] = r
					"j", "k", "u", "n", "c", "d", "f", "h", "l", "m", "o", "s":
						# Pente : collision en biais, ombre un peu en retrait comme les murs
						drawer.slopes.append([cell, c])
						var slope_body := CollisionPolygon2D.new()
						slope_body.polygon = Slopes.shape(c, base)
						body.add_child(slope_body)
						var inset := Geometry2D.offset_polygon(Slopes.shape(c, base), -3.0)
						if not inset.is_empty():
							var socc := LightOccluder2D.new()
							var spoly := OccluderPolygon2D.new()
							spoly.polygon = inset[0]
							socc.occluder = spoly
							occluders.add_child(socc)
					"^", "v", "<", ">":
						drawer.spikes.append([cell, c])
						_add_spike(base, c)
					"B":
						bell_cells.append(cell)
					"R":
						reflect_start = base + Vector2(8, 16 - 7)
					"=":
						glass_cells.append(cell)
					"i":
						hidden_cells.append(cell)
					"p":
						bridge_cells[cell] = true
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
	_add_wall_occluders(occ_rects, occluders)
	_add_bridges(bridge_cells, drawer)
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
	var tb := _add_elements(data.get("elements", []), bell_cells)
	_add_reflection(reflect_start, glass_cells)
	if has_fake and reflection:
		fake.ghosts.append(reflection)
	# Chapitre Compagnie : les pierres cachées n'apparaissent que près de l'orbe
	hint_orb.set_scout(not hidden_cells.is_empty())
	if not hidden_cells.is_empty():
		orb_blocks = OrbBlocks.new()
		orb_blocks.Cells = hidden_cells
		orb_blocks.Player = player
		orb_blocks.Orb = hint_orb
		level_root.add_child(orb_blocks)

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
	player.Light.color = Palette.light(colors)
	# Chaque chapitre a son thème ; l'énergie monte au fil du jeu et au fil du chapitre
	music.set_chapter(data.get("chapter", ""))
	var in_chapter := 0.0 if ascent else _chapter_progress(index)
	if ascent:
		music.set_intensity(0.5 + 0.5 * float(index) / maxf(1.0, LevelData.ASCENT.size() - 1.0))
	elif LevelData.is_epilogue(index):
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
	camera.zoom = Vector2.ONE * _base_zoom()
	# Ascension : l'écran peut être plus large que la salle (la caméra se centre dessus) ; avec des
	# écrans posés à la main, la caméra montre exactement ce qu'ils disent, sans bornes
	if ascent:
		camera.limit_left = -100000
		camera.limit_right = 100000
		if not ascent_screens.is_empty():
			camera.limit_top = -100000
			camera.limit_bottom = 100000
	player.Respawn(respawn_point)
	if ascent:
		_collect_cullables()
		ascent_screen = Vector2i(-1, -1)  # le nouveau niveau choisit son écran (et ses éléments visibles)
		_ascent_screen_update()
	camera.reset_smoothing()
	hint_orb.set_hints(hints)
	if not on_title and not ascent and not LevelData.is_bside(index):
		save.set_last_level(index)

	title_label.text = _level_label(index)
	if on_title:
		return
	var tw := create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(title_label, "modulate:a", 0.0, 0.8)


# Ombres des murs : une case de bord donnait un occulteur ; les cases voisines qui se touchent
# bord à bord sont réunies en un seul rectangle (d'abord en rangées, puis les rangées de même
# largeur empilées). Même ombre à l'écran, mais des dizaines de fois moins d'occulteurs que la
# lumière du fantôme doit passer en revue à chaque image.
func _add_wall_occluders(rects: Dictionary, parent: Node2D) -> void:
	var cells := rects.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var runs: Array[Rect2] = []
	for cell in cells:
		var r: Rect2 = rects[cell]
		if not runs.is_empty():
			var last := runs[runs.size() - 1]
			if is_equal_approx(last.end.x, r.position.x) and is_equal_approx(last.position.y, r.position.y) \
					and is_equal_approx(last.end.y, r.end.y):
				runs[runs.size() - 1] = last.merge(r)
				continue
		runs.append(r)
	# Empilement : un rectangle qui commence pile où finit un autre de mêmes bords gauche/droite
	var open := {}  # Vector3(gauche, droite, bas) -> indice dans merged
	var merged: Array[Rect2] = []
	for r in runs:
		var key := Vector3(r.position.x, r.end.x, r.position.y)
		if open.has(key):
			var i: int = open[key]
			open.erase(key)
			merged[i] = merged[i].merge(r)
			open[Vector3(r.position.x, r.end.x, r.end.y)] = i
		else:
			merged.append(r)
			open[Vector3(r.position.x, r.end.x, r.end.y)] = merged.size() - 1
	for r in merged:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		occ.occluder = poly
		parent.add_child(occ)


# Ponts (tuile p) : une planche par suite de cases, qui porte le fantôme par-dessus et le laisse
# passer par en dessous (collision à sens unique), sans faire d'ombre
func _add_bridges(cells: Dictionary, drawer) -> void:
	if cells.is_empty():
		return
	var body := StaticBody2D.new()
	level_root.add_child(body)
	for cell in cells:
		if cells.has(cell - Vector2i(1, 0)):
			continue
		var length := 1
		while cells.has(cell + Vector2i(length, 0)):
			length += 1
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(length * TILE, 4)
		cs.shape = rect
		cs.one_way_collision = true
		cs.position = Vector2(cell) * TILE + Vector2(length * TILE * 0.5, 2)
		body.add_child(cs)
		drawer.bridges.append([cell, length])


# « 12 · Clocher », ou « Face B · … » pour une face B
func _level_label(index: int) -> String:
	if ascent:
		return "Ascension %d · %s" % [index + 1, LevelData.ASCENT[index]["name"]]
	if LevelData.is_bside(index):
		return "Face B · %s" % LevelData.LEVELS[index]["name"]
	return "%d · %s" % [index + 1, LevelData.LEVELS[index]["name"]]


# Le niveau n° index de la liste en cours : l'histoire, ou l'Ascension
func _level_data(index: int) -> Dictionary:
	return LevelData.ASCENT[index] if ascent else LevelData.LEVELS[index]


# Les éléments réglables posés dans la scène du niveau (levels/elements/) : chacun arrive en
# dictionnaire, avec "type", sa case "cell" depuis le coin de la salle et ses réglages. Les blocs
# d'une même sorte partagent un seul nœud (une horloge, un état de cloches). Rend les blocs
# rythmés (l'horloge que la musique suit), ou null.
func _add_elements(elements: Array, bell_cells: Array) -> Node2D:
	var phase_runs := {"L": [], "O": []}
	var chime_runs := {"a": [], "b": []}
	var timed_runs := [[], []]
	var eyes := []
	var rails := []
	var doors := []
	var key_cells := []
	for e in elements:
		var base := Vector2(e["cell"]) * TILE
		var rect := Rect2(base, Vector2(Vector2i(e.get("size", Vector2i.ONE)).max(Vector2i.ONE)) * TILE)
		match e["type"]:
			"vent":
				var ud := Updraft.new()
				ud.rect = rect
				ud.dir = e["dir"]
				ud.force = e["force"]
				ud.player = player
				level_root.add_child(ud)
			"zero_g":
				var zg := ZeroGravity.new()
				zg.rect = rect
				zg.drag = e["drag"]
				zg.refill = e["refill"]
				zg.player = player
				level_root.add_child(zg)
			"phase":
				phase_runs[e["kind"]].append(rect)
			"crumble":
				var cb: StaticBody2D = CrumbleBlock.new()
				cb.Rect = rect
				cb.ShakeTime = e["shake"]
				cb.GoneTime = e["gone"]
				cb.Player = player
				cb.connect("Crumbled", func(_b): sfx.play("land", 0.3))
				level_root.add_child(cb)
				crumbles.append(cb)
			"exit":
				var ex := ExitPortal.new()
				if e["flat"]:
					ex.flat = true
					ex.length = e["width"] * TILE - 2.0
					ex.position = base + Vector2(e["width"] * TILE - 1.0, 8)
				else:
					ex.position = base + Vector2(8, 16)
				ex.entered.connect(_on_exit)
				level_root.add_child(ex)
			"door":
				var door: StaticBody2D = Door.new()
				door.Rect = rect
				door.Link = e["link"]
				level_root.add_child(door)
				doors.append(door)
			"key":
				key_cells.append([base + Vector2(8, 8), e["link"]])
			"spring":
				var spring := Spring.new()
				spring.position = base + Vector2(8, 16)
				spring.launch_speed = e["force"]
				spring.player = player
				spring.launched.connect(func(_s):
					Settings.rumble(0.5, 0.2, 0.12)
					sfx.play("jump", 0.0)
					add_shake(1.5))
				level_root.add_child(spring)
			"mover":
				var mv: AnimatableBody2D = Mover.new()
				mv.Size = rect.size
				mv.Start = base
				mv.Course = Vector2(e["course"]) * TILE
				mv.Speed = e["speed"]
				mv.SpeedBack = e.get("speed_back", e["speed"])
				mv.EaseOut = e.get("ease", 0)
				mv.EaseBack = e.get("ease_back", 0)
				mv.Pause = e["pause"]
				mv.StartAt = e["start"]
				mv.Trigger = e.get("trigger", 0)
				mv.Propel = e.get("propel", 150.0)
				mv.Player = player
				level_root.add_child(mv)
				rails.append_array(_rail_points(rect, e["course"]))
			"chime":
				chime_runs[e["kind"]].append(rect)
			"timed":
				timed_runs[e["phase"]].append(rect)
			"eye":
				eyes.append([base + Vector2(8, 8), e["offset"], e["range"]])
			"tide":
				if dark == null:
					dark = RisingDark.new()
					dark.player = player
					dark.width = room_size.x
					dark.start_top = base.y
					dark.speed = e["speed"]
					dark.reach = e["reach"]
					dark.catch_up = e["catch_up"]
					dark.below_respawn = e["below"]
					level_root.add_child(dark)
			"chaser":
				for i in int(e["count"]):
					var ch := ShadowChaser.new()
					ch.player = player
					ch.companion = e["companion"]
					ch.delay = roundi((e["delay"] + i * e["gap"]) * Engine.physics_ticks_per_second)
					ch.speed = e["speed"]
					level_root.add_child(ch)
					chasers.append(ch)
	# Les clés après les portes : chacune connaît toutes les portes du niveau
	for k in key_cells:
		var key := KeyItem.new()
		key.home = k[0]
		key.link = k[1]
		key.player = player
		key.doors = doors
		key.picked.connect(func(_k): sfx.play("crystal", 0.0))
		key.used.connect(func(_k):
			sfx.play("candle", 0.0)
			add_shake(1.5)
			Settings.rumble(0.3, 0.3, 0.15))
		level_root.add_child(key)
		keys.append(key)
	if not rails.is_empty():
		var rail := Rail.new()
		rail.points = rails
		level_root.add_child(rail)
		level_root.move_child(rail, 1)
	for k in phase_runs:
		if phase_runs[k].is_empty():
			continue
		var pb: Node2D = PhaseBlocks.new()
		pb.Kind = k
		pb.Runs = phase_runs[k]
		pb.Player = player
		level_root.add_child(pb)
	_add_chimes(chime_runs["a"], chime_runs["b"], bell_cells)
	var tb: Node2D = null
	if not (timed_runs[0].is_empty() and timed_runs[1].is_empty()):
		tb = TimedBlocks.new()
		tb.Runs1 = timed_runs[0]
		tb.Runs2 = timed_runs[1]
		tb.Player = player
		level_root.add_child(tb)
	if not eyes.is_empty():
		watchers = Watchers.new()
		watchers.eyes = eyes
		watchers.player = player
		level_root.add_child(watchers)
	return tb


# Le rail d'une plateforme mobile : un point au centre de chaque case qu'elle balaie, de A à B
func _rail_points(rect: Rect2, course: Vector2i) -> Array:
	var pts := []
	var steps := maxi(absi(course.x), absi(course.y))
	if steps == 0:
		return pts
	var cells := Vector2i(rect.size / TILE)
	for k in steps + 1:
		var shift := Vector2(course) * TILE * (float(k) / steps)
		for j in cells.y:
			for i in cells.x:
				var p := rect.position + shift + Vector2(i, j) * TILE + Vector2(8, 8)
				if not pts.has(p):
					pts.append(p)
	return pts


# Les indices écrivent {jump}, {dash}, {left}, {right} : on y met les touches choisies par le joueur
func _hint_text(t: String) -> String:
	for a in ["jump", "dash", "left", "right"]:
		var names := []
		for k in Controls.keys[a].slice(0, 2):
			names.append(Controls.KEY_NAMES[k] if Controls.KEY_NAMES.has(k) else OS.get_keycode_string(k))
		t = t.replace("{%s}" % a, " / ".join(names) if names else "?")
	return t


# Cloches (tuiles B) et blocs de carillon (solides au repos, ou une fois sonnés)
func _add_chimes(runs_a: Array, runs_b: Array, bell_cells: Array) -> void:
	if runs_a.is_empty() and runs_b.is_empty() and bell_cells.is_empty():
		return
	chimes = ToggleBlocks.new()
	chimes.RunsA = runs_a
	chimes.RunsB = runs_b
	chimes.Player = player
	level_root.add_child(chimes)
	var bells := []
	for c in bell_cells:
		var bell := Bell.new()
		bell.position = Vector2(c) * TILE + Vector2(8, 8)
		bell.player = player
		level_root.add_child(bell)
		bells.append(bell)
	for bell in bells:
		bell.rung.connect(func(_b):
			chimes.Ring()
			for other in bells:
				other.shake()
			sfx.play("candle", 0.0)
			add_shake(1.0))
	# Chaque bougie mémorise l'état des cloches
	for cp in checkpoints:
		cp.reached.connect(func(_cp, b): if b == player: chimes.Save())


# Chapitre Miroir : le reflet part de "R" ; la caméra suit le milieu des deux fantômes
func _add_reflection(start: Vector2, glass_cells: Array) -> void:
	if not glass_cells.is_empty():
		var glass := MirrorGlass.new()
		glass.cells = glass_cells
		level_root.add_child(glass)
	if cam_follow == null:
		cam_follow = Node2D.new()
		world.add_child(cam_follow)
	# Ascension : écrans fixes, la caméra saute d'un coup à l'écran suivant (pas de lissage)
	camera.position_smoothing_enabled = not ascent
	if start == Vector2.INF:
		var anchor: Node2D = cam_follow if ascent else player
		if camera.get_parent() != anchor:
			camera.reparent(anchor, false)
			camera.position = Vector2.ZERO
		ascent_screen = Vector2i(-1, -1)
		return
	reflection = PlayerScript.new()
	reflection.Mirror = true
	# Hérite du monde : s'arrête avec lui sur l'écran titre
	reflection.process_mode = Node.PROCESS_MODE_INHERIT
	level_root.add_child(reflection)
	reflection.modulate = Color(1, 1, 1, 0.7)
	reflection.Respawn(start)
	reflection_respawn = start
	# Si l'un meurt, l'autre aussi : ils repartent ensemble
	reflection.connect("Died", func():
		if not player.Dead:
			player.Die())
	cam_follow.global_position = (start + respawn_point) * 0.5
	if camera.get_parent() != cam_follow:
		camera.reparent(cam_follow, false)
		camera.position = Vector2.ZERO


func _freeze_ghost(g: CharacterBody2D, frozen: bool) -> void:
	g.set_physics_process(not frozen)
	g.Visual.visible = not frozen
	g.Light.visible = not frozen
	g.Trail.emitting = not frozen
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
	if player.Dead or reflection.Dead:
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
		g.Die()
		return
	arrived.clear()
	_freeze_ghost(player, false)
	_freeze_ghost(reflection, false)
	player.Respawn(respawn_point)
	reflection.Respawn(reflection_respawn)
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


# Une case (chaîne de caractères, un par calque) contient-elle l'un de ces éléments ?
func _has_any(here: String, chars: Array) -> bool:
	for c in here:
		if c in chars:
			return true
	return false


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
			b.Die())
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
		if (body == player or body == reflection) and not body.Dead:
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
	if body.RefillDash():
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
	if reflection and not busy and (body == player or body == reflection) and not body.Dead:
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
	if ascent:
		_ascent_exit()
		return
	# Avec l'assistance, on garde les étincelles mais pas les records
	var record := false
	var previous_best: float = save.best_level_time(level_index)
	var looks_before := Looks.unlocked_ids(save, stats).size()
	if not Settings.assisted() and not testing:
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


# Sortie d'un niveau de l'Ascension : temps et chutes, puis le suivant, ou l'écran titre au bout
func _ascent_exit() -> void:
	var lvl_name: String = LevelData.ASCENT[level_index]["name"]
	var previous_best: float = save.best_ascent_time(lvl_name)
	var record := false
	if not Settings.assisted() and not testing:
		record = save.record_ascent(lvl_name, level_time, falls)
	stats.level_finished()
	await fx.iris_close(player)
	var card := "%s\n\n%s   ·   %s" % [_level_label(level_index), _format_time(level_time), _falls_text(falls)]
	if previous_best >= 0.0 and not Settings.assisted():
		var gap := level_time - previous_best
		card += "\n%s%s s par rapport au record" % ["−" if gap < 0.0 else "+", ("%.2f" % absf(gap)).replace(".", ",")]
	if record:
		card += "\n\nrecord !"
	fx.show_card(card)
	await get_tree().create_timer(1.6, false).timeout
	fx.hide_card()
	if level_index + 1 < LevelData.ASCENT.size():
		_load_level(level_index + 1)
		player.set_physics_process(true)
		fx.iris_open(player)
		busy = false
	else:
		_back_to_title()
		fx.iris_open(player)


static func _falls_text(n: int) -> String:
	if n == 0:
		return "aucune chute"
	return "%d chute%s" % [n, "s" if n > 1 else ""]


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
	if reflection and not reflection.Dead:
		reflection.Die()
		_burst(reflection.global_position, 20, 0.6)
	deaths += 1
	level_deaths += 1
	sfx.play("death")
	Settings.rumble(0.6, 0.8, 0.3)
	# Arrêt sur image d'abord, puis tout part d'un coup : éclats, secousse et disque rayé
	await fx.on_died(player)
	music.scratch()
	add_shake(4.0)
	_burst(player.global_position, 28, 0.7)
	await get_tree().create_timer(0.45, false).timeout
	for cr in crystals:
		cr.reset()
	for cb in crumbles:
		cb.Reset()
	for k in keys:
		k.reset()
	if chimes:
		chimes.Reset()
	for ch in chasers:
		ch.reset()
	if reflection:
		arrived.clear()
		_freeze_ghost(player, false)
		_freeze_ghost(reflection, false)
		reflection.Respawn(reflection_respawn)
		since_respawn = 0.0
	if dark:
		dark.reset(respawn_point)
	if watchers:
		watchers.reset()
	if orb_blocks:
		orb_blocks.Reset()
	player.Respawn(respawn_point)
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
	p.color_ramp = Glow.fade_gradient(Color.WHITE)
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
	if not ascent and (ChapterIntro.starts_chapter(level) or LevelData.is_bside(level)):
		busy = true
		player.set_physics_process(false)
		await chapter_intro.play(level)
		player.set_physics_process(true)
		busy = false


# Chemin de la scène d'un niveau (res://levels/…tscn), dans sa liste
func _level_path(index: int) -> String:
	var list: Resource = LevelData.ASCENT_LIST if ascent else LevelData.LIST
	return list.levels[index].resource_path if index < list.levels.size() else ""


# Jeu lancé depuis l'éditeur : quand la scène du niveau en cours est sauvegardée (Ctrl+S), on la
# relit et on reconstruit le niveau, en gardant le fantôme où il est, avec son élan, et le chrono
func _hot_reload_check(delta: float) -> void:
	if hot_path == "" or busy or finished or paused or on_title:
		return
	hot_wait -= delta
	if hot_wait > 0.0:
		return
	hot_wait = HOT_RELOAD_EVERY
	var t := FileAccess.get_modified_time(hot_path)
	if t == hot_time:
		return
	hot_time = t
	var scene := ResourceLoader.load(hot_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if scene == null:
		return
	var level = scene.instantiate()
	var data: Dictionary = level.to_data()
	level.free()
	var levels: Array = LevelData.ASCENT if ascent else LevelData.LEVELS
	levels[level_index] = data
	var pos: Vector2 = player.global_position
	var vel: Vector2 = player.velocity
	var was_dead: bool = player.Dead
	var keep_respawn := respawn_point
	var keep := [level_time, elapsed, falls, deaths, level_deaths]
	_load_level(level_index)
	level_time = keep[0]
	elapsed = keep[1]
	falls = keep[2]
	deaths = keep[3]
	level_deaths = keep[4]
	respawn_point = keep_respawn
	if not was_dead:
		player.Respawn(pos)
		player.velocity = vel
	if ascent:
		_ascent_screen_update()
	camera.reset_smoothing()
	print("Niveau rechargé : ", hot_path)


# Scène de niveau lancée seule depuis l'éditeur (F6) : on saute l'écran titre et on joue ce
# niveau tout de suite, depuis le nœud « DepartTest » s'il y en a un
func _start_test() -> void:
	var path := LevelScene.test_path
	var start := LevelScene.test_start
	LevelScene.test_path = ""
	LevelScene.test_start = Vector2.INF
	var index := -1
	var in_ascent := false
	for list in [LevelData.LIST, LevelData.ASCENT_LIST]:
		for i in list.levels.size():
			if list.levels[i].resource_path == path:
				index = i
				in_ascent = list == LevelData.ASCENT_LIST
	if index < 0:
		push_warning("%s n'est dans aucune liste de niveaux (levels/list.tres ou levels/ascension/list.tres)" % path)
		return
	testing = true
	title_menu.active = false
	ascent = in_ascent
	_on_title_start(index, false)
	if start != Vector2.INF:
		respawn_point = start
		player.Respawn(respawn_point)
		if ascent:
			_ascent_screen_update()
		camera.reset_smoothing()


# Écran titre > Ascension : le mode rageant, depuis son premier niveau
func start_ascent() -> void:
	ascent = true
	_on_title_start(0, false)


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
	var items := [
		"Reprendre",
		"Retour à la bougie",
		"Recommencer le niveau",
		"<  %s  >" % ("Niveau " + _level_label(menu_level) if not ascent and not LevelData.is_bside(menu_level) else _level_label(menu_level)),
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
	if ascent:
		var lvl_name: String = LevelData.ASCENT[index]["name"]
		var best_time := save.best_ascent_time(lvl_name)
		var info := "record %s" % (_format_time(best_time) if best_time >= 0.0 else "—")
		var best_falls := save.best_ascent_falls(lvl_name)
		if best_falls >= 0:
			info += "   ·   au mieux %s" % _falls_text(best_falls)
		return info
	var best := save.best_level_time(index)
	var info := "record %s" % (_format_time(best) if best >= 0.0 else "—")
	var total := LevelData.count(index, "*")
	if total > 0:
		info += "   ·   étincelles %d/%d" % [save.found_sparks(index).size(), total]
	return info


# Depuis la pause : on abandonne la partie en cours, « Continuer » reprendra à ce niveau
func _back_to_title() -> void:
	testing = false
	busy = false
	finished = false
	deaths = 0
	elapsed = 0.0
	results.clear()
	run_valid = true
	run_assisted = false
	_show_title()
	if ascent:
		# Derrière le titre, on retrouve le niveau de l'histoire où l'on en était
		ascent = false
		_load_level(save.last_level())
	else:
		_load_level(level_index)


# Touche « Retour à la bougie » ou menu pause : compte comme une mort, et ramène
# aussi le reflet en Miroir. Invincible, le fantôme est seulement replacé.
func _return_to_checkpoint() -> void:
	if player.Dead or busy or finished:
		return
	if reflection:
		_mirror_lost(player)
	elif Settings.invincible:
		player.Respawn(respawn_point)
	else:
		player.Die()


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
		menu_level = posmod(menu_level - 1, _menu_levels())
	elif menu_index == 3 and Input.is_action_just_pressed("right"):
		menu_level = posmod(menu_level + 1, _menu_levels())
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


# Ascension : le niveau est découpé en écrans fixes, comptés depuis le bas. Dès que le fantôme
# franchit le haut (ou le bas, en tombant) de l'écran, on passe d'un coup au suivant.
# Avec des écrans posés à la main (nœuds Ecran), c'est celui qui contient le fantôme ; on garde
# l'écran actuel tant qu'il y est encore (les écrans peuvent se chevaucher).
func _ascent_screen_update() -> void:
	var p: Vector2 = player.global_position
	var screen := ascent_screen
	var center := Vector2.ZERO
	var zoom := ascent_auto_zoom
	if ascent_screens.is_empty():
		var size := VIEW_HALF * 2.0 / ascent_auto_zoom
		screen = Vector2i(floori(p.x / size.x), floori((room_size.y - p.y) / size.y))
		center = Vector2((screen.x + 0.5) * size.x, room_size.y - (screen.y + 0.5) * size.y)
		# Salle moins large qu'un écran : on la centre
		if room_size.x <= size.x:
			screen.x = 0
			center.x = room_size.x * 0.5
	else:
		var i := screen.x if screen.y == -2 else -1
		if i < 0 or i >= ascent_screens.size() or not ascent_screens[i].has_point(p):
			# Le premier écran qui contient le fantôme, sinon le plus proche
			var best := INF
			for j in ascent_screens.size():
				var other: Rect2 = ascent_screens[j]
				var d := 0.0 if other.has_point(p) else (p.clamp(other.position, other.end) - p).length()
				if d < best:
					best = d
					i = j
		screen = Vector2i(i, -2)
		var r: Rect2 = ascent_screens[i]
		center = r.get_center()
		zoom = minf(VIEW_HALF.x * 2.0 / r.size.x, VIEW_HALF.y * 2.0 / r.size.y)
	if screen != ascent_screen:
		ascent_screen = screen
		ascent_zoom = zoom
		camera.zoom = Vector2.ONE * zoom
		camera.reset_smoothing()
		var half := VIEW_HALF / zoom
		_ascent_cull(Rect2(center - half, half * 2.0))
	# Fantôme endormi : en zoomant, la caméra glisse de l'écran vers lui
	var k := clampf((camera.zoom.x - ascent_zoom) / (SLEEP_ZOOM - ascent_zoom), 0.0, 1.0)
	cam_follow.global_position = center.lerp(p, k)


# Les éléments qu'on peut cacher hors de l'écran : ceux qui ne bougent pas d'eux-mêmes (les
# plateformes, clés, ombres qui poursuivent, ténèbres qui montent restent toujours affichés)
func _collect_cullables() -> void:
	ascent_cullables.clear()
	for child in level_root.get_children():
		var s: Script = child.get_script()
		var area := Rect2()
		if s == Checkpoint or s == Crystal or s == Spark or s == ExitPortal or s == Spring:
			area = Rect2(child.position - Vector2(24, 40), Vector2(48, 56))
			if s == ExitPortal and child.flat:
				area = Rect2(child.position - Vector2(child.length + 16, 24), Vector2(child.length + 32, 48))
		elif s == CrumbleBlock or s == Door:
			area = child.Rect
		elif s == Updraft or s == ZeroGravity:
			area = child.rect
		else:
			continue
		ascent_cullables.append([child, area])


# Montre les éléments qui touchent l'écran (avec une marge pour la lueur de leur lumière), cache
# les autres : un nœud caché ne se redessine plus à chaque image
func _ascent_cull(view: Rect2) -> void:
	var near := view.grow(160.0)
	for entry in ascent_cullables:
		var node: CanvasItem = entry[0]
		if is_instance_valid(node):
			node.visible = near.intersects(entry[1])


# La caméra s'approche du fantôme endormi (pas en Miroir : elle y suit les deux fantômes)
func _sleep_zoom(delta: float) -> void:
	var idle: float = player.Visual.get("idle")
	var base := _base_zoom()
	var target := base
	if not reflection and idle > SLEEP_ZOOM_AT:
		var k := clampf((idle - SLEEP_ZOOM_AT) / SLEEP_ZOOM_TIME, 0.0, 1.0)
		target = lerpf(base, SLEEP_ZOOM, k * k * (3.0 - 2.0 * k))
	var z := camera.zoom.x
	# On s'approche au rythme du sommeil ; au réveil, la caméra recule d'un coup
	z = target if target > z else lerpf(z, target, 1.0 - exp(-8.0 * delta))
	camera.zoom = Vector2(z, z)
	# Pendant le zoom, les textes s'effacent (chrono, nom du niveau, bulle de l'orbe) : il ne reste
	# que le fantôme qui dort
	var shown := clampf(1.0 - (z - base) / 0.3, 0.0, 1.0)
	for label in [hud_label, title_label, hint_orb.bubble]:
		label.self_modulate.a = shown


func _base_zoom() -> float:
	return ascent_zoom if ascent else 1.0


func _menu_levels() -> int:
	return LevelData.ASCENT.size() if ascent else save.playable_levels()


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
	if ascent:
		hud_label.text = "Chutes : %d    %s" % [falls, _format_time(level_time)]
	else:
		hud_label.text = "Morts : %d    %s" % [deaths, _format_time(elapsed)]
	if Settings.assisted():
		run_assisted = true
		hud_label.text += "    assistance"
	if Settings.infinite_dash and not player.Dead:
		player.RefillDash()
		if reflection:
			reflection.RefillDash()

	if Input.is_action_just_pressed("restart"):
		_return_to_checkpoint()

	if reflection:
		since_respawn += delta
		_mirror_update()
	if not player.Dead and player.global_position.y > room_size.y + 24:
		if reflection:
			_mirror_lost(player)
		elif Settings.invincible:
			player.Respawn(respawn_point)
		else:
			player.Die()

	# Décroissance rapide mais visible : un coup sec plutôt qu'un frisson
	shake = shake * exp(-12.0 * delta)
	if shake < 0.25:
		shake = 0.0
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	_sleep_zoom(delta)
	_hot_reload_check(delta)
	if ascent and camera.get_parent() == cam_follow:
		_ascent_screen_update()
	if Settings.shake:
		camera.offset += fx.kick
