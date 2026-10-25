extends Node3D
## Element VFX library: fire, frost, storm, poison, nature, holy, shadow,
## physical, blood, heal, buff and level. Every element has the same variants
## (cast, travel, impact, nova, linger) so any skill, proc, enemy or sidekick
## can say what it is and get a real effect instead of a coloured ring.
##
## Budget (iOS): everything is pooled. Particles live in one MultiMesh per
## sprite layer (CPU-simulated, one draw call each), created on first use and
## hidden once its last particle dies, so an idle layer costs no draw call.
## Ground decals are a small pool of quads. No shadows, no lights: the only
## light an effect may add is Fx.flash_light (tiny, short, capped there).
##
## Art lock: authored hard-edged sprites (tools/art/vfx_textures.py), mostly
## alpha-blended; additive only for small, short accents (sparks, embers,
## motes, rays). No fog, no screen tint, no soft glow blobs.
##
## Not a class_name on purpose (content packs cannot add global classes):
## preload("res://src/vfx/vfx_lib.gd"). Fx owns one as `fx.vfx`.

const DECAL := preload("res://src/vfx/vfx_decal.gdshader")
const CORE := preload("res://src/vfx/vfx_core.gdshader")
const CRYSTAL := preload("res://src/vfx/vfx_crystal.gdshader")
const PUFF := preload("res://src/vfx/vfx_puff.gdshader")
const TEX := "res://assets/vfx/%s.png"

const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"poison", &"nature", &"holy", &"shadow", &"physical", &"blood", &"heal", &"buff", &"level"]
const VARIANTS: Array[StringName] = [&"cast", &"travel", &"impact", &"nova", &"linger"]

## Importance tiers. Every call names one (default skill, the old look):
##   light: basic and auto attacks, sidekick basics, frequent procs. A small
##          dissolve core and a tiny flicker: no ground mark, no shatter, no
##          sky strike, at most one short unforked bolt. Readable at 5+/s.
##   skill: abilities and specials. Procedural core + ground mark + light
##          sprite secondaries.
##   big:   supers, boss attacks, ultimates. Skill, larger and longer ground
##          marks, more bolts and spikes, and a sky strike on storm/holy/level.
## Pass where a caller has no tint but names a tier.
const NO_TINT := Color(0, 0, 0, 0)
const TIERS: Array[StringName] = [&"light", &"skill", &"big"]
const TIER := {
	&"light": {"core": 0.55, "sec": 0.0, "ground": 0.0, "gdur": 0.0, "shatter": false, "sky": false, "bolts": 1, "spikes": 0.0},
	&"skill": {"core": 1.0, "sec": 0.55, "ground": 1.0, "gdur": 1.0, "shatter": true, "sky": false, "bolts": 3, "spikes": 1.0},
	&"big": {"core": 1.35, "sec": 0.9, "ground": 1.45, "gdur": 1.7, "shatter": true, "sky": true, "bolts": 5, "spikes": 1.6},
}

## Procedural core style per element (vfx_core.gdshader / vfx_crystal.gdshader).
const STYLE := {
	&"fire": 0, &"poison": 1, &"blood": 1, &"nature": 1, &"shadow": 2, &"holy": 3, &"heal": 3,
	&"buff": 3, &"level": 3, &"physical": 4, &"storm": 5, &"frost": 5,
}
## Elements whose core is faceted spikes (and their crystal style).
const SPIKES := {&"frost": 0, &"nature": 1, &"physical": 2, &"shadow": 3}

## Default palette per element (tint overrides it where a caller has a colour).
const COLORS := {
	&"fire": Color(1.0, 0.55, 0.18), &"frost": Color(0.7, 0.9, 1.0), &"storm": Color(0.65, 0.82, 1.0),
	&"poison": Color(0.55, 0.85, 0.25), &"nature": Color(0.5, 0.85, 0.35), &"holy": Color(1.0, 0.85, 0.45),
	&"shadow": Color(0.62, 0.38, 0.95), &"physical": Color(0.85, 0.78, 0.65), &"blood": Color(0.8, 0.1, 0.14),
	&"heal": Color(0.45, 1.0, 0.55), &"buff": Color(1.0, 0.85, 0.4), &"level": Color(1.0, 0.85, 0.4),
}

## Ground warning edge per element (assets/vfx/edge_*.png).
const EDGES := {
	&"fire": "fire", &"frost": "frost", &"storm": "storm", &"poison": "poison", &"nature": "poison",
	&"holy": "holy", &"shadow": "shadow", &"physical": "stone", &"blood": "danger", &"heal": "holy",
	&"buff": "holy", &"level": "holy", &"danger": "danger",
}

## Sprite layers. tex, frames (h, v), flipbook (plays once over life) or
## atlas (random frame), blend, life, gravity, damping, size range, spin.
const LAYERS := {
	"flame": {"tex": "flame_flipbook", "hf": 4, "vf": 4, "flip": true, "add": false, "life": 0.55, "grav": Vector3(0, 2.5, 0), "damp": 3.0, "size": Vector2(0.7, 1.1), "amount": 160},
	"flame_lg": {"tex": "flame_flipbook", "hf": 4, "vf": 4, "flip": true, "add": false, "life": 0.7, "grav": Vector3(0, 2.0, 0), "damp": 3.0, "size": Vector2(1.4, 2.0), "amount": 60},
	"ember": {"tex": "ember", "add": true, "life": 0.9, "grav": Vector3(0, 1.6, 0), "damp": 1.2, "size": Vector2(0.1, 0.18), "amount": 200},
	"spark": {"tex": "spark", "add": true, "life": 0.32, "grav": Vector3(0, -12, 0), "damp": 2.0, "size": Vector2(0.18, 0.32), "amount": 220, "spin": 180.0},
	"shard": {"tex": "ice_shards", "hf": 2, "vf": 2, "add": false, "life": 0.75, "grav": Vector3(0, -16, 0), "damp": 0.6, "size": Vector2(0.35, 0.6), "amount": 140, "spin": 360.0},
	"flake": {"tex": "snowflake", "add": false, "life": 1.0, "grav": Vector3(0, -0.6, 0), "damp": 1.5, "size": Vector2(0.14, 0.26), "amount": 90, "spin": 90.0},
	"bubble": {"tex": "bubble", "add": false, "life": 0.8, "grav": Vector3(0, 1.4, 0), "damp": 1.8, "size": Vector2(0.09, 0.2), "amount": 120},
	"spore": {"tex": "spore", "add": false, "life": 1.1, "grav": Vector3(0, 0.5, 0), "damp": 1.6, "size": Vector2(0.1, 0.18), "amount": 100, "spin": 120.0},
	"leaf": {"tex": "leaves", "hf": 2, "vf": 2, "add": false, "life": 1.2, "grav": Vector3(0, -2.2, 0), "damp": 2.4, "size": Vector2(0.22, 0.34), "amount": 120, "spin": 400.0},
	"ray": {"tex": "ray", "add": true, "life": 0.45, "grav": Vector3.ZERO, "damp": 0.0, "size": Vector2(0.8, 1.2), "amount": 48, "quad": Vector2(0.28, 3.0), "fixed_y": true},
	"mote": {"tex": "spark", "add": true, "life": 0.8, "grav": Vector3(0, 1.8, 0), "damp": 1.4, "size": Vector2(0.14, 0.24), "amount": 140, "spin": 90.0},
	"wisp": {"tex": "wisp", "add": false, "life": 0.8, "grav": Vector3(0, 2.2, 0), "damp": 2.0, "size": Vector2(0.45, 0.8), "amount": 120},
	"bone": {"tex": "bone_chips", "hf": 2, "vf": 2, "add": false, "life": 0.7, "grav": Vector3(0, -16, 0), "damp": 0.5, "size": Vector2(0.18, 0.3), "amount": 100, "spin": 540.0},
	"debris": {"tex": "debris", "hf": 2, "vf": 2, "add": false, "life": 0.7, "grav": Vector3(0, -18, 0), "damp": 0.4, "size": Vector2(0.16, 0.32), "amount": 140, "spin": 540.0},
	"dust": {"tex": "dust", "add": false, "life": 0.6, "grav": Vector3(0, 0.6, 0), "damp": 3.5, "size": Vector2(0.5, 0.9), "amount": 120, "spin": 60.0},
	"blood": {"tex": "blood", "hf": 2, "vf": 2, "add": false, "life": 0.5, "grav": Vector3(0, -15, 0), "damp": 0.5, "size": Vector2(0.12, 0.22), "amount": 120},
	"cross": {"tex": "cross", "add": false, "life": 0.9, "grav": Vector3(0, 1.2, 0), "damp": 1.0, "size": Vector2(0.22, 0.34), "amount": 60},
	"chevron": {"tex": "chevron", "add": false, "life": 0.8, "grav": Vector3(0, 2.0, 0), "damp": 0.8, "size": Vector2(0.3, 0.42), "amount": 60},
	# Procedural cores: mesh instances, not sprites. One MultiMesh each.
	"ball": {"mesh": "ball", "life": 0.45, "grav": Vector3.ZERO, "damp": 3.0, "size": Vector2(1, 1), "amount": 96},
	"tongue": {"mesh": "wall", "life": 0.6, "grav": Vector3.ZERO, "damp": 0.0, "size": Vector2(1, 1), "amount": 24},
	"spike": {"mesh": "spike", "life": 0.5, "grav": Vector3.ZERO, "damp": 0.0, "size": Vector2(1, 1), "amount": 160},
	# Volume pieces: seeded noise billboards (sprays, flames, smoke) and a
	# tapering ribbon strip for travel trails.
	"puff": {"mesh": "puff", "life": 0.6, "grav": Vector3(0, 1.2, 0), "damp": 1.2, "size": Vector2(0.5, 0.9), "amount": 260},
	"ribbon": {"mesh": "ribbon", "life": 0.28, "grav": Vector3.ZERO, "damp": 0.0, "size": Vector2(1, 1), "amount": 96},
	"chip": {"mesh": "chip", "life": 0.6, "grav": Vector3(0, -14, 0), "damp": 0.4, "size": Vector2(0.7, 1.2), "amount": 160, "spin": 540.0},
}

