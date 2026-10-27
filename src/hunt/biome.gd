extends RefCounted
## The rules of the Frozen Crypt and the Burning Swamp (a zone with `hazards`
## in DB.ZONES). Preloaded by hunt.gd, no class_name. One instance per hunt,
## ticked from `_tick_hazards`. It owns three things:
##   - hazards: falling icicles, drifts and a gale in the Crypt; methane vents,
##     bog mud and marsh fire in the Swamp. All telegraphed, none in the
##     warm-up, none between rooms of a Long Road trial.
##   - riders: what a foe's landed blow leaves on the hero (`chill` drags,
##     `scorch` sets the ground alight).
##   - the dead's leavings: `leave` (a caster's blast or a slam), `trail` (a
##     lunge) and `death` (a body that shatters or ignites).
## Everything is drawn through the Fx vfx library: crisp, no fog, no tint.

const FROST := Color(0.6, 0.88, 1.0)
const FIRE := Color(1.0, 0.5, 0.15)
const NO_TINT := Color(0, 0, 0, 0)
## Icicles: radius, warning, damage; vents: radius, warning, damage.
const ICICLE := {"r": 1.7, "delay": 1.25, "dmg": 14.0, "every": 8.0, "every_ai": 1.6, "min": 3.2}
const VENT := {"r": 1.5, "warn": 1.1, "dmg": 18.0, "every": 8.5, "every_ai": 1.4, "min": 4.5}
const MARSH := {"r": 1.6, "delay": 1.3, "dps": 7.0, "dur": 5.0, "every": 9.0, "every_ai": 1.5, "min": 4.5}
const GALE := {"every": 24.0, "every_ai": 3.0, "min": 14.0, "warn": 1.6, "dur": 4.0, "accel": 78.0}
const PATCH_DPS := {"frost": 3.0, "fire": 6.0}

var h
var hazards: Array = []
var _ice_t := 5.0
var _marsh_t := 8.0
var _gale_t := 20.0
var _gale_warn := 0.0
var _gale_left := 0.0
var _gale_dir := Vector3.RIGHT
var _puff_t := 0.0
var _idle_t := 0.0
## Methane vents: {pos, t, warn}, from arena.hazard_spots.
var vents: Array = []
static var _spike_mesh: CylinderMesh
static var _spike_mat: StandardMaterial3D


func setup(hunt) -> void:
	h = hunt
	hazards = h.zone.get("hazards", [])
	for p: Vector3 in h.arena.hazard_spots:
		vents.append({"pos": p, "t": randf_range(3.0, 9.0), "warn": 0.0})


func has(id: String) -> bool:
	return id in hazards


func _active() -> bool:
	if h._warming or not h.hero.alive or not (h.phase == "rise" or h.phase == "boss"):
		return false
	return h.mode != "trial" or h._room_active()


func _scale() -> float:
	return float(h.tier["dmg"])


func tick(dt: float) -> void:
	if h.hero.alive and not h._warming and (h.phase == "rise" or h.phase == "boss"):
		_slow_ground()
		ambient(dt)
	if not _active():
		return
	var pace := 0.6 if h.phase == "boss" else 1.0
	var ai: float = h.ai()
	if has("icefall"):
		_ice_t -= dt * pace
		if _ice_t <= 0.0:
			_ice_t = maxf(float(ICICLE["every"]) - float(ICICLE["every_ai"]) * ai, float(ICICLE["min"])) * randf_range(0.85, 1.15)
			_icefall(1 + (1 if ai >= 1.5 else 0) + (1 if ai >= 2.5 else 0))
	if has("gale") and h.phase == "rise":
		_tick_gale(dt, ai)
	if has("marsh"):
		_marsh_t -= dt * pace
		if _marsh_t <= 0.0:
			_marsh_t = maxf(float(MARSH["every"]) - float(MARSH["every_ai"]) * ai, float(MARSH["min"])) * randf_range(0.85, 1.15)
			_marsh_fire(1 + (1 if ai >= 2.0 else 0))
	if has("vents"):
		_tick_vents(dt, pace, ai)


## Drifts and bog mud: standing in one drags the hero (speed x0.6).
func _slow_ground() -> void:
	var hp: Vector3 = h.hero.flat_pos()
	for z: Dictionary in h.arena.slow_zones:
		if hp.distance_to(z["pos"]) < float(z["r"]):
			h.hero.slow_t = maxf(h.hero.slow_t, 0.3)
			return


## Captures: every hazard of this zone going off at once around the hero.
func demo() -> void:
	if has("icefall"):
		_icefall(3)
	if has("marsh"):
		_marsh_fire(3)
	if has("vents"):
		for v: Dictionary in vents:
			_vent_burst(v["pos"])


