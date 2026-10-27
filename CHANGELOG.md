# Changelog

Patch notes for Gravelight (formerly Barrowfall), newest first. Each entry lists the commits that
shipped it. What comes next is in [docs/PLAN.md](docs/PLAN.md), under
**Next up**.

Version in `project.godot` is still 2.0.0. `NATIVE_VERSION` is 3 (the boot
splash settings changed: reinstall the IPA). Save
version is 7.

---

## Unreleased: Biome rebuild, ambient life and audio

- Rimehollow and the Cinder Mire now have their own ambience (`src/hunt/ambience.gd`):
  snow hares, owls on ice crystals, a watching wolf and visible foe breath in the
  cold; frogs, dragonflies, crows on stumps, methane bubbles that pop into small blue
  flames and fish rings in the bog. All flat-coloured primitives, no particles,
  harmless, capped (two on Low quality) and gone when the hero comes near.
- Each zone has a looping sound bed (ducked under loud fights) and spatial one-shots:
  wind, ice creaks and drips; swamp air, frogs, a crow, bubbles and ember pops.
  CC0 recordings from OpenGameArt, credited in CREDITS.md and the in-game credits;
  the creaks and drips are synthesized. `tools/audio/build_ambience.py` builds them.
- `src/ambience_tests.gd`: assets and credits, caps, flee behaviour, ducking.

## Unreleased: Biome rebuild, foe AI

- Sixteen new foes (Rimehollow and Cinder Mire) with their own behaviours:
  wolf packs that lunge one at a time, a yeti, a dormant effigy, wail wraith and
  cinder imp kiting, seer, caller, shaman and hag casters, shardling, sporecap
  and bloat drifters, an ambushing bogfin and bog frog, and the ember wasp. Each
  shows a ground telegraph before it can hurt and plays idle, run, attack, hit
  and death clips. They run as brain objects (`src/hunt/foe_*.gd`, defs in
  `src/data/next_foes.gd`), so the zones still field today's foes until
  `FoeBrains.next` is turned on; `-- --bot --next-foes` plays them now.
- `src/brain_tests.gd` drives a real Hunt with a terrain grid and checks the
  telegraphs, pack rules, ambush, fire and ice interplay. check.sh also runs the
  Frozen Crypt and Burning Swamp hunts with `--next-foes`.

## Unreleased: Biome rebuild, terrain engine

The Cinder Mire boss is now the **Cinder Warlord**: Riltariki's orc (CC BY, see
`CREDITS.md`), 5.7 m tall at scale 3.0 with its own
clips. `DB.BOSSES["cinder"]` names its rig (`"rig": "cinder_warlord"`) and
`DB.boss_def` folds in the fit, clips and alias from `boss_models.gd`. Hitbox
radius is 1.95 and the occluder 2.1 x 6.0 for the taller body. Story cutscenes
pass the rig to the boss actor so the Warlord shows there too.

Rebuild 2/3. No visible change yet: no zone paints terrain until the Rimehollow
and Cinder Mire layouts land.

- The Arena owns a terrain grid (`arena.terrain`, all dry) and `terrain_begin()`
  turns it on for a zone: one ground plane (`terrain_ground.gdshader`) draws
  ice, thin ice, open water, bog, fire and ash cells from two small textures,
  with hard noisy edges and a real specular on ice and water.
- `terrain_run.gd` steps the grid each tick: thin ice snaps, foes that stop on it
  or fall in water drown, fire spreads and burns bog foes, the hero is chilled
  and dragged out of open water, and every body gets its ground's speed, grip
  and knockback slide (`t_speed`, `t_grip`, `t_slide` on `Actor`).
- Ice walls (`add_ice_wall`) are solid to everything and break to a dash or any
  big blow; the flow field routes round water and walls.

## Unreleased: Biome rebuild, test harness

- `src/hunt/terrain.gd`: the terrain cell grid's rules as plain data (nine kinds,
  surface grip and speed, thin ice that snaps after 1.2 s, fire that spreads
  across bog and planks in 1.5 s telegraphed steps, ash that re-floods after
  25 s). Nothing uses it yet; the Arena hooks it in (see
  `biome-rebuild-plan.md`, "Dev hooks").
- `src/terrain_tests.gd` and `src/foe_tests.gd` run inside `-- --test`: surface
  physics, drowning, fire spread and re-flood, and every foe def's six
  animation states against its model.