const DECALS := {
	&"fire": "scorch", &"frost": "frost", &"poison": "poison", &"nature": "poison", &"holy": "holy",
	&"shadow": "shadow", &"physical": "crack", &"storm": "crack", &"level": "holy", &"heal": "holy",
}

## Sprite layers that read as one stamp pasted many times are never drawn.
## Their emits are rerouted to varied procedural pieces:
## [target layer, style (-1 = element style from colour), size mult, growth].
const REMAP := {
	"flame": ["puff", 0, 0.8, 1.5], "flame_lg": ["puff", 0, 0.75, 1.4], "wisp": ["puff", 2, 0.8, 1.4],
	"dust": ["puff", 4, 0.9, 1.6], "cross": ["puff", 3, 1.3, 1.3], "chevron": ["puff", 3, 1.2, 1.3],
	"shard": ["chip", 0, 1.0, 1.0], "flake": ["chip", 0, 0.6, 1.0], "ray": ["puff", 3, 0.45, 1.3],
}
## Fire basic attacks: false = fireball with ribbon trail, true = a flame jet
## (a continuous spray of puffs, Brawl Stars style).
var fire_basic_spray := false
## Spray jets alive at once.
const MAX_SPRAYS := 6

## Particle cap per call and per frame of a wave, so a screen of procs stays cheap.
const MAX_DECALS := 24
const MAX_PER_CALL := 40
const BOLT_POOL := 10
## Sky strikes alive at once (each holds a pooled bolt).
const MAX_SKY := 3

var quality_low := false
var _layers := {}  # name -> particle state, see layer()
var _decal_mats := {}
var _decal_pool: Array[MeshInstance3D] = []
var _decal_quad: PlaneMesh
var _live: Array = []  # decals, waves, fields, bolts
var _bolts: Array[MeshInstance3D] = []
var _bolt_i := 0
var _bolt_mat: StandardMaterial3D
var _now := 0.0
var _noise: Texture2D
## Tier scaling applied while one play() call runs (1 outside it).
var _sec := 1.0
var _ground := 1.0
var _gdur := 1.0
## Counters the tests read: how many nodes each pool ever built.
var built := {"decal": 0, "bolt": 0, "layer": 0}


func _init() -> void:
	name = "VfxLib"


func _ready() -> void:
	_decal_quad = PlaneMesh.new()
	_decal_quad.size = Vector2(2, 2)
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.vertex_color_use_as_albedo = true
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


# --- Public API ----------------------------------------------------------

