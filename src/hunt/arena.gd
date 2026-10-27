class_name Arena
extends Node3D
## The Barrow: a walled graveyard at night. Builds the ground, the props, the
## lights, the mist and the collision (circles on a grid). The layout is fixed
## so it can be learned; small dressing is random per hunt.

const G := "res://assets/kaykit/graveyard/"
const F := "res://assets/kaykit/forest/"
const D := "res://assets/kaykit/dungeon/"
const GROUND_SHADER := preload("res://src/fx/ground.gdshader")
const SMOKE := preload("res://src/fx/smoke.gdshader")
const SOFT := preload("res://src/fx/soft.gdshader")
const EARTH := preload("res://src/fx/earth.gdshader")

## Playfield bounds on XZ.
var min_x := -21.0
var max_x := 21.0
var min_z := -31.0
var max_z := 21.0
var start := Vector3(0, 0, 15)
var crypt_pos := Vector3(0, 0, -26.5)
var boss_spawn := Vector3(0, 0, -21.0)
var graves: Array[Vector3] = []
var lights: Array[OmniLight3D] = []
var env: Environment
var sun: DirectionalLight3D
var low := false
## Set for the Long Road: {"rooms": [...], "boss_z", "boss_gate", "length"}.
var trial: Dictionary = {}
## The atmosphere (mist, motes) trails this node on a long map.
var follow: Node3D
var follow_radius := 0.0
var _mist: GPUParticles3D
var _motes: GPUParticles3D
var _grass_mm: MultiMesh
var _grass_n := 0
var zone := "barrow"
var zone_env: Dictionary
## [{"pos": Vector3 (stand here), "light": OmniLight3D}] for the three shrines.
var shrines: Array = []
## Tall props that can stand between the camera and a fighter. Each entry:
## {"meshes": Array[MeshInstance3D], "x", "z", "r", "h", "t"} — faded by
## update_occlusion() while they cover the hero or the boss.
var occluders: Array = []
## Every prop put() placed: {path, pos, yaw, scale, block} (the collision audit reads it).
var props: Array = []

var _obs: Array = [] # [Vector2 center, radius]
var _grid := {}
const CELL := 4.0
## Steps from the hero over a 1 m grid, so a foe behind a wall can walk round
## it instead of pressing into it. Kept within FLOW_STEPS of the hero and
## rebuilt a slice per frame into a back buffer, so no frame pays for all of it.
const FLOW_STEPS := 40
const FLOW_N := FLOW_STEPS * 2 + 1
const FLOW_EVERY := 0.25
const FLOW_BUDGET := 250
const FLOW_CLEAR := 0.45
const FLOW_FAR := 1 << 20
var _flow := PackedInt32Array() # FLOW_N * FLOW_N steps, FLOW_FAR when unreached
var _flow_o := Vector2i.ZERO # cell at the window's corner
var _fb := PackedInt32Array() # the one being built
var _fb_o := Vector2i.ZERO
var _fq := PackedInt32Array()
var _fq_head := 0
var _fq_tail := 0
var _flow_t := 0.0
var _open := PackedByteArray() # per arena cell: 0 unknown, 1 open, 2 blocked; reset when a gate moves
const GATE_ALPHA := 0.55
var _rng := RandomNumberGenerator.new()
var _aabbs := {}
var _path_img: Image
var _path_tex: ImageTexture
const PATH_RECT := Rect2(-30, -40, 60, 70)


## Content-pack layouts are preloaded by path (no class_name; see tests).
const VaultLayout := preload("res://src/hunt/arena_vault.gd")
const PropShapes := preload("res://src/hunt/prop_shapes.gd")
const Life := preload("res://src/hunt/arena_life.gd")

## The living-world layer (grass wind, footprints, reactive props, critters).
var life: RefCounted
## Baked prop node -> its [MultiMesh, index, transform] slots, so a baked prop can still wobble.
var baked_slots := {}


func build(low_quality := false, zone_id := "barrow", trial_rooms := 0, trial_seed := 1) -> void:
	low = low_quality
	zone = zone_id
	zone_env = DB.zone(zone_id)["env"]
	_rng.seed = 7331
	life = Life.new(self)
	_environment()
	if trial_rooms > 0:
		TrialLayout.build(self, trial_seed, trial_rooms)
	elif zone_id == "depths":
		DepthsLayout.build(self)
	elif zone_id == "vault":
		VaultLayout.build(self)
	elif zone_id == "grove":
		_paths()
		_ground()
		GroveLayout.build(self)
	else:
		_paths()
		_ground()
		_layout()
	_atmosphere()
	if low:
		set_low(true)
	bake_statics()
	life.setup(trial_rooms == 0 and (zone_id == "barrow" or zone_id == "grove"))


# --- Static batching -----------------------------------------------------

## Props placed with put(), for bake_statics().
var _put_nodes: Array[Node3D] = []
## Size of a batching cell: big enough to merge a grove of trees into one draw,
## small enough that cells off screen are still frustum-culled.
const BAKE_CELL := 24.0


