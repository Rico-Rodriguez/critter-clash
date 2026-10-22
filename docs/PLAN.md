# Gravelight — next work plan

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
7. Never push to `main` unless the user says so.

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

### [x] 1.4 Camera distance setting

Files: `src/autoload/game.gd` (`_fresh()` settings: add `"camera": "standard"`),
`src/ui/settings_box.gd` (add a row like the Graphics row with three toggle
buttons `Close / Standard / Wide`), `src/hunt/hunt.gd` (`_ready()`: set
`cam.dist_mult` from the setting: close 0.86, standard 1.0, wide 1.16).

Verify: `tools/dev/shots.sh settings`; the row is there and matches the
Graphics row's style.

### [x] 1.5 Hidden dev tuning panel (so the user can tune on the phone)

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

### [x] 1.6 Camp camera polish

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

### [x] A.1 Research and shortlist (no code)

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

> **Done:** see `docs/art-options.md`. Finding: no free pack covers the whole
> cast in a realistic style (free Quaternius outfits are Ranger + Peasant only;
> Mixamo is the only full-cast route and has a redistribution catch). The
> KayKit **grit pass** (smaller heads via `src/core/bone_scaler.gd`, darker
> desaturated palette and dirt in `src/fx/char.gdshader`) was built as the
> fallback and ships now; tune `desat`, `darken`, `grime` there. A.2 and A.3
> (swapping in a different pack) still wait for the user's choice.

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

### [x] G.1 Visible gear

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

### [x] G.2 Slots

Go from 3 slots to 5: weapon, helm, chest, gloves/legs (whatever the art
supports), trinket. Migration: existing `armor` items become `chest`. Add the
new keys to `Game._fresh()` and convert old saves in `load_save()` (bump
`SAVE_VERSION` to 2 and write a `_migrate_v1()`; never drop items).

### [x] G.3 Paper-doll equipment screen

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

### [x] G.4 In-hunt pickup feedback

When you walk over an item, the toast shows the item's name, rarity and "▲
upgrade" if it beats your equipped piece, so loot feels meaningful in the
moment. In results, upgrades are marked the same way, with an "Equip" button
per upgrade.

> **Done with KayKit.** Models aren't modular, so gear shows as: weapon model
> and size by rarity (unique looks via `look` in `DB.UNIQUES`), a rarity glow
> on the body parts each piece covers, and a glowing belt charm for the
> trinket (`src/core/gear_look.gd`). A modular art pack would only replace that
> file's internals. The equipment screen is `src/lobby/equipment.gd`.

Verify (whole phase): shots `lobby,heroes,bag` plus a new `equip` shot that
opens the equipment screen with a demo inventory (extend `_capture` in
`main.gd`). The hero in the lobby must visibly change when gear changes —
take a shot before and after equipping a legendary.

Note: task 4.3 (gear compare and glow) is superseded by this phase; skip it.

---

## Phase 2 — Feel and readability

### [x] 2.1 Haptics

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

### [x] 2.2 Shader and effect warm-up (removes first-use stutter on phones)

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

### [x] 2.3 Target marker and enemy stagger

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

### [x] 2.4 Damage-number merging and a kill-streak counter

Files: `src/hunt/fx.gd`, `src/hunt/hunt.gd`, `src/ui/hud.gd`/`.tscn`.

- Numbers: keep a Dictionary `actor -> {label, total, t}`. A hit within 0.3 s
  of the previous one on the same actor adds to the total and re-pops the
  same label instead of spawning another. Crits still get their own number.
