"""Critter Clash app icon. Original, drawn with Pillow."""

import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SIZE = 1024


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((40, 40, SIZE - 40, SIZE - 40), radius=220, fill=(242, 125, 58, 255))
    d.rounded_rectangle((70, 70, SIZE - 70, SIZE - 70), radius=190, outline=(90, 42, 32, 255), width=28)
    # Body.
    d.ellipse((250, 360, 774, 860), fill=(255, 214, 170, 255))
    d.ellipse((300, 300, 724, 700), fill=(242, 140, 70, 255))
    # Belly.
    d.ellipse((390, 520, 640, 800), fill=(255, 228, 190, 255))
    # Eyes.
    d.ellipse((360, 400, 500, 560), fill=(255, 248, 240, 255))
    d.ellipse((524, 400, 664, 560), fill=(255, 248, 240, 255))
    d.ellipse((410, 450, 490, 540), fill=(242, 184, 74, 255))
    d.ellipse((574, 450, 654, 540), fill=(242, 184, 74, 255))
    d.ellipse((438, 478, 490, 534), fill=(42, 28, 24, 255))
    d.ellipse((602, 478, 654, 534), fill=(42, 28, 24, 255))
    d.ellipse((450, 488, 472, 510), fill=(255, 255, 255, 255))
    d.ellipse((614, 488, 636, 510), fill=(255, 255, 255, 255))
    # Cheeks and snout.
    d.ellipse((330, 530, 430, 610), fill=(255, 150, 168, 255))
    d.ellipse((594, 530, 694, 610), fill=(255, 150, 168, 255))
    d.ellipse((450, 540, 574, 640), fill=(255, 196, 140, 255))
    d.ellipse((490, 575, 534, 615), fill=(90, 42, 32, 255))
    # Horns.
    d.polygon([(360, 340), (400, 180), (450, 340)], fill=(255, 236, 210, 255))
    d.polygon([(664, 340), (624, 180), (574, 340)], fill=(255, 236, 210, 255))
    # Wings.
    d.polygon([(250, 520), (90, 430), (140, 640), (260, 620)], fill=(255, 176, 122, 255))
    d.polygon([(774, 520), (934, 430), (884, 640), (764, 620)], fill=(255, 176, 122, 255))
    img.save(os.path.join(ROOT, "icon.png"))
    img.resize((128, 128), Image.Resampling.LANCZOS).save(os.path.join(ROOT, "icon_128.png"))
    print("icon ok")


if __name__ == "__main__":
    main()
