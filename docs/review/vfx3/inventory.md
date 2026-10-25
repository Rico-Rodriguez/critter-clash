# VFX3 inventory: Supercell-style refactor

Every effect call site at origin/main 1510382, plus the non-Fx visuals. All of them now go through the toon blocks in `src/vfx/vfx_lib.gd`: puff, smoke, star, sparks, debris, chunk, crescent, spike, shockwave and target.

**Converted:** 225 Fx/vfx call sites. Most kept their call and now render through the new blocks; changed call sites are marked below. Also converted: 8 `fx.ring` sidekick sites, CompanionRing, every `flash_light` line, the SLASH and TORNADO shaders, the boss GPUParticles crown, the hero blade and ward, and the loot souls, hearts, projectiles and streaks.

**Rings that remain:** only `shockwave()`, which is ≤0.26 s, appears only on big-tier and r≥1.5 impacts, and is white-hot and thin; and `target()`/`telegraph()` for enemy and boss telegraphs. A test (`vfx_tests.gd` LEGACY scan) fails if `fx.ring(`, TorusMesh, `flash_light(`, Fx.SLASH/TORNADO, CompanionRing, the removed shaders, or the old `vfx._burst/_cloud/_emit` come back.

## Not converted (intentional)

- Hero locator ring under the player. It is a gameplay readability marker, not an effect.
- Wild storm boundary wall (gameplay zone).
- Arena mist, motes and ambient lights (environment, not effects).
- Lobby and gear_look GPUParticles (menu screens).
- Loot beam (additive pillar that marks a drop; it should be restyled separately).
- Boss glow OmniLight, hero OmniLight and sidekick_look light (scene lighting).

## Call sites

### src/hunt/ally.gd

| line | call | code |
|---|---|---|
| 76 | slash | `hunt.fx.slash(flat_pos(), atan2(fwd.x, fwd.z), reach, float(def.get("arc", 120.0)), Color(` |

### src/hunt/boss.gd

| line | call | code |
|---|---|---|
| 183 | telegraph | `tele.append(hunt.fx.telegraph(1, flat_pos(), yaw, Vector2(5.0, 0), step_t, 1.1))` |
| 188 | telegraph | `tele.append(hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(5.6, 0), step_t))` |
| 195 | telegraph | `tele.append(hunt.fx.telegraph(2, flat_pos(), yaw, Vector2(1.7, 15.0), step_t))` |
| 210 | telegraph | `tele.append(hunt.fx.telegraph(0, p2, 0.0, Vector2(1.7, 0), 1.0 + i * 0.12))` |
| 230 | slash | `hunt.fx.slash(flat_pos(), rotation.y, 5.2, 130, Color(0.5, 1.0, 0.75), false, 0.25)` |
| 231 | puff | `hunt.fx.puff(flat_pos() + dir_of(rotation.y) * 3.0, Color(0.3, 0.27, 0.23, 0.6), 10, 2.0, ` |
| 240 | nova | `hunt.fx.vfx.nova(&"physical", flat_pos(), 6.2, 0.5, Fx.VfxLib.NO_TINT, &"big")` |
| 241 | impact | `hunt.fx.vfx.impact(&"shadow", flat_pos(), 2.5, Fx.VfxLib.NO_TINT, &"big")` |
| 242 | puff | `hunt.fx.puff(flat_pos(), Color(0.3, 0.27, 0.23, 0.7), 18, 4.5, 4.0)` |
| 243 | bone_burst | `hunt.fx.bone_burst(flat_pos(), 8, 7.0)` |
| 244 | flash_light | `hunt.fx.flash_light(flat_pos(), Color(0.4, 1.0, 0.7), 5.0, 10.0, 0.4)` |
| 261 | puff | `hunt.fx.puff(flat_pos(), Color(0.3, 0.27, 0.23, 0.5), 2, 0.6, 1.5)` |
| 268 | impact | `hunt.fx.vfx.impact(&"physical", flat_pos(), 2.4, Fx.VfxLib.NO_TINT, &"skill")` |
| 285 | flash_light | `hunt.fx.flash_light(flat_pos() + dir_of(yaw) * 1.5, Color(0.5, 1.0, 0.7), 2.5, 6.0, 0.2)` |
| 301 | bone_burst | `hunt.fx.bone_burst(p, 5, 6.0)` |
| 302 | puff | `hunt.fx.puff(p, Color(0.3, 0.27, 0.23, 0.6), 6, 1.0, 2.5)` |
| 303 | burst | `hunt.fx.burst(p, Color(0.5, 1.0, 0.75), 8, 5.0, 1.2)` |
| 374 | telegraph | `hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(radius + 1.2, 0), t, 0.6, &"holy")` |
| 375 | impact | `hunt.fx.vfx.impact(&"holy", flat_pos(), radius, Fx.VfxLib.NO_TINT, &"skill")` |
| 410 | nova | `hunt.fx.vfx.nova(&"fire", flat_pos(), 6.0, 0.6, Fx.VfxLib.NO_TINT, &"big")` |

