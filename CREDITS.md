# Credits

Critter Clash is an original game. The match, habitats, and interface are original. The 3D cast and the glade are built from CC0 packs, recolored and scaled for this project.

## Code and engine

- Godot Engine 4.7.2 — https://godotengine.org — MIT License.

## Font

- Nunito by Vernon Adams, Cyreal, Jacques Le Bailly, and other contributors.
- Files: `assets/fonts/Nunito-SemiBold.ttf`, `Nunito-Bold.ttf`, `Nunito-ExtraBold.ttf`.
- License: SIL Open Font License 1.1. See `assets/fonts/OFL.txt`.
- Source: [fontsource Nunito](https://fontsource.org/fonts/nunito) latin weights 600, 700, and 800.

## Creatures

All of these are CC0. Attribution is not required. It is recorded here so the source of each critter is obvious.

- Ember, the baby dragon. [Pixor small dragon](https://pixor.art/library/creatures/dragon-small/) by Pixor. CC0. Rigged, with a fly cycle. Recolored orange, teal, and lava, and the eyes are scaled up.
- Juniper, the fox. [Cozy Animals](https://dragofive.itch.io/cozy-animals-3d) by Gamideo. CC0. The fox mesh, texture, and idle / walk / gesture clips. Gamideo generated the meshes in Meshy and authored the animation clips. Forest and lava forms are hue shifts of that texture.
- Pebble, the otter. Same Gamideo Cozy Animals pack. CC0. Idle, walk, gesture, swim, and swim-idle.
- Lumen, the owl. [Pixor owl](https://pixor.art/library/creatures/owl/) by Pixor. CC0. Rigged, with the pack's blink used as idle. A wingbeat clip was added in `tools/prepare_cast.py`. Recolored cream, grove green, and storm blue, and the eyes are scaled up.
- Pip, the frog, and Bramble, the cactus-hog. [Ultimate Monsters](https://quaternius.com) by Quaternius. CC0. `Frog.gltf` and `Cactoro.gltf`. Their idle is a standing pose taken from the walk cycle, because the pack's own idle holds the arms out. Evolutions are about 1.3 times as tall and wear a leaf mane or a flame crest.

## Glade

- Trees, rocks, grass, flowers, mushrooms, and the path stones in the dens, burrows, and bridge. [Stylized Nature MegaKit](https://quaternius.com/packs/stylizednature.html) by Quaternius. CC0. Standard glTF set. A few lava props are hue shifts of the same meshes.

`tools/prepare_cast.py` imports those files, drops oversized normal maps, recolors, normalizes height, and writes the GLBs in `assets/models/`.

## Audio

- Effects and the music loop are synthesized by `tools/build_audio.py`.
- No sampled libraries and no third-party tracks.

## Icon

- `icon.png` is drawn by `tools/make_icon.py`.