## Any element, any variant. `r` is the area radius (impact/nova/linger) or
## the effect scale; `dir` aims casts and trails; `dur` sets nova/linger time.
## `tier` (light / skill / big) scales how loud it is, see TIER.
func play(el: StringName, variant: StringName, pos: Vector3, r := 1.0, dir := Vector3.ZERO, dur := -1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	if not COLORS.has(el):
		el = &"physical"
	if not TIER.has(tier):
		tier = &"skill"
	var T: Dictionary = TIER[tier]
	var c: Color = tint if tint.a > 0.0 else COLORS[el]
	_sec = float(T["sec"]) * (0.5 if quality_low else 1.0)
	_ground = float(T["ground"])
	_gdur = float(T["gdur"])
	_core(el, variant, pos, r, dir, dur, c, T)
	# Sprite secondaries (the A look), scaled down; light tier skips them.
	if _sec > 0.0:
		match variant:
			&"cast": _cast(el, pos, r, c)
			&"travel": _travel(el, pos, dir, c)
			&"impact": _impact(el, pos, r, c)
			&"nova": _nova(el, pos, r, c, dur)
			&"linger": _linger(el, pos, r, c, dur)
	_sec = 1.0
	_ground = 1.0
	_gdur = 1.0


func cast(el: StringName, pos: Vector3, r := 1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"cast", pos, r, Vector3.ZERO, -1.0, tint, tier)


func travel(el: StringName, pos: Vector3, dir := Vector3.ZERO, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"travel", pos, 1.0, dir, -1.0, tint, tier)


func impact(el: StringName, pos: Vector3, r := 1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"impact", pos, r, Vector3.ZERO, -1.0, tint, tier)


## A shockwave of the element racing out to `r` over `dur` (flames, ice
## spikes, leaves...), not a ring: replaces every old Fx.ring call.
func nova(el: StringName, pos: Vector3, r := 3.0, dur := -1.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"nova", pos, r, Vector3.ZERO, dur, tint, tier)


func linger(el: StringName, pos: Vector3, r := 1.5, dur := 2.0, tint := Color(0, 0, 0, 0), tier: StringName = &"skill") -> void:
	play(el, &"linger", pos, r, Vector3.ZERO, dur, tint, tier)


## Which element a legacy colour means: lets old colour-only call sites (and
## open PRs written against Fx.ring) land on a real effect.
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


# --- Variants ----------------------------------------------------------------

func _cast(el: StringName, pos: Vector3, r: float, c: Color) -> void:
	var p := pos + Vector3(0, 0.9, 0)
	match el:
		&"fire":
			_cloud("flame", pos + Vector3(0, 0.3, 0), 0.35 * r, 3, Vector3(0, 1.5, 0), c)
			_cloud("ember", p, 0.5 * r, 6, Vector3(0, 1.4, 0), c)
		&"frost":
			_swirl("flake", pos, 0.7 * r, 8, 2.0, c)
			_cloud("spark", p, 0.3, 4, Vector3(0, 2.0, 0), c)
		&"storm":
			_cloud("spark", p, 0.5 * r, 10, Vector3(0, 3.0, 0), c, 4.0)
			bolt_arc(p, 0.8 * r, c)
		&"poison":
			_cloud("bubble", pos + Vector3(0, 0.4, 0), 0.5 * r, 6, Vector3(0, 1.2, 0), c)
		&"nature":
			_swirl("leaf", pos, 0.8 * r, 7, 2.5, c)
		&"holy", &"level":
			_cloud("ray", pos, 0.5 * r, 3, Vector3.ZERO, c)
			_cloud("mote", p, 0.6 * r, 8, Vector3(0, 1.5, 0), c)
		&"shadow":
			_cloud("wisp", pos + Vector3(0, 0.4, 0), 0.6 * r, 5, Vector3(0, 1.4, 0), c)
		&"heal":
			_cloud("cross", p, 0.6 * r, 4, Vector3(0, 1.0, 0), c)
			_swirl("mote", pos, 0.8 * r, 8, 3.0, c)
		&"buff":
			_cloud("chevron", p, 0.6 * r, 4, Vector3(0, 1.5, 0), c)
			_swirl("mote", pos, 0.7 * r, 6, 2.5, c)
		&"blood":
			_cloud("blood", p, 0.3, 6, Vector3(0, 2.0, 0), c, 3.0)
		_:
			_cloud("dust", pos + Vector3(0, 0.2, 0), 0.4 * r, 4, Vector3(0, 0.6, 0), c, 1.5)


## One puff of trail per call; projectiles call it every few frames.
func _travel(el: StringName, pos: Vector3, dir: Vector3, c: Color) -> void:
	var back := -dir.normalized() * 1.2 if dir.length_squared() > 0.0 else Vector3.ZERO
	match el:
		&"fire": _emit("ember", pos, back * 0.5 + _rnd(0.6), c)
		&"frost": _emit("flake", pos, back + _rnd(0.4), c); _emit("spark", pos, back * 0.4, c)
		&"storm": _emit("spark", pos, back + _rnd(2.5), c)
		&"poison": _emit("bubble", pos, back + _rnd(0.4), c)
		&"nature": _emit("leaf", pos, back + _rnd(0.8), c)
		&"holy", &"level", &"heal", &"buff": _emit("mote", pos, back + _rnd(0.5), c)
		&"shadow": _emit("wisp", pos, back + _rnd(0.4), c)
		&"blood": _emit("blood", pos, back + _rnd(0.6), c)
		_: _emit("dust", pos - Vector3(0, pos.y, 0), _rnd(0.5), c)


func _impact(el: StringName, pos: Vector3, r: float, c: Color) -> void:
	var p := pos + Vector3(0, 0.6, 0)
	var n := int(clampf(4.0 + r * 4.0, 4.0, 18.0))
	if quality_low:
		n = maxi(3, n / 2)
	match el:
		&"fire":
			_cloud("flame_lg" if r > 1.6 else "flame", pos + Vector3(0, 0.35, 0), 0.45 * r, n / 2 + 1, Vector3(0, 1.2, 0), c, 1.5)
			_burst("spark", p, n, 6.0 + r, Color(1.0, 0.8, 0.4))
			_cloud("ember", p, 0.6 * r, n, Vector3(0, 1.5, 0), c, 1.0)
			decal(&"fire", pos, r * 0.9, 2.4)
		&"frost":
			_burst("shard", p, n, 5.0 + r, c, 1.4)
			_cloud("flake", p, 0.6 * r, n / 2, Vector3(0, 0.5, 0), c, 1.0)
			_burst("spark", p, n / 2, 4.0, Color(0.85, 0.95, 1.0))
			decal(&"frost", pos, r * 0.95, 2.2)
		&"storm":
			for k in mini(3 + int(r), 6):
				var a := randf() * TAU
				bolt(PackedVector3Array([p + Vector3(0, 0.3, 0), pos + Vector3(sin(a), 0.1, cos(a)) * r * randf_range(0.7, 1.1)]), c, false)
			_burst("spark", p, n + 4, 7.0, c)
			decal(&"storm", pos, r * 0.6, 1.2)
		&"poison":
			_cloud("bubble", pos + Vector3(0, 0.3, 0), 0.6 * r, n, Vector3(0, 1.4, 0), c, 1.5)
			_burst("spore", p, n / 2, 3.0, c.lightened(0.3), 0.6)
			decal(&"poison", pos, r * 0.9, 2.4)
		&"nature":
			_burst("leaf", p, n, 4.5, c, 1.0)
			_cloud("spore", p, 0.5 * r, n / 2, Vector3(0, 0.8, 0), c.lightened(0.3))
		&"holy", &"level":
			_cloud("ray", pos, 0.45 * r, mini(2 + int(r), 6), Vector3.ZERO, c)
			_burst("mote", p, n, 4.0, c, 1.2)
			decal(&"holy", pos, r * 0.8, 0.9)
		&"shadow":
			_cloud("wisp", pos + Vector3(0, 0.3, 0), 0.5 * r, n / 2 + 1, Vector3(0, 1.6, 0), c, 1.4)
			_burst("bone", p, n / 3 + 1, 5.0, Color.WHITE, 1.4)
			_burst("spark", p, n / 2, 4.0, c.lightened(0.3))
			decal(&"shadow", pos, r * 0.85, 1.8)
		&"blood":
			_burst("blood", p + Vector3(0, 0.3, 0), n, 4.5, c, 1.2)
			_burst("spark", p + Vector3(0, 0.3, 0), 3, 4.0, Color(1.0, 0.85, 0.7))
		&"heal":
			_cloud("cross", p, 0.5 * r, n / 2, Vector3(0, 1.4, 0), c)
			_swirl("mote", pos, 0.9 * r, n, 3.0, c)
		&"buff":
			_cloud("chevron", p, 0.5 * r, n / 2, Vector3(0, 1.8, 0), c)
			_burst("mote", p, n / 2, 3.0, c, 1.4)
		_:
			_burst("debris", pos + Vector3(0, 0.3, 0), n, 5.0 + r, Color.WHITE, 1.4)
			_cloud("dust", pos + Vector3(0, 0.25, 0), 0.6 * r, n / 2 + 1, Vector3(0, 0.5, 0), c, 2.0)
			_burst("spark", p, n / 3, 5.0, Color(1.0, 0.9, 0.7))
			if r > 1.4:
				decal(&"physical", pos, r * 0.8, 1.8)


func _nova(el: StringName, pos: Vector3, r: float, c: Color, dur: float) -> void:
	if dur <= 0.0:
		dur = clampf(0.25 + r * 0.06, 0.3, 0.7)
	_live.append({"kind": "wave", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": dur, "acc": 0.0, "sec": _sec})
	if DECALS.has(el):
		decal(el, pos, r * (0.55 if el in [&"holy", &"level", &"heal"] else 0.7), maxf(dur * 2.5, 1.2))
	if el in [&"holy", &"level"]:
		_cloud("ray", pos, 0.3, 2, Vector3.ZERO, c)


func _linger(el: StringName, pos: Vector3, r: float, c: Color, dur: float) -> void:
	if dur <= 0.0:
		dur = 2.0
	if DECALS.has(el):
		decal(el, pos, r, dur + 0.4)
	_live.append({"kind": "field", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": dur, "acc": 0.0, "sec": _sec})



# --- Procedural cores (tiered) ----------------------------------------------

## The heart of every effect: dissolve flames/goo/void/light, faceted spikes
## that grow and shatter, re-forking bolts. Scaled by the call's tier.
func _core(el: StringName, variant: StringName, pos: Vector3, r: float, dir: Vector3, dur: float, c: Color, T: Dictionary) -> void:
	var st: int = STYLE[el]
	var k: float = T["core"]
	var light: bool = T == TIER[&"light"]
	match variant:
		&"travel":
			var sp := dir.length()
			var fwd := dir / sp if sp > 0.01 else Vector3.FORWARD
			if el == &"fire" and light and fire_basic_spray:
				spray(el, pos - Vector3(0, 0.7, 0), fwd, 1.1, 0.22, 0.05, c, &"light")
				return
			# A tapering ribbon behind the head: overlapping segments, the
			# older ones thinner, so the trail reads as one strip.
			var seg := clampf(sp * 0.07, 0.35, 1.1)
			_mesh("ribbon", pos - fwd * seg * 0.45, Vector3.ZERO, c, st, (0.3 if light else 0.42) * k, 0.26, Vector3(seg, 1, 1), fwd)
			_mesh("ball", pos, Vector3.ZERO, c, st, 0.5 if light else 0.6 * k, 0.2 if light else 0.3)
			if randf() < (0.25 if light else 0.5):
				_emit("ember", pos, -fwd * 1.5 + _rnd(0.9), c)
			if not light and el == &"storm" and randf() < 0.25:
				bolt_arc(pos, 0.45, c)
			elif not light and SPIKES.has(el) and el != &"physical" and randf() < 0.5:
				_mesh("chip", pos, -dir.normalized() * 1.5 + _rnd(0.8), c, SPIKES[el], 1.0, 0.4)
		&"cast":
			var at := pos + Vector3(0, 0.9, 0)
			if light:
				_mesh("ball", at, Vector3.ZERO, c, st, 0.55, 0.2)
			elif SPIKES.has(el) and el != &"physical":
				_spikes(el, pos, 0.75 * r, int(6 * k), 0.45 * r * k, c, 0.5, false, true)
			elif el == &"storm":
				_mesh("ball", at, Vector3.ZERO, c, st, 0.6 * k, 0.3)
				bolt_arc(at, 0.7 * r, c)
			else:
				_mesh("tongue", pos, Vector3.ZERO, c, st, 0.75, 0.5, Vector3(0.9 * r * k, (1.6 if st == 3 else 1.2) * k, 0.9 * r * k))
		&"impact":
			var at := pos + Vector3(0, 0.5, 0)
			if light:
				# A tiny flicker: one small, fast core (plus one short unforked
				# bolt for storm). Nothing on the ground.
				_mesh("ball", at, Vector3.ZERO, c, st, clampf(0.6 * r, 0.5, 0.8), 0.22)
				if el == &"storm":
					var a := randf() * TAU
					bolt(PackedVector3Array([at + Vector3(0, 0.3, 0), pos + Vector3(sin(a), 0.1, cos(a)) * 0.7]), c, false, 0.04, 0.12)
				return
			if SPIKES.has(el) and (el != &"physical" or T["sky"]):
				_spikes(el, pos, 0.9 * r, int(7 * float(T["spikes"])), 0.8 * r * k, c, 0.5, T["shatter"], false)
				if el == &"nature":
					_mesh("ball", at, Vector3.ZERO, c, st, 0.9 * r * k, 0.35)
			if el == &"storm":
				_mesh("ball", at, Vector3.ZERO, c, st, 0.9 * k, 0.25)
				for i in int(T["bolts"]):
					var a := randf() * TAU
					bolt(PackedVector3Array([at + Vector3(0, 0.3, 0), pos + Vector3(sin(a), 0.1, cos(a)) * r * randf_range(0.7, 1.1)]), c, true, 0.06, 0.3)
			elif el != &"frost" and el != &"nature":
				_mesh("ball", pos + Vector3(0, 0.45 * r * k, 0), Vector3.ZERO, c, st, 1.6 * r * k, 0.6)
				if st == 3:
					_mesh("tongue", pos, Vector3.ZERO, c, st, 0.6, 0.55, Vector3(0.45 * r, 3.0 * k, 0.45 * r))
			if T["sky"] and el in [&"storm", &"holy", &"level"]:
				sky(pos, c, 0.22)
		&"nova":
			var d := dur if dur > 0.0 else clampf(0.25 + r * 0.06, 0.3, 0.7)
			if light:
				_mesh("tongue", pos, Vector3.ZERO, c, st, 0.2, d * 1.2, Vector3(r, 0.5, r))
				return
			if SPIKES.has(el) and (el != &"physical" or T["sky"]):
				_live.append({"kind": "spikes", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": d, "acc": 0.0, "k": k, "shatter": T["shatter"]})
			if el == &"storm":
				_mesh("ball", pos + Vector3(0, 0.5, 0), Vector3.ZERO, c, st, 1.2 * k, 0.3)
			elif el != &"frost":
				_mesh("tongue", pos, Vector3.ZERO, c, st, 0.15, d * 1.35, Vector3(r, (1.6 if st == 3 else 1.1) * k, r))
			if T["sky"] and el in [&"storm", &"holy", &"level"]:
				sky(pos, c, 0.24)
		&"linger":
			var d2 := dur if dur > 0.0 else 2.0
			_live.append({"kind": "field", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": d2, "acc": 0.0, "core": true, "k": k})


## Faceted spikes (ice, thorns, stone, void) in a disc; optional shatter.
func _spikes(el: StringName, pos: Vector3, r: float, n: int, h: float, c: Color, life: float, shatter: bool, ring: bool) -> void:
	var cs: int = SPIKES[el]
	n = mini(n, 16)
	for i in n:
		var an := TAU * i / maxf(n, 1) + randf() * 0.4
		var rr := r if ring else r * sqrt(randf())
		var at := pos + Vector3(sin(an), 0, cos(an)) * rr
		var up := Vector3(sin(an) * (0.5 + rr * 0.3), 1.2, cos(an) * (0.5 + rr * 0.3))
		var hh := h * randf_range(0.7, 1.3)
		var lf := life * randf_range(0.9, 1.1)
		_mesh("spike", at, Vector3.ZERO, c, cs, hh, lf, Vector3.ONE, up)
		if shatter and not quality_low:
			_later(lf * 0.86, _shatter.bind(at + up.normalized() * hh * 0.5, hh, c, cs))


func _shatter(at: Vector3, h: float, c: Color, cs: int) -> void:
	for j in 3:
		var v := Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1)) * 3.0
		_mesh("chip", at, v, c, cs, 0.6 + h * 0.5, 0.55)


func _later(delay: float, fn: Callable) -> void:
	_live.append({"kind": "later", "t": 0.0, "dur": maxf(delay, 0.001), "fn": fn})


## Spikes racing out with a nova front.
func _tick_spikes(e: Dictionary, k: float, dt: float) -> void:
	var r: float = e["r"]
	var front := r * (1.0 - pow(1.0 - k, 2.0))
	e["acc"] = float(e["acc"]) + dt * TAU * r / 0.7 / maxf(float(e["dur"]), 0.2) * float(e["k"]) * (0.5 if quality_low else 1.0)
	var n := mini(int(e["acc"]), 6)
	e["acc"] = float(e["acc"]) - n
	var el: StringName = e["el"]
	var pos: Vector3 = e["pos"]
	for i in n:
		var an := randf() * TAU
		var at := pos + Vector3(sin(an), 0, cos(an)) * front
		var up := Vector3(sin(an) * 0.6, 1.0, cos(an) * 0.6)
		var hh := randf_range(0.5, 0.9) * float(e["k"])
		_mesh("spike", at, Vector3.ZERO, e["c"], SPIKES[el], hh, 0.34, Vector3.ONE, up)
		if e["shatter"] and not quality_low and i % 2 == 0:
			_later(0.3, _shatter.bind(at + up.normalized() * hh * 0.5, hh, e["c"], int(SPIKES[el])))


## A lingering field's cores: small flames, goo, void, light, ice, thorns.
func _tick_core_field(e: Dictionary, dt: float) -> void:
	var el: StringName = e["el"]
	var r: float = e["r"]
	e["acc"] = float(e["acc"]) + dt * clampf(r * 2.5, 2.0, 8.0) * (0.5 if quality_low else 1.0)
	var n := mini(int(e["acc"]), 3)
	e["acc"] = float(e["acc"]) - n
	var pos: Vector3 = e["pos"]
	var c: Color = e["c"]
	for i in n:
		var a := randf() * TAU
		var at := pos + Vector3(sin(a), 0, cos(a)) * r * sqrt(randf())
		if el == &"storm":
			if _bolts_live() < BOLT_POOL / 2:
				bolt_arc(at + Vector3(0, 0.4, 0), 0.4, c)
		elif SPIKES.has(el) and el != &"physical":
			_mesh("spike", at, Vector3.ZERO, c, SPIKES[el], randf_range(0.3, 0.6), 0.8, Vector3.ONE, Vector3(randf_range(-0.3, 0.3), 1, randf_range(-0.3, 0.3)))
		else:
			_mesh("ball", at + Vector3(0, 0.3, 0), Vector3(0, 1.1, 0), c, STYLE[el], randf_range(0.5, 0.8), 0.5)


## A strike from the sky onto `at` (big tier): a tall re-forking bolt, a core
## flash on the ground and a mark. Capped at MAX_SKY alive; pooled.
func sky(at: Vector3, c := Color(0.65, 0.82, 1.0), width := 0.2, height := 14.0) -> void:
	var live := 0
	for e in _live:
		if e["kind"] == "bolt" and e.get("sky", false):
			live += 1
	if live >= MAX_SKY:
		return
	var top := at + Vector3(randf_range(-1.0, 1.0), height, randf_range(-1.0, 1.0))
	bolt(PackedVector3Array([top, at.lerp(top, 0.5) + _rnd(0.6), at]), c, true, width, 0.32)
	_live[_live.size() - 1]["sky"] = true
	var el := element_for(c)
	_mesh("ball", at + Vector3(0, 0.4, 0), Vector3.ZERO, c, 3 if el == &"holy" else 5, 1.4, 0.3)
	var g := _ground
	_ground = maxf(_ground, 1.0)
	decal(&"holy" if el == &"holy" else &"storm", at, 1.2, 1.4)
	_ground = g


func _bolts_live() -> int:
	var n := 0
	for e in _live:
		if e["kind"] == "bolt":
			n += 1
	return n

# --- Bolts -------------------------------------------------------------------

## Forked lightning between points: a jagged hot ribbon with side branches,
## flickering once before it dies (0.2 s). Pooled meshes, one shared material.
## Live bolts re-fork (new jag, new branches) every REFORK seconds.
func bolt(points: PackedVector3Array, c := Color(0.65, 0.82, 1.0), forks := true, width := 0.07, dur := 0.2) -> void:
	if points.size() < 2:
		return
	var mi := _take_bolt()
	_bolt_geo(mi, points, c, forks, width)
	mi.transparency = 0.0
	mi.visible = true
	_live.append({"kind": "bolt", "node": mi, "t": 0.0, "dur": dur, "pts": points, "c": c, "forks": forks, "w": width, "re": 0.0})
	for p in points:
		_burst("spark", p, 3, 3.5, c)


const REFORK := 0.066


func _bolt_geo(mi: MeshInstance3D, points: PackedVector3Array, c: Color, forks: bool, width: float) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	var hot := Color(minf(c.r * 1.6, 1.0), minf(c.g * 1.6, 1.0), minf(c.b * 1.6, 1.0))
	for s in points.size() - 1:
		var path := _jag(points[s], points[s + 1], 6, 0.35)
		_strip(im, path, width, hot)
		if forks and not quality_low:
			for k in 2:
				var j := randi_range(1, path.size() - 2)
				var dirv := (points[s + 1] - points[s]).normalized()
				var side := dirv.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				var end := path[j] + (dirv * 0.5 + side + Vector3(0, -0.3, 0)).normalized() * randf_range(0.6, 1.3)
				_strip(im, _jag(path[j], end, 3, 0.18), width * 0.55, hot)


## Little arcs crackling round a point (storm casts, stuns).
func bolt_arc(pos: Vector3, r: float, c: Color) -> void:
	var pts := PackedVector3Array()
	var a := randf() * TAU
	for k in 4:
		pts.append(pos + Vector3(sin(a + k * 0.9) * r, randf_range(-0.3, 0.4), cos(a + k * 0.9) * r))
	bolt(pts, c, false, 0.045)


func _take_bolt() -> MeshInstance3D:
	if _bolts.size() < BOLT_POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.material_override = _bolt_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_bolts.append(mi)
		built["bolt"] += 1
		return mi
	var b := _bolts[_bolt_i]
	_bolt_i = (_bolt_i + 1) % _bolts.size()
	for e in _live:
		if e.get("node") == b:
			_live.erase(e)
			break
	return b


func _jag(a: Vector3, b: Vector3, steps: int, amp: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var len_ := a.distance_to(b)
	for j in steps + 1:
		var t := float(j) / steps
		var p := a.lerp(b, t)
		if j > 0 and j < steps:
			p += Vector3(randf_range(-1, 1), randf_range(-0.5, 0.7), randf_range(-1, 1)) * amp * minf(1.0, len_ / 3.0)
		out.append(p)
	return out


func _strip(im: ImmediateMesh, path: PackedVector3Array, w: float, col: Color) -> void:
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in path.size():
		var d := (path[mini(j + 1, path.size() - 1)] - path[maxi(j - 1, 0)])
		var side := d.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var ww := w * (1.0 - 0.5 * float(j) / path.size())
		im.surface_set_color(col)
		im.surface_add_vertex(path[j] - side * ww - Vector3(0, ww, 0))
		im.surface_set_color(col)
		im.surface_add_vertex(path[j] + side * ww + Vector3(0, ww, 0))
	im.surface_end()


# --- Decals ------------------------------------------------------------------

func decal(el: StringName, pos: Vector3, r: float, dur := 2.0, tint := Color(1, 1, 1, 1)) -> void:
	if _ground <= 0.0 or not DECALS.has(el):
		return
	r *= _ground
	dur *= _gdur
	if r < 0.15:
		return
	var tex: String = DECALS[el]
	var mat := _decal_mat(tex)
	var mi: MeshInstance3D = null
	# Prefer a pooled quad already wearing this decal's material: swapping
	# materials on a node with instance uniforms re-allocates them.
	for j in range(_decal_pool.size() - 1, -1, -1):
		if _decal_pool[j].material_override == mat:
			mi = _decal_pool[j]
			_decal_pool.remove_at(j)
			break
	if mi == null and not _decal_pool.is_empty():
		mi = _decal_pool.pop_back()
	if mi == null and built["decal"] >= MAX_DECALS:
		# Pool full: steal the oldest live decal rather than grow.
		for j in _live.size():
			if _live[j]["kind"] == "decal":
				mi = _live[j]["node"]
				_live.remove_at(j)
				break
	if mi == null:
		mi = MeshInstance3D.new()
		mi.mesh = _decal_quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		built["decal"] += 1
	if mi.material_override != mat:
		mi.material_override = mat
	mi.position = Vector3(pos.x, 0.045 + randf() * 0.01, pos.z)
	mi.rotation = Vector3(0, randf() * TAU, 0)
	mi.scale = Vector3(r, 1, r)
	mi.set_instance_shader_parameter("progress", 0.0)
	mi.set_instance_shader_parameter("tint", tint)
	mi.visible = true
	_live.append({"kind": "decal", "node": mi, "t": 0.0, "dur": dur})


func _decal_mat(tex: String) -> ShaderMaterial:
	if not _decal_mats.has(tex):
		var m := ShaderMaterial.new()
		m.shader = DECAL
		m.set_shader_parameter("tex", load(TEX % tex))
		m.render_priority = -1
		_decal_mats[tex] = m
	return _decal_mats[tex]


# --- Particle layers ---------------------------------------------------------

func layer(n: String) -> MultiMeshInstance3D:
	if _layers.has(n):
		return _layers[n]["node"]
	var d: Dictionary = LAYERS[n]
	var cap := int(d["amount"]) / (2 if quality_low else 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	if d.has("mesh"):
		return _mesh_layer(n, d, mm, cap)
	var q := QuadMesh.new()
	q.size = d.get("quad", Vector2.ONE)
	if d.has("quad"):
		q.center_offset = Vector3(0, q.size.y * 0.5, 0)
	mm.mesh = q
	mm.instance_count = cap
	for i in cap:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mm.visible_instance_count = 0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(TEX % str(d["tex"]))
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if bool(d["add"]):
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if bool(d.get("fixed_y", false)):
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
	else:
		# Particle billboards read rotation and flipbook frame from custom data.
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.particles_anim_h_frames = int(d.get("hf", 1))
		m.particles_anim_v_frames = int(d.get("vf", 1))
		m.particles_anim_loop = false
	return _finish_layer(n, d, mm, m, cap)


func _mesh_layer(n: String, d: Dictionary, mm: MultiMesh, cap: int) -> MultiMeshInstance3D:
	var mesh: Mesh
	var m := ShaderMaterial.new()
	match str(d["mesh"]):
		"ball":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 16
			sm.rings = 8
			mesh = sm
		"wall":
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 1.0
			cm.height = 1.0
			cm.cap_top = false
			cm.cap_bottom = false
			cm.radial_segments = 40
			cm.rings = 1
			mesh = cm
		"spike":
			var sp := CylinderMesh.new()
			sp.top_radius = 0.0
			sp.bottom_radius = 0.16
			sp.height = 1.0
			sp.radial_segments = 6
			sp.rings = 1
			mesh = sp
		"puff", "ribbon":
			mesh = QuadMesh.new()
		_:
			var pm := PrismMesh.new()
			pm.size = Vector3(0.12, 0.2, 0.06)
			mesh = pm
	if str(d["mesh"]) in ["puff", "ribbon"]:
		m.shader = PUFF
		if _noise == null:
			_noise = load(TEX % "noise")
		m.set_shader_parameter("noise", _noise)
		m.set_shader_parameter("mode", 0 if str(d["mesh"]) == "puff" else 1)
	elif str(d["mesh"]) in ["ball", "wall"]:
		m.shader = CORE
		if _noise == null:
			_noise = load(TEX % "noise")
		m.set_shader_parameter("noise", _noise)
		m.set_shader_parameter("mode", 0 if str(d["mesh"]) == "ball" else 1)
	else:
		m.shader = CRYSTAL
	mm.mesh = mesh
	mm.instance_count = cap
	for i in cap:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mm.visible_instance_count = 0
	return _finish_layer(n, d, mm, m, cap)


func _finish_layer(n: String, d: Dictionary, mm: MultiMesh, m: Material, cap: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = "L_" + n
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 40, 160))
	node.visible = false
	add_child(node)
	var pos := PackedVector3Array(); pos.resize(cap)
	var vel := PackedVector3Array(); vel.resize(cap)
	var col := PackedColorArray(); col.resize(cap)
	var age := PackedFloat32Array(); age.resize(cap)
	var info := PackedFloat32Array(); info.resize(cap * 4)  # size, angle, spin, frame/style
	var lf := PackedFloat32Array(); lf.resize(cap)  # per-particle life
	var shape := PackedVector3Array(); shape.resize(cap)  # mesh cores: per-axis scale
	var axis := PackedVector3Array(); axis.resize(cap)  # mesh cores: up direction
	age.fill(1e9)
	lf.fill(1.0)
	_layers[n] = {"node": node, "mm": mm, "cap": cap, "next": 0, "alive": 0, "top": 0,
		"pos": pos, "vel": vel, "col": col, "age": age, "info": info, "lf": lf, "shape": shape, "axis": axis,
		"mesh": str(d.get("mesh", "")),
		"life": float(d["life"]), "grav": d["grav"], "damp": float(d["damp"]),
		"flip": bool(d.get("flip", false)), "atlas": int(d.get("hf", 1)) * int(d.get("vf", 1)) > 1}
	built["layer"] += 1
	return node


func _emit(n: String, p: Vector3, v: Vector3, c: Color) -> int:
	if REMAP.has(n):
		return _remap(n, p, v, c)
	layer(n)
	var L: Dictionary = _layers[n]
	var i: int = L["next"]
	L["next"] = (i + 1) % int(L["cap"])
	if float(L["age"][i]) >= float(L["lf"][i]):
		L["alive"] = int(L["alive"]) + 1
	L["top"] = maxi(int(L["top"]), i + 1)
	var d: Dictionary = LAYERS[n]
	var sz: Vector2 = d["size"]
	L["pos"][i] = p
	L["vel"][i] = v
	L["col"][i] = c
	L["age"][i] = 0.0
	L["lf"][i] = float(L["life"])
	L["shape"][i] = Vector3.ONE
	L["axis"][i] = Vector3.UP
	var info: PackedFloat32Array = L["info"]
	info[i * 4] = randf_range(sz.x, sz.y)
	info[i * 4 + 1] = randf() * TAU if d.has("spin") else 0.0
	info[i * 4 + 2] = randf_range(-1.0, 1.0) * deg_to_rad(float(d.get("spin", 0.0)))
	info[i * 4 + 3] = float(randi() % 4) / 4.0 + 0.01 if L["atlas"] and not L["flip"] else 0.0
	L["info"] = info
	var node: MultiMeshInstance3D = L["node"]
	node.visible = true
	(L["mm"] as MultiMesh).visible_instance_count = int(L["top"])
	return i


## A stamp-like sprite emit becomes one varied procedural piece instead.
func _remap(n: String, p: Vector3, v: Vector3, c: Color) -> int:
	var r: Array = REMAP[n]
	var d: Dictionary = LAYERS[n]
	var sz: Vector2 = d["size"]
	var size := randf_range(sz.x, sz.y) * float(r[2]) * randf_range(0.7, 1.3)
	var life := float(d["life"]) * randf_range(0.7, 1.3)
	if str(r[0]) == "chip":
		return _mesh("chip", p, v, c, int(r[1]), size * 2.2, life, Vector3(randf_range(0.6, 1.4), randf_range(0.7, 1.7), randf_range(0.6, 1.2)))
	return _mesh("puff", p, v * 0.7, c, int(r[1]), size, life, Vector3(float(r[3]), 1, 1))


## A continuous flame jet: overlapping seeded puffs fired along `dir`,
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
		"rate": (34.0 if light else 70.0) * (0.5 if quality_low else 1.0), "light": light})
	if not light:
		_later(dur * 0.6, func(): decal(el, pos + f * length * 0.6, length * 0.3, 2.0 * _gdur))


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
	var life := 0.32 if light else 0.42
	var speed := ln / life
	var c: Color = e["c"]
	var st: int = STYLE[e["el"]]
	for i in n:
		var a := randf_range(-1.0, 1.0) * float(e["cone"])
		var up := randf_range(-0.08, 0.18)
		var v := (f * cos(a) + side * sin(a) + Vector3(0, up, 0)) * speed * randf_range(0.8, 1.15)
		var p: Vector3 = e["pos"] + Vector3(0, 0.7, 0) + f * randf_range(0.0, 0.3)
		var cc := c.lerp(Color(1.0, 0.85, 0.45), randf() * 0.35) if st == 0 else c
		# Growth: tight at the nozzle, widening as it flies.
		var g := (1.0 + tan(float(e["cone"])) * ln * 0.9)
		_mesh("puff", p, v, cc, st, randf_range(0.28, 0.42) * (0.75 if light else 1.0), life * randf_range(0.8, 1.2), Vector3(g, 1, 1))
	if not light and randf() < 0.3:
		_emit("ember", e["pos"] + Vector3(0, 0.8, 0) + f * ln * randf_range(0.3, 0.9), _rnd(1.0) + Vector3(0, 1.5, 0), c)


## One procedural core instance: `size` overall, `shape` per-axis multiplier
## (walls: end radius/height), `axis` its up, `style` the shader look.
func _mesh(n: String, p: Vector3, v: Vector3, c: Color, style: int, size: float, life: float, shape := Vector3.ONE, axis := Vector3.UP) -> int:
	var i := _emit(n, p, v, c)
	var L: Dictionary = _layers[n]
	L["lf"][i] = life
	L["shape"][i] = shape
	L["axis"][i] = axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP
	var info: PackedFloat32Array = L["info"]
	info[i * 4] = size
	info[i * 4 + 1] = randf() * 10.0
	info[i * 4 + 3] = float(style)
	L["info"] = info
	return i


## Step one layer: integrate, then write transforms, colours and custom data.
func _tick_layer(L: Dictionary, dt: float) -> void:
	var mm: MultiMesh = L["mm"]
	var lf: PackedFloat32Array = L["lf"]
	var mesh: String = L["mesh"]
	var shape: PackedVector3Array = L["shape"]
	var axis: PackedVector3Array = L["axis"]
	var grav: Vector3 = L["grav"]
	var damp := maxf(0.0, 1.0 - float(L["damp"]) * dt)
	var pos: PackedVector3Array = L["pos"]
	var vel: PackedVector3Array = L["vel"]
	var age: PackedFloat32Array = L["age"]
	var info: PackedFloat32Array = L["info"]
	var col: PackedColorArray = L["col"]
	var flip: bool = L["flip"]
	var alive := 0
	var top := 0
	for i in int(L["top"]):
		var a := age[i]
		var life := lf[i]
		if a >= life:
			continue
		a += dt
		age[i] = a
		if a >= life:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		alive += 1
		top = i + 1
		var v := (vel[i] + grav * dt) * damp
		vel[i] = v
		pos[i] += v * dt
		var k := a / life
		if mesh != "":
			_mesh_xform(mm, i, mesh, k, a, pos[i], info, shape[i], axis[i], col[i])
			continue
		# Pop in fast, hold, shrink away at the end: crisp, no soft bloom.
		var s := info[i * 4] * (0.7 + 0.3 * k if flip else (lerpf(0.6, 1.0, k / 0.15) if k < 0.15 else (1.0 if k < 0.75 else lerpf(1.0, 0.0, (k - 0.75) / 0.25))))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), pos[i]))
		var c := col[i]
		if k > 0.7:
			c.a *= 1.0 - (k - 0.7) / 0.3
		mm.set_instance_color(i, c)
		var ang := info[i * 4 + 1] + info[i * 4 + 2] * a
		mm.set_instance_custom_data(i, Color(ang, 0.0, minf(k, 0.999) if flip else info[i * 4 + 3], 0.0))
	L["pos"] = pos
	L["vel"] = vel
	L["age"] = age
	L["alive"] = alive
	L["top"] = top
	mm.visible_instance_count = top
	if alive == 0:
		(L["node"] as Node3D).visible = false


## Shape-over-life of the procedural cores. Crisp: they grow, then the
## dissolve (balls, walls) or a fast shrink (spikes, chips) takes them.
func _mesh_xform(mm: MultiMesh, i: int, mesh: String, k: float, a: float, p: Vector3, info: PackedFloat32Array, sh: Vector3, up: Vector3, c: Color) -> void:
	var size := info[i * 4]
	var seed := info[i * 4 + 1]
	var style := info[i * 4 + 3]
	var b := Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) > -0.999 and up != Vector3.UP else Basis()
	var t: Transform3D
	match mesh:
		"ball":
			var s := size * (0.55 + 0.45 * (1.0 - pow(1.0 - k, 3.0)))
			t = Transform3D(b.scaled(sh * s), p)
		"wall":
			# size = start radius fraction; races out to sh.x, settles lower.
			var rad := lerpf(size, 1.0, 1.0 - pow(1.0 - k, 2.0))
			var h := sh.y * lerpf(1.0, 0.55, k)
			t = Transform3D(b.scaled(Vector3(sh.x * rad, h, sh.z * rad)), p + up * h * 0.5)
		"puff":
			var s2 := size * lerpf(0.6, sh.x, sqrt(k))
			t = Transform3D(Basis().scaled(Vector3(s2, s2, s2)), p)
		"ribbon":
			var w := size * (1.0 - k * 0.8)
			t = Transform3D(Basis(up * sh.x, Vector3(0, w, 0), up.cross(Vector3.UP).normalized() if absf(up.y) < 0.99 else Vector3.RIGHT), p)
		"spike":
			var g := clampf(k / 0.22, 0.02, 1.0)
			if k > 0.85:
				g *= maxf((1.0 - k) / 0.15, 0.02)
			var bb := b.rotated(up, seed)
			t = Transform3D(bb.scaled(Vector3(size * sh.x, size * g, size * sh.z)), p + up * size * g * 0.5)
		_:
			var sc := size * clampf((1.0 - k) / 0.35, 0.0, 1.0)
			var ax := Vector3(sin(seed), cos(seed * 1.3), sin(seed * 0.7)).normalized()
			t = Transform3D(Basis(ax, seed + info[i * 4 + 2] * a).scaled(sh * maxf(sc, 0.001)), p)
	mm.set_instance_transform(i, t)
	mm.set_instance_color(i, c)
	mm.set_instance_custom_data(i, Color(seed, style, minf(k, 0.999), 0.0))


## Particles scattered in a sphere of `spread`, drifting with `vel` (+ jitter).
func _cloud(n: String, at: Vector3, spread: float, count: int, vel: Vector3, c: Color, jitter := 0.6) -> void:
	for i in _n(count):
		var off := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * spread
		if LAYERS[n].get("fixed_y", false):
			off.y = 0.0
		_emit(n, at + off, vel + _rnd(jitter), c)


## Particles thrown outward (and up by `up`) from a point.
func _burst(n: String, at: Vector3, count: int, speed: float, c: Color, up := 0.8) -> void:
	for i in _n(count):
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0) * up + 0.1, randf_range(-1, 1)).normalized()
		_emit(n, at, dir * speed * randf_range(0.45, 1.0), c)