## Folds every prop mesh that never changes into one MultiMesh per (mesh,
## material, shadow, cell): a forest of 30 pines becomes one draw instead of
## 30, and the same again in the shadow pass. Props that fade when they hide
## the fight (occluders) keep their own nodes, as their transparency moves.
func bake_statics() -> void:
	var skip := {}
	for o in occluders:
		for mi in o["meshes"]:
			skip[mi] = true
	var groups := {}
	var owner_of := {}
	for n in _put_nodes:
		if not is_instance_valid(n):
			continue
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.visible or mi.skin != null:
				continue
			var fading := skip.has(mi)
			var mat: Material = mi.material_override
			var surf_over := false
			for si in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(si) != null:
					surf_over = true
			if surf_over or mi.transparency > 0.0:
				continue
			# A prop that fades keeps its own visible mesh, but its shadow
			# (which does not fade) batches with its neighbours'.
			if fading and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var xf := n.transform * _local_to(n, mi)
			var cell := Vector2i(floori(xf.origin.x / BAKE_CELL), floori(xf.origin.z / BAKE_CELL))
			var sh := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if fading else mi.cast_shadow
			var key := [mi.mesh.get_rid(), mat.get_rid() if mat else RID(), sh, cell]
			if not groups.has(key):
				groups[key] = {"mesh": mi.mesh, "mat": mat, "shadow": sh, "list": []}
			groups[key]["list"].append([mi, xf])
			owner_of[mi] = n
	for key in groups:
		var g: Dictionary = groups[key]
		var list: Array = g["list"]
		if list.size() < 2:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = g["mesh"]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][1])
			baked_slots.get_or_add(owner_of[list[i][0]], []).append([mm, i, list[i][1]])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Baked"
		mmi.multimesh = mm
		mmi.material_override = g["mat"]
		mmi.cast_shadow = g["shadow"]
		add_child(mmi)
		for e in list:
			var mi: MeshInstance3D = e[0]
			if g["shadow"] == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mi.get_parent().remove_child(mi)
				mi.free()