### src/hunt/boss_hexer.gd

| line | call | code |
|---|---|---|
| 46 | linger | `hunt.fx.vfx.linger(&"shadow", flat_pos(), 2.4, step_t, Fx.VfxLib.NO_TINT, &"big")` |
| 47 | cast | `hunt.fx.vfx.cast(&"shadow", flat_pos(), 2.0, Fx.VfxLib.NO_TINT, &"big")` |
| 48 | flash_light | `hunt.fx.flash_light(flat_pos(), VIOLET, 3.0, 8.0, step_t)` |
| 58 | telegraph | `tele.append(hunt.fx.telegraph(0, at, 0.0, Vector2(2.1, 0), 1.3 * fast))` |
| 65 | telegraph | `tele.append(hunt.fx.telegraph(2, flat_pos(), yaw, Vector2(2.2, 20.0), step_t))` |
| 68 | telegraph | `tele.append(hunt.fx.telegraph(2, flat_pos(), yaw + 0.45 * sgn, Vector2(2.2, 20.0), step_t)` |
| 77 | impact | `hunt.fx.vfx.impact(&"shadow", flat_pos(), 2.0, Fx.VfxLib.NO_TINT, &"skill")` |
| 78 | puff | `hunt.fx.puff(flat_pos(), Color(0.45, 0.25, 0.6, 0.7), 12, 2.0, 3.0)` |
| 114 | nova | `hunt.fx.vfx.nova(&"shadow", flat_pos(), 4.5, 0.3, Fx.VfxLib.NO_TINT, &"skill")` |
| 126 | bone_burst | `hunt.fx.bone_burst(at, 5, 6.0)` |
| 127 | burst | `hunt.fx.burst(at, VIOLET, 10, 5.0, 1.2)` |
| 128 | puff | `hunt.fx.puff(at, Color(0.35, 0.2, 0.45, 0.6), 6, 1.2, 2.5)` |
| 150 | lightning | `hunt.fx.lightning(PackedVector3Array([flat_pos() + Vector3(0, 1.5, 0) + d * 1.5, flat_pos(` |
| 151 | flash_light | `hunt.fx.flash_light(flat_pos() + lane_dir * 3.0, VIOLET, 4.0, 9.0, 0.3)` |
| 169 | impact | `hunt.fx.vfx.impact(&"shadow", flat_pos(), 2.2, Fx.VfxLib.NO_TINT, &"big")` |
| 170 | puff | `hunt.fx.puff(flat_pos(), Color(0.45, 0.25, 0.6, 0.7), 12, 2.0, 3.0)` |

### src/hunt/boss_thorn.gd

| line | call | code |
|---|---|---|
| 48 | telegraph | `tele.append(hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(3.0, 0), step_t))` |
| 58 | telegraph | `tele.append(hunt.fx.telegraph(0, at, 0.0, Vector2(1.7, 0), 1.1 + i * 0.1))` |
| 89 | nova | `hunt.fx.vfx.nova(&"nature", flat_pos(), RING_REACH, RING_REACH / RING_SPEED, Fx.VfxLib.NO_` |
| 102 | nova | `hunt.fx.vfx.nova(&"nature", flat_pos(), RING_REACH, RING_REACH / RING_SPEED, GREEN.lighten` |
| 114 | burst | `hunt.fx.burst(at, GREEN, 10, 5.0, 1.0)` |
| 115 | puff | `hunt.fx.puff(at, Color(0.3, 0.25, 0.15, 0.6), 6, 1.0, 2.0)` |

### src/hunt/boss_warden.gd

