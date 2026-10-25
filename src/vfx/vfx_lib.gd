extends Node3D
## Element VFX library in the Supercell style (Clash Royale / Brawl Stars):
## chunky toon shapes with 2-3 hard colour bands, an anticipation -> impact
## -> follow-through rhythm, a white hit pop, and shapes that dissolve with a
## hard edge or shrink to nothing. See docs/review/vfx3/README.md.
##
## Twelve elements (fire, frost, storm, poison, nature, holy, shadow,
## physical, blood, heal, buff, level), five variants each (cast, travel,
## impact, nova, linger), and three tiers (light, skill, big).
##
## Building blocks, all public so any system can use them directly:
##   puff()      toon 3-band puff that pops with overshoot then dissolves
##   star()      spiky billboard hit star, white core, hollows out
##   sparks()    fat stretched sparks that fly, fall and shrink
##   debris()    toon chunks (rock, ice, bone, leaf, drop) that hop and bounce
##   decal()     scorch / crack mark with glowing cracks (capped, MAX_DECALS)
##   shockwave() a brief ring that belongs to an impact, never decoration
##   target()    a telegraph target ring that tightens to the moment of hit
##   crescent()  a solid slash crescent (white leading edge)
##   bolt()      a thick 3-band cartoon bolt that re-jags while it lives
##   spray()     a continuous flame jet of puffs
##   kick()      tier-tied camera shake and a short freeze on hit
##
## Budget (iOS): every piece is batched. Toon puffs, chunks, spikes, sparks,
## stars and ground shapes are one MultiMesh each (one draw call per layer
## while anything in it lives, hidden when idle). All bolts and crescents
## are one ImmediateMesh (one draw). No shadows, no lights, no tint washes,
## no fog, no bloom: everything is unlit, hard edged and mostly opaque.
##
## Not a class_name on purpose (content packs cannot add global classes):
## preload("res://src/vfx/vfx_lib.gd"). Fx owns one as `fx.vfx`.

const TOON := preload("res://src/vfx/sc_toon.gdshader")
const STAR := preload("res://src/vfx/sc_star.gdshader")
const GROUND := preload("res://src/vfx/sc_ground.gdshader")
const TEX := "res://assets/vfx/%s.png"

const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"poison", &"nature", &"holy", &"shadow", &"physical", &"blood", &"heal", &"buff", &"level"]
const VARIANTS: Array[StringName] = [&"cast", &"travel", &"impact", &"nova", &"linger"]

## Importance tiers. Every call names one:
##   light: basic and auto attacks, sidekick basics, frequent procs. A small
##          star, a few puffs and sparks. No ground mark, no shake, no
##          freeze, no sky strike, at most one short bolt. Readable at 5+/s.
##   skill: abilities and specials. Bigger pop, shockwave, debris, a scorch,
##          a light shake.
##   big:   supers, boss attacks, ultimates. Owns the screen briefly: a
##          flash disk, more debris, longer marks, a sky strike on
##          storm/holy/level, a real shake and a short freeze.
const NO_TINT := Color(0, 0, 0, 0)
const TIERS: Array[StringName] = [&"light", &"skill", &"big"]
const TIER := {
	&"light": {"core": 0.6, "n": 0.45, "ground": 0.0, "gdur": 0.0, "debris": 0.0, "sky": false, "bolts": 1, "spikes": 0.0, "shake": 0.0, "freeze": 0.0},
	&"skill": {"core": 1.0, "n": 1.0, "ground": 1.0, "gdur": 1.0, "debris": 1.0, "sky": false, "bolts": 3, "spikes": 1.0, "shake": 0.12, "freeze": 0.0},
	&"big": {"core": 1.4, "n": 1.5, "ground": 1.45, "gdur": 1.6, "debris": 1.8, "sky": true, "bolts": 5, "spikes": 1.6, "shake": 0.5, "freeze": 0.06},
}

## Body colour per element (a caller's tint overrides it).
const COLORS := {
	&"fire": Color(1.0, 0.62, 0.12), &"frost": Color(0.6, 0.88, 1.0), &"storm": Color(0.45, 0.85, 1.0),
	&"poison": Color(0.55, 0.9, 0.2), &"nature": Color(0.45, 0.82, 0.28), &"holy": Color(1.0, 0.85, 0.35),
	&"shadow": Color(0.62, 0.36, 0.95), &"physical": Color(0.62, 0.56, 0.5), &"blood": Color(0.86, 0.12, 0.15),
	&"heal": Color(0.45, 1.0, 0.5), &"buff": Color(1.0, 0.8, 0.3), &"level": Color(1.0, 0.86, 0.4),
}
## Dark rim band per element: [hue, value] (saturation is fixed in the shader).
const RIM := {
	&"fire": [0.02, 0.85], &"frost": [0.6, 0.85], &"storm": [0.62, 0.8], &"poison": [0.28, 0.45],
	&"nature": [0.33, 0.4], &"holy": [0.08, 0.85], &"shadow": [0.76, 0.35], &"physical": [0.07, 0.28],
	&"blood": [0.98, 0.4], &"heal": [0.38, 0.5], &"buff": [0.07, 0.75], &"level": [0.08, 0.8],
}
## Ground warning edge per element (assets/vfx/edge_*.png), for Fx.telegraph.
const EDGES := {
	&"fire": "fire", &"frost": "frost", &"storm": "storm", &"poison": "poison", &"nature": "poison",
	&"holy": "holy", &"shadow": "shadow", &"physical": "stone", &"blood": "danger", &"heal": "holy",
	&"buff": "holy", &"level": "holy", &"danger": "danger",
}
## Which elements leave a mark on the ground: [mark colour, crack glow hue].
const DECALS := {
	&"fire": [Color(0.14, 0.1, 0.09), 0.07], &"frost": [Color(0.55, 0.78, 0.92), 0.55], &"poison": [Color(0.2, 0.32, 0.08), 0.25],
	&"nature": [Color(0.2, 0.28, 0.1), 0.3], &"holy": [Color(0.4, 0.34, 0.2), 0.13], &"shadow": [Color(0.12, 0.07, 0.18), 0.78],
	&"physical": [Color(0.22, 0.19, 0.16), 0.08], &"storm": [Color(0.12, 0.12, 0.16), 0.55], &"level": [Color(0.4, 0.34, 0.2), 0.13],
	&"heal": [Color(0.2, 0.34, 0.2), 0.36], &"blood": [Color(0.3, 0.04, 0.05), 0.0],
}
## Debris each element throws: [body colour, shape: 0 rock, 1 shard, 2 leaf, 3 drop].
const DEBRIS := {
	&"fire": [Color(0.42, 0.37, 0.32), 0], &"frost": [Color(0.75, 0.93, 1.0), 1], &"storm": [Color(0.45, 0.4, 0.36), 0],
	&"poison": [Color(0.5, 0.85, 0.2), 3], &"nature": [Color(0.4, 0.78, 0.25), 2], &"holy": [Color(1.0, 0.9, 0.55), 1],
	&"shadow": [Color(0.93, 0.9, 0.82), 0], &"physical": [Color(0.45, 0.4, 0.34), 0], &"blood": [Color(0.8, 0.08, 0.1), 3],
	&"heal": [Color(0.55, 1.0, 0.6), 3], &"buff": [Color(1.0, 0.85, 0.4), 1], &"level": [Color(1.0, 0.88, 0.45), 1],
}
## Spikes (crystals, thorns, stone, void) grow out of the ground on these.
const SPIKES := {&"frost": 0, &"nature": 1, &"physical": 2, &"shadow": 3}
## Star points per element (a heal "plus" is a 4-point star).
const STAR_PTS := {&"heal": 4.0, &"buff": 4.0, &"holy": 8.0, &"level": 8.0, &"storm": 7.0, &"frost": 6.0}

