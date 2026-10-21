# Barrowfall — next work plan

Written to be executed by a smaller model, one task at a time. Each task lists
the files, the steps, and how to prove it works. Read `CLAUDE.md` first.

## How to work through this plan

1. Do tasks **in order**. Later tasks assume earlier ones.
2. One task = one commit. Message: `<task id>: <what changed>`.
3. Before each commit: `tools/dev/check.sh` must print `CHECKS PASSED`.
4. If the task is visible, take the screenshots named under **Verify**, Read
   them, and say what you saw in your reply. Shots are slow (1–3 min each), so
   only take the ones listed.
5. If a task turns out bigger than described, stop after the part that works,
   commit it, and write what's left under "Notes for the next task" at the end
   of this file.
6. Tick the box in this file when a task is done, in the same commit.
7. Never touch `_legacy/`. Never push to `main` unless the user says so.

Numbers given here are starting values. The user tunes feel on a real phone;
the dev panel (task 1.5) is how they do it.

**Order:** Phase 1 (camera) → Phase A (art direction) → Phase G (gear and
inventory) → Phases 2, 3, 4, 5, 6. Phase A can replace every character model,
so don't polish character visuals (portraits, gear glow, new enemy looks)
before it's decided.

---

## Phase 1 — Camera (the user's top complaint)

What's wrong today (`src/hunt/cam.gd`): the camera is a fixed offset
`(0, 14.6, 9.0)` — a steep ~58° look-down with the hero dead center. From that
angle you see the tops of the big KayKit heads instead of faces and armor,
there's no more room ahead of you than behind, tall props (crypt roof, trees,
lantern posts) can cover the hero, and nothing changes for the boss fight.

Target: a lower, more cinematic angle (~50°), the hero a bit below screen
center, the camera leading where you move, props fading when they block the
view, a wider frame for the boss, and player-selectable distance.

### [x] 1.1 Rewrite the camera rig with real parameters

File: `src/hunt/cam.gd` (replace the whole file; keep the class name `HuntCam`
and the public API `target`, `focus_override`, `shake_enabled`, `snap()`,
`follow(dt, vel)`, `add_trauma(v)` because `hunt.gd` uses them).

Use this as the implementation. It was written but **never run**: compile it,
look at the shots, and fix anything off (the tilt sign is the likeliest
mistake: if the hero ends up above center, negate the tilt angle).

```gdscript
class_name HuntCam
extends Camera3D
## Hunt camera: orbits the focus point at a fixed pitch and distance, keeps the
## hero slightly below screen center, leads in the direction of travel and
## shakes on trauma. Every number is a var so the dev panel can tune it live.

var pitch_deg := 50.0     # angle above the ground (90 = straight down)
var distance := 19.5      # metres from focus to camera
var fov_w := 40.0         # horizontal FOV; portrait keeps width
var anchor := 0.57        # hero's screen height: 0 top, 0.5 center, 1 bottom
var lookahead := 0.35     # seconds of velocity to lead by
var lead_max := 2.6       # metres
var follow_rate := 7.0
var dist_mult := 1.0      # player preset: Close 0.86, Standard 1.0, Wide 1.16
var zoom := 1.0           # dynamic, eased toward zoom_target
var zoom_target := 1.0

var target: Node3D
var focus_override: Variant = null
var trauma := 0.0
var shake_enabled := true
var _focus := Vector3.ZERO
var _lead := Vector3.ZERO
var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 0.5
	far = 140.0
	_noise.frequency = 2.2


func snap() -> void:
	if target:
		_focus = Vector3(target.global_position.x, 0, target.global_position.z)
		_apply(0.0)


func follow(dt: float, vel: Vector3) -> void:
	if target == null:
		return
	_t += dt
	var want_lead := Vector3(vel.x, 0, vel.z) * lookahead
	_lead = _lead.lerp(want_lead.limit_length(lead_max), 1.0 - exp(-3.0 * dt))
	var f: Vector3 = target.global_position + _lead
	if focus_override != null:
		f = focus_override
	f.y = 0.0
	_focus = _focus.lerp(f, 1.0 - exp(-follow_rate * dt))
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-2.5 * dt))
	trauma = maxf(trauma - dt * 1.6, 0.0)
	_apply(trauma * trauma if shake_enabled else 0.0)


## Recomputed from scratch every frame, so shake never accumulates.
func _apply(shake: float) -> void:
	fov = fov_w
	var p := deg_to_rad(clampf(pitch_deg, 25.0, 80.0))
	var d := distance * dist_mult * zoom
	global_position = _focus + Vector3(0, sin(p), cos(p)) * d
	look_at(_focus, Vector3.UP)
	# Tilt up so the focus sits at `anchor` instead of the center.
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_v := atan(tan(deg_to_rad(fov_w) * 0.5) / aspect)
	rotate_object_local(Vector3.RIGHT, atan((anchor - 0.5) * 2.0 * tan(half_v)))
	if shake > 0.0:
		rotate_object_local(Vector3.RIGHT, _noise.get_noise_2d(_t * 40.0, 0.0) * 0.05 * shake)
		rotate_object_local(Vector3.UP, _noise.get_noise_2d(0.0, _t * 40.0) * 0.05 * shake)
		global_position += Vector3(_noise.get_noise_2d(_t * 30.0, 7.0), 0, _noise.get_noise_2d(7.0, _t * 30.0)) * 0.6 * shake


func add_trauma(v: float) -> void:
	trauma = clampf(trauma + v, 0.0, 1.0)
```

