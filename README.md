# Critter Clash

A portrait hero-run in Godot 4.7.2. Pick one critter, steer it through a biome, and defeat the boss. Bosses drop loot. They do not become heroes.

The game is free. There are no ads, no in-app purchases, and no paid currency. A critter's role never changes because of where it stands. Roles are fixed on the critter.

This is an original game. It does not use Supercell names, interface layouts, or assets.

## Play

From home, open a biome and pick one unlocked hero. A hunt is one hero in a portrait arena and lasts under two minutes.

Drag anywhere on the lower part of the screen. A thumbstick appears under your finger and the hero follows it. On a desktop, WASD or the arrow keys steer the same way. The hero attacks the nearest wild critter on its own.

Wild critters walk in from the edges. Gems they drop fill a shared XP bar. Each level-up pauses the hunt and offers three upgrade cards. Cards have colored frames: common, rare, epic, and legendary. Some epic cards belong to one role only:

| Role | Exclusive cards |
| --- | --- |
| Mage | Wider splash, hotter splash |
| Archer | Pierce |
| Tank | Thorns, shield bash |

Shared cards cover health, regen, attack speed, ricochet, multishot, move speed, crit, armor, and a legendary second wind.

Around 68 seconds the minions leave and the biome boss arrives. It telegraphs area circles, a charge lane, and a fan of projectiles. Dodge those. Defeat the boss to win. Losing the hero, or still fighting at 119 seconds, ends the hunt.

On a win the boss rolls a drop table and you still bring a hunt chest home. The clear is saved as soon as the boss falls.

## Boss drops

Each boss has a weighted table of common, uncommon, rare, and very rare loot: coins, critter cards, gear, and crafting materials. A boss pet is a separate roll at 1/50 (`Catalog.PET_RATE`). Pets are cosmetic. The active pet follows your hero in a hunt and does not fight. A pet or a very rare drop plays a gold beam and a fanfare before the loot list.

The collection log lists every drop and pet, 48 in all. Unobtained pictures are silhouettes. The header shows an obtained count such as 12/48, and each boss tab shows that boss's kill count.

## Slayer

The slayer master offers tasks such as "Defeat 40 Meadow critters" or "Defeat Thistle". Progress counts the critters you defeat in that biome, and a boss task counts that boss. Turning a task in pays slayer points plus 5 points for each task already in the streak. Cancelling a task resets the streak. The points shop sells a rare charm, a trail ribbon for the home pedestal, and a hunt chest.

## Skills

Foraging, Fishing, Taming, and Crafting are saved as XP. Levels run from 1 to 99 on the same curve as Old School RuneScape (83 XP to reach level 2, 13,034,431 XP to reach level 99). The skills screen only shows the level and the next XP total. There is no gathering yet.

## Heroes

| Critter | Role | How you get them |
| --- | --- | --- |
| Ember, dragon | Mage, fire splash | Starter |
| Juniper, fox | Archer | Starter |
| Pebble, otter | Tank, melee | Starter |
| Lumen, owl | Archer | Trophy road |
| Pip, frog | Mage | Trophy road |
| Bramble, hedgehog | Tank | Trophy road |

Thistle, Caplet, Nimbus, and Cinder are bosses. They stay in the world.

## World and the road

Biomes open in order. Meadow is open from the start. Mushroom Forest needs a Meadow clear and 30 trophies. Frost Peaks needs Mushroom Forest and 80. Ember Volcano needs Frost Peaks and 150. The first clear of a biome is worth 30 trophies. A repeat clear is worth 16.

The trophy road spends those trophies on coins, a chest, Lumen, Pip, Bramble, and gear.

## Between hunts

A win brings home a hunt chest. A loss brings a smaller pouch. Chests pay coins, critter cards for heroes you already own, and sometimes a piece of gear.

Card level works like a collection card game. Duplicates and coins raise a critter from level 1 to 10. Level 2 costs 2 cards and 15 coins, and each level asks for more. Health and damage grow by 8% per level.

Each critter has a weapon slot, an armor slot, and a charm slot. A piece can only be worn by one critter. Weapons roll damage and attack speed, armor rolls health and armor, charms roll crit, move speed, or regen.

Progress is stored on the device at `user://critter_clash.json`.

## Later modes

