# VFX overhaul: real elemental effects instead of rings

Captured on the compatibility renderer (`--rendering-method gl_compatibility`,
`--cam=0.6`) in a live hunt.

- `before_after.jpg`: hunt, powers, fire and hexer shots, main vs this branch
- `elements_contact.jpg`: one frame per element (cast, travel, impact, nova, linger and telegraph together)
- `vfx_<element>.mp4`: a ~2 s clip per element in a hunt

Re-shoot it with:

    godot --path . --rendering-method gl_compatibility --resolution 540x1170 -- \
      --capture --shots=hunt,powers,fire,hexer,vfx --frames=30 --out=OUT --cam=0.6
    tools/art/vfx_review.py OUT BEFORE_OUT docs/review/vfx

## The library

`src/vfx/vfx_lib.gd` (preloaded, no class_name), owned by `Fx` as `fx.vfx`.

- 12 elements: fire, frost, storm, poison, nature, holy, shadow, physical, blood, heal, buff, level
- 5 variants each: `cast`, `travel`, `impact`, `nova` (an expanding front that throws up that element's matter), `linger` (a field)
- `bolt()` for pooled forked lightning, `decal()` for pooled ground marks (scorch, frost, poison, holy, shadow, cracks), `element_for(color)` for old colour-only callers
- Telegraphs take an element and draw a thin, hard-edged textured rim (fire cracks, ice, thorns, stone and so on)
- The sprites are original CC0 art drawn by `tools/art/vfx_textures.py`

## Audit: every ring, circle or disc and what replaced it

| Where | What it was | Now |
|---|---|---|
| hero.gd family slam | two flat rings | physical nova + impact (debris, dust, crack decal) |
| hero.gd potion | green ring + burst | heal impact (crosses, motes) |
| hero.gd whirl super | orange ring | fire nova |
| hero.gd meteor cast | ring + light | fire cast |
| hero.gd slam land | two rings + burst + screen flash | physical nova + holy impact (screen flash removed) |
| hero.gd quake | two rings + burst | physical nova + impact |
| hero.gd meteor shower warning | thin ring | fire-edged telegraph |
| hero.gd frost ring | two rings + burst + puff | frost nova + impact (shards, flakes, frost decal) |
| hero.gd arrow storm area | thin ring + screen dim | stone-edged telegraph (dim removed) |
| hunt_combat blast_at / beams / fire patches / pyres / molten | ring + burst | element impact; element telegraphs; fire linger |
| hunt_combat second wind / phoenix / perfect dodge / boss kill | rings | heal nova / fire nova + holy / storm impact / shadow nova |
| hunt_events shrine / curse / ritual | rings | buff nova + cast / shadow nova / shadow telegraph |
| hunt_loot level up | two rings + burst | level impact (rays, chevrons, motes) |
| hunt_modes depth moment / boss arrival | rings + red screen dim | physical + fire nova (dim removed) / shadow nova |
| hunt_state legendary | ring + screen flash | level impact (flash removed) |
| enemy.gd caster / bomb / slam / necro | rings | shadow or nature impact / fire burst / physical nova / shadow nova |
| boss.gd slam / charge land / exposed / enrage | rings | physical nova / impact / holy telegraph / fire nova |
| boss_hexer.gd (4) | violet rings | shadow linger, cast, impact, nova |
| boss_thorn.gd thorn wave | ring | nature nova moving at exactly RING_SPEED, so it still reads as the dodge front |
| boss_warden.gd coins | ring + burst | holy impact |
| proj.gd orb explode | ring + burst | shadow impact |
| fx.sky_bolt / flame_burst / scorch / lightning / burst / puff / embers / bone_burst | ring shaders and GPU emitters | storm/holy impact, fire nova, fire decal, pooled bolts, sprite layers |
| sidekick.gd (7 calls) | rings | **not edited** (PR #62 owns the file). `fx.ring()` is now a shim that plays `vfx.nova(element_for(color))`, so sidekicks already get real effects. #62 can call `fx.vfx.*` directly; its wind-up telegraph `fx.ring(...)` (~line 401) should become `fx.vfx.cast(el, pos, r)` |

These markers stay and are now crisp, broken bands with no fill and no pulse:
the hero foot ring, the target ring and the shrine rings (`hero_ring.gdshader`).

Deleted: `ring`, `flame_ring`, `flame_wall` and `scorch` shaders.

## Budget

- Particles are CPU-simulated MultiMesh layers: one draw call per layer that has live particles, and hidden at zero cost when idle. Capped per layer (half on low quality), with 40 per call.
- Decals are capped at 24 and steal the oldest. Bolts come from a ring of 10.
- No new lights or shadow casters. `flash_light` is capped (energy ≤ 2.5, range ≤ 6, ≤ 0.3 s).
- Removed the always-on GPU emitters (sparks, embers, glow, dust, bones). On this engine build, `emit_particle` with `amount_ratio = 0` drew nothing on either renderer, so those bursts were invisible anyway.
- Draw calls (compat, from the `SHOT` log): see the PR body.
