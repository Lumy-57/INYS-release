# Couleurs de l'épilogue « Le matin » : après la vraie fin, le noir et blanc se teinte
# doucement. Chaque niveau donne sa force dans "colors" (0 : le jeu habituel, 1 : le plus
# coloré). Les teintes restent pâles pour que les murs et le fantôme gardent leur lisibilité.
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

const DAWN := Color(1.0, 0.7, 0.62)    # rose d'aube
const SKY := Color(0.62, 0.78, 1.0)
const GOLD := Color(1.0, 0.85, 0.55)
const LEAF := Color(0.6, 0.9, 0.68)
const LILAC := Color(0.8, 0.66, 1.0)
const GLASS := [DAWN, SKY, GOLD, LEAF, LILAC]

const AMBIENT := Color(0.09, 0.09, 0.09)
const AMBIENT_DAWN := Color(0.2, 0.15, 0.17)  # le noir s'adoucit, la nuit est finie
const WALL := Color(0.32, 0.32, 0.32)
const WALL_DAWN := Color(0.38, 0.31, 0.4)
const RIM := Color(0.95, 0.95, 0.95)


static func strength(index: int) -> float:
	if index < 0 or index >= LevelData.LEVELS.size():
		return 0.0
	return LevelData.LEVELS[index].get("colors", 0.0)


static func ambient(s: float) -> Color:
	return AMBIENT.lerp(AMBIENT_DAWN, s)


static func wall(s: float) -> Color:
	return WALL.lerp(WALL_DAWN, s)


static func rim(s: float) -> Color:
	return RIM.lerp(Color(1.0, 0.88, 0.78), s)


static func light(s: float) -> Color:
	return Color.WHITE.lerp(GOLD, 0.45 * s)


# Une des couleurs de vitrail, pâlie selon la force
static func glass(i: int, s: float) -> Color:
	return Color.WHITE.lerp(GLASS[posmod(i, GLASS.size())], s)