| line | call | code |
|---|---|---|
| 51 | telegraph | `tele.append(hunt.fx.telegraph(0, at, 0.0, Vector2(1.5, 0), 1.0 + i * 0.12))` |
| 90 | impact | `hunt.fx.vfx.impact(&"holy", p, 1.5, GOLD, &"skill")` |

### src/hunt/enemy.gd

| line | call | code |
|---|---|---|
| 115 | ? | `ward_mesh = Fx.make_ward(1.0)` |
| 173 | puff | `hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.25, 0.8), 10, 1.0, 2.5)` |
| 194 | puff | `hunt.fx.puff(flat_pos(), Color(0.3, 0.55, 0.65, 0.35), 1, 0.2, 0.6)` |
| 265 | puff | `hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.26, 0.4), 1, 0.3, 0.8)` |
| 405 | telegraph | `tele = hunt.fx.telegraph(1, flat_pos(), aim_yaw, Vector2(reach + 0.6, 0), w, 0.9)` |
| 407 | telegraph | `tele = hunt.fx.telegraph(2, flat_pos(), aim_yaw, Vector2(0.35, reach), w)` |
| 410 | telegraph | `tele = hunt.fx.telegraph(0, aim, 0.0, Vector2(blast, 0), w)` |
| 413 | telegraph | `tele = hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(float(def["blast"]), 0), w)` |
| 417 | telegraph | `tele = hunt.fx.telegraph(2, flat_pos(), aim_yaw, Vector2(1.0, 7.5), w)` |
| 450 | impact | `hunt.fx.vfx.impact(&"nature" if def.get("root", false) else &"shadow", aim, blast, Fx.VfxL` |
| 451 | flash_light | `hunt.fx.flash_light(aim, Color(0.7, 0.3, 1.0), 4.0, 5.0, 0.3)` |
| 461 | flame_burst | `hunt.fx.flame_burst(at, blast_r, true, Color(1.0, 0.55, 0.18), &"skill")` |
| 462 | puff | `hunt.fx.puff(at, Color(0.3, 0.25, 0.2, 0.7), 8, 1.2, 3.0)` |
| 463 | flash_light | `hunt.fx.flash_light(at, Color(1.0, 0.55, 0.25), 5.0, 8.0, 0.3)` |
| 477 | nova | `hunt.fx.vfx.nova(&"physical", sat, sr * 1.1, 0.35, Fx.VfxLib.NO_TINT, &"skill")` |
| 478 | puff | `hunt.fx.puff(sat, Color(0.3, 0.26, 0.2, 0.7), 10, 1.4, 3.5)` |
| 479 | bone_burst | `hunt.fx.bone_burst(sat, 5, 6.0)` |
| 499 | nova | `hunt.fx.vfx.nova(&"shadow", flat_pos(), 3.2, 0.5, Fx.VfxLib.NO_TINT, &"skill")` |

### src/hunt/hero.gd