## A child's transform relative to `root`, for nodes not yet in the tree.
func _local_to(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != root and c is Node3D:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


# --- Environment ---------------------------------------------------------

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = zone_env["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = zone_env["ambient"]
	env.ambient_light_energy = zone_env["ambient_e"]
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = zone_env["fog"]
	env.fog_density = zone_env["fog_d"]
	env.fog_sky_affect = 0.0
	env.fog_height = 0.4
	env.fog_height_density = 0.06
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	if not low:
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.6
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = zone_env["sun"]
	sun.light_energy = zone_env["sun_e"]
	sun.rotation_degrees = zone_env["sun_rot"]
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	# One orthogonal split: two splits drew every caster twice. The top-down
	# camera sees ~30 m, so one 30 m map keeps the same texel density.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 1.5
	add_child(sun)


# --- Ground --------------------------------------------------------------

func _paths() -> void:
	var w := 160
	var h := 186
	_path_img = Image.create(w, h, false, Image.FORMAT_L8)
	var segs := [
		[Vector2(0, 24), Vector2(0, 8)],
		[Vector2(0, 8), Vector2(1.5, -6)],
		[Vector2(1.5, -6), Vector2(0, -22)],
		[Vector2(-17, -5), Vector2(1.5, -6)],
		[Vector2(1.5, -6), Vector2(18, -3)],
		[Vector2(0, 8), Vector2(-9, 2)],
		[Vector2(0, 8), Vector2(10, 4)],
	]
	for y in h:
		for x in w:
			var p := Vector2(PATH_RECT.position.x + (x + 0.5) / w * PATH_RECT.size.x, PATH_RECT.position.y + (y + 0.5) / h * PATH_RECT.size.y)
			var best := 99.0
			for s in segs:
				best = minf(best, _seg_dist(p, s[0], s[1]))
			# A wider trodden clearing in the middle and before the crypt.
			best = minf(best, maxf(p.distance_to(Vector2(1, -5)) - 4.5, 0.0))
			best = minf(best, maxf(p.distance_to(Vector2(0, -19)) - 3.0, 0.0))
			var v := clampf(1.0 - (best - 0.8) / 1.6, 0.0, 1.0)
			_path_img.set_pixel(x, y, Color(v, v, v))
	_path_tex = ImageTexture.create_from_image(_path_img)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func on_path(p: Vector3) -> float:
	if _path_img == null:
		return 0.0
	var u := (p.x - PATH_RECT.position.x) / PATH_RECT.size.x
	var v := (p.z - PATH_RECT.position.y) / PATH_RECT.size.y
	if u < 0 or u >= 1 or v < 0 or v >= 1:
		return 0.0
	return _path_img.get_pixel(int(u * _path_img.get_width()), int(v * _path_img.get_height())).r


func _ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(150, 150)
	mi.mesh = pm
	mi.position = Vector3(0, 0, -5)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("noise_a", _noise(256, 0.012, 1))
	m.set_shader_parameter("noise_b", _noise(256, 0.05, 2))
	m.set_shader_parameter("path_mask", _path_tex)
	m.set_shader_parameter("path_rect", Vector4(PATH_RECT.position.x, PATH_RECT.position.y, PATH_RECT.size.x, PATH_RECT.size.y))
	m.set_shader_parameter("bounds", Vector4(min_x - 1.0, min_z - 1.0, max_x + 1.0, max_z + 1.0))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _noise(size: int, freq: float, seed_: int) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	nt.width = size
	nt.height = size
	nt.seamless = true
	nt.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.seed = seed_
	fn.frequency = freq
	fn.fractal_octaves = 4
	nt.noise = fn
	return nt


# --- Props ---------------------------------------------------------------

## Collision comes from the model's PropShapes policy (a box, a circle or
## none), sized from its baked footprint. `block` no longer sizes it: > 0 only
## says the prop is solid enough to fade when it hides the hero.
## `occlude` > 0 marks the prop as view-blocking: its footprint radius in
## metres at scale 1 (the prop fades while it hides the hero).
func put(path: String, pos: Vector3, yaw := 0.0, scale_ := 1.0, block := -1.0, shadow := true, occlude := 0.0) -> Node3D:
	var n := KK.prop(path)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale_
	add_child(n)
	_put_nodes.append(n)
	var shape := PropShapes.shape_for(path, yaw, scale_)
	props.append({"path": path, "pos": pos, "yaw": yaw, "scale": scale_, "shape": shape[0], "obs": -1})
	if shape[0] != "walk" and pos.y < 0.5:
		var c: Vector2 = Vector2(pos.x, pos.z) + shape[1]
		var half: Vector2 = shape[2]
		# Out past the bounds (the forest round the wall) nothing can reach it.
		var reach := half.length()
		if c.x + reach > min_x - 1.0 and c.x - reach < max_x + 1.0 and c.y + reach > min_z - 1.0 and c.y - reach < max_z + 1.0:
			props[-1]["obs"] = _obs.size()
			if shape[0] == "box":
				add_box(c, half, yaw)
			else:
				add_obstacle(c, half.x)
	# Ground clutter (bones, candles, grass tufts) lower than a shin casts a
	# shadow too small to read but costs a draw in the shadow pass.
	if shadow and size_of(path).y * scale_ < 0.45:
		shadow = false
	if not shadow:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Anything solid and taller than the hero's waist can hide the fight: it
	# fades too, without every caller having to say so.
	if occlude <= 0.0 and block > 0.0 and size_of(path).y * scale_ > 1.2:
		occlude = block + 0.3
	if occlude > 0.0:
		var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			occluders.append({"meshes": meshes, "x": pos.x, "z": pos.z, "r": occlude * scale_, "h": size_of(path).y * scale_, "t": 0.0})
	return n


var _earth_mat: ShaderMaterial


## A ragged round patch of turned soil lying on the ground.
func earth_patch(pos: Vector3, radius: float) -> void:
	if _earth_mat == null:
		_earth_mat = ShaderMaterial.new()
		_earth_mat.shader = EARTH
		_earth_mat.render_priority = -2
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	mi.material_override = _earth_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.03, 0)
	mi.rotation.y = _rng.randf() * TAU
	mi.scale = Vector3(radius, 1, radius)
	mi.set_instance_shader_parameter("seed", _rng.randf() * 40.0)
	add_child(mi)


## A moving occluder (the boss): same fade, position read from the node.
func add_dynamic_occluder(node: Node3D, r: float, h: float, fade := 0.4) -> void:
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	occluders.append({"meshes": meshes, "node": node, "x": 0.0, "z": 0.0, "r": r, "h": h, "t": 0.0, "fade": fade})


## Fades props that sit between the camera (south, +Z) and any of `points`.
## A prop of height h covers the ground up to h / tan(pitch) north of itself.
func update_occlusion(points: Array, pitch_deg: float, dt: float) -> void:
	var reach := 1.0 / tan(deg_to_rad(clampf(pitch_deg, 25.0, 80.0)))
	for o in occluders:
		var want := 0.0
		var self_node: Node3D = o.get("node")
		if self_node != null:
			if not is_instance_valid(self_node):
				continue
			o["x"] = self_node.position.x
			o["z"] = self_node.position.z
		for i in points.size():
			var q: Vector3 = points[i]
			if self_node != null and q.distance_squared_to(self_node.position) < 0.01:
				continue
			var dz: float = o["z"] - q.z
			var dx: float = absf(o["x"] - q.x)
			if dz > -float(o["r"]) * 0.6 and dz < float(o["h"]) * reach + float(o["r"]) and dx < float(o["r"]) + 0.6:
				want = float(o.get("fade", 0.72))
				break
			# Props in the band between the hero and the camera fill the bottom
			# of the screen: half-fade them so the ground around the hero shows.
			if i == 0 and self_node == null and dz > 1.5 and dz < 10.0 and dx < 5.5 and float(o["h"]) > 1.2:
				want = maxf(want, 0.5)
		var t: float = o["t"]
		var nt := move_toward(t, want, dt * 4.0)
		if absf(nt - t) > 0.004:
			o["t"] = nt
			for mi: MeshInstance3D in o["meshes"]:
				mi.transparency = nt


func size_of(path: String) -> Vector3:
	if not _aabbs.has(path):
		var n := KK.prop(path)
		var box := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		_aabbs[path] = box.size
		n.free()
	return _aabbs[path]


func add_obstacle(c: Vector2, r: float) -> void:
	_file_obstacle([c, r], r)


## An oriented rectangle: centre, half extents along the prop's own X and Z,
## and its yaw. Stored as [c, bounding r, half, cos, sin].
func add_box(c: Vector2, half: Vector2, yaw: float) -> void:
	_file_obstacle([c, half.length(), half, cos(yaw), sin(yaw)], half.length())


## A blow at `pos`: props nearby wobble and beetles scatter. Returns the
## positions of props hit hard enough to shed dust.
func nudge(pos: Vector3, radius: float, power: float) -> Array:
	return life.nudge(pos, radius, power)


## Once a frame: wind and trampling on the grass, footprints, critters.
func tick_life(dt: float, hero_pos: Vector3, hero_vel: Vector3, hero_alive: bool, foes: Array) -> void:
	life.tick(dt, hero_pos, hero_vel, hero_alive, foes)


## The nearest point of obstacle `o` to `q`, and whether `q` is inside it.
static func _nearest(o: Array, q: Vector2) -> Array:
	var c: Vector2 = o[0]
	var d := q - c
	if o.size() < 5:
		var l := d.length()
		var r: float = o[1]
		return [c + (d / l if l > 0.001 else Vector2(1, 0)) * r, l < r]
	var half: Vector2 = o[2]
	var cs: float = o[3]
	var sn: float = o[4]
	# Into the box's frame (node yaw turns +X toward -Z).
	var lx := d.x * cs - d.y * sn
	var lz := d.x * sn + d.y * cs
	var inside := absf(lx) < half.x and absf(lz) < half.y
	var nx := clampf(lx, -half.x, half.x)
	var nz := clampf(lz, -half.y, half.y)
	if inside:
		# Out through the nearest face.
		if half.x - absf(lx) < half.y - absf(lz):
			nx = half.x * signf(lx if lx != 0.0 else 1.0)
		else:
			nz = half.y * signf(lz if lz != 0.0 else 1.0)
	return [c + Vector2(nx * cs + nz * sn, -nx * sn + nz * cs), inside]


func _file_obstacle(o: Array, r: float) -> void:
	var idx := _obs.size()
	_obs.append(o)
	var c: Vector2 = o[0]
	var x0 := int(floor((c.x - r) / CELL))
	var x1 := int(floor((c.x + r) / CELL))
	var z0 := int(floor((c.y - r) / CELL))
	var z1 := int(floor((c.y + r) / CELL))
	for gx in range(x0, x1 + 1):
		for gz in range(z0, z1 + 1):
			var k := Vector2i(gx, gz)
			if not _grid.has(k):
				_grid[k] = []
			_grid[k].append(idx)


func blocked(p: Vector3, r: float) -> bool:
	var k := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
	# Neighbouring cells too: an obstacle is filed only under the cells its own
	# circle covers, but `r` reaches past them near a cell's edge.
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for idx in _grid.get(Vector2i(k.x + dx, k.y + dz), []):
				var o: Array = _obs[idx]
				var q := Vector2(p.x, p.z)
				if q.distance_to(o[0]) >= float(o[1]) + r:
					continue
				if o.size() < 5:
					return true
				var hit: Array = _nearest(o, q)
				if hit[1] or q.distance_to(hit[0]) < r:
					return true
	return p.x < min_x or p.x > max_x or p.z < min_z or p.z > max_z


## Carries on building the step field toward `target`; starts a new one
## FLOW_EVERY seconds after the last was done.
func update_flow(target: Vector3, dt: float) -> void:
	if _flow.is_empty():
		_flow.resize(FLOW_N * FLOW_N)
		_flow.fill(FLOW_FAR)
		_fb.resize(FLOW_N * FLOW_N)
		_fq.resize(FLOW_N * FLOW_N)
	if _open.is_empty():
		# Fill the whole grid once, at the start, so the hunt never pays for it.
		_open.resize(_arena_w() * (int(max_z - min_z) + 3))
		for cz in range(floori(min_z) - 1, ceili(max_z) + 2):
			for cx in range(floori(min_x) - 1, ceili(max_x) + 2):
				_passable(cx, cz)
	if _fq_head >= _fq_tail:
		_flow_t -= dt
		if _flow_t > 0.0:
			return
		_flow_t = FLOW_EVERY
		_fb.fill(FLOW_FAR)
		_fb_o = Vector2i(roundi(target.x) - FLOW_STEPS, roundi(target.z) - FLOW_STEPS)
		var start := FLOW_STEPS * FLOW_N + FLOW_STEPS
		_fb[start] = 0
		_fq[0] = start
		_fq_head = 0
		_fq_tail = 1
	var budget := FLOW_BUDGET
	while _fq_head < _fq_tail and budget > 0:
		budget -= 1
		var i := _fq[_fq_head]
		_fq_head += 1
		var d := _fb[i] + 1
		if d > FLOW_STEPS:
			continue
		var x := i % FLOW_N
		var z := i / FLOW_N
		if x + 1 < FLOW_N:
			_flow_visit(i + 1, x + 1, z, d)
		if x > 0:
			_flow_visit(i - 1, x - 1, z, d)
		if z + 1 < FLOW_N:
			_flow_visit(i + FLOW_N, x, z + 1, d)
		if z > 0:
			_flow_visit(i - FLOW_N, x, z - 1, d)
	if _fq_head >= _fq_tail:
		var t := _flow
		_flow = _fb
		_fb = t
		_flow_o = _fb_o


func _flow_visit(ni: int, nx: int, nz: int, d: int) -> void:
	if _fb[ni] != FLOW_FAR or not _passable(_fb_o.x + nx, _fb_o.y + nz):
		return
	_fb[ni] = d
	_fq[_fq_tail] = ni
	_fq_tail += 1


func _arena_w() -> int:
	return int(max_x - min_x) + 3


func _open_idx(cx: int, cz: int) -> int:
	var ax := cx - int(floor(min_x)) + 1
	var az := cz - int(floor(min_z)) + 1
	var w := _arena_w()
	if ax < 0 or az < 0 or ax >= w or az * w + ax >= _open.size():
		return -1
	return az * w + ax


func _passable(cx: int, cz: int) -> bool:
	var k := _open_idx(cx, cz)
	if k < 0:
		return false
	if _open[k] == 0:
		_open[k] = 2 if blocked(Vector3(cx, 0, cz), FLOW_CLEAR) else 1
	return _open[k] == 1


func _flow_at(cx: int, cz: int) -> int:
	var x := cx - _flow_o.x
	var z := cz - _flow_o.y
	if x < 0 or z < 0 or x >= FLOW_N or z >= FLOW_N or _flow.is_empty():
		return FLOW_FAR
	return _flow[z * FLOW_N + x]


## The way to walk from `p` to get nearer the hero round walls, or zero when
## `p` is outside the field.
func flow_dir(p: Vector3) -> Vector3:
	var cx := roundi(p.x)
	var cz := roundi(p.z)
	var best := mini(_flow_at(cx, cz), FLOW_STEPS + 1)
	var to := Vector2i(cx, cz)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var v := _flow_at(cx + dx, cz + dz)
			# No cutting a corner past a blocked cell.
			if dx != 0 and dz != 0 and (_flow_at(cx + dx, cz) == FLOW_FAR or _flow_at(cx, cz + dz) == FLOW_FAR):
				continue
			if v < best:
				best = v
				to = Vector2i(cx + dx, cz + dz)
	if to == Vector2i(cx, cz):
		return Vector3.ZERO
	var d := Vector3(to.x - p.x, 0, to.y - p.z)
	return d / maxf(d.length(), 0.01)


## Pushes a position out of every obstacle and back inside the bounds.
func resolve(p: Vector3, r: float) -> Vector3:
	var q := Vector2(clampf(p.x, min_x + r, max_x - r), clampf(p.z, min_z + r, max_z - r))
	var k := Vector2i(int(floor(q.x / CELL)), int(floor(q.y / CELL)))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for idx in _grid.get(Vector2i(k.x + dx, k.y + dz), []):
				var o: Array = _obs[idx]
				var c: Vector2 = o[0]
				if q.distance_to(c) >= float(o[1]) + r:
					continue
				if o.size() < 5:
					var d := q - c
					var l := d.length()
					q = c + (d / l if l > 0.001 else Vector2(1, 0)) * (float(o[1]) + r)
					continue
				var hit: Array = _nearest(o, q)
				var np: Vector2 = hit[0]
				var away := q - np
				var al := away.length()
				if hit[1]:
					# Inside: out through the face, then the walker's radius on.
					var n := (np - q) / maxf(al, 0.001)
					q = np + n * r
				elif al < r:
					q = np + away / maxf(al, 0.001) * r
	return Vector3(q.x, p.y, q.y)


func _layout() -> void:
	# The crypt: the King's lair at the north end.
	put(G + "crypt.gltf", crypt_pos, 0.0, 1.9, -1.0, true, 2.4)
	var cl := _light(crypt_pos + Vector3(0, 2.5, 3.6), Color(0.35, 1.0, 0.75), 2.6, 9.0, false)
	cl.set_meta("flicker", 0.15)
	put(G + "post_skull.gltf", crypt_pos + Vector3(-4.6, 0, 3.2), 0.0, 1.3, 0.3, true, 0.8)
	put(G + "post_skull.gltf", crypt_pos + Vector3(4.6, 0, 3.2), 0.0, 1.3, 0.3, true, 0.8)
	put(G + "pillar.gltf", crypt_pos + Vector3(-6.5, 0, 4.5), 0.0, 1.4, 0.5, true, 1.0)
	put(G + "pillar.gltf", crypt_pos + Vector3(6.5, 0, 4.5), 0.0, 1.4, 0.5, true, 1.0)

	# Perimeter: iron fence with stone pillars; the gate at the south.
	_fence_line(Vector3(min_x - 0.6, 0, max_z + 0.6), Vector3(-3.2, 0, max_z + 0.6))
	_fence_line(Vector3(3.2, 0, max_z + 0.6), Vector3(max_x + 0.6, 0, max_z + 0.6))
	_fence_line(Vector3(min_x - 0.6, 0, min_z - 0.6), Vector3(max_x + 0.6, 0, min_z - 0.6))
	_fence_line(Vector3(min_x - 0.6, 0, min_z - 0.6), Vector3(min_x - 0.6, 0, max_z + 0.6))
	_fence_line(Vector3(max_x + 0.6, 0, min_z - 0.6), Vector3(max_x + 0.6, 0, max_z + 0.6))
	put(G + "arch_gate.gltf", Vector3(0, 0, max_z + 0.6), 0.0, 1.6, -1.0, true, 3.0)
	_light(Vector3(-3.4, 2.2, max_z - 0.6), Color(1.0, 0.6, 0.3), 1.6, 7.0)
	put(G + "lantern_standing.gltf", Vector3(-3.4, 0, max_z - 0.6), 0.0, 1.3, 0.3, true, 0.6)
	put(G + "lantern_standing.gltf", Vector3(3.4, 0, max_z - 0.6), 0.0, 1.3, 0.3, true, 0.6)

	# Grave plots: rows of headstones with open graves the dead climb out of.
	_plot(Vector3(-12, 0, 8), 3, 4, 0.0)
	_plot(Vector3(11, 0, 10), 3, 3, 0.0)
	_plot(Vector3(-12.5, 0, -14), 4, 3, 0.0)
	_plot(Vector3(12, 0, -14), 4, 3, 0.0)
	_plot(Vector3(-6, 0, -24), 2, 2, 0.0)
	_plot(Vector3(8, 0, -24), 2, 2, 0.0)

	# The shrine and benches by the cross path.
	for sp in [[Vector3(17.5, 0, -6), -PI * 0.5], [Vector3(-17.5, 0, 6.0), PI * 0.5], [Vector3(17.5, 0, 9.0), -PI * 0.5]]:
		var at: Vector3 = sp[0]
		put(G + "shrine_candles.gltf", at, sp[1], 1.4, 1.0, true, 1.2)
		var inward := -signf(at.x)
		var sl := _light(at + Vector3(inward * 1.0, 1.6, 0), Color(1.0, 0.65, 0.3), 1.6, 6.5)
		shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})
	put(G + "bench_decorated.gltf", Vector3(-6, 0, -9.6), 0.0, 1.3, 0.7)
	put(G + "bench.gltf", Vector3(7, 0, -10), 0.2, 1.3, 0.7)
	# Lanterns along the paths.
	for lp in [Vector3(-2.6, 0, 9), Vector3(4.2, 0, -1.5), Vector3(-5, 0, -2), Vector3(2.8, 0, -17)]:
		put(G + "post_lantern.gltf", lp, _rng.randf() * TAU, 1.35, 0.3, true, 0.6)
		_light(lp + Vector3(0, 2.4, 0), Color(1.0, 0.62, 0.32), 1.5, 7.5)
	# Dead trees inside the walls.
	for tp in [Vector3(-17, 0, -2), Vector3(16, 0, 3), Vector3(-17.5, 0, 17), Vector3(17, 0, 17.5), Vector3(-2, 0, -12.5), Vector3(-18, 0, -27), Vector3(18, 0, -27)]:
		var tn: String = ["tree_dead_large.gltf", "tree_dead_large_decorated.gltf", "tree_dead_medium.gltf"][_rng.randi() % 3]
		put(G + tn, tp, _rng.randf() * TAU, _rng.randf_range(1.3, 1.7), 0.45, true, 1.2)
	# Coffins, skulls and bones lying about.
	for i in 26:
		var p := _free_spot(0.5)
		var bn: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf", "skull.gltf"][_rng.randi() % 6]
		put(G + bn, p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.1), -1.0, false)
	for cp in [Vector3(5.5, 0, 14), Vector3(-15.5, 0, -8), Vector3(14.5, 0, -20)]:
		put(G + ("coffin_decorated.gltf" if _rng.randf() < 0.5 else "coffin.gltf"), cp, _rng.randf() * TAU, 1.3, 0.8)
	# A few jack-o'-lanterns for warm accents.
	for pp in [Vector3(-8.5, 0, 14.5), Vector3(14, 0, -9.5), Vector3(-15, 0, -20)]:
		put(G + "pumpkin_orange_jackolantern.gltf", pp, _rng.randf() * TAU, 1.3, 0.4)
		_light(pp + Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.15), 0.9, 3.5)
	# Rocks.
	for i in 10:
		var rp := _free_spot(1.0)
		var rn := "Rock_%d_%s_Color1.gltf" % [_rng.randi_range(1, 3), "ABCDEFGH"[_rng.randi() % 8]]
		put(F + rn, rp, _rng.randf() * TAU, _rng.randf_range(0.9, 1.5), 0.55)

	_forest()
	_grass()


