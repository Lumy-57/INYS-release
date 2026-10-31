# L'ordre des niveaux du jeu (levels/list.tres). Le chapitre, l'épilogue et les faces B se lisent
# dans chaque scène ; l'ordre attendu : les chapitres, puis l'épilogue, puis les faces B.
class_name LevelList
extends Resource

@export var levels: Array[PackedScene] = []
