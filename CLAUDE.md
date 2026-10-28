# Gravelight — working rules

Godot 4.7.2, GDScript, portrait mobile (iOS). Read `README.md` for what the game
is, and `docs/PLAN.md` for the work queue and the rules for working with other bots.
Do tasks in plan order, one task per PR.

## Every session

```
tools/dev/setup.sh            # once per fresh container (Godot + software GPU)
tools/dev/check.sh            # before every commit: must print CHECKS PASSED
tools/dev/check.sh --quick    # compile + rule checks (`-- --test`), while iterating
tools/dev/shots.sh lobby,hunt # screenshots into ./shots — then Read the PNGs
```

A change that touches anything visible is not done until you have taken the
relevant screenshots, looked at them, and described what you saw. Do not claim
a visual result you have not looked at.

## Where things are

- `src/data/db.gd` — every tuning number (heroes, enemies, boss, cards, loot,
  tiers, skills). Balance changes go here, not in logic files.
- `src/autoload/game.gd` — save data, hero stats, loot rolls, rewards. The
  `Game` autoload is a chain of scripts by subject, each extending the one
  before: `game_state` (save, accessors) < `game_items` (gear) < `game_heroes`
  (stats, talents) < `game_rewards` (chests, road, omen, clues, bounties) <
  `game_goals` (mastery, dailies, achievements, season) < `game` (boot,
  migrations, `finish_hunt`).
- `src/hunt/` — the hunt. `Hunt` is the same kind of chain: `hunt_state`
  (fields, queries, feel) < `hunt_loot` (drops, cards, projectiles) <
  `hunt_combat` (damage, kills, the end) < `hunt_events` (shrines, surges,
  ritual) < `hunt_modes` (Long Road, Wilderness, Descent, Rush) < `hunt.gd`
  (setup, tick, director).
- `src/lobby/lobby_ui.gd` sits on `lobby_ui_widgets` < `lobby_ui_hero_sheets`
  < `lobby_ui_sheets`.
- A part may only call parts below it (GDScript won't compile a call to a
  method a base doesn't have). New code goes in the lowest part that has
  everything it calls. The chains use path `extends`, not `class_name`.
- `src/lobby/` — the camp screen and its sheets.
- `src/ui/` — HUD and modal scenes (`.tscn` + script), `theme.tres`.
- `src/fx/` — shaders.
- `src/main.gd` — screen switching plus the `--check`, `--bot`, `--capture` modes.

## GDScript traps that cost time here

- `var x := some_dict["k"]` or `var x := some_array[i]` fails to compile
  ("Cannot infer the type"). Indexing returns Variant: write `var x: float = ...`
  or `var x: String = ...`. Same for values from untyped `for f in array:` loops
  (`var d: Vector3 = f.flat_pos() - p`).
- No new `class_name`. Over-the-air packs cannot register global classes:
  installed copies keep the IPA's class list, so a pack that names a class
  the IPA lacks fails to compile and boots to a black screen. Give new
  scripts no `class_name` and use them via
  `const Foo := preload("res://path/foo.gd")`. The `-- --test` rule
  "no class_name the IPA lacks" enforces this.
- New `class_name` scripts are unknown until the class cache refreshes:
  `tools/dev/check.sh` re-imports first, so run it rather than a bare compile.
- Typed arrays: assign with `.assign([...])`, not `=` with an untyped literal.
- Don't name a variable `ready` on a Node (clashes with the `ready` signal).
- `%Name` unique-name lookups need `unique_name_in_owner = true` in the `.tscn`.
- Second-finger taps don't become mouse clicks. Anything pressed during play
  must read `InputEventScreenTouch` (see `src/ui/radial_button.gd`).
- Particles: one-shot bursts go through the shared emitters in `fx.gd`
  (`burst`, `puff`, `bone_burst`, `embers_at`) — never create a GPUParticles3D
  per hit.

## Style

- UI layout lives in `.tscn` files and is styled by `src/ui/theme.tres`.
  Never edit `theme.tres` by hand: change `tools/build_theme.gd` and run
  `tools/dev/godot.sh -s res://tools/build_theme.gd`.
- Colors, fonts and sizes come from theme type variations (`Title`, `Heading`,
  `Body`, `Small`, `Caption`, `HudLabel`, `PrimaryButton`, `GoldButton`,
  `Ghost`, `RoundButton`, `Card`, `Chip`, `Plaque`, `Parchment`, `Sheet`, bars
  `HPBar`/`XPBar`/`SoulBar`/`BossBar`). Use them; add a new variation in
  `build_theme.gd` rather than per-node overrides.
- Art: KayKit only (same rig, same palette). Any `Rig_Medium` character works
  with `KK.character()` and the baked animation library. If you add clips from
  another KayKit animation file, add it to `tools/bake_anims.gd` and re-run it.
- Comments say why, briefly. Match the surrounding code.

## Release safety

- Pushing to `main` builds the iOS IPA and publishes an over-the-air content
  pack to every installed copy. Work on a branch; merge only when asked.
- If you change `project.godot` autoloads, input map or other project settings
  that a content pack cannot carry, bump `NATIVE_VERSION` in
  `src/autoload/ota_boot.gd` and tell the user they need to reinstall the IPA.
- Saves are `user://barrowfall_save.json`. New save keys must have a default in
  `Game._fresh()` (old saves are merged over the defaults). Never rename or
  remove a key without a migration.

## Working with other bots

Claude and other bots (grokbot) both commit here, so:

- `docs/PLAN.md` is the one queue. Tick the task in the same PR and add a `CHANGELOG.md`
  entry; when two PRs both add one, keep both.
- Branch `claude/<task>` or `grok/<task>`; never push to another bot's open branch.
- CI must be green before a merge: it fails on a `valid=false` `.import`, an engine load
  error and an OTA pack over budget. Never commit a `.import` with `valid=false`: re-import
  from the real file (git LFS files must be pulled first).
- A new third-party model needs a row in `docs/art-audit.md` (source, author, licence, no
  commercial game or character in the title). When in doubt use KayKit or draw it in code.
- Screenshots in the PR for anything visible, and say what they show.
- Rico decides what ships to `main`, the economy's direction, and anything that needs a phone
  or a secret.