- `tools/dev/perf-biomes.sh` (and `check.sh --perf`): draw calls, triangles and
  frame ms for the Frozen Crypt and Burning Swamp, hunt, busy and boss scenes.

## Unreleased: Phone performance and battery

Code only (OTA-safe, no `project.godot` change, no reinstall). The look is untouched.

- **Frame cap.** On a phone the game now asks for 60 fps (`Game.fps_cap`); an iPhone with a
  120 Hz screen used to draw twice as many frames for no gain in a top-down hunt. New
  Settings row **Frame rate: 60 / 30** (setting `fps`, 30 = battery saver, applies at once).
  At 30 the simulation step ceiling is 1/24 s (`Game.max_step`) so the hunt keeps real-time
  pace. Desktop and the bot checks are not capped.
- **Physics tick 30 Hz** on a phone, at most 2 steps a frame: nothing uses the physics engine.
- **Background.** `NOTIFICATION_APPLICATION_PAUSED` drops the cap to 5 fps until the app resumes
  (the hunt already pauses itself in `focus_guard.gd`).
- **Hunt CPU.** Prop fade checks at 30 Hz with the elapsed time accumulated (no reusable
  array per frame), torch flicker at 20 Hz, foe separation rejects far pairs on plain numbers
  (no vector per pair), the HUD stops restyling the buff label and re-setting the hurt
  shader every frame.
- **Measuring.** `tools/dev/perf.sh [hunt|busy|boss] [zone] [low|high] [frames]` runs the new
  `--shots=perf` capture twice: headless for script time per frame, software Vulkan with the
  mobile renderer at 1179x2556 for draw calls and triangles.
- Already in place and left alone: batched props (MultiMesh), blob shadows for minions, no
  shadows on small props, low-quality particle halving. Mesh LOD threshold was tried (1 to 3)
  and changed under 3% of triangles, so it was not shipped.

---

## Unreleased: Real music for the new zones

The placeholder synth loops for the Frozen Crypt and the Burning Swamp are replaced by
real tracks (Kevin MacLeod, CC BY 4.0): cold choir and bass for the Crypt, a clicking
drone for the Swamp, a waterphone-and-brass march for Rime Regent and a choir-and-anvil
drive for Cinder Ogre. Each loops seamlessly at -16.5 LUFS like the other zones.
`frozen_boss` and `swamp_boss` also get the 0.7 boss intensity floor the other boss
tracks have.

---

## Unreleased: Screen shake intensity

The Screen shake on/off switch is now Off / Low / Medium / High (setting
`shake_level`), in the pause menu and the camp settings. It applies live and is
saved. **Low is the default**, about a third of the old strength. No save-version
change: `Game._migrate_shake` turns an old shake-on into Low and shake-off into
Off on load (safe to repeat).

- One dial in `HuntCam` (`LEVELS`): the rattle, the hit kicks and the punch-in
  (supers, boss slams) all scale by the level, so every `hunt.shake`, VFX tier
  shake, boss and biome hazard call, `cam.kick` and `cam.punch` follow it.
- Lower ceilings at every level, High included: peak shift 0.6 m to 0.45 m,
  rotation 0.05 to 0.025 rad, trauma capped at 0.8, one blow adds at most 0.5,
  kicks cap at 0.3 m, punch-ins at 0.16.
- The camp's jolts (chest open, hatch, evolve) follow the setting too, capped at 10 px.

---

## Unreleased: The Frozen Crypt and the Burning Swamp

Two new zones after the Vault, opened on the Trophy Road (Frozen Crypt at
10500 trophies, Burning Swamp at 12500). No save-version change: the road gains
seven appended steps and `Game.zone_unlocked` also opens a zone for any save
whose `road` already passed its step.

- **Frozen Crypt** (boss: the Rime Regent): a rimed crypt lair on snow, ice
  crystal clusters as cover, snow drifts that slow, a gale that shoves, and
  icicles that fall on a telegraph. Foes: Frostbound Thrall, Rime Guard, Rime
  Archer, Rime Seer, Winter Caller, Rime Hound, Glacier Colossus. Chilling hits
  leave frost patches; bodies shatter.
- **Burning Swamp** (boss: the Cinder Ogre): a scorched crypt, bog pools that
  drag, methane vents that erupt on a telegraph, marsh fire, burning stumps.
  Foes: Bogwalker, Charred Guard, Ember Spitter, Cinder Witch, Pyre Caller,
  Bog Leaper, Methane Bloat (ignites the ground when it dies), Pyre Brute.
