# Génère levels/tiles.png : la palette de tuiles de l'éditeur de niveaux (une icône de 16 px
# par caractère de l'ancien format texte). L'ordre doit rester celui de CHARS dans levels/level.gd.
#   python3 tools/make_tiles.py levels/tiles.png
import sys
from PIL import Image, ImageDraw

T = 16
COLS = 8
CHARS = "#%=^v<>-" "LOX|12ab" "iMWSB~HR" "PCDEe*Yy"

img = Image.new("RGBA", (COLS * T, (len(CHARS) + COLS - 1) // COLS * T), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

WALL = (82, 82, 82, 255)
RIM = (235, 235, 235, 255)
WHITE = (242, 242, 242, 255)
DARK = (24, 24, 24, 255)
GOLD = (240, 196, 90, 255)


def box(x, y, fill, outline=None):
    d.rectangle([x, y, x + T - 1, y + T - 1], fill=fill, outline=outline)


def spikes(x, y, kind):
    for i in range(2):
        o = i * 8
        if kind == "^":
            tri = [(x + o, y + 15), (x + o + 4, y + 7), (x + o + 7, y + 15)]
        elif kind == "v":
            tri = [(x + o, y), (x + o + 7, y), (x + o + 4, y + 8)]
        elif kind == "<":
            tri = [(x + 15, y + o), (x + 15, y + o + 7), (x + 7, y + o + 4)]
        else:
            tri = [(x, y + o), (x + 8, y + o + 4), (x, y + o + 7)]
        d.polygon(tri, fill=(230, 60, 60, 255))


def ghost(x, y, body, eyes):
    d.ellipse([x + 3, y + 2, x + 12, y + 11], fill=body)
    d.rectangle([x + 3, y + 7, x + 12, y + 13], fill=body)
    for i in range(3):
        d.point((x + 4 + i * 4, y + 14), fill=body)
    d.rectangle([x + 5, y + 6, x + 6, y + 8], fill=eyes)
    d.rectangle([x + 9, y + 6, x + 10, y + 8], fill=eyes)


def digit(x, y, ch, col):
    # Chiffres et lettres 3x5, pour les blocs numérotés
    font = {
        "1": [".#.", "##.", ".#.", ".#.", "###"],
        "2": ["##.", "..#", ".#.", "#..", "###"],
        "a": [".#.", "#.#", "###", "#.#", "#.#"],
        "b": ["##.", "#.#", "##.", "#.#", "##."],
    }[ch]
    for j, row in enumerate(font):
        for i, c in enumerate(row):
            if c == "#":
                d.rectangle([x + i * 2, y + j * 2, x + i * 2 + 1, y + j * 2 + 1], fill=col)


for n, ch in enumerate(CHARS):
    x, y = n % COLS * T, n // COLS * T
    if ch == "#":  # mur : à peine marqué, pour que les grandes masses restent lisibles
        box(x, y, WALL)
        d.line([x, y + 15, x + 15, y + 15, x + 15, y], fill=(70, 70, 70, 255))
    elif ch == "%":  # fausse paroi : un mur au liseré pointillé
        box(x, y, WALL)
        for i in range(0, T, 4):
            for p in [(x + i, y), (x + i, y + 15), (x, y + i), (x + 15, y + i)]:
                d.point(p, fill=RIM)
        d.line([x + 4, y + 11, x + 11, y + 4], fill=(150, 150, 150, 255))
    elif ch == "=":  # vitre
        box(x, y, (150, 200, 230, 160), (210, 235, 250, 255))
        d.line([x + 3, y + 12, x + 12, y + 3], fill=(240, 250, 255, 255))
    elif ch in "^v<>":
        spikes(x, y, ch)
    elif ch == "-":  # rail
        d.line([x, y + 7, x + 15, y + 7], fill=(170, 170, 170, 255))
        d.line([x + 7, y, x + 7, y + 15], fill=(110, 110, 110, 255))
        d.rectangle([x + 6, y + 6, x + 8, y + 8], fill=(200, 200, 200, 255))
    elif ch == "L":  # lumière
        box(x, y, (250, 250, 220, 255), (255, 210, 80, 255))
    elif ch == "O":  # ombre, hachurée
        box(x, y, DARK, (120, 120, 140, 255))
        for i in range(-T, T, 4):
            d.line([x + max(0, i), y + max(0, -i), x + min(15, i + 15), y + min(15, 15 - i)], fill=(80, 80, 100, 255))
    elif ch == "X":  # pierre fissurée
        box(x, y, (120, 100, 80, 255), (170, 150, 120, 255))
        d.line([x + 3, y + 2, x + 7, y + 7, x + 5, y + 13], fill=DARK)
        d.line([x + 7, y + 7, x + 13, y + 9], fill=DARK)
    elif ch == "|":  # courant d'air
        box(x, y, (60, 120, 160, 90))
        for cx in (4, 11):
            d.line([x + cx, y + 13, x + cx, y + 3], fill=(170, 220, 255, 255))
            d.line([x + cx - 2, y + 5, x + cx, y + 3, x + cx + 2, y + 5], fill=(170, 220, 255, 255))
    elif ch in "12":
        col = (90, 170, 230, 255) if ch == "1" else (230, 140, 60, 255)
        box(x, y, col, WHITE)
        digit(x + 5, y + 3, ch, DARK)
    elif ch in "ab":
        col = (220, 220, 220, 255) if ch == "a" else (60, 60, 60, 255)
        box(x, y, col, (200, 170, 60, 255))
        digit(x + 5, y + 3, ch, DARK if ch == "a" else WHITE)
    elif ch == "i":  # pierre cachée
        for i in range(0, T, 3):
            for p in [(x + i, y), (x + i, y + 15), (x, y + i), (x + 15, y + i)]:
                d.point(p, fill=(200, 220, 255, 255))
        d.ellipse([x + 6, y + 6, x + 9, y + 9], fill=(200, 220, 255, 255))
    elif ch in "MW":  # plateformes mobiles
        box(x, y, (150, 110, 190, 255), WHITE)
        if ch == "M":
            d.line([x + 3, y + 7, x + 12, y + 7], fill=WHITE)
            d.line([x + 5, y + 5, x + 3, y + 7, x + 5, y + 9], fill=WHITE)
            d.line([x + 10, y + 5, x + 12, y + 7, x + 10, y + 9], fill=WHITE)
        else:
            d.line([x + 7, y + 3, x + 7, y + 12], fill=WHITE)
            d.line([x + 5, y + 5, x + 7, y + 3, x + 9, y + 5], fill=WHITE)
            d.line([x + 5, y + 10, x + 7, y + 12, x + 9, y + 10], fill=WHITE)
    elif ch == "S":  # ressort
        d.rectangle([x + 2, y + 13, x + 13, y + 15], fill=(160, 160, 160, 255))
        d.line([x + 4, y + 12, x + 11, y + 10, x + 4, y + 8, x + 11, y + 6], fill=(120, 220, 120, 255))
        d.rectangle([x + 3, y + 4, x + 12, y + 5], fill=WHITE)
    elif ch == "B":  # cloche
        d.polygon([(x + 4, y + 12), (x + 5, y + 5), (x + 8, y + 2), (x + 11, y + 5), (x + 12, y + 12)], fill=(220, 180, 60, 255))
        d.rectangle([x + 3, y + 12, x + 12, y + 13], fill=(220, 180, 60, 255))
        d.rectangle([x + 7, y + 14, x + 8, y + 15], fill=WHITE)
    elif ch == "~":  # marée
        d.rectangle([x, y + 8, x + 15, y + 15], fill=(40, 20, 60, 220))
        d.line([x, y + 8, x + 3, y + 6, x + 7, y + 8, x + 11, y + 6, x + 15, y + 8], fill=(170, 120, 220, 255))
    elif ch == "H":
        ghost(x, y, (40, 40, 40, 255), (230, 60, 60, 255))
    elif ch == "R":
        ghost(x, y, (150, 200, 230, 200), DARK)
    elif ch == "P":
        ghost(x, y, WHITE, DARK)
    elif ch == "C":  # bougie
        d.rectangle([x + 6, y + 8, x + 9, y + 15], fill=WHITE)
        d.ellipse([x + 6, y + 2, x + 9, y + 7], fill=GOLD)
    elif ch == "D":  # cristal
        d.polygon([(x + 8, y + 2), (x + 13, y + 8), (x + 8, y + 14), (x + 3, y + 8)], fill=(110, 230, 210, 255), outline=WHITE)
    elif ch in "Ee":  # sortie (secrète : pointillée, violette)
        col = WHITE if ch == "E" else (200, 120, 230, 255)
        d.rectangle([x + 3, y + 3, x + 12, y + 15], outline=col)
        d.ellipse([x + 3, y + 1, x + 12, y + 8], outline=col)
        d.rectangle([x + 5, y + 6, x + 10, y + 14], fill=(col[0], col[1], col[2], 110))
        if ch == "e":
            d.point((x + 8, y + 10), fill=WHITE)
    elif ch == "*":  # étincelle
        d.polygon([(x + 8, y + 1), (x + 10, y + 6), (x + 15, y + 8), (x + 10, y + 10), (x + 8, y + 15),
                   (x + 6, y + 10), (x + 1, y + 8), (x + 6, y + 6)], fill=GOLD)
    elif ch in "Yy":  # œil, ouvert en premier (Y) ou une demi-période plus tard (y)
        d.ellipse([x + 1, y + 4, x + 14, y + 11], fill=WHITE, outline=(230, 60, 60, 255))
        d.ellipse([x + 6, y + 5, x + 9, y + 10], fill=DARK)
        if ch == "y":
            d.rectangle([x + 1, y + 4, x + 14, y + 7], fill=(90, 90, 90, 255))

img.save(sys.argv[1])
