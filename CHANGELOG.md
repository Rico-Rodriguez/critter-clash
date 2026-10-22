# Changelog

Patch notes for Barrowfall, newest first. Each entry lists the commits that
shipped it. What comes next is in [docs/PLAN.md](docs/PLAN.md), under
**Next up**.

Version in `project.godot` is still 2.0.0. `NATIVE_VERSION` is still 2 (no
autoloads, input map or project settings changed since the last IPA). Save
version is 3.

---

## 2026-10-22: A cleaner camp (UI pass, part 1)

On branch `claude/game-codebase-review-m1uchq`, not yet on `main`.

### Changed
- **Camp screen:** the three choice rows (mode, location, difficulty) are now
  one expedition card above the Play button. Tap it to open the Expedition
  sheet, where each choice says what it means (for example "Foes ×2.6 health,
  ×2.1 damage · loot ×1.6 · Gold Chest") or how to unlock it.
- **Bounties** moved from the tab bar to a button under the top bar, with a red
  badge counting rewards to claim and a "Bounties 1 / 3" line.
- Tab bar: Heroes, Gear (was Bag), Skills, Log.
- "Something new" markers are red round badges instead of green squares.

### Fixed
- On iPhones with a notch, the kill-streak counter covered the pause button
  and the clock.

### Docs
- `docs/review-ux-and-depth.md`: a review of every screen, and a proposal for
  more depth (talent trees, OSRS-style Prayer, Slayer and Smithing, Endless
  Descent and Boss Rush modes, a renown road). Tasks are Phases 9 and 10 in
  `docs/PLAN.md`.

---

## 2026-10-22: The Long Road, class powers, gear v2

Commits on `main`: `2d2254b`, `f6bd479`, `565f234`, `c5ae099`.

### Added

**The Long Road (second mode)**
- Mode picker in camp: **Horde Hunt** or **The Long Road**. The choice is
  saved (`Game.data["mode"]`, default `horde`).
- A seed builds a new dungeon every run. Rooms: 5 on Normal, 6 on Veteran,
  7 on Nightmare, then a boss hall. The boss is the zone's boss (Gravemaw in
  the Barrow, the Hexer Queen in the Sunken Crypt).
- Room kinds: ambush, horde, hunters (crossbows and staves), brutes, elite (a
  champion with an escort), shrine (hearts and a quiet breather), treasure (a
  gold chest guarded by a few foes). Kinds are weighted by depth: early rooms
  favour ambushes and hunters, later rooms favour elites, brutes and hordes.
- Gates: each divider has a gap. A glowing barrier fills the gap when you walk
  in and opens when the room is clear. The boss gate seals behind you.
- Room progress shows in the top bar ("Room 2 / 6"). A banner announces each
  room. The soul meter is replaced by room progress.
- Clearing a room drops gold, hearts and gear. Elite and brute rooms drop a
  better piece. Treasure rooms hold a chest. Shrines are placed in quiet rooms
  and the start.
- Far-behind foes despawn so the dungeon stays readable.
- The Long Road gets +1 loot tier over the zone's base.
- Bot support: `--bot --mode=trial`. Results record `mode` and
  `rooms_cleared`.

**Class powers (each one belongs to one hero, and only that hero sees it)**
- Knight: **Holy Smite** (lightning falls on the nearest foes; evolution
  **Wrath of Heaven** adds three more strikes and a stun). Knight super
  **Judgement** now calls lightning around the landing.
- Barbarian: **Earthshaker** (ground bursts outward, knockback, stun) and
  **Thrown Axes** (spinning axe projectiles). Evolution **Faultline** doubles
  the width. Barbarian's orbiting blades are axes.
- Mage: **Frost Ring** (ice ring that freezes nearby foes) and **Meteor
  Shower** (meteors on the densest crowd). Evolution **Armageddon** doubles the
  meteors. Mage super is now **Meteor Storm** (replaces Frost Nova).
- Ranger: **Arrow Storm** (a hail of arrows on the thickest cluster),
  **Explosive Arrows** (every Nth volley fires a fire arrow). Evolution
  **Deluge** drops a second wave. Ranger's super volley also rains arrows.
- Evolution cards are restricted to their hero class.

**Visual effects**
- `Fx.sky_bolt`: a lightning column that flashes on impact, with a ring and
  sparks.