- Bosses use the existing entrance (`boss_intro.gd` styles `rime`, `cinder`)
  with new patterns: Rime Regent's Icelances and Blizzard, Cinder Ogre's
  Eruption, Inferno and Bloats; both reuse cleave, quake and charge.
- Loot: five uniques per boss (weapon, armor, boots/robe/cowl, trinket, and an
  Ancient relic at Torment+), a Frost Egg and a Cinder Egg on the road.
- Art: `tools/art/biome_textures.py` recolors the KayKit skeleton, ogre, forest
  and graveyard atlases (unmodified PBR, no fog, no tint wash); `biome_art.gd`
  batches the crystals, drifts, pools and vents.
- Music: `frozen`, `frozen_boss`, `swamp` and `swamp_boss` are cut by
  `tools/audio/build_biome_music.py` from four Kevin MacLeod tracks (CC BY 4.0,
  see CREDITS.md). Snow and embers are crisp round dots.
- Weekly events, pets, power-ups, the living world and the quality toggles work
  as in the other zones; the Long Road gets the zone's lighting and weather,
  and its hazards, but not the static drifts or vents.
- `tools/dev/check.sh` also runs a hunt in each new zone.

---

## Unreleased: The Trophy Road

The feature freeze was lifted once for this, at the user's request. Save
version 7: `renown` is now trophies (same total), `road` counts steps on the
new road, new keys `unlocks` and `start_picked` (`Game._migrate_v6`).
`NATIVE_VERSION` unchanged.

- Hunts earn trophies, which never go down: 30 for a win, +10 per difficulty
  above Normal, +2 per elite (up to 5), +30 for the first win of the day, +50
  for a first clear; a loss pays up to 15; the Descent +4 per depth.
- The renown road becomes the Trophy Road (`src/lobby/trophy_road.gd`), a full
  screen from the trophy button: arena banners, a glowing track that fills to
  your trophies, claim bursts and a reveal for each unlock.
- Unlocks move onto the road: Long Road 150, Boss Rush 550, the Crypt 800,
  Descent 1200, Wilderness 2100, the Grove 2500, Barbarian 3000, a rift key
  3500, then a Crypt chest every 500. Heroes no longer join from shards.
- A new save chooses its first hero (Knight, Ranger or Mage,
  `src/lobby/hero_pick.gd`); the other two are picks at 400 and 1500.
- Old saves keep every hero, mode and zone they had; steps below their
  trophies count as claimed.

---

## Unreleased: Weapon skins

Two weapons modeled from scratch for the shop: the **Oathbound Blade**
(Knight, 6,000 gold) and the **Reaper's Scythe** (Barbarian, 8,000 gold).
A skin changes the model in the hero's hand; stats stay the equipped
weapon's. Built by the Blender scripts in `tools/art/`, colored with the
KayKit palette texture so they match the rest of the art. New per-hero save
keys `skin` and `skins` have defaults; save version unchanged. Look at them
with `--capture --shots=skins`.

---

## Unreleased: Camp tabs and hunting together

The feature freeze was lifted once for this, at the user's request (see
docs/PLAN.md "Next up"). Save version unchanged: new keys `profile` and
`online` have defaults. `NATIVE_VERSION` unchanged: no autoloads or project
settings changed. Online features stay off until the server is deployed and
`src/net/net_config.gd` points at it.

### Added
- **Tabs along the bottom**: Heroes, Hunt and Clan, tapped or swiped like
  the big mobile games, icons only with the open tab named. Hunt is home,
  with a fixed chest slot beside the Hunt button, a player plate with your
  name and clan, and a Journal button for the reward tracks, feats and log.
  Heroes is the gear screen with each hero's skills, talents, looks and ally;
  tap the name for the hero's card.
- **Shop**, the leftmost tab, paid in gold only (nothing costs money). Six
  daily deals that turn over at midnight: a free gift, discounted shards for
  your hero and one other (a locked hero first), two pieces of gear for your
  hero at the best material you've opened, and a chest at 30% off. A chest
  shelf (Silver 400, Gold 1,100, Crypt 2,600 gold; a bought chest opens in
  camp like a won one) and every weapon glow, one of them 30% off each week.
  New save key `shop` has a default.
- **Clans**: search, join or ask to join, start one (name, badge, open or
  closed, minimum combat), members with leader and elder tools, filtered clan
  chat with emotes, and tap any name to report or block.