func _plot(center: Vector3, cols: int, rows: int, yaw: float) -> void:
	var stones := ["gravestone.gltf", "grave_A.gltf", "grave_B.gltf", "gravemarker_A.gltf", "gravemarker_B.gltf", "grave_A_destroyed.gltf"]
	for c in cols:
		for r in rows:
			var p := center + Vector3((c - (cols - 1) * 0.5) * 2.6, 0, (r - (rows - 1) * 0.5) * 2.9)
			p += Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.2, 0.2))
			if _rng.randf() < 0.3:
				# An open grave: dirt mound, and a place the dead rise from.
				put(G + "floor_dirt_grave.gltf", p + Vector3(0, 0.04, 0.5), yaw, 1.05, -1.0, false)
				graves.append(p + Vector3(0, 0, 0.9))
				put(G + "gravemarker_A.gltf", p + Vector3(0, 0, -0.6), yaw + _rng.randf_range(-0.2, 0.2), 1.0, 0.3)
			else:
				var s: String = stones[_rng.randi() % stones.size()]
				put(G + s, p, yaw + _rng.randf_range(-0.25, 0.25), _rng.randf_range(0.95, 1.15), 0.38)
				graves.append(p + Vector3(0, 0, 1.2))
				if _rng.randf() < 0.25:
					put(G + ["candle_triple.gltf", "skull_candle.gltf", "candle_melted.gltf"][_rng.randi() % 3], p + Vector3(0.5, 0, 0.6), 0.0, 1.2, -1.0, false)


