# VFX3: Supercell-style effects review

All clips use the compat renderer at 720x1560, downscaled to 360 wide. Regenerate them with `tools/dev/vfx3_capture.sh`.

- `el_<element>.mp4` (12 elements): cast, travel and impact at the light, skill and big tiers.
- `fire_modes.mp4`: the fire effect in every mode.
- `busy_mage.mp4` and `busy_knight.mp4`: busy hunt, `--cam=0.6`.
- `contact_sheet.png`: the big impact for each element, plus busy frames.
- `inventory.md`: every call site, and what was not converted.

## Draw calls

| clip | avg | max |
|---|---|---|
| main busy hunt (baseline) | ~500 | ~622 |
| busy_mage | 402 | 495 |
| busy_knight | 481 | 581 |

Extra draws per tier over the idle 285: most elements add +7 (light), +9-10 (skill) and +9-10 (big). Holy and level add +18 at big. Storm adds +10, +36 and +63 because of the bolt pool, which is capped at 10.
