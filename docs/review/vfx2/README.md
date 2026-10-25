# VFX v2: dynamic elements (approach C) with light / skill / big tiers

**Revision 2 (no stamps).** No effect pastes the same icon N times anymore. Flame cones, ember diamonds, ice-shard diamonds, sparks, motes, crosses, chevrons, rays, wisps and dust now emit varied procedural pieces. Each piece is a seeded noise-dissolve billboard ("puff") or a faceted chip with random proportions.

- Travel is a fireball with a tapering ribbon trail plus a few embers.
- Fire breath is one continuous flame spray (`VfxLib.spray`). Fire basics can use the same spray through `fire_basic_spray`.
- Novas are one irregular, noise-eroded ring with heat licks, plus a scorch decal.
- `fire_compare.mp4` / `fire_compare.jpg` show the fireball basic, the spray basic option with the drake breath, and the big wavefront.

- `<element>.mp4` (12): each clip shows the element at **light** (3 quick basic shots), then **skill** (cast, travel, impact, nova), then **big** (the same with sky strike and larger ground marks).
- `busy_before.mp4` / `busy_after.mp4`: a busy hunt with the mage spamming basics (forced to 6 attacks/s, gl_compatibility, 30 fps). `busy_before_after.jpg` is one frame from each run. The runs are random, so the two frames show different moments.
- `contact_sheet.jpg`: one row per element in this order: fire, frost, storm, poison, nature, holy, shadow, physical, blood, heal, buff, level. Each row has five frames: light, skill impact, skill nova, big impact, big nova.
- The busy-hunt clips are from revision 1.

Draw calls in the busy hunt over 240 frames, 3 runs each:

| | avg | max |
|---|---|---|
| before (origin/main 89e14f2) | 554 / 533 / 505 | 712 / 671 / 590 |
| after, revision 1 | 531 / 542 / 509 | 668 / 709 / 663 |
| after, revision 2 (no stamps) | 499 / 500 | 624 / 622 |

Regenerate: `godot --path . --rendering-method gl_compatibility --write-movie x.avi --fixed-fps 30 -s tools/dev/vfx_tiers.gd -- --el=fire`, and `-- --capture --shots=busy --hero=mage [--clip=1]` for the busy hunt.