- **Friends** by 6-letter friend code, with online status, requests and blocks.
- **Bring a friend**: a new player who enters your code in their first week
  gets 2,000 gold, a Gold Chest and 10 shards. You get 500 gold at once and
  more as they play (5 hunts, combat 25, a Veteran win), plus a Kinship weapon
  glow for the first friend, two Crypt Chests at three, 10,000 gold at five
  and 25,000 gold and a Crypt Chest at ten. Rewards are paid by the server as
  the friend really plays, capped at 20 friends.
- **Weekly clan raid boss**: every hunt you finish hits it; when it falls,
  every raider gets 1,500 gold and a Crypt Chest, the top three 20 shards.
- **Parties and co-op hunts**: up to three clanmates; partners walk where
  their player walks and fight beside you, and a party hunt pays 20% more gold.
- **Rankings** by power, **cloud save**, **moving to a new phone** with a
  transfer code, and **account deletion** under Profile › Account.
- `server/`: the game server (Nakama with our rules, Docker, HTTPS, nightly
  backups), its smoke test, and `-- --nettest` for the game's side.

## Unreleased: Skills are a hero's power

Save version unchanged (bought levels are refunded on load). `NATIVE_VERSION`
unchanged.

### Changed
- **Each hero has their own skills and combat level.** Hunt XP trains only the
  hero who played. Heroes start fresh at Combat 3.
- **No more bought hero levels.** Damage and health come from skills (+4.5%
  per level for 40 levels, then +1.5%). Every style trains three skills at the
  same pace. Combat counts Ranged and Magic 2x so all heroes top out alike.
- **Combat level earns talent points** (one per 5 levels), a fourth card
  choice at 70 and a second potion at 95.
- **Shards rub XP lamps** in Skills: 10 shards for XP in a trained skill.
- Old saves get back the shards and gold their bought levels cost.

---

## Unreleased: Gear has one quality ladder

Save version unchanged (old item names are rewritten on load). `NATIVE_VERSION`
unchanged.

### Changed
- **Tier is the color.** A piece's frame, name and drop beam show its
  material tier, grey to red, everywhere. Rarity is now pips under the icon
  (how many bonus stats); uniques carry a star.
- **Plain names.** "Barrowborn Steel Greaves" is now "Steel Greaves": the
  random prefixes are gone, and gear already in a bag is renamed.
- **Equipment screen.** The hero stands between the slots, with the stats
  under them and the bag as a grid of tiles below. No power numbers on gear:
  the card says what changes on the hero ("Health 516 → 634") if you wear it.
- **Armor icons** for helms, chests and legs are flat outlines in place of
  tiny renders of a whole hero.

---

## 2026-10-29: First steps, more music, results

No save version change (the new tutorial notes use the existing `tips` key).
`NATIVE_VERSION` unchanged.

### Added
- **First camp is quieter.** Before the first hunt the camp shows the hero,
  the expedition, the big button and the tabs; the side column, bounties and
  the road appear once there is something on them.
- **One-time notes** point at the next thing for a new player: the hunt
  button, the first chest, new gear, a hero ready to level up. Any tap puts
  one away; each shows once per save.
- **Five more music tracks** by Kevin MacLeod: two for camp, two for hunts,
  one for bosses. Camp, hunt and boss pick a different track each visit.
- **Defeat points somewhere.** The defeat screen names the one thing most
  likely to win the next try (equip a found upgrade, level the hero, close a
  power gap, or a tip), and its button reads "Try again".

### Fixed
- Loot left on the ground at a win flies to the hero instead of standing
  there: its floating names showed through the results screen.
- The results chest sits beside its name, so three loot rows fit on a short
  phone instead of one and a half.

## Unreleased: Launch splash and in-game updates

`NATIVE_VERSION` 3: needs a new IPA. Installs on shell 2 keep their current
content until reinstalled.

- The launch screen is a Gravelight splash (the app icon's lantern scene, full
  length, with the title) instead of the Godot logo. iOS builds its launch
  screen from `application/boot_splash/image`; with none set it used Godot's.
  `tools/dev/splash.sh` re-renders `assets/splash.png`.
- Boot holds on that splash while the update check runs, then fades into camp.
- An update shows a progress bar over the splash, then restarts the game on the
  new content in-process (scene freed, scripts and resources reloaded,
  autoloads rebuilt), so it applies without closing the app.

---

## 2026-10-28: Release cleanup

