# Les pentes : raides (45°, une case) et douces (une case de haut pour deux de long, en deux
# tuiles : la moitié basse puis la moitié haute). En pixels dans une case de 16 px.
# Même ordre que la rangée des pentes de levels/murs.png (tools/make_murs.py) et SLOPE_CHARS
# dans levels/level.gd.
extends RefCounted

const SHAPES := {
	# Raides : sol qui monte vers la droite, vers la gauche ; plafond à droite, à gauche
	"j": [Vector2(0, 16), Vector2(16, 0), Vector2(16, 16)],
	"k": [Vector2(0, 0), Vector2(16, 16), Vector2(0, 16)],
	"u": [Vector2(0, 0), Vector2(16, 0), Vector2(16, 16)],
	"n": [Vector2(0, 0), Vector2(16, 0), Vector2(0, 16)],
	# Douces, au sol : montée vers la droite (bas, haut), montée vers la gauche (haut, bas)
	"c": [Vector2(0, 16), Vector2(16, 8), Vector2(16, 16)],
	"d": [Vector2(0, 8), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)],
	"f": [Vector2(0, 0), Vector2(16, 8), Vector2(16, 16), Vector2(0, 16)],
	"h": [Vector2(0, 8), Vector2(16, 16), Vector2(0, 16)],
	# Douces, au plafond : les mêmes, retournées
	"l": [Vector2(0, 0), Vector2(16, 0), Vector2(16, 8)],
	"m": [Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 8)],
	"o": [Vector2(0, 0), Vector2(16, 0), Vector2(16, 8), Vector2(0, 16)],
	"s": [Vector2(0, 0), Vector2(16, 0), Vector2(0, 8)],
}

# Côtés entièrement pleins de chaque pente (t haut, b bas, l gauche, r droite) : un mur collé à
# l'un d'eux n'a pas de liseré de ce côté
const COVERS := {
	"j": "rb", "k": "lb", "u": "tr", "n": "tl",
	"c": "b", "d": "rb", "f": "lb", "h": "b",
	"l": "t", "m": "tr", "o": "tl", "s": "t",
}


static func is_slope(c: String) -> bool:
	return SHAPES.has(c)


static func shape(c: String, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in SHAPES[c]:
		out.append(origin + p)
	return out


# Les arêtes en biais (celles qui ne suivent pas le bord de la case) : là où passe le liseré
static func slants(c: String, origin: Vector2) -> Array:
	var pts: Array = SHAPES[c]
	var out := []
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		if a.x != b.x and a.y != b.y:
			out.append([origin + a, origin + b])
	return out