- Massacre (Diablo's kill streak): count kills; reset if 2.5 s pass with no
  kill. At 15/30/50/100 show a HUD streak label ("Massacre ×30") near the
  top-right under the clock, and grant bonus souls (`run_xp += streak / 3`)
  and gold. Data in `db.gd`: `const STREAKS := [15, 30, 50, 100]`.

Verify: `tools/dev/shots.sh hunt`. Fewer stacked numbers around the hero.

### [x] 2.5 Audio buses and ducking

Files: new `default_bus_layout.tres` (buses `Master`, `Music`, `SFX`; a
`AudioEffectLowPassFilter` on `Music`, disabled by default), `src/autoload/sfx.gd`
(players use bus `SFX`/`Music`; volume sliders set bus volumes instead of
per-player `volume_db`), `src/ui/hud.gd` (enable the low-pass while the
level-up or pause menu is open, cutoff 900 Hz; disable on close).

Write the `.tres` with `AudioServer` in a small `tools/build_buses.gd` script
(same pattern as `build_theme.gd`) rather than by hand.

Verify: compile check; bot run still passes. Mention in the commit that it
can't be heard here.

### [x] 2.6 Boss stall guard

File: `src/hunt/boss.gd`.

If the fight lasts more than 150 s (track time from the end of the intro),
the King goes berserk: `banner("Gravemaw grows impatient")`, damage ×1.5,
speed ×1.3, cooldowns ×0.7. Prevents endless kiting fights (seen with the bot).

Verify: `check.sh`.

---

## Phase 3 — More to do in a hunt

### [x] 3.1 The Grave Robber (treasure goblin)

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

### [x] 3.2 Shrines

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

### [x] 3.3 Card evolutions

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

### [x] 3.4 Elite affixes you can see

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

### [x] 3.5 Two new enemy types

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

### [x] 3.6 Pacing: surges and breathers

File: `src/hunt/hunt.gd` (`_direct`).

Today the horde grows smoothly. Make it breathe: at progress 0.25, 0.5 and
0.75, "The graves open!" — a banner, then a ring of 10–14 enemies spawning
8–10 m around the hero over 2 s. After each surge, spawn rate drops to half for
8 s. Keep `MAX_FOES` as the hard cap.

Verify: bot runs still clear in 90–200 s (`check.sh` prints times).

---

## Phase 4 — Camp and progression

### [x] 4.1 Real hero portraits

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

### [x] 4.2 Daily bounties

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

### [x] 4.4 Results screen count-ups

File: `src/ui/results.gd`.

Gold and each skill's XP count up over 0.8 s (tween a number and set text each
step), skill bars fill from the old value to the new, and level-ups flash. Play
`coin` ticks while gold counts. Keep the Continue button hidden until the count
finishes (tap anywhere skips to the end).

Verify: shot `results` (after the count) — final numbers match today's.

### [x] 4.5 Level-up reroll

Files: `src/hunt/hunt.gd`, `src/ui/levelup.gd`/`.tscn`.

One free reroll per hunt (two on Nightmare): a Ghost button under the cards,
"Reroll (1)". Rerolls draw three new cards excluding the ones just shown.

Verify: shot `levelup`.

---

## Phase 5 — A second zone (large; split into sub-commits)

Do this only after phases 1–4. Keep the Barrow exactly as it is.

### [x] 5.1 Zones as data

Files: `src/data/db.gd` (`ZONES := {"barrow": {...}, "depths": {...}}` with
name, enemy weights, boss id, music, souls multiplier, unlock rule),
`src/hunt/arena.gd` (move today's layout into `_layout_barrow()`; `build()`
takes a zone id), `src/hunt/hunt.gd` (read the zone), `src/autoload/game.gd`
(`data["zone"]`, unlocked zones).

No visible change yet. Verify: `check.sh` passes, shots identical to before.

### [x] 5.2 The Sunken Crypt (indoor zone)

File: `src/hunt/arena.gd` (`_layout_depths()`).

Build a 40×52 m dungeon from `assets/kaykit/dungeon/` floor and wall tiles
(`floor_tile_large.gltf`, `wall.gltf`, `wall_corner.gltf`, `pillar.gltf`,
`torch_mounted.gltf`, `barrel_*`, `rubble_*`, `banner_*`, `candle_*`). Rooms
joined by wide corridors (≥ 6 m, the horde needs space), torches with warm
OmniLights (≤ 12 total), a ritual chamber in the north for the boss. Walls are
obstacles. Darker ambient than the Barrow; no moon (use a dim cold
DirectionalLight from above for shadows).

Verify: shots `hunt` with the zone forced via a capture arg `--zone=depths`.

