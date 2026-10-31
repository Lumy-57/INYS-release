# Génère levels/murs.png et la source « Murs taillés » de levels/tiles.tres : les murs aux coins
# arrondis (r roche), biseautés (t pierre taillée) ou enneigés (g givre). Une rangée par style,
# 16 tuiles par rangée : une par combinaison de voisins (haut, droite, bas, gauche), pour le
# remplissage automatique de Godot (terrains, « Match Sides »). Le rendu en jeu est fait par
# scripts/tiles_drawer.gd, qui suit les mêmes formes.
#   python3 tools/make_murs.py levels/murs.png levels/tiles.tres
import math
import re
import sys
from PIL import Image, ImageDraw

T = 16
STYLES = [("r", "Roche", "0.55, 0.55, 0.55"), ("t", "Pierre taillée", "0.75, 0.75, 0.75"),
          ("g", "Givre", "0.95, 0.95, 0.95")]
WALL = (82, 82, 82, 255)
RIM = (242, 242, 242, 255)
DARK = (64, 64, 64, 255)
LIGHT = (98, 98, 98, 255)
RIM_W = 2


def shape(x0, y0, x1, y1, corners, radius, bevel):
    pts = []
    centers = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    inward = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
    for i in range(4):
        cx, cy = centers[i]
        if not corners[i] or radius <= 0:
            pts.append((cx, cy))
            continue
        ox, oy = cx + inward[i][0] * radius, cy + inward[i][1] * radius
        steps = 1 if bevel else 4
        for k in range(steps + 1):
            a = math.pi + i * math.pi / 2 + math.pi / 2 * k / steps
            pts.append((ox + math.cos(a) * radius, oy + math.sin(a) * radius))
    return pts


def fill(d, pts, color):
    # Remplit les pixels dont le centre est dans le polygone (comme le rendu en jeu)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for py in range(int(min(ys)), int(max(ys)) + 1):
        for px in range(int(min(xs)), int(max(xs)) + 1):
            cx, cy = px + 0.5, py + 0.5
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                (xi, yi), (xj, yj) = pts[i], pts[j]
                if (yi > cy) != (yj > cy) and cx < (xj - xi) * (cy - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                d.point((px, py), fill=color)


def tile(d, x, y, kind, up, right, down, left):
    radius = 4 if kind == "t" else 5
    bevel = kind == "t"
    corners = [up and left, up and right, down and right, down and left]
    if up or down or left or right:
        fill(d, shape(x, y, x + T, y + T, corners, radius, bevel), RIM)
        fill(d, shape(x + (RIM_W if left else 0), y + (RIM_W if up else 0), x + T - (RIM_W if right else 0),
                        y + T - (RIM_W if down else 0), corners, radius - (1.2 if bevel else RIM_W), bevel), WALL)
    else:
        d.rectangle([x, y, x + T - 1, y + T - 1], fill=WALL)
    if kind == "r":
        for px, py in [(6, 5), (10, 9), (5, 11)]:
            d.point((x + px, y + py), fill=DARK)
        d.line([x + 5, y + 6, x + 8, y + 8, x + 9, y + 11, x + 12, y + 12], fill=DARK)
    elif kind == "t":
        top = y + (RIM_W if up else 0)
        bottom = y + T - 1 - (RIM_W if down else 0)
        d.line([x + (RIM_W + 1 if left else 0), y + 8, x + T - 1 - (RIM_W + 1 if right else 0), y + 8], fill=DARK)
        d.line([x + 8, top, x + 8, y + 7], fill=DARK)
        if not left:
            d.line([x, y + 9, x, bottom], fill=DARK)
    elif kind == "g":
        if up:
            d.line([x + (2 if left else 0), y + RIM_W, x + T - 1 - (2 if right else 0), y + RIM_W], fill=RIM)
            for i, n in enumerate([3, 0, 4, 2]):
                px = x + 2 + i * 4
                if n < 2 or (left and px < x + 4) or (right and px > x + T - 5):
                    continue
                d.rectangle([px, y + RIM_W + 1, px + 1, y + RIM_W + n], fill=RIM)
                d.point((px, y + RIM_W + 1 + n), fill=RIM)
        else:
            for px, py in [(6, 6), (10, 10)]:
                d.point((x + px, y + py), fill=LIGHT)


def main(png, tres):
    img = Image.new("RGBA", (16 * T, len(STYLES) * T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lines = []
    for row, (kind, _, _) in enumerate(STYLES):
        for mask in range(16):
            # bit 0 : voisin en haut, 1 : à droite, 2 : en bas, 3 : à gauche (même style)
            linked = [bool(mask & (1 << b)) for b in range(4)]
            tile(d, mask * T, row * T, kind, not linked[0], not linked[1], not linked[2], not linked[3])
            key = "%d:%d/0" % (mask, row)
            lines.append("%s = 0" % key)
            lines.append("%s/terrain_set = 0" % key)
            lines.append("%s/terrain = %d" % (key, row))
            for b, side in enumerate(["top_side", "right_side", "bottom_side", "left_side"]):
                if linked[b]:
                    lines.append("%s/terrains_peering_bit/%s = %d" % (key, side, row))
    img.save(png)

    # La source 1 de levels/tiles.tres, et l'ensemble de terrains qui la remplit
    text = open(tres).read()
    text = re.sub(r'\[ext_resource type="Texture2D" path="res://levels/murs.png"[^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="TileSetAtlasSource" id="Murs"\]\n.*?\n\n', "", text, flags=re.S)
    text = re.sub(r"\nterrain_set_0/.*", "", text)
    text = re.sub(r"\nsources/1 = .*", "", text)
    text = text.replace('[sub_resource type="TileSetAtlasSource"',
                        '[ext_resource type="Texture2D" path="res://levels/murs.png" id="murs_png"]\n\n'
                        '[sub_resource type="TileSetAtlasSource" id="Murs"]\ntexture = ExtResource("murs_png")\n'
                        + "\n".join(lines) + "\n\n" + '[sub_resource type="TileSetAtlasSource"', 1)
    terrains = ["terrain_set_0/mode = 2"]
    for i, (_, name, col) in enumerate(STYLES):
        terrains.append('terrain_set_0/terrain_%d/name = "%s"' % (i, name))
        terrains.append("terrain_set_0/terrain_%d/color = Color(%s, 1)" % (i, col))
    text = text.replace("[resource]\n", "[resource]\n" + "\n".join(terrains) + "\n", 1)
    text = text.rstrip("\n") + '\nsources/1 = SubResource("Murs")\n'
    text = re.sub(r"load_steps=\d+ ", "", text)
    open(tres, "w").write(text)


main(sys.argv[1], sys.argv[2])