func _fence_line(a: Vector3, b: Vector3) -> void:
	var seg := maxf(size_of(G + "fence.gltf").x * 1.4, 1.0)
	var length := a.distance_to(b)
	var n := int(ceil(length / seg))
	var dir := (b - a) / length
	var yaw := atan2(dir.x, dir.z) + PI * 0.5
	for i in n:
		var p := a + dir * (seg * (i + 0.5))
		var broken := _rng.randf() < 0.18
		put(G + ("fence_broken.gltf" if broken else "fence.gltf"), p, yaw, 1.4, -1.0)
		if i % 2 == 0:
			put(G + ("fence_pillar_broken.gltf" if _rng.randf() < 0.2 else "fence_pillar.gltf"), a + dir * (seg * i), yaw, 1.4)


func _forest() -> void:
	# Autumn pines and dark trees outside the wall close the horizon.
	var kinds := [G + "tree_pine_orange_large.gltf", G + "tree_pine_yellow_large.gltf", G + "tree_pine_orange_medium.gltf",
		F + "Tree_1_A_Color1.gltf", F + "Tree_2_A_Color1.gltf", F + "Tree_3_A_Color1.gltf", F + "Tree_Bare_1_A_Color1.gltf", F + "Tree_Bare_2_A_Color1.gltf"]
	var count := 70 if low else 130
	var placed := 0
	var tries := 0
	while placed < count and tries < 2000:
		tries += 1
		var p := Vector3(_rng.randf_range(min_x - 16, max_x + 16), 0, _rng.randf_range(min_z - 14, max_z + 10))
		var inside := p.x > min_x - 2.0 and p.x < max_x + 2.0 and p.z > min_z - 2.0 and p.z < max_z + 2.0
		if inside:
			continue
		# Keep the view south of the gate open-ish.
		if p.z > max_z and absf(p.x) < 5.0:
			continue
		var k: String = kinds[_rng.randi() % kinds.size()]
		var sc := _rng.randf_range(1.6, 2.6) if k.begins_with(G) else _rng.randf_range(1.3, 2.0)
		# Trees by the wall, and every tree on the camera's side (south), fade
		# while they cover the hero: tall pines there hide fights at the edge.
		var near := p.x > min_x - 4.0 and p.x < max_x + 4.0 and p.z > min_z - 4.0 and (p.z < max_z + 4.0 or p.z > max_z)
		put(k, p, _rng.randf() * TAU, sc, -1.0, absf(p.x) < max_x + 6.0 and p.z > min_z - 6.0, 1.2 if near else 0.0)
		placed += 1
	for i in (14 if low else 30):
		var p2 := Vector3(_rng.randf_range(min_x - 8, max_x + 8), 0, _rng.randf_range(min_z - 6, max_z + 6))
		if p2.x > min_x - 1.0 and p2.x < max_x + 1.0 and p2.z > min_z - 1.0 and p2.z < max_z + 1.0:
			continue
		put(F + "Bush_%d_%s_Color1.gltf" % [_rng.randi_range(1, 2), "ABC"[_rng.randi() % 3]], p2, _rng.randf() * TAU, _rng.randf_range(1.2, 1.8), -1.0, false)