The launch build is single-player. The hunt itself does not know about buttons or sprites. `Session` can describe a solo hunt, a co-op pair that shares a team, or a duel. `RunBot.steer` is the stand-in brain for a future rival. The save keeps an unused `clan_id`. None of those modes have a screen yet.

## Run it

Godot 4.7.2. The desktop and web renderer is GL Compatibility. iOS uses the Mobile renderer and Metal.

```
godot --path .
```

Headless check of roles, the save, and three Meadow hunts:

```
godot --headless --path . --import --quit
godot --headless --path . -- --sim-check
```

The first command fills the class cache. The second prints `SIM CHECK PASSED` and exits 0 when Ember, Juniper, and Pebble can clear the Meadow inside the hunt window, and a hero who never moves loses.

### iOS

Bundle id `com.rico.critterclash`, display name Critter Clash, minimum iOS 15, version 1.1.0. The export preset writes an Xcode project only (`application/export_project_only`). Team id `ABCDE12345` is a placeholder so Godot will export.

`.github/workflows/ios-ipa.yml` runs on `macos-26` for pushes to `main` and for workflow dispatch. The Godot 4.7.2 iOS template links Metal symbols from the iOS 26 SDK, so an older Xcode cannot archive it. The workflow installs Godot 4.7.2 and the export templates, exports with the Mobile renderer and Metal so the shader baker can run, archives with signing turned off, zips `Payload/*.app` into `CritterClash.ipa`, and publishes that file on the `ios-v1` prerelease.

### Web

There is no checked-in web build. With export templates installed:

```
godot --headless --path . --export-release "Web" web/index.html
python3 -m http.server 8941 --directory web
```

## Sprite drop-in

Critters and arenas ship from Kenney's CC0 packs. `tools/apply_kenney.py` fills the filenames below. Replace a PNG and the next launch uses it. `SpriteBank` falls back to a flat circle if a file is missing, so a new id still runs.

Rebuild the Kenney set (needs `rsvg-convert`, Pillow, and numpy):

```
python3 tools/apply_kenney.py
```

`tools/build_sprites.py` paints the effects and the vignette. It also overwrites critters and arenas with procedural stand-ins, so run it only when you want those stand-ins back.

| File | Size | Notes |
| --- | --- | --- |
| `assets/sprites/critters/<id>.png` | 1024×1024 | Transparent. Kenney round animal, feet near the lower third, dark outline. Side view; the hunt flips them to face the way they move. |
| `assets/sprites/arenas/<biome>.png` | 1440×2560 | Opaque portrait backdrop, 2× the 720×1280 playfield. Kenney trees and bushes around a clear center. |
| `assets/sprites/fx/gem.png` | 128×128 | XP gem. |
| `assets/sprites/fx/orb.png` | 128×128 | Mage and enemy projectile. |
| `assets/sprites/fx/arrow.png` | 128×128 | Archer shot, pointing right. |
| `assets/sprites/fx/heart.png` | 128×128 | Taming heart. |
| `assets/sprites/fx/shadow.png` | 256×128 | Soft ellipse under a critter. |
| `assets/sprites/ui/vignette.png` | 720×1280 | Soft edge darkening, mostly transparent. |

Critter ids: `ember`, `juniper`, `pebble`, `lumen`, `pip`, `bramble`, `thistle`, `caplet`, `nimbus`, `cinder`, `sprout`, `beetle`, `moth`, `boarlet`, `capling`, `spore`, `glowmoth`, `puddle`, `snowpup`, `shard`, `icewisp`, `yeti`, `cindling`, `skink`, `ashbat`, `magmash`.

Biome ids: `meadow`, `mushroom`, `frost`, `volcano`.

## Project layout

- `scripts/` hunt simulation, screens (including the collection log, slayer master, and skills stub), save, sprite loader
- `assets/sprites/` Kenney critters and arenas, plus generated effects
- `assets/audio/` synthesized effects and the music loop
- `assets/fonts/` Nunito for body copy, Lilita One for titles, numbers, and buttons
- `tools/apply_kenney.py` CC0 critter and arena composer
- `tools/build_sprites.py` effects, vignette, and procedural stand-ins
- `tools/build_audio.py` and `tools/make_icon.py`
- `.github/workflows/ios-ipa.yml` unsigned IPA

## Art and audio rebuild

Sound and the icon are generated:

```
python3 tools/build_audio.py
python3 tools/make_icon.py
```

Licenses are in `CREDITS.md`.