| line | call | code |
|---|---|---|
| 324 | puff | `hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.26, 0.4), 1, 0.2, 0.6)` |
| 425 | slash | `hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.05, arc, col, swing_i % 2 == 0, 0.2)` |
| 500 | lightning | `hunt.fx.lightning(pts, col, &"light")` |
| 504 | slash | `hunt.fx.slash(flat_pos(), aim_yaw, 1.6, 40, col, false, 0.15)` |
| 559 | slash | `hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.05, arc, col, swing_i % 2 == 0, 0.2)` |
| 580 | nova | `hunt.fx.vfx.nova(&"physical", at, r * 1.1, 0.3, Fx.VfxLib.NO_TINT, &"light")` |
| 581 | impact | `hunt.fx.vfx.impact(&"physical", at, r * 0.7, Fx.VfxLib.NO_TINT, &"light")` |
| 596 | slash | `hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.08, arc, col, false, 0.34)` |
| 597 | slash | `hunt.fx.slash(flat_pos(), aim_yaw, reach * 0.8, arc * 0.85, col.lightened(0.3), false, 0.2` |
| 617 | slash | `hunt.fx.slash(flat_pos() - fwd * 0.4, aim_yaw, reach * 1.1, 30, col, false, 0.18)` |
| 618 | slash | `hunt.fx.slash(flat_pos() - fwd * 0.4, aim_yaw, reach * 1.18, 30, Color(1, 1, 1), true, 0.1` |
| 631 | slash | `hunt.fx.slash(flat_pos(), aim_yaw + (0.25 if left else -0.25), reach * 1.0, arc, _trail(),` |
| 651 | slash | `hunt.fx.slash(f.flat_pos() - dir_of(aim_yaw) * 1.2, aim_yaw, 1.8, 120, _trail(), randf() <` |
| 672 | puff | `hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.26, 0.55), 6, 0.5, 2.0)` |
| 710 | impact | `hunt.fx.vfx.impact(&"heal", flat_pos(), 1.4, Fx.VfxLib.NO_TINT, &"skill")` |
| 754 | tornado | `hunt.fx.tornado(self, Color(1.0, 0.42, 0.12), super_t)` |
| 755 | nova | `hunt.fx.vfx.nova(&"fire", flat_pos(), 3.4, 0.4, Fx.VfxLib.NO_TINT, &"big")` |
| 770 | fall | `hunt.fx.fall("arrow", cp, randf_range(0.15, 0.95), 0.28, func(): hunt.fx.puff(cp, Color(0.` |
| 777 | fall | `hunt.fx.fall("arrow", ap, 0.25 + 0.05 * (k * 5 + j), 0.28, func(): _arrow_hit(ap, dmg * 0.` |
| 786 | puff | `hunt.fx.puff(flat_pos(), Color(0.1, 0.12, 0.1, 0.5), 4, 0.5, 1.0)` |
| 789 | slash | `hunt.fx.slash(mf.flat_pos(), randf() * TAU, 1.8, 140, Color(0.6, 1.0, 0.7), randf() < 0.5,` |
| 796 | cast | `hunt.fx.vfx.cast(&"fire", flat_pos(), 1.6, Fx.VfxLib.NO_TINT, &"big")` |
| 831 | slash | `hunt.fx.slash(flat_pos(), randf() * TAU, 3.2, 360, Color(1.0, 0.55, 0.25), false, 0.22)` |
| 832 | embers_at | `hunt.fx.embers_at(flat_pos(), Color(1.0, 0.6, 0.2), 5, 2.4)` |
| 849 | nova | `hunt.fx.vfx.nova(&"physical", at, 5.0, 0.45, Fx.VfxLib.NO_TINT, &"big")` |
| 850 | impact | `hunt.fx.vfx.impact(&"holy", at, 2.6, Fx.VfxLib.NO_TINT, &"big")` |
| 851 | puff | `hunt.fx.puff(at, Color(0.35, 0.3, 0.25, 0.7), 10, 2.5, 4.0)` |
| 852 | flash_light | `hunt.fx.flash_light(at, Color(1.0, 0.8, 0.5), 7.0, 10.0, 0.4)` |
| 859 | sky_bolt | `hunt.fx.sky_bolt(f2.flat_pos(), Color(1.0, 0.88, 0.5), 0.22)` |
| 867 | sky_bolt | `hunt.fx.sky_bolt(bp, Color(0.85, 0.92, 1.0), 0.14, 12.0))` |
| 915 | embers_at | `hunt.fx.embers_at(p - Vector3(0, 0.3, 0), Color(0.45, 0.8, 1.0), 1, 0.15)` |
| 919 | burst | `hunt.fx.burst(p, Color(0.5, 0.8, 1.0), 6, 5.0)` |
| 920 | flare | `hunt.fx.flare(p, Color(0.45, 0.75, 1.0))` |
| 936 | flame_burst | `hunt.fx.flame_burst(flat_pos(), r2, true, Color(1.0, 0.55, 0.18), &"skill")` |
| 970 | make_wisp | `wisp = hunt.fx.make_wisp()` |
| 973 | flame_burst | `hunt.fx.flame_burst(flat_pos(), 1.6, false, Color(1.0, 0.55, 0.18), &"skill")` |
| 979 | embers_at | `hunt.fx.embers_at(wisp.position - Vector3(0, 0.6, 0), Color(1.0, 0.5, 0.15), 1, 0.12)` |
| 1004 | flare | `hunt.fx.flare(wisp.position - Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.2))` |
| 1005 | burst | `hunt.fx.burst(wisp.position - Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.25), 5, 4.0)` |
| 1112 | sky_bolt | `hunt.fx.sky_bolt(at, Color(1.0, 0.88, 0.5), 0.22)` |
| 1124 | nova | `hunt.fx.vfx.nova(&"physical", at, r, 0.45, Fx.VfxLib.NO_TINT, &"skill")` |
| 1125 | impact | `hunt.fx.vfx.impact(&"physical", at, r * 0.6, Fx.VfxLib.NO_TINT, &"skill")` |
| 1126 | bone_burst | `hunt.fx.bone_burst(at, 6, 8.0)` |
| 1127 | flash_light | `hunt.fx.flash_light(at, Color(1.0, 0.7, 0.4), 4.0, r * 1.5, 0.3)` |
| 1158 | telegraph | `hunt.fx.telegraph(0, at, 0.0, Vector2(radius, 0), 0.55 + delay, 0.6, &"fire")` |
| 1159 | fall | `hunt.fx.fall("meteor", at, delay, 0.55, func(): _meteor_hit(at, amount, radius))` |
| 1165 | flame_burst | `hunt.fx.flame_burst(at, radius * 1.2, true, Color(1.0, 0.55, 0.18), &"skill")` |
| 1166 | puff | `hunt.fx.puff(at, Color(0.25, 0.2, 0.17, 0.7), 8, radius * 0.6, 3.0)` |
| 1179 | nova | `hunt.fx.vfx.nova(&"frost", at, radius, 0.4, Fx.VfxLib.NO_TINT, &"skill")` |
| 1180 | impact | `hunt.fx.vfx.impact(&"frost", at, radius * 0.5, Fx.VfxLib.NO_TINT, &"skill")` |
| 1181 | flash_light | `hunt.fx.flash_light(at, Color(0.5, 0.85, 1.0), 4.0, radius * 2.0, 0.35)` |
| 1201 | telegraph | `hunt.fx.telegraph(0, center, 0.0, Vector2(radius, 0), 0.6, 0.6, &"physical")` |
| 1207 | fall | `hunt.fx.fall("arrow", at, delay, 0.28, func(): _arrow_hit(at, amount))` |
| 1213 | burst | `hunt.fx.burst(at, Color(1.0, 0.9, 0.6), 3, 4.0)` |
| 1214 | puff | `hunt.fx.puff(at, Color(0.4, 0.34, 0.26, 0.5), 2, 0.4, 1.5)` |
| 1242 | lightning | `hunt.fx.lightning(pts, Color(0.6, 0.8, 1.0), &"skill")` |
| 1250 | burst | `hunt.fx.burst(flat_pos(), Color(0.5, 0.8, 1.0), 18, 7.0)` |

