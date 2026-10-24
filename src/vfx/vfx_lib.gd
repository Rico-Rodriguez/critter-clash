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
const TEX := "res://assets/vfx/%s.png"

const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"storm", &"poison", &"nature", &"holy", &"shadow", &"physical", &"blood", &"heal", &"buff", &"level"]
const VARIANTS: Array[StringName] = [&"cast", &"travel", &"impact", &"nova", &"linger"]

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
}

const DECALS := {
	&"fire": "scorch", &"frost": "frost", &"poison": "poison", &"nature": "poison", &"holy": "holy",
	&"shadow": "shadow", &"physical": "crack", &"storm": "crack", &"level": "holy", &"heal": "holy",
}

## Particle cap per call and per frame of a wave, so a screen of procs stays cheap.
const MAX_DECALS := 24
const MAX_PER_CALL := 40
const BOLT_POOL := 10

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
func play(el: StringName, variant: StringName, pos: Vector3, r := 1.0, dir := Vector3.ZERO, dur := -1.0, tint := Color(0, 0, 0, 0)) -> void:
	if not COLORS.has(el):
		el = &"physical"
	var c: Color = tint if tint.a > 0.0 else COLORS[el]
	match variant:
		&"cast": _cast(el, pos, r, c)
		&"travel": _travel(el, pos, dir, c)
		&"impact": _impact(el, pos, r, c)
		&"nova": _nova(el, pos, r, c, dur)
		&"linger": _linger(el, pos, r, c, dur)


func cast(el: StringName, pos: Vector3, r := 1.0, tint := Color(0, 0, 0, 0)) -> void:
	play(el, &"cast", pos, r, Vector3.ZERO, -1.0, tint)


func travel(el: StringName, pos: Vector3, dir := Vector3.ZERO, tint := Color(0, 0, 0, 0)) -> void:
	play(el, &"travel", pos, 1.0, dir, -1.0, tint)


func impact(el: StringName, pos: Vector3, r := 1.0, tint := Color(0, 0, 0, 0)) -> void:
	play(el, &"impact", pos, r, Vector3.ZERO, -1.0, tint)


## A shockwave of the element racing out to `r` over `dur` (flames, ice
## spikes, leaves...), not a ring: replaces every old Fx.ring call.
func nova(el: StringName, pos: Vector3, r := 3.0, dur := -1.0, tint := Color(0, 0, 0, 0)) -> void:
	play(el, &"nova", pos, r, Vector3.ZERO, dur, tint)


func linger(el: StringName, pos: Vector3, r := 1.5, dur := 2.0, tint := Color(0, 0, 0, 0)) -> void:
	play(el, &"linger", pos, r, Vector3.ZERO, dur, tint)


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
		&"fire": _emit("flame", pos, back + Vector3(0, 0.6, 0), c); _emit("ember", pos, back * 0.5 + _rnd(0.6), c)
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
			_burst("debris", pos + Vector3(0, 0.3, 0), n / 3, 4.0, Color.WHITE, 1.4)
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
	_live.append({"kind": "wave", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": dur, "acc": 0.0})
	if DECALS.has(el):
		decal(el, pos, r * (0.55 if el in [&"holy", &"level", &"heal"] else 0.7), maxf(dur * 2.5, 1.2))
	if el in [&"holy", &"level"]:
		_cloud("ray", pos, 0.3, 2, Vector3.ZERO, c)


func _linger(el: StringName, pos: Vector3, r: float, c: Color, dur: float) -> void:
	if dur <= 0.0:
		dur = 2.0
	if DECALS.has(el):
		decal(el, pos, r, dur + 0.4)
	_live.append({"kind": "field", "el": el, "pos": pos, "r": r, "c": c, "t": 0.0, "dur": dur, "acc": 0.0})


# --- Bolts -------------------------------------------------------------------

## Forked lightning between points: a jagged hot ribbon with side branches,
## flickering once before it dies (0.2 s). Pooled meshes, one shared material.
func bolt(points: PackedVector3Array, c := Color(0.65, 0.82, 1.0), forks := true, width := 0.07) -> void:
	if points.size() < 2:
		return
	var mi := _take_bolt()
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
	mi.transparency = 0.0
	mi.visible = true
	_live.append({"kind": "bolt", "node": mi, "t": 0.0, "dur": 0.2})
	for p in points:
		_burst("spark", p, 3, 3.5, c)


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
	if not DECALS.has(el) or r < 0.15:
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
	var info := PackedFloat32Array(); info.resize(cap * 4)  # size, angle, spin, frame
	age.fill(1e9)
	_layers[n] = {"node": node, "mm": mm, "cap": cap, "next": 0, "alive": 0, "top": 0,
		"pos": pos, "vel": vel, "col": col, "age": age, "info": info,
		"life": float(d["life"]), "grav": d["grav"], "damp": float(d["damp"]),
		"flip": bool(d.get("flip", false)), "atlas": int(d.get("hf", 1)) * int(d.get("vf", 1)) > 1}
	built["layer"] += 1
	return node


func _emit(n: String, p: Vector3, v: Vector3, c: Color) -> void:
	layer(n)
	var L: Dictionary = _layers[n]
	var i: int = L["next"]
	L["next"] = (i + 1) % int(L["cap"])
	if float(L["age"][i]) >= float(L["life"]):
		L["alive"] = int(L["alive"]) + 1
	L["top"] = maxi(int(L["top"]), i + 1)
	var d: Dictionary = LAYERS[n]
	var sz: Vector2 = d["size"]
	L["pos"][i] = p
	L["vel"][i] = v
	L["col"][i] = c
	L["age"][i] = 0.0
	var info: PackedFloat32Array = L["info"]
	info[i * 4] = randf_range(sz.x, sz.y)
	info[i * 4 + 1] = randf() * TAU if d.has("spin") else 0.0
	info[i * 4 + 2] = randf_range(-1.0, 1.0) * deg_to_rad(float(d.get("spin", 0.0)))
	info[i * 4 + 3] = float(randi() % 4) / 4.0 + 0.01 if L["atlas"] and not L["flip"] else 0.0
	L["info"] = info
	var node: MultiMeshInstance3D = L["node"]
	node.visible = true
	(L["mm"] as MultiMesh).visible_instance_count = int(L["top"])


## Step one layer: integrate, then write transforms, colours and custom data.
func _tick_layer(L: Dictionary, dt: float) -> void:
	var mm: MultiMesh = L["mm"]
	var life: float = L["life"]
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


## Particles scattered in a sphere of `spread`, drifting with `vel` (+ jitter).
func _cloud(n: String, at: Vector3, spread: float, count: int, vel: Vector3, c: Color, jitter := 0.6) -> void:
	for i in mini(count, MAX_PER_CALL):
		var off := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * spread
		if LAYERS[n].get("fixed_y", false):
			off.y = 0.0
		_emit(n, at + off, vel + _rnd(jitter), c)


## Particles thrown outward (and up by `up`) from a point.
func _burst(n: String, at: Vector3, count: int, speed: float, c: Color, up := 0.8) -> void:
	for i in mini(count, MAX_PER_CALL):
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0) * up + 0.1, randf_range(-1, 1)).normalized()
		_emit(n, at, dir * speed * randf_range(0.45, 1.0), c)


