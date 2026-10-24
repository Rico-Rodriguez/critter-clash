# Sidekick clip inventory and gaps

This reflects **#63** (`art/sidekick-clips` @ 4c76c2e), which Critter Clash
Art stacked on this branch. I read the clips from each wrapped scene's
`AnimationPlayer` with #63 merged locally. The game maps clips in
`src/data/sidekick_db.gd` `CLIPS`. A state with no clip falls back to a
procedural pose in `src/hunt/sidekick.gd` `pose()`. Where a clip exists, the
game adds a lighter accent (35%) on top of it.

Game timing: attacks are fitted to 0.55 s and land at 0.22 s (40%). Specials
are fitted to 0.8 s and land at 0.32 s (40%). Hits are fitted to 0.32 s. The
#63 clips are 0.6 s for attacks (strike at 0.24 s), 0.9 s for specials
(landing at 0.36 s) and 0.35 s for hits, so their 40% points line up.

| Sidekick | Scene | idle | move | run | attack | hit | special |
|---|---|---|---|---|---|---|---|
| Grave Wisp | `sf:mawko` | Idle_Loop 3.0s | Walk 7.67s (slow) | none | Attack 0.6 | Hit 0.35 (subtle) | Special 0.9 |
| Ember Drake / Ash Wyrm | `sf:dragon` | Flying_Idle 13.1s (**long**) | Fast_Flying 13.1s | none | Attack 0.6 | Hit 0.35 | Special 0.9 |
| Bonelet | `sf:skeleton` | Idle_Loop 1.6s | Walk_Loop 1.0s | Run 0.6s | Attack 0.6 | Hit 0.35 | Special 0.9 |
| Hexling | `sf:lich` | Idle 5.0s | Walk 5.0s (**no clean walk**) | none | Attack 0.6 | Hit 0.35 | Special 0.9 |
| Acolyte | `sf:plague` | Idle 3.33s | Walk_Loop 1.1s | Run 0.66s | Attack 0.6 | Hit 0.35 | Special 0.9 |
| Storm Crow | `sf:crow` | Idle 7.0s | Fast_Flying 1.62s | none | Attack 0.6 | Hit 0.35 | Special 0.9 |
| Gilded Mimic | `sf:mimic` (node anim) | Idle 2.4s | Walk 0.8s | none | Bite_Front 3.0s (original, fitted 5.5x) | Hit 0.35 (subtle) | Special 0.9 |
| Night Bat | `sf:bat` | Hover 3.21s | Bat_Flying 2.25s | none | Attack 0.6 (busy) | Hit 0.35 | Special 0.9 |
| Barrow Squire | `sf:squire` | Idle 1.54s | Walk 1.29s | Run 0.83s | Punch 1.21s (original, fitted 2.2x) | Hit 0.35 (subtle) | Special 0.9 |
| Hexbound Shade | `sf:wraith` | Idle 2.08s | Walk 3.33s | Run 1.85s | Attack 0.6 | Hit 0.35 | Special 0.9 |
| Thorn Sapling | `sf:treant` | Idle 2.36s | Walk_Loop 1.0s | none | Attack 0.6 | Hit 0.35 | Special 0.9 |

Every state now has its own clip, so the procedural fallback only covers
`run` on walkers without one, which then use `move`.

## Remaining gaps

1. **Hexling:** a clean `Walk_Loop`. The current walk is a 5 s take.
2. **Drake:** a short `Idle_Loop` (1 to 3 s). Flying_Idle and Fast_Flying are
   13 s takes.
3. **Hit readability:** the squire, wisp and mimic hits barely read at phone
   size. They need a larger recoil (more spine and head angle) in the first
   0.07 s.
4. **Bat:** the Attack has too many wing beats for 0.55 s. One clean dive
   and bite would read better.
5. **Mimic and squire attacks** still use the original Bite_Front (3.0 s)
   and Punch (1.21 s) takes, squeezed into 0.55 s. Their contact isn't
   authored at 40%. Make 0.6 s `Attack` takes that strike at 0.24 s, like the
   other models.
6. Nice to have: `Run` for the wisp, hexling and sapling, and `Walk_Loop` for
   the wisp (Walk is 7.7 s).

## Delivery notes

- In-place clips only, with no root motion. The game moves the node. #63's
  small root offsets (up to 0.3 m forward on the strike) are fine.
- The test `every sidekick has real attack, hit and special clips` (#63)
  and `sidekick clip map matches the rigs` (#62) catch a missing mapping.