func _grass() -> void:
	var src := KK.prop(F + "Grass_1_A_Color1.gltf")
	var mesh: Mesh = null
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		mesh = (mi as MeshInstance3D).mesh
		break
	src.free()
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	# Always laid out at full density; low quality just shows the first part
	# (the scatter is random, so any prefix is an even spread). That lets the
	# Graphics setting switch mid-hunt.
	var want := 1300
	mm.instance_count = want
	var n := 0
	var tries := 0
	while n < want and tries < want * 6:
		tries += 1
		var p := Vector3(_rng.randf_range(min_x - 4, max_x + 4), 0, _rng.randf_range(min_z - 4, max_z + 4))
		if on_path(p) > 0.25 or blocked(p, 0.3) and p.x > min_x and p.x < max_x and p.z > min_z and p.z < max_z:
			continue
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.55, 0.95))
		mm.set_instance_transform(n, Transform3D(b, p))
		var shade := _rng.randf_range(0.55, 0.9)
		mm.set_instance_color(n, Color(shade, shade, shade))
		n += 1
	mm.visible_instance_count = n
	_grass_mm = mm
	_grass_n = n
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var src_mat := mesh.surface_get_material(0)
	if src_mat is BaseMaterial3D:
		mmi.material_override = life.grass_material(src_mat as BaseMaterial3D)
	add_child(mmi)