## Batched layers: mesh, cap.
const LAYERS := {
	"toon": {"mesh": "sphere", "amount": 300},
	"chunk": {"mesh": "box", "amount": 140},
	"spike": {"mesh": "cone", "amount": 120},
	"spark": {"mesh": "prism", "amount": 220},
	"star": {"mesh": "quad", "amount": 48},
	"ground": {"mesh": "plane", "amount": 64},
}

## Fire basic attacks: false = trail of puffs behind the fireball, true = a
## flame jet (a continuous spray of puffs, Brawl Stars style).
var fire_basic_spray := false
const MAX_SPRAYS := 6
## Scorch marks alive at once.
const MAX_DECALS := 24
const MAX_PER_CALL := 40
## Bolts alive at once (all bolts share one mesh).
const BOLT_POOL := 10
## Sky strikes alive at once.
const MAX_SKY := 3
## Crescents alive at once.
const MAX_SWIPES := 40
const REFORK := 0.06

var quality_low := false
## Hooks the hunt sets: on_shake(amount) and on_freeze(seconds).
var on_shake := Callable()
var on_freeze := Callable()
var _layers := {}
var _live: Array = []  # waves, fields, sprays, spikes, later
var _strips: Array = []  # bolts and crescents (one ImmediateMesh)
var _strip_mi: MeshInstance3D
var _noise: NoiseTexture2D
var _now := 0.0
var _last_freeze := -9.0
var _n_mult := 1.0
var _ground := 1.0
var _gdur := 1.0
## Counters the tests read.
var built := {"layer": 0, "strip": 0, "decal": 0}


func _init() -> void:
	name = "VfxLib"
	_noise = NoiseTexture2D.new()
	_noise.seamless = true
	_noise.width = 128
	_noise.height = 128
	var fn := FastNoiseLite.new()
	fn.frequency = 0.022
	_noise.noise = fn
	_strip_mi = MeshInstance3D.new()
	_strip_mi.name = "Strips"
	_strip_mi.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strip_mi.material_override = m
	_strip_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strip_mi.custom_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 40, 160))
	_strip_mi.visible = false
	add_child(_strip_mi)
	built["strip"] = 1


# --- Public API ----------------------------------------------------------

## Any element, any variant. `r` is the area radius (impact/nova/linger) or
## the effect scale; `dir` aims casts and trails; `dur` sets nova/linger time.
func play(el: StringName, variant: StringName, pos: Vector3, r := 1.0, dir := Vector3.ZERO, dur := -1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	if not COLORS.has(el):
		el = &"physical"
	if not TIER.has(tier):
		tier = &"skill"
	var T: Dictionary = TIER[tier]
	var c: Color = tint if tint.a > 0.0 else COLORS[el]
	c.a = 1.0
	_n_mult = float(T["n"]) * (0.5 if quality_low else 1.0)
	_ground = float(T["ground"])
	_gdur = float(T["gdur"])
	match variant:
		&"cast": _cast(el, pos, r, c, T, tier)
		&"travel": _travel(el, pos, dir, c, tier)
		&"impact": _impact(el, pos, r, c, T, tier)
		&"nova": _nova(el, pos, r, c, T, tier, dur)
		&"linger": _linger(el, pos, r, c, T, dur)
	_n_mult = 1.0
	_ground = 1.0
	_gdur = 1.0


func cast(el: StringName, pos: Vector3, r := 1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"cast", pos, r, Vector3.ZERO, -1.0, tint, tier)


func travel(el: StringName, pos: Vector3, dir := Vector3.ZERO, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"travel", pos, 1.0, dir, -1.0, tint, tier)


func impact(el: StringName, pos: Vector3, r := 1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"impact", pos, r, Vector3.ZERO, -1.0, tint, tier)


## A burst of the element racing out to `r` over `dur`: a ragged front of
## varied puffs (spikes for frost/nature/stone), one shockwave that belongs
## to the blast, and a scorch left behind.
func nova(el: StringName, pos: Vector3, r := 3.0, dur := -1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"nova", pos, r, Vector3.ZERO, dur, tint, tier)


func linger(el: StringName, pos: Vector3, r := 1.5, dur := 2.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"linger", pos, r, Vector3.ZERO, dur, tint, tier)


## Which element a colour means (for callers that only have a colour).
static func element_for(c: Color) -> StringName:
	if c.s < 0.22:
		return &"holy" if c.v > 0.92 else &"physical"
	var h := c.h
	if (h > 0.95 or h < 0.02) and c.v < 0.9 and c.s > 0.6:
		return &"blood"
	if h < 0.105 or h > 0.95:
		return &"fire"
	if h < 0.17:
		return &"holy"
	if h < 0.3:
		return &"poison"
	if h < 0.45:
		return &"heal" if c.v > 0.9 else &"nature"
	if h < 0.6:
		return &"frost"
	if h < 0.68:
		return &"storm"
	return &"shadow"


## Tier-tied camera shake and hit freeze (rate limited, so a crowd of big
## hits is one freeze, not a stutter).
func kick(tier: StringName) -> void:
	var T: Dictionary = TIER.get(tier, TIER[&"skill"])
	if float(T["shake"]) > 0.0 and on_shake.is_valid():
		on_shake.call(float(T["shake"]))
	if float(T["freeze"]) > 0.0 and on_freeze.is_valid() and _now - _last_freeze > 0.4:
		_last_freeze = _now
		on_freeze.call(float(T["freeze"]))


# --- Variants ----------------------------------------------------------------

## Anticipation: the element gathers into the hand, then pops.
func _cast(el: StringName, pos: Vector3, r: float, c: Color, T: Dictionary, tier: StringName) -> void:
	var hand := pos + Vector3(0, 1.1, 0)
	var k: float = T["core"]
	var n := _n(4)
	for i in n:
		var off := Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.5), randf_range(-0.6, 0.6)) * r
		puff_el(el, hand + off, 0.2 * k, -off * 3.5, 0.22, c)
	star(hand, 0.45 * k, c, 0.16, _pts(el))
	match el:
		&"storm":
			if tier != &"light":
				bolt_arc(hand, 0.6 * r, c)
		&"frost", &"holy", &"buff", &"level":
			if tier != &"light":
				for i in _n(3):
					var o := Vector3(randf_range(-1, 1), randf_range(0, 0.6), randf_range(-1, 1)) * 0.9 * r
					chunk(hand + o, -o * 3.0, DEBRIS[el][0], 0.16, 0.3, int(DEBRIS[el][1]), 0.0)
		&"heal":
			for i in _n(4):
				var a := TAU * i / 4.0 + randf() * 0.5
				puff_el(el, pos + Vector3(sin(a) * 0.6 * r, 0.3, cos(a) * 0.6 * r), randf_range(0.2, 0.32) * k, Vector3(0, 2.2, 0), 0.5, c, i * 0.05)
	if tier == &"big":
		_core_ball(hand, c, el, 0.6)
		for i in _n(6):
			var off := Vector3(randf_range(-1, 1), randf_range(0.0, 0.8), randf_range(-1, 1)).normalized() * 1.8 * r
			puff_el(el, hand + off, 0.22, -off * 2.6, 0.36, c, i * 0.05)