Save version 6 (stored item names take the new gear words). `NATIVE_VERSION`
unchanged.

### Changed
- **The game is called Gravelight.** Window title, Settings and the sideload
  listing. The home-screen name changes with the next IPA; bundle id and save
  file are unchanged, so nothing is lost.
- **Original gear names.** Materials no longer borrow Old School RuneScape's:
  metal is Bronze, Iron, Steel, Cobalt, Verdite, Skyiron, Bloodiron; hide is
  Leather, Hard Leather, Studded, Fenscale, Tidescale, Emberscale, Nightscale;
  cloth's Mystic and Infinity are now Sage and Sunwoven. Pieces: Helm, Visored
  Helm, Hauberk, Cuirass, Chausses, Greaves, Warden Shield, Robe, Robe Skirt.
  Gear already in a bag is renamed on load.
- **Level-up scroll** reads "Strength rises! Your Strength is now level 12."

### Added
- **A new app icon.** The Knight, lit from below by a lantern at his feet,
  graves behind him in blue night. Rendered from the game's own models by
  `tools/dev/icon.sh` (`tools/app_icon.gd`, shot `appicon`), so it can be
  re-rendered when the art changes. Shows on the home screen with the next IPA.
- **Error report for playtests.** Every engine and script error is logged
  locally (`user://errors.json`, repeats folded into one line with a count),
  and a run that never closed cleanly counts as a crash. Settings shows
  "Errors N · crashes N" and a **Copy report** button that puts build,
  device and the log on the clipboard, ready to paste into a message.
  Bots and captures don't write it. No backend, nothing leaves the phone.

### Process
- **Feature freeze** until the first real playtest: see `docs/PLAN.md`,
  Next up. Fixes, tuning, feel, art swaps and release work continue.

---

## 2026-10-27: Fantasy Weapons Bits

No save, settings or native changes.

### Added
- **The KayKit Fantasy Weapons Bits pack (CC0)** and new drop looks built from
  it. Knight: Arming Sword, Morning Star, Warhammer, Rapier, Claymore, Halberd,
  Plank, Crest and Bulwark shields. Barbarian: Spiked Club, Bearded Axe,
  Double Axe, Labrys, Maul, Plank Shield, Bulwark. Mage: Crystal Wand, Crystal
  Staff. Ranger: Hunting Bow, Recurve Bow.
- **Bigger boss-set pieces.** The Blackguard Blade is now a black claymore with
  a crest shield, the Dread Axe a labrys with a bulwark, the Shade Bow a
  recurve. The Thorn set gets a katana-thin Thornblade, a plank Grove Shield,
  a spiked Root Club and a hunting-bow Thornbow.
- `--shots=arms --hero=H`: every weapon and offhand look in one hero's hands.

---

## 2026-10-26: More gear looks, a clearer equipment screen, bigger supers

Save version still 5 (one new per-hero key, `best_mat`, defaults in `_fresh()`;
items gain an optional `look` roll, old items show their stage's base look).
`NATIVE_VERSION` unchanged.

### Added
- **Many more gear looks, all KayKit.** Tier stages can roll an alternative
  model: horned helms, war axes, tower and heraldic shields, witch hats, cowls,
  ragged robes, bandit masks, lantern staffs, skull orbs, candelabras,
  phylacteries, hooded cloaks. Each boss set has its own look per hero:
  the Barrow King's **bone** set (horned bone helm, skull shield, ribcage
  harness, bone staff), the Crypt Queen's **blackened** set (Blackguard plate,
  Necromancer robes and Deathlight staff, Shade garb) and the Thornmother's
  **bark** set (bear masks, druid cowls, the Grove Lantern). Uniques got models
  of their own (the Crown is a horned gold helm, the Cleaver a bone axe).
  New weapons are put together from several props (`GearDB.KITS`).
- **Equipment screen, rebuilt.** The bag is a list grouped by what matters:
  Upgrades (sorted by power gained), Wearing, In your bag, Needs more skill,
  and other heroes' gear folded away. Each row says what the piece is in words
  and shows one number: the power it adds. Slots show their material and a
  green arrow when the bag holds an upgrade. Tapping a row tries it on and
  slides up a card with what it replaces and every action.
- **Inspect:** any piece alone, big and turning; weapons float with their
  sparks, worn pieces are shown on the bare hero with the camera on them.
- **New tier reveal:** the first time a hero wears a higher material, light
  wheels out behind them and the material's name punches in.