- `Fx.fall`: falling meteors (with fire trails) and arrows, used by the
  meteor, arrow and super effects.
- Axe projectile (spins in flight).

**Enemies and bosses**
- **Grave Hound**: charges along a telegraphed lane and lunges at you.
- **Bone Brute**: a heavy skeleton with a telegraphed slam and shockwave. It
  does not flinch when hit.
- Foes now lead their target when they chase, and packs fan out so they
  surround instead of queueing.
- Bosses call a court of the dead: after 10 seconds of fighting, then every
  20 seconds (16 on Veteran, 12 on Nightmare). Court size grows with tier.
- Boss berserk comes earlier on harder tiers: after 150 s on Normal, 110 s on
  Veteran, 70 s on Nightmare.

**Gear v2 (class-specific gear)**
- Every piece belongs to one hero class and one material tier. Seven
  tiers: Bronze, Iron, Steel, Mithril, Adamant, Rune, Dragon (metal classes),
  Leather through Black Dragonhide (Ranger), Novice through Eldritch (Mage).
- Gear is built from KayKit parts: a Knight can wear the Mage's hat, a
  Barbarian can wear a Ranger's tunic. Parts are dyed with the material colour
  (`dye` instance uniform in `char.gdshader`).
- A hero with nothing on is a plain man in a tunic with a starter weapon.
- Weapons change shape with the tier (e.g. Knight: Shortsword, Longsword,
  Greatsword).
- Skill requirements gate each tier: Defence for armour and Attack for melee
  weapons (Knight and Barbarian), Magic for mage gear, Ranged for ranger
  gear.
- Drops favour the hero you're playing (65%). Harder content drops better
  material. Uniques have their own class and colour.
- The equipment screen shows a "Needs Magic 20" line on pieces you can't wear
  yet and a lock icon on the tile.
- Save version 3. Old v2 items migrate to the hero wearing them, or to a class
  by item id. Old uniques become class gear.

**Equipment screen (rebuilt)**
- Big 3D hero in the middle. Drag to turn.
- Five slots either side. Tap a slot or a bag piece to try it on: the model
  changes immediately and Equip makes it stick.
- Bag shows this hero's gear first. An "Others" tab shows other heroes' gear.
- Equip best, sell junk and the item detail strip are kept.

**Camp and menus**
- Mode picker row above the zone picker.
- Hunt button text follows the mode ("Take the Long Road").
- Menu sheets keep their content clear of the home bar.