## Particles spiralling up around a point (heals, frost casts, leaves).
func _swirl(n: String, at: Vector3, r: float, count: int, spin: float, c: Color) -> void:
	count = _n(count)
	for i in count:
		var a := TAU * i / maxf(count, 1) + randf() * 0.3
		var off := Vector3(sin(a), 0, cos(a)) * r
		var tang := Vector3(cos(a), 0, -sin(a)) * spin
		_emit(n, at + off + Vector3(0, randf_range(0.2, 0.9), 0), tang + Vector3(0, randf_range(1.0, 2.2), 0), c)


## Sprite count after tier scaling, capped per call.
func _n(count: int) -> int:
	if _sec < 1.0:
		count = int(ceil(count * _sec))
	return mini(count, MAX_PER_CALL)


func _rnd(s: float) -> Vector3:
	return Vector3(randf_range(-s, s), randf_range(-s, s) * 0.6, randf_range(-s, s))


# --- Waves and fields (driven per frame) -------------------------------------

## What the front of a nova throws up, per element: [layer, up speed, outward].
const WAVE := {
	&"fire": ["ember", 2.0, 2.0], &"frost": ["shard", 5.5, 1.5], &"storm": ["spark", 3.5, 3.0],
	&"poison": ["bubble", 1.6, 1.0], &"nature": ["leaf", 3.0, 2.0], &"holy": ["mote", 2.5, 1.0],
	&"level": ["mote", 3.0, 1.0], &"shadow": ["wisp", 1.8, 1.4], &"physical": ["dust", 0.8, 2.5],
	&"blood": ["blood", 3.0, 2.0], &"heal": ["cross", 1.4, 0.5], &"buff": ["chevron", 1.8, 0.5],
}
## And the second accent layer on the front.
const WAVE2 := {
	&"fire": "", &"frost": "flake", &"storm": "", &"poison": "spore", &"nature": "spore",
	&"holy": "ray", &"level": "ray", &"shadow": "bone", &"physical": "debris", &"blood": "",
	&"heal": "mote", &"buff": "mote",
}