### src/hunt/hunt.gd

| line | call | code |
|---|---|---|
| 151 | slash | `fx.slash(at, 0.0, 2.0, deg, Color.WHITE)` |
| 154 | telegraph | `fx.telegraph(shape, at, 0.0, Vector2(2.0, 5.0), 0.4)` |
| 155 | beam | `var beam := fx.beam(at, Color.WHITE, 3.0)` |
| 158 | burst | `fx.burst(at, Color.WHITE, 4)` |
| 159 | puff | `fx.puff(at, Color(1, 1, 1, 0.3), 2)` |
| 160 | bone_burst | `fx.bone_burst(at, 2)` |
| 161 | embers_at | `fx.embers_at(at, Color.ORANGE, 2)` |
| 162 | flare | `fx.flare(at, Color.WHITE)` |
| 163 | flash_light | `fx.flash_light(at, Color.WHITE, 0.1, 3.0, 0.1)` |
| 164 | lightning | `fx.lightning(PackedVector3Array([at + flat, at + flat + Vector3(2, 0, 0)]), Color(0.6, 0.8` |

### src/hunt/hunt_combat.gd

| line | call | code |
|---|---|---|
| 12 | telegraph | `fx.telegraph(0, pos, 0.0, Vector2(r, 0), delay, 0.6, el)` |
| 16 | impact | `fx.vfx.impact(el, pos, r, col, &"skill")` |
| 29 | telegraph | `fx.telegraph(2, from, yaw, Vector2(0.9, 14.0), delay, 0.6, el)` |
| 38 | impact | `fx.vfx.impact(el, from + fwd * (2.0 + k * 3.5), 0.9, col, &"skill")` |
| 46 | telegraph | `patches.append({"pos": at, "r": r, "t": dur, "dps": dps, "tick": 0.5, "node": fx.telegraph` |
| 47 | linger | `fx.vfx.linger(&"fire", at, r * 0.8, dur, Fx.VfxLib.NO_TINT, &"skill")` |
| 53 | linger | `fx.vfx.linger(&"fire", at, r * 0.8, dur, Fx.VfxLib.NO_TINT, &"light")` |
| 64 | embers_at | `fx.embers_at(pr["pos"], Color(1.0, 0.45, 0.1), 3, float(pr["r"]) * 0.7)` |
| 117 | burst | `fx.burst(f.flat_pos(), Color(0.6, 0.55, 1.0), 16, 7.0)` |
| 140 | burst | `fx.burst(f.flat_pos(), Color(1.0, 0.85, 0.6) if not crit else Color(1.0, 0.6, 0.2), 5 if n` |
| 188 | bone_burst | `fx.bone_burst(at, 5 if not f.elite else 12, 5.5 if not f.elite else 8.0)` |
| 189 | puff | `fx.puff(at, Color(0.4, 0.38, 0.35, 0.5), 3, 0.4, 1.2)` |
| 221 | flash_light | `fx.flash_light(at, Color(1.0, 0.82, 0.35), 4.0, 7.0, 0.4)` |
| 222 | burst | `fx.burst(at + Vector3(0, 0.8, 0), Color(1.0, 0.82, 0.35), 20, 7.0, 1.8)` |
| 228 | telegraph | `fx.telegraph(0, at, 0.0, Vector2(2.6, 0), 1.0, 0.6, &"fire")` |
| 230 | flame_burst | `fx.flame_burst(at, 2.8, true, Color(1.0, 0.55, 0.18), &"skill")` |
| 255 | bone_burst | `fx.bone_burst(at, 20, 10.0)` |
| 256 | nova | `fx.vfx.nova(&"shadow", at, 9.0, 0.9, Fx.VfxLib.NO_TINT, &"big")` |
| 257 | impact | `fx.vfx.impact(&"holy", at, 3.0, Fx.VfxLib.NO_TINT, &"big")` |
| 258 | flash_light | `fx.flash_light(at, Color(DB.boss_def(cur_boss)["color"]).lightened(0.3), 10.0, 18.0, 1.5)` |
| 343 | lightning | `fx.lightning(PackedVector3Array([hero.position + Vector3(0, 1.0, 0), e.position + Vector3(` |
| 351 | nova | `fx.vfx.nova(&"heal", hero.flat_pos(), 3.0, 0.5, Fx.VfxLib.NO_TINT, &"skill")` |
| 357 | nova | `fx.vfx.nova(&"fire", hero.flat_pos(), 6.0, 0.55, Fx.VfxLib.NO_TINT, &"big")` |
| 358 | impact | `fx.vfx.impact(&"holy", hero.flat_pos(), 2.0, Color(1.0, 0.7, 0.35), &"big")` |
| 359 | flash_light | `fx.flash_light(hero.flat_pos(), Color(1.0, 0.6, 0.25), 8.0, 12.0, 0.8)` |
| 379 | impact | `fx.vfx.impact(&"storm", hero.flat_pos(), 1.4, Color(0.55, 0.9, 1.0), &"skill")` |
| 380 | flash_light | `fx.flash_light(hero.flat_pos(), Color(0.5, 0.85, 1.0), 3.0, 6.0, 0.25)` |
| 423 | bone_burst | `fx.bone_burst(at, 16, 9.0)` |
| 424 | nova | `fx.vfx.nova(&"shadow", at, 8.0, 0.8, Fx.VfxLib.NO_TINT, &"big")` |
| 425 | flash_light | `fx.flash_light(at, Color(col).lightened(0.3), 9.0, 16.0, 1.2)` |

