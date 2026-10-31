"""Paints the uniques' colors into spare swatches of weapons/dark_texture.png
and its metal/roughness mask, the way the other dark swatches are painted:
light at the top of the cell, falling to under a third of that at the bottom.

    python3 tools/art/dark_swatches.py   (plain Python + Pillow)

Cells are (column, row) of the 8x4 grid, as SWATCH in kk_mesh.py and
make_hero_body.py name them; these were filler before.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX = os.path.join(ROOT, "assets", "kaykit", "weapons", "dark_texture.png")
MASK = os.path.join(ROOT, "assets", "kaykit", "weapons", "dark_texture_mask.png")

# name: (cell, top color, (metalness, roughness))
NEW = {
    "violet": ((2, 1), (132, 70, 190), (0, 210)),   # the Hexer's: the gown, the scepter's stone
    "frost": ((3, 1), (200, 232, 250), (150, 70)),  # the Rime's ice, the wraith's pale blue
    "ember": ((2, 2), (255, 140, 48), (0, 200)),    # the Cinder's coals, Emberheart
    "verdant": ((3, 2), (120, 180, 64), (0, 220)),  # the Thorn's leaves and seed
    "bark": ((4, 2), (104, 82, 60), (0, 245)),     # the Thorn's bark
}


def paint() -> None:
    tex = Image.open(TEX).convert("RGBA")
    mask = Image.open(MASK).convert("RGBA")
    cw, ch = tex.width // 8, tex.height // 4
    for (c, r), top, (metal, rough) in NEW.values():
        for y in range(ch):
            f = 1.0 - 0.71 * y / (ch - 1)
            col = tuple(int(round(v * f)) for v in top) + (255,)
            for x in range(cw):
                tex.putpixel((c * cw + x, r * ch + y), col)
                mask.putpixel((c * cw + x, r * ch + y), (metal, rough, 255, 255))
    tex.save(TEX)
    mask.save(MASK)


if __name__ == "__main__":
    paint()