func _tick_wave(e: Dictionary, k: float, dt: float) -> void:
	var el: StringName = e["el"]
	var front: float = float(e["r"]) * (1.0 - pow(1.0 - k, 2.0))
	var c: Color = e["c"]
	var w: Array = WAVE[el]
	# Density by circumference: about one sprite per 0.6 m of front per frame step.
	var rate := clampf(TAU * maxf(front, 0.5) / 0.6, 6.0, 60.0) / maxf(float(e["dur"]), 0.2) * 1.4 * float(e.get("sec", 1.0))
	if quality_low:
		rate *= 0.5
	e["acc"] = float(e["acc"]) + rate * dt
	var n := mini(int(e["acc"]), 24)
	e["acc"] = float(e["acc"]) - n
	var pos: Vector3 = e["pos"]
	var two: String = WAVE2[el]
	for i in n:
		var a := randf() * TAU
		var dirv := Vector3(sin(a), 0, cos(a))
		var at := pos + dirv * front + Vector3(0, 0.15, 0)
		_emit(str(w[0]), at, dirv * float(w[2]) + Vector3(0, float(w[1]) * randf_range(0.6, 1.0), 0), c)
		if two != "" and i % 3 == 0:
			_emit(two, at + Vector3(0, 0.2, 0), dirv * 1.2 + Vector3(0, 1.4, 0), c if two != "ray" else c)
		if el == &"storm" and i % 8 == 0 and not quality_low:
			bolt(PackedVector3Array([at + Vector3(0, 0.1, 0), at + dirv * 0.9 + Vector3(0, 0.1, 0)]), c, false, 0.04)