### [x] 5.3 Second boss: the Hexer Queen

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

### [x] 5.4 Zone choice in camp

Files: `src/lobby/lobby_ui.gd` + `.tscn`: above the tier row, a zone picker
(two cards with the zone name, boss name and a lock showing the unlock rule).
The Sunken Crypt unlocks after the first Veteran clear of the Barrow.

Verify: shot `lobby`.

---

## Phase 6 — Housekeeping

### [x] 6.1 Remove `_legacy/` (done at the user's request)

Only when the user confirms: `git rm -r _legacy`. Keep `docs/ota.md`. Update
`README.md` (the "old project" section) and `CREDITS.md` (it points at
`_legacy/tools/` for the audio build scripts — move the two audio scripts the
credits mention into `tools/audio/` first if the user wants to keep them).

### [x] 6.2 Unit checks (`--test` mode)

File: `src/main.gd` (add `--test` like `--check`), new `src/tests.gd`.

Assert, printing `TEST <name> OK/FAIL`, exit code non-zero on failure:
`DB.xp_for_level(2) == 83`, `DB.xp_for_level(99) == 13034431`,
`DB.combat_level` of a fresh account == 3, `Game.hero_stats` scales by 9% per
level, `Game.roll_rarity("boss")` never returns common over 2000 rolls,
`Game.open_chest` adds gold, a save round-trip (`JSON` stringify/parse of
`Game.data` equals the original), bounty day rollover (after 4.2). Add the
`--test` run to `tools/dev/check.sh` and `.github/workflows/checks.yml`.

### [x] 6.3 Performance budget in captures

File: `src/main.gd` (`_save`). If a hunt shot reports more than 700 draw calls
or 400k triangles, print `BUDGET WARNING` with the numbers. Mention any warning
in the task's reply.

### [x] 6.4 Bot improvements

File: `src/hunt/bot.gd`. Ranged heroes: collect souls when no enemy is within
5 m; kite in a circle around the arena center instead of straight away. Goal:
the Ranger wins ≥ 3 of 4 bot runs on Normal. Then add `ranger` to the CI bot
line in `.github/workflows/checks.yml`.

---

## Phase 8 — Gear that shows, a harder hunt, the Long Road (user feedback, round 3)

Feedback: gear did not feel special or show on the model; the equipment screen
made changes hard to see and could not be turned; the hunt was too easy to
kite; some screens clipped at the top of an iPhone; level-up cards loaded
slowly now and then; abilities should be unique per class (lightning, meteors,
never spinning swords for a mage); and a second mode, a procedural trail to a
boss.

### [x] 8.1 Gear v2
Class-specific gear with seven material tiers (Bronze..Dragon, Leather..Black
Dragonhide, Novice..Eldritch). Every piece is {slot, cls, mat, rarity}; looks come
from `src/data/gear_db.gd`, never from the save. Parts are lifted from other
KayKit characters onto the hero (`src/core/gear_look.gd`) and dyed
(`dye` instance uniform in `char.gdshader`). Heroes start as a plain man in a tunic
with a starter weapon. Skill requirements gate tiers (Defence, Attack, Ranged,
Magic). Drops are for the hero you play (65%), harder content drops better
metal. Save version 3 migrates old items.

### [x] 8.2 Equipment screen
Big spinnable hero (drag), slots either side, the bag below, try-on preview,
"Others" tab for other heroes' gear. Safe-area bug fixed in `Ui.apply_safe_area`
(it read the viewport of a node not yet in the tree).

### [x] 8.3 UI polish
`--notch` capture flag simulates an iPhone's insets; menu sheets keep clear of
the home bar; the level-up cards are drawn once behind the curtain at hunt
start so the first level-up does not compile shaders.

### [x] 8.4 A harder hunt
Tier scaling (health, damage, speed, pressure), Grave Hounds (lunge) and Bone
Brutes (slam), enemies lead their target and fan out, packs sometimes wait
ahead of a running hero, bosses call a court of the dead and go berserk sooner.

