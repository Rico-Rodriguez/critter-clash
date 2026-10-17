# Credits

Critter Clash is an original game. The hunt, the roster, and the interface are original. The world is licensed 3D: critters, nature, ground textures, and a sky. Kenney pictures remain on the interface portraits. Nothing in the game changes a critter's role based on where it stands.

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

## 3D models

- Ember the dragon: Pixor "Small Dragon" — https://pixor.art/library/creatures/dragon-small/ — CC0. Files `assets/models/ember_*.glb`. The pack includes a fly cycle. Hit and death are posed in game.
- Juniper the fox and Pebble the otter: "Cozy Animals" by Gamideo — https://dragofive.itch.io/cozy-animals-3d — CC0. Files `juniper_*.glb` and `pebble_*.glb` (the otter). Meshes were generated in Meshy; the clips were authored by Gamideo. Idle, walk, and gesture ship in the file.
- Lumen the owl: Pixor "Owl" — https://pixor.art/library/creatures/owl/ — CC0. Files `lumen_*.glb`.
- Pip the frog and Bramble the cactus-hog, plus minions that share those rigs: Quaternius Ultimate Monsters — https://quaternius.com — CC0. Files `pip_*.glb` (Frog) and `bramble_*.glb` (Cactoro, sombrero brim pulled in). Clips include Idle, Run, Punch, HitReact, and Death.
- Thistle the meadow boss: Quaternius Ultimate Monsters "Demon" — https://quaternius.com/packs/ultimatemonsters.html — CC0. File `assets/models/thistle_boss.gltf`. Same clip set, including a trident.
- Sketchfab replacements, when a file is present, win over the CC0 mesh. Only CC0 and CC-BY belong in this folder. Record the artist, URL, and license here before shipping one. Expected names: `assets/models/sketchfab/ember.glb` (Stylized Dragon), `juniper.glb` (KAI or GIGI fox), `thistle.glb` (Mushroom Boss), and vegetation pieces in `assets/models/sketchfab/nature/`. Nothing from Sketchfab is in the build until those files are added.
- Trees, rocks, grass, flowers, mushrooms, and the pedestal stones: Quaternius Stylized Nature MegaKit — https://quaternius.com/packs/stylizednature.html — CC0.

## Textures and sky

- Ground color, normal, and roughness are ambientCG Grass004, Ground037, and Rock051 — https://ambientcg.com — CC0. The hunt shader splats `assets/textures/grass_*.jpg`, `dirt_*.jpg`, and `rock_*.jpg`.
- Sky: Poly Haven `kloofendal_48d_partly_cloudy_puresky` (1k) — https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky — CC0. File `assets/textures/sky.hdr`.
- `assets/textures/dust.png` is drawn for this game.

## Interface pictures

- The hunt medallion is a live render of the hero's 3D model. Collection cards, the collection log, and the slayer panel still use Kenney's [Animal Pack Redux](https://opengameart.org/content/animal-pack-redux) (CC0).
- Credit to Kenney (www.kenney.nl) is appreciated and not required.
- `icon.png` is drawn by `tools/make_icon.py`.

## Audio

- Effects and the music loop are synthesized by `tools/build_audio.py`.
- No sampled libraries and no third-party tracks.