func _tick_field(e: Dictionary, dt: float) -> void:
	var el: StringName = e["el"]
	var r: float = e["r"]
	e["acc"] = float(e["acc"]) + dt * clampf(r * 6.0, 4.0, 18.0) * (0.5 if quality_low else 1.0) * float(e.get("sec", 1.0))
	var n := mini(int(e["acc"]), 6)
	e["acc"] = float(e["acc"]) - n
	var pos: Vector3 = e["pos"]
	var c: Color = e["c"]
	for i in n:
		var a := randf() * TAU
		var at := pos + Vector3(sin(a), 0, cos(a)) * r * sqrt(randf()) + Vector3(0, 0.1, 0)
		match el:
			&"fire": _emit("flame", at + Vector3(0, 0.3, 0), Vector3(0, 0.8, 0), c); _emit("ember", at + Vector3(0, 0.5, 0), Vector3(0, 1.2, 0) + _rnd(0.3), c)
			&"frost": _emit("flake", at + Vector3(0, 1.2, 0), _rnd(0.2), c)
			&"storm": _emit("spark", at + Vector3(0, 0.3, 0), Vector3(0, 3.0, 0) + _rnd(1.5), c)
			&"poison": _emit("bubble", at, Vector3(0, 0.8, 0), c)
			&"nature": _emit("leaf", at + Vector3(0, 1.6, 0), _rnd(0.4), c)
			&"shadow": _emit("wisp", at, Vector3(0, 1.0, 0), c)
			&"heal": _emit("cross", at + Vector3(0, 0.4, 0), Vector3(0, 0.9, 0), c)
			&"blood": _emit("blood", at + Vector3(0, 0.6, 0), _rnd(0.5), c)
			&"physical": _emit("dust", at, Vector3(0, 0.3, 0), c)
			_: _emit("mote", at + Vector3(0, 0.3, 0), Vector3(0, 1.2, 0), c)


