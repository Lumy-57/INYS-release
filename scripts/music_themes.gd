# Partitions de la musique : un thème par chapitre, lu par music.gd.
# Chaque thème garde les mêmes huit couches (nappe, mélodie, pouls, arpège, basse, tambour,
# charleston, tension) pour que la progression reste la même partout : seules la tonalité,
# le tempo, les timbres et les motifs changent.
#
# Notes en MIDI (69 = la 440 Hz), positions en temps depuis le début de la boucle.
# Motifs rythmiques : une lettre par subdivision ("div" par temps), sur une mesure.
#   "." silence, "x" coup, "X" coup appuyé, "o" basse à l'octave.
# "sync" : le thème se cale sur une horloge du niveau.
#   "timed" : métronome des blocs rythmés (2,4 s, bascule toutes les 1,2 s).
#   "eyes"  : cycle des yeux de Regards (3,9 s : fermés 1,8 s, éveil 0,5 s, regard 1,6 s).
extends RefCounted

const ORDER := [
	"Le Seuil", "Lumière et ombre", "Profondeurs", "Clocher", "Carillon", "Horloge",
	"Dernière lueur", "Poursuite", "Regards", "Miroir", "Compagnie", "Le matin",
]


static func get_theme(chapter: String) -> Dictionary:
	var th: Dictionary
	match chapter:
		"Lumière et ombre": th = _lumiere()
		"Profondeurs": th = _profondeurs()
		"Clocher": th = _clocher()
		"Carillon": th = _carillon()
		"Horloge": th = _horloge()
		"Dernière lueur": th = _derniere_lueur()
		"Poursuite": th = _poursuite()
		"Regards": th = _regards()
		"Miroir": th = _miroir()
		"Compagnie": th = _compagnie()
		"Le matin": th = _matin()
		_: th = _seuil()
	var base := {
		"beat": 0.5, "bar": 4, "bars": 8, "chord_bars": 2,
		"voice": "cloche", "melody_gain": 1.0, "canon": 0.0,
		"arp_div": 4, "arp": [0, 1, 2, 3, 2, 1, 0, 2],
		"bass_div": 2, "bass": "XxXxXxXx",
		"drum_div": 2, "kick": "X...X...", "snare": "..x...x.",
		"hat_div": 2, "hats": "xXxXxXxX",
		"pulse": "heart", "sync": "", "rise": 0.06, "thresholds": {},
	}
	base.merge(th, true)
	return base


# Le thème d'origine : la mineur, 120 bpm
static func _seuil() -> Dictionary:
	return {
		"drone": [33, 40, 45],
		"chords": [[45, [69, 72, 76, 81]], [41, [65, 69, 72, 77]], [48, [67, 72, 76, 79]], [43, [67, 71, 74, 79]]],
		"melody": [[0, 69], [5, 64], [8, 67], [13, 60], [16, 69], [19, 62], [24, 64], [29, 57]],
		"tension": [69, 70, 76],
	}


# Ré dorien, cloches de verre. La mélodie répond à elle-même : une phrase claire, un écho sombre.
static func _lumiere() -> Dictionary:
	return {
		"drone": [26, 33, 38],
		"chords": [[38, [62, 65, 69, 74]], [43, [62, 67, 71, 74]], [38, [62, 65, 69, 74]], [48, [60, 64, 67, 72]]],
		"melody": [[0, 74], [1.5, 76], [3, 77], [6, 62], [8, 79], [9.5, 77], [11, 74], [14, 57],
			[16, 74], [17.5, 76], [19, 77], [22, 62], [24, 72], [25.5, 74], [27, 76], [30, 50]],
		"voice": "verre",
		"arp": [0, 2, 1, 3],
		"bass": "X.xoX.xo",
		"kick": "X..x..x.", "snare": "....x...", "hats": ".x.x.x.x",
		"tension": [62, 63, 69],
	}


# Mi phrygien, 80 bpm, demi-temps. Des gouttes qui tombent dans le noir.
static func _profondeurs() -> Dictionary:
	return {
		"beat": 0.75,
		"drone": [28, 35, 40],
		"chords": [[40, [64, 67, 71, 76]], [41, [65, 69, 72, 77]], [43, [67, 71, 74, 79]], [41, [65, 69, 72, 77]]],
		"melody": [[0, 76], [2.5, 77], [4, 83], [8, 76], [11, 74], [12, 72], [16, 76], [18.5, 77],
			[20, 79], [24, 83], [26, 84], [28, 83], [30, 76]],
		"voice": "goutte",
		"arp_div": 2, "arp": [0, 2, 1, 2],
		"bass_div": 1, "bass": "X.x.",
		"kick": "X.......", "snare": "....x...", "hats": "..x...x.",
		"tension": [64, 65, 71],
	}