### [x] 8.5 Class powers and sky VFX
Each hero has its own signature cards: Knight Holy Smite, Barbarian Earthshaker
and Thrown Axes, Mage Meteor Shower and Frost Ring, Ranger Arrow Storm and
Explosive Arrows, each with a legendary evolution. Mage super is Meteor Storm;
Knight's Judgement calls lightning; Ranger's volley rains arrows. `Fx.sky_bolt`
and `Fx.fall` are the shared sky effects.

### [x] 8.6 The Long Road
A mode picker in camp. A seed builds a long dungeon of rooms divided by walls
with a gap (`src/hunt/arena_trial.gd`); rooms hold an ambush, horde, hunters,
brutes, a champion, a shrine or guarded treasure; the way on is sealed until
the room is clear; the boss waits at the end. The autopilot plays it
(`--bot --mode=trial`).

## Phase 9 — UI and UX pass (user feedback, round 4)

Feedback: the camp screen is cluttered, the hunt HUD is cluttered, and the
equipment screen is not clear. The full review, with the reasons behind each
task, is `docs/review-ux-and-depth.md` (Part 1). Take every shot at
`720x1560` with `--notch` (run `tools/dev/godot-gpu.sh --resolution 720x1560
--fixed-fps 30 -- --capture --notch --shots=... --out=$PWD/shots`).

### [x] 9.1 Camp: one expedition card, bounties on the home screen
Mode, location and difficulty rows replaced by one `Expedition` card (theme
`CardButton`) that opens an Expedition sheet (`_build_expedition` in
`lobby_ui.gd`): one card per choice with what it means, or how to unlock it.
Bounties moved from the tab bar to a round button with a red `Badge` count and
"Bounties n / 3". Tab bar: Heroes, Gear, Skills, Log. Red `Badge` dots replace
the green squares. New capture shot: `expedition`.

### [x] 9.2 HUD: streak and blessings inside the safe area
Bug: under a notch the kill-streak label covered the pause button and clock.
The streak and shrine-buff labels now sit in a row inside `%Safe/Top`.

### [x] 9.3 HUD: one bar at the top, HP on the hero
Done. The health bar is a HUD control that follows the hero's feet
(`HeroBar`, projected each frame); XP is `XpRing` around the portrait; the top
strip is portrait, one objective-or-boss bar, pause/clock/gold. The left-edge
`Hud.event()` feed carries the kill streak and blessing timers (shrine and
massacre banners became events). The stick ghost is hidden after the tutorial.
Original spec, kept for reference:
Files: `src/ui/hud.tscn` + `hud.gd`, `src/hunt/hero.gd`.
- A world-space HP bar under the hero (a `Sprite3D` or `SubViewport`-free
  quad with a shader; one node, moved with the hero) with the run level as a
  chip at its left end. Remove `HPWrap` from the top row.
- XP becomes a ring around the portrait medal (a `TextureProgressBar` with a
  ring texture, or a shader on `Medal`). Remove the XP row; gold moves to a
  chip under the clock.
- The top strip is `[portrait+XP ring] [objective bar] [pause / clock]`. The
  boss bar replaces the objective bar in the same spot.
- An event feed on the left edge (VBox, max 3 rows, icon + short text, fades
  after 2 s) takes the streak, shrine and champion messages. `banner()` stays
  for: champion rises, boss wakes, room clear, victory.
- Joystick ghost only while the tutorial flag is unset or a finger is down.
Verify: shots `hunt,boss,shrine` at 720x1560 `--notch`. Nothing but the
objective/boss bar and the event feed sits between the top strip and the hero.

### [x] 9.4 Gear screen: rarity is the only color, item power on every tile
Done, with two changes from the spec: the details panel is a fixed-height card
under the hero (so the 3D hero never resizes) rather than a bottom sheet, and
the layout is still code-built (moving it to a `.tscn` was left out).
`Game.hero_stats(id, preview)` powers the before/after strip; `Game.item_power`
is the tile number; "Requires Attack 20" wording. Original spec:
Files: `src/lobby/equipment.gd` (move layout into a new `equipment.tscn`
while here), `src/data/db.gd`, `src/data/gear_db.gd`.
- Tile: frame + soft background in the rarity color; icon in one neutral
  tone; under it the tier tag ("T4 · Mithril"); top-right the item power, or a
  green "▲ 42" (score gain) when it beats what is worn. Locked tiles say the
  requirement in red ("Attack 20").