# --- The Frozen Crypt ---------------------------------------------------------

func _icefall(n: int) -> void:
	var hero = h.hero
	for i in n:
		var at: Vector3 = hero.flat_pos() + hero.vel * 0.35 * minf(h.ai(), 1.0)
		if i > 0:
			at = hero.flat_pos() + Actor.dir_of(randf() * TAU) * randf_range(2.5, 5.0)
		_icicle(h.arena.resolve(at, 0.4), 0.25 * i)
	Sfx.play("quake", -14.0, 1.7)
	h.tip("icefall", "Icicles fall where you stand: keep moving", "ice-bolt")


## One icicle: a frost circle warns, a spike drops into it, then it shatters
## (hero hurt and dragged, foes under it hurt) and leaves a slowing patch.
func _icicle(at: Vector3, extra: float) -> void:
	var delay := float(ICICLE["delay"]) + extra
	var r := float(ICICLE["r"])
	h.blast_at(at, r, delay, float(ICICLE["dmg"]) * _scale(), "slow", FROST, 0.5)
	var spike := _spike(at, delay)
	h.get_tree().create_timer(delay, false).timeout.connect(func():
		if not is_instance_valid(h) or h._ended or h._warming:
			return
		if is_instance_valid(spike):
			spike.queue_free()
		for f in h.foes_near(at, r):
			h.damage_foe(f, 40.0, h.hero, Vector3.ZERO, 0.0)
		h.add_fire_patch(at, r * 0.85, 4.0, 0.0, &"frost", true))