- **Supers:** the Knight's Judgement brings down a crown of lightning around the
  landing; the Barbarian's Whirlwind becomes a column of fire; the Ranger's
  Hail of Arrows darkens the sky and rains arrows all around.
- **Descent:** each new depth sends a red shockwave out from the hero, embers
  burst from the ground and the camera drops back.

### Fixed
- Hats, hoods and horned helms from the skeleton characters never showed (they
  are pinned to a bone, not skinned). The Barbarian's starting Horned Cap was
  invisible because of it.
- The rarity glow and polish washed whole pieces in color; they stay on the
  edges now, so black reads black and bone reads bone.
- Tall pines on the camera's side of the arena hid fights near the south wall
  (worse when a super pushes the camera in); they fade like the near trees.

---

## 2026-10-25: Playtest fixes, gear that looks its tier, big moments

Save version is now 5 (each mode keeps its own unlocked difficulty; old saves
rebuild them from the wins they already record). `NATIVE_VERSION` unchanged.

### Fixed
- Tapping the campfire crashed the app (a scene node was not marked unique).
  A test now checks every `%Name` lookup against its scene.
- After a boss fell mid-run in the Descent or Boss Rush, the camera stayed
  pinned where the fight had been.
- Winning a difficulty opened it in every mode. Each mode now opens its own;
  the Descent opens its next tier when one of its bosses falls.
- The fallen never left the ground (thousands of bodies deep in the Descent,
  and a growing cost per frame). They now lie 20 s, at most 45 at once.
- Long Road: foes walk through the gap to reach you in another room instead of
  pressing against the wall; a shove can no longer push you through a sealed
  gate past the fight. Loot no longer lands outside the walls.

### Added
- **Gear that looks its tier.** Every material has a finish: bronze and iron
  dull and dirty, steel and mithril clean and gleaming, adamant and rune with
  light running over them, dragon (and Eldritch, black dragonhide) glowing
  from molten seams. Weapons and offhands from the fifth tier shed sparks, and
  a full set from that tier wraps the hero in rising motes. Item icons take
  their metal's color.
- **Weapons in combat:** melee swings take the weapon's metal color, and
  dropped weapons and offhands show their real model on the ground.
- **Super moment:** the camera pushes in, the screen washes in the hero's
  color and the super's name rises over the hero.
- **Legendary moment:** a bolt of light on the drop, a brief slow-down and its
  name in the feed.
- The campfire answers every tap: what it paid, or its rate per hour.

---

## 2026-10-24: Skill over stats, the Hollow Grove, Phase 11

Merged to `main`. Save version
is now 4 (old saves migrate: Veteran becomes tier 3 of 8, Nightmare tier 5).
`NATIVE_VERSION` is unchanged; no project settings changed.

### Why
Stacked gear and cards made every tier AFK-able: a level-12 Mage in material-4
gear stood still for a whole Nightmare hunt and won at full health (armor at
the 60% cap, 36 HP/s regen). The fix is to make *playing well* matter more than
numbers, and to give strong accounts a ladder that keeps going.

### Added
- **Eight difficulty tiers** (Normal, Hard, Veteran, Expert, Nightmare, Hell,
  Torment, Abyss), each about +65% foe health. Every tier lists its recommended
  power; the camp card shows yours against it.
- **Mechanics through armor:** telegraphed attacks also take a share of max
  health (0% Normal to 35% Abyss). You cannot tank them; step out or dash.
- **Grave eruptions:** the ground bursts under and around the hero every few
  seconds (telegraphed). Standing still is always punished.
- **Perfect dodge:** dash through a blow that would have hit for a riposte
  (+35% damage for 3 s) and some super.
- **Steady aim:** bow and staff heroes deal +25% after standing still a moment.
  Moving is safety; standing is damage.
- **Exposed bosses:** Gravemaw charging into a wall, the Hexer Queen blinking
  away from a hero in her face, the Thornmother after her thorn ring: each is
  dazed and takes +50% for a moment.
- **The ritual** (Horde): Grave Callers chant at a sigil. Kill them in 18 s for
  a rare, or a champion brute climbs out and the dead quicken.
- **A mini-boss** (a champion Bone Brute) at the middle champion mark; a second
  wave of champions on Nightmare and up.
