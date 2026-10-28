# Biomes

What the code shows on 2026-10-28. The original biome plan was not in the repo; if you have
it, replace this file with it.

| Zone | Id | Boss | Built on the Art kits | Rebuilt foe brains |
| --- | --- | --- | --- | --- |
| The Barrow | `barrow` | Gravemaw | no (the first arena) | no |
| The Sunken Crypt | `depths` | Hexer Queen | no | no |
| The Hollow Grove | `grove` | Thorn Mother | no | no |
| The Gilded Vault | `vault` | Gilded Warden | no | no |
| Rimehollow | `frost` | Rime Regent | yes (`arena_rime.gd`) | yes |
| The Cinder Mire | `swamp` | Cinder Warlord | yes (`arena_mire.gd`) | yes |

- The Long Road has a frost and a mire variant (`arena_trial_zone.gd`) on the same kits.
- Foes: `src/data/next_foes.gd` holds the rebuilt Rimehollow and Mire roster; the older zones
  use the foe tables in `db.gd`. `--old-foes` plays the old ones for comparison.
- Bots: `check.sh` plays the frost and swamp zones with and without `--old-foes`.
- Perf: `tools/dev/perf-biomes.sh` holds both biomes to the frame budget.
- Models: every third-party model is listed in `docs/art-audit.md`.