Also in `src/hunt/hunt.gd`, `on_screen()` uses `s.y > 80.0` as the top HUD
margin; leave it.

Verify: `tools/dev/shots.sh hunt,boss` and `tools/dev/shots.sh hunt 720x1560`
(tall iPhone shape). In the shots: the hero's feet sit a little below the
middle of the screen; you see the front of the characters (faces, shields),
not just helmet tops; there is more ground visible above the hero than below;
the HUD bars don't cover the hero. Run `tools/dev/check.sh`: the bot still
wins (it uses `on_screen` for ranged enemies).

### [x] 1.2 Dynamic framing: boss, crowds, victory

File: `src/hunt/hunt.gd` (in `tick()`, after `cam.follow`… set targets before
calling `cam.follow`).

- Boss fight (`phase == "boss"` and `boss.alive`): `cam.zoom_target = 1.18`,
  and set `cam.focus_override` to a point 25% of the way from the hero to the
  boss (`hero.position.lerp(boss.position, 0.25)`), so both stay in frame.
- Rise phase: `cam.zoom_target = 1.0 + clampf((foes.size() - 15) / 60.0, 0.0, 0.12)`
  (pull back a little as the horde grows).
- Victory: `cam.zoom_target = 0.85` (push in on the loot fountain).
- Boss intro (`_begin_boss`): today it sets `focus_override` to the crypt. Keep
  that, but also `cam.zoom_target = 1.25` for the intro, so the crypt roof does
  not fill the screen. When the intro ends (the `"boss_intro"` branch of
  `tick()`), go to the boss-fight rule above instead of `focus_override = null`.

Verify: `tools/dev/shots.sh boss,victory`. Boss and hero both visible in the
boss shot; the crypt roof does not cover more than the top fifth of the screen.

### [x] 1.3 Fade props that block the view

Files: `src/hunt/arena.gd`, `src/hunt/hunt.gd`.

The camera always looks north (−Z), so a prop blocks the hero only when it is
just south of the hero (+Z, between hero and camera) and tall enough.

1. In `arena.gd` add `var occluders: Array = []` (each entry a Dictionary
   `{"node": Node3D, "meshes": Array, "r": float, "h": float, "t": 0.0}`).
2. Add a parameter `occlude := false` to `put()`. When true, collect
   `n.find_children("*", "MeshInstance3D", true, false)`, measure the height
   with the same AABB code as `size_of()` (times `scale_`), and append the entry.
   Use `r = 1.2 * scale_` unless you have a better footprint (crypt: 4.0).
3. Pass `occlude = true` for: the crypt, `pillar.gltf`, `post_skull.gltf`,
   `post_lantern.gltf`, `lantern_standing.gltf`, all dead trees, the shrine,
   `arch_gate.gltf`, and forest/pine trees placed within 4 m of the bounds.
4. Add `func update_occlusion(points: Array, pitch_deg: float, dt: float)`:
   for each occluder, `want = 0.0`; for each point `q` in `points` (hero, and
   the boss when alive): `dz = node.z - q.z`, `dx = abs(node.x - q.x)`; if
   `dz > -0.3 and dz < h / tan(pitch) + r and dx < r + 0.6` then `want = 0.72`.
   Ease `t` toward `want` (rate 10/s) and set
   `mi.transparency = t` on every mesh of the entry (skip the write when the
   value hasn't changed by more than 0.01 — it's a render-state change).
5. Call it from `Hunt.tick()` every frame with `[hero.position]` plus
   `boss.position` when the boss is alive, passing `cam.pitch_deg`.

Verify: `tools/dev/shots.sh boss` (the crypt sits behind the boss spawn) and a
`film` shot. Props right in front of the hero are see-through; nothing else is.
Check `draws=` in the shot output did not jump by more than ~30.

### [ ] 1.4 Camera distance setting

Files: `src/autoload/game.gd` (`_fresh()` settings: add `"camera": "standard"`),
`src/ui/settings_box.gd` (add a row like the Graphics row with three toggle
buttons `Close / Standard / Wide`), `src/hunt/hunt.gd` (`_ready()`: set
`cam.dist_mult` from the setting: close 0.86, standard 1.0, wide 1.16).

