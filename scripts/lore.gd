# L'histoire cachée : un journal, un fragment par étincelle.
# En surface, quelqu'un raconte sa vie dans une grande tour : les cloches, la flamme
# qu'on doit tenir « comme il faut », et un tout petit lumignon gardé allumé en secret.
# En dessous, une double lecture voulue par Alex, à laisser deviner sans jamais la dire :
# la tour est l'école, les cloches rangent chacun dans sa file, le lumignon est la part
# de soi qu'on cache, l'ombre et les miroirs parlent du corps et du regard. La personne
# qui écrit accorde ses adjectifs tantôt au masculin, tantôt au féminin, sans l'expliquer.
# La petite lueur blanche qui tourne autour du fantôme et lui souffle les indices, ce sont
# les ami·es qui l'acceptent tel·le qu'il ou elle est : elle reste, ne rit pas, l'appelle
# comme il faut, et « ils sont plusieurs dedans ».
# Fragment clé : celui de Contre-jour. Texte de référence :
# /mnt/project-files/histoire/lumignon-double-lecture.md (hors du dépôt).
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

# Le nom du jeu, à un seul endroit
const TITLE := "L U M I G N O N"
const NAME := "Lumignon"
const TAGLINE := "Une petite lueur, et tout le noir autour."

# Fragment n° i = étincelle du niveau i (même ordre que LevelData.LEVELS)
const FRAGMENTS := [
	# Le Seuil : l'école
	"Le premier jour, on m'a donné une place dans la tour. Une rangée, un nom, une façon de tenir la flamme.",
	"On nous alignait le long du mur, du plus petit au plus grand. Je regardais les autres pour savoir comment me tenir.",
	"Il y avait deux escaliers, un pour chaque sorte d'enfants. Je ne savais pas qu'on pouvait se tromper d'escalier.",
	"Je prenais toujours l'escalier qu'on m'indiquait. Sur les marches de l'autre, il restait des braises, et j'avais envie d'y poser la main.",
	"J'ai appris vite. J'étais sage, j'étais content, on me le disait. Je le répétais pour m'en souvenir.",
	# Lumière et ombre : la prise de conscience
	"La flamme fait danser des ombres sur les murs. Certaines me ressemblent plus que moi.",
	"Quand je brille, tout le monde me voit. Quand je m'éteins, je passe là où personne ne regarde.",
	"La nuit, j'allume une toute petite lueur au pied du lit, juste pour moi. Mon lumignon. Personne ne la voit.",
	"Dans la pénombre, j'essaie des gestes qu'on ne m'a pas appris. Personne ne me corrige, alors je recommence.",
	"Au matin, mon lumignon brûlait encore. Je ne l'avais pas éteint. J'étais un peu fière de lui.",
	# Profondeurs : chercher
	"Sous la tour, il y a des galeries que personne ne visite. J'y descends quand le bruit d'en haut est trop fort.",
	"Les pierres d'en bas cèdent si l'on s'y attarde. Moi aussi, je m'effrite quand je fais semblant trop longtemps.",
	"Le vent des puits porte des voix. Pour la première fois, l'une d'elles parle comme moi. Elle brille tout blanc, et elle ne repart pas.",
	"La voix m'a demandé comment je voulais qu'on m'appelle. Personne ne me l'avait jamais demandé. Je n'ai pas su répondre. Elle a dit : « Ça ne presse pas. »",
	"Tout en bas, une pierre gravée : « Tant qu'elle brûle, rien de ce que tu es n'est perdu. »",
	# Clocher : les règles
	"Trois cloches : une pour se lever, une pour se ranger, une pour se taire.",
	"Pour atteindre les cloches, il faut sauter haut. On applaudit ceux qui sautent comme il faut, du bon côté de la cour.",
	"Quand la cloche sonne, chacun rejoint sa file. Je reste un instant entre les deux. On me le reproche.",
	"Chaque jour le même trajet, aller et retour, d'une file à l'autre. On finit par connaître le chemin sans jamais choisir où il mène.",
	"On m'a dit de tenir la flamme droite, comme il faut. J'ai appris à la cacher dans ma main.",
	# Carillon : les étiquettes
	"Les cloches ont chacune un nom. On voulait m'en donner un aussi, et qu'il sonne toujours pareil.",
	"Un soir, j'ai essayé un autre nom, tout bas, pour entendre comment il sonnait. Il a tinté longtemps dans ma tête. Il m'allait bien.",
	"Certains jours, ma voix sonne grave. D'autres jours, plus claire. Les deux sont à moi.",
	"Sous la voûte, l'écho me renvoie ma voix. Je suis resté longtemps à l'écouter, pour apprendre à l'aimer.",
	"Ils rient quand ma cloche ne fait pas le son attendu. Alors je sonne moins fort. La petite lueur, elle, ne rit jamais. Elle m'appelle comme je le lui ai demandé.",
	# Horloge : attendre
	"On me dit : plus tard. Quand tu seras grand. Plus tard, je serai qui je veux, mais pas aujourd'hui.",
	"Le balancier va d'un côté, puis de l'autre. On me dit de choisir un côté et de m'y tenir. Lui ne choisit jamais, et personne ne le gronde.",
	"J'ai arrêté l'horloge pour que plus tard n'arrive jamais. J'étais fatiguée d'attendre. J'étais fatigué de faire semblant.",
	"Sans l'horloge, les jours se ressemblent moins. Certains matins, je me sens prête. D'autres, je préfère attendre encore un peu, et c'est permis.",
	"Minuit. Je ferme les yeux et j'essaie d'imaginer mon reflet sans personne autour pour le juger.",
	# Dernière lueur : presque
	"Quand la flamme qu'on m'avait confiée s'est éteinte, j'ai eu peur. Puis j'ai vu qu'une autre brûlait encore.",
	"Je repasse chaque marche de la tour dans ma tête. Tout ce que j'ai appris pour leur plaire me sert maintenant à aller ailleurs.",
	"Mon lumignon. Il tremblait, mais il tenait tout seul. Il n'avait jamais eu besoin de leur flamme.",
	"Je l'ai veillé toute la nuit, la main autour de la flamme. Pas pour la cacher, cette fois : pour qu'elle ait chaud.",
	"Je lui ai donné tout ce que je cachais. Il trouvera la sortie, et moi avec.",
	# Poursuite : le corps
	"Il y a une ombre qui me suit partout. Elle a ma taille, ma démarche. C'est le corps qu'on attend de moi.",
	"Elle colle à mes talons. Si je ralentis, elle me tire en arrière, vers ce que j'étais censé être.",
	"Dans le miroir, certains jours je suis belle, d'autres je suis beau. Les deux jours, c'est moi.",
	"Le noir monte dès que je m'arrête. Alors je grimpe, même épuisée, parce qu'en haut il fait moins froid.",
	"Mon ombre ne veut pas m'éteindre. Elle a seulement froid. Un jour, on marchera ensemble.",
	# Regards : le regard des autres
	"Ici, chaque fenêtre est un œil. J'avance plus vite quand on ne me regarde pas.",
	"J'apprends à marcher entre deux clignements. Le temps qu'ils rouvrent les yeux, je suis déjà plus loin, et un peu plus moi.",
	"Leurs regards pèsent plus lourd que mes pas. Une petite lueur marche avec moi. On dirait une seule ; ils sont plusieurs dedans.",
	"Quand l'un détourne les yeux, un autre me trouve. Alors je reste près de ceux qui ne demandent rien.",
	"Je ne leur demande pas de comprendre. Seulement de me laisser passer.",
	# Miroir : se regarder soi-même
	"Dans le miroir, il y a quelqu'un qui fait tout comme moi. Sauf que ce n'est pas tout à fait moi.",
	"Quand je saute, mon reflet saute aussi. De son côté, les obstacles ne sont pas les mêmes, mais on les franchit d'un seul élan.",
	"Si je lève la main gauche, mon reflet lève la droite. On se trompe ensemble, alors on se trompe moins.",
	"Parfois on se décale, mon reflet et moi. Il suffit de s'appuyer contre le même mur pour se retrouver. Je n'ai plus peur des murs.",
	"Au sommet, on s'est rejoints. Je ne sais plus lequel de nous deux était le reflet. Ça n'a plus d'importance.",
	# Compagnie : ceux qui restent
	"Dans le noir, je ne vois pas où poser le pied. Elle, si. Elle ne marche pas à ma place : elle éclaire juste là où je vais.",
	"Je pose un pied, elle éclaire le suivant. On n'a pas besoin de parler. Pour une fois, je ne suis pas seul dans le noir.",
	"Quand je m'élance trop vite, elle passe devant. Quand je m'arrête, elle s'arrête aussi. Elle n'a jamais demandé où j'allais, ni qui j'étais censée être.",
	"Je lui ai demandé si elle avait peur, parfois, de ce qu'il y a devant. Elle a dit oui. Elle y va quand même, et elle m'attend de l'autre côté.",
	"De loin, on croit qu'il n'y a qu'une lueur. De près, elles sont plusieurs, serrées. Chacune connaît mon nom, le vrai. Ce soir-là, je suis rentré sans avoir peur du noir.",
]