### src/hunt/hunt_events.gd

| line | call | code |
|---|---|---|
| 66 | nova | `fx.vfx.nova(&"buff", hero.flat_pos(), 3.5, 0.5, d["color"], &"skill")` |
| 67 | cast | `fx.vfx.cast(&"buff", hero.flat_pos(), 1.2, d["color"], &"skill")` |
| 68 | flash_light | `fx.flash_light(hero.flat_pos(), d["color"], 4.0, 8.0, 0.5)` |
| 80 | nova | `fx.vfx.nova(&"shadow", hero.flat_pos(), 5.0, 0.6, Fx.VfxLib.NO_TINT, &"skill")` |
| 81 | impact | `fx.vfx.impact(&"shadow", hero.flat_pos(), 1.6, Fx.VfxLib.NO_TINT, &"skill")` |
| 82 | flash_light | `fx.flash_light(hero.flat_pos(), col, 5.0, 9.0, 0.6)` |
| 166 | telegraph | `_ritual_tele = fx.telegraph(0, ritual_at, 0.0, Vector2(2.8, 0), ritual_t, 0.6, &"shadow")` |
| 190 | lightning | `fx.lightning(PackedVector3Array([(c as Enemy).position + Vector3(0, 1.6, 0), ritual_at + V` |

### src/hunt/hunt_loot.gd