- **The Long Road:** dark rooms, timed vaults, cursed altar rooms.
- **The Hollow Grove**, a third zone: an autumn forest, the Grove Cult (hooded
  cutthroats, slingers, thorn shamans that root, brawlers), and **the
  Thornmother**, a boss built around the dash (thorn rings, briar seeds that
  stay, vine sweeps, roots). Three uniques, a pet and a set.
- **Rifts:** reach depth 8 in the Descent for a key; a rift is one boss at 2.6×
  strength with a guaranteed unique.
- **Signature legendaries:** Bulwark (Knight blocks frontal blows standing still),
  Ricochet (Ranger), Pyre (Mage), Rampage (Barbarian).
- **Card banishes** (three a hunt), evolutions from three stacks instead of max,
  a fourth card choice at hero level 15, a second potion at level 20.
- **Gear sets** (Regalia, Raiment, Barkbound) and **ancient** items (+30%, Hell+).
- **Gold sinks:** reforge (reroll extra affixes), temper (raise material),
  paid talent resets after the first, weapon glows.
- **Hero mastery** (titles, gold, shards, glows), **trophy rating** per hero,
  **first win of the day**, a **7-day login calendar**, **campfire** idle gold,
  **feats** (achievements), a free six-week **season** track, boss **kill counts**
  and **dry streaks**, the **Hexling** pet, and a **companion** hero at your side.
- **Results:** Play again, XP bars, the chest shown big, the road bar filling,
  upgrades named by hero. Chests won while playing again wait in camp in order.
- **Victory:** the combat buttons step aside, a white flash, the camera on the
  fall, then the loot flies to the hero; loot labels are short and big.
- Music for the Descent, rifts, the Grove and its boss; the music muffles below
  25% health. Bigger crits, a level-up burst, a coin fountain from champions,
  the Descent darkening with depth, first-time tips for each new mechanic.

### Changed
- Normal: boss health +25%, 150 souls, first surge at 15%.
- Chest shards: 75% to the hero you played (was two random heroes).
- Armor is now a rating with diminishing returns (DB.armor_dr), and foes on
  higher tiers ignore some of it. Regen is capped at 2.5% of health a second and
  leech at 4%; higher tiers cut passive healing.
- Foes and bosses grow with the hunt's level, so a snowballing build still
  meets a real boss.
- Heroes wear their class outfit and starter gear when nothing is equipped.
- Tall props fade while they hide the fight; foreground props half-fade.
- Ranged foes fire a three-bolt spread on Expert and up; hounds hunt in pairs
  on Nightmare and up; bow and staff dashes throw back the crowd.

### Not done
- **Game Center** leaderboards and achievements: the IPA is unsigned and
  installed through AltStore, and Game Center needs an App Store provisioned
  entitlement. Feats and records are kept locally instead.

---

## 2026-10-23: UI pass, talents, new modes (Phase 9 and 10)

On branch `claude/game-codebase-review-m1uchq`, not yet on `main`. Prayer,
Slayer and Smithing were left out on request.

### Added
- **Talent trees:** three paths per hero, eight nodes each, a point per hero
  level, free reset. Hero max level is now 20 (levels past 10 add less raw
  power). Open it from the Heroes sheet.
- **Endless Descent:** the horde never ends; every minute goes a level deeper
  with a champion, every fifth depth a boss. Deepest depth is kept per hero;
  chests by depth.
- **Boss Rush:** Gravemaw and the Hexer Queen, twice, empowered on the second
  lap, with a card and a breath between fights.
- **The Wilderness:** a closing ring and five to seven rival bands (hero-built
  foes) hunting you while the dead rise. Last band standing wins.
- **Pacts** offered mid-hunt (a gain with a price), the **cursed shrine**,
  five more champion affixes (Frozen, Jailer, Mortar, Plagued, Arcane), a
  **health potion** button, and Veteran/Nightmare bosses that learn a blast ring
  and a fan of lances.
- **Renown road** on the camp screen, the **weekly omen** (a rule twist with a
  better chest) and **clue scrolls** (three goals, then a casket) in the Log.

### Changed
- Hunt HUD: health bar under the hero, XP ring on the portrait, one objective
  or boss bar, a left-edge event feed.
- Gear screen: rarity-only colors, item power and tier on every tile, a
  before/after stat strip, a fixed-height detail card, red "new" dots.
- Heroes sheet, sheet sizing, camp follow-ups (profile chip, tap the hero,
  chest on the rail).

### Fixed
- A foe-list index error when a foe's tick removed other foes (bomber blasts).

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
