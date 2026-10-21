"""Print a PNG as ASCII art, so a screenshot can be checked without eyes.

    python tools/ascii_shot.py captures/hub.png [width]

The width is the number of characters across (default 96). The picture is
scaled to that width, turned to grey, and printed with a brightness ramp.
"""

import sys
from pathlib import Path

from PIL import Image

RAMP = "@%#*+=-:. "


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: ascii_shot.py <png> [width]")
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print("no such file: %s" % path)
        return 1
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 96
    img = Image.open(path).convert("L")
    w, h = img.size
    height = max(1, int(width * h / w / 2.1))
    small = img.resize((width, height))
    data = list(small.getdata())
    print("%s %dx%d -> %dx%d" % (path.name, w, h, width, height))
    for row in range(height):
        line = []
        for col in range(width):
            v = data[row * width + col]
            line.append(RAMP[min(len(RAMP) - 1, v * len(RAMP) // 256)])
        print("".join(line))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