## One trail piece per call (projectiles call it every few frames): a
## varied puff that pops and dissolves behind the head.
func _travel(el: StringName, pos: Vector3, dir: Vector3, c: Color, tier: StringName) -> void:
	var sp := dir.length()
	var fwd := dir / sp if sp > 0.01 else Vector3.FORWARD
	var light := tier == &"light"
	if el == &"fire" and light and fire_basic_spray:
		spray(el, pos - Vector3(0, 0.7, 0), fwd, 1.1, 0.22, 0.05, c, &"light")
		return
	var j := Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	var sz := randf_range(0.22, 0.34) if light else randf_range(0.3, 0.45)
	puff_el(el, pos - fwd * 0.15 + j, sz, Vector3(0, 0.6, 0) - fwd * 0.5, randf_range(0.2, 0.3), c)
	if el == &"storm" and randf() < 0.3:
		spark(pos, -fwd * 3.0 + _rnd(2.0), c, 0.2)
	elif not light and el in [&"frost", &"nature", &"holy"] and randf() < 0.35:
		chunk(pos, -fwd * 1.5 + _rnd(0.8), DEBRIS[el][0], 0.12, 0.4, int(DEBRIS[el][1]), -6.0)


func _impact(el: StringName, pos: Vector3, r: float, c: Color, T: Dictionary, tier: StringName) -> void:
	var k: float = T["core"]
	var light := tier == &"light"
	var hp := pos + Vector3(0, 0.7, 0)
	r = clampf(r, 0.4, 4.0)
	var spread := clampf(0.35 + r * 0.22, 0.4, 1.4)
	star(hp, (0.55 + 0.3 * r) * k, c, 0.15 if light else 0.17, _pts(el))
	var np := _n(5 + int(r * 1.5))
	for i in np:
		var o := Vector3(randf_range(-1, 1) * spread, randf_range(-0.2, 0.35), randf_range(-1, 1) * spread)
		var sz := randf_range(0.55, 0.95) * maxf(k, 0.8) * clampf(0.6 + r * 0.25, 0.6, 1.6)
		var up := Vector3(0, 1.6, 0) if el in [&"heal", &"buff", &"level", &"holy"] else Vector3(0, 1.2, 0)
		puff_el(el, hp + o, sz, o * 2.0 + up, randf_range(0.34, 0.48) * (1.0 if light else 1.1), c, i * 0.02)
	sparks(hp, _n(4 + int(r * 2.0)), 6.5 + r, _spark_col(el, c), 0.3 if light else 0.38)
	if el == &"storm":
		for i in int(T["bolts"]) if not light else 1:
			var a := randf() * TAU
			bolt(PackedVector3Array([hp + Vector3(0, 0.3, 0), pos + Vector3(sin(a), 0.1, cos(a)) * r * randf_range(0.7, 1.1)]), c, not light, 0.08 if light else 0.11, 0.14 if light else 0.24)
	if light:
		return
	# Follow-through: smoke, debris, a shockwave tied to the blast, a mark.
	if el in [&"fire", &"physical", &"storm", &"shadow"]:
		for i in _n(3):
			smoke(pos + Vector3(randf_range(-0.5, 0.5) * spread * 1.4, 0.3, randf_range(-0.5, 0.5) * spread * 1.4), randf_range(0.35, 0.5) * k, Vector3(0, 1.3, 0), 0.6, 0.12)
	debris(pos, int(ceil((3 + r * 2.0) * float(T["debris"]))), 3.5 + r, el)
	if tier == &"big" or r >= 1.5:
		shockwave(pos, r * 1.15, c, 0.24)
	if SPIKES.has(el) and (el != &"physical" or tier == &"big"):
		_spikes(el, pos, 0.9 * r, int(6 * float(T["spikes"])), 0.8 * r * k, c, 0.5, false)
	decal(el, pos, r * 0.9, 1.6)
	if tier == &"big":
		if el in [&"storm", &"holy", &"level"]:
			sky(pos, c, 0.24)
	kick(tier)


