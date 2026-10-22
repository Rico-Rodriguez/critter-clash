# Gravelight

*Formerly Barrowfall. The repo is still called critter-clash, and the bundle id
(`com.rico.critterclash`) and save file (`barrowfall_save.json`) keep their old
names so installed copies carry on. The name lives in `project.godot`
(`config/name`).*

A portrait, one-thumb action game for phones, built in Godot 4.7.2.

- **Feel (Diablo):** dark world, the hero carries the light, every kill crunches,
  loot drops in pillars of colored light, and champions have names.
- **Soul (Old School RuneScape):** skills from 1 to 99 on the real OSRS XP curve,
  a combat level, the parchment level-up
  scroll, and a collection log with 1/n drop rates and a boss pet.
- **Play (Brawl Stars / Hunt Royale / Clash Royale):** 2–3 minute hunts, a floating
  stick, auto-attack, a dash, a charged Super, level-up cards mid-run, and a chest
  to open back at camp.

| Camp | Hunt | Level-up | Boss |
| --- | --- | --- | --- |
| ![](docs/screens/lobby.jpg) | ![](docs/screens/hunt.jpg) | ![](docs/screens/levelup.jpg) | ![](docs/screens/boss.jpg) |

| Victory | Heroes | Skills | Collection log |
| --- | --- | --- | --- |
| ![](docs/screens/victory.jpg) | ![](docs/screens/heroes.jpg) | ![](docs/screens/skills.jpg) | ![](docs/screens/log.jpg) |

## The loop

1. **Camp.** Your hero stands by the fire. Pick a hero, a place (the Barrow, or the
   **Sunken Crypt** once you clear Veteran, the **Hollow Grove** after Expert),
   a difficulty (eight steps from Normal to Abyss; each clear opens the next, and
   the card shows the power it expects) and a mode (the Horde Hunt, or the **Long
   Road**, a new dungeon every run, room by room to the boss) and go. Three **daily bounties** and the
   equipment screen live here too.
2. **The rise.** The dead climb out of the graves around you. Every kill fills the
   **soul meter** and drops souls (XP) and sometimes gold. Each level-up pauses the
   hunt and offers **three cards** (more damage, orbiting blades, chain lightning,
   fire nova, split shot, a revive…). At about 30%, 60% and 85% a **champion** rises
   with a name and affixes (Vampiric, Swift, Molten, Warded) and drops real loot.
3. **The King.** When the meter is full, every skeleton crumbles and **Gravemaw, the
   Barrow King** bursts out of the crypt. Every attack he has is drawn on the
   ground first (cleave cone, quake circle, charge lane, grave eruptions) or comes
   as a spear volley you can walk out of. At half health he enrages.
   In the Sunken Crypt the boss is the **Hexer Queen**: rings of orbs, summoning
   circles, a blink, and a cursed lane that slows you.
4. **The hoard.** Gold fountains out, items fall in rarity-colored pillars, and the
   boss rolls his collection-log table (legendaries, the Bonelet pet at 1/50).
5. **Back at camp.** Open the chest (gold, hero shards, gear), upgrade heroes with
   shards and gold, equip gear, and watch your skills climb.

Dying keeps what you picked up but loses the chest.

## Controls

- **Move:** drag anywhere on the screen. On desktop: WASD or the arrow keys.
- **Attack:** automatic, at the nearest foe. You keep attacking while you run.
- **Dash** (bottom right): a quick roll that ignores damage. Space on desktop.
- **Super** (above the dash): charges as you deal damage. E on desktop.
  - Knight — *Judgement*: leap and slam, stunning everything nearby.
  - Ranger — *Hail of Arrows*: a wide fan of piercing arrows.
  - Mage — *Meteor Storm*: a barrage of meteors on the horde.
  - Barbarian — *Whirlwind*: spin through the crowd for three seconds.

## Heroes

| Hero | Style | Unlock |
| --- | --- | --- |
| Knight | sword and shield, wide swings, tanky | start |
| Ranger | double-shot bow, arrows pierce | start |
| Mage | fireballs that burst | start |
| Barbarian | huge two-handed swings | clear Veteran, or 20 shards |

