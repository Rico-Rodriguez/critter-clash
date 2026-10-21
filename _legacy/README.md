# Critter Clash

A portrait hero-run in Godot 4.7.2. The camp is the front door: choose the hero who walks, pick a gate, and go north through the Barrow Lands. The deeper you go, the harder the ground gets, and the guardian at the far gate of a depth has to fall before the next gate opens. Bosses drop loot. They do not become heroes.

The game is free. There are no ads, no in-app purchases, and no paid currency. A hero's role never changes because of where it stands. Roles are fixed on the hero.

This is an original game. It does not use Supercell names, interface layouts, or assets.

## Play

The game opens in the camp, Barrow Haven: your hero stands by the fire, the four standing stones of the Barrow Lands stand in a row behind, and the counter under the camp holds the stalls, the stash, the desk and today's hunt.

Pick your hero in the camp. The CHOOSE button opens the roster; the hero you pick walks out of the camp and travels from it.

Pick a gate. A gate that stands open is lit, and a tap on its standing stone walks you through it. The gate names the depth it leads into: the Fringe, the Wilds, the Deep, the Abyss. A gate that stands shut opens when the depth below it is cleared.

A hunt in a depth is a walk, not a fight in a ring. The hero comes in by the south gate of the ground and has to reach the far gate at the north, where the guardian of that depth waits. The ground between the gates holds the depth's own beasts, its own resources and its own chests, and the map in the corner charts it.

Drag anywhere on the lower part of the screen. A thumbstick appears under your finger and the hero follows it. On a desktop, WASD or the arrow keys steer the same way. The hero attacks the nearest wild critter on its own.

Wild critters walk in from the edges. Gems they drop fill a shared XP bar. Each level-up pauses the hunt and offers three upgrade cards. Cards have colored frames: common, rare, epic, and legendary. Some epic cards belong to one role only:

| Role | Exclusive cards |
| --- | --- |
| Mage | Wider splash, hotter splash |
| Archer | Pierce |
| Tank | Thorns, shield bash |

Shared cards cover health, regen, attack speed, ricochet, multishot, move speed, crit, armor, and a legendary second wind.

The guardian of a depth rises when the hero reaches the far gate. It telegraphs area circles, a charge lane, and a fan of projectiles. Dodge those. Defeat it to clear the depth and open the next gate. Losing the hero, or still walking when the clock runs out at 300 seconds, ends the hunt.

On a win the boss rolls a drop table and you still bring a hunt chest home. The clear is saved as soon as the boss falls.

Roughly one hunt in three or four holds a treasure goblin. It waits in a clearing on the main trail and darts out when you come close; if you never walk past its haunt, it still finds you a little way into the hunt, so a hunt that rolls a goblin always shows one. It never fights, it runs, and it tires as it goes, so a chase you keep is a chase you win. Catch it and its hoard is the biggest payout in the hunt: three pieces of gear, a silver chest, and a burst of coins.

## Boss drops

Each boss has a weighted table of common, uncommon, rare, and very rare loot: coins, critter cards, gear, and crafting materials. A boss pet is a separate roll at 1/50 (`Catalog.PET_RATE`). Pets are cosmetic. The active pet follows your hero in a hunt and does not fight. A pet or a very rare drop plays a gold beam and a fanfare before the loot list.

The collection log lists every drop and pet, 64 in all. Unobtained pictures are silhouettes. The header shows an obtained count such as 12/64, and each boss tab shows that boss's kill count.

## Elites and the guardians

The ground sets how often a wild critter is promoted to an elite: the Fringe never, the Wilds 5% of the time, the Deep 15% and the Abyss 30%, plus the challenge's own chance on top. An elite wears a visible aura where the ground allows them at all (`Catalog.elite_has_aura`), and its gear comes from a boosted drop table of its own (`LootTable.elite_source`: fringe, wilds, deep, abyss).

The guardian of a depth waits at the far gate and rises when the hero gets there: Gravemaw in the Fringe, Nightmaw in the Wilds, Nimbus in the Deep, Cinder in the Abyss. A depth can also hold a second, older lair beside its guardian: Boreal, the Frost Wyrm in the Deep and Inferno, the Magma Colossus in the Abyss (`Catalog.LAIRS`). A lair hoard holds no common coin: every row of a lair's drop table is rare or better, so a lair kill is a haul (`Catalog.guaranteed_drops`).

