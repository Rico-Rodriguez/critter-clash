#!/usr/bin/env python3
"""Build critter and arena PNGs from Kenney's CC0 packs.

Downloads (already mirrored on OpenGameArt):

- https://opengameart.org/content/animal-pack-redux
- https://opengameart.org/content/background-elements-redux

The game still loads sprites by filename. This only fills those files.
"""

from __future__ import annotations

import math
import urllib.request
import zipfile
from collections import deque
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CRITTER = ROOT / "assets" / "sprites" / "critters"
ARENA = ROOT / "assets" / "sprites" / "arenas"
CACHE = Path("/tmp/critter-clash-kenney")

ANIMALS = "https://opengameart.org/sites/default/files/kenney_animalPackRedux.zip"
SCENERY = "https://opengameart.org/sites/default/files/Background%20Elements%20Redux.zip"

# Alphabetical sheet order from Animal Pack Redux, round-outline vector.
ORDER = [
    "bear", "buffalo", "chick", "chicken", "cow",
    "crocodile", "dog", "duck", "elephant", "frog",
    "giraffe", "goat", "gorilla", "hippo", "horse",
    "monkey", "moose", "narwhal", "owl", "panda",
    "parrot", "penguin", "pig", "rabbit", "rhino",
    "sloth", "snake", "walrus", "whale", "zebra",
]

# critter id -> (kenney animal, hue degrees). Outline and white stay put.
CAST = {
    "ember": ("parrot", -75),
    "juniper": ("dog", -8),
    "pebble": ("penguin", 18),
    "lumen": ("owl", 0),
    "pip": ("frog", 8),
    "bramble": ("goat", 12),
    "thistle": ("pig", -6),
    "caplet": ("hippo", 28),
    "nimbus": ("rabbit", 0),
    "cinder": ("crocodile", -55),
    "sprout": ("chick", 25),
    "beetle": ("duck", -12),
    "moth": ("chicken", 10),
    "boarlet": ("buffalo", -4),
    "capling": ("monkey", 18),
    "spore": ("panda", 16),
    "glowmoth": ("sloth", 70),
    "puddle": ("walrus", 35),
    "snowpup": ("bear", 140),
    "shard": ("moose", 150),
    "icewisp": ("narwhal", 20),
    "yeti": ("elephant", 160),
    "cindling": ("horse", -35),
    "skink": ("snake", -40),
    "ashbat": ("cow", -20),
    "magmash": ("rhino", -48),
}

BIOMES = {
    "meadow": {
        "top": (176, 210, 104),
        "bot": (64, 138, 58),
        "props": [
            "tree.png", "treePine.png", "bush1.png", "bush2.png", "bush3.png", "bush4.png",
            "treeSmall_green1.png", "treeSmall_green2.png", "treeSmall_green3.png",
        ],
    },
    "mushroom": {
        "top": (132, 104, 176),
        "bot": (46, 78, 68),
        "props": [
            "treeOrange.png", "treeLongOrange.png", "bushOrange1.png", "bushOrange2.png",
            "bushOrange3.png", "bushOrange4.png", "treeSmall_orange1.png", "treeSmall_orange2.png",
        ],
    },
    "frost": {
        "top": (214, 230, 242),
        "bot": (118, 158, 188),
        "props": [
            "treePineSnow.png", "treeSnow.png", "treeFrozen.png", "treePineFrozen.png",
            "treeLongSnow.png", "treeLongFrozen.png",
        ],
    },
    "volcano": {
        "top": (132, 62, 46),
        "bot": (42, 24, 26),
        "props": [
            "treeDead.png", "treeOrange.png", "cactus1.png", "cactus2.png", "cactus3.png",
            "bushOrange1.png", "bushOrange3.png",
        ],
    },
}


def fetch(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 1000:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, dest)