- "New": one red `Badge` dot, cleared when that slot filter is opened.
- Slot naming: `trinket` is shown as "Offhand" with the shield icon
  everywhere (`DB.SLOT_NAME`, `DB.SLOT_ICON`, the filter row, the Heroes sheet).
- A stat strip under the name (Health, Damage, Armor, Attack speed) that shows
  `33 → 41 ▲` while an item is selected.
- Item details open as a bottom sheet over the bag; the 3D hero never resizes.
- "Requires Attack 20" wording; "Other heroes" tab hidden when empty; "14 / 48"
  bag count by the filters.
Verify: shots `equip,equipdetail`. Read them and check every tile's color
matches its rarity and the selected item's stat deltas are visible.

### [x] 9.5 Heroes sheet and sheet sizes
Done (sheets size to content up to the cap, with a bottom fade hint). Spec:
Files: `src/lobby/lobby_ui.gd`, `src/lobby/sheet.gd`.
- Shard bar: "Ready" (gold fill) when shards ≥ cost; never "9 / 6".
- Replace the gear circles with "Gear power N · 3 / 5 slots" and a link.
- Roster tiles: power number and a red `Badge` on a hero that can level up.
- `Sheet.open` sizes the panel to its content, capped at 0.86 of the screen.
- Collection log: scroll hint (fade at the bottom edge) when content overflows.
Verify: shots `heroes,bounties,skills,log`.

### [x] 9.6 Camp follow-ups
Done. The profile chip opens Skills, a quick tap on the hero opens the roster
(swipe still turns the hero), the chest sits on the rail with a pulse. Spec:
- Profile chip (portrait + combat level) top-left opens Skills and Log.
- Tapping the hero (or swiping) opens the roster.
- Pending chest: a chest slot on a right-side rail instead of a full-width
  button that pushes the layout. Center the chest-open prompt.
Verify: shots `lobby,chest`.

---

## Phase 10 — Depth (proposals; ask the user before starting each)

The reasoning and the details are in `docs/review-ux-and-depth.md`, Part 2.
Each item needs its own short plan (files, data, save keys with defaults in
`Game._fresh()`) before code. Recommended order:

- [x] 10.1 **Talent trees** (eight nodes per path, `HERO_MAX_LEVEL` 20, `TalentDB`): three paths per hero, a point per hero level
  (`HERO_MAX_LEVEL` 10 → 30), minor / notable / keystone nodes, free respec.
- [x] 10.2 **Endless Descent**: horde without end, depth rises every 60 s,
  personal best per hero.
- [x] 10.3 **Boss Rush**: every boss in a row, card pick between fights,
  best time.
- [-] 10.4 **Prayer** (skipped on request): bury bones, unlock OSRS prayers, take 1–2 into a hunt.
- [-] 10.5 **Slayer** (skipped on request): tasks from a Slayer Master, points for unlocks and
  superior foes.
- [-] 10.6 **Smithing** (skipped on request): smelt gear into bars, smith or reforge pieces.
- [x] 10.7 **Renown road**: one progression track on the camp screen that
  hands out today's scattered unlocks in order.
- [x] 10.8 **Weekly Omen**: one rule twist a week, better chest.
- [x] 10.9 **Treasure Trails**: clue scroll drops with multi-step goals.
- [x] 10.10 **The Wilderness** (rivals are hero-built foes; no boss): Hunt Royale-style shared shrinking map with
  bot heroes.
- [x] In-run variety: cursed shrine, omen choice at 50% souls,
  five more elite affixes, a potion, one new boss pattern per tier.

### How Phase 10 was built (where to tune)

- **Talents:** `src/data/talent_db.gd` (nodes, effects), `Game._apply_talents`,
  flags read in `hunt.gd` (`execute`, `mark`, `critdmg`, `bloodlust`,
  `second_wind`). Save: `heroes[id].talents` = `["path.index", ...]`. Level
  past 10 is worth `DB.LEVEL_POWER_LATE` per level.
