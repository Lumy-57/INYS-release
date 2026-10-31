# Génère icon.png, icon.ico et splash.png (pixel art du fantôme, noir et blanc)
import sys, math
from PIL import Image, ImageDraw, ImageFilter
out = sys.argv[1]
GHOST = [
".....####.....",
"...########...",
"..##########..",
".############.",
".############.",
"#####oo###oo##",
"#####oo###oo##",
"#####oo###oo##",
"##############",
"##############",
"##############",
"##############",
"###.####.####.",
"##...##...##..",
]
FONT = {
"L":["#....","#....","#....","#....","#....","#....","#####"],
"U":["#...#","#...#","#...#","#...#","#...#","#...#",".###."],
"M":["#...#","##.##","#.#.#","#.#.#","#...#","#...#","#...#"],
"I":["#####","..#..","..#..","..#..","..#..","..#..","#####"],
"G":[".###.","#...#","#....","#.###","#...#","#...#",".###."],
"N":["#...#","##..#","#.#.#","#..##","#...#","#...#","#...#"],
"O":[".###.","#...#","#...#","#...#","#...#","#...#",".###."],
}
def halo(size, center, radius, strength):
    img = Image.new("L", size, 0)
    px = img.load()
    cx, cy = center
    for y in range(size[1]):
        for x in range(size[0]):
            d = math.hypot(x-cx, y-cy)/radius
            px[x, y] = int(255*strength*math.exp(-d*d*2.2))
    return img
def stamp(img, grid, x0, y0, s, col):
    d = ImageDraw.Draw(img)
    for j, row in enumerate(grid):
        for i, c in enumerate(row):
            if c in "#o":
                d.rectangle([x0+i*s, y0+j*s, x0+(i+1)*s-1, y0+(j+1)*s-1], fill=col if c == "#" else (0,0,0))

def ghost_on(size, center, s, glow_r, glow):
    w, h = size
    base = Image.merge("RGB", [halo(size, center, glow_r, glow)]*3)
    gw, gh = len(GHOST[0])*s, len(GHOST)*s
    stamp(base, GHOST, center[0]-gw//2, center[1]-gh//2, s, (255,255,255))
    return base

# Icône : fond noir arrondi, halo, fantôme ; un fin filet comme les vignettes
def icon(n):
    img = ghost_on((n, n), (n//2, n//2 + n//32), max(1, n*11//16//14), n*0.42, 0.55)
    d = ImageDraw.Draw(img)
    m = max(1, n//16)
    if n >= 64:
        d.rounded_rectangle([m, m, n-1-m, n-1-m], radius=n//8, outline=(110,110,110), width=max(1, n//128))
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n-1, n-1], radius=n//6, fill=255)
    rgba = img.convert("RGBA"); rgba.putalpha(mask)
    return rgba
big = icon(256)
big.save(f"{out}/icon.png")
big.save(f"{out}/icon.ico", sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])

# Écran de démarrage : fenêtre 1440x810, fantôme au centre, nom du jeu en lettres pixel
W, H = 1440, 810
img = ghost_on((W, H), (W//2, H//2 - 60), 12, 260, 0.32)
word = "LUMIGNON"; s = 6; gap = 4*s
tw = len(word)*5*s + (len(word)-1)*gap
x = (W - tw)//2; y = H//2 + 90
for ch in word:
    stamp(img, FONT[ch], x, y, s, (235,235,235))
    x += 5*s + gap
d = ImageDraw.Draw(img)
d.line([(W//2-150, y+7*s+28), (W//2+150, y+7*s+28)], fill=(70,70,70), width=2)
img.save(f"{out}/splash.png")