| line | call | code |
|---|---|---|
| 90 | beam | `p.beam = fx.beam(Vector3(p.position.x, 0, p.position.z), col, 9.0 if it["rarity"] == "lege` |
| 140 | flare | `fx.flare(hero.flat_pos() + Vector3(0, 0.3, 0), Color(0.3, 0.8, 1.0, 0.5))` |
| 154 | burst | `fx.burst(hero.flat_pos(), col, 12, 5.0)` |
| 182 | impact | `fx.vfx.impact(&"level", hero.flat_pos(), 1.8, Fx.VfxLib.NO_TINT, &"skill")` |
| 183 | cast | `fx.vfx.cast(&"buff", hero.flat_pos(), 1.0, Color(1.0, 0.85, 0.4), &"skill")` |
| 184 | flash_light | `fx.flash_light(hero.flat_pos(), Color(0.5, 0.85, 1.0), 4.0, 8.0, 0.35)` |

### src/hunt/hunt_modes.gd

| line | call | code |
|---|---|---|
| 171 | puff | `fx.puff(cp, Color(1.0, 0.85, 0.4, 0.6), 10, 1.0, 2.0)` |
| 336 | nova | `fx.vfx.nova(&"physical", at, 12.0, 0.9, Fx.VfxLib.NO_TINT, &"big")` |
| 337 | nova | `fx.vfx.nova(&"fire", at, 6.0, 0.6, Fx.VfxLib.NO_TINT, &"big")` |
| 338 | flash_light | `fx.flash_light(at, col, 5.0, 14.0, 0.8)` |
| 341 | embers_at | `fx.embers_at(p, col.lerp(Color(1.0, 0.8, 0.4), randf()), 4, 0.8)` |
| 342 | puff | `fx.puff(at, Color(0.3, 0.12, 0.08, 0.5), 10, 4.0, 3.0)` |
| 366 | bone_burst | `fx.bone_burst(f.flat_pos(), 3, 4.0)` |
| 382 | puff | `fx.puff(arena.boss_spawn, Color(0.3, 0.27, 0.22, 0.85), 22, 3.0, 3.0)` |
| 383 | bone_burst | `fx.bone_burst(arena.boss_spawn, 10, 8.0)` |
| 385 | nova | `fx.vfx.nova(&"shadow", arena.boss_spawn, 7.0, 0.8, Fx.VfxLib.NO_TINT, &"big")` |
| 386 | impact | `fx.vfx.impact(&"shadow", arena.boss_spawn, 2.5, Fx.VfxLib.NO_TINT, &"big")` |
| 387 | flash_light | `fx.flash_light(arena.boss_spawn, aura, 8.0, 16.0, 1.2)` |

### src/hunt/hunt_state.gd

| line | call | code |
|---|---|---|
| 207 | puff | `fx.puff(at, Color(0.28, 0.23, 0.18, 0.75), 7, 0.7, 1.6)` |
| 209 | bone_burst | `fx.bone_burst(at, 2, 3.0)` |
| 491 | sky_bolt | `fx.sky_bolt(at, col.lightened(0.3), 0.5, 18.0)` |
| 492 | impact | `fx.vfx.impact(&"level", at, 2.4, col.lightened(0.3), &"big")` |
| 493 | flash_light | `fx.flash_light(at, col, 6.0, 10.0, 0.8)` |

### src/hunt/proj.gd