# Ajout à l'épilogue quand toutes les étincelles ont été trouvées
const TRUE_ENDING := [
	"",
	"Mais cette fois, le fantôme ne sort pas.",
	"Il remonte tout en haut, là où l'on rangeait les enfants, et allume sa propre flamme.",
	"",
	"Elle ne brûle ni comme ceci, ni comme cela. Elle brûle comme elle est.",
	"L'ombre s'assoit près du feu, la petite lueur tourne autour, et pour la première fois, personne n'a froid.",
]

# Épilogue « Le matin » : une page par niveau, écrite en le finissant.
# Plus d'accord qui hésite : la personne qui écrit ne choisit plus que des mots
# qui lui vont dans tous les cas (libre, calme, tranquille), et ça ne se remarque pas.
const EPILOGUE_PAGES := [
	"Ce matin, aucune cloche n'a sonné. J'ai ouvert les yeux quand j'ai voulu, et la tour avait des couleurs.",
	"La brume se lève doucement sur la cour. Je prends le temps de tout regarder, et rien ne me presse.",
	"Les fenêtres qui me regardaient sont devenues des vitraux. La petite lueur m'appelle par mon nom, et les autres ont appris à le dire aussi.",
	"À midi, la lumière entre partout. Je me vois passer dans les vitres, et je me reconnais du premier coup.",
	"Mon ombre marche à côté de moi. On ne se ressemble pas tout à fait. On se tient chaud quand même, et je suis tranquille.",
]

# Fin de l'épilogue, sur fond d'aube
const EPILOGUE_END := [
	"Le fantôme ne cherche plus la sortie.",
	"Il est chez lui, et chez lui, il y a des couleurs.",
	"",
	"Personne ne lui demande plus laquelle est la sienne.",
	"Il les garde toutes, et sa flamme brûle comme elle est.",
]


static func fragment(index: int) -> String:
	if LevelData.is_epilogue(index):
		var page := index - LevelData.story_end()
		return EPILOGUE_PAGES[page] if page < EPILOGUE_PAGES.size() else ""
	if index < 0 or index >= FRAGMENTS.size():
		return ""
	return FRAGMENTS[index]