- **Modes:** `DB.MODES` / `MODE_ORDER`; `hunt.gd` has `_tick_depth`,
  `_direct_rush`, `_boss_down_midway`, `_tick_wild`. Descent and Boss Rush open
  after a Normal win (`Game.mode_unlocked`). Bests live in `stats.best`:
  `descent_<hero>`, `rush<tier>_<hero>`, `wildplace_<hero>`.
- **The Wilderness:** `DB.WILD_*` (ring keyframes, rival counts) and
  `DB.rival_def(hero)`; rivals are `Enemy` kinds `rival_<hero>` built from the
  hero model. The ring is a mesh plus a damage tick. No boss in this mode.
- **Pacts, cursed shrine, potion, affixes:** `DB.PACTS`, `DB.CURSE`,
  `DB.POTION`, `DB.ELITE_AFFIXES`; casts in `Enemy._tick_casts`, blasts and
  lances in `Hunt.blast_at` / `beam_from`. Veteran and Nightmare bosses gain a
  blast ring and a lance fan (`Boss._tick_tier_moves`).
- **Meta:** renown road (`DB.road_*`, `Game.claim_road`), weekly omen
  (`DB.WEEKLY_OMENS`, `Game.weekly_omen`, toggle in the Expedition sheet), clue
  scrolls (`DB.CLUE_GOALS`, `Game._clue_progress`, shown in the Log). New save
  keys: `renown`, `road`, `omen_on`, `clue`, per-hero `talents`.
- Open: all of this was tuned with the autopilot only. Talent numbers, the
  Wilderness rivals, Descent scaling and the potion need a playtest on a phone.

## Phase 11 — Premium feel, difficulty ladder, retention (done)

From `docs/audit-2026-10.md`. All of it shipped on the branch, plus a skill
pass the audit underrated: stacked gear and cards made every tier AFK-able.
See CHANGELOG 2026-10-24.

- [x] 11.0 Skill over stats: mechanics through armor (% of max health), grave
      eruptions, perfect dodge, steady aim, exposed bosses, armor curve, regen
      and leech caps, tier healing cuts, foes scale with the hunt's level
- [x] 11.1 Normal retune: boss HP +25%, 150 souls, first surge at 15%
- [x] 11.2 Shards go to the hero played (75%); recommended power on the card
- [x] 11.3 Results: Play again, skill XP bars, big chest, road bar, hero-named upgrades
- [x] 11.4 Victory set piece: buttons hide, flash, camera on the fall, loot vacuum, big labels
- [x] 11.5 Class starter outfits; Renown Road bar reads "0 / 60"
- [x] 11.6 Tall props fade; foreground band half-fades
- [x] 11.7 Eight-step tier ladder (Normal to Abyss); souls scale per tier
- [x] 11.8 Gold sinks: reforge, temper, paid respec, weapon glows
- [x] 11.9 Hero mastery, rating, first win of the day, login calendar, campfire
- [x] 11.10 Boss kill counts, dry streaks, Hexling pet
- [x] 11.11 Evolution at three stacks, banishes, signature legendaries, 4th card at 15
- [x] 11.12 Gear sets (Regalia, Raiment, Barkbound) and ancients
- [x] 11.13 Music: Descent, rift, Grove tracks; low-HP muffle
- [x] 11.14 Third zone: the Hollow Grove, the Grove Cult, the Thornmother
- [ ] 11.15 Game Center: blocked. The IPA is unsigned (AltStore); Game Center
      needs an App Store provisioned entitlement. Feats are local for now.
- [x] 11.16 Season track: free (no monetization in the game)

Also done: rifts (Descent keys), the ritual event, a mini-boss brute, Long Road
dark rooms / timed vaults / cursed altars, a companion hero, first-time tips,
gold count-up in camp, the Descent darkening with depth.

