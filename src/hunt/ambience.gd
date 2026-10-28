extends RefCounted
## Ambient life and sound for Rimehollow (frost) and the Cinder Mire (swamp).
## Hunt calls `Ambience.tick(self, dt)` once per physics tick (hunt_events.gd,
## `_tick_hazards`); the first call builds the zone's set, or nothing for a zone
## without one. Everything is hung under the hunt's world and freed with it.
##
## Life is a handful of flat-coloured primitive critters (clean, crisp, no haze,
## no particles): at most `cap` alive, each 4 to 12 meshes, none that collide,
## hurt or block. They sit, then leave when the hero comes close or their time is
## up. The sound is one looping bed (ducked while the fight is loud) and a few
## spatial one-shots. On Low quality there are two critters and no breath puffs.
## No class_name (OTA).

const DIR := "res://assets/audio/ambient/"
const Terrain := preload("res://src/hunt/terrain.gd")

## `life`: kind -> weight. `shots`: [sound, dB, [min, max] seconds between].
const SETS := {
	"frost": {
		"bed": "frost_bed", "bed_db": 0.0, "breath": true, "cap": 5, "every": Vector2(2.5, 6.0),
		"life": {"hare": 3.0, "owl": 1.2, "wolf": 0.8},
		"shots": [["frost_creak", -12.0, Vector2(9.0, 18.0)], ["frost_drip", -15.0, Vector2(4.0, 9.0)], ["frost_gust", -10.0, Vector2(16.0, 32.0)]],
	},
	"swamp": {
		"bed": "swamp_bed", "bed_db": 0.0, "breath": false, "cap": 6, "every": Vector2(2.0, 5.0),
		"life": {"frog": 3.0, "dragonfly": 1.6, "crow": 1.0, "bubble": 2.2, "ring": 1.2},
		"shots": [["swamp_ember", -13.0, Vector2(5.0, 10.0)]],
	},
}
## Most of a kind alive at once, and the closest it may appear to the hero.
const LIMIT := {"hare": 3, "owl": 2, "wolf": 1, "frog": 4, "dragonfly": 3, "crow": 2, "bubble": 3, "ring": 2}
const MIN_D := {"hare": 8.0, "owl": 8.0, "wolf": 9.0, "frog": 5.0, "dragonfly": 4.0, "crow": 9.0, "bubble": 2.5, "ring": 3.0}
const VOICES := 4

static var _mats := {}
static var _streams := {}

var h  ## the Hunt (untyped: Hunt reaches this script through its own base class)
var zone := ""
var cfg: Dictionary
var bits: Array = []
var cap := 5
var _spawn_t := 1.5
var _shot_t: Array = []
var _breath_t := 1.0
var _bed: AudioStreamPlayer
var _vol := -40.0
var _voices := 0
var calm := false  ## nothing takes fright (the screenshot lineup sets it)


class Bit extends RefCounted:
	var kind := ""
	var node: Node3D
	var st := "idle"
	var t := 0.0
	var age := 0.0
	var life := 20.0
	var leave := INF
	var dir := Vector3.ZERO
	var from := Vector3.ZERO
	var n := 0
	var croak := 3.0
	var parts := {}


## The Hunt's entry. Builds the set on the first call; null when the zone has none.
static func tick(hunt, dt: float) -> void:
	if not hunt.has_meta("ambience"):
		var made: Variant = make(hunt, hunt.zone_id)
		hunt.set_meta("ambience", made if made != null else false)  # a null meta would remove the key
	var a: Variant = hunt.get_meta("ambience")
	if a is RefCounted:
		(a as RefCounted).step(dt)


static func make(hunt, zone_id: String) -> RefCounted:
	if not SETS.has(zone_id):
		return null
	var a: RefCounted = (load("res://src/hunt/ambience.gd") as GDScript).new()
	a.setup(hunt, zone_id)
	return a