func _free_spot(r: float) -> Vector3:
	for i in 40:
		var p := Vector3(_rng.randf_range(min_x + 1, max_x - 1), 0, _rng.randf_range(min_z + 4, max_z - 1))
		if not blocked(p, r + 0.4) and on_path(p) < 0.4:
			return p
	return Vector3(_rng.randf_range(min_x, max_x), 0, _rng.randf_range(min_z, max_z))


func _light(pos: Vector3, color: Color, energy: float, range_: float, flicker := true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = range_
	o.omni_attenuation = 1.3
	o.shadow_enabled = false
	o.set_meta("base", energy)
	o.set_meta("flicker", 0.12 if flicker else 0.0)
	o.set_meta("phase", _rng.randf() * 10.0)
	add_child(o)
	lights.append(o)
	return o


# --- Atmosphere ----------------------------------------------------------

## Switches the Graphics setting mid-hunt: ambient occlusion, grass density and
## the mist and firefly counts. (Tree and bush counts are baked at build.)
func set_low(on: bool) -> void:
	low = on
	if env:
		env.ssao_enabled = not on
		if not on:
			env.ssao_radius = 1.2
			env.ssao_intensity = 1.6
	life.set_low(on)
	if _grass_mm:
		_grass_mm.visible_instance_count = int(_grass_n * (500.0 / 1300.0)) if on else _grass_n
	if _mist:
		_mist.amount = 26 if on else 48
	if _motes:
		_motes.amount = 40 if on else 90


func _atmosphere() -> void:
	# Low mist drifting across the graves.
	var mist := GPUParticles3D.new()
	mist.amount = 48
	mist.lifetime = 16.0
	mist.preprocess = 16.0
	mist.local_coords = false
	mist.visibility_aabb = AABB(Vector3(-40, -2, -50), Vector3(80, 10, 90))
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var span_z := minf(max_z - min_z, follow_radius if follow_radius > 0.0 else 1e9)
	pm.emission_box_extents = Vector3((max_x - min_x) * 0.55, 0.2, span_z * 0.55)
	pm.direction = Vector3(1, 0, 0.2)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.color = zone_env["mist"]
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	mist.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(9, 9)
	var sm := ShaderMaterial.new()
	sm.shader = SMOKE
	sm.set_shader_parameter("noise", _noise(128, 0.04, 9))
	q.material = sm
	mist.draw_pass_1 = q
	mist.position = Vector3((min_x + max_x) * 0.5, 0.5, (min_z + max_z) * 0.5)
	add_child(mist)
	_mist = mist
	# Fireflies and grave-wisps.
	var ff := GPUParticles3D.new()
	ff.amount = 90
	ff.lifetime = 6.0
	ff.preprocess = 6.0
	ff.local_coords = false
	ff.visibility_aabb = mist.visibility_aabb
	ff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fm.emission_box_extents = Vector3((max_x - min_x) * 0.5, 1.0, span_z * 0.5)
	fm.direction = Vector3(0, 1, 0)
	fm.spread = 180.0
	fm.initial_velocity_min = 0.1
	fm.initial_velocity_max = 0.4
	fm.gravity = Vector3(0, 0.05, 0)
	fm.turbulence_enabled = true
	fm.turbulence_noise_strength = 0.6
	fm.turbulence_noise_scale = 3.0
	fm.color = zone_env["motes"]
	var fr := Gradient.new()
	fr.set_color(0, Color(1, 1, 1, 0))
	fr.add_point(0.2, Color(1, 1, 1, 1))
	fr.add_point(0.8, Color(1, 1, 1, 0.8))
	fr.set_color(fr.get_point_count() - 1, Color(1, 1, 1, 0))
	var frt := GradientTexture1D.new()
	frt.gradient = fr
	fm.color_ramp = frt
	ff.process_material = fm
	var fq := QuadMesh.new()
	fq.size = Vector2(0.14, 0.14)
	var fmat := ShaderMaterial.new()
	fmat.shader = SOFT
	fmat.set_shader_parameter("intensity", 3.0)
	fq.material = fmat
	ff.draw_pass_1 = fq
	ff.position = Vector3((min_x + max_x) * 0.5, 1.2, (min_z + max_z) * 0.5)
	add_child(ff)
	_motes = ff


func _process(_dt: float) -> void:
	if follow and follow_radius > 0.0 and _mist:
		var fz := follow.position.z
		_mist.position.z = fz
		_motes.position.z = fz
	var t := Time.get_ticks_msec() / 1000.0
	for o in lights:
		var f: float = o.get_meta("flicker")
		if f <= 0.0:
			continue
		var ph: float = o.get_meta("phase")
		var n := sin(t * 9.0 + ph) * 0.5 + sin(t * 23.0 + ph * 2.0) * 0.3 + sin(t * 3.0 + ph) * 0.2
		o.light_energy = float(o.get_meta("base")) * (1.0 + n * f)


# --- Gates and rooms (the Long Road) -----------------------------------------

## A glowing barrier across a gap in a divider. Starts open; `set_gate` closes it.
func add_gate(x0: float, x1: float, z: float) -> Dictionary:
	var ids: Array = []
	var x := x0 + 0.5
	while x <= x1 - 0.4:
		ids.append(_obs.size())
		add_obstacle(Vector2(x, z), 0.9)
		x += 1.0
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(x1 - x0, 3.2)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.5, 1.0, 0.7, GATE_ALPHA)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 0.0))
	gg.set_color(1, Color(1, 1, 1, 1.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = gg
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 8
	gtex.height = 32
	m.albedo_texture = gtex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3((x0 + x1) * 0.5, 1.6, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var radii: Array = []
	for id in ids:
		radii.append(float(_obs[id][1]))
	return {"ids": ids, "radii": radii, "node": mi, "closed": false}


func set_gate(g: Dictionary, closed: bool, instant := false) -> void:
	g["closed"] = closed
	# Only the cells the gate covers change; rechecked when next needed.
	if not _open.is_empty():
		for id: int in g["ids"]:
			var c: Vector2 = _obs[id][0]
			for cx in range(floori(c.x) - 2, floori(c.x) + 4):
				for cz in range(floori(c.y) - 2, floori(c.y) + 4):
					var k := _open_idx(cx, cz)
					if k >= 0:
						_open[k] = 0
	var ids: Array = g["ids"]
	for i in ids.size():
		_obs[ids[i]][1] = float(g["radii"][i]) if closed else -2.0
	var mi: MeshInstance3D = g["node"]
	if instant:
		mi.visible = closed
		return
	mi.visible = true
	var tw := mi.create_tween()
	var m: StandardMaterial3D = mi.material_override
	tw.tween_property(m, "albedo_color:a", GATE_ALPHA if closed else 0.0, 0.4)
	if not closed:
		tw.tween_callback(func(): mi.visible = false)


## The room of a trial (its index) that contains this z, or -1.
func room_at(z: float) -> int:
	for r: Dictionary in trial.get("rooms", []):
		if z <= float(r["hi"]) and z > float(r["lo"]):
			return int(r["index"])
	return trial.get("rooms", []).size() if z <= float(trial.get("boss_z", -1e9)) + 6.0 else -1


## On the Long Road, where to walk to get from `a` toward `b`: `b` itself in
## the same room, else the gap in the divider between a's room and the next
## one toward b (first to its near side, then just past it). Walls between
## rooms are walked around, not pressed against.
func route(a: Vector3, b: Vector3) -> Vector3:
	if trial.is_empty():
		return b
	var rooms: Array = trial["rooms"]
	var ia := room_at(a.z)
	var ib := room_at(b.z)
	if ia < 0 or ib < 0 or ia == ib:
		return b
	var k := ia if ib > ia else ia - 1
	if k < 0 or k >= rooms.size():
		return b
	var r: Dictionary = rooms[k]
	var line := float(r["lo"])
	var ahead := -1.0 if ib > ia else 1.0
	var gx := float(r["gap_x"])
	if absf(a.z - line) > 2.5 or absf(a.x - gx) > 1.6:
		return Vector3(gx, 0, line - ahead * 1.8)
	return Vector3(gx, 0, line + ahead * 1.8)


## A free spot in a room, at least `min_hero` from `hero_pos`.
func room_point(room: Dictionary, hero_pos: Vector3, min_hero := 8.0) -> Vector3:
	for i in 24:
		var p := Vector3(_rng.randf_range(min_x + 3.0, max_x - 3.0), 0, _rng.randf_range(float(room["lo"]) + 4.0, float(room["hi"]) - 3.0))
		if not blocked(p, 0.8) and p.distance_to(hero_pos) >= min_hero:
			return p
	return resolve(Vector3(0, 0, (float(room["hi"]) + float(room["lo"])) * 0.5), 0.8)


## A random point the dead can rise at, near `around` but not on top of it.
func spawn_point(around: Vector3, near: float, far: float) -> Vector3:
	# Prefer graves in the ring.
	var cands := []
	for g in graves:
		var d := g.distance_to(around)
		if d >= near and d <= far:
			cands.append(g)
	if not cands.is_empty() and _rng.randf() < 0.55:
		var g2: Vector3 = cands[_rng.randi() % cands.size()]
		return g2 + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.4, 0.4))
	for i in 30:
		var a := _rng.randf() * TAU
		var d2 := _rng.randf_range(near, far)
		var p := around + Vector3(sin(a), 0, cos(a)) * d2
		if not blocked(p, 0.6):
			return p
	return resolve(around + Vector3(_rng.randf_range(-far, far), 0, -far), 0.6)


## Thin outlines of every collider on the ground, for captures and debugging.
func debug_outlines(color := Color(0.2, 1.0, 0.9)) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for o: Array in _obs:
		var c: Vector2 = o[0]
		var pts: Array[Vector2] = []
		if o.size() < 5:
			var r: float = o[1]
			if r <= 0.0:
				continue
			for i in 20:
				pts.append(c + Vector2(cos(TAU * i / 20.0), sin(TAU * i / 20.0)) * r)
		else:
			var h: Vector2 = o[2]
			var cs: float = o[3]
			var sn: float = o[4]
			for l: Vector2 in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
				pts.append(c + Vector2(l.x * cs + l.y * sn, -l.x * sn + l.y * cs))
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			im.surface_add_vertex(Vector3(a.x, 0.08, a.y))
			im.surface_add_vertex(Vector3(b.x, 0.08, b.y))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