**Needs a human:** play Expert and up on a phone. The autopilot dodges
telegraphs perfectly but never perfect-dodges on purpose; real players will
find the eruption rate and the mechanic share either fair or too much. Tune
`DB.ERUPTION` and `TIERS[*].mech` first.

## Phase 12 — Playtest round 5: fixes, gear that shows its tier (done)

Feedback: "very fun now"; four bugs (campfire crash, Descent camera stuck after
a boss, difficulty unlocks shared across modes, bodies never despawn) and
"gear is so underwhelming; in OSRS gear looks so cool as you progress".
All in CHANGELOG 2026-10-25. Where to tune:
- Gear finish per material: `GearDB.GRADES` (polish, shimmer, veins, heat),
  `GearDB.ACCENTS` for dark materials, `GearDB.ENCHANT_FROM` for sparks and
  the full-set aura. The look itself is `src/fx/char.gdshader` (`grade`,
  `accent`). Shots: `--shots=icon --mat=N --hero=H`, `--shots=equip --mat=6`.
- Item icons now take their material's color (reverses 9.4's single neutral
  tone: the frame still carries rarity, the icon carries the metal).
- Bodies: `DB.CORPSE_LINGER`, `DB.CORPSE_MAX`. Per-mode tiers: save key
  `mode_tiers`, `Game.mode_tier_unlocked()`.
- Moments: `Hunt.super_moment()`, `Hunt._legendary_moment()`; shots `super`,
  `legendary`, `campfire`.

## Phase 13 — Gear variety, equipment screen, bigger supers (done)

Feedback: "the gear equipment menu is confusing, even to me", "even cooler
looking options: a bone staff, a different wizard outfit, a blacked-out
knight set... we want a lot more variety". All in CHANGELOG 2026-10-26.
Where to tune:
- Looks: `GearDB.LINES` stages and their `alts` (rolled per drop through the
  item's `look`), `GearDB.SET_LOOKS` (dye, accent, least grade, model per
  hero and slot), `GearDB.UNIQUE_LOOKS`, `GearDB.KITS` (props put together into
  one weapon), `GearDB.PART_NUDGE` (rigid parts that sit wrong on a living
  head). `GearDB.piece(it)` resolves them in that order.
- Shots: `--shots=sets` and `sets2` (contact sheets),
  `--shots=equip --hero=H --mat=N --set=hexer` or `--look=1`, `weapons`
  (now includes kits), `equipdetail`, `inspect`, `inspecthelm`, `reveal`,
  `super --hero=H --after=S`, `depth`.
- The KayKit **Fantasy Weapons Bits** pack is in `assets/kaykit/weapons/`
  (its files have letter suffixes: `hammer_A`, `sword_E`, `shield_C`...). Its
  bows lie along X, so they go through the `hunting_bow` and `recurve` kits,
  which turn them. Unused so far: `spear_A`, `dagger_A`/`dagger_B`, `staff_A`,
  the fist weapons and arrows. `--shots=arms --hero=H` lines up every weapon
  and offhand look in that hero's hands. The paid Mystery Monthly series 5 has a Black Knight character whose
  parts would slot straight into `GearDB` like any other KayKit character.

## Next up

**Feature freeze (since the release cleanup, CHANGELOG 2026-10-28).** No new
modes, zones, currencies, meta systems or card pools until real players have
played the build (items 1 and 2 below) and their feedback is written down
here. Allowed: bug fixes, tuning numbers in `db.gd`/`gear_db.gd`, readability
and feel, art that replaces existing art, performance, release work (signing,
TestFlight, store listing) and refactors that change no behavior. If the user
asks for a new system during the freeze, point at this note and ask once
whether to lift it.

Ordered. Do the first item before the rest: it is the only one that needs a
real phone. Everything else is tuned by the autopilot and by eye.

1. **Device check (blocking).** Install the build from `main`. Check, on an
   iPhone with a notch: the equipment screen top edge, the Heroes and Bag sheets
   near the home bar, level-up cards on the first level-up of a hunt, and that
   gear shows on the hero when equipped. Log what breaks as bugs under this item.