func _nova(el: StringName, pos: Vector3, r: float, c: Color, T: Dictionary, tier: StringName, dur: float) -> void:
	var d := dur if dur > 0.0 else clampf(0.25 + r * 0.06, 0.3, 0.7)
	var light := tier == &"light"
	if tier == &"big":
		shockwave(pos, r, c, minf(d, 0.26), true)
	var total := clampf(r * 4.0, 6.0, 26.0) * _n_mult
	_live.append({"kind": "wave", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": d, "acc": 0.0, "rate": total / d, "k": float(T["core"]), "light": light})
	if light:
		return
	if SPIKES.has(el) and (el != &"physical" or tier == &"big"):
		_live.append({"kind": "spikes", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": d, "acc": 0.0, "k": float(T["core"])})
	star(pos + Vector3(0, 0.8, 0), 0.9 * float(T["core"]), c, 0.16, _pts(el))
	sparks(pos + Vector3(0, 0.5, 0), _n(8), 8.0, _spark_col(el, c), 0.4)
	decal(el, pos, r * 0.6, maxf(d * 2.5, 1.4))
	if tier == &"big":
		debris(pos, int(6 * float(T["debris"])), 5.0, el)
		if el in [&"storm", &"holy", &"level"]:
			sky(pos, c, 0.26)
	kick(tier)


func _linger(el: StringName, pos: Vector3, r: float, c: Color, T: Dictionary, dur: float) -> void:
	if dur <= 0.0:
		dur = 2.0
	var g := _ground
	_ground = maxf(_ground, 1.0)
	decal(el, pos, r, dur + 0.4)
	_ground = g
	_live.append({"kind": "field", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": dur, "acc": 0.0, "k": float(T["core"]), "m": _n_mult})


# --- Building blocks ---------------------------------------------------------

func _pts(el: StringName) -> float:
	return float(STAR_PTS.get(el, 5.0))


func _spark_col(el: StringName, c: Color) -> Color:
	if el == &"fire" or el == &"physical":
		return Color(1.0, 0.78, 0.25)
	return c.lightened(0.25)


## Rim band for a colour: the element's own, or a darker hue-shifted one.
func _rim(el: StringName, c: Color, tinted: bool) -> Vector2:
	if not tinted and RIM.has(el):
		var rr: Array = RIM[el]
		return Vector2(float(rr[0]), float(rr[1]))
	var h := c.h - 0.03 if c.h < 0.2 else c.h + 0.02
	return Vector2(fposmod(h, 1.0), clampf(c.v * 0.5, 0.2, 0.8))


func puff_el(el: StringName, p: Vector3, size: float, v: Vector3, life: float, c: Color, delay := 0.0) -> void:
	var rim := _rim(el, c, c != COLORS.get(el, c))
	puff(p, size, v, life, c, rim, delay)


## A chunky toon puff: pops up with overshoot, drifts, then erodes away.
## `rim` = (hue, value) of its dark band.
func puff(p: Vector3, size: float, v: Vector3, life: float, body: Color, rim := Vector2(0.03, 0.6), delay := 0.0) -> void:
	var sq := Vector3(randf_range(0.85, 1.15), randf_range(0.8, 1.1), randf_range(0.85, 1.15))
	_add("toon", p, v, body, size, life, delay, sq, Vector3.UP, 0.0, Color(randf() * 10.0, 0.0, rim.x, rim.y))


## Grey-brown smoke puff (fire, dust, rubble).
func smoke(p: Vector3, size: float, v: Vector3, life: float, delay := 0.0) -> void:
	puff(p, size, v, life, Color(0.46, 0.41, 0.38), Vector2(0.03, 0.24), delay)


## A charging core: a toon ball that grows and churns, then pops.
func _core_ball(p: Vector3, c: Color, el: StringName, life: float) -> void:
	var rim := _rim(el, c, c != COLORS.get(el, c))
	_add("toon", p, Vector3.ZERO, c, 1.1, life, 0.0, Vector3.ONE, Vector3.UP, 2.0, Color(randf() * 10.0, 0.0, rim.x, rim.y))


## Spiky billboard hit star: white core, coloured rim, hollows out.
func star(p: Vector3, size: float, c: Color, life: float, spikes := 5.0) -> void:
	_add("star", p, Vector3.ZERO, c, size, life, 0.0, Vector3.ONE, Vector3.UP, spikes, Color(randf() * TAU, 0, spikes, 0))


## Fat stretched sparks thrown out of `p`; one in three is white-hot.
func sparks(p: Vector3, n: int, speed: float, c: Color, life := 0.35, upk := 0.6) -> void:
	n = mini(n, MAX_PER_CALL)
	for i in n:
		var ang := TAU * (i + randf() * 0.6) / maxf(n, 1)
		var v := Vector3(cos(ang), randf_range(0.2, 1.0) * upk, sin(ang)).normalized() * speed * randf_range(0.7, 1.2)
		spark(p, v, c if i % 3 else Color(1, 1, 0.92), life * randf_range(0.8, 1.2))


func spark(p: Vector3, v: Vector3, c: Color, life := 0.3) -> void:
	_add("spark", p, v, c, 1.0, life)


## Toon chunks hopping out of `p` and bouncing once: the element's debris.
func debris(p: Vector3, n: int, speed: float, el: StringName = &"physical") -> void:
	var d: Array = DEBRIS.get(el, DEBRIS[&"physical"])
	for i in mini(_n(n), MAX_PER_CALL):
		var ang := randf() * TAU
		var v := Vector3(cos(ang), randf_range(1.2, 2.0), sin(ang)) * speed * randf_range(0.6, 1.1)
		chunk(p + Vector3(0, 0.2, 0), v, d[0], randf_range(0.12, 0.26), 0.85, int(d[1]))


## One chunk. shape: 0 rock, 1 shard, 2 leaf, 3 drop. grav < 0 overrides gravity.
func chunk(p: Vector3, v: Vector3, c: Color, size: float, life: float, shape := 0, grav := -22.0) -> void:
	var sh := Vector3(1.0, 0.8, 1.1)
	match shape:
		1: sh = Vector3(0.45, 1.6, 0.45)
		2: sh = Vector3(1.3, 0.18, 0.8)
		3: sh = Vector3(0.7, 0.9, 0.7)
	sh *= Vector3(randf_range(0.8, 1.2), randf_range(0.8, 1.2), randf_range(0.8, 1.2))
	var rim := Vector2(fposmod(c.h - 0.02, 1.0), clampf(c.v * 0.45, 0.15, 0.6))
	_add("chunk", p, v, c, size, life, 0.0, sh, Vector3(randf(), randf(), randf()).normalized(), grav, Color(randf() * 10.0, 0, rim.x, rim.y))


## Flat ground shapes. mode: 0 shockwave ring, 1 scorch, 2 flash disk,
## 3 telegraph target ring. glow < 0 = white.
func ground(p: Vector3, r: float, mode: int, c: Color, life: float, grow := true, glow := -1.0, y := 0.04) -> int:
	return _add("ground", Vector3(p.x, y + randf() * 0.006, p.z), Vector3.ZERO, c, r, life, 0.0, Vector3(1.0 if grow else 0.0, 0, 0), Vector3.UP, float(mode), Color(float(mode), 0, randf(), glow))


## A brief ring that belongs to an impact or nova: thick, white inside,
## thinning as it races out. Never a lingering decoration.
func shockwave(p: Vector3, r: float, c: Color, life := 0.3, _nova := false) -> void:
	if r < 0.3:
		return
	ground(p, r, 0, c, life, true, -1.0, 0.05)


func flash_disk(p: Vector3, r: float, c: Color) -> void:
	ground(p, r, 2, c, 0.16, true, -1.0, 0.055)


## A telegraph target ring (rim + fill that tightens to the hit). The only
## ring a caller may place on purpose, and only as a warning.
func target(p: Vector3, r: float, c: Color, life: float) -> void:
	ground(p, r, 3, Color(c.r, c.g, c.b, 1.0), life, false, -1.0, 0.045)


## Scorch / crack mark that cools and erodes away. Capped at MAX_DECALS.
func decal(el: StringName, pos: Vector3, r: float, dur := 2.0, _tint := Color(1, 1, 1, 1)) -> void:
	if _ground <= 0.0 or not DECALS.has(el):
		return
	r *= _ground
	dur *= _gdur
	if r < 0.15:
		return
	var marks := 0
	var oldest := -1
	var oldest_age := -1.0
	if _layers.has("ground"):
		var L: Dictionary = _layers["ground"]
		for i in int(L["top"]):
			if L["age"][i] < L["life"][i] and int(L["prm"][i]) == 1:
				marks += 1
				if L["age"][i] / L["life"][i] > oldest_age:
					oldest_age = L["age"][i] / L["life"][i]
					oldest = i
	if marks >= MAX_DECALS and oldest >= 0:
		_layers["ground"]["age"][oldest] = _layers["ground"]["life"][oldest]
	var d: Array = DECALS[el]
	ground(pos, r, 1, d[0], dur, false, float(d[1]), 0.03)
	built["decal"] = maxi(int(built["decal"]), mini(marks + 1, MAX_DECALS))


## Solid crescent swipe (tapered arc, white leading edge -> colour), sweeping
## from angle a0 to a1 around `center` at height `y`.
func crescent(center: Vector3, r: float, a0: float, a1: float, w: float, c: Color, life := 0.22, y := 0.9) -> void:
	var n := 0
	for s in _strips:
		if s["kind"] == "swipe":
			n += 1
	if n >= MAX_SWIPES:
		return
	_strips.append({"kind": "swipe", "c": center, "r": r, "a0": a0, "a1": a1, "w": w, "col": c, "t": 0.0, "dur": life, "y": y})
	_strip_mi.visible = true


## Thick cartoon bolt between points: dark outline, body, white core; it
## re-jags every REFORK seconds while it lives. Capped at BOLT_POOL alive.
func bolt(points: PackedVector3Array, c := Color(0.45, 0.85, 1.0), forks := true, width := 0.12, dur := 0.22) -> bool:
	if points.size() < 2:
		return false
	if _bolts_live() >= BOLT_POOL:
		for i in _strips.size():
			if _strips[i]["kind"] == "bolt" and not _strips[i].get("sky", false):
				_strips.remove_at(i)
				break
		if _bolts_live() >= BOLT_POOL:
			return false
	_strips.append({"kind": "bolt", "pts": points, "col": c, "forks": forks and not quality_low, "w": width, "t": 0.0, "dur": dur, "re": 99.0, "geo": []})
	_strip_mi.visible = true
	for p in [points[0], points[points.size() - 1]]:
		sparks(p, 3, 4.0, c.lightened(0.3), 0.22)
	return true


## Little arcs crackling round a point (storm casts, stuns).
func bolt_arc(pos: Vector3, r: float, c: Color) -> void:
	var pts := PackedVector3Array()
	var a := randf() * TAU
	for k in 4:
		pts.append(pos + Vector3(sin(a + k * 0.9) * r, randf_range(-0.3, 0.4), cos(a + k * 0.9) * r))
	bolt(pts, c, false, 0.06, 0.18)


func _bolts_live() -> int:
	var n := 0
	for s in _strips:
		if s["kind"] == "bolt":
			n += 1
	return n


## A strike from the sky onto `at`: anticipation-free (callers telegraph),
## a fat re-jagging bolt, a flash disk, a shockwave, a star, sparks, rubble,
## smoke and a crack. Capped at MAX_SKY alive.
func sky(at: Vector3, c := Color(0.45, 0.85, 1.0), width := 0.22, height := 12.0) -> void:
	var live := 0
	for s in _strips:
		if s["kind"] == "bolt" and s.get("sky", false):
			live += 1
	if live >= MAX_SKY:
		return
	var top := at + Vector3(0.6, height, -1.0)
	if bolt(PackedVector3Array([top, at + Vector3(0, 0.1, 0)]), c, true, maxf(width, 0.16), 0.26):
		_strips[_strips.size() - 1]["sky"] = true
	ground(at, 0.9, 2, c, 0.1, true, -1.0, 0.055)
	ground(at, 2.0, 0, c, 0.24, true, -1.0, 0.05)
	star(at + Vector3(0, 0.5, 0), 1.3, c, 0.14, 8.0)
	sparks(at + Vector3(0, 0.3, 0), 10, 8.0, c.lightened(0.2), 0.3)
	debris(at, 6, 3.5, &"storm")
	for i in 3:
		smoke(at + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6)), 0.4, Vector3(0, 1.0, 0), 0.5, 0.08)
	var g := _ground
	_ground = maxf(_ground, 1.0)
	decal(&"holy" if element_for(c) == &"holy" else &"storm", at, 1.3, 1.3)
	_ground = g
	if on_shake.is_valid():
		on_shake.call(0.45)
	if on_freeze.is_valid() and _now - _last_freeze > 0.4:
		_last_freeze = _now
		on_freeze.call(0.05)


## Faceted toon spikes (ice, thorns, stone, void) in a disc.
func _spikes(el: StringName, pos: Vector3, r: float, n: int, h: float, c: Color, life: float, ring: bool) -> void:
	n = mini(n, 16)
	var col: Color = DEBRIS[el][0] if el != &"shadow" else c
	for i in n:
		var an := TAU * i / maxf(n, 1) + randf() * 0.6
		var rr := r * (0.9 + randf() * 0.2) if ring else r * sqrt(randf())
		var at := pos + Vector3(sin(an), 0, cos(an)) * rr
		var up := Vector3(sin(an) * (0.5 + rr * 0.3), 1.2, cos(an) * (0.5 + rr * 0.3))
		spike(at, up, col, h * randf_range(0.7, 1.3), life * randf_range(0.9, 1.1))


func spike(at: Vector3, up: Vector3, c: Color, h: float, life: float) -> void:
	var rim := Vector2(fposmod(c.h - 0.02, 1.0), clampf(c.v * 0.45, 0.15, 0.6))
	_add("spike", at, Vector3.ZERO, c, h, life, 0.0, Vector3(randf_range(0.8, 1.3), 1, randf_range(0.8, 1.3)), up, 0.0, Color(randf() * 10.0, 0, rim.x, rim.y))


func _later(delay: float, fn: Callable) -> void:
	_live.append({"kind": "later", "t": 0.0, "dur": maxf(delay, 0.001), "fn": fn})


## A continuous flame jet: overlapping varied puffs fired along `dir`,
## spreading into a cone of half-angle `cone`, for `dur` seconds.
func spray(el: StringName, pos: Vector3, dir: Vector3, length := 4.0, cone := 0.45, dur := 0.45, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	if not COLORS.has(el):
		el = &"fire"
	var f := Vector3(dir.x, 0, dir.z)
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var live := 0
	for e in _live:
		if e["kind"] == "spray":
			live += 1
	if live >= MAX_SPRAYS:
		return
	var light := tier == &"light"
	var c: Color = tint if tint.a > 0.0 else COLORS[el]
	_live.append({"kind": "spray", "el": el, "pos": pos, "dir": f, "len": length, "cone": cone, "c": c, "t": 0.0, "dur": dur, "acc": 0.0,
		"rate": (40.0 if light else 80.0) * (0.5 if quality_low else 1.0), "light": light})
	if not light:
		var gd := _gdur
		_later(dur * 0.6, func(): decal(el, pos + f * length * 0.6, length * 0.3, 2.0 * gd))


# --- Batched layers ----------------------------------------------------------

func layer(n: String) -> MultiMeshInstance3D:
	if _layers.has(n):
		return _layers[n]["node"]
	var d: Dictionary = LAYERS[n]
	var cap := int(d["amount"]) / (2 if quality_low else 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var mat: Material
	match str(d["mesh"]):
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 16
			sm.rings = 8
			mm.mesh = sm
		"box":
			mm.mesh = BoxMesh.new()
		"cone":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.18
			cm.height = 1.0
			cm.radial_segments = 5
			cm.rings = 1
			mm.mesh = cm
		"prism":
			var pm := PrismMesh.new()
			pm.size = Vector3(0.16, 0.7, 0.16)
			mm.mesh = pm
		"quad":
			var q := QuadMesh.new()
			q.size = Vector2(2, 2)
			mm.mesh = q
		"plane":
			var pl := PlaneMesh.new()
			pl.size = Vector2(2, 2)
			mm.mesh = pl
	match n:
		"toon", "chunk", "spike":
			var sh := ShaderMaterial.new()
			sh.shader = TOON
			sh.set_shader_parameter("nz", _noise)
			mat = sh
		"star":
			var st := ShaderMaterial.new()
			st.shader = STAR
			st.render_priority = 2
			mat = st
		"ground":
			var gm := ShaderMaterial.new()
			gm.shader = GROUND
			gm.set_shader_parameter("nz", _noise)
			gm.render_priority = -1
			mat = gm
		_:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
			mat = m
	mm.instance_count = cap
	for i in cap:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "L_" + n
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 40, 160))
	node.visible = false
	add_child(node)
	var L := {"node": node, "mm": mm, "cap": cap, "next": 0, "alive": 0, "top": 0}
	for key in ["pos", "vel", "sh", "ax"]:
		var a := PackedVector3Array(); a.resize(cap); L[key] = a
	for key in ["age", "life", "size", "prm"]:
		var f := PackedFloat32Array(); f.resize(cap); L[key] = f
	var col := PackedColorArray(); col.resize(cap); L["col"] = col
	var aux := PackedColorArray(); aux.resize(cap); L["aux"] = aux
	(L["age"] as PackedFloat32Array).fill(1e9)
	(L["life"] as PackedFloat32Array).fill(1.0)
	_layers[n] = L
	built["layer"] += 1
	return node


## Add one piece to a layer. Delay is a negative starting age.
func _add(n: String, p: Vector3, v: Vector3, c: Color, size: float, life: float, delay := 0.0, sh := Vector3.ONE, ax := Vector3.UP, prm := 0.0, aux := Color()) -> int:
	layer(n)
	var L: Dictionary = _layers[n]
	var cap: int = L["cap"]
	var i: int = L["next"]
	L["next"] = (i + 1) % cap
	L["top"] = maxi(int(L["top"]), i + 1)
	L["pos"][i] = p
	L["vel"][i] = v
	L["col"][i] = c
	L["age"][i] = -maxf(delay, 0.0)
	L["life"][i] = maxf(life, 0.02)
	L["size"][i] = size
	L["sh"][i] = sh
	L["ax"][i] = ax.normalized() if ax.length_squared() > 0.0001 else Vector3.UP
	L["prm"][i] = prm
	L["aux"][i] = aux
	(L["node"] as Node3D).visible = true
	(L["mm"] as MultiMesh).visible_instance_count = int(L["top"])
	return i


static func ease_pop(k: float) -> float:
	# Overshoot pop: 0 -> 1.18 -> 1.
	if k < 0.35:
		return sin(k / 0.35 * PI * 0.5) * 1.18
	return lerpf(1.18, 1.0, (k - 0.35) / 0.65)


## Hard-edged dissolve: a puff holds its shape, then erodes from k = 0.45.
static func erode_at(k: float) -> float:
	return clampf((k - 0.45) / 0.55, 0.0, 1.0)


const HIDE := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)


func _tick_layer(n: String, L: Dictionary, dt: float) -> void:
	var mm: MultiMesh = L["mm"]
	var pos: PackedVector3Array = L["pos"]
	var vel: PackedVector3Array = L["vel"]
	var age: PackedFloat32Array = L["age"]
	var life: PackedFloat32Array = L["life"]
	var size: PackedFloat32Array = L["size"]
	var sh: PackedVector3Array = L["sh"]
	var ax: PackedVector3Array = L["ax"]
	var prm: PackedFloat32Array = L["prm"]
	var col: PackedColorArray = L["col"]
	var aux: PackedColorArray = L["aux"]
	var alive := 0
	var top := 0
	for i in int(L["top"]):
		var a := age[i]
		var lf := life[i]
		if a >= lf:
			continue
		a += dt
		age[i] = a
		if a >= lf:
			mm.set_instance_transform(i, HIDE)
			continue
		alive += 1
		top = i + 1
		if a < 0.0:
			mm.set_instance_transform(i, HIDE)
			continue
		var k := a / lf
		var p := pos[i]
		var v := vel[i]
		var cu := aux[i]
		var t := HIDE
		match n:
			"toon":
				p += v * dt * (1.0 - k)
				var s := size[i]
				if prm[i] > 1.5:
					# Charging core: grows and churns, no erosion until it pops.
					s *= (0.2 + k * 0.9) * (1.0 + sin(a * 50.0) * 0.08)
					cu.g = 0.0
				else:
					s *= ease_pop(minf(k * 2.2, 1.0)) * (1.0 + k * 0.25)
					cu.g = erode_at(k)
				t = Transform3D(Basis().scaled(sh[i] * s), p)
			"chunk":
				var g := prm[i]
				v.y += g * dt
				p += v * dt
				if g < -10.0 and p.y < 0.08 and v.y < 0.0:
					p.y = 0.08
					v = Vector3(v.x * 0.4, -v.y * 0.3, v.z * 0.4)
				var spin := a * 12.0 * (1.0 if p.y > 0.1 else 0.2)
				var sc := size[i] * (1.0 - clampf((k - 0.7) / 0.3, 0.0, 1.0))
				t = Transform3D(Basis(ax[i], spin + cu.r).scaled(sh[i] * maxf(sc, 0.001)), p)
			"spike":
				var gk := clampf(k / 0.22, 0.02, 1.0)
				if k > 0.85:
					gk *= maxf((1.0 - k) / 0.15, 0.02)
				var up := ax[i]
				var b := Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) < 0.999 else Basis()
				b = b.rotated(up, cu.r)
				var hh := size[i]
				t = Transform3D(b.scaled(Vector3(hh * sh[i].x, hh * gk, hh * sh[i].z)), p + up * hh * gk * 0.5)
			"spark":
				v.y -= 14.0 * dt
				p += v * dt
				var s2 := 1.0 - k
				var dirv := v.normalized() if v.length_squared() > 0.0001 else Vector3.UP
				var side := dirv.cross(Vector3.UP if absf(dirv.y) < 0.95 else Vector3.RIGHT).normalized()
				var fw := side.cross(dirv).normalized()
				t = Transform3D(Basis(side * s2, dirv * s2 * (0.6 + v.length() * 0.12), fw * s2), p)
			"star":
				cu.g = clampf((k - 0.4) / 0.6, 0.0, 1.0)
				cu.a = size[i] * ease_pop(minf(k * 3.0, 1.0))
				t = Transform3D(Basis(), p)
			"ground":
				var mode := int(prm[i])
				var r := size[i]
				if sh[i].x > 0.5:
					r *= 1.0 - pow(1.0 - minf(k, 1.0), 3.0)
				if mode == 1:
					cu.g = clampf((k - 0.55) / 0.45, 0.0, 1.0)
				elif mode == 2:
					cu.g = clampf((k - 0.3) / 0.7, 0.0, 1.0)
				else:
					cu.g = k
				t = Transform3D(Basis(Vector3.UP, cu.b * TAU).scaled(Vector3(r, 1, r)), p)
		pos[i] = p
		vel[i] = v
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, col[i])
		mm.set_instance_custom_data(i, cu)
	L["pos"] = pos
	L["vel"] = vel
	L["age"] = age
	L["alive"] = alive
	L["top"] = top
	mm.visible_instance_count = top
	if alive == 0:
		(L["node"] as Node3D).visible = false


func _n(count: int) -> int:
	if _n_mult != 1.0:
		count = int(ceil(count * _n_mult))
	return mini(count, MAX_PER_CALL)


func _rnd(s: float) -> Vector3:
	return Vector3(randf_range(-s, s), randf_range(-s, s) * 0.6, randf_range(-s, s))


# --- Waves, fields and sprays (driven per frame) -----------------------------

## A nova's front: varied puffs (sizes, timing, angles all random) thrown up
## where the front is, so it reads as one ragged blast, not a ring of stamps.
func _tick_wave(e: Dictionary, k: float, dt: float) -> void:
	var el: StringName = e["el"]
	var r: float = e["r"]
	var front := r * (1.0 - pow(1.0 - k, 2.0))
	var c: Color = e["c"]
	e["acc"] = float(e["acc"]) + float(e["rate"]) * dt
	var n := mini(int(e["acc"]), 6)
	e["acc"] = float(e["acc"]) - n
	var pos: Vector3 = e["pos"]
	var kk: float = e["k"]
	for i in n:
		var a := randf() * TAU
		var dirv := Vector3(sin(a), 0, cos(a))
		var at := pos + dirv * front * randf_range(0.55, 1.05) + Vector3(0, randf_range(0.15, 0.6), 0)
		var sz := randf_range(0.4, 0.85) * kk * (0.6 if e["light"] else 1.0) * clampf(0.7 + r * 0.08, 0.7, 1.3)
		if el == &"physical":
			smoke(at, sz, dirv * 2.0 + Vector3(0, 1.0, 0), randf_range(0.35, 0.5))
		else:
			puff_el(el, at, sz, dirv * 2.5 + Vector3(0, 1.4, 0), randf_range(0.3, 0.45), c)
		if not e["light"] and randf() < 0.25:
			var d: Array = DEBRIS[el]
			chunk(at, dirv * 3.0 + Vector3(0, 5.0, 0), d[0], randf_range(0.12, 0.22), 0.7, int(d[1]))
		if el == &"storm" and randf() < 0.15 and not quality_low and not e["light"]:
			bolt(PackedVector3Array([at, at + dirv * 0.9 + Vector3(0, 0.1, 0)]), c, false, 0.06, 0.14)


## Spikes racing out with a nova front.
func _tick_spikes(e: Dictionary, k: float, dt: float) -> void:
	var r: float = e["r"]
	var front := r * (1.0 - pow(1.0 - k, 2.0))
	e["acc"] = float(e["acc"]) + dt * TAU * r / 0.8 / maxf(float(e["dur"]), 0.2) * float(e["k"]) * (0.5 if quality_low else 1.0)
	var n := mini(int(e["acc"]), 6)
	e["acc"] = float(e["acc"]) - n
	var el: StringName = e["el"]
	var pos: Vector3 = e["pos"]
	var col: Color = DEBRIS[el][0] if el != &"shadow" else e["c"]
	for i in n:
		var an := randf() * TAU
		var at := pos + Vector3(sin(an), 0, cos(an)) * front
		spike(at, Vector3(sin(an) * 0.6, 1.0, cos(an) * 0.6), col, randf_range(0.5, 0.9) * float(e["k"]), 0.36)


## A lingering field: small puffs bubbling up inside it (bubbles, embers,
## motes), crackles for storm, little crystals for frost/nature.
func _tick_field(e: Dictionary, dt: float) -> void:
	var el: StringName = e["el"]
	var r: float = e["r"]
	e["acc"] = float(e["acc"]) + dt * clampf(r * 3.0, 2.5, 9.0) * (0.5 if quality_low else 1.0) * float(e.get("m", 1.0))
	var n := mini(int(e["acc"]), 3)
	e["acc"] = float(e["acc"]) - n
	var pos: Vector3 = e["pos"]
	var c: Color = e["c"]
	for i in n:
		var a := randf() * TAU
		var at := pos + Vector3(sin(a), 0, cos(a)) * r * sqrt(randf())
		match el:
			&"storm":
				if _bolts_live() < BOLT_POOL / 2:
					bolt_arc(at + Vector3(0, 0.4, 0), 0.4, c)
			&"frost", &"nature":
				spike(at, Vector3(randf_range(-0.3, 0.3), 1, randf_range(-0.3, 0.3)), DEBRIS[el][0], randf_range(0.3, 0.55), 0.8)
			&"physical":
				smoke(at + Vector3(0, 0.2, 0), randf_range(0.25, 0.4), Vector3(0, 0.6, 0), 0.5)
			_:
				puff_el(el, at + Vector3(0, 0.25, 0), randf_range(0.18, 0.34) * float(e["k"]), Vector3(0, 1.4, 0), randf_range(0.4, 0.6), c)


func _tick_spray(e: Dictionary, k: float, dt: float) -> void:
	if k >= 1.0:
		return
	e["acc"] = float(e["acc"]) + float(e["rate"]) * dt
	var n := mini(int(e["acc"]), 8)
	e["acc"] = float(e["acc"]) - n
	var f: Vector3 = e["dir"]
	var side := f.cross(Vector3.UP)
	var ln: float = e["len"]
	var light: bool = e["light"]
	var life := 0.3 if light else 0.4
	var speed := ln / life * 1.6
	var c: Color = e["c"]
	for i in n:
		var a := randf_range(-1.0, 1.0) * float(e["cone"])
		var v := (f * cos(a) + side * sin(a) + Vector3(0, randf_range(-0.05, 0.15), 0)) * speed * randf_range(0.8, 1.15)
		var p: Vector3 = e["pos"] + Vector3(0, 0.7, 0) + f * randf_range(0.1, 0.4)
		var cc := c.lerp(Color(1.0, 0.85, 0.45), randf() * 0.35)
		var g := 1.0 + tan(float(e["cone"])) * ln * 0.5
		puff_el(e["el"], p, randf_range(0.35, 0.55) * (0.7 if light else 1.0) * g, v, life * randf_range(0.8, 1.2), cc)
	if not light and randf() < 0.25:
		smoke(e["pos"] + Vector3(0, 0.9, 0) + f * ln * randf_range(0.6, 1.0), 0.35, Vector3(0, 1.2, 0), 0.5)


# --- Strips: bolts and crescents (one ImmediateMesh) -------------------------

func _jag(a: Vector3, b: Vector3, steps: int, amp: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var len_ := a.distance_to(b)
	for j in steps + 1:
		var t := float(j) / steps
		var p := a.lerp(b, t)
		if j > 0 and j < steps:
			p += Vector3(randf_range(-1, 1), randf_range(-0.4, 0.5), randf_range(-1, 1)) * amp * minf(1.0, len_ / 3.0)
		out.append(p)
	return out


func _bolt_paths(s: Dictionary) -> Array:
	var paths: Array = []
	var pts: PackedVector3Array = s["pts"]
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		var steps := clampi(int(seg / 0.7), 3, 12)
		var path := _jag(pts[i], pts[i + 1], steps, 0.45)
		paths.append([path, 1.0])
		if s["forks"]:
			for f in 2:
				var j := randi_range(1, path.size() - 2)
				var dirv := (pts[i + 1] - pts[i]).normalized()
				var sd := dirv.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				if sd.length_squared() < 0.01:
					sd = Vector3.RIGHT
				var end := path[j] + (dirv * 0.4 + sd + Vector3(0, -0.4, 0)).normalized() * randf_range(0.7, 1.4)
				paths.append([_jag(path[j], end, 3, 0.2), 0.5])
	return paths


func _strip(im: ImmediateMesh, path: PackedVector3Array, w: float, c: Color, cam: Vector3, lift: float) -> void:
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in path.size():
		var q := path[j] + (cam - path[j]).normalized() * lift
		var d := path[mini(j + 1, path.size() - 1)] - path[maxi(j - 1, 0)]
		var side := d.cross(cam - q).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var ww := w * (1.0 - 0.45 * float(j) / path.size())
		im.surface_set_color(c)
		im.surface_add_vertex(q - side * ww)
		im.surface_set_color(c)
		im.surface_add_vertex(q + side * ww)
	im.surface_end()


func _tick_strips(dt: float) -> void:
	var im := _strip_mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if _strips.is_empty():
		_strip_mi.visible = false
		return
	var vp := get_viewport()
	var camn := vp.get_camera_3d() if vp else null
	var cam := camn.global_position if camn else Vector3(0, 20, 12)
	var i := _strips.size() - 1
	while i >= 0:
		var s: Dictionary = _strips[i]
		s["t"] = float(s["t"]) + dt
		var k := float(s["t"]) / float(s["dur"])
		if k >= 1.0:
			_strips.remove_at(i)
			i -= 1
			continue
		if s["kind"] == "bolt":
			s["re"] = float(s["re"]) + dt
			if float(s["re"]) >= REFORK:
				s["re"] = 0.0
				s["geo"] = _bolt_paths(s)
			var c: Color = s["col"]
			var w := float(s["w"]) * (1.0 - k * 0.6)
			var outline := Color(c.r * 0.3, c.g * 0.4, minf(c.b * 0.95 + 0.1, 1.0)) if c.b >= c.r else c.darkened(0.6)
			for pw in s["geo"]:
				var path: PackedVector3Array = pw[0]
				var m: float = pw[1]
				_strip(im, path, w * 1.6 * m, outline, cam, 0.0)
				_strip(im, path, w * m, c, cam, 0.05)
				_strip(im, path, w * 0.45 * m, Color(1, 1, 1), cam, 0.1)
		else:
			_crescent_geo(im, s, k)
		i -= 1
	_strip_mi.visible = not _strips.is_empty()


func _crescent_geo(im: ImmediateMesh, s: Dictionary, k: float) -> void:
	var head := clampf(k / 0.35, 0.0, 1.0)
	var tail := clampf((k - 0.3) / 0.7, 0.0, 1.0)
	if head - tail < 0.01:
		return
	var n := 16
	var center: Vector3 = s["c"]
	var r: float = s["r"]
	var w: float = s["w"]
	var c: Color = s["col"]
	var y: float = s["y"]
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in n + 1:
		var u := lerpf(tail, head, float(j) / n)
		var ang := lerpf(float(s["a0"]), float(s["a1"]), u)
		var taper := sin(clampf((u - tail) / maxf(head - tail, 0.001), 0.0, 1.0) * PI * 0.5) * (1.0 - tail * 0.6)
		var dirv := Vector3(sin(ang), 0, cos(ang))
		im.surface_set_color(c)
		im.surface_add_vertex(center + dirv * (r - w * taper) + Vector3(0, y, 0))
		im.surface_set_color(Color(1, 1, 0.95))
		im.surface_add_vertex(center + dirv * (r + w * 0.25 * taper) + Vector3(0, y, 0))
	im.surface_end()


func _process(delta: float) -> void:
	_now += delta
	var i := _live.size() - 1
	while i >= 0:
		var e: Dictionary = _live[i]
		e["t"] = float(e["t"]) + delta
		var k := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		match str(e["kind"]):
			"wave":
				_tick_wave(e, k, delta)
			"field":
				_tick_field(e, delta)
			"spikes":
				_tick_spikes(e, k, delta)
			"spray":
				_tick_spray(e, k, delta)
			"later":
				if k >= 1.0:
					(e["fn"] as Callable).call()
		if k >= 1.0:
			_live.remove_at(i)
		i -= 1
	if _strip_mi.visible or not _strips.is_empty():
		_tick_strips(delta)
	for n in _layers:
		var L: Dictionary = _layers[n]
		if (L["node"] as Node3D).visible:
			_tick_layer(n, L, delta)


## Build every layer once, tiny, so the first real hit does not stall on a
## shader compile.
func warmup(at: Vector3) -> void:
	for n in LAYERS:
		_add(n, at, Vector3.ZERO, Color(1, 1, 1), 0.001, 0.05)
	bolt(PackedVector3Array([at, at + Vector3(0.1, 0, 0)]), Color.WHITE, false, 0.001, 0.05)


## Layers drawing right now (each is one draw call). Tests and captures read it.
func active_layers() -> int:
	var c := 0
	for n in _layers:
		if (_layers[n]["node"] as Node3D).visible:
			c += 1
	return c + (1 if _strip_mi.visible else 0)