func setup(hunt, zone_id: String) -> void:
	h = hunt
	zone = zone_id
	cfg = SETS[zone_id]
	cap = 2 if h.low else int(cfg["cap"])
	for s: Array in cfg["shots"]:
		_shot_t.append(randf_range(2.0, float((s[2] as Vector2).x)))
	var bed: AudioStream = _load(str(cfg["bed"]))
	if bed != null:
		if bed is AudioStreamOggVorbis:
			(bed as AudioStreamOggVorbis).loop = true
		_bed = AudioStreamPlayer.new()
		_bed.stream = bed
		_bed.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		_bed.volume_db = _vol
		h.add_child(_bed)
		_bed.play()


func step(dt: float) -> void:
	if h._warming or h._ended or not h.hero.alive or not (h.phase == "rise" or h.phase == "boss"):
		return
	_bed_level(dt)
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		var span: Vector2 = cfg["every"]
		_spawn_t = randf_range(span.x, span.y)
		if bits.size() < cap:
			_spawn_one()
	var i := bits.size() - 1
	while i >= 0:
		var b: Bit = bits[i]
		_think(b, dt)
		_scale(b, dt)
		if b.leave <= 0.0 or b.node.position.distance_to(h.hero.flat_pos()) > 30.0:
			b.node.queue_free()
			bits.remove_at(i)
		i -= 1
	_shots(dt)
	if bool(cfg["breath"]) and not h.low:
		_breath(dt)


# --- Sound ----------------------------------------------------------------------

func _bed_level(dt: float) -> void:
	if _bed == null:
		return
	var target: float = Sfx._sfx_db(float(cfg["bed_db"]) - Sfx.intensity * 8.0)
	_vol = move_toward(_vol, target, 12.0 * dt)
	_bed.volume_db = _vol


static func _load(name_: String) -> AudioStream:
	var p := DIR + name_ + ".ogg"
	return load(p) as AudioStream if ResourceLoader.exists(p) else null


## Every numbered variant of a sound ("swamp_frog" is swamp_frog_1, _2, ...).
static func variants(name_: String) -> Array:
	if not _streams.has(name_):
		var list: Array = []
		var i := 1
		while ResourceLoader.exists("%s%s_%d.ogg" % [DIR, name_, i]):
			list.append(load("%s%s_%d.ogg" % [DIR, name_, i]))
			i += 1
		var single := _load(name_)
		if single != null:
			list.append(single)
		_streams[name_] = list
	return _streams[name_]


func play(name_: String, db: float, at: Vector3) -> bool:
	if _voices >= VOICES:
		return false
	var list := variants(name_)
	if list.is_empty():
		return false
	var p := AudioStreamPlayer3D.new()
	p.stream = list[randi() % list.size()]
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.volume_db = Sfx._sfx_db(db)
	p.unit_size = 10.0
	p.max_distance = 45.0
	p.pitch_scale = randf_range(0.93, 1.07)
	p.position = at + Vector3(0, 0.6, 0)
	h.world.add_child(p)
	_voices += 1
	p.finished.connect(func():
		_voices -= 1
		p.queue_free())
	p.play()
	return true


func _shots(dt: float) -> void:
	var list: Array = cfg["shots"]
	for i in list.size():
		_shot_t[i] -= dt
		if _shot_t[i] > 0.0:
			continue
		var s: Array = list[i]
		var span: Vector2 = s[2]
		_shot_t[i] = randf_range(span.x, span.y)
		var a := randf() * TAU
		var at: Vector3 = h.hero.flat_pos() + Vector3(sin(a), 0, cos(a)) * randf_range(6.0, 12.0)
		play(str(s[0]), float(s[1]), at)
		if str(s[0]) == "swamp_ember" and not h.low:
			h.fx.embers_at(at, Color(1.0, 0.55, 0.15), 1, 0.4)