def hue_rotate(img: Image.Image, degrees: float) -> Image.Image:
    if abs(degrees) < 0.5:
        return img
    arr = np.array(img.convert("RGBA")).astype(np.float32)
    rgb = arr[:, :, :3] / 255.0
    span = rgb.max(axis=2) - rgb.min(axis=2)
    rad = math.radians(degrees)
    cos, sin = math.cos(rad), math.sin(rad)
    third = (1.0 - cos) / 3.0
    root = math.sqrt(1.0 / 3.0) * sin
    matrix = np.array(
        [
            [cos + third, third - root, third + root],
            [third + root, cos + third, third - root],
            [third - root, third + root, cos + third],
        ],
        dtype=np.float32,
    )
    rotated = np.clip(rgb.reshape(-1, 3) @ matrix.T, 0, 1).reshape(rgb.shape)
    mask = (span > 0.12)[:, :, None]
    arr[:, :, :3] = np.where(mask, rotated * 255.0, arr[:, :, :3])
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def components(img: Image.Image) -> list[tuple[int, int, int, int]]:
    alpha = np.array(img.convert("RGBA"))[:, :, 3]
    small = alpha[::8, ::8] > 20
    height, width = small.shape
    seen = np.zeros_like(small, dtype=bool)
    boxes: list[tuple[int, int, int, int, int]] = []
    ys, xs = np.where(small)
    for y, x in zip(ys, xs):
        if seen[y, x]:
            continue
        queue = deque([(int(y), int(x))])
        seen[y, x] = True
        minx = maxx = int(x)
        miny = maxy = int(y)
        count = 0
        while queue:
            cy, cx = queue.popleft()
            count += 1
            minx, maxx = min(minx, cx), max(maxx, cx)
            miny, maxy = min(miny, cy), max(maxy, cy)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < height and 0 <= nx < width and small[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        if count > 40:
            boxes.append((minx * 8, miny * 8, (maxx + 1) * 8, (maxy + 1) * 8, count))
    boxes.sort(key=lambda box: ((box[1] + box[3]) // 2 // 700, box[0]))
    return [(b[0], b[1], b[2], b[3]) for b in boxes]


def render_svg(svg: Path, dest: Path) -> Image.Image:
    if dest.exists():
        return Image.open(dest).convert("RGBA")
    import shutil
    import subprocess

    if shutil.which("rsvg-convert") is None:
        raise SystemExit("rsvg-convert is required to rasterize the Kenney vectors")
    # Pad the page. The source SVG is cropped tight and clips ears and feet.
    subprocess.check_call(
        [
            "rsvg-convert",
            "-w",
            "7200",
            "--page-width",
            "7800",
            "--page-height",
            "7600",
            "--left",
            "300",
            "--top",
            "300",
            "-o",
            str(dest),
            str(svg),
        ]
    )
    return Image.open(dest).convert("RGBA")


def _thumb(img: Image.Image, size: int = 40) -> np.ndarray:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sprite = img.convert("RGBA").copy()
    sprite.thumbnail((size, size), Image.Resampling.BOX)
    canvas.paste(sprite, ((size - sprite.size[0]) // 2, (size - sprite.size[1]) // 2), sprite)
    arr = np.array(canvas).astype(np.float32)
    alpha = arr[:, :, 3:4] / 255.0
    return (arr[:, :, :3] * alpha).reshape(-1)


def add_outline(img: Image.Image, px: int = 28) -> Image.Image:
    """Dark sticker outline. The round vectors ship without one."""
    img = img.convert("RGBA")
    grown = img.getchannel("A")
    for _ in range(max(1, px // 4)):
        grown = grown.filter(ImageFilter.MaxFilter(9))
    base = Image.new("RGBA", img.size, (32, 26, 34, 255))
    base.putalpha(grown)
    base.alpha_composite(img)
    return base


def animals() -> dict[str, Image.Image]:
    zpath = CACHE / "animals.zip"
    fetch(ANIMALS, zpath)
    unpacked = CACHE / "animals"
    svg = unpacked / "Vector" / "round.svg"
    if not svg.exists():
        with zipfile.ZipFile(zpath) as zf:
            zf.extractall(unpacked)
    sheet = render_svg(svg, CACHE / "round_padded.png")
    boxes = components(sheet)
    png_dir = unpacked / "PNG" / "Round"
    names = sorted(path.stem for path in png_dir.glob("*.png"))
    if len(boxes) != len(names):
        raise SystemExit(f"expected {len(names)} animals, found {len(boxes)}")
    bank = {name: _thumb(Image.open(png_dir / f"{name}.png")) for name in names}
    crops: list[Image.Image] = []
    for box in boxes:
        crop = sheet.crop(box)
        bbox = crop.getbbox()
        crops.append(crop.crop(bbox) if bbox else crop)
    pairs: list[tuple[float, int, int]] = []
    thumbs = [_thumb(crop) for crop in crops]
    for i, thumb in enumerate(thumbs):
        for j, name in enumerate(names):
            pairs.append((float(np.mean(np.abs(thumb - bank[name]))), i, j))
    pairs.sort()
    used_i: set[int] = set()
    used_j: set[int] = set()
    assigned: dict[str, Image.Image] = {}
    for cost, i, j in pairs:
        if i in used_i or j in used_j:
            continue
        used_i.add(i)
        used_j.add(j)
        assigned[names[j]] = crops[i]
    if len(assigned) != len(names):
        raise SystemExit("could not match every Kenney animal")
    return assigned


def place_critter(sprite: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    sprite = sprite.copy()
    sprite.thumbnail((860, 860), Image.Resampling.LANCZOS)
    x = (1024 - sprite.size[0]) // 2
    y = 560 - sprite.size[1] // 2
    canvas.paste(sprite, (x, y), sprite)
    return canvas


def ground(name: str, spec: dict) -> Image.Image:
    w, h = 1440, 2560
    top = np.array(spec["top"], dtype=np.float32)
    bot = np.array(spec["bot"], dtype=np.float32)
    yy = np.linspace(0, 1, h)[:, None, None]
    col = np.broadcast_to(top * (1 - yy) + bot * yy, (h, w, 3)).copy()
    rng = np.random.default_rng(sum((i + 3) * ord(ch) for i, ch in enumerate(name)))
    col += rng.normal(0, 3.5, (h, w, 1))
    # A soft center so the fight reads, without a flat oval.
    xx = np.linspace(-1, 1, w)[None, :]
    y2 = np.linspace(-1, 1, h)[:, None]
    light = np.clip(1.08 - (xx * xx * 0.35 + (y2 - 0.05) ** 2 * 0.22), 0.72, 1.08)
    col *= light[:, :, None]
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def scenery() -> dict[str, Image.Image]:
    zpath = CACHE / "scenery.zip"
    fetch(SCENERY, zpath)
    unpacked = CACHE / "scenery"
    retina = unpacked / "PNG" / "Retina"
    if not retina.exists():
        with zipfile.ZipFile(zpath) as zf:
            zf.extractall(unpacked)
    out = {}
    for path in retina.glob("*.png"):
        out[path.name] = Image.open(path).convert("RGBA")
    return out


def stamp(base: Image.Image, sprite: Image.Image, x: int, y: int, scale: float) -> None:
    spr = sprite.copy()
    spr = spr.resize((max(8, int(spr.size[0] * scale)), max(8, int(spr.size[1] * scale))), Image.Resampling.NEAREST if scale >= 0.99 else Image.Resampling.LANCZOS)
    # Contact shadow, then the sprite. Feet sit on y.
    shadow = Image.new("RGBA", spr.size, (0, 0, 0, 0))
    sh = np.zeros((spr.size[1], spr.size[0], 4), dtype=np.uint8)
    alpha = np.array(spr)[:, :, 3]
    foot = alpha[-max(4, spr.size[1] // 8) :, :].max(axis=0) > 20
    if foot.any():
        left, right = int(np.argmax(foot)), int(len(foot) - 1 - np.argmax(foot[::-1]))
        cy = spr.size[1] - 8
        cx = (left + right) // 2
        rx = max(10, (right - left) // 2)
        yy, xx = np.ogrid[: spr.size[1], : spr.size[0]]
        ell = ((xx - cx) / rx) ** 2 + ((yy - cy) / 10) ** 2
        sh[:, :, 3] = (np.clip(1 - ell, 0, 1) * 90).astype(np.uint8)
        shadow = Image.fromarray(sh, "RGBA")
    base.alpha_composite(shadow, (x, y + 10))
    base.alpha_composite(spr, (x, y))


def build_arena(name: str, spec: dict, props: dict[str, Image.Image]) -> Image.Image:
    img = ground(name, spec)
    rng = np.random.RandomState(sum(ord(ch) for ch in name) + 17)
    w, h = img.size
    choices = [props[p] for p in spec["props"] if p in props]
    for i in range(42):
        spr = choices[i % len(choices)]
        edge = i < 26
        if edge:
            side = i % 4
            if side == 0:
                x, y = rng.randint(-40, 180), rng.randint(80, h - 200)
            elif side == 1:
                x, y = rng.randint(w - 320, w - 40), rng.randint(80, h - 200)
            elif side == 2:
                x, y = rng.randint(40, w - 200), rng.randint(40, 280)
            else:
                x, y = rng.randint(40, w - 200), rng.randint(h - 420, h - 80)
            scale = rng.uniform(0.85, 1.25)
        else:
            x, y = rng.randint(180, w - 360), rng.randint(360, h - 420)
            # Keep the middle of the fight clear.
            if abs(x - w / 2) < 220 and abs(y - h * 0.55) < 280:
                continue
            scale = rng.uniform(0.45, 0.75)
        stamp(img, spr, int(x), int(y), scale)
    return img.convert("RGB")


def main() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    CRITTER.mkdir(parents=True, exist_ok=True)
    ARENA.mkdir(parents=True, exist_ok=True)
    roster = animals()
    for cid, (animal, hue) in CAST.items():
        place_critter(add_outline(hue_rotate(roster[animal], hue))).save(CRITTER / f"{cid}.png")
        print("critter", cid, "<-", animal)
    props = scenery()
    for name, spec in BIOMES.items():
        build_arena(name, spec, props).save(ARENA / f"{name}.png", optimize=True)
        print("arena", name)


if __name__ == "__main__":
    main()