## Particles spiralling up around a point (heals, frost casts, leaves).
func _swirl(n: String, at: Vector3, r: float, count: int, spin: float, c: Color) -> void:
	for i in mini(count, MAX_PER_CALL):
		var a := TAU * i / maxf(count, 1) + randf() * 0.3
		var off := Vector3(sin(a), 0, cos(a)) * r
		var tang := Vector3(cos(a), 0, -sin(a)) * spin
		_emit(n, at + off + Vector3(0, randf_range(0.2, 0.9), 0), tang + Vector3(0, randf_range(1.0, 2.2), 0), c)


func _rnd(s: float) -> Vector3:
	return Vector3(randf_range(-s, s), randf_range(-s, s) * 0.6, randf_range(-s, s))


# --- Waves and fields (driven per frame) -------------------------------------

## What the front of a nova throws up, per element: [layer, up speed, outward].
const WAVE := {
	&"fire": ["flame", 1.4, 2.0], &"frost": ["shard", 5.5, 1.5], &"storm": ["spark", 3.5, 3.0],
	&"poison": ["bubble", 1.6, 1.0], &"nature": ["leaf", 3.0, 2.0], &"holy": ["mote", 2.5, 1.0],
	&"level": ["mote", 3.0, 1.0], &"shadow": ["wisp", 1.8, 1.4], &"physical": ["dust", 0.8, 2.5],
	&"blood": ["blood", 3.0, 2.0], &"heal": ["cross", 1.4, 0.5], &"buff": ["chevron", 1.8, 0.5],
}
## And the second accent layer on the front.
const WAVE2 := {
	&"fire": "ember", &"frost": "flake", &"storm": "", &"poison": "spore", &"nature": "spore",
	&"holy": "ray", &"level": "ray", &"shadow": "bone", &"physical": "debris", &"blood": "",
	&"heal": "mote", &"buff": "mote",
}

func _tick_wave(e: Dictionary, k: float, dt: float) -> void:
	var el: StringName = e["el"]
	var front: float = float(e["r"]) * (1.0 - pow(1.0 - k, 2.0))
	var c: Color = e["c"]
	var w: Array = WAVE[el]
	# Density by circumference: about one sprite per 0.6 m of front per frame step.
	var rate := clampf(TAU * maxf(front, 0.5) / 0.6, 6.0, 60.0) / maxf(float(e["dur"]), 0.2) * 1.4
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
	e["acc"] = float(e["acc"]) + dt * clampf(r * 6.0, 4.0, 18.0) * (0.5 if quality_low else 1.0)
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
				_tick_field(e, delta)
			"bolt":
				var b := e["node"] as MeshInstance3D
				# Hard flicker: full, dip, full, then gone. No soft fade-out glow.
				b.transparency = 0.0 if k < 0.35 or (k > 0.5 and k < 0.75) else 0.7
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