## A foe's breath in the cold: one small puff, only for the three nearest.
func _breath(dt: float) -> void:
	_breath_t -= dt
	if _breath_t > 0.0:
		return
	_breath_t = 1.6
	var hp: Vector3 = h.hero.flat_pos()
	var n := 0
	for f in h.foes:
		if not f.alive or f.state == "spawn" or f.def.get("fly", false):
			continue
		if f.flat_pos().distance_to(hp) > 9.0:
			continue
		var fwd := Vector3(sin(f.rotation.y), 0, cos(f.rotation.y))
		h.fx.puff(f.position + Vector3(0, 1.0 * float(f.def["scale"]), 0) + fwd * 0.4 * float(f.def["scale"]), Color(0.9, 0.95, 1.0, 0.35), 2, 0.15, 0.4)
		n += 1
		if n >= 3:
			break


# --- Spawning -------------------------------------------------------------------

func count(kind: String) -> int:
	var n := 0
	for b: Bit in bits:
		if b.kind == kind:
			n += 1
	return n


func _spawn_one() -> void:
	var kinds: Dictionary = cfg["life"]
	var total := 0.0
	for k: String in kinds:
		if count(k) < int(LIMIT[k]):
			total += float(kinds[k])
	if total <= 0.0:
		return
	var r := randf() * total
	for k: String in kinds:
		if count(k) >= int(LIMIT[k]):
			continue
		r -= float(kinds[k])
		if r <= 0.0:
			var at: Variant = _spot(k)
			if at != null:
				spawn(k, at)
			return


func _spot(kind: String) -> Variant:
	var hp: Vector3 = h.hero.flat_pos()
	var ar: Node = h.arena
	var tr: Object = ar.get("terrain")
	if tr == null and ar.has_meta("terrain"):
		tr = ar.get_meta("terrain")
	for i in 8:
		var p := Vector3(hp.x + randf_range(-13.0, 13.0), 0.0, hp.z + randf_range(-12.0, 5.0))
		if kind == "wolf":
			p.x = ar.max_x - 1.2 if randf() < 0.5 else ar.min_x + 1.2
		p.x = clampf(p.x, ar.min_x + 1.2, ar.max_x - 1.2)
		p.z = clampf(p.z, ar.min_z + 1.2, ar.max_z - 1.2)
		var d := p.distance_to(hp)
		if d < float(MIN_D[kind]) or d > 18.0:
			continue
		if kind != "wolf" and ar.blocked(p, 0.6):
			continue
		if tr != null and int(tr.kind_at(p)) in [Terrain.WATER, Terrain.WALL_ICE, Terrain.BURNING, Terrain.THIN_ICE]:
			continue
		return p
	return null


func spawn(kind: String, at: Vector3) -> Bit:
	var b := Bit.new()
	b.kind = kind
	b.node = Node3D.new()
	b.node.position = Vector3(at.x, 0.0, at.z)
	b.node.scale = Vector3.ONE * 0.01
	h.world.add_child(b.node)
	b.life = randf_range(14.0, 26.0)
	var to: Vector3 = h.hero.flat_pos() - b.node.position
	b.node.rotation.y = atan2(to.x, to.z) + randf_range(-0.8, 0.8)
	match kind:
		"hare":
			_build_hare(b)
		"owl":
			_build_owl(b)
		"wolf":
			_build_wolf(b)
			b.life = randf_range(18.0, 30.0)
			b.node.rotation.y = atan2(to.x, to.z)
		"frog":
			_build_frog(b)
		"dragonfly":
			_build_dragonfly(b)
			b.from = b.node.position
			b.node.position.y = 1.2
			b.life = randf_range(12.0, 20.0)
		"crow":
			_build_crow(b)
		"bubble":
			_build_bubble(b)
			b.st = "rise"
		"ring":
			_build_ring(b)
			b.st = "ring"
	bits.append(b)
	return b


# --- Building: flat colours, a few primitives each ------------------------------