Verify: `tools/dev/shots.sh settings`; the row is there and matches the
Graphics row's style.

### [ ] 1.5 Hidden dev tuning panel (so the user can tune on the phone)

Files: new `src/ui/dev_panel.gd` (a `PanelContainer` built in code),
`src/ui/pause.gd` / `pause.tscn`.

- In the pause menu, tapping the `Info` label 5 times within 3 seconds opens
  the dev panel over the pause screen.
- The panel has one `HSlider` per camera var: `pitch_deg` 30–75, `distance`
  12–28, `fov_w` 30–60, `anchor` 0.4–0.7, `lookahead` 0–0.8, `lead_max` 0–5,
  `follow_rate` 2–14. Each slider shows its value and writes straight to
  `hunt.cam` (the hunt is paused, so call `hunt.cam._apply(0.0)` after each
  change so the frame behind the menu updates).
- A "Copy values" button puts a one-line summary on the clipboard
  (`DisplayServer.clipboard_set`), e.g.
  `pitch=50 dist=19.5 fov=40 anchor=0.57 look=0.35 lead=2.6 rate=7`, so the user
  can paste it back to you.
- Values are not saved (dev only).

Verify: compile check; one screenshot is optional (the panel needs taps, so a
capture would need a `devpanel` shot that opens it directly — add one to
`_capture` in `main.gd` if you want to look at it).

### [ ] 1.6 Camp camera polish

File: `src/lobby/lobby.gd` (`_build_world`, `cam.look_at_from_position`).

- Add a slow idle drift: in `_process`, move the camera ±0.15 m sideways on a
  12-second sine and look at the same point, so the camp feels alive.
- When the hero changes (`show_hero`), do a quick 0.35 s push-in (move the
  camera 0.4 m toward the hero and back with a tween).

Verify: `tools/dev/shots.sh lobby`.

---

## Phase A — Art direction: grittier, realistic-proportion characters

The user's words: the KayKit models are "fine", but a more realistic and grungy
look would be better — "a real OSRS knight or Diablo knight", and the same
for the other classes and the enemies. KayKit is chibi (huge heads, toy
proportions, bright palette). What's wanted is adult proportions, armor that
reads as armor, and a darker, dirtier palette. Low-poly is fine (OSRS is
low-poly); cute is not.

### [ ] A.1 Research and shortlist (no code)

Search for free 3D character packs and write the findings to
`docs/art-options.md`. Requirements, in order:

1. License allows use in a released game: CC0 preferred; CC-BY OK (add to
   `CREDITS.md`). No "personal use only", no unclear license, no AI-generated
   meshes (that's what the old game used and it failed).
2. Humanoid, rigged, with adult proportions, covering at least: a knight
   (plate armor, helm), a ranger/archer, a mage, a barbarian/brute, plus
   undead enemies (skeletons or similar) and something that can be a big boss.
3. One shared skeleton (or easy retargeting) so one animation set drives
   everyone, like today's `KK.character()` + baked library.
4. Modular parts (separate helmet, chest, legs, weapon) are a big plus: they let
   equipped gear change the model (Phase G).
5. Mobile budget: about 5–15k triangles per character, ≤ 2 textures each; 40
   enemies on screen at once.
6. Matches across packs (same palette and texel density), or one pack covers
   everything.

Leads to check first (not verified to meet everything):
- Quaternius "Modular Character Outfits — Fantasy" (CC0; 12 outfits from 62
  modular parts on the "Universal Base Characters"; works with the
  "Universal Animation Library", 120+ animations):
  https://quaternius.itch.io/modular-character-outfits-fantasy — check
  whether its look is gritty enough and whether matching undead exist.
- Mixamo (Adobe; free with an Adobe login, royalty-free in games): realistic
  characters and a huge animation library on one rig. Check the license on
  committing raw files to a (possibly public) repo, and triangle counts for
  40-on-screen enemies. The user would have to do the download (it needs a
  login).
- Other itch.io / OpenGameArt / Sketchfab (CC-filtered) "dark fantasy",
  "PSX", "medieval" packs.

For each candidate list: link, license, what characters it covers, rig,
triangle count, modular or not, and one-line verdict. End with a
recommendation and a fallback ("keep KayKit but re-grade it": desaturated
palette, darker textures, grime overlay in `char.gdshader`).

Reply to the user with the shortlist and **wait for their choice** before A.2.

### [ ] A.2 Prove it with one hero

Download the chosen pack into `assets/<pack>/` (keep its license file), import,
and get one hero (the Knight) working in the existing systems:

- A loader like `src/core/kk.gd` for the new pack (model + animation library +
  weapon attachment points). Keep `KK` working; switch per hero via a
  `"pack"` field in `DB.HEROES`.
- Map the clips the game uses (`idle`, `run`, attack list, `super`,
  `Dodge_Forward`, `Death_A`, `Hit_A`, `Cheering`, `Spawn_Ground`) to the new
  library's names in the hero's `anim` dict. `Hero.UPPER_BONES` must list the
  new skeleton's upper-body bone names (the attack-while-running filter
  depends on it).
