# VFX v2: dynamic elements (approach C) with light / skill / big tiers

- `<element>.mp4` (12): each clip shows the element at **light** (3 quick basic shots), then **skill** (cast, travel, impact, nova), then **big** (the same with sky strike and larger ground marks).
- `busy_before.mp4` / `busy_after.mp4`: a busy hunt with the mage spamming basics (forced to 6 attacks/s, gl_compatibility, 30 fps). `busy_before_after.jpg` is one frame from each run. The runs are random, so the two frames show different moments.
- `contact_sheet.jpg`: one frame per segment for every element except fire. Fire is in `fire.mp4`.

Draw calls in the busy hunt over 240 frames, 3 runs each:

| | avg | max |
|---|---|---|
| before (origin/main 89e14f2) | 554 / 533 / 505 | 712 / 671 / 590 |
| after | 531 / 542 / 509 | 668 / 709 / 663 |

Regenerate: `godot --path . --rendering-method gl_compatibility --write-movie x.avi --fixed-fps 30 -s tools/dev/vfx_tiers.gd -- --el=fire`, and `-- --capture --shots=busy --hero=mage [--clip=1]` for the busy hunt.
