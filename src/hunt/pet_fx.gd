extends RefCounted
## Every sidekick ability's effects, in the Supercell style of vfx_lib.gd:
## a readable anticipation at the pet (windup), a hit with flying pieces and a
## signature burst of the pet's element (the move itself), then a follow-
## through that settles. Damage stays in sidekick.gd; this file only draws.
##
## Tier scales with the pet's growth stage: a Hatchling's basics are light
## (no ground mark or shake), Grown pets cast at skill tier, and an Elder
## casts at skill tier but bigger (SCALE) with a second layer of accents.
## A bred pet's element (`el`) swaps the accents: embers, ice shards, arcs,
## drops, leaves, motes, wisps or rock. No rings except the blast's own.
## Preloaded by path (no class_name: OTA packs).

const SCALE := [0.9, 1.0, 1.3]
const GOLD := Color(1.0, 0.82, 0.3)
const BONE := Color(0.95, 0.91, 0.8)
const BLOOD := Color(0.85, 0.15, 0.2)


static func tier_for(stage: int, special: bool) -> StringName:
	if stage <= 0 and not special:
		return &"light"
	return &"skill"


static func k_for(stage: int) -> float:
	return float(SCALE[clampi(stage, 0, SCALE.size() - 1)])


## Runs `fn` after `t` seconds of sim time, if the pet and hunt still exist.
static func later(sk: Node, t: float, fn: Callable) -> void:
	if t <= 0.0:
		fn.call()
		return
	var me := sk
	sk.get_tree().create_timer(t, false).timeout.connect(func():
		if is_instance_valid(me) and is_instance_valid(me.hunt):
			fn.call())


# --- Building blocks ---------------------------------------------------------

## Motes pulled in toward `to` from a sphere of radius `r`: anticipation.
static func gather(v: Node, el: StringName, to: Vector3, n: int, r: float, c: Color, life := 0.26, size := 0.2) -> void:
	for i in n:
		var d := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1))
		d = d.normalized() * r * randf_range(0.7, 1.0)
		v.puff_el(el, to + d, size * randf_range(0.8, 1.2), -d / life, life, c, i * 0.025)


## Motes drifting up from a spot (heal, holy, shadow wisps, spores).
static func rise(v: Node, el: StringName, at: Vector3, n: int, r: float, c: Color, up := 2.0, life := 0.55, size := 0.24) -> void:
	for i in n:
		var a := TAU * (float(i) + randf()) / float(maxi(n, 1))
		var rr := r * randf_range(0.3, 1.0)
		v.puff_el(el, at + Vector3(sin(a) * rr, randf_range(0.0, 0.3), cos(a) * rr), size * randf_range(0.8, 1.2), Vector3(0, up * randf_range(0.8, 1.2), 0), life, c, i * 0.03)


## A string of puffs from `a` to `b`, popping one after another (a trail).
static func trail(v: Node, el: StringName, a: Vector3, b: Vector3, n: int, dur: float, c: Color, size := 0.26) -> void:
	for i in n:
		var u := float(i) / float(maxi(n - 1, 1))
		var p := a.lerp(b, u) + Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
		v.puff_el(el, p, size * lerpf(0.7, 1.1, u), Vector3(0, 0.5, 0), 0.24, c, dur * u)


## One piece thrown from `a` to land on `b` after `t` seconds (a ballistic arc).
static func fling(v: Node, a: Vector3, b: Vector3, t: float, c: Color, size: float, shape := 0) -> void:
	var g := 22.0
	var d := b - a
	var vel := Vector3(d.x / t, (d.y + 0.5 * g * t * t) / t, d.z / t)
	v.chunk(a, vel, c, size, t, shape, -g)