A lair only stands in ground deep enough for it (`Catalog.LAIRS` `depth_min`), so the shallows never hold one. The lair boss keeps its own seat -- it has its own bar, its own fight and its own drop table -- and its hoard is paid the moment it falls. The guardian is never replaced by it.

## Slayer

The slayer master offers tasks such as "Defeat 40 Meadow critters" or "Defeat Gravemaw". Progress counts the critters you defeat in that biome, and a boss task counts that boss. Turning a task in pays slayer points plus 5 points for each task already in the streak. Cancelling a task resets the streak. The points shop sells a rare charm, a trail ribbon for the camp, and a hunt chest.

## Skills

Woodcutting, Fishing and Mining are saved as XP for the account. Levels run from 1 to 99 on the same curve as Old School RuneScape (83 XP to reach level 2, 13,034,431 XP to reach level 99). Gathering is still being built: the depths now carry resource nodes, walking up to one works it for XP and materials, and the skills screen's Gathering tab shows the account's levels and the XP toward the next one. The materials it pays, and the boss materials, share one bag: the Skills screen has a Materials tab that lists them and sells them for a few coins each. The contract is in `docs/gathering.md`.

The bag is the sell pile, so what you want to keep has its own place: the Hub stash. The STASH button in the camp (or the one under the bag) parks a stack out of reach of the sell button, and takes it back when you want it. The contract is in `docs/stash.md`.

## Heroes

| Hero | Role | How you get them |
| --- | --- | --- |
| Barbarian, axe | Tank, melee | Starter |
| Paladin, sword and shield | Tank | Starter |
| Sorceress, fire and frost | Mage | Starter |
| Rogue, bow and traps | Archer | Starter |
| Necromancer, bone | Mage | Trophy road |
| Druid, bear and thornwood | Tank | Trophy road |

The class ids are `barbarian`, `paladin`, `sorceress`, `rogue`, `necromancer` and `druid`. The old critter ids still load: a save that owned or featured one moves to the class that replaced it (`Catalog.RETIRED_HEROES`).

Gravemaw (a corrupted barrow troll, id `thistle`), Nightmaw (a blighted rot-wolf, id `caplet`), Nimbus, and Cinder are the guardians of the four depths. They stay in the world.

## World and the road

The Barrow Lands are four depths, not one arena. The Fringe, the Wilds, the Deep and the Abyss are each a large zone with a gate at the south and a gate at the north, and the hero walks from one to the other (`docs/wilderness.md`). The Fringe's north gate is the Wilds' south gate, and the Abyss' north gate is the lair.

Each depth holds its own monsters, at levels that climb as the walk goes north, its own elites, its own resources and its own chests. Clearing a depth opens the gate into the one above it.

Every gate also carries a challenge: Normal, Veteran and Nightmare. A cleared challenge opens the next one, and a challenge scales the monsters, the loot and the skill XP. The line under a gate steps it up.

The trophy road spends the trophies a clear pays on coins, a chest, the Necromancer, the Druid, and gear.

## Between hunts

A win brings home a hunt chest. A loss brings a smaller pouch. Chests pay coins, critter cards for heroes you already own, and sometimes a piece of gear.

The chest drawer holds four chests. A chest that arrives when every slot is taken, whether it came home from a hunt or was a prize from the trophy road or the slayer shop, is never lost: it joins the chest queue instead, where it waits its turn on the rarity ladder (common 15m, rare 1h, epic 3h). The desk in the camp shows the queue under the drawer, one chip per chest with a countdown on its timer, and a queued chest whose timer is up opens through the same reveal as any other chest.

Card level works like a collection card game. Duplicates and coins raise a critter from level 1 to 10. Level 2 costs 2 cards and 15 coins, and each level asks for more. Health and damage grow by 8% per level.