func _spike(at: Vector3, delay: float) -> MeshInstance3D:
	if _spike_mesh == null:
		_spike_mesh = CylinderMesh.new()
		_spike_mesh.top_radius = 0.0
		_spike_mesh.bottom_radius = 0.32
		_spike_mesh.height = 2.4
		_spike_mesh.radial_segments = 6
		_spike_mesh.rings = 1
		_spike_mat = StandardMaterial3D.new()
		_spike_mat.albedo_color = Color(0.82, 0.94, 1.0)
		_spike_mat.roughness = 0.12
		_spike_mat.metallic = 0.1
		_spike_mat.emission_enabled = true
		_spike_mat.emission = Color(0.35, 0.65, 0.95)
		_spike_mat.emission_energy_multiplier = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = _spike_mesh
	mi.material_override = _spike_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.world.add_child(mi)
	mi.rotation.x = PI
	mi.position = Vector3(at.x, 11.0, at.z)
	var t := mi.create_tween()
	t.tween_property(mi, "position:y", 1.15, delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return mi


func _tick_gale(dt: float, ai: float) -> void:
	var hero = h.hero
	if _gale_left > 0.0:
		_gale_left -= dt
		hero.knock += _gale_dir * float(GALE["accel"]) * (0.6 if ai < 1.0 else 1.0) * dt
		_puff_t -= dt
		if _puff_t <= 0.0 and not h.low:
			_puff_t = 0.12
			var side := Vector3(-_gale_dir.z, 0, _gale_dir.x) * randf_range(-5.0, 5.0)
			h.fx.puff(hero.flat_pos() - _gale_dir * 6.0 + side, Color(0.95, 0.98, 1.0, 0.55), 2, 0.3, 9.0)
		return
	if _gale_warn > 0.0:
		_gale_warn -= dt
		if _gale_warn <= 0.0:
			_gale_left = float(GALE["dur"])
			Sfx.play("charge", -10.0, 0.6)
		return
	_gale_t -= dt
	if _gale_t <= 0.0:
		_gale_t = maxf(float(GALE["every"]) - float(GALE["every_ai"]) * ai, float(GALE["min"])) * randf_range(0.9, 1.1)
		_gale_dir = Actor.dir_of(randi_range(0, 3) * PI * 0.5 + PI * 0.25)
		_gale_warn = float(GALE["warn"])
		h.fx.text(hero.flat_pos() + Vector3(0, 0, -1.2), "Cold snap", FROST, 0.9, 1.4)
		h.tip("gale", "A gale shoves you across the ice: brace and dash against it", "whirlwind")


# --- The Burning Swamp --------------------------------------------------------

func _marsh_fire(n: int) -> void:
	var hero = h.hero
	for i in n:
		var at: Vector3 = h.arena.resolve(hero.flat_pos() + Actor.dir_of(randf() * TAU) * randf_range(1.5, 5.5), 0.4)
		_marsh_at(at)
	h.tip("marsh", "The marsh gas ignites near you: step off the glow", "campfire")


func _marsh_at(at: Vector3) -> void:
	var r := float(MARSH["r"])
	var delay := float(MARSH["delay"])
	h.fx.telegraph(0, at, 0.0, Vector2(r, 0), delay, 0.6, &"fire")
	h.fx.embers_at(at, FIRE, 5, r * 0.6)
	h.get_tree().create_timer(delay, false).timeout.connect(func():
		if not is_instance_valid(h) or h._ended or h._warming:
			return
		h.add_fire_patch(at, r, float(MARSH["dur"]), float(MARSH["dps"]) * _scale()))


func _tick_vents(dt: float, pace: float, ai: float) -> void:
	var hp: Vector3 = h.hero.flat_pos()
	for v: Dictionary in vents:
		if hp.distance_to(v["pos"]) > 34.0:
			continue
		v["t"] -= dt * pace
		if v["t"] > 0.0:
			continue
		v["t"] = maxf(float(VENT["every"]) - float(VENT["every_ai"]) * ai, float(VENT["min"])) * randf_range(0.85, 1.15)
		_vent_burst(v["pos"])


func _vent_burst(at: Vector3) -> void:
	var r := float(VENT["r"])
	var warn := float(VENT["warn"])
	h.fx.telegraph(0, at, 0.0, Vector2(r, 0), warn, 0.7, &"fire")
	h.fx.embers_at(at, FIRE, 6, r * 0.7)
	h.tip("vents", "Methane vents flare when they glow: stay off them", "fire-breath")
	h.get_tree().create_timer(warn, false).timeout.connect(func():
		if not is_instance_valid(h) or h._ended or h._warming:
			return
		h.fx.flame_burst(at, r, true, FIRE, &"skill")
		Sfx.play("boom", -9.0, 1.1)
		h.world_hit(at, r + 0.8, 1.2)
		for f in h.foes_near(at, r):
			h.damage_foe(f, 38.0, h.hero, Vector3.ZERO, 0.0)
		if h.hero.alive and h.hero.flat_pos().distance_to(at) < r + h.hero.radius * 0.5:
			h.damage_hero(float(VENT["dmg"]) * _scale(), null, 0.5)
		h.add_fire_patch(at, r * 0.9, 3.5, PATCH_DPS["fire"] * _scale()))


## Idle bubbling at the vents in view (skipped on Low quality).
func ambient(dt: float) -> void:
	if h.low or vents.is_empty():
		return
	_idle_t -= dt
	if _idle_t > 0.0:
		return
	_idle_t = 1.4
	var hp: Vector3 = h.hero.flat_pos()
	for v: Dictionary in vents:
		if hp.distance_to(v["pos"]) < 16.0:
			h.fx.embers_at(v["pos"], FIRE, 1, 0.5)


# --- Riders, leavings and deaths ------------------------------------------------

## A foe's blow landed on the hero (called from damage_hero).
func rider(e: Node) -> void:
	var hero = h.hero
	match str(e.def.get("rider", "")):
		"chill":
			hero.slow_t = maxf(hero.slow_t, 1.4)
			h.fx.vfx.impact(&"frost", hero.flat_pos(), 0.7, NO_TINT, &"light")
		"scorch":
			h.add_fire_patch(hero.flat_pos(), 1.1, 2.5, 5.0 * _scale())


## What a caster's blast or a slam leaves where it lands (`leave` in the def).
func leave(e: Node, at: Vector3) -> void:
	if not _can_leave():
		return
	match str(e.def.get("leave", "")):
		"frost":
			h.add_fire_patch(at, 1.5, 4.0, PATCH_DPS["frost"] * _scale(), &"frost", true)
		"fire":
			h.add_fire_patch(at, 1.4, 4.0, PATCH_DPS["fire"] * _scale())


## A lunging foe sheds a small patch under itself (`trail` in the def).
func trail(e: Node) -> void:
	if not _can_leave():
		return
	match str(e.def.get("trail", "")):
		"frost":
			h.add_fire_patch(e.flat_pos(), 0.9, 2.5, PATCH_DPS["frost"] * _scale(), &"frost", true)
		"fire":
			h.add_fire_patch(e.flat_pos(), 0.9, 2.5, 5.0 * _scale())


## A body that was killed (hp <= 0): `death` in its def.
func on_death(f: Node) -> void:
	if not _can_leave():
		return
	var at: Vector3 = f.flat_pos()
	match str(f.def.get("death", "")):
		"shatter":
			h.blast_at(at, 2.4, 0.7, 14.0 * _scale(), "slow", FROST, 0.3)
		"ignite":
			h.add_fire_patch(at, 1.3, 3.0, 5.0 * _scale())


func _can_leave() -> bool:
	return not h._warming and h.hero.alive and (h.phase == "rise" or h.phase == "boss")
