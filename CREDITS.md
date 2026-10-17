# Credits

Critter Clash is an original game. The hunt, the roster, and the interface are original. Critter and arena pictures are Kenney's CC0 packs, composed onto the filenames the game already loads. Nothing in the game changes a critter's role based on where it stands.

## Code and engine

- Godot Engine 4.7.2 — https://godotengine.org — MIT License.

## Font

- Nunito by Vernon Adams, Cyreal, Jacques Le Bailly, and other contributors.
- Files: `assets/fonts/Nunito-SemiBold.ttf`, `Nunito-Bold.ttf`, `Nunito-ExtraBold.ttf`.
- License: SIL Open Font License 1.1. See `assets/fonts/OFL.txt`.
- Source: [fontsource Nunito](https://fontsource.org/fonts/nunito) latin weights 600, 700, and 800.
- Lilita One by Juan Montoreano. File: `assets/fonts/LilitaOne-Regular.ttf`.
- License: SIL Open Font License 1.1, reserved font name Lilita. See `assets/fonts/OFL-LilitaOne.txt`.
- Source: [google/fonts](https://github.com/google/fonts) `ofl/lilitaone`.

## Pictures

- Critters are Kenney's [Animal Pack Redux](https://opengameart.org/content/animal-pack-redux) (CC0). `tools/apply_kenney.py` rasterizes `Vector/round.svg`, matches each animal to the named PNG, and writes `assets/sprites/critters/<id>.png`.
- Arena props are Kenney's [Background Elements Redux](https://opengameart.org/content/background-elements-redux) (CC0), stamped around a top-down ground.
- Credit to Kenney (www.kenney.nl) is appreciated and not required. Both packs are CC0 / public domain.
- `tools/build_sprites.py` still paints effects, the vignette, and older stand-in critters. Running it overwrites the Kenney critters and arenas.
- `icon.png` is drawn by `tools/make_icon.py`.

Drop a replacement PNG on the same filename and the next launch uses it. Sizes are listed in the README under "Sprite drop-in".

## Audio

- Effects and the music loop are synthesized by `tools/build_audio.py`.
- No sampled libraries and no third-party tracks.