Each critter has a weapon slot, an armor slot, and a charm slot. A piece can only be worn by one critter. Weapons roll damage and attack speed, armor rolls health and armor, charms roll crit, move speed, or regen.

Progress is stored on the device at `user://critter_clash.json`.

## Maps

Each ground is data: a pixel size, a chunk grid, spawn zones, and a boss arena point (`HuntMap`). A depth zone is many screens: the Fringe is 4480×2560 sim px, the Abyss 5600×5120, and both are built from the biome's own cells. The zone is a single record of the same kind as the old one-screen arena, so the fight does not assume the zone is the whole screen.

The simulation stores a follow camera for when maps grow. Inside a soft deadzone that camera stays still; past that edge it eases after the hero, and it never slides outside the map. On a one-screen map the view and the map are the same size, so that camera stays put. The picture you see is a separate 3D camera: it always frames the hero from about 55 degrees above, with the same deadzone and the same clamp, even on today's small map. The heads-up display is not parented to the world, so it does not scroll.

Only chunks that overlap the view, plus a small margin, are instanced. The 3D hunt draws one terrain mesh and a MultiMesh of grass and flowers for the whole clearing, and it keeps trees and rocks around the rim. The chunk stream is still in the project for the larger maps. A 4×4 map does not build all sixteen chunks at once.

Wild critters spawn on the rim of the zone nearest the hero, not on the edge of the screen. With one zone, that rim is the edge of the playfield.

## Wilderness

The Barrow Lands are four depth tiers — the Fringe, the Wilds, the Deep, the Abyss — and each one is a large explorable zone, not an arena. `ZoneBuilder` lays them out from `WorldData`: the ground (a gate at the south, a gate at the north, a chain of clearings between them, pockets off the side), the monster spawn points (scaled by the tier's level range, pack size and patrol density), the elite packs (the tier's elite chance, and a guaranteed few in the deep tiers), the resource nodes the tier names, the chests in the pockets, and the scenery each tier wears. The Fringe is 4480×2560 sim px and the Abyss 5600×5120, so every zone is at least four times the ground of the shipped hunt arena.

A zone is a `HuntMap`, so the hunt simulation already knows how to walk one, and the four zones stack north to south in tier order: the Fringe's north gate is the Wilds' south gate. A gate in the camp opens the zone of its depth, the hero walks in by the south gate, and the guardian at the north gate has to fall before the depth is cleared. The contract is in `docs/wilderness.md`, and `godot --headless --path . -s res://tools/zone_check.gd` checks the four zones.

## Later modes

The launch build is single-player. The hunt itself does not know about buttons or sprites. `Session` can describe a solo hunt, a co-op pair that shares a team, or a duel. `RunBot.steer` is the stand-in brain for a future rival. The save keeps an unused `clan_id`. None of those modes have a screen yet.

## World in 3D

The hunt, the camp and the hero plinth are 3D views. The fight itself is still the flat simulation, so steering, cards, and clear times are unchanged.

Desktop and the screenshot capture use Forward+. iOS export uses the Mobile renderer and Metal (`--rendering-method mobile --rendering-driver metal`). The camera sits about 55 degrees above the hero. A warm sun casts cascaded shadows (four splits on a desktop GPU, two on iOS and on software renderers). A cool rim light fills the shadow side. The sky is a Poly Haven HDRI. Tonemap is ACES, with a little bloom and height fog. SSAO and SDFGI turn on only for the high tier, which is a real desktop GPU. iPhones and lavapipe stay on the medium tier so the target stays 60fps.

The ground is one shader over a baked blend of ambientCG grass, dirt, and rock, with the height map pushed into the vertices. Grass, flowers, ferns, and clover are MultiMesh instances and do not cast shadows. Trees, bushes, and rocks around the clearing do.

The six heroes are rigged models in `assets/models/heroes_rigged/`, and each class scene in `assets/models/heroes_new/<class>/` carries the model with a baked animation library (idle, walk, run, attack, hit, death, cast, block, bash, dodge) retargeted onto it. The old critter cast (Ember the dragon, Juniper the fox, Pebble the otter, Lumen the owl, Pip the frog, Bramble the cactus-hog) stays on CC0 meshes, and the meadow boss Thistle uses a CC-BY Sketchfab model. The rim uses the Nature Vegetation Pack. The camp opens an in-game Credits list with the CC-BY title, author, URL, and license. Footstep dust and hit sparks are GPU particles.