# Sol mixolydien, orgue de clocher, basse qui rebondit comme les ressorts.
static func _clocher() -> Dictionary:
	return {
		"drone": [31, 38, 43],
		"chords": [[43, [67, 71, 74, 79]], [41, [65, 69, 72, 77]], [48, [64, 67, 72, 76]], [43, [67, 71, 74, 79]]],
		"melody": [[0, 74], [2, 79], [3, 77], [4, 74], [6, 72], [8, 77], [10, 76], [12, 72], [14, 74],
			[16, 74], [18, 79], [19, 81], [20, 83], [22, 81], [24, 77], [26, 76], [28, 74]],
		"voice": "orgue", "melody_gain": 0.8,
		"arp": [0, 3, 1, 3, 2, 3, 1, 3],
		"bass": "Xo.oXo.o",
		"kick": "X..xx...", "snare": "..x...x.", "hats": "xxxxxxxx",
		"tension": [67, 68, 74],
	}


# Do majeur à trois temps. Les cloches sonnent une vraie méthode de carillonneur :
# six cloches, et à chaque rangée les voisines échangent leur place (« plain hunt »).
static func _carillon() -> Dictionary:
	var bells := [84, 83, 81, 79, 77, 76]
	var row := [0, 1, 2, 3, 4, 5]
	var melody := []
	for r in 16:
		for k in 6:
			melody.append([r * 3 + k * 0.5, bells[row[k]], 1.0 if k == 0 else 0.7])
		var start := 0 if r % 2 == 0 else 1
		for k in range(start, 5, 2):
			var tmp: int = row[k]
			row[k] = row[k + 1]
			row[k + 1] = tmp
	return {
		"bar": 3, "bars": 16, "chord_bars": 4,
		"drone": [24, 31, 36],
		"chords": [[48, [72, 76, 79, 84]], [45, [69, 72, 76, 81]], [41, [65, 69, 72, 77]], [43, [67, 71, 74, 79]]],
		"melody": melody,
		"voice": "carillon", "melody_gain": 0.55,
		"arp_div": 2, "arp": [0, 1, 2, 3, 2, 1],
		"bass_div": 1, "bass": "Xxo",
		"kick": "X.....", "snare": "..x.x.", "hats": "xXxXxX",
		"tension": [72, 73, 79],
	}


# Fa dièse mineur, 100 bpm : une mesure = un cycle des blocs rythmés (2,4 s).
# Grosse caisse et « toc » de l'horloge sur chaque bascule, cliquetis pendant le clignotement.
static func _horloge() -> Dictionary:
	return {
		"beat": 0.6, "sync": "timed", "rise": 0.0,
		"drone": [30, 37, 42],
		"chords": [[42, [66, 69, 73, 78]], [38, [62, 66, 69, 74]], [40, [64, 68, 71, 76]], [37, [61, 64, 68, 73]]],
		"melody": [[0, 78], [1, 76], [2, 73], [3, 76], [4, 78], [6, 81], [8, 74], [9, 73], [10, 69], [11, 73],
			[12, 74], [14, 78], [16, 76], [17, 73], [18, 71], [19, 73], [20, 76], [22, 80],
			[24, 73], [25, 71], [26, 68], [27, 71], [28, 73], [30, 66]],
		"voice": "pincé",
		"arp": [0, 2, 1, 3, 2, 1, 3, 0],
		"bass": "X.x.X.x.",
		"kick": "X...X...", "snare": "..x...x.", "hat_div": 4, "hats": "x.x.X.x.x.x.X.x.",
		"pulse": "clock", "thresholds": {2: 0.0},
		"tension": [66, 67, 73],
	}


# Ré mineur, 100 bpm aussi : calé sur les blocs rythmés quand le niveau en a.
static func _derniere_lueur() -> Dictionary:
	return {
		"beat": 0.6, "sync": "timed", "rise": 0.0,
		"drone": [26, 33, 38],
		"chords": [[38, [62, 65, 69, 74]], [34, [62, 65, 70, 74]], [41, [65, 69, 72, 77]], [36, [64, 67, 72, 76]]],
		"melody": [[0, 74], [2, 77], [3, 76], [4, 74], [6, 72], [7, 69], [8, 70], [11, 69], [12, 65], [14, 67],
			[16, 74], [18, 77], [19, 79], [20, 81], [22, 79], [23, 77], [24, 76], [26, 72], [28, 74]],
		"bass": "Xx.xXx.x",
		"kick": "X...X...", "snare": "..x...x.", "hat_div": 4, "hats": "x.x.x.x.x.x.x.x.",
		"pulse": "clock_soft",
		"tension": [62, 63, 69],
	}