## The element's own accent: what makes a frost pet read different from a
## fire pet with the same move. `r` sizes it, `k` is the stage scale.
static func signature(v: Node, el: StringName, at: Vector3, r: float, c: Color, k: float, light := false) -> void:
	var n := 4 if light else int(round(7.0 * k))
	var p := at + Vector3(0, 0.5, 0)
	match el:
		&"fire":
			v.sparks(p, n + 2, 6.0 * k, Color(1.0, 0.7, 0.2), 0.45, 1.2)
			for i in n:
				fling(v, p, p + Vector3(randf_range(-1, 1), -0.4, randf_range(-1, 1)) * r, randf_range(0.4, 0.6), Color(1.0, 0.55, 0.15), 0.13, 0)
		&"frost":
			for i in n:
				var a := TAU * i / n
				v.chunk(p, Vector3(sin(a), 1.4, cos(a)) * 3.0 * k, Color(0.75, 0.93, 1.0), randf_range(0.14, 0.22), 0.55, 1)
			v.star(p + Vector3(0, 0.4, 0), 0.6 * k, Color(0.8, 0.95, 1.0), 0.18, 6.0)
		&"storm":
			for i in (1 if light else 3):
				v.bolt_arc(p, 0.9 * r * k, c)
			v.sparks(p, n, 7.0, Color(0.7, 0.95, 1.0), 0.3, 0.8)
		&"poison":
			for i in n:
				v.puff_el(el, p + Vector3(randf_range(-1, 1), randf_range(0, 0.5), randf_range(-1, 1)) * r * 0.6, randf_range(0.14, 0.24), Vector3(0, 2.0, 0), 0.6, c, i * 0.03)
			v.debris(at, n, 3.0, &"poison")
		&"nature":
			for i in n:
				var a := TAU * i / n + randf()
				v.chunk(p, Vector3(sin(a) * 2.5, 2.4, cos(a) * 2.5), Color(0.4, 0.78, 0.25), randf_range(0.16, 0.26), 0.9, 2, -6.0)
		&"holy", &"heal", &"buff", &"level":
			v.star(p + Vector3(0, 0.5, 0), 0.7 * k, c.lightened(0.3), 0.2, 8.0 if el == &"holy" else 4.0)
			rise(v, el, at, n, 0.8 * r, c, 2.4, 0.6, 0.2)
		&"shadow":
			gather(v, el, p, n, 1.2 * r, c, 0.2, 0.22)
			v.sparks(p, n, 5.0, Color(0.8, 0.5, 1.0), 0.35, 0.8)
		&"blood":
			for i in n:
				var a := TAU * i / n + randf()
				v.chunk(p, Vector3(sin(a) * 3.0, 2.2, cos(a) * 3.0), BLOOD, randf_range(0.12, 0.2), 0.7, 3)
		_:
			v.debris(at, n, 3.5 * k, &"physical")
			v.smoke(p, 0.4, Vector3(0, 1.2, 0), 0.5)


## A cross of two white-edged slashes through `at` (a bite, a cut, a claw).
static func slash(v: Node, at: Vector3, c: Color, r := 0.9, yaw := -1.0) -> void:
	var base := randf() * TAU if yaw < 0.0 else yaw
	v.crescent(at, r, base, base + 2.4, 0.3, c, 0.2, 0.9)
	v.crescent(at, r * 0.85, base + 3.2, base + 5.4, 0.24, c.lightened(0.2), 0.2, 0.75)


## Stars circling over a foe's head: stunned.
static func dizzy(v: Node, at: Vector3, c: Color, n := 3) -> void:
	for i in n:
		var a := TAU * i / n
		v.star(at + Vector3(sin(a) * 0.45, 1.9 + 0.05 * i, cos(a) * 0.45), 0.3, c, 0.5 + 0.1 * i, 4.0)


# --- Anticipation ------------------------------------------------------------