func _process(delta: float) -> void:
	_now += delta
	var i := _live.size() - 1
	while i >= 0:
		var e: Dictionary = _live[i]
		e["t"] = float(e["t"]) + delta
		var k := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		match str(e["kind"]):
			"decal":
				(e["node"] as GeometryInstance3D).set_instance_shader_parameter("progress", k)
			"wave":
				_tick_wave(e, k, delta)
			"field":
				if e.get("core", false):
					_tick_core_field(e, delta)
				else:
					_tick_field(e, delta)
			"bolt":
				var b := e["node"] as MeshInstance3D
				# Hard flicker: full, dip, full, then gone. No soft fade-out glow.
				b.transparency = 0.0 if k < 0.35 or (k > 0.5 and k < 0.75) else 0.7
				e["re"] = float(e["re"]) + delta
				if e.has("pts") and float(e["re"]) >= REFORK and k < 0.8:
					e["re"] = 0.0
					_bolt_geo(b, e["pts"], e["c"], e["forks"], e["w"])
			"spikes":
				_tick_spikes(e, k, delta)
			"spray":
				_tick_spray(e, k, delta)
			"later":
				if k >= 1.0:
					(e["fn"] as Callable).call()
		if k >= 1.0:
			if e["kind"] == "decal":
				var d := e["node"] as MeshInstance3D
				d.visible = false
				_decal_pool.append(d)
			elif e["kind"] == "bolt":
				(e["node"] as Node3D).visible = false
			_live.remove_at(i)
		i -= 1
	for n in _layers:
		var L: Dictionary = _layers[n]
		if (L["node"] as Node3D).visible:
			_tick_layer(L, delta)


## Build every layer, the bolt pool and a decal per element once, tiny, so
## the first real cast does not stall on a shader compile.
func warmup(at: Vector3) -> void:
	for n in LAYERS:
		_emit(n, at, Vector3.ZERO, Color(1, 1, 1, 0.01))
	for el in DECALS:
		decal(el, at, 0.2, 0.05)
	bolt(PackedVector3Array([at, at + Vector3(0.1, 0, 0)]), Color.WHITE, false)


## Layers drawing right now (each is one draw call). Tests and captures read it.
func active_layers() -> int:
	var c := 0
	for n in _layers:
		if (_layers[n]["node"] as Node3D).visible:
			c += 1
	return c