**Capture and tests**
- `--notch` capture flag: simulates iPhone inset padding for screenshots.
- Capture shots: `parts`, `weapons`, `dress` (class lineup), `powers`
  (each hero's power cards on screen).
- `--test` adds gear checks (parts exist, class lock, skill lock, migration,
  material rolls), mode save and validation, tier scaling, and card icons.
- CI and `check.sh` run the Long Road autopilot for Knight and Mage.

### Changed

- Difficulty tiers (scaling is applied to enemy health, damage, speed and
  spawn pressure):
  - Normal: unchanged (1.0 everywhere).
  - Veteran: health 2.6x (was 2.1x), damage 2.1x (was 1.6x), speed 1.08x,
    pressure 1.25x.
  - Nightmare: health 6.5x (was 4.2x), damage 4.6x (was 2.4x), speed 1.17x,
    pressure 1.5x.
- Hunts spawn more foes on harder tiers. Packs sometimes appear ahead of a
  running hero (Veteran and above, or past 35% progress).
- Level-up cards: classes only see their own cards. Storm Call and Fire Nova
  are Mage-only. Orbiting Blades and Thorns are Melee-only. Evolutions obey the
  same rule.
- Starting uniques now grant different cards:
  - Crown of the Barrow King: starts with Holy Smite (was Storm Call).
  - Gown of Thorns: starts with Frost Ring (was Thorns).
- Knight super description updated (Judgement calls lightning).
- Save version 2 → 3 (see Gear v2).
- Bot: waypoint navigation on the Long Road; ignores pickups behind walls; no
  pull toward the arena centre on the Long Road.

### Fixed

- Equipment screen cut off at the top on iPhone. The safe area was read from a
  node not yet in the tree. `Ui.apply_safe_area` now reads the scene root.
- Gear did not show on the model. Parts now swap and dye per item.
- Level-up cards loading slowly the first time. The cards are now drawn once
  behind the start-of-hunt curtain, so the first real level-up doesn't compile
  shaders. Mitigated. Needs a check on device.
- Long Road autopilot stalls: it walked into walls to reach pickups, and it
  parked at the arena edge. Both fixed (`565f234`, `c5ae099`).
- Gate barrier looked like a solid wall. Now a soft gradient at 55%.
- Heavy foes (Brutes) no longer flinch on each hit.

### Removed

- `_legacy/` (the previous project, about 648 MB). The four audio build
  scripts moved to `tools/audio/`. Credits point there now.
- Frost Nova super (replaced by Meteor Storm).

---

## 2.0.0: Barrowfall rebuild and phases 1–6

Earlier entries, in order of shipping. Commit hashes are on `main`.

### Phase 6: housekeeping
- `--test` rule checks (`fce9d9d`).
- Render budget warnings: a shot over 700 draw calls or 400k triangles
  prints `BUDGET WARNING`.
- Ranger autopilot tuned; Sunken Crypt bot added to CI.
- `_legacy/` removed (`421b3c5`).

### Phase 5: second zone
- Zones as data. Barrow and Sunken Crypt share the hunt code (`4087ca3`).
- **The Sunken Crypt**: an indoor dungeon built from KayKit dungeon tiles,
  with a ritual floor and torchlit halls. Unlocks after clearing Veteran in the
  Barrow.
- **The Hexer Queen**: the Crypt's boss. Orb rings, summoning circles, a
  blink, and a cursed lane that slows you.
- Zone picker in camp.
- Crypt-only uniques and drops.

### Phase 4: progression
- Real hero portraits rendered from the 3D models, in the roster and the HUD
  medal (`47543e7`).
- Daily bounties: three per day from a pool of seven. Bounties are seeded from
  the date, so every player gets the same set that day. Claim from the nav
  button in camp.
- Results screen counts up gold, kills and skill XP. Tap to skip.
- Level-up reroll: one per hunt (two on Nightmare).

### Phase 3: depth
- **Grave Robber**: a thief who flees with loot. Catch him before he escapes.
- **Shrines**: three shrines, each giving a timed buff.
- **Card evolutions**: Bladestorm, Tempest, Inferno Heart, Rain of Arrows,
  Judgement Day.
- Visible elite affixes: Warded bubble, Molten fire patches, Swift dust trail.
- New enemies: Pumpkin Bomber (runs in and detonates, hurting other foes),
  Grave Caller (summons minions).
- Surges: "The graves open!" spawns a ring of foes, then a breather
  (`0024550`).

### Phase 2: feel
- Haptics (Vibration toggle in settings).
- Shader warm-up on first use.
- Target ring and stagger on light hits.
- Merged damage numbers.
- Massacre streaks.
- Audio buses (Music and SFX) and ducking when menus open.
- Boss berserk after a long fight (`900ec0c`).

### Gear (G.1–G.4)
- Five gear slots: weapon, helm, chest, legs, trinket.
- Visible gear on heroes.
- Equipment screen with upgrade markers (`d2a99ae`).

### Art
- A.1: KayKit grit pass. Smaller heads, darker palette, dirt in the character
  shader (`94856ef`).
- Art research recorded in [docs/art-options.md](docs/art-options.md).

### Controls and layout
- Action buttons move to the thumb corner. "Buttons" setting: Right or Left.
- Banners moved under the HUD (`1616732`).

### Phase 1: camera
- 1.1: camera rig with pitch, distance, anchor and lookahead (`a5714e3`).
- 1.2: dynamic framing for boss, crowds and victory (`59d4818`).
- 1.3: props fade when they hide the hero or the boss (`aaa66e3`).
- 1.4: camera distance setting: Close, Standard, Wide (`8c05772`).
- 1.5: hidden camera tuning panel: tap the info line five times in pause
  (`67b554d`).
- 1.6: camp camera drift and push-in on hero switch (`599c345`).

### Initial rebuild
- Barrowfall rebuilt on KayKit art with the new hunt loop, camp, skills, collection
  log and save (`557388c`).
- Screenshots, compile check mode, CI checks (`40f7cab`).
- Next-work plan, CLAUDE.md and dev scripts (`8806999`).
