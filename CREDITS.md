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

- Ember the dragon: "Stylized Dragon" by Stan (Stas_SayHallo) — https://sketchfab.com/3d-models/stylized-dragon-97d00c182fa24fa4838493c41ad8e52c — CC-BY 4.0. File `assets/models/sketchfab/ember.glb`. Clips are wing flaps and a head turn. The CC0 fallback is Pixor's "Small Dragon" — https://pixor.art/library/creatures/dragon-small/ — files `assets/models/ember_*.glb`, used for lava and water variants.
- Juniper the fox: "KAI" — The Little Fox Warrior (Animated) by Realidad Aumentada Empezando Desde Cero — https://sketchfab.com/3d-models/kai-the-little-fox-warrior-animated-aa56e447b578470b8d6b1b9587fd29ac — CC-BY 4.0. File `assets/models/sketchfab/juniper.glb`. Idle, Run, and Punch. The CC0 fallback is Gamideo's fox in `juniper_*.glb`.
- Pebble the otter: "Cozy Animals" by Gamideo — https://dragofive.itch.io/cozy-animals-3d — CC0. File `pebble_*.glb`. No CC0 or CC-BY rigged otter on Sketchfab was a real otter with a walk cycle, so this mesh stays. It is tinted teal-brown in game.
- Lumen the owl: Pixor "Owl" — https://pixor.art/library/creatures/owl/ — CC0. Files `lumen_*.glb`. Searches did not turn up a rigged CC0 or CC-BY owl that was actually an owl.
- Pip the frog and Bramble the cactus-hog, plus minions that share those rigs: Quaternius Ultimate Monsters — https://quaternius.com — CC0. Files `pip_*.glb` (Frog) and `bramble_*.glb` (Cactoro). Clips include Idle, Run, Punch, HitReact, and Death. No rigged CC0 or CC-BY frog or hedgehog cleared the license and character checks.
- Thistle the meadow boss: "Mushroom Boss - game ready with animations" by iamjohnhult — https://sketchfab.com/3d-models/mushroom-boss-game-ready-with-animations-ee611e4925e94a98baa4cfd3d89d3449 — CC-BY 4.0. File `assets/models/sketchfab/thistle.glb`. Idle, Walk, Attack, and Die. The CC0 fallback is Quaternius "Demon" in `assets/models/thistle_boss.gltf`.
- Meadow trees, bushes, and rocks: "Nature Vegetation Pack" by AnderArts — https://sketchfab.com/3d-models/nature-vegetation-pack-c257b444645542da867fce0cf221e52d — CC-BY 4.0. File `assets/models/sketchfab/nature/grove.glb`. The shipped file keeps one LOD0 of each tree, bush, and rock. The astronaut, ground plane, cliffs, and extra LODs are not included.
- Grass, flowers, mushrooms, pedestal stones, and the trees outside the meadow: Quaternius Stylized Nature MegaKit — https://quaternius.com/packs/stylizednature.html — CC0.

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
