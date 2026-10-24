# Sidekick clip inventory and gaps

For Critter Clash Art. Read from each wrapped scene's `AnimationPlayer` on
main @ e8f9909 (after #58-#60). The game maps clips in
`src/data/sidekick_db.gd` `CLIPS` (keys: `idle`, `move`, `run`, `attack`,
`hit`, `special`). Any state without a clip falls back to a procedural pose
in `src/hunt/sidekick.gd` `pose()`: a lunge for attacks, a hop and spin for
specials, a recoil for hits, and a step bounce or breathing for movement and
rest. Nothing is blocked on these clips.

| Sidekick | Scene | Rig | Clips present (length) | Mapped now | Missing |
|---|---|---|---|---|---|
| Grave Wisp (`wisp`) | `sf:mawko` | 34 bones | Idle 7.67s, Walk 7.67s | idle, move | attack, hit, special (cast) |
| Ember Drake / Ash Wyrm (`drake`) | `sf:dragon` | 220 bones | Flying_Idle 13.12s, Fast_Flying 13.12s | idle, move | attack (bite or claw), hit, special (fire-breath pose) |
| Bonelet (`bonelet`) | `sf:skeleton` | 67 bones | Idle 3.33s, Walk 3.33s | idle, move | attack (throw), hit, special, run |
| Hexling (`hexling`) | `sf:lich` | 57 bones | Idle 5.00s, Walk 5.00s | idle, move | attack, hit, special (staff cast) |
| Acolyte (`acolyte`) | `sf:plague` | 46 bones | Idle 3.33s, Walk 3.33s | idle, move | attack, hit, special (ground slam/ward) |
| Storm Crow (`crow`) | `sf:crow` | 92 bones | Idle 7.00s, Fast_Flying 1.62s | idle, move | attack (peck/screech), hit, special |
| Gilded Mimic (`mimic`) | `sf:mimic` | none (node animation) | Bite_Front 3.00s, Idle 2.40s, Walk 0.80s | idle, move, attack | hit, special |
| Night Bat (`bat`) | `sf:bat` | 29 bones | Bat_Flying 2.25s | idle, move (same clip) | separate idle/hover, attack (dive bite), hit, special |
| Barrow Squire (`barrow_squire`) | `sf:squire` | 384 bones | Dead 1.00s, Idle 1.54s, Punch 1.21s, Run 0.83s, Walk 1.29s | idle, move, run, attack | hit, special (shield bash). `Dead` is not used. |
| Hexbound Shade (`shade`) | `sf:wraith` | 77 bones | Idle 2.08s, Walk 3.33s | idle, move | attack (strike), hit, special (blink) |
| Thorn Sapling (`sapling`) | `sf:treant` | 64 bones | Idle 2.36s, Walk 2.36s | idle, move | attack, hit, special (root slam) |

## Requests, in priority order

1. **attack** for every model except the mimic and the squire. About 0.4 to
   0.7 s, with the hit frame about 40% in. The game fits one-shot clips to
   0.55 s and lands damage at 0.22 s.
2. **special** for the five area abilities: wisp (Mending Light), drake (Fire
   Breath), hexling (Hex), acolyte (Thorn Ward) and sapling (Rootsnare). The
   game fits it to 0.8 s and lands it at 0.32 s.
3. **hit** (a short flinch, about 0.3 s) for every model. It plays when the
   hero is struck.
4. **run** for the fast walkers (bonelet, shade, acolyte). It plays while
   sprinting to catch up.
5. Bat: a separate hover idle, so standing still doesn't look like full
   flapping.
6. Wisp and drake: their Idle and Walk clips are 7.7 s and 13.1 s, so they
   loop slowly. Shorter loops (1 to 3 s) read better at phone size.

## Delivery notes

- Keep clip names as listed (`Idle`, `Walk`, `Run`, `Attack`, `Hit`,
  `Special`), or tell me the names and I'll update `CLIPS`. The test
  `sidekick clip map matches the rigs` fails if a mapped clip is missing.
- In-place clips only, with no root motion. The game moves the node.
- Keep the triangle counts and draw counts as they are. There's no new
  shadow caster, and the companion casts one shadow as before.