Hero levels 1–10 cost shards (from chests) and gold; each level adds 9% health and
damage. Gear (weapon, armor, trinket) rolls Diablo-style affixes; legendaries start
every hunt holding a card (for example, Gravemaw's Cleaver: Orbiting Blades).

## Skills (Old School rules)

Attack, Strength, Defence, Hitpoints, Ranged and Magic, 1–99, with the RuneScape XP
table (83 XP for level 2, 13,034,431 for 99). Damage you deal trains them: melee
heroes train Attack/Strength/Defence, the Ranger trains Ranged, the Mage trains
Magic, and Hitpoints always trains. Every level gives a small, permanent edge. The
combat level uses the OSRS formula.

## Run it

```
godot --path .                     # play (desktop window is phone-shaped)
godot --headless --path . --import # first run: import assets
```

### Checks (no screen needed)

```
# Autopilot hunts: prints one line per hunt, exits 0 when they behave.
godot --headless --path . --fixed-fps 60 -- --bot --hero=knight,ranger,mage,barbarian --runs=2
# An idle hero must lose (proves the Barrow can kill you).
godot --headless --path . --fixed-fps 60 -- --bot --hero=knight --idle
# Compile every script, scene and shader.
godot --headless --path . -- --check
```

### Screenshots

```
godot --path . --resolution 720x1280 --fixed-fps 30 -- --capture \
  --shots=lobby,hunt,levelup,boss,victory,results,death,heroes,skills,log,bag,chest,film \
  --out=/absolute/dir
```

Each shot also prints draw calls, objects and triangles. A full hunt frame is
about 450 draw calls and 225k triangles.

## Where things live

```
src/
  main.gd / main.tscn     app shell: camp <-> hunt, bot and capture modes
  autoload/
    game.gd               the save, hero stats, loot rolls, chests, hunt rewards
    sfx.gd                sound events (with variants) and music crossfades
    ota_boot.gd           over-the-air content updates (see below)
  data/db.gd              ALL tuning: heroes, enemies, boss, cards, items,
                          drop rates, tiers, skills — balance the game here
  hunt/                   the hunt: hunt.gd (rules, director, damage, loot),
                          hero.gd, enemy.gd, boss.gd, proj.gd, pickup.gd,
                          arena.gd (the graveyard), fx.gd (pooled effects),
                          cam.gd, bot.gd (autopilot for checks)
  lobby/                  the camp: 3D scene, UI, sheets, chest opening
  ui/                     HUD, level-up, pause, results, theme.tres, widgets
  fx/                     shaders: characters, ground, slashes, rings,
                          telegraphs, loot beams, particles
assets/
  kaykit/                 KayKit models and animations (CC0)
  icons/                  game-icons.net SVGs (CC BY 3.0)
  audio/, fonts/
tools/
  bake_anims.gd           rebuild the shared animation library
  build_theme.gd          rebuild src/ui/theme.tres (all colors, fonts, buttons)
  preview.gd              cast preview render
```

**UI** is built from real scenes (`.tscn`) styled by one Theme. To restyle the
whole game, edit the tokens at the top of `tools/build_theme.gd` and run it, or
open `src/ui/theme.tres` in the editor.

**Adding art:** stay inside the KayKit family (same rig, same palette). Any
`Rig_Medium` character works with the existing animation library. Props are
`.gltf` files placed by `src/hunt/arena.gd` and `src/lobby/lobby.gd`.

## iOS build and over-the-air updates

`.github/workflows/ios-ipa.yml` runs on pushes to `main`: it imports, exports the
Xcode project with the Mobile renderer and Metal, builds an unsigned IPA (bundle
id `com.rico.critterclash`), and publishes it on the `ios-v1` prerelease. It also
publishes the exported `.pck` on the `ota` release, which installed copies
download on launch (`src/autoload/ota_boot.gd`, details in
`docs/ota.md`).

This rebuild changed the autoloads, so `NATIVE_VERSION` went to 2: **phones need
the new IPA once.** Older installs ignore the new content packs instead of
loading something they can't run.