- `char.gdshader` must still apply (it reads `albedo_texture`); add normal or
  roughness maps only if the pack has them.

Verify: shots `lobby,hunt,film` with the Knight. Put the old and new side by
side in the reply. **Ask the user** before converting the rest.

### [ ] A.3 Convert everything

Remaining heroes, all enemies (minion, warrior, rogue, mage, elites), the
boss, the pet, the camp scene's hero, the app icon (`--shots=icon`, then save
as `assets/icon.png` in RGB). Re-tune `db.gd` `radius`/`scale` values to the
new models' sizes. Environment props can stay KayKit if they still match;
otherwise re-grade them darker. Update `CREDITS.md` and `README.md`.

Verify: full shot set (`lobby,hunt,levelup,boss,victory,heroes`) and
`check.sh`. Report draw calls and triangles from the shot output; the hunt shot
should stay under ~700 draws and ~400k triangles.

---

## Phase G — Gear and inventory overhaul

What the user noticed is true: today gear is **stats only**. Equipping an item
never changes the hero's model; every Knight looks the same. The flow is also
clunky: a Bag sheet with long cards, Equip buttons per row, a separate gear
row in the Heroes sheet, no clear comparison, and only three slots.

Do G after Phase A is decided, because visible gear depends on the art.

### [ ] G.1 Visible gear

Files: `src/data/db.gd`, `src/autoload/game.gd`, `src/hunt/actor.gd` (or the
new pack loader), `src/lobby/lobby.gd`, `src/hunt/hero.gd`.

- Every item gets a `"look"`: for weapons, a weapon model file; for armor
  pieces, a model part (modular packs) or a material/tint variant (KayKit:
  `Knight_Helmet`, `Knight_Cape` and body meshes can be shown, hidden or
  tinted).
- Looks come in tiers by rarity: common = plain, magic = trimmed, rare =
  darker steel with color accents, legendary = unique model or an emissive
  glow. Legendary uniques (`DB.UNIQUES`) each get a fixed look.
- `build_model` takes the hero's equipped looks, so the camp, the hunt and the
  portraits all show the real gear. Changing gear in camp updates the 3D hero
  immediately with a short flash.
- Item pickups in the hunt show the item's real model under the beam (today
  they show a generic sword, shield or key).

### [ ] G.2 Slots

Go from 3 slots to 5: weapon, helm, chest, gloves/legs (whatever the art
supports), trinket. Migration: existing `armor` items become `chest`. Add the
new keys to `Game._fresh()` and convert old saves in `load_save()` (bump
`SAVE_VERSION` to 2 and write a `_migrate_v1()`; never drop items).

### [ ] G.3 Paper-doll equipment screen

Replace the gear rows in the Heroes sheet and the Bag sheet's per-row buttons
with one **Equipment** screen (`src/lobby/equipment.tscn` + `.gd`):

- The 3D hero (or its portrait render) in the middle, slot buttons around it
  showing the equipped item's icon in its rarity frame.
