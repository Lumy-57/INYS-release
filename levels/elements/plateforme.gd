# Plateforme mobile : elle fait l'aller-retour entre deux bouts, A (là où le nœud est posé) et B
# (A + « Course »), en ligne droite : à l'horizontale, à la verticale ou en diagonale. Le rail
# qui montre sa course est dessiné tout seul. L'aller (A → B) et le retour (B → A) ont chacun leur
# vitesse et leur accélération, et elle peut attendre que le fantôme monte dessus pour partir.
# Le fantôme qui la quitte garde son élan ; si elle arrive assez vite au bout de sa course, elle le
# lance en s'arrêtant (« Propulsion »).
@tool
extends LevelElement

## Taille de la plateforme, en cases
@export var size := Vector2i(3, 1)
## Le bout B, en cases depuis le bout A : (6, 0) = 6 cases à droite, (0, -4) = 4 cases plus haut
@export var course := Vector2i(6, 0)
## Secondes d'arrêt à chaque bout (0,4 = normal)
@export_range(0.0, 5.0, 0.05) var pause := 0.4
## Où elle se trouve au lancement : 0 = au bout A, 1 = au bout B. Elle part vers B (vers A si elle
## commence en B).
@export_range(0.0, 1.0, 0.01) var depart := 0.0
## Quand elle part :
## « Toujours » : elle fait l'aller-retour sans s'arrêter, comme avant ;
## « Fantôme dessus » : elle attend en A que le fantôme monte dessus, va en B, puis revient seule ;
## « Fantôme dessus aux deux bouts » : elle attend le fantôme à chaque bout (aller comme retour).
@export_enum("Toujours", "Fantôme dessus", "Fantôme dessus aux deux bouts") var declenchement := 0
## Vitesse d'arrivée à un bout (px/s) à partir de laquelle la plateforme, en s'arrêtant, lance le
## fantôme posé dessus : il garde son élan et file au-delà du bout. 0 = jamais. Avec une
## accélération constante, la vitesse d'arrivée est la vitesse réglée ; « Douce au départ » arrive
## 1,6 fois plus vite ; une arrivée douce ne lance jamais.
@export_range(0.0, 800.0, 10.0) var propulsion := 150.0

@export_group("Aller (A → B)")
## Vitesse moyenne de l'aller, en px/s (60 = normal ; une case = 16 px)
@export_range(5.0, 400.0, 5.0) var vitesse := 60.0
## Comment elle prend de la vitesse à l'aller : constante, en douceur au départ et à l'arrivée,
## seulement au départ (elle accélère jusqu'au bout), seulement à l'arrivée (elle part vite et
## freine)
@export_enum("Constante", "Douce au départ et à l'arrivée", "Douce au départ", "Douce à l'arrivée") var acceleration := 0

@export_group("Retour (B → A)")
## Le retour reprend la vitesse et l'accélération de l'aller
@export var meme_retour := true
## Vitesse moyenne du retour, en px/s (utilisée si « Meme Retour » est décoché)
@export_range(5.0, 400.0, 5.0) var vitesse_retour := 60.0
## Accélération du retour (utilisée si « Meme Retour » est décoché)
@export_enum("Constante", "Douce au départ et à l'arrivée", "Douce au départ", "Douce à l'arrivée") var acceleration_retour := 0


func element_data() -> Dictionary:
	return {
		"type": "mover", "size": size, "course": course, "pause": pause, "start": depart,
		"trigger": declenchement, "propel": propulsion,
		"speed": vitesse, "ease": acceleration,
		"speed_back": vitesse if meme_retour else vitesse_retour,
		"ease_back": acceleration if meme_retour else acceleration_retour,
	}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := _zone(size)
	var b := Vector2(course) * TILE
	# La course, le bout B en pointillé, puis la plateforme là où elle part
	draw_line(r.get_center(), r.get_center() + b, SOFT, 1.0)
	_dotted(Rect2(b, r.size), INK)
	draw_rect(r, Color(0.75, 0.75, 0.75, 0.6))
	var start := Rect2(b * depart, r.size)
	draw_rect(start, Color(0.75, 0.75, 0.75))
	draw_rect(Rect2(start.position + Vector2(2, 3), start.size - Vector2(4, 5)), Color(0.3, 0.3, 0.3))
	var wait: String = ["", " · attend", " · attend"][declenchement]
	_note(Vector2(2, -3), "A" + wait)
	var back: String = "" if meme_retour else " / %d" % int(vitesse_retour)
	_note(b + Vector2(2, -3), "B · %d%s px/s%s%s" % [int(vitesse), back, wait if declenchement == 2 else "", " · lance" if _lance(true) else ""])
	if _lance(false):
		_note(Vector2(2, -11), "lance")


# Vrai si la plateforme lance le fantôme en arrivant au bout B (aller) ou A (retour)
func _lance(aller: bool) -> bool:
	if propulsion <= 0.0:
		return false
	var v: float = vitesse if aller or meme_retour else vitesse_retour
	var e: int = acceleration if aller or meme_retour else acceleration_retour
	return v * [1.0, 0.0, PI * 0.5, 0.0][e] >= propulsion