2. **Long Road playtest.** Play Normal, Veteran and Nightmare on the Long Road.
   Judge: room count, how long a room takes, whether the gates read clearly,
   whether the boss hall feels like a finale, and whether the loot is worth the
   walk. The autopilot only proves it can finish; it says nothing about fun.
3. ~~**Results screen: show the Long Road.**~~ Done: results show "The Long
   Road" and a Rooms 4 / 6 stat.
4. **Nightmare and Veteran balance.** The numbers in CHANGELOG 2026-10-22 came
   from autopilot runs only. Tune in `src/data/db.gd` `TIERS`. Watch Ranger on
   Trial: it has won on Normal but has not been tested on higher tiers.
5. ~~**UI polish pass.**~~ Phase 9 is done; it needs a look on a real phone.
6. **Difficulty and AI (task #13).** The complaint was that the hunt is brain
   dead. The autopilot still kites well. Ideas, in order of cost: foes that
   cut off retreat paths; a Nightmare-only fast hound pack; elites that
   pick a corner to trap the hero; fewer safe pockets on the map.
7. ~~**Remove the debug print.**~~ Done.
8. **Gear depth** (frozen except the reveal, which shipped). Set bonuses (two or three pieces of one class's line),
   per-tier drop tuning on the Long Road, and a gear reveal when a piece is
   first worn.
9. ~~**Modes after the Long Road.**~~ Frozen. Boss Rush shipped; the
   Royale-style mode from Phase 7 waits until after the freeze.
10. **Art (deferred).** A.2/A.3 (a different art pack) was skipped on purpose.
   Options are in `docs/art-options.md`. Only revisit if the KayKit look is the
   blocker after the device check.

Release rule: merge to `main` only when asked. A push to `main` builds the
IPA and ships an OTA content update to every installed copy.

---

## Phase 7 — Where it goes next (ideas, not tasks yet)

The Barrow and the Sunken Crypt are one mode: a timed horde hunt that ends in
a boss. It is a good start, but it is not what keeps people coming back. These
are the directions, roughly in the order they should be tried. Each needs its
own plan before anyone codes it; do not start one without asking.

### 7.1 The Long Road (trial mode)

The old game had a "trail" — walk a path, fight what is on it, reach a boss.
Rebuild it on the new engine: a run is five to seven short rooms (30–45 s
each, reuse `Hunt` with a `room` rule instead of a soul meter), a choice
between rooms (an altar for a blessing, a rest fire, a harder room for better
loot, a shop for gold), and a boss at the end. Cards and shrine buffs carry
through the run; death ends it and pays out by how far you got. This is the
Slay-the-Spire-meets-Hunt-Royale loop: every run different, every choice
meaningful, and runs are short enough for a bus ride.

Needs: `Hunt` split into "arena + rules" so a room can be a rule set;
a run map UI; per-run state kept outside `Hunt` so it survives rooms.

### 7.2 Royale hunt (Hunt Royale style)

Several heroes (you and 5–7 bots) share one big arena that shrinks. Everyone
fights the same horde for souls and loot; the last band standing or the first
to kill the boss wins. The existing `HuntBot` is the seed for the bot heroes.
Needs: a bigger arena (a third zone), a shrinking-zone hazard, bot heroes with
their own gear, and a placement reward. Only worth it once the core hunt feels
great; it is the biggest bet on this list.

### 7.3 Engagement ideas that fit the current hunt

- Weekly "mutator" hunt: one rule twist for everyone (double elites, no dash,
  arrows only) with a bigger reward; a banner in camp shows this week's rule.
- Boss rush: all bosses in a row with the same hero, no soul phase.
- Hero mastery: a per-hero track (kills, wins) that unlocks cosmetic weapon
  glows and a title under the name.
- A third zone and boss for each new KayKit pack that fits the palette
  (the Halloween bits and the forest are already imported).
- Gear sets: two or three pieces of the same set give a bonus; the Barrow set
  is the Gravemaw uniques, the Crypt set is the Hexer uniques.

---

## Notes for the next task

- Next up is at the top of this section. The change history is in CHANGELOG.md.
- Open: Veteran/Nightmare tuning (4).