- Below, an inventory grid of square tiles (icon + rarity frame + a small ▲
  when it beats what's equipped), filterable by slot. Tapping a slot filters
  the grid to that slot.
- Tapping an item opens a detail panel: name, rarity, stats, and a side-by-side
  compare with the equipped item (green ▲ / red ▼ per stat), with buttons
  Equip / Sell. One tap to equip, no confirmation; selling a rare or better
  asks once.
- "Equip best" button (by `Game.item_score`) and "Sell all below Rare" with a
  count and gold total before confirming.
- "New" dots on items obtained since the screen was last opened (store item
  uids seen in the save).
- The Bag nav button opens this screen; the Heroes sheet links to it.

### [ ] G.4 In-hunt pickup feedback

When you walk over an item, the toast shows the item's name, rarity and "▲
upgrade" if it beats your equipped piece, so loot feels meaningful in the
moment. In results, upgrades are marked the same way, with an "Equip" button
per upgrade.

Verify (whole phase): shots `lobby,heroes,bag` plus a new `equip` shot that
opens the equipment screen with a demo inventory (extend `_capture` in
`main.gd`). The hero in the lobby must visibly change when gear changes —
take a shot before and after equipping a legendary.

Note: task 4.3 (gear compare and glow) is superseded by this phase; skip it.

---

## Phase 2 — Feel and readability

### [ ] 2.1 Haptics

Files: `src/autoload/game.gd` (`_fresh()` settings: `"haptics": true`), new
static helper `Ui.buzz(ms: int, amp := 0.5)` in `src/ui/ui.gd` that calls
`Input.vibrate_handheld(ms, amp)` only if the setting is on and
`OS.has_feature("mobile")`, `src/ui/settings_box.gd` (a `CheckButton`
"Vibration").

Call sites: hero hit in `Hunt.damage_hero` (35 ms), dash in `Hero.try_dash`
(12 ms), super in `Hero.try_super` (50 ms), Knight slam landing (70 ms), boss
death and hero death (120 ms), level-up offer (25 ms), legendary drop (60 ms).
Do not buzz on every enemy hit.

Verify: compile check (no phone here). List the call sites in the commit message.

### [ ] 2.2 Shader and effect warm-up (removes first-use stutter on phones)

Files: `src/hunt/hunt.gd`, `src/ui/hud.tscn` (+ `hud.gd`).

On Metal the first time a material/particle/effect draws, the shader pipeline
compiles and the frame hitches. Draw everything once behind a black curtain at
hunt start:

1. Add a full-screen black `ColorRect` named `Curtain` (unique name) as the
   last child of the HUD, `mouse_filter = 2`, starting at alpha 1.
2. New `Hunt._warmup()` called at the end of `_ready()`, as a coroutine:
   - `fx.slash`, `fx.ring`, `fx.telegraph` (all three shapes), `fx.beam` (then
     `release_beam` after the wait), `fx.number`, `fx.burst`, `fx.puff`,
     `fx.bone_burst`, `fx.embers_at`, `fx.flare`, `fx.flash_light`,
     `fx.lightning` — all at a point 3 m in front of the hero.
   - `spawn_proj` once per kind (`arrow`, `bolt`, `fireball`, `spear`, `wave`)
     with zero velocity and `{"life": 0.05}`.
   - One `Enemy` of each kind (+ one elite) placed in view, and one `Boss`;
     after the wait, `queue_free()` them and remove them from `foes`
     (don't count kills).
   - Wait 3 frames (`await get_tree().process_frame`), clean up, then fade the
     curtain out over 0.3 s and only then start the director (set a
     `_warming := true` flag that makes `_direct()` return early).
3. Skip the warm-up when `bot` is true (headless has no renderer).

Verify: `tools/dev/shots.sh hunt`; nothing left over from the warm-up is
visible, kills and souls start at 0, the curtain is gone. `check.sh` passes.

### [ ] 2.3 Target marker and enemy stagger

Files: `src/hunt/hero.gd`, `src/hunt/enemy.gd`, `src/hunt/fx.gd`.

- Target marker: a small red ring (reuse `hero_ring.gdshader` with a
  `ShaderMaterial` whose `color` is `Color(1, 0.3, 0.25)` and size 1.2) that
  sits under `hero.target` while `aim_hold > 0` and the target is alive. One
  node, moved each frame; hidden otherwise.
- Stagger: in `Hunt.damage_foe`, if the foe is an `Enemy`, not elite, kind
  `minion` or `rogue`, and `state == "chase"`, play `def["anim"]["hit"]` with
  `play(..., 0.05, 1.6, true)` and set a `hit_t = 0.18` during which `_chase`
  doesn't move it. Warriors, mages, elites and the boss never stagger.

Verify: `tools/dev/shots.sh film` (6 frames ~0.13 s apart). The ring is under
the enemy being hit; minions visibly react.

### [ ] 2.4 Damage-number merging and a kill-streak counter

Files: `src/hunt/fx.gd`, `src/hunt/hunt.gd`, `src/ui/hud.gd`/`.tscn`.

- Numbers: keep a Dictionary `actor -> {label, total, t}`. A hit within 0.3 s
  of the previous one on the same actor adds to the total and re-pops the
  same label instead of spawning another. Crits still get their own number.
- Massacre (Diablo's kill streak): count kills; reset if 2.5 s pass with no
  kill. At 15/30/50/100 show a HUD streak label ("Massacre ×30") near the
  top-right under the clock, and grant bonus souls (`run_xp += streak / 3`)
  and gold. Data in `db.gd`: `const STREAKS := [15, 30, 50, 100]`.

Verify: `tools/dev/shots.sh hunt`. Fewer stacked numbers around the hero.

### [ ] 2.5 Audio buses and ducking

Files: new `default_bus_layout.tres` (buses `Master`, `Music`, `SFX`; a
`AudioEffectLowPassFilter` on `Music`, disabled by default), `src/autoload/sfx.gd`
(players use bus `SFX`/`Music`; volume sliders set bus volumes instead of
per-player `volume_db`), `src/ui/hud.gd` (enable the low-pass while the
level-up or pause menu is open, cutoff 900 Hz; disable on close).

Write the `.tres` with `AudioServer` in a small `tools/build_buses.gd` script
(same pattern as `build_theme.gd`) rather than by hand.

Verify: compile check; bot run still passes. Mention in the commit that it
can't be heard here.

### [ ] 2.6 Boss stall guard

File: `src/hunt/boss.gd`.

If the fight lasts more than 150 s (track time from the end of the intro),
the King goes berserk: `banner("Gravemaw grows impatient")`, damage ×1.5,
speed ×1.3, cooldowns ×0.7. Prevents endless kiting fights (seen with the bot).

Verify: `check.sh`.

---

## Phase 3 — More to do in a hunt

### [ ] 3.1 The Grave Robber (treasure goblin)

Files: `src/data/db.gd` (`ENEMIES["robber"]`: model `Skeleton_Rogue`, no
weapon, hp 260, speed 6.2, ai `flee`, xp 10), `src/hunt/enemy.gd` (an `ai ==
"flee"` branch in `_chase`: run directly away from the hero, steer around
walls with `arena.resolve`, slow down by 20% every 4 s; after 16 s alive it
digs back into the ground with a puff and is gone), `src/hunt/hunt.gd`.

- 30% of hunts: when progress first passes 0.4, spawn one 9–12 m away with a
  banner "A Grave Robber!" and a sound (`roar` at pitch 1.6).
- Carry a sack: attach `res://assets/kaykit/dungeon/coin_stack_small.gltf` to
  its back (`BoneAttachment3D` on bone `chest`). Gold tint via `set_tint`.
- Each time it's hit, drop 1–2 gold pickups. On death: 25 gold pickups, two
  items rolled with source `"elite"` and one at least rare, a big beam.

Verify: add a capture shot `robber` that forces the spawn; `shots.sh robber`.

### [ ] 3.2 Shrines

Files: `src/hunt/arena.gd` (record shrine positions; place 2 more
`shrine_candles.gltf` so there are three), `src/hunt/hunt.gd`, `src/data/db.gd`
(`SHRINES := {"fury": {"name": "Shrine of Fury", "dmg": 1.5}, "haste":
{"name": "Shrine of Haste", "rate": 1.4, "speed": 1.2}, "ward": {"name":
"Shrine of Bones", "armor": 0.35}}`).

- Each shrine gets a random blessing at hunt start, a colored glow (an
  OmniLight with the blessing color) and a ring on the ground.
- Standing within 1.6 m for 1.5 s (show a fill ring) activates it once: 20 s
  buff applied in `Hero.recompute()` via a `buffs` Dictionary with expiry,
  banner with the shrine's name, the light goes out.
- HUD: a small buff icon with a shrinking ring next to the level chip.

Verify: a capture shot that walks the hero to a shrine (`--shots=shrine`).

### [ ] 3.3 Card evolutions

Files: `src/data/db.gd`, `src/hunt/hunt.gd` (`roll_cards`), `src/hunt/hero.gd`.

`const EVOLUTIONS := {"bladestorm": {"from": ["blades", "haste"], "name":
"Bladestorm", "desc": "Twice the blades, twice as fast", "icon":
"spinning-sword"}, "tempest": {"from": ["storm", "crit"], ...}, "inferno_heart":
{"from": ["nova", "vigor"], ...}, "rain": {"from": ["multishot", "pierce"],
"only": ["bow"], ...}, "judgement_day": {"from": ["wave", "reach"], "only":
["melee"], ...}}`.

- An evolution is offered (rarity `legendary`, gold frame) when the first card
  of its pair is at max and the second is owned. Once taken, it's never offered
  again, and the base card's level stays.
- Effects in `Hero._tick_cards`: Bladestorm = blade count ×2 and rotation speed
  ×1.6; Tempest = storm jumps +3, every crit has a 20% chance to call a strike;
  Inferno Heart = nova radius +50% and heals 3% max HP per enemy hit (cap
  10%/pulse); Rain = every 3rd volley fires a full circle; Judgement Day =
  waves are twice as wide and stun 0.5 s.
- `levelup.gd`: evolution cards get an extra "EVOLUTION" caption.

Verify: a capture shot `evolve` that grants the prerequisite cards and calls
`_offer_cards()`. Read it: the evolution card is in the offer.

### [ ] 3.4 Elite affixes you can see

Files: `src/hunt/enemy.gd`, `src/hunt/fx.gd`, `src/hunt/hunt.gd`.

- Warded: a translucent sphere (same shader approach as the hero's ward in
  `hero.gd`) that absorbs the first 25% of its HP, then shatters with a burst
  (replace the flat 35% reduction).
- Molten: every 0.6 s while moving, leave a small fire patch (orange ring
  telegraph at 100% fill, radius 0.9, lasts 3 s) that hurts the hero for
  `dmg * 0.25`/s inside it.
- Vampiric: when it hits the hero, draw a short red lightning line (`fx.lightning`
  with red) from hero to elite.
- Swift: leave `fx.puff` dust behind every 0.2 s while running.

Verify: a capture shot `elites` that spawns one elite per affix near the hero.

### [ ] 3.5 Two new enemy types

File: `src/data/db.gd` (data), `src/hunt/enemy.gd` (behavior), `src/hunt/hunt.gd`
(`_pick_kind` weights).

- `bomber`: `Skeleton_Minion` holding
  `res://assets/kaykit/graveyard/pumpkin_orange_jackolantern.gltf` in
  `handslot.r`, tinted orange, speed 4.2, hp 20. Runs at the hero; at 1.4 m it
  stops, shows a 0.7 s circle telegraph (r 2.2) and explodes (kills itself,
  damages anything in the circle, including other skeletons). Appears from
  progress 0.3.
- `necro`: `Skeleton_Mage` with a purple tint, keeps 9 m away, every 7 s raises
  3 minions around itself (`spawn_foe`), max 2 necros alive. Appears from
  progress 0.55. Champions should prefer to be necros sometimes.

Verify: shots `hunt` late in a run (or a forced spawn shot); `check.sh` still
wins for knight/mage/barbarian.

### [ ] 3.6 Pacing: surges and breathers

File: `src/hunt/hunt.gd` (`_direct`).

Today the horde grows smoothly. Make it breathe: at progress 0.25, 0.5 and
0.75, "The graves open!" — a banner, then a ring of 10–14 enemies spawning
8–10 m around the hero over 2 s. After each surge, spawn rate drops to half for
8 s. Keep `MAX_FOES` as the hard cap.

Verify: bot runs still clear in 90–200 s (`check.sh` prints times).

---

## Phase 4 — Camp and progression

### [ ] 4.1 Real hero portraits

Files: new `src/ui/portraits.gd` (`class_name Portraits`, static cache),
`src/ui/hud.gd` (medal), `src/lobby/lobby_ui.gd` (roster tiles, chest shard
cards).

Render each hero once into a texture: a `SubViewport` (256×256,
`transparent_bg = true`, `own_world_3d = true`, `render_target_update_mode =
UPDATE_ONCE`) holding the hero (`Actor.build_model`, idle pose), a key light, a
rim light and a camera framing head and shoulders (see the `icon` capture in
`main.gd` for framing). Wait two frames, copy
`viewport.get_texture().get_image()` into an `ImageTexture`, free the viewport.
Generate all four on the first call (from the lobby's `_ready`), then serve from
the cache. Fall back to the current icon when running headless.

Verify: `tools/dev/shots.sh lobby,heroes,hunt`; portraits in the roster and HUD
medal.

### [ ] 4.2 Daily bounties

Files: `src/data/db.gd` (`BOUNTY_POOL`: kill N skeletons, slay N champions,
win with hero X, clear Veteran, collect N gold, reach run level N — each with a
reward of gold or shards), `src/autoload/game.gd` (`data["bounties"] = {"day":
"", "list": []}` in `_fresh()`; `refresh_bounties()` picks 3 when the local date
(`Time.get_date_string_from_system()`) changed; progress updated in
`finish_hunt()`; `claim_bounty(i)`), `src/lobby/lobby_ui.gd` + `.tscn` (a
"Bounties" nav button with a dot when one is claimable; a sheet listing the
three with progress bars and Claim buttons).

Verify: shots `lobby` and a new `bounties` sheet shot. Write a short unit check
in `--test` (task 6.2) for day rollover.

### [ ] 4.3 Gear compare and gear visuals (superseded by Phase G — skip)

Files: `src/lobby/lobby_ui.gd` (`_item_card`), `src/hunt/hero.gd` and
`src/lobby/lobby.gd` (show_hero).

- In the bag, under each unequipped item, list stat deltas against what the
  current hero wears in that slot: green `▲ +6% damage`, red `▼ −3% health`.
- The hero's weapon mesh glows with the equipped weapon's rarity color (a
  faint rim via `set_instance_shader_parameter("tint", ...)` on the weapon's
  mesh instances only, alpha 0.35; legendary 0.6).

Verify: shots `bag,lobby`.

### [ ] 4.4 Results screen count-ups

File: `src/ui/results.gd`.

Gold and each skill's XP count up over 0.8 s (tween a number and set text each
step), skill bars fill from the old value to the new, and level-ups flash. Play
`coin` ticks while gold counts. Keep the Continue button hidden until the count
finishes (tap anywhere skips to the end).

Verify: shot `results` (after the count) — final numbers match today's.

### [ ] 4.5 Level-up reroll

Files: `src/hunt/hunt.gd`, `src/ui/levelup.gd`/`.tscn`.

One free reroll per hunt (two on Nightmare): a Ghost button under the cards,
"Reroll (1)". Rerolls draw three new cards excluding the ones just shown.

Verify: shot `levelup`.

---

## Phase 5 — A second zone (large; split into sub-commits)

Do this only after phases 1–4. Keep the Barrow exactly as it is.

### [ ] 5.1 Zones as data

Files: `src/data/db.gd` (`ZONES := {"barrow": {...}, "depths": {...}}` with
name, enemy weights, boss id, music, souls multiplier, unlock rule),
`src/hunt/arena.gd` (move today's layout into `_layout_barrow()`; `build()`
takes a zone id), `src/hunt/hunt.gd` (read the zone), `src/autoload/game.gd`
(`data["zone"]`, unlocked zones).

No visible change yet. Verify: `check.sh` passes, shots identical to before.

### [ ] 5.2 The Sunken Crypt (indoor zone)

File: `src/hunt/arena.gd` (`_layout_depths()`).

Build a 40×52 m dungeon from `assets/kaykit/dungeon/` floor and wall tiles
(`floor_tile_large.gltf`, `wall.gltf`, `wall_corner.gltf`, `pillar.gltf`,
`torch_mounted.gltf`, `barrel_*`, `rubble_*`, `banner_*`, `candle_*`). Rooms
joined by wide corridors (≥ 6 m, the horde needs space), torches with warm
OmniLights (≤ 12 total), a ritual chamber in the north for the boss. Walls are
obstacles. Darker ambient than the Barrow; no moon (use a dim cold
DirectionalLight from above for shadows).

Verify: shots `hunt` with the zone forced via a capture arg `--zone=depths`.

### [ ] 5.3 Second boss: the Hexer Queen

Files: `src/data/db.gd` (`BOSSES` dict; move `BOSS` into it), new
`src/hunt/boss_hexer.gd` extending `Boss` (override `_choose`/`_begin`/
`_tick_pattern`), `src/hunt/hunt.gd` (instantiate by zone).

`Skeleton_Mage` at scale 2.4 with purple rim and eyes. Patterns: orbiting bone
orbs (6 projectiles circling her, released outward), summoning circles (three
circle telegraphs that spawn minions if not stood in), blink (vanish in a puff,
reappear 8 m away with a ring), curse lane (a lane telegraph that slows the
hero 40% for 3 s if hit). Enrage at 50%: orbs ×2.

Verify: a `boss` shot in the depths zone; `check.sh` with a new bot line
`--zone=depths` for knight and mage.

### [ ] 5.4 Zone choice in camp

Files: `src/lobby/lobby_ui.gd` + `.tscn`: above the tier row, a zone picker
(two cards with the zone name, boss name and a lock showing the unlock rule).
The Sunken Crypt unlocks after the first Veteran clear of the Barrow.

Verify: shot `lobby`.

---

## Phase 6 — Housekeeping

### [ ] 6.1 Remove `_legacy/` (ask the user first)

Only when the user confirms: `git rm -r _legacy`. Keep `docs/ota.md`. Update
`README.md` (the "old project" section) and `CREDITS.md` (it points at
`_legacy/tools/` for the audio build scripts — move the two audio scripts the
credits mention into `tools/audio/` first if the user wants to keep them).

### [ ] 6.2 Unit checks (`--test` mode)

File: `src/main.gd` (add `--test` like `--check`), new `src/tests.gd`.

Assert, printing `TEST <name> OK/FAIL`, exit code non-zero on failure:
`DB.xp_for_level(2) == 83`, `DB.xp_for_level(99) == 13034431`,
`DB.combat_level` of a fresh account == 3, `Game.hero_stats` scales by 9% per
level, `Game.roll_rarity("boss")` never returns common over 2000 rolls,
`Game.open_chest` adds gold, a save round-trip (`JSON` stringify/parse of
`Game.data` equals the original), bounty day rollover (after 4.2). Add the
`--test` run to `tools/dev/check.sh` and `.github/workflows/checks.yml`.

### [ ] 6.3 Performance budget in captures

File: `src/main.gd` (`_save`). If a hunt shot reports more than 700 draw calls
or 400k triangles, print `BUDGET WARNING` with the numbers. Mention any warning
in the task's reply.

### [ ] 6.4 Bot improvements

File: `src/hunt/bot.gd`. Ranged heroes: collect souls when no enemy is within
5 m; kite in a circle around the arena center instead of straight away. Goal:
the Ranger wins ≥ 3 of 4 bot runs on Normal. Then add `ranger` to the CI bot
line in `.github/workflows/checks.yml`.

---

## Notes for the next task

(Append here when a task leaves something unfinished.)