static func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var key := "%s%s" % [c.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		if glow:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 1.3
		_mats[key] = m
	return _mats[key]


static func _m(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, sc := Vector3.ONE, rot := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, glow)
	mi.position = pos
	mi.scale = sc
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _cone(r: float, hgt: float, top := 0.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = top
	c.height = hgt
	c.radial_segments = 8
	c.rings = 1
	return c


static func _capsule(r: float, hgt: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = hgt
	c.radial_segments = 8
	c.rings = 3
	return c


## Critter models (CC BY, Sketchfab; assets/critters/CREDITS in CREDITS.md): file, height in metres,
## albedo tint (a grimmer, duller cast on the one that came out too bright). The dragonfly is drawn in code.
const CRIT := "res://assets/critters/"
const MODELS := {
	"hare": ["hare", 0.8, Color(1, 1, 1)],
	"owl": ["owl", 0.9, Color(1, 1, 1)],
	"wolf": ["wolf", 1.2, Color(1, 1, 1)],
	"frog": ["frog", 0.4, Color(0.52, 0.6, 0.46)],
	"crow": ["crow", 0.7, Color(1, 1, 1)],
}


## The critter's model under `parent`: its wrapped scene scaled to the kind's height, the posed
## culling bounds set, the tint and a lit material applied. The AnimationPlayer goes in parts["ap"].
func _model(b: Bit, parent: Node3D) -> Node3D:
	var spec: Array = MODELS[b.kind]
	var ps := load(CRIT + str(spec[0]) + ".tscn") as PackedScene
	var m: Node3D = ps.instantiate()
	m.scale = Vector3.ONE * float(spec[1])
	var culls: Dictionary = m.get_meta("cull_aabbs", {})
	var inner := m.get_child(0) if m.get_child_count() > 0 else null
	for mp: String in culls:
		var mi := inner.get_node_or_null(mp) as MeshInstance3D if inner else null
		if mi:
			mi.custom_aabb = culls[mp]
	var tint: Color = spec[2]
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in inst.get_surface_override_material_count():
			var mat := inst.get_active_material(i) as BaseMaterial3D
			if mat == null:
				continue
			mat = mat.duplicate() as BaseMaterial3D
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = mat.albedo_color * tint
			inst.set_surface_override_material(i, mat)
	parent.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	b.parts["ap"] = ap
	return m


## Plays the model's clip whose name has `key` in it (looping), from `at` (0..1 of its length);
## speed 0 holds that frame.
func _clip(b: Bit, key: String, speed := 1.0, at := 0.0, loop := true) -> void:
	var ap: AnimationPlayer = b.parts.get("ap")
	if ap == null:
		return
	for n: String in ap.get_animation_list():
		if n.to_lower().contains(key) or key == "":
			var an := ap.get_animation(n)
			an.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			ap.play(n, 0.15, speed)
			if at > 0.0:
				ap.seek(an.length * at, true)
			return


func _build_hare(b: Bit) -> void:
	var body := Node3D.new()
	b.node.add_child(body)
	b.parts["body"] = body
	_model(b, body)
	var ears := Node3D.new()
	body.add_child(ears)
	b.parts["ears"] = ears
	_clip(b, "idle")


func _build_owl(b: Bit) -> void:
	# The snowy owl model is flying (wings out, no folded pose): it glides across the hollow.
	var bird := Node3D.new()
	bird.position = Vector3(0, 2.3, 0)
	b.node.add_child(bird)
	b.parts["bird"] = bird
	_model(b, bird)
	_clip(b, "", 1.0)
	b.st = "glide"


func _build_wolf(b: Bit) -> void:
	var body := Node3D.new()
	b.node.add_child(body)
	b.parts["body"] = body
	b.parts["legs"] = []
	_model(b, body)
	_clip(b, "idle", 0.6)


func _build_frog(b: Bit) -> void:
	_model(b, b.node)
	_clip(b, "", 0.7)


## Drawn in code (flat primitives, no licensed model): a slim blue-grey body, a round head and
## four glassy wings that `_dragonfly` beats. The body points along +Z, the way it flies.
func _build_dragonfly(b: Bit) -> void:
	var body := Color(0.34, 0.5, 0.62)
	_m(b.node, _sphere(0.045), body, Vector3(0, 0, 0.17))
	_m(b.node, _cone(0.03, 0.2), body, Vector3(0, 0, 0.07), Vector3.ONE, Vector3(PI / 2, 0, 0))
	_m(b.node, _cone(0.018, 0.34, 0.006), body, Vector3(0, 0, -0.2), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	var wings := []
	for side in [-1.0, 1.0]:
		for zoff in [0.1, 0.03]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.03, 0.03, zoff)
			b.node.add_child(pivot)
			_m(pivot, _box(0.24, 0.006, 0.07), Color(0.75, 0.88, 0.95), Vector3(side * 0.12, 0, 0))
			wings.append([pivot, side])
	b.parts["wings"] = wings


func _build_crow(b: Bit) -> void:
	_m(b.node, _cone(0.16, 1.0, 0.12), Color(0.34, 0.25, 0.17), Vector3(0, 0.5, 0))  # its stump
	var bird := Node3D.new()
	bird.position = Vector3(0, 1.0, 0)
	b.node.add_child(bird)
	b.parts["bird"] = bird
	_model(b, bird)
	_clip(b, "takeoff", 0.0, 0.3)  # held on a perched frame


func _build_bubble(b: Bit) -> void:
	var ball := _m(b.node, _sphere(0.13), Color(0.3, 0.75, 0.95), Vector3(0, 0.1, 0), Vector3.ONE, Vector3.ZERO, true)
	b.parts["ball"] = ball
	var flame := _m(b.node, _cone(0.1, 0.4), Color(0.4, 0.65, 1.0), Vector3(0, 0.2, 0), Vector3.ONE, Vector3.ZERO, true)
	flame.visible = false
	b.parts["flame"] = flame


func _build_ring(b: Bit) -> void:
	var ring := Node3D.new()
	ring.position = Vector3(0, 0.05, 0)
	b.node.add_child(ring)
	b.parts["ring"] = ring
	for i in 8:
		var a := TAU * i / 8.0
		_m(ring, _box(0.2, 0.02, 0.05), Color(0.62, 0.7, 0.5), Vector3(sin(a), 0, cos(a)) * 0.2, Vector3.ONE, Vector3(0, a + PI / 2, 0))


# --- Behaviour ------------------------------------------------------------------

func _away(b: Bit) -> Vector3:
	var d: Vector3 = b.node.position - h.hero.flat_pos()
	d.y = 0.0
	if d.length() < 0.05:
		d = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return d.normalized()


func _dist(b: Bit) -> float:
	if calm:
		return 99.0
	return b.node.position.distance_to(h.hero.flat_pos())


func _clamped(p: Vector3) -> bool:
	var ar: Node = h.arena
	return p.x <= ar.min_x + 0.5 or p.x >= ar.max_x - 0.5 or p.z <= ar.min_z + 0.5 or p.z >= ar.max_z - 0.5


## Grow in over 0.4 s; once `leave` is counting, shrink away over the last 0.5 s.
func _scale(b: Bit, dt: float) -> void:
	b.age += dt
	if b.leave < INF:
		b.leave -= dt
	var k := minf(b.age / 0.4, 1.0) * clampf(b.leave / 0.5, 0.0, 1.0)
	b.node.scale = Vector3.ONE * maxf(k, 0.01)


func _think(b: Bit, dt: float) -> void:
	b.t += dt
	match b.kind:
		"hare":
			_hare(b, dt)
		"owl":
			_glide(b, dt)
		"crow":
			_perched(b, dt, 9.0, 6.5, 4.0, "swamp_crow")
		"wolf":
			_wolf(b, dt)
		"frog":
			_frog(b, dt)
		"dragonfly":
			_dragonfly(b, dt)
		"bubble":
			_bubble(b, dt)
		"ring":
			_ring(b, dt)


func _hare(b: Bit, dt: float) -> void:
	var body: Node3D = b.parts["body"]
	if b.st == "idle":
		(b.parts["ears"] as Node3D).rotation.z = sin(b.t * 2.3) * 0.08
		b.life -= dt
		if _dist(b) < 6.0 or b.life <= 0.0:
			b.st = "run"
			b.t = 0.0
			b.dir = _away(b)
			b.leave = 2.4
			_clip(b, "run", 1.4)
		return
	var d := b.dir.rotated(Vector3.UP, sin(b.t * 5.0) * 0.5)
	b.node.position += d * 9.0 * dt
	b.node.rotation.y = atan2(d.x, d.z)
	body.position.y = absf(sin(b.t * 13.0)) * 0.07
	if _clamped(b.node.position):
		var ar: Node = h.arena
		b.node.position.x = clampf(b.node.position.x, ar.min_x + 0.5, ar.max_x - 0.5)
		b.node.position.z = clampf(b.node.position.z, ar.min_z + 0.5, ar.max_z - 0.5)
		b.leave = minf(b.leave, 0.5)


## An owl glides across the hollow, high and slow, and is gone.
func _glide(b: Bit, dt: float) -> void:
	var bird: Node3D = b.parts["bird"]
	if b.dir == Vector3.ZERO:
		var to: Vector3 = h.hero.flat_pos() - b.node.position
		b.dir = Vector3(to.z, 0.0, -to.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
		b.node.rotation.y = atan2(b.dir.x, b.dir.z)
	b.node.position += b.dir * (0.0 if calm else 3.4) * dt
	bird.position.y = 2.3 + sin(b.t * 1.1) * 0.12
	bird.rotation.z = sin(b.t * 0.8) * 0.12
	if _clamped(b.node.position):
		var ar: Node = h.arena
		b.node.position.x = clampf(b.node.position.x, ar.min_x + 0.5, ar.max_x - 0.5)
		b.node.position.z = clampf(b.node.position.z, ar.min_z + 0.5, ar.max_z - 0.5)
		b.leave = minf(b.leave, 0.6)
	if b.t > 7.0 and b.leave == INF:
		b.leave = 0.6


## A crow on its stump: sits, looks about, flaps off.
func _perched(b: Bit, dt: float, scare: float, speed: float, rise: float, call: String) -> void:
	var bird: Node3D = b.parts["bird"]
	if b.st == "idle":
		bird.rotation.y = sin(b.t * 1.3) * 0.5
		b.croak -= dt
		if b.croak <= 0.0:
			b.croak = randf_range(5.0, 11.0)
			if randf() < 0.6:
				play(call, -10.0, b.node.position)
		b.life -= dt
		if _dist(b) < scare or b.life <= 0.0:
			b.st = "fly"
			b.t = 0.0
			b.dir = _away(b)
			play(call, -8.0, b.node.position)
			_clip(b, "takeoff", 1.0, 0.62, false)
		return
	bird.position += (b.dir * speed + Vector3.UP * rise) * dt
	bird.rotation.y = atan2(b.dir.x, b.dir.z)
	if b.t > 2.6 and b.leave == INF:
		b.leave = 0.6


func _wolf(b: Bit, dt: float) -> void:
	var body: Node3D = b.parts["body"]
	var legs: Array = b.parts["legs"]
	if b.st == "idle":
		b.life -= dt
		var to: Vector3 = h.hero.flat_pos() - b.node.position
		b.node.rotation.y = lerp_angle(b.node.rotation.y, atan2(to.x, to.z), minf(dt * 1.2, 1.0))
		body.rotation.x = sin(b.t * 0.9) * 0.02
		if _dist(b) < 5.5 or b.life <= 0.0:
			b.st = "trot"
			b.t = 0.0
			b.dir = Vector3(signf(b.node.position.x), 0, 0.0) if absf(b.node.position.x) > 1.0 else _away(b)
			b.leave = 2.6
		return
	b.node.position += b.dir * 6.0 * dt
	b.node.rotation.y = atan2(b.dir.x, b.dir.z)
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(b.t * 12.0 + (0.0 if i % 3 == 0 else PI)) * 0.6


func _frog(b: Bit, dt: float) -> void:
	if b.st == "idle":
		b.croak -= dt
		if b.croak <= 0.0:
			b.croak = randf_range(4.0, 9.0)
			if randf() < 0.7:
				play("swamp_frog", -9.0, b.node.position)
				b.node.scale.y = 1.0
		b.life -= dt
		if _dist(b) < 4.5 or b.life <= 0.0:
			b.st = "hop"
			b.t = 0.0
			b.n = 3
			b.dir = _away(b)
			b.from = b.node.position
		return
	if b.st == "hop":
		var k := b.t / 0.38
		b.node.position = b.from + b.dir * 1.5 * minf(k, 1.0)
		b.node.position.y = sin(PI * minf(k, 1.0)) * 0.45
		b.node.rotation.y = atan2(b.dir.x, b.dir.z)
		if k >= 1.0:
			b.n -= 1
			b.node.position.y = 0.0
			b.t = 0.0
			b.from = b.node.position
			b.st = "rest" if b.n > 0 else "sink"
		return
	if b.st == "rest":
		if b.t >= 0.12:
			b.t = 0.0
			b.st = "hop"
		return
	if b.st == "sink" and b.leave == INF:
		b.leave = 0.6
	b.node.position.y -= dt * 0.3


func _dragonfly(b: Bit, dt: float) -> void:
	for w: Array in b.parts["wings"]:
		(w[0] as Node3D).rotation.z = sin(b.t * 50.0) * 0.5 * float(w[1])
	if b.st == "idle":
		var a := b.t * 1.8
		var p := b.from + Vector3(cos(a), 0, sin(a)) * 1.4
		p.y = 1.2 + sin(b.t * 2.4) * 0.25
		b.node.rotation.y = atan2(-sin(a), cos(a))
		b.node.position = p
		b.life -= dt
		if _dist(b) < 3.0 or b.life <= 0.0:
			b.st = "dash"
			b.t = 0.0
			b.dir = (_away(b) + Vector3.UP * 0.3).normalized()
			b.leave = 1.4
		return
	b.node.position += b.dir * 8.0 * dt
	b.node.rotation.y = atan2(b.dir.x, b.dir.z)


func _bubble(b: Bit, dt: float) -> void:
	var ball: Node3D = b.parts["ball"]
	var flame: Node3D = b.parts["flame"]
	if b.st == "rise":
		var k := minf(b.t / 1.3, 1.0)
		ball.position.y = 0.1 + k * 0.8
		ball.scale = Vector3.ONE * (0.5 + k * 0.7)
		if k >= 1.0:
			b.st = "pop"
			b.t = 0.0
			ball.visible = false
			flame.visible = true
			b.leave = 0.55
			play("swamp_bubble", -12.0, b.node.position)
		return
	flame.scale = Vector3(1.0 - b.t * 0.8, 1.0 + sin(b.t * 18.0) * 0.2, 1.0 - b.t * 0.8)


func _ring(b: Bit, dt: float) -> void:
	var k := minf(b.t / 1.5, 1.0)
	(b.parts["ring"] as Node3D).scale = Vector3(1.0 + k * 3.2, 1.0, 1.0 + k * 3.2)
	if k >= 1.0 and b.leave == INF:
		b.leave = 0.01