## The wind-up: the element gathers where the move will come from.
## `at` is the target (or the hero for hero-centred moves).
static func windup(sk: Node, kind: String, el: StringName, c: Color, stage: int, special: bool, at: Vector3) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var tier := tier_for(stage, special)
	var p := Vector3(sk.motor.pos.x, 0.0, sk.motor.pos.z)
	var fwd := Vector3(at.x - p.x, 0.0, at.z - p.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var body := p + Vector3(0, 0.7 + float(sk.def["fly"]) * 0.5, 0)
	var mouth := body + fwd * 0.5
	match kind:
		"breath":
			gather(v, el, mouth, 6, 1.1 * k, c, 0.3, 0.22)
			v.cast(el, p, 0.7 * k, c, tier)
		"bone_toss":
			gather(v, &"physical", body + fwd * 0.3, 4, 0.9, BONE, 0.2, 0.15)
			v.star(body + fwd * 0.3, 0.3 * k, BONE, 0.14, 4.0)
		"hex":
			rise(v, el, p, 5, 0.6 * k, c, 3.0, 0.5, 0.2)
			v.cast(el, p, 0.8 * k, c, tier)
		"thorns", "snare":
			var hp: Vector3 = sk.hunt.hero.flat_pos() if kind == "thorns" else p
			for i in 5:
				var a := TAU * i / 5.0 + randf() * 0.5
				v.chunk(hp + Vector3(sin(a), 0.1, cos(a)) * 0.9, Vector3(0, 2.2, 0), Color(0.4, 0.78, 0.25) if el == &"nature" else c, 0.14, 0.4, 2, -4.0)
			v.cast(el, p, 0.8 * k, c, tier)
		"storm":
			v.bolt_arc(body, 0.7 * k, c)
			v.sparks(body, 6, 3.0, c.lightened(0.3), 0.25)
			v.cast(el, p, 0.6 * k, c, tier)
		"snap":
			v.sparks(mouth, 5, 2.5, GOLD, 0.3)
			v.star(mouth, 0.35 * k, GOLD, 0.14, 4.0)
		"leech":
			gather(v, &"blood", mouth, 5, 0.9, BLOOD, 0.22, 0.16)
		"bash":
			for i in 4:
				v.smoke(p + Vector3(randf_range(-0.5, 0.5), 0.15, randf_range(-0.5, 0.5)), 0.3 * k, Vector3(0, 0.8, 0), 0.4)
			v.cast(&"physical", p, 0.6 * k, Color(0.8, 0.75, 0.65), &"light")
		"shadowstrike":
			gather(v, &"shadow", body, 7, 1.3 * k, c, 0.28, 0.24)
		"mend":
			rise(v, el, p, 5, 0.7, c, 2.2, 0.45, 0.2)
			v.cast(el, p, 0.8 * k, c, tier)
		_:
			v.cast(el, p, 0.6 * k, c, tier)


# --- Hit frames --------------------------------------------------------------

static func mend(sk: Node, el: StringName, c: Color, hero_at: Vector3, r: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var from: Vector3 = sk.position + Vector3(0, 0.6, 0)
	# A thread of light from the pet to the hero, then the heal blooms there.
	trail(v, el, from, hero_at + Vector3(0, 1.0, 0), 6, 0.22, c, 0.22)
	later(sk, 0.2, func():
		v.star(hero_at + Vector3(0, 1.2, 0), 0.9 * k, c.lightened(0.25), 0.22, 4.0)
		rise(v, &"heal", hero_at, 8, 0.8, c, 2.6, 0.7, 0.24)
		v.sparks(hero_at + Vector3(0, 1.0, 0), 8, 4.0, c.lightened(0.2), 0.45, 1.4))
	v.nova(el, hero_at, r, 0.5, c, tier_for(stage, true))
	signature(v, el, hero_at, r * 0.5, c, k)


static func breath(sk: Node, el: StringName, c: Color, start: Vector3, fwd: Vector3, rng: float, cone: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var mouth: Vector3 = sk.position + fwd * 0.5 + Vector3(0, 0.1, 0)
	v.star(mouth, 0.8 * k, c.lightened(0.3), 0.14, 5.0)
	v.sparks(mouth, 6, 5.0, c.lightened(0.2), 0.3, 0.4)
	v.spray(el, start, fwd, rng, cone, 0.5, c, tier_for(stage, true))
	# Embers carried on the jet, and smoke where it dies out.
	for i in int(6 * k):
		var u := randf_range(0.3, 1.0)
		var side := fwd.cross(Vector3.UP) * randf_range(-1, 1) * tan(cone) * rng * u * 0.6
		fling(v, start + fwd * rng * u * 0.4 + Vector3(0, 0.6, 0), start + fwd * rng * u + side, randf_range(0.35, 0.6), c.lightened(0.1), 0.12)
	var tip := start + fwd * rng * 0.85
	for i in 3:
		v.smoke(tip + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6)), 0.45 * k, Vector3(0, 1.4, 0), 0.7, 0.3 + i * 0.08)
	signature(v, el, tip, 1.2, c, k, true)


## One bone leaving the pet (or the last foe) and landing on the next.
static func bone_hop(sk: Node, el: StringName, from: Vector3, to: Vector3, hop: int, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var t := 0.1
	var delay := float(hop) * 0.09
	var col := BONE if el == &"shadow" or el == &"physical" or el == &"fire" else Color(sk.def["color"]).lightened(0.2)
	var go := func():
		fling(v, from, to + Vector3(0, 0.5, 0), t, col, 0.3 * k, 1)
		trail(v, &"physical", from, to + Vector3(0, 0.5, 0), 4, t, Color(0.9, 0.88, 0.8, 1.0), 0.16)
		later(sk, t, func():
			v.star(to + Vector3(0, 0.6, 0), 0.5 * k, Color(1, 1, 0.92), 0.14, 5.0)
			v.debris(Vector3(to.x, 0, to.z), 3, 3.0, &"shadow")
			if el != &"shadow" and el != &"physical":
				signature(v, el, to, 0.8, Color(sk.def["color"]), k, true))
	later(sk, delay, go)


static func hex_mark(sk: Node, el: StringName, c: Color, at: Vector3, r: float, delay: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	# A curse winds up round the foe while the warning ring tightens.
	for i in 12:
		var a := TAU * i / 12.0
		v.puff_el(el, at + Vector3(sin(a) * r * 0.7, 0.1, cos(a) * r * 0.7), 0.2 * k, Vector3(0, 2.4, 0), delay * 0.7, c, delay * 0.3 * float(i) / 12.0)
	v.star(at + Vector3(0, 1.3, 0), 0.5 * k, c.lightened(0.3), 0.3, 6.0)


static func hex_burst(sk: Node, el: StringName, c: Color, at: Vector3, r: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	gather(v, el, at + Vector3(0, 0.8, 0), 6, 1.4 * r * 0.5, c, 0.12, 0.3)
	v.impact(el, at, minf(r, 1.45), c, &"skill")
	signature(v, el, at, r, c, k)
	for i in 3:
		v.star(at + Vector3(randf_range(-0.6, 0.6), 0.8 + i * 0.35, randf_range(-0.6, 0.6)), 0.4 * k, c.lightened(0.3), 0.16 + 0.04 * i, 6.0)


static func thorns(sk: Node, el: StringName, c: Color, hero_at: Vector3, r: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	v.nova(el, hero_at, r, 0.45, c, tier_for(stage, true))
	var n := int(round(10.0 * k))
	for i in n:
		var a := TAU * i / n + randf() * 0.2
		var rr := r * randf_range(0.45, 0.95)
		var up := Vector3(sin(a) * 0.8, 1.2, cos(a) * 0.8)
		var at := hero_at + Vector3(sin(a), 0, cos(a)) * rr
		later(sk, 0.02 + rr / r * 0.14, func():
			v.spike(at, up, c if el != &"nature" else Color(0.32, 0.62, 0.2), 0.9 * k, 0.6))
	signature(v, el, hero_at, r * 0.6, c, k)


## Lightning hopping between foes: bolts at each link, a crack at each node.
static func storm(sk: Node, el: StringName, c: Color, pts: PackedVector3Array, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	v.bolt_arc(pts[0], 0.5, c)
	for i in range(1, pts.size()):
		var seg := PackedVector3Array([pts[i - 1], pts[i]])
		var node_at := pts[i]
		later(sk, 0.05 * float(i - 1), func():
			v.bolt(seg, c, true, 0.1 * k, 0.2)
			v.star(node_at, 0.55 * k, c.lightened(0.3), 0.14, 7.0)
			v.sparks(node_at, 5, 5.0, Color(0.8, 0.97, 1.0), 0.3)
			v.impact(el, Vector3(node_at.x, 0.0, node_at.z), 0.6, c, &"light"))
	if stage >= 2 and pts.size() > 1:
		v.sky(Vector3(pts[pts.size() - 1].x, 0, pts[pts.size() - 1].z), c, 0.2)


static func snap(sk: Node, el: StringName, at: Vector3, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var p := at + Vector3(0, 0.6, 0)
	slash(v, p, GOLD, 0.8)
	v.star(p, 0.8 * k, Color(1.0, 0.95, 0.6), 0.16, 4.0)
	for i in int(round(8.0 * k)):
		var a := randf() * TAU
		v.chunk(p, Vector3(sin(a) * 2.2, randf_range(3.5, 5.5), cos(a) * 2.2), GOLD, randf_range(0.13, 0.2), 0.8, 0)
	v.sparks(p, 8, 5.5, GOLD, 0.4, 1.0)
	if el != &"buff" and el != &"physical" and el != &"fire":
		signature(v, el, at, 0.8, GOLD, k, true)


## One bite of Blood Dive: slash on the foe, drops arcing back to the hero.
static func leech(sk: Node, el: StringName, c: Color, foe_at: Vector3, hero_at: Vector3, bite: int, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var col := BLOOD if el in [&"blood", &"fire", &"physical", &"shadow"] else c
	var go := func():
		var p := foe_at + Vector3(0, 0.6, 0)
		slash(v, p, col, 0.7)
		v.star(p, 0.5 * k, col.lightened(0.3), 0.14, 5.0)
		for i in 3:
			fling(v, p, hero_at + Vector3(0, 1.1, 0), randf_range(0.25, 0.4), col, 0.13, 3)
		later(sk, 0.3, func():
			v.sparks(hero_at + Vector3(0, 1.1, 0), 4, 3.0, Color(0.5, 1.0, 0.55), 0.3, 1.2))
	later(sk, float(bite) * 0.09, go)


static func bash(sk: Node, el: StringName, at: Vector3, r: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	v.impact(&"physical", at, minf(r, 1.45), Color(0, 0, 0, 0), &"skill")
	v.star(at + Vector3(0, 0.9, 0), 1.0 * k, Color(1, 0.97, 0.85), 0.2, 6.0)
	v.sparks(at + Vector3(0, 0.6, 0), 10, 7.0, Color(1, 0.9, 0.6), 0.35)
	for i in int(round(4.0 * k)):
		var a2 := TAU * i / 4.0 + randf()
		fling(v, at + Vector3(0, 0.3, 0), at + Vector3(sin(a2), 0, cos(a2)) * r * 0.9, 0.55, Color(0.62, 0.58, 0.52), 0.16 * k, 0)
	for i in int(round(5.0 * k)):
		var a := TAU * i / 5.0 + randf()
		v.smoke(at + Vector3(sin(a), 0.2, cos(a)) * r * 0.5, 0.45 * k, Vector3(sin(a), 0.8, cos(a)) * 1.6, 0.6)
	if el != &"physical":
		signature(v, el, at, r, Color(sk.def["color"]), k)


static func shadow_cut(sk: Node, el: StringName, c: Color, foe_at: Vector3, order: int, tough: bool, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	var go := func():
		var p := foe_at + Vector3(0, 0.7, 0)
		slash(v, p, c.lightened(0.15), 1.1 if tough else 0.9)
		v.star(p, (0.9 if tough else 0.6) * k, Color(1, 0.95, 1.0), 0.16, 6.0)
		for i in 4:
			v.puff_el(el, p + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.3), randf_range(-0.4, 0.4)), 0.4 * k, Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)), 0.45, c)
		v.sparks(p, 6, 6.0, c.lightened(0.3), 0.3)
		if el != &"shadow":
			signature(v, el, foe_at, 0.8, c, k, true)
	later(sk, float(order) * 0.07, go)


static func snare_open(sk: Node, el: StringName, c: Color, at: Vector3, r: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	v.nova(el, at, r, 0.45, c, tier_for(stage, true))
	var n := int(round(9.0 * k))
	for i in n:
		var a := TAU * i / n + randf() * 0.3
		var rr := r * randf_range(0.5, 1.0)
		var sp := at + Vector3(sin(a), 0, cos(a)) * rr
		later(sk, 0.02 + float(i) * 0.012, func():
			v.spike(sp, Vector3(-sin(a) * 0.6, 1.2, -cos(a) * 0.6), Color(0.3, 0.58, 0.2) if el == &"nature" else c, 1.0 * k, 0.9))
	signature(v, el, at, r * 0.7, c, k)


static func snare_pulse(sk: Node, el: StringName, c: Color, at: Vector3, r: float, stage: int) -> void:
	var v: Node = sk.hunt.fx.vfx
	var k := k_for(stage)
	v.impact(el, at, r * 0.8, c, &"light")
	for i in 5:
		var a := randf() * TAU
		var sp := at + Vector3(sin(a), 0, cos(a)) * r * randf_range(0.3, 0.9)
		v.spike(sp, Vector3(0, 1, 0), Color(0.3, 0.58, 0.2) if el == &"nature" else c, 0.55 * k, 0.3)