| line | call | code |
|---|---|---|
| 59 | travel | `h.fx.vfx.travel(el, position - vel.normalized() * 0.25, vel, ec, &"light")` |
| 69 | burst | `h.fx.burst(flat, Color(0.8, 0.75, 0.6), 4, 3.0)` |
| 118 | burst | `h.fx.burst(flat, Color(1.0, 0.4, 0.3), 6, 4.0)` |
| 148 | burst | `h.fx.burst(f.flat_pos(), Color(1.0, 0.7, 0.45), 4, 4.0)` |
| 150 | embers_at | `h.fx.embers_at(flat, Color(1.0, 0.6, 0.3), 1, 0.2)` |
| 187 | impact | `h.fx.vfx.impact(&"shadow", at, r, Fx.VfxLib.NO_TINT, &"light")` |
| 188 | flash_light | `h.fx.flash_light(at, Color(0.7, 0.4, 1.0), 3.0, r * 3.0, 0.2)` |
| 193 | flame_burst | `h.fx.flame_burst(at, r, kind == "firebolt", Color(1.0, 0.55, 0.18), &"light")` |

### src/hunt/sidekick.gd

| line | call | code |
|---|---|---|
| 180 | puff | `fx.puff(Vector3(from.x, 0, from.z), Color(0.5, 0.5, 0.55, 0.5), 5, 0.5, 1.0)` |
| 181 | burst | `fx.burst(Vector3(motor.pos.x, 0, motor.pos.z), def["color"], 6, 3.0, 0.6)` |
| 233 | ring | `fx.ring(Vector3(motor.pos.x, 0.05, motor.pos.z), 0.55 if not is_special() else 0.8, def["c` |
| 245 | burst | `hunt.fx.burst(Vector3(position.x, maxf(position.y - 0.6, 0.0), position.z), def["color"], ` |
| 393 | ring | `fx.ring(hero.flat_pos(), r, col, 0.5, 0.12, &"skill")` |
| 394 | burst | `fx.burst(hero.flat_pos() + Vector3(0, 1.0, 0), col, 10, 3.0, 1.5)` |
| 413 | spray | `fx.vfx.spray(&"fire", start, fwd, rng, float(ab["cone"]), 0.5, flame, &"skill")` |
| 421 | ring | `fx.ring(mid, rng * 0.5, flame, 0.4, 0.12, &"skill")` |
| 437 | lightning | `fx.lightning(PackedVector3Array([prev, at.flat_pos() + Vector3(0, 0.6, 0)]), Color(0.95, 0` |
| 438 | bone_burst | `fx.bone_burst(at.flat_pos(), 3, 3.5)` |
| 455 | telegraph | `fx.telegraph(0, at, 0.0, Vector2(r, 0), float(ab["delay"]))` |
| 462 | ring | `fx.ring(at, r, c2, 0.45, 0.12, &"skill")` |
| 463 | burst | `fx.burst(at, c2, 14, 6.0)` |
| 475 | ring | `fx.ring(hero.flat_pos(), r, col, 0.5, 0.2, &"skill")` |
| 476 | burst | `fx.burst(hero.flat_pos(), col, 16, 7.0, 0.3)` |
| 495 | lightning | `fx.lightning(pts, Color(0.6, 0.85, 1.0), &"skill")` |
| 503 | burst | `fx.burst(p, Color(1.0, 0.82, 0.3), 8, 5.0)` |
| 518 | burst | `fx.burst(at.flat_pos() + Vector3(0, 0.6, 0), Color(0.85, 0.2, 0.25), 6, 4.0)` |
| 530 | ring | `fx.ring(p, r, col, 0.4, 0.18, &"skill")` |
| 531 | puff | `fx.puff(p, Color(0.3, 0.27, 0.23, 0.6), 8, 1.5, 2.0)` |
| 546 | puff | `fx.puff(f.flat_pos(), Color(0.15, 0.1, 0.25, 0.7), 6, 0.8, 1.5)` |
| 547 | burst | `fx.burst(f.flat_pos() + Vector3(0, 0.7, 0), col, 6, 4.0)` |
| 557 | ring | `fx.ring(at, r, col, 0.5, 0.2, &"skill")` |
| 558 | burst | `fx.burst(at, col, 14, 5.0, 0.4)` |
| 568 | ring | `fx.ring(at, r * 0.8, col, 0.3, 0.12, &"light")` |

### src/ui/hud.gd

| line | call | code |
|---|---|---|
| 349 | burst | `hunt.fx.burst(hunt.hero.flat_pos() + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.3), 16, 6.0, 1` |