## Run it

Godot 4.7.2. Desktop uses Forward+. iOS uses the Mobile renderer and Metal.

```
godot --path .
```

Headless check of roles, the save, and the depth hunts:

```
godot --headless --path . --import --quit
godot --headless --path . -- --sim-check
```

The first command fills the class cache. The second prints `SIM CHECK PASSED` and exits 0 when Ember, Juniper, and Pebble can clear the Meadow inside the hunt window, and a hero who never moves loses.

### iOS

Bundle id `com.rico.critterclash`, display name Critter Clash, minimum iOS 15, version 1.1.0. The export preset writes an Xcode project only (`application/export_project_only`). Team id `ABCDE12345` is a placeholder so Godot will export.

`.github/workflows/ios-ipa.yml` runs on `macos-26` for pushes to `main` and for workflow dispatch. The Godot 4.7.2 iOS template links Metal symbols from the iOS 26 SDK, so an older Xcode cannot archive it. The workflow installs Godot 4.7.2 and the export templates, imports assets headless (10 minute limit), then exports with the Mobile renderer and Metal (20 minute limit). The iOS shader baker is off, because baking the 3D materials hung the export. Shaders compile on device. The job archives with signing turned off, zips `Payload/*.app` into `CritterClash.ipa`, and publishes that file on the `ios-v1` prerelease.

### Web

There is no checked-in web build. With export templates installed:

```
godot --headless --path . --export-release "Web" web/index.html
python3 -m http.server 8941 --directory web
```

## Portraits

The world is the 3D cast in `assets/models/`. Kenney pictures remain only for interface portraits: the hunt medallion, collection cards, the collection log, and the slayer panel. `tools/build_sprites.py` overwrites those portraits with procedural stand-ins, so leave it alone.

Critter ids: `ember`, `juniper`, `pebble`, `lumen`, `pip`, `bramble`, `thistle`, `caplet`, `nimbus`, `cinder`, `sprout`, `beetle`, `moth`, `boarlet`, `capling`, `spore`, `glowmoth`, `puddle`, `snowpup`, `shard`, `icewisp`, `yeti`, `cindling`, `skink`, `ashbat`, `magmash`.

Biome ids: `meadow`, `mushroom`, `frost`, `volcano`.

Depth ids: `fringe`, `wilds`, `deep`, `abyss`.

## Project layout

- `scripts/` hunt simulation, map data, follow camera, chunk stream, 3D stage, wilderness zone builder, screens (including the collection log, slayer master, and skills stub), save, portrait loader
- `assets/models/` licensed critter and nature GLBs, and the rigged hero models with their baked animation libraries
- `assets/textures/` baked ground maps, the sky HDRI, and the dust puff
- `shaders/terrain.gdshader` ground blend
- `assets/sprites/` Kenney portraits and generated interface effects
- `assets/audio/` the licensed effects, the synthesized effects and the music loops
- `assets/fonts/` Nunito for body copy, Lilita One for titles, numbers, and buttons
- `tools/build_sfx.py`, `tools/build_sfx_synth.py`, `tools/check_sfx.py` and `tools/make_icon.py`
- `.github/workflows/ios-ipa.yml` unsigned IPA
- `.memory/` the project memory: `index.md` is the table of contents, `topics/*.md` hold the history and the open issues

## Art and audio rebuild

Sound and the icon are generated:

```
python3 tools/build_sfx.py        # the licensed packs, trimmed and layered
python3 tools/build_sfx_synth.py  # the moments the packs do not cover
python3 tools/check_sfx.py        # every clip exists, is played, and is not silent
python3 tools/make_icon.py
```

`tools/build_sfx.py` needs the source packs downloaded (see `CREDITS.md`);
`tools/build_sfx_synth.py` draws its clips from oscillators and noise, and
leaves any clip already on disk alone so a rebuild does not churn the
resource uids.

Licenses are in `CREDITS.md`.