# Do mineur, 150 bpm, basse en doubles croches : on fuit. Phrases de trois mesures.
static func _poursuite() -> Dictionary:
	return {
		"beat": 0.4, "bars": 12, "chord_bars": 3, "sync": "timed",
		"drone": [24, 31, 36],
		"chords": [[36, [60, 63, 67, 72]], [32, [60, 63, 68, 72]], [34, [62, 65, 70, 74]], [31, [62, 67, 71, 74]]],
		"melody": [[0, 72], [0.5, 75], [1, 79], [2, 77], [3, 75], [4, 74], [6, 72], [7, 74], [8, 75], [10, 74],
			[12, 72], [12.5, 75], [13, 80], [14, 79], [15, 77], [16, 75], [18, 72], [20, 75], [22, 77],
			[24, 74], [24.5, 77], [25, 82], [26, 80], [27, 79], [28, 77], [30, 74], [32, 77], [34, 79],
			[36, 74], [37, 71], [38, 74], [39, 79], [40, 77], [41, 75], [42, 74], [44, 71], [46, 67]],
		"voice": "pincé",
		"bass_div": 4, "bass": "Xx.xXxoxXx.xXxox",
		"kick": "X.x.X.x.", "snare": "..x...x.", "hat_div": 4, "hats": ".x.x.x.x.x.x.x.x",
		"tension": [60, 61, 67],
	}


# Si mineur, mesures à six temps de 0,65 s : une mesure = un cycle des yeux (3,9 s).
# La mélodie ne chante que paupières closes ; quand le regard s'ouvre, tout retient son souffle.
static func _regards() -> Dictionary:
	return {
		"beat": 0.65, "bar": 6, "bars": 4, "chord_bars": 1, "sync": "eyes", "rise": 0.0,
		"drone": [23, 30, 35],
		"chords": [[35, [62, 66, 71, 74]], [31, [62, 67, 71, 74]], [40, [64, 67, 71, 76]], [42, [61, 66, 70, 73]]],
		"melody": [[0, 74], [1, 73], [2, 71], [6, 71], [7, 69], [8, 67], [12, 67], [13, 66], [14, 64],
			[18, 66], [19, 70], [20, 73]],
		"voice": "verre",
		"arp_div": 2, "arp": [0, 1, 2, 1],
		"bass_div": 1, "bass": "X.x.x.",
		"kick": "X.....x.....", "snare": "............", "hats": ".x.x.x.x.x.x",
		"pulse": "gaze",
		"tension": [71, 72, 78],
	}


# Mi mineur. Tout se lit dans les deux sens : accords, mélodie, motifs de batterie.
static func _miroir() -> Dictionary:
	var half := [[0, 76], [1, 79], [2, 83], [4, 81], [6, 79], [8, 76], [9, 74], [10, 71], [12, 74], [14, 78]]
	var melody := half.duplicate()
	for n in half:
		melody.append([31 - n[0], n[1]])
	return {
		"chord_bars": 1,
		"drone": [28, 35, 40],
		"chords": [[40, [64, 67, 71, 76]], [36, [64, 67, 72, 76]], [43, [67, 71, 74, 79]], [38, [66, 69, 74, 78]],
			[38, [66, 69, 74, 78]], [43, [67, 71, 74, 79]], [36, [64, 67, 72, 76]], [40, [64, 67, 71, 76]]],
		"melody": melody,
		"voice": "verre",
		"arp": [0, 1, 2, 3, 3, 2, 1, 0],
		"bass": "X.x..x.X",
		"kick": "X......X", "snare": "...xx...", "hats": "x.x..x.x",
		"tension": [64, 65, 71],
	}


# Fa majeur. Une seconde voix reprend la mélodie deux temps plus tard, une octave dessous.
static func _compagnie() -> Dictionary:
	return {
		"drone": [29, 36, 41],
		"chords": [[41, [65, 69, 72, 77]], [38, [62, 65, 69, 74]], [34, [62, 65, 70, 74]], [36, [64, 67, 72, 76]]],
		"melody": [[0, 72], [1, 74], [2, 76], [3, 77], [4, 76], [6, 72], [8, 74], [9, 72], [10, 69], [12, 70],
			[14, 69], [16, 70], [17, 72], [18, 74], [19, 77], [20, 76], [22, 74], [24, 72], [26, 76], [28, 77]],
		"voice": "pincé", "canon": 2.0,
		"arp": [0, 1, 2, 1, 3, 2, 1, 2],
		"bass": "X.xoX.x.",
		"kick": "X..x..x.", "snare": "....x...", "hats": ".x.x.x.x",
		"tension": [65, 66, 72],
	}


# Ré majeur à trois temps, doux : le jour se lève.
static func _matin() -> Dictionary:
	return {
		"bar": 3, "bars": 16,
		"drone": [26, 33, 38],
		"chords": [[38, [66, 69, 74, 78]], [45, [64, 69, 73, 76]], [35, [66, 71, 74, 78]], [43, [67, 71, 74, 79]]],
		"melody": [[0, 78], [3, 81], [4.5, 79], [6, 76], [9, 78], [12, 74], [15, 71], [18, 74], [21, 73],
			[24, 78], [27, 81], [28.5, 83], [30, 85], [33, 81], [36, 83], [39, 79], [42, 78], [45, 74]],
		"melody_gain": 0.8,
		"arp_div": 2, "arp": [0, 1, 2, 3, 2, 1],
		"bass_div": 1, "bass": "X.x",
		"kick": "X.....", "snare": "...x..", "hats": ".x.x.x",
		"tension": [74, 75, 81],
	}
