class_name Stage3D
extends Control

## The hunt and the home pedestal, drawn in 3D. The simulation stays on the
## flat playfield. This view follows it with a tilted camera.

const SCALE := 0.02
const PITCH := 0.907571  # 52 degrees: Diablo-style tilt so faces and silhouettes read
## The follow camera sits far back so two or three camps of forest are on
## screen and a camp shows well before the hero reaches it.
const DIST := 65.0
const FOV := 40.0
const BOSS_DIST := 79.0
## Aim a metre above the ground so the hero sits just below screen centre,
## leaving room to see what comes from above.
const AIM := 1.5
## On-screen size targets. With the camera at DIST these put the hero near
## 10% of the screen height; the boss stands about 3x the hero's footprint.
const HERO_METERS := 3.6
const PEDESTAL_TOP := 0.34
const HERO_BOOST := 1.18
## Screen fraction (from the top) the boss's cap must stay below: the bottom
## of the boss bar plus a margin.
const BOSS_TOP_LIMIT := 0.185
const BOSS_METERS := 14.5
## Highest render density over the logical canvas (device px per canvas px).
const MAX_DENSITY := 1.65

var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var _boss_shift := 0.0
var _ped_focus := Vector3.ZERO
var _ped_dir := Vector3.BACK
var _ped_dist := 0.0
var world_root: Node3D
var actor_root: Node3D
var _look := Vector3.ZERO
var _ready_cam := false
var _shake := Vector3.ZERO
var _dist := DIST
var _bodies: Dictionary = {}
var _fx: Dictionary = {}
var _biome := "meadow"
var _mode := "hunt"
var _hero_id := "ember"
var _pedestal_hero: Node3D
## Procedural wing pairs to flap each frame: {"l": Node3D, "r": Node3D, "body": Node3D}.
var _wing_sets: Array = []
var _pet: Node3D
var _pet_ready := false
var _dust: GPUParticles3D
var _sparks: Array = []
var _mark: Node3D
var _grass_mats: Array = []
var _grass_nodes: Array[MultiMeshInstance3D] = []
var _env_ref: Environment
var _frame_acc := 0.0
var _frame_n := 0
var _slow_windows := 0
var _props: Array = []
## Canopy trees and the meshes under them, collected once when the stage is
## built: the fade only has to touch a tree's geometry when its value
## changes, and walking every tree hierarchy each frame allocated dozens of
## arrays per frame. Refreshed wherever props are added (see _cache_canopy).
var _canopy_props: Array[Node3D] = []
## The meshes of all the canopy trees, flattened: tree i owns the meshes
## from _canopy_start[i] up to _canopy_start[i] + _canopy_count[i].
var _canopy_meshes: Array[GeometryInstance3D] = []
var _canopy_start: PackedInt32Array = PackedInt32Array()
var _canopy_count: PackedInt32Array = PackedInt32Array()
## The props that are not canopy: they only need their visibility toggled.
var _plain_props: Array[Node3D] = []
var _contacts: Array[Vector3] = []
var _xray_mat: ShaderMaterial
var _hero_key: OmniLight3D
var _hero_rim: OmniLight3D
## Pedestal framing: share of the view height the hero fills. Home keeps the
## default; Heroes tightens so the model fills the space between the sockets.
var pedestal_fill := 0.46
var _bolt := Color(0, 0, 0, 0)
## Hero cast telegraphs and hit impacts (scripts/cast_fx3d.gd).
var _cast_fx: CastFx3D
var _occl_hit := false
var _xray := 0.0
var _contact_node: MultiMeshInstance3D
var _pings: Dictionary = {}
var _decal_shader: Shader
var _view: TextureRect
## Pedestal: the hero renders sharp in its own transparent pass over a
## blurred, darkened backdrop (engine DOF smeared the hero too).
var _hero_vp: SubViewport
var _hero_cam: Camera3D
var _hero_view: TextureRect
## Offline bakers pin the render size instead of following the control.
var fixed_px := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Render at device pixels rather than logical canvas pixels, so the 3D
	# isn't upscaled (and soft) on high-density screens. A plain Control
	# hosts the SubViewport and a TextureRect scales its frame to fit. (An
	# unstretched SubViewportContainer takes the viewport size as its minimum
	# size, which feeds back into the viewport size.)
	clip_contents = true
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.use_debanding = true
	viewport.size = Vector2i(720, 1280)
	add_child(viewport)
	_view = TextureRect.new()
	_view.texture = viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	_lights()
	actor_root = Node3D.new()
	world_root.add_child(actor_root)
	_dust_pool()
	# Hero cast telegraphs and hit impacts live in their own node so the
	# stage stays a view of the fight, not a bag of effects.
	_cast_fx = CastFx3D.new()
	actor_root.add_child(_cast_fx)


func _process(delta: float) -> void:
	var density := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, MAX_DENSITY)
	var target := Vector2i(maxi(16, int(size.x * density)), maxi(16, int(size.y * density)))
	if fixed_px != Vector2i.ZERO:
		target = fixed_px
	if viewport.size != target:
		viewport.size = target
	if _hero_vp != null:
		if _hero_vp.size != viewport.size:
			_hero_vp.size = viewport.size
		_hero_cam.global_transform = camera.global_transform
		_hero_cam.fov = camera.fov
	if not _wing_sets.is_empty():
		_flap_wings()
	if _mode == "hunt":
		_watch_frames(delta)
	if _arena_key != "":
		# The boss arena is made while the hunt runs on, a couple of props
		# per frame, so the fight's first frame has nothing left to build.
		_arena_build_step()
	# The hero's pose is owned by its PedestalIdle node (attached in
	# bind_pedestal); the stage only drifts the camera slowly so the glade
	# breathes and parallaxes.
	if _mode == "pedestal" and _ped_dist > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		var drift := Vector3(sin(t * 0.31) * 0.08 * _ped_dist, sin(t * 0.23 + 1.3) * 0.025 * _ped_dist, 0.0)
		camera.position = _ped_focus + _ped_dir * _ped_dist + drift
		camera.look_at(_ped_focus + drift * 0.2, Vector3.UP)


func bind_hunt(biome_id: String) -> void:
	_mode = "hunt"
	_arena_built = false
	_arena_reset()
	_biome = biome_id
	viewport.transparent_bg = false
	_ground(biome_id)
	_foliage(biome_id)
	_build_contacts()
	_biome_mood(biome_id)
	_apply_render_scale()
	_look = _to3(HuntMap.PLAY.get_center())
	_dist = DIST
	_ready_cam = false
	_frame(_look)


func bind_pedestal(hero_id: String) -> void:
	_mode = "pedestal"
	_hero_id = hero_id
	viewport.transparent_bg = false
	# Golden hour in a quiet glade: a low warm sun, a dim dusky sky, warm fog
	# that swallows the distance, and a cool fill so the hero still reads.
	# It sits under dark, torch-lit menu chrome, so it must not be noon-bright.
	var env := _environment(Color("6a5a4a"), false)
	env.background_energy_multiplier = 0.42
	env.ambient_light_energy = 0.42
	env.ambient_light_color = Color("b4aab0")
	env.tonemap_exposure = 1.0
	# Art-direction lock: clean, crisp, clear. A light neutral haze only for
	# depth; no bloom, no grade on top of the artist's materials.
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.4, 0.38, 0.36)
	env.fog_sky_affect = 0.3
	env.glow_enabled = false
	env.adjustment_enabled = false
	_apply_env(env)
	# Warm but not orange: the glade stays golden, the hero keeps its reds.
	sun.light_color = Color("fff1e2")
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	sun.rotation_degrees = Vector3(-24, 38, 0)
	# Glade lamps light the set only (layer 1); the hero takes the showcase
	# rig (_showcase_lights) plus the sun, so it is never over-lit.
	_lamp(Color("fff0e4"), 2.2, Vector3(-1.8, 2.6, -1.8), false, 8.0, 1)
	_lamp(Color("8fb0ff"), 1.0, Vector3(-2.2, 1.8, 1.6), false, 8.0, 1)
	# Rim: a hot back light behind the hero carves its silhouette from the forest.
	_lamp(Color("eef2ff"), 3.2, Vector3(1.2, 2.8, -2.0), false, 3.6, 1)
	_lamp(Color("fff6ec"), 1.6, Vector3(-1.4, 2.4, -1.6), false, 3.2, 1)
	# Low back rim at chest height: traces the flanks and wing roots so the
	# front view reads as a rounded body, not a flat cream bib.
	_lamp(Color("dfe8ff"), 2.4, Vector3(0.2, 1.3, -1.25), false, 2.2, 1)
	_pedestal_set()
	var body := _spawn_model(hero_id, 1.5)
	body.position = Vector3(0, PEDESTAL_TOP, 0)
	body.rotation.y = -float(body.get_meta("face", PI)) + 0.45
	world_root.add_child(body)
	_pedestal_hero = body
	_outline(body, Color("101418"), 0.005)
	_hide_catch(body)
	var clips: Dictionary = body.get_meta("clips")
	if clips.has("perch"):
		var player: AnimationPlayer = body.get_meta("player")
		if player != null and player.has_animation(str(clips["perch"])):
			player.get_animation(str(clips["perch"])).loop_mode = Animation.LOOP_PINGPONG
	_play(body, "perch" if clips.has("perch") else "idle")
	# Breathing wing fold over the clip so the wings never sit stiff.
	for sk in body.find_children("*", "Skeleton3D", true, false):
		var sway := WingSway.new()
		sk.add_child(sway)
	_frame_on(body)
	_reframe_posed(body)
	_split_hero(body)
	# Guaranteed idle life: a dedicated node that bobs, sways and leans the
	# body even when the model has no idle clip (ember has none) or the clip
	# is too shallow to read at showcase scale.
	var idle := PedestalIdle.new()
	body.add_child(idle)


func sync_hunt(sim: RunSim, alpha: float) -> void:
	if _mode != "hunt":
		return
	# The boss arena is queued here, on the hunt's first frame, so its props
	# are built long before the boss lands.
	_arena_prepare(sim)
	var seen := {}
	var hero_at := _look
	_sim_ref = sim
	var builds := 0
	for actor in sim.actors:
		if not actor.alive and actor.kind != "hero":
			continue
		if sim.explore and actor.kind == "minion" and not _bodies.has(actor.id):
			# Camps out in the fog are built when the hero first sees them,
			# two bodies a frame so a revealed camp never hitches.
			if not sim.visible_at(actor.pos) or builds >= 2:
				continue
			builds += 1
		seen[actor.id] = true
		var body := _body_for(actor)
		if sim.explore and actor.kind == "minion":
			body.visible = actor.aggro or sim.visible_at(actor.pos)
		var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
		body.position = _to3(pos)
		var dt := get_process_delta_time()
		var turn := 1.0 - exp(-(45.0 if actor.kind == "hero" else 16.0) * dt)
		body.rotation.y = lerp_angle(body.rotation.y, _yaw(actor.facing, body), turn)
		_anim(body, actor)
		if actor.kind == "hero" and not actor.alive and bool(body.get_meta("dying", false)):
			# The hero topples and stays down (no fade) under the defeat card.
			_dying(body, Time.get_ticks_msec() / 1000.0, false)
		if actor.kind == "boss":
			_boss_fx(body, actor)
		if actor.kind == "hero" and actor.team == 0:
			hero_at = body.position
			_step_dust(body, actor, sim)
			if is_instance_valid(_hero_key):
				_hero_key.global_position = hero_at + Vector3(1.6, 4.2, 3.4)
			if is_instance_valid(_hero_rim):
				_hero_rim.global_position = hero_at + Vector3(-2.2, 3.6, -2.8)
	var boss_up := false
	var boss_at := Vector3.ZERO
	for actor in sim.actors:
		if actor.alive and actor.kind == "boss":
			boss_up = true
			boss_at = _to3(actor.pos)
	_dist = lerpf(_dist, BOSS_DIST if boss_up else DIST, 0.08)
	_update_xray(boss_up, boss_at, hero_at, sim)
	var drop: Array = []
	var now_s := Time.get_ticks_msec() / 1000.0
	for id in _bodies.keys():
		if seen.has(id):
			continue
		var body: Node3D = _bodies[id]
		if bool(body.get_meta("dying", false)):
			_dying(body, now_s)
			if float(body.get_meta("die_at", 0.0)) + 1.1 < Time.get_ticks_msec() / 1000.0:
				drop.append(id)
		else:
			drop.append(id)
	for id in drop:
		var body: Node3D = _bodies[id]
		_bodies.erase(id)
		body.queue_free()
	if _mark != null:
		_mark.visible = false
	if _reach != null:
		_reach.visible = false
	for actor in sim.actors:
		if actor.kind == "hero" and actor.team == 0 and actor.alive:
			_place_mark(_to3(actor.prev.lerp(actor.pos, alpha)))
			_place_reach(actor, _to3(actor.prev.lerp(actor.pos, alpha)))
			break
	for mat in _grass_mats:
		(mat as ShaderMaterial).set_shader_parameter("hero", hero_at)
	_open_around(hero_at)
	_threat_rings(sim, hero_at)
	_sync_mob_decals(sim, hero_at)
	sync_fog(sim, get_process_delta_time())
	var focus := hero_at
	if boss_up:
		# Lean the view toward the boss so its telegraphs stay on screen.
		var lean := (boss_at - hero_at) * 0.5
		lean.y = 0.0
		focus = hero_at + lean.limit_length(5.5)
		# Keep the whole cap under the boss bar: if the top of the boss
		# projects too high, ease the view up-screen, as long as the hero
		# stays clear of the bottom HUD.
		var vh := float(viewport.size.y)
		var head_y := camera.unproject_position(boss_at + Vector3(0, BOSS_METERS * 1.02, 0)).y / vh
		var hero_y := camera.unproject_position(hero_at).y / vh
		if head_y < BOSS_TOP_LIMIT and hero_y < 0.8:
			_boss_shift = minf(_boss_shift + 0.12, 9.0)
		elif head_y > BOSS_TOP_LIMIT + 0.06 or hero_y > 0.84:
			_boss_shift = maxf(_boss_shift - 0.08, 0.0)
		focus.z -= _boss_shift
	else:
		_boss_shift = 0.0
	_follow(focus, get_process_delta_time())


func sync_fx(sim: RunSim, alpha: float) -> void:
	if _mode != "hunt":
		return
	var seen := {}
	for gem in sim.gems:
		if not gem.alive:
			continue
		var id := gem.get_instance_id()
		seen[id] = true
		var node := _fx_node(id, "gem")
		var pos: Vector2 = gem.prev.lerp(gem.pos, alpha)
		node.position = _to3(pos) + Vector3(0.0, 0.4 + sin(gem.bob) * 0.08, 0.0)
		node.rotate_y(0.05)
		var trail := node.get_node_or_null("Trail") as GPUParticles3D
		if trail != null:
			trail.emitting = gem.pos.distance_to(gem.prev) > 1.2
	for shot in sim.shots:
		if not shot.alive:
			continue
		var id := shot.get_instance_id()
		seen[id] = true
		var node := _fx_node(id, shot.kind)
		var pos: Vector2 = shot.prev.lerp(shot.pos, alpha)
		node.position = _to3(pos) + Vector3(0.0, 0.72, 0.0)
		var vel: Vector2 = shot.vel
		if shot.kind == "arrow" and vel.length() > 1.0:
			var dir := Vector3(vel.x, 0.0, vel.y).normalized()
			node.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	_sync_pings(sim)
	var gone: Array = []
	for id in _fx.keys():
		if not seen.has(id):
			gone.append(id)
	for id in gone:
		var node: Node3D = _fx[id]
		_fx.erase(id)
		node.queue_free()


## Boss telegraphs on the ground: a red disc that charges from the center,
## or a charge lane, both with a crisp ring so the player can read the edge.
func _sync_pings(sim: RunSim) -> void:
	var seen := {}
	for ping in sim.pings:
		if not ping.alive or ping.max_life <= 0.0:
			continue
		var id := ping.get_instance_id()
		seen[id] = true
		var node: MeshInstance3D = _pings.get(id, null)
		var lane: bool = ping.kind != "circle"
		if node == null:
			node = _decal(1.0, {
				"ring_color": Color(1.0, 0.42, 0.22, 0.95),
				"ring_radius": 0.46,
				"ring_width": 0.018 if not lane else 0.012,
				"ring_glow": 0.4,
				"fill_color": Color(1.0, 0.18, 0.08, 0.38),
				"lane": lane,
			})
			actor_root.add_child(node)
			_pings[id] = node
		var charged := 1.0 - clampf(ping.life / ping.max_life, 0.0, 1.0)
		(node.material_override as ShaderMaterial).set_shader_parameter("fill_progress", charged)
		if lane:
			var mid: Vector2 = ping.pos + ping.dir * ping.length * 0.5
			node.position = _to3(mid) + Vector3(0, 0.04, 0)
			node.rotation = Vector3(0, -ping.dir.angle() , 0)
			node.scale = Vector3(ping.length * SCALE / 0.92, 1.0, ping.width * 2.0 * SCALE / 0.92)
		else:
			node.position = _to3(ping.pos) + Vector3(0, 0.04, 0)
			var d := ping.radius * 2.0 * SCALE / 0.92
			node.scale = Vector3(d, 1.0, d)
	for id in _pings.keys():
		if not seen.has(id):
			(_pings[id] as Node).queue_free()
			_pings.erase(id)


func sync_pet(sprite: String, sim_pos: Vector2, facing: float, moving: bool) -> void:
	if sprite == "" or _mode != "hunt":
		return
	if _pet == null:
		_pet = _spawn_model(sprite, 0.72)
		actor_root.add_child(_pet)
		_pet_ready = false
	var goal := _to3(sim_pos)
	if not _pet_ready:
		_pet.position = goal
		_pet_ready = true
	_pet.position = _pet.position.lerp(goal, 0.22)
	_pet.rotation.y = lerp_angle(_pet.rotation.y, _yaw(facing, _pet), 0.35)
	_play(_pet, "run" if moving else "idle")


func project(sim_pos: Vector2, height := 1.1) -> Vector2:
	if camera == null:
		return sim_pos
	var screen := camera.unproject_position(_to3(sim_pos) + Vector3(0, height, 0))
	var rect := get_global_rect()
	var vp := Vector2(viewport.size)
	return rect.position + Vector2(screen.x / vp.x * rect.size.x, screen.y / vp.y * rect.size.y)


## Like project(), but over the body's visual centre (models are often
## offset from their origin), for tags that must sit centred on a creature.
func project_body(actor_id: int, sim_pos: Vector2, height: float) -> Vector2:
	var body: Node3D = _bodies.get(actor_id)
	if camera == null or body == null:
		return project(sim_pos, height)
	if not body.has_meta("center_off"):
		var c := _measure(body).get_center()
		body.set_meta("center_off", Vector3(c.x, 0, c.z))
	var at: Vector3 = body.global_transform * (body.get_meta("center_off") as Vector3) + Vector3(0, height, 0)
	var screen := camera.unproject_position(at)
	var rect := get_global_rect()
	var vp := Vector2(viewport.size)
	return rect.position + Vector2(screen.x / vp.x * rect.size.x, screen.y / vp.y * rect.size.y)


func attack(actor_id: int) -> void:
	if not _bodies.has(actor_id):
		return
	var body: Node3D = _bodies[actor_id]
	body.set_meta("lock", "attack")
	body.set_meta("att_t", Time.get_ticks_msec() / 1000.0)
	body.set_meta("wind_len", 0.0)
	body.set_meta("lock_until", Time.get_ticks_msec() / 1000.0 + 0.38)
	_play(body, "attack")
	# Release flash at the mouth or weapon side.
	var face := float(body.get_meta("face", PI))
	var fwd := body.global_transform.basis * Vector3(sin(face), 0.0, cos(face))
	var m := float(body.get_meta("meters", 1.0))
	_spark(body.position + fwd.normalized() * m * 0.45 + Vector3(0, m * 0.45, 0), Color("ffd28a"))
	# A hero's cast gets a telegraph: a ring at its feet and a lane along
	# the aim, both in the hero's own colour.
	if _cast_fx != null and str(body.get_meta("kind", "")) == "hero":
		var aim_dir := Vector3(fwd.x, 0.0, fwd.z)
		if aim_dir.length() > 0.001:
			# The ground plane is x/z; the sim's facing is an angle in x/y.
			var aim := atan2(aim_dir.z, aim_dir.x)
			var reach := float(body.get_meta("reach", 0.0)) * SCALE
			var melee := str(body.get_meta("role", "")) == "tank"
			_cast_fx.cast_telegraph(str(body.get_meta("sprite", "")), body.position, aim, reach, melee)


## Wind-up before a release: crouch, lean back and shiver (motion layer).
func windup(actor_id: int, seconds: float) -> void:
	if not _bodies.has(actor_id):
		return
	var body: Node3D = _bodies[actor_id]
	body.set_meta("wind_t", Time.get_ticks_msec() / 1000.0)
	body.set_meta("wind_len", seconds)


## Level-up: a hop and full spin with a golden spark ring.
func celebrate(actor_id: int) -> void:
	if not _bodies.has(actor_id):
		return
	var body: Node3D = _bodies[actor_id]
	body.set_meta("lvl_t", Time.get_ticks_msec() / 1000.0)
	for i in 6:
		var a := TAU * float(i) / 6.0
		_spark(body.position + Vector3(cos(a), 0.3, sin(a)) * 0.9, Color("ffe08a"))


func hurt(actor_id: int, boss := false, heavy := false) -> void:
	if not _bodies.has(actor_id):
		return
	var body: Node3D = _bodies[actor_id]
	if str(body.get_meta("lock", "")) == "death":
		return
	# The hit landed: motes, a light flash and a ring at the struck body.
	_impact_at(body, heavy)
	if boss:
		# A boss shrugs off chip damage: a flash, a spark and a small recoil
		# every hit; the full stagger clip only on a heavy hit, at most every
		# 1.6 s, and never mid wind-up or swing so telegraphs stay honest.
		var now := Time.get_ticks_msec() / 1000.0
		body.set_meta("hit_t", now)
		body.set_meta("hit_amp", 0.45)
		_spark(body.position + Vector3(0, BOSS_METERS * 0.25, 0), Color("ffb15a"))
		_flash(body)
		var winding := now - float(body.get_meta("wind_t", -10.0)) < float(body.get_meta("wind_len", 0.0))
		var busy := winding or str(body.get_meta("lock", "")) == "attack"
		if heavy and not busy and now - float(body.get_meta("stagger_t", -10.0)) > 1.6:
			body.set_meta("stagger_t", now)
			body.set_meta("hit_amp", 1.0)
			body.set_meta("lock", "hit")
			body.set_meta("lock_until", now + 0.32)
			_play(body, "hit")
		return
	body.set_meta("hit_amp", 1.0)
	body.set_meta("lock", "hit")
	body.set_meta("hit_t", Time.get_ticks_msec() / 1000.0)
	body.set_meta("lock_until", Time.get_ticks_msec() / 1000.0 + 0.22)
	_play(body, "hit")
	_spark(body.position, Color("ffb15a"))
	_flash(body)


## The burst where a hit landed, sized to the body that took it. A hero
## flares red; anything else wears the colour of the hero that cast at it.
func _impact_at(body: Node3D, heavy: bool) -> void:
	if _cast_fx == null:
		return
	var meters := float(body.get_meta("meters", 1.0))
	var col := CastFx3D.HURT_COLOR
	if str(body.get_meta("kind", "")) != "hero":
		col = _cast_fx.impact_color()
	_cast_fx.impact_burst(
		body.position + Vector3(0, meters * 0.45, 0),
		col,
		meters * 0.42,
		heavy,
		int(body.get_meta("actor_id", 0)))


## A brief additive white pulse over the whole body: the classic hit flash.
## Hit flash: a quick warm emissive tint on the body's own materials. No
## overlay or outline swap, so nothing but the critter's surface changes.
func _flash(body: Node3D) -> void:
	if body.has_meta("mob"):
		# Shared minion materials: the flash is a per-instance uniform.
		var stamp_m := Time.get_ticks_msec()
		body.set_meta("flash_stamp", stamp_m)
		var gis := body.find_children("*", "MeshInstance3D", true, false)
		for gi in gis:
			(gi as GeometryInstance3D).set_instance_shader_parameter("flash", 0.3 * AudioDirector.flash_scale())
		get_tree().create_timer(0.07).timeout.connect(func() -> void:
			if not is_instance_valid(body) or int(body.get_meta("flash_stamp", 0)) != stamp_m:
				return
			for gi in gis:
				if is_instance_valid(gi):
					(gi as GeometryInstance3D).set_instance_shader_parameter("flash", 0.0))
		return
	if not body.has_meta("big"):
		body.set_meta("big", _measure(body).size.y * body.scale.y > HERO_METERS * 2.0)
	# Low energy: a warm glint over the painted surface, not a flat fill.
	var energy := (0.1 if bool(body.get_meta("big")) else 0.3) * AudioDirector.flash_scale()
	var mats: Array = body.get_meta("flash_mats", [])
	if mats.is_empty():
		for m in body.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if str(mi.name).begins_with("Catch") or mi.has_meta("decal") or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var base := mi.get_active_material(i)
				if not base is StandardMaterial3D:
					continue
				# Own copy per body so one hit never lights the whole pack.
				var own := base as StandardMaterial3D
				if mi.get_surface_override_material(i) != base:
					own = base.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(i, own)
				own.set_meta("emit_on", own.emission_enabled)
				own.set_meta("emit_col", own.emission)
				own.set_meta("emit_e", own.emission_energy_multiplier)
				mats.append(own)
		body.set_meta("flash_mats", mats)
	for mat in mats:
		var sm := mat as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = Color(1.0, 0.6, 0.4)
		sm.emission_energy_multiplier = energy
	var stamp := Time.get_ticks_msec()
	body.set_meta("flash_stamp", stamp)
	get_tree().create_timer(0.07).timeout.connect(func() -> void:
		if not is_instance_valid(body) or int(body.get_meta("flash_stamp", 0)) != stamp:
			return
		for mat in mats:
			var sm := mat as StandardMaterial3D
			sm.emission_enabled = bool(sm.get_meta("emit_on"))
			sm.emission = sm.get_meta("emit_col")
			sm.emission_energy_multiplier = float(sm.get_meta("emit_e")))


func died(actor_id: int, sim_pos: Vector2, sprite: String) -> void:
	var body: Node3D = _bodies.get(actor_id, null)
	if body == null:
		body = _spawn_model(sprite, 1.0)
		body.position = _to3(sim_pos)
		actor_root.add_child(body)
		_bodies[actor_id] = body
	body.set_meta("dying", true)
	body.set_meta("lock", "death")
	body.set_meta("die_at", Time.get_ticks_msec() / 1000.0)
	_play(body, "death")
	_spark(body.position, Color("ffe08a"))


func set_shake(offset: Vector2) -> void:
	_shake = Vector3(offset.x, offset.y, 0.0) * 0.01
	if camera != null and _ready_cam:
		_frame(_look)


func _lights() -> void:
	var high := _tier() == "high"
	sun = DirectionalLight3D.new()
	# Warm late-afternoon key; the cool rim opposite keeps forms round.
	sun.light_color = Color("ffbd72")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 80.0 if high else 64.0
	sun.shadow_bias = 0.04
	sun.rotation_degrees = Vector3(-48, 38, 0)
	world_root.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("c5dcff")
	rim.light_energy = 1.35
	rim.light_specular = 0.25
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-18, -150, 0)
	world_root.add_child(rim)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.08
	camera.far = 150.0
	camera.current = true
	world_root.add_child(camera)
	_apply_env(_environment(Color("c5d4e8"), high))


func _environment(fog: Color, high: bool) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	var tex := load("res://assets/textures/sky.hdr")
	if tex:
		panorama.panorama = tex
	sky.sky_material = panorama
	env.sky = sky
	env.background_energy_multiplier = 0.32
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Lower ambient so sun shadows read as real contact and depth.
	env.ambient_light_energy = 0.5
	# Warm key, cool fill: half the ambient comes from a blue sky colour so
	# everything in shadow leans cool against the sunlit warm side.
	env.ambient_light_color = Color("7f9ccc")
	env.ambient_light_sky_contribution = 0.5
	# Filmic AgX, a hair desaturated: mature, not candy.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.14
	env.tonemap_white = 6.5
	# Art-direction lock: no colour grade and no bloom over the materials;
	# only emissive VFX above HDR 2.0 may bloom, faintly.
	env.adjustment_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.06
	env.glow_strength = 0.4
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 2.0
	env.ssao_enabled = high
	env.ssao_radius = 1.3
	env.ssao_intensity = 2.0
	env.ssao_power = 1.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.5, 0.6)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.1
	env.sdfgi_enabled = high and not _software()
	return env


func _apply_env(env: Environment) -> void:
	var old := world_root.get_node_or_null("World")
	if old:
		old.queue_free()
	_env_ref = env
	var holder := WorldEnvironment.new()
	holder.name = "World"
	holder.environment = env
	world_root.add_child(holder)
	camera.environment = env


## Lattice cells of the baked noise field across one texture tile. The
## terrain shader samples the field in the same lattice units the old
## analytic fbm used, so every mask keeps the world size it had.
const NOISE_CELLS := 16
const NOISE_SIZE := 256
## The noise field the terrain shader splats with. Baking it once turns
## every mask into a single texture fetch instead of a per-fragment fbm.
static var _noise_tex: ImageTexture


## Tileable three-octave value noise, baked once and reused by every ground.
## The lattice of each octave wraps, so the field is periodic and the
## texture tiles without a seam.
static func _terrain_noise() -> ImageTexture:
	if _noise_tex == null:
		_noise_tex = _bake_noise(NOISE_SIZE, NOISE_CELLS)
	return _noise_tex


static func _bake_noise(size: int, cells: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED17
	var counts: Array[int] = []
	counts.append(cells)
	counts.append(cells * 2)
	counts.append(cells * 4)
	var tables: Array[PackedFloat32Array] = []
	for c in counts:
		var t := PackedFloat32Array()
		t.resize(c * c)
		for i in c * c:
			t[i] = rng.randf()
		tables.append(t)
	var data := PackedByteArray()
	data.resize(size * size)
	var step := 1.0 / float(size)
	var t0: PackedFloat32Array = tables[0]
	var t1: PackedFloat32Array = tables[1]
	var t2: PackedFloat32Array = tables[2]
	var c0 := counts[0]
	var c1 := counts[1]
	var c2 := counts[2]
	for y in size:
		var fy := (float(y) + 0.5) * step
		for x in size:
			var fx := (float(x) + 0.5) * step
			# Same octaves and weights as the shader's fbm: one cell of the
			# base octave is one lattice unit, so scales carry over unchanged.
			var v := _lattice(t0, c0, fx, fy) * 0.55 \
				+ _lattice(t1, c1, fx, fy) * 0.3 \
				+ _lattice(t2, c2, fx, fy) * 0.15
			data[y * size + x] = int(clampf(v, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(size, size, false, Image.FORMAT_L8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## One octave of value noise over the tile: bilinear between the lattice
## corners, faded like the shader's noise() did.
static func _lattice(t: PackedFloat32Array, c: int, fx: float, fy: float) -> float:
	var ux := fx * float(c)
	var uy := fy * float(c)
	var ix := int(ux)
	var iy := int(uy)
	var tx := ux - float(ix)
	var ty := uy - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var m := c - 1
	var i0 := ix & m
	var i1 := (ix + 1) & m
	var j0 := (iy & m) * c
	var j1 := ((iy + 1) & m) * c
	var h00 := t[j0 + i0]
	var h10 := t[j0 + i1]
	var h01 := t[j1 + i0]
	var h11 := t[j1 + i1]
	var a := h00 + (h10 - h00) * tx
	var b := h01 + (h11 - h01) * tx
	return a + (b - a) * ty


func _ground(biome_id: String) -> void:
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	var pad := 28.0
	var span := Vector2(HuntMap.ARENA.x * SCALE + pad * 2.0, HuntMap.ARENA.y * SCALE + pad * 2.0)
	plane.size = span
	plane.subdivide_width = 96
	plane.subdivide_depth = 120
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("grass_color", load("res://assets/textures/ground_grass_color.jpg"))
	mat.set_shader_parameter("grass_normal", load("res://assets/textures/ground_grass_normal.jpg"))
	mat.set_shader_parameter("grass_data", load("res://assets/textures/ground_grass_data.jpg"))
	mat.set_shader_parameter("forest_color", load("res://assets/textures/ground_forest_color.jpg"))
	mat.set_shader_parameter("forest_normal", load("res://assets/textures/ground_forest_normal.jpg"))
	mat.set_shader_parameter("forest_data", load("res://assets/textures/ground_forest_data.jpg"))
	mat.set_shader_parameter("dirt_color", load("res://assets/textures/ground_dirt_color.jpg"))
	mat.set_shader_parameter("dirt_normal", load("res://assets/textures/ground_dirt_normal.jpg"))
	mat.set_shader_parameter("dirt_data", load("res://assets/textures/ground_dirt_data.jpg"))
	mat.set_shader_parameter("noise_tex", _terrain_noise())
	mat.set_shader_parameter("noise_uv", 1.0 / float(NOISE_CELLS))
	mat.set_shader_parameter("world_span", span)
	mat.set_shader_parameter("tint", _biome_tint(biome_id))
	mat.set_shader_parameter("dirt_tint", _dirt_tint(biome_id))
	mat.set_shader_parameter("snow", 0.75 if biome_id == "frost" else 0.0)
	mat.set_shader_parameter("ash", 0.85 if biome_id == "volcano" else 0.0)
	var a0 := _to3(HuntMap.PLAY.position - Vector2(40.0, 58.0))
	var a1 := _to3(HuntMap.PLAY.end + Vector2(40.0, 82.0))
	mat.set_shader_parameter("arena", Vector4(a0.x, a0.z, a1.x, a1.z))
	mat.set_shader_parameter("litter", 0.0 if biome_id == "volcano" else (0.3 if biome_id == "frost" else 1.0))
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = mat
	mesh.position = Vector3(HuntMap.ARENA.x * SCALE * 0.5, 0, HuntMap.ARENA.y * SCALE * 0.5)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mesh)


## Distance in meters to the dirt trails the terrain shader paints, without
## the shader's wobble. Grass and props keep off the trails with it.
static func path_dist(w: Vector2) -> float:
	var a := absf(w.x - (11.2 + sin(w.y * 0.17 + 0.6) * 3.8))
	var b := absf(w.y - (24.0 + sin(w.x * 0.25 + 1.8) * 2.8))
	var c := absf(w.x - (5.0 + w.y * 0.2)) + maxf(w.y - 19.0, 0.0) * 4.0
	return minf(minf(a, b), c)


func _foliage(biome_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id) + 17
	_grass_mats.clear()
	_grass_nodes.clear()
	_props.clear()
	_cache_canopy()
	_contacts.clear()
	# Budget: the pulled-back camera sees nearly the whole field, so every
	# blade is drawn. grass_short is ~155 tris, wispy ~620, flowers ~1700,
	# so the cheap blade carries the density and the costly ones accent.
	var tier := _tier()
	# The arena is ~2x the old field; density scales with it (the grid cut in
	# _scatter keeps what is drawn close to the old budget).
	var area_k := 2.4
	var count := int((420 if tier == "low" else (1300 if tier == "medium" else 2100)) * area_k)
	var accent := 0.4 if tier == "low" else (0.6 if tier == "medium" else 1.0)
	_scatter(rng, "grass_short", int(count * 0.62), 0.4, 0.6, true)
	_scatter(rng, "grass_wispy", int(count * 0.14 * accent), 0.38, 0.55, true)
	if not biome_id in ["frost", "volcano"]:
		# Taller tufts in clumps break up the turf at the hunt zoom.
		_scatter(rng, "grass_tall", int(count * 0.08 * accent), 0.45, 0.7, true)
	if not biome_id in ["frost", "volcano"]:
		_scatter(rng, "flower_a", int(34 * accent * area_k), 0.5, 0.75, false)
		_scatter(rng, "flower_b", int(30 * accent * area_k), 0.5, 0.75, false)
	_scatter(rng, "clover", int(40 * area_k), 0.45, 0.62, false)
	_scatter(rng, "fern", int((22 if biome_id == "meadow" else 34) * area_k), 0.6, 0.9, false)
	var trees: Array = ["tree_a", "tree_b", "bush_flower", "tree_a"]
	match biome_id:
		"mushroom":
			trees = ["mushroom_tall", "mushroom", "mushroom_tall", "tree_pine_b"]
		"frost":
			trees = ["tree_pine", "tree_pine_b", "bush"]
		"volcano":
			trees = ["tree_dead", "tree_dead", "rock_lava"]
	var pack := biome_id == "meadow" and ResourceLoader.exists("res://assets/models/sketchfab/nature/grove.glb")
	if not pack:
		for i in (11 if _tier() == "low" else 20):
			var name: String = trees[i % trees.size()]
			var at := _rim_point(rng)
			_place_prop(name, at, rng.randf_range(1.15, 1.55), true, null, rng)
	if not biome_id in ["frost", "volcano"]:
		# The leafy, blossoming nature pack belongs in green biomes only.
		_sketchfab_nature(rng)
		# Big trunks just outside the arena: their canopies frame the
		# corners and their shadows fall into the clearing.
		var edge_trees := ["tree_a", "tree_b", "tree_pine"] if biome_id == "meadow" else ["mushroom_tall", "tree_pine_b"]
		for i in (4 if tier == "low" else (6 if tier == "medium" else 8)):
			var side := -1.0 if i % 2 == 0 else 1.0
			# Right at the frame edge: the canopy crops off-screen while the
			# trunk and its shadow read inside the clearing.
			# Outside the playable bounds: trunks stand past the arena edge
			# and only the canopy edge overhangs the clearing.
			var x := HuntMap.PLAY.position.x - rng.randf_range(90.0, 140.0) if side < 0.0 else HuntMap.PLAY.end.x + rng.randf_range(90.0, 140.0)
			var y := lerpf(HuntMap.PLAY.position.y + 100.0, HuntMap.PLAY.end.y - 80.0, float(i / 2) / 3.0) + rng.randf_range(-60.0, 60.0)
			_place_prop(edge_trees[i % edge_trees.size()], _to3(Vector2(x, y)), rng.randf_range(2.2, 2.9), true, null, rng)
	_field_props(rng)
	_clutter(rng, biome_id)
	# Every canopy tree is in place now: cache them and their meshes once.
	_cache_canopy()


## Small 3D ground clutter so the floor reads as material, not a painting:
## pebbles along the trails, fallen twigs, and flat leaf litter, each one
## multimesh (split into a grid when large) with per-instance colour.
func _clutter(rng: RandomNumberGenerator, biome_id: String) -> void:
	var tier := _tier()
	var k := (0.45 if tier == "low" else (1.0 if tier == "medium" else 1.5)) * 1.5
	var green := not biome_id in ["frost", "volcano"]
	# Pebbles: squashed low-poly spheres, mostly on and beside the trails.
	var peb := SphereMesh.new()
	peb.radius = 0.06
	peb.height = 0.12
	peb.radial_segments = 7
	peb.rings = 4
	var peb_mat := StandardMaterial3D.new()
	peb_mat.albedo_texture = load("res://assets/textures/rock_color.jpg")
	peb_mat.uv1_triplanar = true
	peb_mat.uv1_scale = Vector3(6, 6, 6)
	peb_mat.vertex_color_use_as_albedo = true
	peb_mat.roughness = 0.85
	var xf: Array = []
	var cols: Array = []
	for i in int(300 * k):
		var at := _field_point(rng)
		for _t in 6:
			if path_dist(Vector2(at.x, at.z)) < 1.6 or rng.randf() < 0.18:
				break
			at = _field_point(rng)
		var s := rng.randf_range(0.5, 1.5)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
		b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.5), s * rng.randf_range(0.35, 0.65), s * rng.randf_range(0.7, 1.2)))
		xf.append(Transform3D(b, at + Vector3(0, 0.005, 0)))
		var v := rng.randf_range(0.55, 1.0)
		cols.append(Color(v, v * 0.92, v * 0.82) if biome_id != "volcano" else Color(v * 0.3, v * 0.28, v * 0.28))
	_mm_grid(peb, peb_mat, xf, cols)
	if not green and biome_id != "frost":
		return
	# Twigs: thin tapered sticks lying flat, a few with a short side branch.
	var twig := CylinderMesh.new()
	twig.top_radius = 0.009
	twig.bottom_radius = 0.016
	twig.height = 0.55
	twig.radial_segments = 5
	twig.rings = 1
	twig.cap_top = false
	twig.cap_bottom = false
	var twig_mat := StandardMaterial3D.new()
	twig_mat.albedo_texture = load("res://assets/textures/wood_color.jpg")
	twig_mat.vertex_color_use_as_albedo = true
	twig_mat.roughness = 0.9
	xf = []
	cols = []
	for i in int(130 * k):
		var at := _field_point(rng)
		var yaw := rng.randf() * TAU
		var len := rng.randf_range(0.6, 1.6)
		var lie := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5 + rng.randf_range(-0.08, 0.08))
		var col := Color(0.42, 0.3, 0.2).lerp(Color(0.62, 0.5, 0.36), rng.randf())
		xf.append(Transform3D(lie.scaled(Vector3(1, len, 1)), at + Vector3(0, 0.012, 0)))
		cols.append(col)
		if rng.randf() < 0.45:
			var side := Basis(Vector3.UP, yaw + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)) * Basis(Vector3.RIGHT, PI * 0.5)
			var off := Basis(Vector3.UP, yaw) * Vector3(0, 0, rng.randf_range(-0.12, 0.12) * len)
			var tip := side * Vector3(0, 0.12 * len, 0)
			xf.append(Transform3D(side.scaled(Vector3(0.7, len * 0.45, 0.7)), at + off + tip + Vector3(0, 0.012, 0)))
			cols.append(col)
	_mm_grid(twig, twig_mat, xf, cols)
	# Leaf litter: flat alpha-cut leaves in drifts along the trails and in
	# clumps, autumn browns and ambers with the odd green one.
	var leaf := PlaneMesh.new()
	leaf.size = Vector2(0.16, 0.1)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_texture = _leaf_texture()
	leaf_mat.vertex_color_use_as_albedo = true
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_mat.alpha_scissor_threshold = 0.5
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.roughness = 0.8
	xf = []
	cols = []
	var centers: Array = []
	for c in int(26 * k):
		centers.append(_field_point(rng))
	var ambers := [Color(0.55, 0.3, 0.1), Color(0.7, 0.45, 0.14), Color(0.45, 0.24, 0.1), Color(0.5, 0.45, 0.16), Color(0.36, 0.2, 0.09)]
	for i in int(520 * k * (0.35 if biome_id == "frost" else 1.0)):
		var at: Vector3
		if rng.randf() < 0.6:
			var c: Vector3 = centers[rng.randi() % centers.size()]
			at = c + Vector3(rng.randfn(0.0, 0.7), 0, rng.randfn(0.0, 0.7))
		else:
			at = _field_point(rng)
		var s := rng.randf_range(0.7, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)))
		xf.append(Transform3D(b.scaled(Vector3(s, s, s)), at + Vector3(0, 0.01 + rng.randf() * 0.01, 0)))
		cols.append(ambers[rng.randi() % ambers.size()] * rng.randf_range(0.62, 0.92))
	_mm_grid(leaf, leaf_mat, xf, cols)


## Clutter instances are a few dozen triangles, so one multimesh per kind
## (drawing the off-screen ones too) is cheaper than extra draw calls.
func _mm_grid(mesh: Mesh, mat: Material, xf: Array, cols: Array) -> void:
	var n := 1
	var m := 1
	var lo3 := _to3(HuntMap.PLAY.position)
	var span3 := _to3(HuntMap.PLAY.end) - lo3
	var cells: Array = []
	for i in n * m:
		cells.append([])
	for i in xf.size():
		var at: Vector3 = (xf[i] as Transform3D).origin
		var cx := clampi(int((at.x - lo3.x) / span3.x * n), 0, n - 1)
		var cy := clampi(int((at.z - lo3.z) / span3.z * m), 0, m - 1)
		cells[cy * n + cx].append(i)
	for cell in cells:
		if cell.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = cell.size()
		for j in cell.size():
			mm.set_instance_transform(j, xf[cell[j]])
			mm.set_instance_color(j, cols[cell[j]])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(node)


static var _leaf_tex: Texture2D

## A white leaf silhouette with a darker midrib and veins; tinted per instance.
func _leaf_texture() -> Texture2D:
	if _leaf_tex:
		return _leaf_tex
	var img := Image.create(64, 40, true, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 64:
			var u := (x + 0.5) / 64.0 * 2.0 - 1.0
			var v := (y + 0.5) / 40.0 * 2.0 - 1.0
			# Pointed ellipse: narrower toward the tip (u = 1).
			var half := sqrt(maxf(0.0, 1.0 - u * u)) * (1.0 - 0.35 * maxf(u, 0.0))
			var inside := absf(v) < half * 0.95 and u > -0.98
			var stem := u < -0.85 and absf(v) < 0.06
			if not inside and not stem:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var shade := 0.85 + 0.15 * (1.0 - absf(v) / maxf(half, 0.01))
			if absf(v) < 0.05 or stem:
				shade *= 0.7
			elif absf(fmod(u * 4.0 + absf(v) * 3.0, 1.0) - 0.5) < 0.06:
				shade *= 0.86
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	img.generate_mipmaps()
	_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


## Mid-field set dressing a Diablo floor needs: mossy rocks, fallen logs,
## stumps, mushroom clusters, and flower beds, kept off the trails.
func _field_props(rng: RandomNumberGenerator) -> void:
	var kit := [
		["rock_a", 0.55, 0.95, 5], ["rock_b", 0.45, 0.8, 5], ["rock_c", 0.6, 1.0, 3],
		["pebble_rock", 0.5, 0.8, 6], ["pebble_rock_b", 0.45, 0.7, 5],
		# No logs or stumps: from the hunt camera they read as dark red
		# primitives. Rocks, ferns, blossoms and mushrooms carry the field.
		["mushroom_tall", 1.3, 2.1, 7], ["mushroom_shelf", 0.35, 0.5, 3],
		["fern", 0.8, 1.1, 6], ["flower_b", 0.7, 0.95, 6], ["flower_a", 0.7, 0.95, 6],
	]
	for row in kit:
		row[3] = int(round(int(row[3]) * 2.0))
	if _tier() == "low":
		for row in kit:
			row[3] = maxi(1, int(row[3]) / 2)
	elif _tier() == "medium":
		# The wider camera sees the whole field: thin the small dressing
		# (each flower or mushroom group is several draws), keep the rocks.
		for row in kit:
			if not str(row[0]).begins_with("rock") and not str(row[0]).begins_with("pebble"):
				row[3] = maxi(1, int(round(int(row[3]) * 0.6)))
	if _biome in ["frost", "volcano"]:
		# No blossoms on snow or ash.
		kit = kit.filter(func(row: Array) -> bool: return not ("flower" in str(row[0])))
	# Small dressing goes through one multimesh per surface, so a field
	# full of ferns, blossoms, mushrooms and stumps costs a handful of draws.
	var bulk := ["fern", "flower_a", "flower_b", "mushroom_tall", "mushroom_shelf", "stump"]
	var dense := {"low": 1.2, "medium": 2.6, "high": 3.2}
	# Fewer, more meaningful landmarks: mushrooms and stumps stay sparse,
	# ferns and blossoms carry the fill.
	var landmark := {"mushroom_tall": 0.35, "stump": 0.3, "mushroom_shelf": 0.6}
	for row in kit:
		if str(row[0]) in bulk:
			var n := int(round(int(row[3]) * float(dense.get(_tier(), 2.6)) * float(landmark.get(str(row[0]), 1.0))))
			# The kit's blossoms, caps and stumps are tiny from the hunt
			# camera: grow them into readable mid-size dressing.
			var grow := float({"flower_a": 2.6, "flower_b": 2.6, "mushroom": 1.7, "mushroom_shelf": 1.5, "stump": 2.4}.get(str(row[0]), 1.0))
			_scatter_kit(rng, str(row[0]), n, float(row[1]) * grow, float(row[2]) * grow)
	kit = kit.filter(func(row: Array) -> bool: return not (str(row[0]) in bulk))
	# The stones go through one multimesh per kind: a glade full of mossy
	# rock used to be a hundred GLB scenes, one draw call each.
	_scatter_rocks(rng, kit)


## The field's rock rows: one MultiMesh per kind, so a glade full of mossy
## stone costs a handful of draws instead of a hundred GLB scenes. Every
## stone keeps the place, size, spin and bedded-in tilt it had as its own
## scene: the same prop is still posed here, only the way it is drawn
## changed.
func _scatter_rocks(rng: RandomNumberGenerator, rows: Array) -> void:
	var probes := {}
	var spots := {}
	for row in rows:
		var model := str(row[0])
		var rocky := model.begins_with("rock") or model.begins_with("pebble_rock")
		for _n in int(row[3]):
			var at := _off_path_point(rng, 1.5)
			var sc := rng.randf_range(float(row[1]), float(row[2]))
			# Shadow casters cost a draw per split: only the big pieces cast.
			var shadows := (model.begins_with("rock") and sc > 0.75) or model == "log"
			if not rocky:
				_place_prop(model, at, sc, shadows, null, rng)
				continue
			_rock_spot(probes, spots, model, at, sc, shadows, rng)
			# Rocks sit in groups: a couple of chips beside each one.
			var chips := rng.randi_range(1, 2) if _tier() == "high" else 0
			for k in chips:
				var off := Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.7, 0.7)) * sc * 1.6
				_rock_spot(probes, spots, ["rock_c", "pebble_rock_b", "rock_flat"][k % 3], at + off, sc * rng.randf_range(0.3, 0.5), false, rng)
	for model in spots:
		var probe: Dictionary = probes.get(model, {})
		if not probe.is_empty():
			_rock_draw(probe, spots[model])
	for model in probes:
		var probe: Dictionary = probes[model]
		if not probe.is_empty():
			(probe["node"] as Node).free()


## Poses one stone the way the field props were posed and files its shape
## under its kind. A multimesh casts as one, so the stones big enough to
## throw a shadow are filed apart from the small ones.
func _rock_spot(probes: Dictionary, spots: Dictionary, model: String, at: Vector3, scale: float, shadows: bool, rng: RandomNumberGenerator) -> void:
	if not probes.has(model):
		probes[model] = _rock_probe(model)
	var probe: Dictionary = probes[model]
	if probe.is_empty():
		return
	var node: Node3D = probe["node"]
	_rock_reset(node, probe["home"])
	_pose_prop(node, model, at, scale, rng)
	_shape_rock(node, rng)
	if not spots.has(model):
		spots[model] = {"shade": [], "plain": []}
	var group := "shade" if shadows else "plain"
	var by_group: Dictionary = spots[model]
	(by_group[group] as Array).append(node.transform)


## One stone of a kind, kept as a hidden prop: it is posed over and over to
## give every stone of that kind its shape, then thrown away.
func _rock_probe(model: String) -> Dictionary:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return {}
	var node := packed.instantiate() as Node3D
	if node == null:
		return {}
	_paint_prop(node, model)
	# The probe is posed in the tree (the tilt needs a parent), but it never
	# draws: it only carries the kind's shape.
	node.visible = false
	world_root.add_child(node)
	var home := node.transform
	var meshes: Array = []
	var locals: Array = []
	var mats: Array = []
	for mi_node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		meshes.append(mi.mesh)
		# Where the mesh sits inside the model, so an instance can be put
		# back exactly where the scene had it.
		locals.append(_chain(mi, node) * home.affine_inverse())
		mats.append(mi.material_override)
	return {"node": node, "home": home, "meshes": meshes, "locals": locals, "mats": mats}


## Puts the probe back the way the model made it, so the next stone of the
## kind starts from the model's own shape.
func _rock_reset(node: Node3D, home: Transform3D) -> void:
	node.transform = home
	node.rotation = home.basis.get_euler()
	node.scale = home.basis.get_scale()


## Draws a kind of rock: one multimesh per mesh of the model, and every
## stone of that kind an instance in it.
func _rock_draw(probe: Dictionary, groups: Dictionary) -> void:
	var meshes: Array = probe["meshes"]
	var locals: Array = probe["locals"]
	var mats: Array = probe["mats"]
	for key in groups:
		var list: Array = groups[key]
		if list.is_empty():
			continue
		var shadows := str(key) == "shade"
		for i in meshes.size():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[i]
			mm.instance_count = list.size()
			for j in list.size():
				mm.set_instance_transform(j, (list[j] as Transform3D) * (locals[i] as Transform3D))
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat: Material = mats[i]
			if mat:
				inst.material_override = mat
			world_root.add_child(inst)


## Instances every mesh of a kit model with a MultiMesh (one draw per
## surface for the whole set), keeping each mesh's offset in the model.
func _scatter_kit(rng: RandomNumberGenerator, model: String, count: int, lo: float, hi: float) -> void:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null or count <= 0:
		return
	var probe := packed.instantiate()
	if model == "stump":
		_bark(probe)
	if model == "mushroom_tall":
		_paint_mushroom(probe)
	var spots: Array[Transform3D] = []
	for _n in count:
		var at := _off_path_point(rng, 1.2)
		var sc := rng.randf_range(lo, hi)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
		spots.append(Transform3D(basis, at))
		if model == "stump":
			_contacts.append(Vector3(at.x, at.z, 0.6 * sc))
	for mi_node in probe.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := _chain(mi, probe)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = spots.size()
		for i in spots.size():
			mm.set_instance_transform(i, spots[i] * local)
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.material_override:
			inst.material_override = mi.material_override
		world_root.add_child(inst)
	probe.free()


## Breaks the kit rocks' rounded look: non-uniform stretch (tall shards,
## flat slabs), a tilt so they sit bedded in the ground, partly sunk.
func _shape_rock(node: Node3D, rng: RandomNumberGenerator) -> void:
	var shape := _shape_rock_params(rng)
	_shape_rock_apply(node, shape)
	node.position.y -= 0.08 * node.scale.y


## The shape a rock takes, drawn apart from the rock itself: the boss arena
## makes its stones long before the fight knows where they stand.
func _shape_rock_params(rng: RandomNumberGenerator) -> Dictionary:
	var kind := rng.randi() % 3
	var stretch := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.9, 1.7), rng.randf_range(0.8, 1.2))
	if kind == 1:
		stretch = Vector3(rng.randf_range(1.2, 1.7), rng.randf_range(0.45, 0.7), rng.randf_range(1.0, 1.4))
	return {
		"stretch": stretch,
		"tilt": Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)),
	}


func _shape_rock_apply(node: Node3D, shape: Dictionary) -> void:
	node.scale *= shape["stretch"]
	var tilt: Vector2 = shape["tilt"]
	node.rotate_object_local(Vector3.RIGHT, tilt.x)
	node.rotate_object_local(Vector3.FORWARD, tilt.y)


func _off_path_point(rng: RandomNumberGenerator, keep: float) -> Vector3:
	var at := _field_point(rng)
	for _try in 12:
		if path_dist(Vector2(at.x, at.z)) > keep:
			return at
		at = _field_point(rng)
	return at


## The culling grid for the grass: the playfield is cut into cells this many
## meters across and every scattered kind gets one multimesh per cell, so
## the cells the camera cannot see are skipped whole instead of every blade
## being drawn.
const CULL_CELL := 4.0
## Blades a cell should hold before the grid splits any finer. A kind with
## fewer blades than this stays in one multimesh: splitting it would cost
## more draw calls than the culling saves.
const CULL_PER_CELL := 96


## Grid size (cells across, cells deep) for a scatter of `count` blades.
func _cull_grid(count: int) -> Vector2i:
	var lo3 := _to3(HuntMap.PLAY.position)
	var span3 := _to3(HuntMap.PLAY.end) - lo3
	var area := maxf(span3.x * span3.z, 1.0)
	# Aim for a fixed number of blades per cell: the dense kinds get a fine
	# grid, where dropping an off-screen cell pays for its own draw call;
	# the sparse ones stay whole.
	var cell := maxf(CULL_CELL, sqrt(area * CULL_PER_CELL / maxf(float(count), 1.0)))
	return Vector2i(
		maxi(1, int(ceil(span3.x / cell))),
		maxi(1, int(ceil(span3.z / cell))))


func _scatter(rng: RandomNumberGenerator, model: String, count: int, lo: float, hi: float, sway: bool) -> void:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return
	var probe := packed.instantiate()
	var source := _first_mesh(probe)
	if source == null or source.mesh == null:
		probe.free()
		return
	var posed := _chain(source, probe)
	# The arena is about twice what the camera frames: big scatters are cut
	# into a grid of multimeshes so off-screen cells are culled whole. Each
	# cell carries its own transform (the node sits on the cell's corner and
	# its blades are relative to it), so the cell's bounds stay tight and
	# the engine can drop the whole cell in one go.
	var grid := _cull_grid(count)
	var cols := grid.x
	var rows := grid.y
	var cells: Array = []
	for i in cols * rows:
		cells.append([])
	var lo3 := _to3(HuntMap.PLAY.position)
	var span3 := _to3(HuntMap.PLAY.end) - lo3
	for i in count:
		var at := _off_path_point(rng, 1.0)
		var s := rng.randf_range(lo, hi)
		var spin := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		var cx := clampi(int((at.x - lo3.x) / span3.x * cols), 0, cols - 1)
		var cy := clampi(int((at.z - lo3.z) / span3.z * rows), 0, rows - 1)
		cells[cy * cols + cx].append(Transform3D(spin, at) * posed)
	var grass: ShaderMaterial = _grass_material(source) if sway else null
	if grass:
		_grass_mats.append(grass)
	for cy in rows:
		for cx in cols:
			var cell: Array = cells[cy * cols + cx]
			if cell.is_empty():
				continue
			# The cell's own corner: the node carries it and the blades in
			# the multimesh are relative to it, so the cell's bounds are the
			# bounds of its own blades.
			var step := Vector3(span3.x / float(cols), 0.0, span3.z / float(rows))
			var corner := lo3 + Vector3(float(cx), 0.0, float(cy)) * step
			var to_cell := Transform3D(Basis.IDENTITY, -corner)
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = false
			multi.mesh = source.mesh
			multi.instance_count = cell.size()
			for i in cell.size():
				multi.set_instance_transform(i, to_cell * (cell[i] as Transform3D))
			var node := MultiMeshInstance3D.new()
			node.transform = Transform3D(Basis.IDENTITY, corner)
			node.multimesh = multi
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_grass_nodes.append(node)
			# Coarser mesh LODs: blades are a few pixels tall at the hunt zoom.
			node.lod_bias = 0.35 if _tier() != "high" else 0.6
			if grass:
				node.material_override = grass
			world_root.add_child(node)
	probe.free()


## Puts a model in the world. `parent` parks the prop somewhere else than
## the field (the boss arena keeps its stones in their own hidden node).
## `rng`, when given, draws the prop yaw so seeded worlds rebuild identically.
func _place_prop(model: String, at: Vector3, scale: float, shadows: bool, parent: Node = null, rng: RandomNumberGenerator = null) -> void:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return
	var node := packed.instantiate()
	_paint_prop(node, model)
	if node is Node3D:
		_pose_prop(node as Node3D, model, at, scale, rng)
	if not shadows:
		# glTF roots are plain Node3D: switch off every mesh under the prop.
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for gi in node.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Node3D:
		(node as Node3D).set_meta("model", model)
		if model.begins_with("tree") or (model == "mushroom_tall" and scale > 2.0):
			(node as Node3D).set_meta("canopy", true)
		_props.append(node)
	if parent != null:
		parent.add_child(node)
	else:
		world_root.add_child(node)


## The materials a prop wears: bark on the logs and stumps, the rock shader
## on the stones, painted caps on the mushrooms, crisp leaves on the trees.
func _paint_prop(node: Node, model: String) -> void:
	if model in ["log", "stump"]:
		_bark(node)
	if (model.begins_with("rock") or model.begins_with("pebble_rock")) and model != "rock_lava":
		_paint_rock(node)
	if model == "mushroom_tall":
		_paint_mushroom(node)
	if model.begins_with("tree") or model.begins_with("bush"):
		_crisp_leaves(node)


## Puts a prop where it belongs: placed, sized, spun, and sitting in its own
## soft contact shadow. The spin is a full turn drawn from the builder's
## seeded rng, so a given seed lays the world out the same way every time
## (dailies, captures and movies rebuild identically). The global rng is
## only a fallback for callers with no seeded rng of their own.
func _pose_prop(node: Node3D, model: String, at: Vector3, scale: float, rng: RandomNumberGenerator = null) -> void:
	node.position = at
	var contact := {"rock": 0.75, "pebble": 0.55, "log": 1.0, "stump": 0.6, "tree": 1.1, "mushroom_tall": 0.5, "bush": 0.8}
	for key in contact.keys():
		if model.begins_with(key):
			_contacts.append(Vector3(at.x, at.z, float(contact[key]) * scale))
			break
	node.scale *= scale
	var yaw := 0.0
	if rng != null:
		yaw = rng.randf()
	else:
		yaw = randf()
	node.rotation.y = yaw * TAU


## Giant mushrooms: the kit's clay caps repainted with plum tops, freckles,
## glowing gills and rim light; lilac fibrous stems.
static var _cap_mat: ShaderMaterial
static var _stem_mat: ShaderMaterial


## Alpha-blended leaf cards smear into soft blobs from above: cut them with
## alpha scissor (with alpha-to-coverage) and deepen the green so canopies
## read as crisp clusters of leaves.
func _crisp_leaves(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null or not str(src.resource_name).to_lower().contains("lea"):
				continue
			var key := "crisp_" + str(src.get_instance_id())
			var mat: StandardMaterial3D
			if _leaf_cache.has(key):
				mat = _leaf_cache[key]
			else:
				mat = src.duplicate() as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.45
				mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				mat.albedo_color = src.albedo_color * Color(0.72, 0.82, 0.66)
				mat.roughness = 0.75
				mat.rim_enabled = true
				mat.rim = 0.35
				mat.rim_tint = 0.6
				_leaf_cache[key] = mat
			m.set_surface_override_material(i, mat)


static var _leaf_cache := {}


## One multimesh of soft dark discs under every prop: cheap contact shadow
## and ambient occlusion where the Mobile renderer has no SSAO.
func _build_contacts() -> void:
	if _contact_node:
		_contact_node.queue_free()
		_contact_node = null
	if _contacts.is_empty():
		return
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.add_point(0.55, Color(0, 0, 0, 0.3))
	grad.set_color(grad.get_point_count() - 1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.render_priority = -1
	pm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pm
	mm.instance_count = _contacts.size()
	for i in _contacts.size():
		var c := _contacts[i]
		var y := 0.03
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(c.z, 1, c.z)), Vector3(c.x, y, c.y)))
	_contact_node = MultiMeshInstance3D.new()
	_contact_node.multimesh = mm
	_contact_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(_contact_node)


func _paint_mushroom(node: Node) -> void:
	if _cap_mat == null:
		_cap_mat = ShaderMaterial.new()
		_cap_mat.shader = load("res://shaders/mushcap.gdshader")
		_stem_mat = ShaderMaterial.new()
		_stem_mat.shader = load("res://shaders/mushstem.gdshader")
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var n := m.name.to_lower()
		if n.contains("cap"):
			m.material_override = _cap_mat
		elif n.contains("stem"):
			m.material_override = _stem_mat


## A raised grassy platform with a stone rim, flowers, rocks, and a ring of
## trees and bushes behind, all from the CC0 kits already in the project.
func _pedestal_set() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_texture = load("res://assets/textures/lush_color.jpg")
	grass.normal_enabled = true
	grass.normal_texture = load("res://assets/textures/lush_normal.jpg")
	grass.uv1_triplanar = true
	grass.uv1_scale = Vector3(0.9, 0.9, 0.9)
	grass.albedo_color = Color(0.95, 1.0, 0.85)
	grass.roughness = 0.95
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/textures/rock_color.jpg")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(1.2, 1.2, 1.2)
	stone.albedo_color = Color("b9b0a4")
	stone.roughness = 0.9
	var dirt := StandardMaterial3D.new()
	dirt.albedo_texture = load("res://assets/textures/path_color.jpg")
	dirt.uv1_triplanar = true
	dirt.uv1_scale = Vector3(0.6, 0.6, 0.6)
	dirt.roughness = 1.0
	# Ground that runs to the horizon, softened by fog.
	var field := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	field.mesh = plane
	var far_grass := grass.duplicate() as StandardMaterial3D
	far_grass.uv1_scale = Vector3(0.45, 0.45, 0.45)
	far_grass.albedo_color = Color(0.82, 0.92, 0.7)
	field.material_override = far_grass
	world_root.add_child(field)
	# Stone plinth with a grassy top.
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.35
	cyl.bottom_radius = 1.5
	cyl.height = PEDESTAL_TOP
	cyl.radial_segments = 48
	base.mesh = cyl
	base.material_override = stone
	base.position = Vector3(0, PEDESTAL_TOP * 0.5, 0)
	world_root.add_child(base)
	var top := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 1.3
	cap.bottom_radius = 1.36
	cap.height = 0.06
	cap.radial_segments = 48
	top.mesh = cap
	top.material_override = grass
	top.position = Vector3(0, PEDESTAL_TOP + 0.01, 0)
	world_root.add_child(top)
	# A worn dirt apron around the plinth.
	var apron := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.3
	disc.bottom_radius = 2.3
	disc.height = 0.02
	disc.radial_segments = 48
	apron.mesh = disc
	apron.material_override = dirt
	apron.position = Vector3(0, 0.005, 0)
	world_root.add_child(apron)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dressing := [
		["rock_a", Vector3(1.75, 0, 0.9), 0.55], ["rock_b", Vector3(-1.9, 0, 0.5), 0.5],
		["pebble_rock", Vector3(0.9, 0, 1.9), 0.5], ["mushroom", Vector3(-1.3, 0, 1.55), 0.45],
		["mushroom", Vector3(1.55, 0, -0.6), 0.4], ["flower_a", Vector3(-0.95, PEDESTAL_TOP, 0.55), 0.55],
		["flower_b", Vector3(0.95, PEDESTAL_TOP, 0.45), 0.55], ["fern", Vector3(-2.2, 0, -0.6), 0.75],
		["bush_flower", Vector3(2.4, 0, -1.2), 1.0], ["bush_flower", Vector3(-2.6, 0, -1.6), 1.1],
		["log", Vector3(-2.1, 0, 1.4), 0.9], ["flower_b", Vector3(2.0, 0, 1.6), 0.7],
		# Close framing only ever shows tree trunks, so the backdrop is low
		# growth that the warm fog swallows, with trees well off to the sides.
		["tree_a", Vector3(-4.6, 0, -3.0), 2.6], ["tree_b", Vector3(5.0, 0, -3.6), 2.8],
		["bush_flower", Vector3(-1.4, 0, -3.2), 1.2], ["bush_flower", Vector3(1.2, 0, -4.4), 1.4],
		["fern", Vector3(0.2, 0, -3.0), 1.1], ["fern", Vector3(-0.9, 0, -5.2), 1.3],
		["rock_c", Vector3(-2.8, 0, -4.8), 1.1], ["bush_flower", Vector3(3.2, 0, -6.5), 1.8],
		["bush_flower", Vector3(-3.4, 0, -7.0), 1.9],
		["rock_c", Vector3(2.6, 0, -2.4), 0.9],
	]
	for row in dressing:
		_place_prop(str(row[0]), row[1], float(row[2]), true, null, rng)
	for i in 70:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.6, 4.5)
		_place_prop("grass_short" if i % 3 else "clover", Vector3(cos(ang) * r, 0, sin(ang) * r), rng.randf_range(0.5, 0.8), false, null, rng)
	for i in 14:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.5, 1.15)
		_place_prop("grass_short", Vector3(cos(ang) * r, PEDESTAL_TOP, sin(ang) * r), rng.randf_range(0.35, 0.5), false, null, rng)
	# A real forest edge behind the glade: layered trees, then a dense band
	# of bushes and tall grass, so the backdrop has depth instead of flat fog.
	var trees := ["tree_a", "tree_b", "tree_pine", "tree_pine_b", "tree_a", "tree_b"]
	for i in 16:
		var x := lerpf(-9.0, 9.0, float(i) / 15.0) + rng.randf_range(-0.6, 0.6)
		var z := -6.5 - rng.randf_range(0.0, 4.5) - absf(x) * 0.1
		_place_prop(trees[i % trees.size()], Vector3(x, 0, z), rng.randf_range(2.4, 3.4), true, null, rng)
	for i in 18:
		var x := rng.randf_range(-7.5, 7.5)
		var z := rng.randf_range(-5.8, -3.6)
		_place_prop("bush_flower", Vector3(x, 0, z), rng.randf_range(1.1, 1.8), true, null, rng)
	for i in 120:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(2.2, 6.5)
		var kind := "grass_tall" if i % 3 == 0 else ("grass_wispy" if i % 3 == 1 else "fern")
		_place_prop(kind, Vector3(cos(ang) * r, 0, sin(ang) * r), rng.randf_range(0.7, 1.15), false, null, rng)
	for i in 26:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.7, 3.6)
		_place_prop(["flower_a", "flower_b", "flower_warm", "pebble_rock_b"][i % 4], Vector3(cos(ang) * r, 0, sin(ang) * r), rng.randf_range(0.4, 0.65), false, null, rng)
	# The glade's trees are in place: cache them for the canopy fade.
	_cache_canopy()


func _field_point(rng: RandomNumberGenerator) -> Vector3:
	var f := HuntMap.PLAY.grow_individual(-8.0, -22.0, -8.0, 8.0)
	return _to3(Vector2(rng.randf_range(f.position.x, f.end.x), rng.randf_range(f.position.y, f.end.y)))


func _rim_point(rng: RandomNumberGenerator) -> Vector3:
	# A band hugging the arena edge, mostly just outside the playable rect.
	var p := HuntMap.PLAY
	var edge := rng.randi() % 4
	var x := rng.randf_range(p.position.x - 30.0, p.end.x + 30.0)
	var y := rng.randf_range(p.position.y - 30.0, p.end.y + 40.0)
	match edge:
		0:
			x = rng.randf_range(p.position.x - 40.0, p.position.x + 90.0)
		1:
			x = rng.randf_range(p.end.x - 90.0, p.end.x + 40.0)
		2:
			y = rng.randf_range(p.position.y - 30.0, p.position.y + 100.0)
		_:
			y = rng.randf_range(p.end.y - 140.0, p.end.y + 60.0)
	return _to3(Vector2(x, y))


func _body_for(actor: RunSim.Actor) -> Node3D:
	if _bodies.has(actor.id):
		return _bodies[actor.id]
	var meters := HERO_METERS
	if actor.kind == "hero" and actor.team == 0:
		# The wider hunt camera shrank the hero; it gets a bump over the cast.
		meters = HERO_METERS * HERO_BOOST
	elif actor.kind == "boss":
		meters = BOSS_METERS
	elif actor.kind == "ally":
		meters = HERO_METERS * 0.8
	elif actor.kind != "hero":
		# Rank-and-file critters stand roughly hero height so they read.
		# A touch bigger than before so mobs read at the pulled-back camera.
		meters = clampf(actor.radius / 40.0, 0.5, 0.66) * HERO_METERS * 1.12
	var body := _spawn_model(actor.sprite, meters)
	# Who this body is: the hero colour keys the cast telegraph, the reach
	# sets the aim lane, and the id keys the impact cooldown.
	body.set_meta("sprite", actor.sprite)
	body.set_meta("kind", actor.kind)
	body.set_meta("role", actor.role)
	body.set_meta("reach", actor.range)
	body.set_meta("actor_id", actor.id)
	# Outlines keep silhouettes readable from the far camera: a dark hairline
	# on the hero (its ring marks it), deep red for anything hostile.
	if actor.kind == "hero" and actor.team == 0:
		_bolt = Gear3D.KITS.get(actor.sprite, {}).get("bolt", Color(0, 0, 0, 0))
		if Gear3D.has_kit(actor.sprite):
			# Dark plate on dark ground: a steel-blue hairline, a cool
			# fresnel rim in the armour shader and a soft key light that
			# follows the hero (no shadows, short range).
			# Crisp light-steel keyline + stronger cool fresnel: the knight
			# never melts into brown paths, bare leather included.
			# Showcase lock: crisp dark hairline (a fat pale-blue shell
			# smeared Corvin's thin cloth into a glowing blob); the rim
			# light below carries the separation.
			_outline(body, Color("101418"), 0.007)
			Gear3D.set_rim(body, Color(0.22, 0.34, 0.5))
			if not is_instance_valid(_hero_rim):
				# Cool back light (hero layer only): steel speculars on the
				# shoulders and helm edge, the way a moonlit rim reads.
				_hero_rim = OmniLight3D.new()
				_hero_rim.light_color = Color("9cc4ff")
				_hero_rim.light_energy = 3.2
				_hero_rim.omni_range = 7.0
				_hero_rim.omni_attenuation = 1.1
				_hero_rim.light_specular = 1.6
				_hero_rim.shadow_enabled = false
				_hero_rim.light_cull_mask = 1 << 19
				world_root.add_child(_hero_rim)
			if not is_instance_valid(_hero_key):
				_hero_key = OmniLight3D.new()
				_hero_key.light_color = Color("fff1dc")
				_hero_key.light_energy = 2.2
				_hero_key.omni_range = 7.5
				_hero_key.omni_attenuation = 1.2
				_hero_key.light_specular = 0.9
				_hero_key.shadow_enabled = false
				# Lights the hero only (layer 20): no bright pool on the ground.
				_hero_key.light_cull_mask = 1 << 19
				world_root.add_child(_hero_key)
			for gi in body.find_children("*", "GeometryInstance3D", true, false):
				(gi as GeometryInstance3D).layers |= 1 << 19
		else:
			_outline(body, Color("1a0806"), 0.011)
		_hero_glow(body)
		if Gear3D.has_kit(actor.sprite) and int(Gear3D.tiers(actor.sprite)["armor"]) >= 3:
			# Runebound plate: the hunt rim burns ember instead of steel blue,
			# so the top tier reads at the far camera, not only up close.
			var ember := _glow_mat.duplicate() as ShaderMaterial
			var rc: Color = Gear3D.KITS[actor.sprite].get("rune", Color(1.0, 0.4, 0.1))
			ember.set_shader_parameter("rim_color", Vector3(rc.r, rc.g, rc.b))
			ember.set_shader_parameter("rim_strength", 0.8)
			ember.set_shader_parameter("rim_power", 2.6)
			ember.next_pass = _xray_mat
			for m in body.find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).material_overlay == _glow_mat:
					m.set_meta("overlay", ember)
					(m as MeshInstance3D).material_overlay = ember
			_rune_aura(body, rc)
		if Gear3D.has_kit(actor.sprite) and int(Gear3D.tiers(actor.sprite)["weapon"]) >= 3:
			var rc2: Color = Gear3D.KITS[actor.sprite].get("rune", Color(1.0, 0.4, 0.1))
			var gm := body.find_child("GearMain", true, false) as Node3D
			if gm == null:
				# Own-mesh blades (Mordrek) mount as GearMain too; claws and
				# staffs have no trail.
				pass
			else:
				var trail := BladeTrail.new()
				body.add_child(trail)
				trail.bind.call_deferred(gm, rc2)
	elif actor.kind == "ally":
		# Summoned spirit: the hero's cool rim glow, no hostile ring.
		_hero_glow(body)
	elif actor.kind == "boss":
		# No ink line on bosses: their size carries the silhouette and the
		# outline read as a thick toon stroke round the PBR cap.
		pass
	elif actor.kind != "hero":
		# One draw per critter: merged mesh, shared material with the ink
		# edge and rim folded in (see _mob_share), and the contact shadow
		# drawn by the shared minion MultiMesh (_sync_mob_decals).
		_mob_share(body, actor.sprite)
		body.set_meta("mob", true)
		body.set_meta("decal_size", meters * 1.1)
		if _tier() != "high":
			# Minions already sit on a contact-shadow decal; a real shadow
			# per critter costs a draw per split for little gain on phones.
			for gi in body.find_children("*", "GeometryInstance3D", true, false):
				(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if actor.goblin:
		# The treasure goblin wears a gold ring on the ground: a green
		# critter running for its life still reads as the goblin across a
		# clearing, and the ring is the one mark that says so.
		var hoard := _decal(meters * 1.2, {
			"ring_color": Color(0.98, 0.8, 0.34, 0.6),
			"ring_radius": 0.34,
			"ring_width": 0.018,
			"ring_glow": 0.55,
			"shadow_alpha": 0.0,
			"shadow_radius": 0.34,
			"pulse": 0.5,
			"ring_fade": 1.0,
		})
		hoard.position.y = 0.03
		body.add_child(hoard)
	if actor.kind == "boss":
		# The boss gets its own soft contact shadow. Its threat ring is a thin,
		# soft, low-opacity line that fades in only when the critter is close
		# to the hero or winding up (see _threat_rings).
		var boss := actor.kind == "boss"
		var blob := _decal(meters * (0.95 if boss else 1.1), {
			"ring_color": Color(0.95, 0.22, 0.12, 0.42 if boss else 0.36),
			"ring_radius": 0.4, "ring_width": 0.006 if boss else 0.012, "ring_glow": 0.6,
			"shadow_alpha": 0.78 if boss else 0.7, "shadow_radius": 0.36 if boss else 0.44,
			"pulse": 1.0, "ring_fade": 0.0,
		})
		blob.position.y = 0.03
		body.add_child(blob)
		body.set_meta("threat", blob.material_override)
	body.rotation.y = _yaw(actor.facing, body)
	actor_root.add_child(body)
	_bodies[actor.id] = body
	if actor.kind == "hero" and actor.team == 0:
		_center_posed(body, 0.45)
	if actor.kind == "boss":
		_boss_landing(body)
		_boss_glow(body)
		_boss_arena(body.position)
	return body


## --- Boss arena ---------------------------------------------------------
## The boss fight gets a place: a broken ring of standing stones rises
## around where the boss lands, with gnarled roots between them and a
## fringe of giant mushrooms and ferns outside, so the wider boss camera
## frames an arena instead of an empty field.
##
## The arena is built while the hunt runs on, not when the boss lands: its
## props are made a couple per frame, parked out of sight, and the fight
## only stands them up and shows them. Making them on the boss's first
## frame put a whole scene of fresh glTF instantiations in one go, which
## hitched right on the fight's opening beat.
const ARENA_PROPS_PER_FRAME := 2
## The explore lair can need the sim's ring stones on top of its own
## landmarks, so the pool of stones is made deeper than the landmarks.
const ARENA_POOL_SPARE := 14

## Arenas by boss type (the biome's boss), so the props are built once and
## the next fight reuses them instead of building them again.
var _arena_cache := {}
## The arena of this run: which boss it belongs to, and how much of it is
## built.
var _arena_key := ""
var _arena_built := false


## Queue the arena for this boss type: the explore map's lair gets the
## sim's own stones, the arena hunt gets the broken ring. The props are
## made while the hunt runs on, so the fight's first frame only has to
## stand them up.
func _arena_prepare(sim: RunSim) -> void:
	if sim.explore:
		_arena_prepare_sim(sim)
	else:
		_arena_prepare_ring()


## The explore map's lair: a pool of standing stones, deep enough for the
## lair's landmarks and for the ring the sim draws around the boss.
func _arena_prepare_sim(sim: RunSim) -> void:
	var key := "sim:" + _biome
	if _arena_cache.has(key):
		_arena_key = key
		return
	_arena_prepare_key(key, _arena_pool_slots(_arena_lair_stones(sim.map) + ARENA_POOL_SPARE))


## The arena hunt's ring: the same broken circle for every boss.
func _arena_prepare_ring() -> void:
	var key := "ring:" + _biome
	if _arena_cache.has(key):
		_arena_key = key
		return
	_arena_prepare_key(key, _arena_ring_slots())


func _arena_prepare_key(key: String, slots: Array) -> void:
	_arena_key = key
	if _arena_cache.has(key):
		return
	var root := Node3D.new()
	root.name = "BossArena"
	root.visible = false
	world_root.add_child(root)
	_arena_cache[key] = {"root": root, "slots": slots, "made": 0}


## Drop the arenas of the last run: the props belong to the world they
## were built for.
func _arena_reset() -> void:
	for key in _arena_cache.keys():
		var root: Node3D = _arena_cache[key]["root"]
		if is_instance_valid(root):
			root.queue_free()
	_arena_cache.clear()
	_arena_key = ""


func _arena_now() -> Dictionary:
	if _arena_key == "" or not _arena_cache.has(_arena_key):
		return {}
	return _arena_cache[_arena_key]


## Make a couple of the parked arena props per frame: the work is the same,
## but no single frame carries the whole lot.
func _arena_build_step() -> void:
	var arena := _arena_now()
	if arena.is_empty():
		return
	var slots: Array = arena["slots"]
	var made := int(arena["made"])
	var budget := ARENA_PROPS_PER_FRAME
	while made < slots.size() and budget > 0:
		_arena_make(slots[made], arena["root"])
		made += 1
		budget -= 1
	arena["made"] = made


## Make the rest of the arena at once. Only a boss that arrived before the
## hunt had time to build the props would need this.
func _arena_build_all() -> void:
	var arena := _arena_now()
	if arena.is_empty():
		return
	var slots: Array = arena["slots"]
	var made := int(arena["made"])
	while made < slots.size():
		_arena_make(slots[made], arena["root"])
		made += 1
	arena["made"] = made


## Make one arena prop: the model and its paint, plus the shape and the
## stance the layout gives it. It waits at the origin until the fight
## stands it up.
func _arena_make(slot: Dictionary, root: Node3D) -> void:
	var count := _props.size()
	_place_prop(str(slot["model"]), Vector3.ZERO, float(slot["scale"]), bool(slot["shadows"]), root)
	if _props.size() == count:
		return
	var node: Node3D = _props[-1]
	if slot.has("stretch"):
		node.scale *= slot["stretch"]
	if slot.has("rot"):
		node.rotation = slot["rot"]
	if slot.has("shape"):
		_shape_rock_apply(node, slot["shape"])
	# The arena is not field dressing: a parked prop stays out of the
	# field's bookkeeping until the fight stands it up.
	_props.erase(node)
	slot["node"] = node


## The arena hunt's ring: a broken circle of tall menhirs with low slabs
## between them and a fringe of mushrooms and ferns outside. The stones are
## laid out around the origin; the fight gives the ring its centre and its
## radius.
func _arena_ring_slots() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var slots: Array = []
	var count := 15
	for i in count:
		if i % 5 == 4:
			continue  # gaps so the ring reads as old and broken
		var ang := TAU * float(i) / float(count) + rng.randf_range(-0.08, 0.08)
		# Tall, leaning menhirs.
		slots.append({
			"model": ["rock_a", "rock_b"][i % 2],
			"ang": ang,
			"delta": rng.randf_range(-0.4, 0.4),
			"scale": rng.randf_range(2.8, 3.4),
			"stretch": Vector3(0.7, rng.randf_range(1.8, 2.4), 0.65),
			"rot": Vector3(rng.randf_range(-0.12, 0.12), ang, rng.randf_range(-0.12, 0.12)),
			"shadows": i % 3 == 0,
			"rise": true,
			"order": float(i),
			"in_props": true,
		})
		# A low rock slab between neighbouring stones, sunk like a root.
		if i % 2 == 0:
			slots.append({
				"model": "rock_flat",
				"ang": ang + PI / float(count),
				"delta": -0.4,
				"scale": rng.randf_range(1.6, 2.2),
				"shape": _shape_rock_params(rng),
				"shadows": false,
				"rise": false,
				"in_props": true,
			})
	# Outer fringe: big mushrooms and ferns just beyond the stones.
	for i in 10:
		slots.append({
			"model": "mushroom_tall" if i % 3 != 2 else "bush_flower",
			"ang": TAU * float(i) / 10.0 + 0.3,
			"delta": rng.randf_range(1.6, 3.2),
			"scale": rng.randf_range(1.6, 2.6),
			"shadows": false,
			"rise": false,
			"in_props": true,
		})
	return slots


## The explore lair's stones: one standing stone per stone the sim put
## down, drawn from a pool made ahead of the fight. The pool is deep
## enough for the lair's landmarks and for the ring the sim draws around
## the boss, so the fight never has to make a prop.
func _arena_pool_slots(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var slots: Array = []
	for i in count:
		slots.append({
			"model": ["rock_a", "rock_b"][i % 2],
			"scale": rng.randf_range(2.8, 3.4),
			"stretch": Vector3(0.7, rng.randf_range(1.8, 2.4), 0.65),
			"rot": Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)),
			"shadows": i % 3 == 0,
			"rise": true,
			"order": float(i),
			"in_props": false,
		})
	return slots


## How many of the map's landmarks stand close enough to the lair to be
## part of the fight's ground.
func _arena_lair_stones(map: HuntMap) -> int:
	var n := 0
	for l in map.landmarks:
		var p: Vector2 = l["pos"]
		if p.distance_to(map.lair) <= map.lair_r + 200.0:
			n += 1
	return n


## Stand the arena up around the fight: the parked props are put where
## they belong, and the standing stones rise as the boss drops.
func _boss_arena(center: Vector3) -> void:
	if _arena_built or _mode != "hunt":
		return
	_arena_built = true
	if _sim_ref != null and _sim_ref.explore:
		_arena_from_sim(_sim_ref)
		_cache_canopy()
		return
	_arena_prepare_ring()
	_arena_build_all()
	var arena := _arena_now()
	if arena.is_empty():
		return
	# Ring the whole fight: centred between the landing spot and the hero,
	# wide enough that both stand inside it.
	var radius := 10.0
	if _mark != null:
		var hero := Vector3(_mark.global_position.x, 0, _mark.global_position.z)
		radius = clampf(center.distance_to(hero) * 0.5 + 7.5, 10.0, 13.0)
		center = center.lerp(hero, 0.5)
	var slots: Array = arena["slots"]
	for slot in slots:
		var node: Node3D = slot.get("node")
		if node == null:
			continue
		var ang := float(slot["ang"])
		var at := center + Vector3(cos(ang), 0, sin(ang)) * (radius + float(slot["delta"]))
		_arena_stand(slot, node, at)
		if bool(slot.get("in_props", false)):
			# The ring is part of the field now, so the near-hero hide and
			# the canopy fade treat it like the rest of the props.
			_props.append(node)
	arena["root"].visible = true
	# Arena props joined the field: refresh the canopy cache.
	_cache_canopy()


## Put a parked prop where it belongs: the standing stones start below the
## ground and rise while the boss drops.
func _arena_stand(slot: Dictionary, node: Node3D, at: Vector3) -> void:
	if slot.has("shape"):
		# The slab is bedded in the ground, not standing on it.
		at.y -= 0.08 * node.scale.y
	node.position = at
	node.visible = true
	if not bool(slot.get("rise", false)):
		return
	var rest: Vector3 = at
	node.position = rest - Vector3(0, 2.6, 0)
	var tw := create_tween()
	# The ring rises while the boss drops, so the intro shows it.
	tw.tween_interval(0.03 * float(slot.get("order", 0.0)))
	tw.tween_property(node, "position", rest, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Boss wind-up glow: an additive hot rim over the whole body, driven by
## the sim's wind-up state so the attack telegraphs on the boss itself.
func _boss_glow(body: Node3D) -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform float amount = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = vec3(1.0, 0.36, 0.1) * (0.25 + rim * 1.6) * amount;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("amount", 0.0)
	body.set_meta("windup_amt", 0.0)
	# The overlay is an extra pass (a draw per surface), so it is attached
	# only while the glow shows (see _boss_fx), not for the whole fight.
	var meshes: Array = []
	for m in body.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).material_overlay == null and not str(m.name).begins_with("Catch"):
			meshes.append(m)
	body.set_meta("windup_meshes", meshes)
	body.set_meta("windup_on", false)
	body.set_meta("windup_mat", mat)


## Idle sway (a slow, heavy rock side to side) and the wind-up glow pulse.
func _boss_fx(body: Node3D, actor: RunSim.Actor) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var winding := actor.boss_state == "windup"
	body.rotation.z = sin(now * 1.4) * 0.035 + (sin(now * 22.0) * 0.02 if winding else 0.0)
	body.rotation.x = sin(now * 0.9 + 1.0) * 0.02 - (0.06 if winding else 0.0)
	var mat: ShaderMaterial = body.get_meta("windup_mat", null)
	if mat != null:
		var cur := float(body.get_meta("windup_amt", 0.0))
		var want := (0.55 + 0.45 * sin(now * 14.0)) if winding else 0.0
		cur = move_toward(cur, want, 0.12)
		body.set_meta("windup_amt", cur)
		mat.set_shader_parameter("amount", cur)
		var on := cur > 0.002
		if on != bool(body.get_meta("windup_on", false)):
			body.set_meta("windup_on", on)
			for m in body.get_meta("windup_meshes", []):
				if is_instance_valid(m):
					(m as MeshInstance3D).material_overlay = mat if on else null


## Mobs: a warm fresnel rim baked into their own materials (no extra
## pass, so no extra draw calls), plus a little more roughness so the
## surface reads as painted skin rather than plastic. One shared copy per
## source material keeps instances batching together.
## Minion batching. The first critter of a sprite builds the shared parts:
## a merged mesh when the model is several skinned pieces of flat colour
## (the owl is 8 meshes / 10 surfaces), and one ShaderMaterial per surface
## (mob.gdshader: paint, rim and ink edge in one pass). Every later critter
## of that sprite reuses them, so a minion is one draw and one material.
var _mob_cache := {}
func _mob_share(body: Node3D, sprite: String) -> void:
	if body.get_child_count() == 0:
		return
	var model := body.get_child(0)
	var meshes: Array = []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.visible and not str(m.name).begins_with("Catch") and not str(m.name).begins_with("GlowEye") and not str(m.name).begins_with("Armor"):
			meshes.append(m)
	if meshes.is_empty():
		return
	var entry: Dictionary = _mob_cache.get(sprite, {})
	if entry.is_empty():
		entry = _mob_build(meshes, sprite)
		_mob_cache[sprite] = entry
	if entry.has("merged"):
		var keep := meshes[0] as MeshInstance3D
		keep.mesh = entry["merged"]
		for i in (entry["mats"] as Array).size():
			keep.set_surface_override_material(i, entry["mats"][i])
		for k in range(1, meshes.size()):
			(meshes[k] as Node).get_parent().remove_child(meshes[k])
			(meshes[k] as Node).queue_free()
		return
	var mats: Array = entry["mats"]
	var n := 0
	for m in meshes:
		for i in (m as MeshInstance3D).mesh.get_surface_count():
			if n < mats.size() and mats[n] != null:
				(m as MeshInstance3D).set_surface_override_material(i, mats[n])
			n += 1


func _mob_build(meshes: Array, sprite: String) -> Dictionary:
	var first := meshes[0] as MeshInstance3D
	var can_merge := meshes.size() > 1
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.skin != first.skin or mi.skeleton != first.skeleton or mi.get_parent() != first.get_parent() or mi.transform != first.transform or mi.mesh.get_blend_shape_count() > 0:
			can_merge = false
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if not (mat is StandardMaterial3D) or (mat as StandardMaterial3D).albedo_texture != null or mi.mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
				can_merge = false
	if can_merge:
		var acc := {}
		var flags := 0
		for m in meshes:
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(i)
				flags |= mi.mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
				# The part's own colour (beak, eyes, face) under the biome tint,
				# instead of one flat tint over the whole critter.
				var own := mi.mesh.surface_get_material(i) as StandardMaterial3D
				var col := (own.albedo_color if own else Color.WHITE) * Cast3D.tint(sprite)
				_mob_append(acc, arr, col.srgb_to_linear())
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = acc["v"]
		out[Mesh.ARRAY_NORMAL] = acc["n"]
		if acc.has("t"):
			out[Mesh.ARRAY_TANGENT] = acc["t"]
		out[Mesh.ARRAY_COLOR] = acc["c"]
		out[Mesh.ARRAY_BONES] = acc["b"]
		out[Mesh.ARRAY_WEIGHTS] = acc["w"]
		out[Mesh.ARRAY_INDEX] = acc["i"]
		var merged := ArrayMesh.new()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, flags)
		var mat := _mob_mat(first.get_active_material(0) as StandardMaterial3D, true, sprite)
		return {"merged": merged, "mats": [mat]}
	var mats: Array = []
	for m in meshes:
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			mats.append(_mob_mat(src as StandardMaterial3D, false, sprite) if src is StandardMaterial3D else null)
	return {"mats": mats}


func _mob_append(acc: Dictionary, arr: Array, col: Color) -> void:
	if acc.is_empty():
		acc["v"] = PackedVector3Array()
		acc["n"] = PackedVector3Array()
		acc["t"] = PackedFloat32Array()
		acc["c"] = PackedColorArray()
		acc["b"] = PackedInt32Array()
		acc["w"] = PackedFloat32Array()
		acc["i"] = PackedInt32Array()
	var base: int = (acc["v"] as PackedVector3Array).size()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	acc["v"].append_array(verts)
	acc["n"].append_array(arr[Mesh.ARRAY_NORMAL])
	if arr[Mesh.ARRAY_TANGENT] != null and acc.has("t"):
		acc["t"].append_array(arr[Mesh.ARRAY_TANGENT])
	else:
		acc.erase("t")
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(col)
	acc["c"].append_array(cols)
	acc["b"].append_array(arr[Mesh.ARRAY_BONES])
	acc["w"].append_array(arr[Mesh.ARRAY_WEIGHTS])
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null:
		idx = PackedInt32Array(range(verts.size()))
	for k in (idx as PackedInt32Array):
		acc["i"].append(k + base)


static var _mob_shader: Shader
func _mob_mat(src: StandardMaterial3D, vcol: bool, sprite := "") -> ShaderMaterial:
	if _mob_shader == null:
		_mob_shader = load("res://shaders/mob.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _mob_shader
	mat.set_shader_parameter("albedo", Color.WHITE if vcol else src.albedo_color)
	# Merged parts carry their own colour; keep the paint lift on top.
	if vcol and src.detail_enabled:
		mat.set_shader_parameter("albedo", Color(1.12, 1.1, 1.08))
	mat.set_shader_parameter("use_vcol", vcol)
	if src.albedo_texture != null:
		mat.set_shader_parameter("use_tex", true)
		mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("use_grain", src.detail_enabled)
	if src.detail_enabled:
		mat.set_shader_parameter("grain_tex", src.detail_albedo)
		mat.set_shader_parameter("grain_nrm", src.detail_normal)
		mat.set_shader_parameter("grain_scale", src.uv2_scale.x)
	mat.set_shader_parameter("roughness", maxf(src.roughness, 0.7))
	mat.set_shader_parameter("specular", src.metallic_specular)
	mat.set_shader_parameter("rim", 0.55)
	mat.set_shader_parameter("rim_tint", 0.35)
	mat.set_shader_parameter("sss", src.subsurf_scatter_strength if src.subsurf_scatter_enabled and _tier() == "high" else 0.0)
	mat.set_shader_parameter("clearcoat", src.clearcoat if src.clearcoat_enabled else 0.0)
	mat.set_shader_parameter("ink_color", Color("3a0a08"))
	if _biome == "mushroom":
		# Night biome: a cool fill rim so small foes never read as black blobs.
		mat.set_shader_parameter("rim", 0.85)
		mat.set_shader_parameter("rim_glow", Color(0.72, 0.8, 1.0, 0.55))
	if Cast3D.dark(sprite) != "":
		# Dark-furred feral beasts went to black blobs at the far camera: lift
		# the fur, thin the ink, and wrap them in a corruption-coloured
		# fresnel glow that reads against the grass.
		mat.set_shader_parameter("albedo", src.albedo_color * 1.9)
		mat.set_shader_parameter("ink", 0.55)
		mat.set_shader_parameter("rim", 0.8)
		var g := Cast3D.feral_color(sprite)
		mat.set_shader_parameter("rim_glow", Color(g.r, g.g, g.b, 0.9))
	return mat


## Every minion's soft contact shadow and threat ring in one MultiMesh draw.
## Per instance: transform (position, size) and custom data (ring fade,
## shadow fade while it dies).
var _mob_mm: MultiMeshInstance3D
const MOB_DECALS := 96
func _sync_mob_decals(sim: RunSim, hero_at: Vector3) -> void:
	if _mob_mm == null or not is_instance_valid(_mob_mm):
		if _decal_shader == null:
			_decal_shader = load("res://shaders/ground_decal.gdshader")
		var quad := QuadMesh.new()
		quad.orientation = PlaneMesh.FACE_Y
		quad.size = Vector2.ONE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = MOB_DECALS
		mm.visible_instance_count = 0
		var mat := ShaderMaterial.new()
		mat.shader = _decal_shader
		var params := {"ring_color": Color(0.95, 0.22, 0.12, 0.36), "ring_radius": 0.4, "ring_width": 0.012,
				"ring_glow": 0.6, "shadow_alpha": 0.7, "shadow_radius": 0.44, "pulse": 1.0, "per_instance": true}
		for key in params:
			mat.set_shader_parameter(key, params[key])
		_mob_mm = MultiMeshInstance3D.new()
		_mob_mm.multimesh = mm
		_mob_mm.material_override = mat
		_mob_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mob_mm.custom_aabb = AABB(Vector3(-500, -5, -500), Vector3(1000, 10, 1000))
		_mob_mm.set_meta("decal", true)
		actor_root.add_child(_mob_mm)
	var wind := {}
	for actor in sim.actors:
		if actor.kind == "minion" and actor.boss_state == "windup":
			wind[actor.id] = true
	var mm := _mob_mm.multimesh
	var n := 0
	for id in _bodies:
		var body: Node3D = _bodies[id]
		if not body.has_meta("mob") or n >= MOB_DECALS or not body.visible:
			continue
		var dying := bool(body.get_meta("dying", false))
		var d := Vector2(body.position.x - hero_at.x, body.position.z - hero_at.z).length()
		# A faint red ring always marks hostiles at the far camera; it
		# brightens when they close in or wind up.
		var want := 0.0 if dying else (1.0 if d < 3.6 or wind.has(id) else 0.45)
		var ring := lerpf(float(body.get_meta("ring", 0.0)), want, 0.12)
		body.set_meta("ring", ring)
		var size := float(body.get_meta("decal_size", 1.0))
		var pos := body.position + Vector3(0, 0.03, 0)
		mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(size, 1.0, size)), pos))
		mm.set_instance_custom_data(n, Color(ring, 1.0 - float(body.get_meta("fade", 0.0)), 0, 0))
		n += 1
	mm.visible_instance_count = n


var _rim_cache := {}
func _mob_rim(body: Node3D) -> void:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var src := m.get_active_material(si)
			if not (src is StandardMaterial3D):
				continue
			var mat: StandardMaterial3D = _rim_cache.get(src)
			if mat == null:
				mat = (src as StandardMaterial3D).duplicate()
				mat.rim_enabled = true
				mat.rim = 0.55
				mat.rim_tint = 0.35
				mat.roughness = maxf(mat.roughness, 0.7)
				_rim_cache[src] = mat
			m.set_surface_override_material(si, mat)


## Hunt hero only: a cool fresnel rim plus a faint warm lift, added over
## the lit surface, so the hero reads off the ground at the far zoom.
var _glow_mat: ShaderMaterial
func _hero_glow(body: Node3D) -> void:
	if _glow_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec3 rim_color = vec3(0.62, 0.86, 1.0);
uniform float rim_power = 3.2;
uniform float rim_strength = 0.3;
uniform vec3 lift = vec3(0.022, 0.008, 0.006);
void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Fade out at exact grazing: a flat wing turned edge-on would otherwise
	// light up blue across its whole surface for a frame.
	float f = pow(1.0 - ndv, rim_power) * smoothstep(0.0, 0.14, ndv);
	ALBEDO = rim_color * f * rim_strength + lift;
}
"""
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = sh
		# X-ray: drawn with depth test off, but only where the scene depth
		# says something (a boss cap, a tree) sits in front of the hero, so
		# Ember shows through as a warm rim silhouette when occluded.
		var xs := Shader.new()
		xs.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_test_inverted, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec3 xray_color = vec3(1.0, 0.36, 0.03);
uniform float amount = 0.0;
void fragment() {
	// depth_test_inverted: this pass only lands where something already
	// in the depth buffer is nearer than the hero, i.e. where it is hidden.
	float ahead = 1.0;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float r = 1.0 - ndv;
	// A saturated orange outer line with a dark inner line just inside it,
	// so the silhouette holds up over the boss's pale cap.
	float outer = smoothstep(0.7, 0.92, r);
	float inner = smoothstep(0.48, 0.58, r) * (1.0 - smoothstep(0.64, 0.72, r));
	ALBEDO = mix(vec3(0.12, 0.03, 0.01), xray_color, outer / max(outer + inner, 1e-3));
	ALPHA = max(outer * 0.98, inner * 0.8) * amount * ahead;
}
"""
		_xray_mat = ShaderMaterial.new()
		_xray_mat.shader = xs
		_xray_mat.render_priority = 10
		_glow_mat.next_pass = _xray_mat
	for m in body.find_children("*", "MeshInstance3D", true, false):
		if str(m.name).begins_with("Catch"):
			continue
		m.set_meta("overlay", _glow_mat)
		(m as MeshInstance3D).material_overlay = _glow_mat


## X-ray: when the boss stands between the camera and the hero (the hero is
## further back and overlaps the boss's body on screen), the hero's overlay
## pass draws a warm rim silhouette through it. Gated on the CPU, so it
## needs no depth texture and costs nothing when clear.
func _update_xray(boss_up: bool, boss_at: Vector3, hero_at: Vector3, sim: RunSim = null) -> void:
	if _xray_mat == null or camera == null:
		return
	var want := 0.0
	# Mobs standing in front of the hero (nearer the camera) and over its
	# body on screen also switch the silhouette on.
	if sim != null:
		var hs := camera.unproject_position(hero_at + Vector3(0, HERO_METERS * 0.4, 0))
		var reach := absf(camera.unproject_position(hero_at).y - camera.unproject_position(hero_at + Vector3(0, HERO_METERS, 0)).y) * 0.55
		for actor in sim.actors:
			if not actor.alive or actor.team == 0 or actor.kind == "boss":
				continue
			var at := _to3(actor.pos)
			# Depth: the mob must stand nearer the camera than the hero.
			if at.z <= hero_at.z + 0.25:
				continue
			if camera.unproject_position(at + Vector3(0, HERO_METERS * 0.3, 0)).distance_to(hs) < reach * 0.7:
				want = 1.0
				break
	if boss_up and hero_at.z < boss_at.z:
		var hs := camera.unproject_position(hero_at + Vector3(0, HERO_METERS * 0.45, 0))
		var top := camera.unproject_position(boss_at + Vector3(0, BOSS_METERS * 1.05, 0))
		var foot := camera.unproject_position(boss_at)
		var half_w := absf(foot.y - top.y) * 0.42
		if hs.y > top.y and hs.y < foot.y and absf(hs.x - foot.x) < half_w:
			want = 1.0
	_xray = move_toward(_xray, want, 0.12)
	_xray_mat.set_shader_parameter("amount", _xray)


## Threat rings show only where they matter: critters near the hero and
## anything winding up an attack. They ease in and out rather than pop.
func _threat_rings(sim: RunSim, hero_at: Vector3) -> void:
	for actor in sim.actors:
		if actor.team == 0 or not _bodies.has(actor.id):
			continue
		var body: Node3D = _bodies[actor.id]
		if not body.has_meta("threat"):
			continue
		var mat: ShaderMaterial = body.get_meta("threat")
		var near := 5.0 if actor.kind == "boss" else 3.6
		var d := Vector2(body.position.x - hero_at.x, body.position.z - hero_at.z).length()
		var want := 0.0
		if actor.alive and (d < near + (BOSS_METERS * 0.4 if actor.kind == "boss" else 0.0) or actor.boss_state == "windup"):
			want = 1.0
		var now := float(mat.get_shader_parameter("ring_fade"))
		mat.set_shader_parameter("ring_fade", lerpf(now, want, 0.12))


## The boss drops in from above and slams down in a ring of dust. The screen
## rumble is timed to the impact (RunScreen adds it on "boss_in").
const BOSS_DROP_TIME := 0.42
func _boss_landing(body: Node3D) -> void:
	if body.get_child_count() == 0:
		return
	var model := body.get_child(0) as Node3D
	var rest := model.position
	model.position = rest + Vector3(0, 9.0, 0)
	var tw := create_tween()
	tw.tween_property(model, "position", rest, BOSS_DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(body):
			return
		for k in 3:
			var dust := _puff(Color("a88a66"), 48, 1.4)
			var pm := dust.process_material as ParticleProcessMaterial
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_radius = BOSS_METERS * (0.3 + 0.12 * k)
			pm.emission_ring_inner_radius = BOSS_METERS * 0.2
			pm.emission_ring_height = 0.1
			pm.direction = Vector3(0, 0.35, 0)
			pm.spread = 80.0
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 5.5
			pm.damping_min = 2.0
			pm.damping_max = 4.0
			pm.gravity = Vector3(0, -0.6, 0)
			pm.scale_min = 3.0
			pm.scale_max = 6.0
			world_root.add_child(dust)
			dust.global_position = body.global_position + Vector3(0, 0.2, 0)
			dust.emitting = true
			get_tree().create_timer(2.0).timeout.connect(dust.queue_free)
		var squash := create_tween()
		squash.tween_property(model, "scale", model.scale * Vector3(1.12, 0.86, 1.12), 0.08)
		squash.tween_property(model, "scale", model.scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Flying rigs hover off-centre from their rest-pose bounds, so the hero drifted
## away from its ground ring. Once the clip is running, pull the posed
## skeleton over the body origin and bring its lowest bone down to `lift` m.
func _center_posed(body: Node3D, lift: float) -> void:
	for i in 4:
		await get_tree().process_frame
	if not is_instance_valid(body) or body.get_child_count() == 0:
		return
	var model := body.get_child(0) as Node3D
	var sum := Vector3.ZERO
	var low := INF
	var n := 0
	for sk in body.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for b in skel.get_bone_count():
			var lp := body.to_local(skel.global_transform * skel.get_bone_global_pose(b).origin)
			sum += lp
			low = minf(low, lp.y)
			n += 1
	if n < 4 or model == null:
		return
	var mid := sum / float(n)
	model.position -= Vector3(mid.x, 0.0, mid.z) / body.scale.x
	if low > lift:
		model.position.y -= (low - lift) / body.scale.y
	# The procedural motion layer rebuilds the model transform from this
	# base every frame, so the centred position must become the new base.
	body.set_meta("model_base", model.position)


func _spawn_model(sprite: String, meters: float) -> Node3D:
	var root := Node3D.new()
	root.set_meta("clips", Cast3D.clips(sprite))
	root.set_meta("lock", "")
	root.set_meta("player", null)
	var packed := load(Cast3D.model(sprite)) as PackedScene
	if packed == null:
		return root
	var model := packed.instantiate()
	root.add_child(model)
	var player := _find_player(model)
	root.set_meta("player", player)
	_loop_clips(player, root.get_meta("clips"))
	_strip_root_motion(player, root.get_meta("clips"))
	var marker := _find_named(model, "Forward")
	var face := PI
	if marker != null:
		var p := marker.position
		if Vector2(p.x, p.z).length() > 0.02:
			face = atan2(p.x, p.z)
	else:
		var hinted := Cast3D.nose(sprite)
		if hinted >= 0.0:
			face = hinted
		elif hinted < -1.5:
			face = _rig_nose(model, root, face)
	root.set_meta("face", face)
	_fix_far_skins(model)
	Gear3D.hide_own(model, sprite)
	var box := _measure(model)
	# Wide critters (the dragon's wingspan) read by footprint from the
	# high camera, so size by whichever is larger.
	var h := maxf(maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.7), 0.05)
	var factor := meters / h * Cast3D.size_boost(sprite)
	model.scale *= factor
	# Feet on the ground, and the body centered. Sketchfab rigs often sit
	# far from the origin (Mixamo hips, FBX axes).
	var center := box.get_center()
	model.position.y -= box.position.y * factor
	model.position.x -= center.x * factor
	model.position.z -= center.z * factor
	_hide_catch(model)
	_fix_pbr(model, sprite)
	_tint(model, Cast3D.tint(sprite))
	if Gear3D.has_kit(sprite):
		Gear3D.dress(model, sprite)
	elif Cast3D.armor(sprite) != "":
		Armor3D.dress(model, Cast3D.armor(sprite))
	elif Cast3D.dark(sprite) != "":
		Armor3D.glow_eyes(model, Cast3D.feral_color(sprite))
	root.set_meta("model_base", model.position)
	root.set_meta("meters", meters)
	if BossLook.has(sprite):
		BossLook.dress(model, sprite)
	# No real run clip (or none at all): the procedural gait hops it along.
	var has_run := false
	if player != null:
		var run_name := _clip_name(player, Cast3D.clips(sprite), "run")
		var low := run_name.to_lower()
		has_run = run_name != "" and (run_name == str(Cast3D.clips(sprite).get("run", "")) or ["run", "walk", "move", "locomotion"].any(func(k: String) -> bool: return k in low))
	root.set_meta("has_run", has_run)
	root.set_meta("flyer", Cast3D.flies(sprite))
	if Cast3D.model(sprite) == Cast3D.EMBER_CUTE:
		root.set_meta("bob", true)
		_add_wings(root, model, meters)
	elif not has_run:
		root.set_meta("bob", true)
	return root


## The baby dragon's own wings are nubs fused to the spine (no wing bones),
## so from the hunt camera it read as a spiky hedgehog. These are real wings:
## a scalloped membrane on three finger ribs, warm amber fading to ember red,
## pinned at the shoulders and flapped procedurally in _flap_wings.
func _add_wings(root: Node3D, model: Node3D, meters: float) -> void:
	var skel := _skeleton_of(model) as Skeleton3D
	var shoulder := Vector3(0.0, 0.62, 0.05)
	var idx := skel.find_bone("Bone006_06") if skel else -1
	if idx >= 0:
		# Skeleton space -> model space, then into root (meters).
		var xf := Transform3D.IDENTITY
		var n: Node = skel
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		shoulder = xf * skel.get_bone_global_rest(idx).origin
	var face := float(root.get_meta("face", PI))
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var rig := Node3D.new()
	rig.name = "Wings"
	root.add_child(rig)
	rig.position = shoulder + Vector3(0, meters * 0.12, 0) - fwd * meters * 0.04
	rig.basis = Basis(Vector3.UP, face)
	root.set_meta("wing_base", rig.position)
	# Membrane: tools/paint_wing.py paints it from the model's own wing
	# art (struts, veins, dark root to warm edge, feathered scallops). The
	# alpha cut-out gives the outline; the mesh is a bent grid so the skin
	# billows between the struts instead of reading as flat triangles.
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/models/sketchfab/ember_wing_paint.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/models/sketchfab/ember_wing_normal.png")
	mat.normal_scale = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.62
	mat.metallic_specular = 0.35
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.rim_tint = 0.6
	mat.backlight_enabled = true
	mat.backlight = Color(0.62, 0.26, 0.08)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var span := meters * 0.62
	var chord := span * 0.652
	var pivots: Array = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		rig.add_child(pivot)
		pivot.position = Vector3(side * 0.07, 0, 0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nu := 16
		var nv := 10
		var grid: Array = []
		for j in nv + 1:
			var row: Array = []
			for i in nu + 1:
				var u := float(i) / float(nu)
				var v := float(j) / float(nv)
				# Rig space: x out to the side, y up, +z forward. The arm
				# rises and sweeps back; the skin sags between the struts.
				var x: float = side * (0.04 + u) * span
				var y := (0.85 * u - 0.28 * v) * span
				y -= 0.07 * span * sin(PI * v) * (0.3 + u)
				y += 0.025 * span * sin(u * TAU * 2.0) * v
				var z := (0.12 - v) * chord - 0.12 * u * span
				row.append([Vector3(x, y, z), Vector2(u, v)])
			grid.append(row)
		for j in nv:
			for i in nu:
				var q: Array = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
				# Mirrored side: flip the winding so both wings face up.
				for k in ([0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]):
					st.set_uv(q[k][1])
					st.add_vertex(q[k][0])
		st.generate_normals()
		st.generate_tangents()
		var memb := MeshInstance3D.new()
		memb.mesh = st.commit()
		memb.material_override = mat
		memb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		pivot.add_child(memb)
		pivots.append(pivot)
	_wing_sets.append({"l": pivots[0], "r": pivots[1], "body": root})


## Flap: a slow breathing beat at rest, quicker and wider on the move.
func _flap_wings() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var keep: Array = []
	for w in _wing_sets:
		var body = w["body"]
		if not is_instance_valid(body):
			continue
		keep.append(w)
		var moving := bool((body as Node3D).get_meta("moving", false))
		var rate := 9.0 if moving else 3.2
		var amp := 0.42 if moving else 0.16
		var beat := sin(t * rate + float(body.get_instance_id() % 7))
		var lift := 0.12 + beat * amp
		(w["l"] as Node3D).rotation = Vector3(0, 0, -lift)
		(w["r"] as Node3D).rotation = Vector3(0, 0, lift)
	_wing_sets = keep


## Sketchfab exports pack AO, roughness, and metal into one map. Godot reads
## the blue channel as metal, so the dragon came in as polished chrome that
## only reflected the sky. Critters are painted fur, scale, and cloth: no
## metal, a soft sheen, and the normal map only where it carries detail.
static var _grain_tex: NoiseTexture2D
static var _grain_nrm: NoiseTexture2D


## Painterly grain for flat-atlas critters: a soft mottled multiply and a
## fine bumpy normal, both triplanar in object space (the kit meshes have no
## spare UVs), so the hide reads as fur and skin rather than plastic.
func _paint_grain(mat: StandardMaterial3D) -> void:
	if _grain_tex == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.fractal_octaves = 4
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.68, 0.66))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		_grain_tex = NoiseTexture2D.new()
		_grain_tex.width = 256
		_grain_tex.height = 256
		_grain_tex.seamless = true
		_grain_tex.noise = noise
		_grain_tex.color_ramp = ramp
		var fine := FastNoiseLite.new()
		fine.noise_type = FastNoiseLite.TYPE_CELLULAR
		fine.frequency = 0.06
		_grain_nrm = NoiseTexture2D.new()
		_grain_nrm.width = 256
		_grain_nrm.height = 256
		_grain_nrm.seamless = true
		_grain_nrm.as_normal_map = true
		_grain_nrm.bump_strength = 6.0
		_grain_nrm.noise = fine
	mat.detail_enabled = true
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = _grain_tex
	mat.detail_normal = _grain_nrm
	mat.uv2_triplanar = true
	mat.uv2_scale = Vector3(5, 5, 5)
	mat.albedo_color = mat.albedo_color * Color(1.12, 1.1, 1.08)


## De-toy a flat-coloured monster material (Quaternius names its eyes
## Eye_White / Eye_Black): eyes become glowing sockets, hides go muted.
func _menace(mat: StandardMaterial3D, glow: Color) -> void:
	var n := mat.resource_name
	if n.begins_with("Eye_White"):
		mat.albedo_color = Color(0.02, 0.015, 0.012)
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.8
		mat.rim_enabled = false
		return
	if n.begins_with("Eye_Black"):
		mat.albedo_color = Color(0.0, 0.0, 0.0)
		mat.roughness = 0.3
		return
	var c := mat.albedo_color
	var grey := c.get_luminance()
	c = Color(grey, grey, grey).lerp(c, 0.68) * 0.78
	c.a = 1.0
	mat.albedo_color = c


func _fix_pbr(node: Node, sprite: String) -> void:
	var opts := Cast3D.pbr(sprite)
	if opts.is_empty():
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var base := mesh.get_active_material(i)
			if not base is StandardMaterial3D:
				continue
			var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.metallic = 0.0
			mat.metallic_texture = null
			mat.metallic_specular = float(opts.get("specular", 0.45))
			mat.roughness_texture = null
			mat.roughness = float(opts.get("roughness", 0.62))
			if bool(opts.get("drop_normal", false)):
				mat.normal_enabled = false
				mat.normal_texture = null
			if bool(opts.get("drop_ao", false)):
				mat.ao_enabled = false
				mat.ao_texture = null
			if opts.has("rough_tex"):
				mat.roughness_texture = load(str(opts["rough_tex"]))
				mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			if opts.has("ao_tex"):
				mat.ao_enabled = true
				mat.ao_texture = load(str(opts["ao_tex"]))
				mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				mat.ao_light_affect = 1.0
			if opts.has("normal_tex"):
				mat.normal_enabled = true
				mat.normal_texture = load(str(opts["normal_tex"]))
				mat.normal_scale = float(opts.get("normal_scale", 1.0))
			if opts.has("backlight"):
				# Thin membranes glow where the sun shines through them.
				mat.backlight_enabled = true
				mat.backlight = opts["backlight"]
			if opts.has("normal_scale") and not opts.has("normal_tex") and mat.normal_enabled:
				mat.normal_scale = float(opts["normal_scale"])
			if opts.has("subsurface"):
				mat.subsurf_scatter_enabled = true
				mat.subsurf_scatter_strength = float(opts["subsurface"])
				mat.subsurf_scatter_skin_mode = true
			if opts.has("albedo_tex") and mat.albedo_texture != null:
				mat.albedo_texture = load(str(opts["albedo_tex"]))
			var lift: Color = opts.get("albedo", Color.WHITE)
			mat.albedo_color = mat.albedo_color * lift
			if opts.has("rim"):
				mat.rim_enabled = true
				mat.rim = float(opts["rim"])
				mat.rim_tint = float(opts.get("rim_tint", 0.35))
			if bool(opts.get("paint", false)):
				_paint_grain(mat)
			if opts.has("menace"):
				_menace(mat, opts["menace"])
			if opts.has("glow_core"):
				# Molten (or frozen) veins burn through the hide.
				mat.emission_enabled = true
				mat.emission = opts["glow_core"]
				mat.emission_energy_multiplier = 2.4
				if opts.has("glow_tex"):
					# Multiply: the mask picks the veins (Add would light it all).
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_texture = load(str(opts["glow_tex"]))
			if opts.has("fur_cut") and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				# Fur cards: a hard alpha cut (with coverage AA) instead of a
				# soft blend, so tips clump instead of fraying see-through.
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = float(opts["fur_cut"])
				mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if opts.has("clearcoat"):
				mat.clearcoat_enabled = true
				mat.clearcoat = float(opts["clearcoat"])
				mat.clearcoat_roughness = 0.35
			mesh.set_surface_override_material(i, mat)
	for child in node.get_children():
		_fix_pbr(child, sprite)


func _anim(body: Node3D, actor: RunSim.Actor) -> void:
	var lock := str(body.get_meta("lock", ""))
	var until := float(body.get_meta("lock_until", 0.0))
	var now := Time.get_ticks_msec() / 1000.0
	body.set_meta("speed_ms", actor.vel.length() * SCALE)
	_motion(body, actor.vel.length() > 18.0, now, clampf(actor.vel.length() / maxf(actor.speed, 1.0), 0.0, 1.3))
	if lock == "death" or not actor.alive:
		body.set_meta("lock", "death")
		_play(body, "death")
		return
	if lock != "" and now < until:
		return
	if lock != "":
		body.set_meta("lock", "")
	var moving := actor.vel.length() > 18.0
	body.set_meta("moving", moving)
	if moving:
		var player0: AnimationPlayer = body.get_meta("player")
		var slow := actor.vel.length() < actor.speed * 0.5
		if slow and player0 != null and _has_walk(player0, body):
			_play(body, "walk")
		else:
			_play(body, "run")
		# Belt and braces: a locomotion clip that has stopped is restarted.
		var p1: AnimationPlayer = body.get_meta("player")
		if p1 != null and not p1.is_playing() and str(body.get_meta("state", "")) in ["run", "walk"]:
			body.set_meta("state", "")
			_play(body, "walk" if slow and _has_walk(p1, body) else "run")
		# Cadence follows speed: half-tilted stick, half-speed legs.
		var player: AnimationPlayer = body.get_meta("player")
		var stt := str(body.get_meta("state", ""))
		if player != null and (stt == "run" or stt == "walk"):
			var ref := actor.speed * (0.5 if stt == "walk" else 1.0)
			player.speed_scale = (1.0 if stt == "walk" else 1.15) * clampf(actor.vel.length() / maxf(ref, 1.0), 0.45, 1.3)
		elif player != null and bool(body.get_meta("bob", false)):
			# Hopping on the idle clip: keep it calm so the hop leads.
			player.speed_scale = 0.6
	else:
		_play(body, "idle")


## Procedural motion layer, rebuilt every frame on top of any clip:
## - gait: a hop and forward lean for models without a run clip (a light
##   lean for the rest), scaled by speed so it never glides
## - idle breathing for models with no idle clip
## - hit recoil (squash and a kick back), attack lunge on the release,
##   a wind-up crouch and shiver before it, and a level-up hop and spin.
func _motion(body: Node3D, moving: bool, now: float, speed_k: float) -> void:
	if body.get_child_count() == 0 or bool(body.get_meta("dying", false)):
		return
	var model := body.get_child(0) as Node3D
	var base: Vector3 = body.get_meta("model_base", model.position)
	if not body.has_meta("model_scale"):
		body.set_meta("model_scale", model.scale)
	var s0: Vector3 = body.get_meta("model_scale")
	var m := float(body.get_meta("meters", 1.0)) / maxf(body.scale.x, 0.001)
	var face := float(body.get_meta("face", PI))
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var axis := Vector3.UP.cross(fwd).normalized()
	var dt := get_process_delta_time()
	var was := float(body.get_meta("gait", 0.0))
	# Fast in, fast out: the lean snaps on within ~60 ms and off within ~90.
	var k := move_toward(was, 1.0 if moving else 0.0, dt / (0.06 if moving else 0.09))
	body.set_meta("gait", k)
	if was > 0.6 and not moving and float(body.get_meta("stop_t", -10.0)) < now - 0.3:
		body.set_meta("stop_t", now)
	var off := Vector3.ZERO
	var lean := 0.0
	var spin := 0.0
	var sq := Vector3.ONE
	if bool(body.get_meta("bob", false)):
		# Hop gait driven by distance covered, not time: one hop per stride,
		# so the feet land where the ground is and nothing glides.
		var meters := float(body.get_meta("meters", 1.0))
		var stride := meters * 0.42
		var phase := float(body.get_meta("phase", 0.0)) + float(body.get_meta("speed_ms", 0.0)) * dt / stride * PI
		body.set_meta("phase", fmod(phase, TAU * 8.0))
		var hop := absf(sin(phase))
		off.y += hop * 0.1 * m * k
		lean += (0.14 + 0.06 * speed_k) * k
		# Squash on landing, stretch at the top of each hop.
		sq *= Vector3(1.0 + 0.06 * (1.0 - hop) * k, 1.0 + (0.08 * hop - 0.05) * k, 1.0 + 0.06 * (1.0 - hop) * k)
	else:
		lean += 0.07 * k
	# Settle on stop: a quick forward rock and squash that eases out.
	var st := now - float(body.get_meta("stop_t", -10.0))
	if st < 0.22:
		var e := sin(PI * st / 0.22) * (1.0 - st / 0.22)
		lean += 0.12 * e
		sq *= Vector3(1.0 + 0.05 * e, 1.0 - 0.07 * e, 1.0 + 0.05 * e)
	if body.get_meta("player") == null:
		sq.y *= 1.0 + 0.03 * sin(now * 2.2 + float(body.get_instance_id() % 7))
	var ht := now - float(body.get_meta("hit_t", -10.0))
	if ht < 0.24:
		var e := 1.0 - ht / 0.24
		e *= e * float(body.get_meta("hit_amp", 1.0))
		sq *= Vector3(1.0 + 0.12 * e, 1.0 - 0.16 * e, 1.0 + 0.12 * e)
		lean -= 0.22 * e
		off -= fwd * 0.06 * m * e
	var wt := now - float(body.get_meta("wind_t", -10.0))
	var wl := float(body.get_meta("wind_len", 0.0))
	if wt < wl:
		var p := wt / maxf(wl, 0.01)
		sq *= Vector3(1.0 + 0.08 * p, 1.0 - 0.12 * p, 1.0 + 0.08 * p)
		lean -= 0.18 * p
		off -= fwd * 0.1 * m * p
		off += axis * sin(now * 70.0) * 0.012 * m * p
	var at := now - float(body.get_meta("att_t", -10.0))
	if at < 0.3:
		var e := sin(PI * at / 0.3)
		off += fwd * 0.22 * m * e
		lean += 0.2 * e
		sq *= Vector3(1.0 - 0.05 * e, 1.0 + 0.1 * e, 1.0 - 0.05 * e)
	if bool(body.get_meta("flyer", false)):
		# Flyers hold altitude with a slow bob and pitch nose-down into a
		# dart while moving, instead of sliding along the ground.
		var ph := float(body.get_instance_id() % 97)
		off.y += m * (0.55 + 0.1 * sin(now * 3.3 + ph) + 0.05 * sin(now * 7.1 + ph))
		lean += 0.3 * k
		off += axis * sin(now * 2.1 + ph) * 0.06 * m
	var lt := now - float(body.get_meta("lvl_t", -10.0))
	if lt < 0.6:
		var p := lt / 0.6
		off.y += 4.0 * p * (1.0 - p) * 0.5 * m
		spin = TAU * (1.0 - pow(1.0 - p, 3.0))
	var basis := Basis(Vector3.UP, spin) * Basis(axis, lean)
	model.transform = Transform3D(basis * Basis.from_scale(s0 * sq), basis * base + off)
	var wings := body.get_node_or_null("Wings") as Node3D
	if wings:
		var wb: Vector3 = body.get_meta("wing_base", wings.position)
		wings.position = basis * wb + off
		wings.basis = basis * Basis(Vector3.UP, face)


## Death: the model's own clip if it has one, else a topple; either way it
## sinks and dissolves out instead of vanishing.
func _dying(body: Node3D, now: float, vanish := true) -> void:
	if body.get_child_count() == 0:
		return
	var d := clampf((now - float(body.get_meta("die_at", now))) / 1.0, 0.0, 1.0)
	var model := body.get_child(0) as Node3D
	var base: Vector3 = body.get_meta("model_base", model.position)
	var s0: Vector3 = body.get_meta("model_scale", model.scale)
	var m := float(body.get_meta("meters", 1.0)) / maxf(body.scale.x, 0.001)
	var face := float(body.get_meta("face", PI))
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var side := Vector3.UP.cross(fwd).normalized()
	var has_clip := bool(body.get_meta("death_clip", false))
	var topple := 0.0 if has_clip else 1.45 * (1.0 - pow(1.0 - minf(d * 2.2, 1.0), 3.0))
	var sink := 0.35 * m * smoothstep(0.45, 1.0, d)
	var flat := 1.0 - 0.25 * smoothstep(0.2, 0.6, d)
	var basis := Basis(side, topple)
	model.transform = Transform3D(basis * Basis.from_scale(s0 * Vector3(1.0, flat, 1.0)), basis * base - Vector3(0, sink, 0))
	var fade := smoothstep(0.4, 1.0, d) if vanish else 0.0
	if absf(fade - float(body.get_meta("fade", -1.0))) > 0.02:
		body.set_meta("fade", fade)
		for gi in body.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).transparency = fade


## Every imported clip arrives as LOOP_NONE, so a 0.7 s run cycle played
## once and froze on its last frame: the hero then slid along with no legs
## moving. Locomotion and idle clips loop; one-shots (attack, hit, death)
## stay one-shot unless the model reuses its only clip for them.
func _loop_clips(player: AnimationPlayer, clips: Dictionary) -> void:
	if player == null:
		return
	var once := []
	for k in ["attack", "hit", "death"]:
		once.append(str(clips.get(k, "")))
	var loops := []
	for k in ["idle", "run", "walk", "perch"]:
		loops.append(str(clips.get(k, "")))
	for name in player.get_animation_list():
		var low := String(name).to_lower()
		var cyc := String(name) in loops or ["walk", "run", "idle", "fly", "move", "swim"].any(func(w: String) -> bool: return w in low)
		if not cyc or (String(name) in once and not String(name) in loops):
			continue
		var anim := player.get_animation(name)
		if anim != null and anim.loop_mode == Animation.LOOP_NONE and anim.length > 0.05:
			anim.loop_mode = Animation.LOOP_LINEAR


## Clips authored with root motion (the AnimalMesh3D walk carries the rig
## root ~80 cm per cycle, the death throws it sideways) drift the model off
## its actor, so the body slides away from its ring. Remove the net XZ
## travel from root/pelvis tracks (linear de-trend keeps the bob and sway).
## Clips are shared resources, and a second pass finds no drift.
func _strip_root_motion(player: AnimationPlayer, clips: Dictionary) -> void:
	if player == null:
		return
	for key in clips:
		var name := str(clips[key])
		if name == "" or not player.has_animation(name):
			continue
		var anim := player.get_animation(name)
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			var bone := str(anim.track_get_path(t).get_concatenated_subnames()).to_lower()
			if not ("root" in bone or "pelvis" in bone or "hips" in bone):
				continue
			var n := anim.track_get_key_count(t)
			if n < 2:
				continue
			var p0: Vector3 = anim.track_get_key_value(t, 0)
			var p1: Vector3 = anim.track_get_key_value(t, n - 1)
			var drift := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)
			if drift.length() < 0.5:
				continue
			var t0 := anim.track_get_key_time(t, 0)
			var span := maxf(anim.track_get_key_time(t, n - 1) - t0, 0.0001)
			for k in n:
				var f := (anim.track_get_key_time(t, k) - t0) / span
				var v: Vector3 = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, v - drift * f)


func _has_walk(player: AnimationPlayer, body: Node3D) -> bool:
	if body.has_meta("walk_clip"):
		return str(body.get_meta("walk_clip")) != ""
	var found := ""
	for anim in player.get_animation_list():
		if "walk" in anim.to_lower():
			found = anim
			break
	body.set_meta("walk_clip", found)
	return found != ""


func _play(body: Node3D, state: String) -> void:
	if str(body.get_meta("state", "")) == state:
		return
	body.set_meta("state", state)
	var player: AnimationPlayer = body.get_meta("player")
	if player == null:
		_pose(body, state)
		return
	var clips: Dictionary = body.get_meta("clips")
	var name := _clip_name(player, clips, state)
	if state == "walk":
		name = str(body.get_meta("walk_clip", ""))
	if state == "death":
		var dn := _clip_name(player, clips, "death")
		var has_death := dn != "" and dn != str(clips.get("idle", "")) and ["death", "die", "dead"].any(func(k: String) -> bool: return k in dn.to_lower())
		body.set_meta("death_clip", has_death)
		if not has_death:
			player.pause()
			return
	if name != "" and player.has_animation(name):
		player.play(name, 0.14)
		if state == "attack":
			player.speed_scale = 1.35
		elif state == "run":
			player.speed_scale = 1.15
		else:
			player.speed_scale = 1.0
	else:
		_pose(body, state)


func _pose(body: Node3D, state: String) -> void:
	# Models that have no death or hit clip still read the moment.
	if state == "death":
		body.set_meta("death_clip", false)


func _yaw(facing: float, body: Node3D) -> float:
	var face := float(body.get_meta("face", PI))
	var dir := Vector2(cos(facing), sin(facing))
	return atan2(dir.x, dir.y) - face


func _follow(hero: Vector3, delta: float) -> void:
	if not _ready_cam:
		_look = hero
		_ready_cam = true
	else:
		# Tight follow: the camera trails by a few cm at full speed, so the
		# hero doesn't swim against the frame.
		_look = _look.lerp(hero, 1.0 - exp(-22.0 * delta))
	_frame(_look)


func _frame(look: Vector3) -> void:
	var back := Vector3(0.0, sin(PITCH), cos(PITCH)) * _dist
	camera.position = look + back + _shake
	# Aim above the chest so the body sits a little below the middle.
	camera.look_at(look + Vector3(0.0, AIM, 0.0), Vector3.UP)


## Frames the hero so its body fills about 60% of the stage height, standing
## a little below center with the plinth and props in view.
func _frame_on(body: Node3D) -> void:
	var box := _measure_local(body)
	var h := maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.75)
	camera.fov = 30.0
	var view_h := h / 0.6
	var dist := view_h * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	var focus := body.position + Vector3(0, box.position.y + box.size.y * 0.5 - h * 0.06, 0)
	var dir := Vector3(0.0, 0.32, 1.0).normalized()
	camera.position = focus + dir * dist
	camera.look_at(focus, Vector3.UP)


## Skinned meshes report their rest-pose bounds, which can be far bigger than
## the animated pose (the dragon's spread wings). After the idle has started,
## measure the posed skeleton and frame on that instead.
func _reframe_posed(body: Node3D) -> void:
	for i in 3:
		await get_tree().process_frame
	if not is_instance_valid(body) or _mode != "pedestal":
		return
	var pts: Array[Vector3] = []
	for sk in body.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for b in skel.get_bone_count():
			pts.append(skel.global_transform * skel.get_bone_global_pose(b).origin)
	if pts.size() < 4:
		return
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	# Plant the lowest bone (a foot or the tail) on the plinth. The rest-pose
	# bounds put the feet well below where the perch pose has them.
	var model := body.get_child(0) as Node3D
	var drop := box.position.y - (PEDESTAL_TOP + 0.03)
	if model != null and absf(drop) > 0.02:
		model.position.y -= drop
		box.position.y -= drop
	box = box.grow(box.size.length() * 0.06)
	var h := maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.7)
	# The hero takes half the stage height and sits low, so horns and wing
	# tips clear the title plate and the feet stay above the name badge.
	var view_h := h / pedestal_fill
	var dist := view_h * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	var focus := box.get_center() + Vector3(0, view_h * 0.215, 0)
	var dir := Vector3(0.0, 0.3, 1.0).normalized()
	camera.position = focus + dir * dist
	camera.look_at(focus, Vector3.UP)
	_ped_focus = focus
	_ped_dir = dir
	_ped_dist = dist
	_pedestal_atmos(box)
	_showcase_lights(box)
	# No depth of field: on this renderer it smeared the hero along with the
	# glade. Warm fog does the separation instead.
	camera.attributes = null


const HERO_LAYER := 1 << 1


## Three-point light on the showcase hero only (cull mask = hero layer), so
## dark plate and bone read as metal instead of a silhouette against the
## glade: a warm key high camera-left, a cool rim behind camera-right that
## traces the edges, and a soft neutral fill low camera-right.
func _showcase_lights(box: AABB) -> void:
	for old in get_tree().get_nodes_in_group("showcase_light"):
		if old.is_inside_tree() and world_root.is_ancestor_of(old):
			old.queue_free()
	var c := box.get_center()
	var h := maxf(box.size.y, 0.5)
	var specs := [
		# colour, energy, offset (in hero heights), range, specular
		# Key (warm, high front-left), rims either side, front fill, and a
		# top light so blackened plate keeps its form on the dark stage.
		# Showcase lock: the artist's materials are no longer darkened by a
		# tint shader, so these sit near the reference render's levels:
		# one clean key, a cool rim pair for the silhouette, soft fill.
		[Color("fff4ea"), 2.4, Vector3(-0.9, 0.9, 1.3), 3.4, 1.0],
		[Color("cfe0ff"), 3.6, Vector3(1.0, 0.8, -1.1), 3.0, 1.0],
		[Color("eef2ff"), 0.9, Vector3(0.9, 0.1, 1.4), 3.6, 0.3],
		[Color("cfe0ff"), 2.2, Vector3(-1.0, 0.6, -1.0), 2.8, 0.9],
		[Color("f4f6ff"), 1.0, Vector3(0.1, 1.5, 0.4), 2.6, 0.8],
	]
	for sp in specs:
		var l := OmniLight3D.new()
		l.add_to_group("showcase_light")
		l.light_color = sp[0]
		l.light_energy = float(sp[1])
		l.omni_range = h * float(sp[3])
		l.omni_attenuation = 1.2
		l.light_specular = float(sp[4])
		l.light_cull_mask = HERO_LAYER
		l.shadow_enabled = false
		l.position = c + (sp[2] as Vector3) * h
		world_root.add_child(l)
	_plinth(box)


## A lit stone plinth under the showcase hero: dark worn stone, a gilt rune
## ring glowing at its lip and a warm pool of light from above on it.
func _plinth(_box: AABB) -> void:
	# Sits on the glade's grassy pedestal cap (hero stands at the origin):
	# a dark worn stone dais, a gilt rune ring at its lip and a neutral pool
	# of light from above so the dais reads as a lit stage.
	var root := Node3D.new()
	root.add_to_group("showcase_light")
	root.position = Vector3(0, PEDESTAL_TOP + 0.04, 0)
	world_root.add_child(root)
	var stone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.92
	cyl.bottom_radius = 0.98
	cyl.height = 0.08
	cyl.radial_segments = 40
	stone.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("6b6258")
	sm.roughness = 0.8
	stone.material_override = sm
	stone.position.y = -0.02
	root.add_child(stone)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 0.95
	tor.rings = 48
	tor.ring_segments = 6
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("c99a4a")
	rm.emission_enabled = true
	rm.emission = Color("ffb85a")
	rm.emission_energy_multiplier = 2.6
	ring.material_override = rm
	ring.position.y = 0.025
	root.add_child(ring)
	var pool := SpotLight3D.new()
	pool.light_color = Color("fff4e6")
	pool.light_energy = 5.0
	pool.spot_range = 7.0
	pool.spot_angle = 18.0
	pool.shadow_enabled = false
	# Stone only: a 5.0 spot straight down blew out hoods and shoulders
	# (Corvin read as a white ghost on the Heroes screen).
	pool.light_cull_mask = 1
	pool.position = Vector3(0, 5.0, 0)
	pool.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(pool)


func _split_hero(body: Node3D) -> void:
	for v in body.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = HERO_LAYER
	# The main pass still draws (and lights) the hero. The second pass only
	# renders the hero's silhouette, which the backdrop blur uses as a mask
	# to keep the hero's pixels sharp.
	_hero_vp = SubViewport.new()
	_hero_vp.transparent_bg = true
	_hero_vp.world_3d = viewport.find_world_3d()
	# The pedestal only needs a small silhouette of the hero, so render it at
	# a fraction of the frame resolution instead of the full viewport size.
	_hero_vp.scaling_3d_scale = 0.6
	_hero_vp.scaling_3d_mode = SubViewport.SCALING_3D_MODE_FSR
	_hero_vp.msaa_3d = Viewport.MSAA_DISABLED
	_hero_vp.use_debanding = true
	_hero_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hero_vp.size = viewport.size
	add_child(_hero_vp)
	_hero_cam = Camera3D.new()
	_hero_cam.cull_mask = HERO_LAYER
	var env := (camera.environment as Environment).duplicate() as Environment
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.glow_enabled = false
	env.fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_hero_cam.environment = env
	_hero_vp.add_child(_hero_cam)
	_hero_cam.current = true
	_hero_cam.global_transform = camera.global_transform
	_hero_cam.fov = camera.fov
	var blur := ShaderMaterial.new()
	blur.shader = load("res://shaders/backdrop_blur.gdshader")
	_view.material = blur
	blur.set_shader_parameter("mask", _hero_vp.get_texture())


## Life for the glade: slanted shafts of sun through the canopy and a slow
## drift of fireflies and pollen around the hero.
func _pedestal_atmos(box: AABB) -> void:
	var c := box.get_center()
	var ray_shader := Shader.new()
	ray_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.94, 0.84, 1.0);
uniform float strength = 0.45;
uniform float phase = 0.0;
void fragment() {
	float across = smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x);
	float down = smoothstep(1.0, 0.25, UV.y) * smoothstep(0.0, 0.12, UV.y);
	float flicker = 0.75 + 0.25 * sin(TIME * 0.6 + phase + UV.y * 3.0);
	ALBEDO = tint.rgb * strength * across * down * flicker;
}
"""
	var rays := [[Vector3(-1.3, 0, -1.4), 0.8, 0.0], [Vector3(0.1, 0, -1.9), 1.2, 1.7], [Vector3(1.4, 0, -1.3), 0.6, 3.1], [Vector3(-2.4, 0, -0.9), 0.55, 4.4]]
	for r in rays:
		var plane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(float(r[1]), 7.0)
		plane.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = ray_shader
		mat.set_shader_parameter("phase", float(r[2]))
		plane.material_override = mat
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(plane)
		plane.global_position = Vector3(c.x, PEDESTAL_TOP, c.z) + (r[0] as Vector3) + Vector3(0, 3.0, 0)
		# Lean the shafts away from the low sun, facing the camera.
		plane.rotation = Vector3(0.0, 0.0, deg_to_rad(-24.0))
	var flies := GPUParticles3D.new()
	flies.amount = 16
	flies.lifetime = 7.0
	flies.preprocess = 7.0
	flies.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 8, 12))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(box.size.x * 0.9 + 1.2, box.size.y * 0.6 + 0.4, 1.4)
	proc.gravity = Vector3(0, 0.03, 0)
	proc.initial_velocity_min = 0.02
	proc.initial_velocity_max = 0.12
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 180.0
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 0.4
	proc.turbulence_noise_scale = 2.5
	proc.turbulence_influence_min = 0.05
	proc.turbulence_influence_max = 0.12
	proc.scale_min = 0.5
	proc.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	proc.color_ramp = ramp
	flies.process_material = proc
	var dot := QuadMesh.new()
	dot.size = Vector2(0.09, 0.09)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	glow.vertex_color_use_as_albedo = true
	glow.albedo_color = Color(1.0, 0.86, 0.5)
	glow.disable_fog = true
	glow.albedo_texture = _soft_dot()
	glow.disable_receive_shadows = true
	dot.material = glow
	flies.draw_pass_1 = dot
	world_root.add_child(flies)
	flies.global_position = c + Vector3(0, 0.2, 0.3)


func _soft_dot() -> Texture2D:
	# One dot for the whole game: the builder lives with the cast effects
	# (scripts/cast_fx3d.gd), which tint the same dot per hero.
	return CastFx3D.soft_dot()


func _decal(size: float, params: Dictionary) -> MeshInstance3D:
	if _decal_shader == null:
		_decal_shader = load("res://shaders/ground_decal.gdshader")
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(size, size)
	node.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _decal_shader
	for key in params:
		mat.set_shader_parameter(key, params[key])
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("decal", true)
	return node


## Reach ring: a faint hairline at the hero's real attack reach, per class.
## Melee (tank) swings land out to range + 10 plus the target's body
## (run_sim._melee), so the ring sits at range + 10 + a typical critter
## radius; shooters pick targets within range. Colour keys the class.
var _reach: MeshInstance3D
const REACH_COLORS := {
	"tank": Color(1.0, 0.78, 0.45, 0.32),
	"archer": Color(0.62, 0.9, 1.0, 0.3),
	"mage": Color(0.72, 1.0, 0.55, 0.3),
}
func _place_reach(actor: RunSim.Actor, at: Vector3) -> void:
	var px := actor.range + (10.0 + 16.0 if actor.role == "tank" else 0.0)
	var meters := px * SCALE
	if _reach == null:
		_reach = _decal(1.0, {
			"ring_color": REACH_COLORS.get(actor.role, REACH_COLORS["mage"]),
			"ring_radius": 0.48,
			"ring_width": 0.006,
			"ring_glow": 0.25,
			"shadow_alpha": 0.0,
			"pulse": 0.0,
		})
		_reach.position.y = 0.03
		actor_root.add_child(_reach)
	var size := meters / 0.48
	_reach.scale = Vector3(size, 1.0, size)
	(_reach.material_override as ShaderMaterial).set_shader_parameter("ring_color", REACH_COLORS.get(actor.role, REACH_COLORS["mage"]))
	(_reach.material_override as ShaderMaterial).set_shader_parameter("ring_width", 0.006 * 12.0 / maxf(size, 1.0))
	_reach.visible = true
	# Lifted over the grass blades (they cover a ground-level hairline).
	_reach.position = Vector3(at.x, 0.32, at.z)


## The hero's selection ring: a soft contact shadow under a smooth gold ring.
func _place_mark(at: Vector3) -> void:
	if _mark == null:
		_mark = _decal(HERO_METERS * 0.82, {
			# A gilt rune circle with a soft glow: reads as "you" at the far
			# camera, never as a donut.
			"ring_color": Color(1.0, 0.8, 0.42, 0.85),
			"ring_radius": 0.42,
			"ring_width": 0.013,
			"ring_glow": 0.55,
			"rune": true,
			"shadow_alpha": 0.86,
			"shadow_radius": 0.27,
			"pulse": 0.0,
		})
		_mark.position.y = 0.035
		actor_root.add_child(_mark)
		# Ground glow: a soft pool of cool light under the hero so it
		# separates from the warm dirt and grass at the hunt zoom.
		var pool := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * HERO_METERS * 2.0
		pool.mesh = quad
		var gs := Shader.new()
		gs.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled, cull_disabled;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float g = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = vec3(0.5, 0.72, 1.0) * g * 0.42;
}
"""
		var gm := ShaderMaterial.new()
		gm.shader = gs
		pool.material_override = gm
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.position.y = 0.01
		_mark.add_child(pool)
		# A personal key light that rides with the hero: lifts its fur and
		# armour out of the forest gloom without brightening the whole map.
		var key := OmniLight3D.new()
		key.light_color = Color("ffe2b8")
		key.light_energy = 0.9
		key.omni_range = HERO_METERS * 1.7
		key.omni_attenuation = 1.6
		key.light_specular = 0.4
		key.shadow_enabled = false
		key.position = Vector3(-0.6, HERO_METERS * 1.1, 0.9)
		_mark.add_child(key)
	_mark.visible = true
	_mark.position = Vector3(at.x, 0.035, at.z)


## Runebound aura: a breathing rune-coloured halo on the ground and a slow
## drift of embers rising off the plate. Two draws, reads at phone distance.
func _rune_aura(body: Node3D, c: Color) -> void:
	var halo := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * HERO_METERS * HERO_BOOST * 1.5
	halo.mesh = quad
	var hs := Shader.new()
	hs.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled, cull_disabled;
uniform vec4 tint : source_color;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.55, 0.78, d) * smoothstep(1.0, 0.8, d);
	float core = pow(clamp(1.0 - d, 0.0, 1.0), 2.0) * 0.35;
	float breath = 0.7 + 0.3 * sin(TIME * 2.4);
	ALBEDO = tint.rgb * (ring * 0.9 + core) * breath;
}
"""
	var hm := ShaderMaterial.new()
	hm.shader = hs
	hm.set_shader_parameter("tint", c)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position.y = 0.04
	halo.top_level = false
	body.add_child(halo)
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 1.3
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = HERO_METERS * 0.35
	pm.emission_ring_inner_radius = HERO_METERS * 0.15
	pm.emission_ring_height = HERO_METERS * 0.6
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.gravity = Vector3(0, HERO_METERS * 0.1, 0)
	pm.initial_velocity_min = HERO_METERS * 0.18
	pm.initial_velocity_max = HERO_METERS * 0.3
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * HERO_METERS * 0.035
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = Color(c.r * 2.0, c.g * 2.0, c.b * 2.0)
	q.material = qm
	p.draw_pass_1 = q
	p.position.y = HERO_METERS * 0.4
	body.add_child(p)


func _step_dust(body: Node3D, actor: RunSim.Actor, sim: RunSim) -> void:
	if _dust == null:
		return
	if actor.vel.length() < 40.0:
		return
	var next := float(body.get_meta("step", 0.0))
	if sim.time < next:
		return
	body.set_meta("step", sim.time + 0.28)
	_dust.global_position = body.global_position + Vector3(0, 0.05, 0)
	_dust.restart()
	_dust.emitting = true


func _spark(at: Vector3, color: Color) -> void:
	for spark in _sparks:
		var particles: GPUParticles3D = spark
		if particles.emitting:
			continue
		particles.global_position = at + Vector3(0, 0.6, 0)
		var mat: StandardMaterial3D = particles.draw_pass_1.surface_get_material(0)
		if mat:
			mat.albedo_color = color
		particles.restart()
		particles.emitting = true
		return


func _dust_pool() -> void:
	_dust = _puff(Color("c4a574"), 14, 0.45)
	world_root.add_child(_dust)
	for _i in 4:
		var spark := _puff(Color("ffb15a"), 18, 0.35)
		world_root.add_child(spark)
		_sparks.append(spark)


func _puff(color: Color, amount: int, life: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	mat.albedo_texture = load("res://assets/textures/dust.png")
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.4
	quad.material = mat
	particles.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 55.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.6
	process.gravity = Vector3(0, -2.2, 0)
	process.scale_min = 0.4
	process.scale_max = 1.1
	particles.process_material = process
	return particles


func _tint(node: Node, color: Color) -> void:
	if color == Color.WHITE:
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var base := mesh.get_active_material(i)
			var mat := base.duplicate() if base else StandardMaterial3D.new()
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = color
			mesh.set_surface_override_material(i, mat)
	for child in node.get_children():
		_tint(child, color)


func _expand_aabb(acc: Dictionary, point: Vector3) -> void:
	if not bool(acc["ok"]):
		acc["box"] = AABB(point, Vector3.ZERO)
		acc["ok"] = true
	else:
		acc["box"] = (acc["box"] as AABB).expand(point)


## Some exports bind skinned vertices far from the origin (the hyena's
## bind box sits ~1000 units away): their mesh box means nothing.
func _far_skin(mi: MeshInstance3D) -> bool:
	if mi.skin == null and String(mi.skeleton) == "":
		return false
	var box := mi.mesh.get_aabb()
	return box.get_center().length() > 20.0 * maxf(box.size.length(), 0.001)


## Give far-bound skinned meshes a culling box around their bones, or the
## renderer culls them whenever the phantom box leaves the view.
func _fix_far_skins(model: Node) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _far_skin(mi):
			continue
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if sk == null:
			continue
		var box := AABB()
		for b in sk.get_bone_count():
			var p := mi.transform.affine_inverse() * (sk.transform * sk.get_bone_global_rest(b).origin)
			box = AABB(p, Vector3.ZERO) if b == 0 else box.expand(p)
		mi.custom_aabb = box.grow(box.size.length() * 0.4)


## Nose direction read off the skeleton: from the hips/pelvis bone to the
## head bone at rest, in the body's frame (y ignored).
func _rig_nose(model: Node, root: Node3D, fallback: float) -> float:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return fallback
	var sk := found[0] as Skeleton3D
	var head := -1
	var tail := -1
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b).to_lower()
		if head < 0 and "head" in n:
			head = b
		if tail < 0 and ("pelvis" in n or "hips" in n):
			tail = b
	if head < 0 or tail < 0:
		return fallback
	var xf := _chain(sk, root)
	var d := xf * sk.get_bone_global_rest(head).origin - xf * sk.get_bone_global_rest(tail).origin
	if Vector2(d.x, d.z).length() < 0.0001:
		return fallback
	return fposmod(atan2(d.x, d.z), TAU)


func _measure(node: Node) -> AABB:
	var acc := {"ok": false, "box": AABB()}
	_measure_into(node, Transform3D.IDENTITY, acc)
	if not bool(acc["ok"]):
		return AABB(Vector3.ZERO, Vector3(0.4, 1.0, 0.4))
	return acc["box"]


func _measure_into(node: Node, parent: Transform3D, acc: Dictionary) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh and not _far_skin(node as MeshInstance3D):
		var local: AABB = (node as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			_expand_aabb(acc, xf * local.get_endpoint(i))
	if node is Skeleton3D:
		# Skinned meshes often report the bind-pose box, which is tiny on
		# Mixamo rigs. Bone joints are the size the player actually sees.
		var skel := node as Skeleton3D
		for b in skel.get_bone_count():
			_expand_aabb(acc, xf * skel.get_bone_global_pose(b).origin)
	for child in node.get_children():
		_measure_into(child, xf, acc)


func _chain(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		if cur == root:
			break
		cur = cur.get_parent()
	return xf


func _fx_node(id: int, kind: String) -> MeshInstance3D:
	if _fx.has(id):
		return _fx[id]
	var mesh_node := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.25
	mat.metallic_specular = 0.8
	if kind == "gem":
		# A small cut emerald: six facets top and bottom, a soft inner glow.
		var gem := SphereMesh.new()
		gem.radial_segments = 6
		gem.rings = 2
		gem.radius = 0.15
		gem.height = 0.4
		mesh_node.mesh = gem
		mat.albedo_color = Color("3af08a")
		mat.emission_enabled = true
		mat.emission = Color("1fd468")
		mat.emission_energy_multiplier = 1.1
		mat.rim_enabled = true
		mat.rim = 0.8
		mat.metallic_specular = 1.0
		mat.roughness = 0.12
		# A soft additive halo so the gem glows at the far hunt zoom.
		var halo := MeshInstance3D.new()
		var hq := QuadMesh.new()
		hq.size = Vector2(0.7, 0.7)
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.albedo_color = Color(0.3, 1.0, 0.55, 0.55)
		hm.albedo_texture = _soft_dot()
		hm.disable_fog = true
		hq.material = hm
		halo.mesh = hq
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.add_child(halo)
		# Magnet trail: a short green streak, only while the gem is pulled.
		var trail := GPUParticles3D.new()
		trail.name = "Trail"
		trail.amount = 18
		trail.lifetime = 0.3
		trail.local_coords = false
		trail.emitting = false
		var tp := ParticleProcessMaterial.new()
		tp.gravity = Vector3.ZERO
		tp.scale_min = 0.6
		tp.scale_max = 1.0
		var tf := Gradient.new()
		tf.set_color(0, Color(1, 1, 1, 0.9))
		tf.set_color(1, Color(1, 1, 1, 0))
		var tr := GradientTexture1D.new()
		tr.gradient = tf
		tp.color_ramp = tr
		trail.process_material = tp
		var tq := QuadMesh.new()
		tq.size = Vector2(0.22, 0.22)
		var tm := hm.duplicate() as StandardMaterial3D
		tm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		tm.vertex_color_use_as_albedo = true
		tq.material = tm
		trail.draw_pass_1 = tq
		mesh_node.add_child(trail)
	elif kind == "arrow":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = 0.04
		cyl.height = 0.5
		mesh_node.mesh = cyl
		mat.albedo_color = Color("f4e2b0")
		mat.emission_enabled = true
		mat.emission = Color("ffd27a")
		mat.emission_energy_multiplier = 0.5
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.14 if kind == "bash" else 0.11
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		mesh_node.mesh = sphere
		var col := Color("ff7a1a")
		if kind == "enemy":
			col = Color("c040ff")
		elif kind == "bash":
			col = Color("ffd34a")
		elif kind == "orb" and _bolt != Color(0, 0, 0, 0):
			# Caster's own bolt (Gear3D kit "bolt"): a hot core in a soft
			# halo trailing smoke, so it never reads as a generic fire orb.
			col = _bolt
			sphere.radius = 0.13
			sphere.height = 0.26
			_bolt_dress(mesh_node, col)
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.15 if kind != "orb" else 2.2
	mesh_node.material_override = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor_root.add_child(mesh_node)
	_fx[id] = mesh_node
	return mesh_node


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found:
			return found
	return null


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _find_named(node: Node, wanted: String) -> Node3D:
	if node.name == wanted and node is Node3D:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found:
			return found
	return null


func _has_head(body: Node) -> bool:
	return _skeleton_of(body) != null or _find_loose(body, "head") != null


func _head_point(body: Node) -> Vector3:
	var skel := _skeleton_of(body)
	if skel:
		for b in skel.get_bone_count():
			if "head" in skel.get_bone_name(b).to_lower():
				return _in_body(skel, body, skel.get_bone_global_pose(b).origin)
	var bone := _find_loose(body, "head")
	if bone:
		return _local_point(bone, body)
	return Vector3.ZERO


func _skeleton_of(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _skeleton_of(child)
		if found:
			return found
	return null


func _in_body(node: Node3D, body: Node, point: Vector3) -> Vector3:
	var cur: Node = node
	while cur != null and cur != body:
		if cur is Node3D:
			point = (cur as Node3D).transform * point
		cur = cur.get_parent()
	return point


func _find_loose(node: Node, needle: String) -> Node3D:
	var low := str(node.name).to_lower()
	if node is Node3D and needle in low and node is not AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_loose(child, needle)
		if found:
			return found
	return null


func _lamp(color: Color, energy: float, pos: Vector3, shadows: bool, reach := 8.0, cull := 0xFFFFF) -> void:
	var light := OmniLight3D.new()
	light.light_cull_mask = cull
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = shadows
	light.position = pos
	world_root.add_child(light)


func _grass_material(source: MeshInstance3D) -> ShaderMaterial:
	var tex: Texture2D = null
	var mat := source.get_active_material(0)
	if mat is StandardMaterial3D:
		tex = (mat as StandardMaterial3D).albedo_texture
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/grass.gdshader")
	shader_mat.set_shader_parameter("albedo_tex", tex)
	shader_mat.set_shader_parameter("clear_radius", 1.45)
	shader_mat.set_shader_parameter("fade_radius", 2.35)
	return shader_mat


## Collect the canopy trees and their geometry, plus the props that only need
## their visibility toggled. Called once the stage content is built (and
## again wherever props are added later), so the per-frame fade walks a
## cached list instead of the whole tree hierarchy.
func _cache_canopy() -> void:
	_canopy_props.clear()
	_canopy_meshes.clear()
	_canopy_start.clear()
	_canopy_count.clear()
	_plain_props.clear()
	for node in _props:
		var prop := node as Node3D
		if prop == null:
			continue
		if not bool(prop.get_meta("canopy", false)):
			_plain_props.append(prop)
			continue
		_canopy_props.append(prop)
		_canopy_start.append(_canopy_meshes.size())
		var n := 0
		for gi in prop.find_children("*", "GeometryInstance3D", true, false):
			_canopy_meshes.append(gi as GeometryInstance3D)
			n += 1
		_canopy_count.append(n)


func _open_around(hero: Vector3) -> void:
	if _mode == "hunt":
		_fade_occluders(hero)
	var hs := Vector2.INF
	var reach := 0.0
	if camera != null and _mode == "hunt":
		hs = camera.unproject_position(hero + Vector3(0, HERO_METERS * 0.4, 0))
		reach = viewport.size.x * 0.24 if viewport != null else 280.0
	# Occluders are measured against the camera, not the hero: a hero-side
	# distance blinked rocks and rim trees out of the world as the player
	# walked up to them. The camera is the one that can be crowded.
	var cam_flat := Vector2.INF
	if camera != null:
		cam_flat = Vector2(camera.position.x, camera.position.z)
	# Canopy fade: a tree whose crown covers the hero on screen eases to
	# see-through instead of hiding the fight. The trees and their meshes
	# come from the build-time cache, so no hierarchy is walked per frame.
	for i in _canopy_props.size():
		var prop := _canopy_props[i]
		var want := 0.0
		if hs != Vector2.INF and prop.position.z > hero.z - 1.0:
			var crown := camera.unproject_position(prop.position + Vector3(0, 2.2 * prop.scale.y, 0))
			var d := crown.distance_to(hs)
			want = clampf(1.0 - (d - reach * 0.5) / reach, 0.0, 1.0)
		var cur := float(prop.get_meta("fade", 0.0))
		if absf(cur - want) > 0.005:
			cur = move_toward(cur, want, 0.06)
			prop.set_meta("fade", cur)
			var k := _canopy_start[i]
			var last := k + _canopy_count[i]
			while k < last:
				_canopy_meshes[k].transparency = cur
				k += 1
	# Hide what crowds the lens and blocks the view of the fight.
	for prop in _plain_props:
		var flat := cam_flat - Vector2(prop.position.x, prop.position.z)
		prop.visible = flat.length() > 3.1


func _has_surface(root: Node, material_name: String) -> bool:
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat != null and mat.resource_name == material_name:
				return true
	return false


func _sketchfab_nature(rng: RandomNumberGenerator) -> void:
	var path := "res://assets/models/sketchfab/nature/grove.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var lib := packed.instantiate()
	world_root.add_child(lib)
	var holder := _find_named(lib, "GLTF_SceneRootNode")
	if holder == null:
		holder = lib
	var plants: Array[Node3D] = []
	var stones: Array[Node3D] = []
	for child in holder.get_children():
		if not child is Node3D:
			continue
		var piece := child as Node3D
		var low := str(piece.name).to_lower()
		if "cliff" in low or "astronaut" in low or "plane" in low or "lod1" in low or "lod2" in low:
			piece.visible = false
			continue
		piece.visible = false
		if _has_surface(piece, "Leaf_B"):
			# Leaf_B is the pack's red-pink blossom; it fought every boss
			# silhouette and read as candy against the forged palette.
			continue
		if "rock" in low or "stone" in low:
			stones.append(piece)
		else:
			plants.append(piece)
	var sources: Array[Node3D] = plants if not plants.is_empty() else stones
	if sources.is_empty():
		lib.visible = false
		return
	var count := 12 if _tier() == "low" else 24
	for i in count:
		var src: Node3D = sources[rng.randi() % sources.size()]
		if i % 5 == 4 and not stones.is_empty():
			src = stones[rng.randi() % stones.size()]
		var prop := src.duplicate() as Node3D
		prop.visible = true
		world_root.add_child(prop)
		prop.global_transform = src.global_transform
		# Yaw only. Setting rotation.y would wipe the pack's axis fix.
		prop.rotate_y(rng.randf() * TAU)
		var low := str(src.name).to_lower()
		# The pack's rocks have no usable material and rendered as white
		# slabs once the wider camera brought the rim into view.
		if "rock" in low or "stone" in low:
			_paint_rock(prop)
		else:
			_crisp_leaves(prop)
		var target := rng.randf_range(2.1, 3.3)
		if "bush" in low:
			target = rng.randf_range(0.55, 0.95)
		elif "stone" in low:
			target = rng.randf_range(0.35, 0.6)
		elif "rock_medium" in low or "rock-medium" in low:
			target = rng.randf_range(0.7, 1.15)
		elif "rock" in low:
			target = rng.randf_range(0.8, 1.2)
		elif "dead" in low:
			target = rng.randf_range(1.5, 2.3)
		var box := _measure(prop)
		var fit := target / maxf(box.size.y, 0.05)
		if "rock" in low or "stone" in low:
			# Flat slabs scaled by height alone became car-sized; cap the footprint.
			fit = minf(fit, 1.7 / maxf(maxf(box.size.x, box.size.z), 0.05))
		prop.scale *= fit
		box = _measure(prop)
		var dest := _rim_point(rng)
		var mid := box.get_center()
		prop.position += Vector3(dest.x - mid.x, -box.position.y, dest.z - mid.z)
		_props.append(prop)
	lib.visible = false


## The CC0 log and stump ship without a texture and render white. Wrap them
## in the kit's own bark, projected so seams do not matter.
func _bark(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/models/tree_a_Bark_NormalTree.png")
		mat.albedo_color = Color("8a7d70")
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
		mat.roughness = 1.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_bark(child)


var _rock_mat: ShaderMaterial


func _paint_rock(node: Node) -> void:
	if _rock_mat == null:
		_rock_mat = ShaderMaterial.new()
		_rock_mat.shader = load("res://shaders/rock.gdshader")
		_rock_mat.set_shader_parameter("rock_color", load("res://assets/textures/rock_color.jpg"))
		_rock_mat.set_shader_parameter("rock_normal", load("res://assets/textures/rock_normal.jpg"))
		_rock_mat.set_shader_parameter("rock_rough", load("res://assets/textures/rock_rough.jpg"))
		_rock_mat.set_shader_parameter("moss_color", load("res://assets/textures/moss_color.jpg"))
		_rock_mat.set_shader_parameter("moss_normal", load("res://assets/textures/moss_normal.jpg"))
		var b := _biome
		_rock_mat.set_shader_parameter("moss", 0.0 if b in ["frost", "volcano"] else (0.9 if b == "mushroom" else 0.7))
		_rock_mat.set_shader_parameter("snow", 0.9 if b == "frost" else 0.0)
		if b == "volcano":
			_rock_mat.set_shader_parameter("rock_tint", Vector3(0.3, 0.27, 0.27))
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _rock_mat
	for child in node.get_children():
		_paint_rock(child)


## Boss fights: push the hero's cool rim and key so the knight stays the
## brightest read against a large dark boss.
func boss_focus(on: bool) -> void:
	if is_instance_valid(_hero_rim):
		_hero_rim.light_energy = 6.0 if on else 3.2
	if is_instance_valid(_hero_key):
		_hero_key.light_energy = 3.4 if on else 2.2


func _outline(root: Node, color := Color("2b1210"), width := 0.012) -> void:
	var shader: Shader = load("res://shaders/outline.gdshader")
	_outline_walk(root, shader, color, width)


func _outline_walk(node: Node, shader: Shader, color: Color, width: float) -> void:
	if node is MeshInstance3D and not str(node.name).begins_with("Catch"):
		var mesh := node as MeshInstance3D
		if mesh.mesh:
			for i in mesh.mesh.get_surface_count():
				var base := mesh.get_active_material(i)
				if base == null:
					continue
				var mat := base.duplicate()
				var shell := ShaderMaterial.new()
				shell.shader = shader
				# Grow is in mesh space. A quantized Sketchfab mesh is thousands
				# of units tall before its node scale, so the outline tracks height.
				var height := mesh.mesh.get_aabb().size.y
				shell.set_shader_parameter("grow", maxf(height * width, 0.001))
				shell.set_shader_parameter("line_color", color)
				mat.next_pass = shell
				mesh.set_surface_override_material(i, mat)
	for child in node.get_children():
		_outline_walk(child, shader, color, width)


func _hide_catch(node: Node) -> void:
	if str(node.name).begins_with("Catch") and node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide_catch(child)


func _clip_name(player: AnimationPlayer, clips: Dictionary, state: String) -> String:
	var named := str(clips.get(state, ""))
	if named != "" and player.has_animation(named):
		return named
	var keys: Array = ["idle", "stand"]
	match state:
		"run":
			keys = ["run", "walk", "move", "fly", "locomotion"]
		"attack":
			keys = ["attack", "punch", "bite", "slash", "shoot", "fly"]
		"hit":
			keys = ["hit", "hurt", "react", "damage"]
		"death":
			keys = ["death", "die", "dead"]
	for anim in player.get_animation_list():
		var low := anim.to_lower()
		for key in keys:
			if key in low:
				return anim
	var idle := str(clips.get("idle", ""))
	if idle != "" and player.has_animation(idle):
		return idle
	return ""


func _measure_local(node: Node) -> AABB:
	var acc := {"ok": false, "box": AABB()}
	for child in node.get_children():
		_measure_into(child, Transform3D.IDENTITY, acc)
	if not bool(acc["ok"]):
		return AABB(Vector3.ZERO, Vector3(0.4, 1.0, 0.4))
	return acc["box"]


func _local_point(node: Node3D, root: Node) -> Vector3:
	var point := Vector3.ZERO
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			point = (cur as Node3D).transform * point
		cur = cur.get_parent()
	return point


func _to3(pos: Vector2) -> Vector3:
	return Vector3(pos.x * SCALE, 0.0, pos.y * SCALE)


## Light, fog, and foliage grade per biome so each hunt has its own air.
func _biome_mood(biome_id: String) -> void:
	var holder := world_root.get_node_or_null("World") as WorldEnvironment
	if holder == null or holder.environment == null:
		return
	var env := holder.environment
	var grass := Vector3.ONE
	match biome_id:
		"mushroom":
			# Night biome, crisp pass: a bright near-white moon key, a neutral
			# fill and only a breath of neutral fog, so the models read like
			# the showcase renders; the mood lives in the props and the boss.
			env.fog_light_color = Color(0.36, 0.37, 0.41)
			env.fog_density = 0.0007
			env.ambient_light_color = Color("c4c7d3")
			env.ambient_light_energy = 0.8
			sun.light_color = Color("f4f2ff")
			sun.light_energy = 1.75
			grass = Vector3(0.92, 0.95, 1.0)
		"frost":
			env.fog_light_color = Color(0.72, 0.8, 0.94)
			env.fog_density = 0.005
			env.ambient_light_color = Color("c8d8f0")
			sun.light_color = Color("e8f0ff")
			sun.light_energy = 1.45
			grass = Vector3(0.8, 0.95, 1.05)
		"volcano":
			env.fog_light_color = Color(0.4, 0.16, 0.08)
			env.fog_density = 0.007
			env.ambient_light_color = Color("c07050")
			sun.light_color = Color("ff9a5a")
			sun.light_energy = 1.25
			grass = Vector3(0.45, 0.36, 0.3)
	if biome_id in ["meadow", "mushroom"]:
		_crisp_hunt(env, biome_id)
	for mat in _grass_mats:
		(mat as ShaderMaterial).set_shader_parameter("biome_tint", grass)


## Hunt-only crisp grade for the meadow and the night biome (both lairs
## included): this edits the hunt stage's own Environment, never the shared
## one the Heroes/Home pedestal builds. No bloom at all (the shared env
## already has no grade), light neutral fog, a brighter exposure and fill,
## and a stronger cool rim light.
func _crisp_hunt(env: Environment, biome_id: String) -> void:
	env.glow_enabled = false
	env.tonemap_exposure = 1.22
	env.fog_aerial_perspective = 0.04
	if biome_id == "meadow":
		env.fog_density = 0.0005
		env.fog_light_color = Color(0.5, 0.56, 0.62)
		env.ambient_light_energy = 0.68
		sun.light_energy = 2.0
	for child in world_root.get_children():
		if child is DirectionalLight3D and child != sun:
			# The cool rim from _lights: lift it so silhouettes separate.
			(child as DirectionalLight3D).light_energy = 1.75


func _biome_tint(biome_id: String) -> Vector3:
	match biome_id:
		"mushroom":
			return Vector3(0.86, 0.92, 1.0)
		"frost":
			return Vector3(0.84, 0.92, 1.08)
		"volcano":
			return Vector3(1.08, 0.78, 0.62)
		_:
			# Richer, cleaner green; less olive in the midtones.
			return Vector3(0.9, 1.06, 0.8)


func _dirt_tint(biome_id: String) -> Vector3:
	match biome_id:
		"frost":
			return Vector3(0.95, 0.98, 1.05)
		"volcano":
			return Vector3(0.7, 0.55, 0.5)
		_:
			return Vector3(1.0, 0.94, 0.86)


func _tier() -> String:
	if _software() and Quality.level() == "high":
		return "medium"
	return Quality.level()


func _software() -> bool:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	return "llvmpipe" in name or "lavapipe" in name or "swiftshader" in name


# --- Quality tiers -----------------------------------------------------------

func _apply_render_scale() -> void:
	var scale := Quality.render_scale()
	viewport.scaling_3d_scale = scale
	viewport.mesh_lod_threshold = {"high": 1.0, "medium": 3.0, "low": 6.0}.get(Quality.level(), 3.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	if Quality.level() == "low":
		_apply_low()


## Rolling frame-time watch: two slow 2 s windows in a row drop one tier.
func _watch_frames(delta: float) -> void:
	if not Quality.can_auto_drop() or Quality.level() == "low":
		return
	_frame_acc += delta
	_frame_n += 1
	if _frame_acc < Quality.WINDOW:
		return
	var avg := _frame_acc / float(_frame_n)
	_frame_acc = 0.0
	_frame_n = 0
	_slow_windows = _slow_windows + 1 if avg > Quality.SLOW_FRAME else 0
	if _slow_windows < 2:
		return
	_slow_windows = 0
	Quality.set_level("medium" if Quality.level() == "high" else "low")
	print("QUALITY drop to ", Quality.level(), " (avg frame %.1f ms)" % (avg * 1000.0))
	_apply_render_scale()


## Low tier: thin the grass, no sun shadows, no SSAO or glow.
func _apply_low() -> void:
	# The grass is split into grid cells now, so every cell keeps its own
	# share of the blades: a cell that rounds its share down to nothing
	# would leave a bald patch where it stood.
	for node in _grass_nodes:
		if not is_instance_valid(node) or node.multimesh == null:
			continue
		var n := node.multimesh.instance_count
		if n <= 0:
			continue
		node.multimesh.visible_instance_count = maxi(1, int(round(n * 0.4)))
	if sun != null:
		sun.shadow_enabled = false
	if _env_ref != null:
		_env_ref.ssao_enabled = false
		_env_ref.glow_enabled = false
		_env_ref.ssil_enabled = false


# --- Explore world ------------------------------------------------------------
# The explore map drawn in 3D: chunked terrain with the trails and forest edge
# from the map's shapes, forest walls and ground cover as per-chunk
# MultiMeshes (one draw per mesh per visible chunk), a few unique landmarks,
# loot chests, the boss lair, and fog of war as one big projected decal.

var world_map: HuntMap = null
var _fog_decal: Decal
## Unexplored ground stays a murky blue-black silhouette (never a black
## void); explored but out of sight dims by about a third.
const FOG_DARK := 0.8
const FOG_SEEN := 0.38
var _fog_dirty_t := 0.0
var _fog_pending := false
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog_alpha := PackedFloat32Array()
var _chest_nodes: Array = []
var _sim_ref: RunSim = null
const FOG_PAD := 20
## Render chunk: 2x2 map cells, so a screen touches 2-4 chunks.
const RCHUNK := Vector2(2240, 2560)


func bind_world(map: HuntMap, biome_id: String) -> void:
	_mode = "hunt"
	_arena_built = false
	_arena_reset()
	_biome = biome_id
	world_map = map
	viewport.transparent_bg = false
	_grass_mats.clear()
	_grass_nodes.clear()
	_props.clear()
	_cache_canopy()
	_contacts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id) + 91 + map.seed * 31
	_world_ground(map, biome_id)
	_world_forest(map, biome_id, rng)
	_world_cover(map, biome_id, rng)
	_world_landmarks(map, biome_id, rng)
	if _hp_probe:
		_hp_probe.free()
		_hp_probe = null
	_world_chests(map, rng)
	_world_lair(map)
	_world_fog(map)
	# The world builders are done: cache the canopy trees and their meshes.
	_cache_canopy()
	_biome_mood(biome_id)
	_apply_render_scale()
	_look = _to3(map.start)
	_dist = DIST
	_ready_cam = false
	_frame(_look)


func _world_ground(map: HuntMap, biome_id: String) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	for layer in ["grass", "forest", "dirt"]:
		mat.set_shader_parameter(layer + "_color", load("res://assets/textures/ground_%s_color.jpg" % layer))
		mat.set_shader_parameter(layer + "_normal", load("res://assets/textures/ground_%s_normal.jpg" % layer))
		mat.set_shader_parameter(layer + "_data", load("res://assets/textures/ground_%s_data.jpg" % layer))
	mat.set_shader_parameter("noise_tex", _terrain_noise())
	mat.set_shader_parameter("noise_uv", 1.0 / float(NOISE_CELLS))
	mat.set_shader_parameter("tint", _biome_tint(biome_id))
	mat.set_shader_parameter("dirt_tint", _dirt_tint(biome_id))
	mat.set_shader_parameter("snow", 0.75 if biome_id == "frost" else 0.0)
	mat.set_shader_parameter("ash", 0.85 if biome_id == "volcano" else 0.0)
	mat.set_shader_parameter("litter", 0.0 if biome_id == "volcano" else (0.3 if biome_id == "frost" else 1.0))
	mat.set_shader_parameter("arena", Vector4(-100, -100, 1000, 1000))
	mat.set_shader_parameter("path_width", 1.35)
	mat.set_shader_parameter("world_mode", true)
	var nodes := PackedVector3Array()
	for n in map.nodes:
		var p: Vector2 = (n["pos"] as Vector2) * SCALE
		nodes.append(Vector3(p.x, p.y, float(n["r"]) * SCALE))
	var segs := PackedVector4Array()
	var widths := PackedFloat32Array()
	for sg in map.segs:
		var a: Vector2 = (sg["a"] as Vector2) * SCALE
		var b: Vector2 = (sg["b"] as Vector2) * SCALE
		segs.append(Vector4(a.x, a.y, b.x, b.y))
		widths.append(float(sg["w"]) * SCALE)
	mat.set_shader_parameter("w_nodes", nodes)
	mat.set_shader_parameter("w_segs", segs)
	mat.set_shader_parameter("w_seg_w", widths)
	mat.set_shader_parameter("w_nnode", mini(nodes.size(), 20))
	mat.set_shader_parameter("w_nseg", mini(segs.size(), 40))
	# One plane per map cell (plus a forest margin ring) so off-screen ground culls.
	var margin := 1
	var cell3 := HuntMap.CELL * SCALE
	var plane := PlaneMesh.new()
	plane.size = cell3
	plane.subdivide_width = 22
	plane.subdivide_depth = 26
	for row in range(-margin, HuntMap.WORLD_ROWS + margin):
		for col in range(-margin, HuntMap.WORLD_COLS + margin):
			var mesh := MeshInstance3D.new()
			mesh.mesh = plane
			mesh.material_override = mat
			mesh.position = Vector3((col + 0.5) * cell3.x, 0, (row + 0.5) * cell3.y)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world_root.add_child(mesh)


## Instances every mesh of a kit model through per-render-chunk MultiMeshes.
## `spots` are world transforms; each mesh keeps its offset in the model.
func _kit_chunks(model: String, spots: Array, shadows: bool) -> void:
	if spots.is_empty():
		return
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return
	var probe := packed.instantiate()
	if model.begins_with("tree") or model.begins_with("bush"):
		_crisp_leaves(probe)
	if model == "mushroom_tall":
		_paint_mushroom(probe)
	if (model.begins_with("rock") or model.begins_with("pebble_rock")) and model != "rock_lava":
		_paint_rock(probe)
	if model in ["log", "stump"]:
		_bark(probe)
	var buckets := {}
	var rc := RCHUNK * SCALE
	for xf in spots:
		var at: Vector3 = (xf as Transform3D).origin
		var key := Vector2i(int(floor(at.x / rc.x)), int(floor(at.z / rc.y)))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(xf)
	for mi_node in probe.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := _chain(mi, probe)
		var mesh: Mesh = mi.mesh
		var baked := false
		for si in mesh.get_surface_count():
			if mi.get_surface_override_material(si) != null:
				baked = true
		if baked:
			mesh = mi.mesh.duplicate()
			for si in mesh.get_surface_count():
				(mesh as ArrayMesh).surface_set_material(si, mi.get_active_material(si))
		for key in buckets:
			var list: Array = buckets[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = list.size()
			var top := (local * mesh.get_aabb()).end.y
			for i in list.size():
				var txf := list[i] as Transform3D
				mm.set_instance_transform(i, txf * local)
				mm.set_instance_color(i, Color.WHITE)
				_occl_add(txf.origin, top * txf.basis.get_scale().y, mm, i)
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mi.material_override:
				inst.material_override = mi.material_override
			world_root.add_child(inst)
	probe.free()


const HANDPAINTED := "res://assets/models/sketchfab/nature/handpainted.glb"
var _hp_probe: Node3D
var _hp_mats := {}


## One piece of the hand-painted tree pack (rudolfs, CC-BY 4.0) chunked into
## MultiMeshes like _kit_chunks. Each tree is a single mesh and material.
## The material is graded toward a darker, cooler, damp forest.
## Occluder index: every packed tree instance by 4 m ground cell, so the
## few that stand between the camera and the hero can fade.
var _occl := {}
var _occl_faded := {}
const OCCL_CELL := 4.0
func _occl_add(at: Vector3, height: float, mm: MultiMesh, idx: int) -> void:
	if height < 1.2:
		return
	var key := Vector2i(int(floor(at.x / OCCL_CELL)), int(floor(at.z / OCCL_CELL)))
	if not _occl.has(key):
		_occl[key] = []
	_occl[key].append([at, height, mm, idx])


## Trees whose crown covers the hero (or a nearby fight) on screen and stand
## nearer the camera fade to a dithered ghost; they ease back once clear.
func _fade_occluders(hero: Vector3) -> void:
	if camera == null or _occl.is_empty():
		return
	var vw: float = viewport.size.x if viewport != null else 1179.0
	# Screen points to keep clear: the hero (wide), plus foes that are
	# hunting it or close by (narrow), so nothing attacks out of a canopy.
	var keep := [[camera.unproject_position(hero + Vector3(0, HERO_METERS * 0.4, 0)), vw * 0.24]]
	if _sim_ref != null:
		var foes := []
		for actor in _sim_ref.actors:
			if not actor.alive or actor.team == 0 or actor.kind == "boss":
				continue
			var at3 := _to3(actor.pos)
			var d := Vector2(at3.x - hero.x, at3.z - hero.z).length()
			if (actor.aggro and d < 14.0) or d < 7.0:
				foes.append([d, at3])
		foes.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(foes.size(), 8):
			keep.append([camera.unproject_position(foes[i][1] + Vector3(0, HERO_METERS * 0.3, 0)), vw * 0.08])
	var want := {}
	var c := Vector2i(int(floor(hero.x / OCCL_CELL)), int(floor(hero.z / OCCL_CELL)))
	for dx in range(-4, 5):
		for dz in range(-1, 9):
			for e in _occl.get(c + Vector2i(dx, dz), []):
				var at: Vector3 = e[0]
				if at.z < hero.z - 3.0:
					continue
				var h: float = e[1]
				# Distance from each kept point to the trunk-to-crown segment on screen.
				var a := camera.unproject_position(at + Vector3(0, h * 0.2, 0))
				var b := camera.unproject_position(at + Vector3(0, h, 0))
				var ab := b - a
				# Crowns are wide: a tree whose trunk is off to the side can
				# still spread its canopy over the hero. Widen by the crown's
				# on-screen radius (about a third of the tree's height).
				var crown_px := absf(b.y - camera.unproject_position(at + Vector3(0, h * 0.62, 0)).y)
				for k in keep:
					var hs: Vector2 = k[0]
					var t := clampf((hs - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
					if (a + ab * t).distance_to(hs) < float(k[1]) + crown_px * 0.9:
						want[e] = true
						break
	_occl_hit = not want.is_empty()
	for e in want:
		_occl_faded[e] = true
	for e in _occl_faded.keys():
		var mm: MultiMesh = e[2]
		var cur := mm.get_instance_color(e[3]).a
		# Fully clear over the hero: a hashed 10-30% ghost reads as noise
		# over dark plate at phone size.
		var to := 0.0 if want.has(e) else 1.0
		var nxt := move_toward(cur, to, 0.14)
		mm.set_instance_color(e[3], Color(1, 1, 1, nxt))
		if nxt >= 1.0 and not want.has(e):
			_occl_faded.erase(e)


func _pack_chunks(piece_name: String, spots: Array, shadows: bool, grade: Color) -> void:
	if spots.is_empty() or not ResourceLoader.exists(HANDPAINTED):
		return
	if _hp_probe == null:
		_hp_probe = (load(HANDPAINTED) as PackedScene).instantiate() as Node3D
	var piece := _hp_probe.find_child(piece_name, true, false) as Node3D
	if piece == null:
		return
	var base := _chain(piece, _hp_probe).origin
	var buckets := {}
	var rc := RCHUNK * SCALE
	for xf in spots:
		var at: Vector3 = (xf as Transform3D).origin
		var key := Vector2i(int(floor(at.x / rc.x)), int(floor(at.z / rc.y)))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(xf)
	for mi_node in piece.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := _chain(mi, _hp_probe)
		local.origin -= Vector3(base.x, 0.0, base.z)
		var mesh: Mesh = mi.mesh
		var key_m := str(mesh.get_instance_id()) + str(grade)
		if not _hp_mats.has(key_m):
			var dup := mesh.duplicate() as ArrayMesh
			for si in dup.get_surface_count():
				var src := dup.surface_get_material(si) as StandardMaterial3D
				if src == null:
					continue
				var mat := src.duplicate() as StandardMaterial3D
				mat.albedo_color = src.albedo_color * grade
				mat.roughness = 0.88
				mat.metallic_specular = 0.25
				if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				# Dithered (hashed) alpha so a tree between the camera and the
				# fight can fade per instance through its MultiMesh colour
				# (see _fade_occluders); opaque trees stay a single pass.
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
				mat.alpha_hash_scale = 1.0
				mat.vertex_color_use_as_albedo = true
				mat.rim_enabled = true
				mat.rim = 0.25
				mat.rim_tint = 0.7
				dup.surface_set_material(si, mat)
			_hp_mats[key_m] = dup
		mesh = _hp_mats[key_m]
		for key in buckets:
			var list: Array = buckets[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = list.size()
			var top := (local * mesh.get_aabb()).end.y
			for i in list.size():
				var txf := list[i] as Transform3D
				mm.set_instance_transform(i, txf * local)
				mm.set_instance_color(i, Color.WHITE)
				_occl_add(txf.origin, top * txf.basis.get_scale().y, mm, i)
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world_root.add_child(inst)


func _world_forest(map: HuntMap, biome_id: String, rng: RandomNumberGenerator) -> void:
	var kinds: Array = ["tree_a", "tree_b", "tree_pine"]
	var edge: Array = ["bush", "bush_flower"]
	match biome_id:
		"mushroom":
			kinds = ["mushroom_tall", "tree_pine_b", "tree_twist"]
			edge = ["bush"]
		"frost":
			kinds = ["tree_pine", "tree_pine_b"]
			edge = ["rock_b"]
		"volcano":
			kinds = ["tree_dead", "tree_dead", "rock_lava"]
			edge = ["rock_b"]
	# Hand-painted pack: pines and spruces make the wall, oaks break it up,
	# dead snags and stumps scatter through. Graded per biome.
	var pack: Array = []
	var grade := Color(0.74, 0.8, 0.72)
	if ResourceLoader.exists(HANDPAINTED):
		match biome_id:
			"meadow":
				# Five pieces, not eight: each extra species costs a draw per
				# render chunk, and the pack fight peaked at 157 3D draws.
				pack = ["pine_2", "pine_3", "spruce_3", "oak_green_1", "pine_2", "pine_3"]
			"mushroom":
				pack = ["spruce_2", "spruce_3", "oak_green_1", "oak_dead_3"]
				grade = Color(0.62, 0.66, 0.8)
			"frost":
				pack = ["pine_2", "pine_3", "spruce_3", "pine_2", "pine_dead_2"]
				grade = Color(0.78, 0.88, 0.98)
			"volcano":
				pack = ["oak_dead_1", "oak_dead_3", "pine_dead_2", "birch_dead", "spruce_dead"]
				grade = Color(0.5, 0.42, 0.4)
	if not pack.is_empty():
		kinds = pack
	var tier := _tier()
	# Dense walls: trees every ~2.4 m along the edge, thinning deeper in.
	var step := 115.0 if tier == "high" else (125.0 if tier == "medium" else 150.0)
	var by_kind := {}
	var span := map.size + Vector2(600, 600)
	var y := -300.0
	while y < span.y - 300.0:
		var x := -300.0
		while x < span.x - 300.0:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * step
			var d := map.depth(p)
			x += step
			if d > -60.0 or d < -620.0:
				continue
			if d < -260.0 and rng.randf() < 0.6:
				continue
			# Trees cluster: noise thins the deep woods into groves with dark gaps.
			if d < -160.0 and sin(p.x * 0.004 + 1.3) * cos(p.y * 0.0035) > 0.55 and rng.randf() < 0.6:
				continue
			var kind: String = kinds[rng.randi() % kinds.size()]
			var s := rng.randf_range(2.2, 3.2) * (1.15 if d < -300.0 else 1.0)
			if not pack.is_empty():
				# Pack trees are true scale (7-10 m pines): vary them gently,
				# and drop a dead snag or stump in now and then.
				s = rng.randf_range(0.95, 1.35) * (1.1 if d < -300.0 else 1.0)
				if rng.randf() < 0.07:
					kind = ["pine_dead_2", "oak_dead_1"][rng.randi() % 2]
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.9, 1.1), s * rng.randf_range(0.9, 1.25), s * rng.randf_range(0.9, 1.1)))
			if not by_kind.has(kind):
				by_kind[kind] = []
			by_kind[kind].append(Transform3D(basis, _to3(p)))
		y += step
	for kind in by_kind:
		if not pack.is_empty():
			_pack_chunks(kind, by_kind[kind], tier == "high", grade)
		else:
			_kit_chunks(kind, by_kind[kind], tier == "high")
	# Undergrowth along the edge softens the forest line.
	var bushes := {}
	for sg in map.segs:
		var a: Vector2 = sg["a"]
		var b: Vector2 = sg["b"]
		var len := a.distance_to(b)
		var n := int(len / 140.0)
		for k in n:
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.35:
					continue
				var t := (float(k) + rng.randf()) / float(maxi(n, 1))
				var dir := (b - a).normalized()
				var p: Vector2 = a.lerp(b, t) + dir.orthogonal() * side * (float(sg["w"]) * 0.5 + rng.randf_range(10.0, 70.0))
				if map.depth(p) > -8.0:
					continue
				var kind: String = edge[rng.randi() % edge.size()]
				var s := rng.randf_range(1.1, 1.9)
				if not bushes.has(kind):
					bushes[kind] = []
				bushes[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), _to3(p)))
	for kind in bushes:
		if not pack.is_empty() and biome_id in ["meadow", "mushroom"] and kind == "bush":
			_pack_chunks("bush", bushes[kind], false, grade * Color(0.9, 0.95, 0.85))
		else:
			_kit_chunks(kind, bushes[kind], false)


func _world_cover(map: HuntMap, biome_id: String, rng: RandomNumberGenerator) -> void:
	var tier := _tier()
	var green := not biome_id in ["frost", "volcano"]
	# Grass: sparse accent blades on the open ground (the terrain carries the turf).
	var per_m2 := 0.5 if tier == "high" else (0.3 if tier == "medium" else 0.14)
	var probe := (load("res://assets/models/grass_short.glb") as PackedScene).instantiate()
	var src := _first_mesh(probe)
	var posed := _chain(src, probe)
	var grass := _grass_material(src)
	_grass_mats.append(grass)
	var cells := {}
	var area_px := map.size.x * map.size.y
	var tries := int(area_px * SCALE * SCALE * per_m2 * 1.6)
	for i in tries:
		var p := Vector2(rng.randf() * map.size.x, rng.randf() * map.size.y)
		if map.depth(p) < 20.0 or map.trail_dist(p) < 50.0:
			continue
		var key := Vector2i(int(p.x / HuntMap.CELL.x), int(p.y / HuntMap.CELL.y))
		if not cells.has(key):
			cells[key] = []
		var s := rng.randf_range(0.45, 0.7)
		cells[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), _to3(p)) * posed)
	for key in cells:
		var list: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = src.mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = grass
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.lod_bias = 0.35
		_grass_nodes.append(node)
		world_root.add_child(node)
	probe.free()
	# Clustered dressing: each cluster is one kind, a few pieces of varied size.
	var kit: Array = [["fern", 0.9, 1.5], ["rock_a", 0.5, 1.1], ["mushroom_tall", 1.0, 2.0], ["clover", 0.6, 0.9]]
	if green:
		kit.append(["flower_a", 1.6, 2.4])
		kit.append(["flower_b", 1.6, 2.4])
	else:
		kit = [["rock_a", 0.5, 1.2], ["rock_b", 0.5, 1.0], ["pebble_rock", 0.6, 1.0]]
	var spots := {}
	var clusters := int(area_px * SCALE * SCALE / 900.0 * (1.0 if tier != "low" else 0.6))
	for c in clusters:
		var center := Vector2(rng.randf() * map.size.x, rng.randf() * map.size.y)
		var d := map.depth(center)
		if d < 30.0 or map.trail_dist(center) < 90.0:
			continue
		var row: Array = kit[rng.randi() % kit.size()]
		var kind: String = row[0]
		for k in rng.randi_range(3, 7):
			var p := center + Vector2(rng.randfn(0.0, 55.0), rng.randfn(0.0, 55.0))
			if map.depth(p) < 10.0 or map.trail_dist(p) < 60.0:
				continue
			var s := rng.randf_range(float(row[1]), float(row[2])) * (1.4 if k == 0 else 1.0)
			if not spots.has(kind):
				spots[kind] = []
			spots[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), _to3(p)))
	for kind in spots:
		_kit_chunks(kind, spots[kind], false)


var _landmarks: Array = []
func _world_landmarks(map: HuntMap, biome_id: String, rng: RandomNumberGenerator) -> void:
	for l in map.landmarks:
		var at := _to3(l["pos"])
		var yaw: float = l["yaw"]
		match str(l["kind"]):
			"great_tree" when ResourceLoader.exists(HANDPAINTED):
				# A towering hand-painted elder, graded like the forest, with a
				# root stone at its foot as the landmark's anchor.
				var elder := {"meadow": "oak_green_2", "mushroom": "oak_dead_3", "frost": "pine_3"}.get(biome_id, "oak_dead_1") as String
				var g := {"mushroom": Color(0.62, 0.66, 0.8), "frost": Color(0.78, 0.88, 0.98), "volcano": Color(0.5, 0.42, 0.4)}.get(biome_id, Color(0.74, 0.8, 0.72)) as Color
				_pack_chunks(elder, [Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.7), at)], true, g)
				_place_prop("rock_a", at + Vector3(1.4, 0, 0.6), 1.3, true, null, rng)
			"great_tree":
				_place_prop("tree_a" if biome_id in ["meadow", "mushroom"] else ("tree_pine" if biome_id == "frost" else "tree_dead"), at, 4.6, true, null, rng)
			"standing_stones":
				for k in 3:
					var off := Vector3(cos(yaw + k * 2.1), 0, sin(yaw + k * 2.1)) * 1.3
					_place_prop("rock_b", at + off, 2.2, true, null, rng)
					var st: Node3D = _props[-1]
					st.scale *= Vector3(0.6, 2.3, 0.6)
					st.rotation = Vector3(rng.randf_range(-0.1, 0.1), yaw + k, rng.randf_range(-0.1, 0.1))
			"ruin":
				_place_prop("den", at, 2.6, true, null, rng)
			"crystal":
				_place_prop("crystal", at, 3.2, true, null, rng)
			"hollow_log":
				_place_prop("log", at, 3.6, true, null, rng)
			_:
				_place_prop("rock_a", at, 2.5, true, null, rng)
		var node: Node3D = _props[-1]
		node.rotation.y = yaw
		# Landmarks are not field dressing: keep them out of the near-hero hide.
		_props.erase(node)
		if str(l["kind"]) == "standing_stones":
			for k in 2:
				_props.erase(_props[-1])
		_landmarks.append(node)


func _world_chests(map: HuntMap, rng: RandomNumberGenerator) -> void:
	_chest_nodes.clear()
	for c in map.loot:
		var chest := Chest3D.new("silver" if str(c["tier"]) == "rare" else "wood")
		chest.scale = Vector3.ONE * 1.5
		chest.position = _to3(c["pos"])
		chest.rotation.y = rng.randf_range(-0.6, 0.6)
		if chest.inner_light:
			chest.inner_light.visible = false
		var glow := _decal(3.2, {"ring_color": Color(1.0, 0.8, 0.35, 0.5), "ring_radius": 0.36, "ring_width": 0.02, "ring_glow": 0.9, "shadow_alpha": 0.55, "shadow_radius": 0.3, "pulse": 1.0})
		glow.position = chest.position + Vector3(0, 0.03, 0)
		world_root.add_child(glow)
		world_root.add_child(chest)
		_chest_nodes.append({"pos": c["pos"], "node": chest, "glow": glow})


## A looted chest throws its lid and its ring goes out.
func loot_open(at: Vector2) -> void:
	for c in _chest_nodes:
		if (c["pos"] as Vector2).distance_to(at) > 4.0:
			continue
		var chest: Chest3D = c["node"]
		var tw := create_tween()
		tw.tween_method(chest.set_open, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		(c["glow"] as Node3D).visible = false
		_spark(chest.position + Vector3(0, 0.8, 0), Color("ffd27a"))


func _world_lair(map: HuntMap) -> void:
	var r := map.lair_r * SCALE
	var rune := _decal(r * 1.7, {"ring_color": Color(0.85, 0.2, 0.12, 0.55), "ring_radius": 0.42, "ring_width": 0.01, "ring_glow": 0.7, "shadow_alpha": 0.35, "shadow_radius": 0.5, "rune": true, "pulse": 0.0})
	rune.position = _to3(map.lair) + Vector3(0, 0.025, 0)
	world_root.add_child(rune)
	# Dead trees and bones of rock lean in around the lair's rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var spots: Array = []
	for i in 14:
		var ang := TAU * float(i) / 14.0 + rng.randf_range(-0.12, 0.12)
		var p := map.lair + Vector2(cos(ang), sin(ang)) * (map.lair_r + rng.randf_range(20.0, 120.0))
		if map.depth(p) > 0.0:
			continue
		var s := rng.randf_range(2.2, 3.2)
		spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), _to3(p)))
	_kit_chunks("tree_dead", spots, false)


func _world_fog(map: HuntMap) -> void:
	var w := map.grid_w + FOG_PAD * 2
	var h := map.grid_h + FOG_PAD * 2
	_fog_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.03, 0.05, 0.07, FOG_DARK))
	_fog_alpha.resize(map.grid_w * map.grid_h)
	_fog_alpha.fill(FOG_DARK)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	var cell := HuntMap.GRID * SCALE
	_fog_decal = Decal.new()
	_fog_decal.size = Vector3(w * cell, 40.0, h * cell)
	_fog_decal.position = Vector3((map.grid_w * 0.5) * cell, 0.0, (map.grid_h * 0.5) * cell)
	_fog_decal.texture_albedo = _fog_tex
	_fog_decal.albedo_mix = 1.0
	_fog_decal.upper_fade = 0.0
	_fog_decal.lower_fade = 0.0
	_fog_decal.normal_fade = 0.0
	_fog_decal.distance_fade_enabled = false
	world_root.add_child(_fog_decal)
	if OS.get_environment("CC_NOFOG") == "1":
		_fog_decal.visible = false


## Fog follows the sim's reveal: unexplored ground is near-black, seen but
## out-of-sight ground dims, and what the hero sees is clear. Each cell eases
## toward its target so the reveal edge glides instead of stepping.
func sync_fog(sim: RunSim, delta: float) -> void:
	if _fog_img == null or not sim.explore:
		return
	var map := sim.map
	var w := map.grid_w
	var data := _fog_img.get_data()
	var stride := (w + FOG_PAD * 2) * 4
	var k := clampf(delta * 6.0, 0.0, 1.0)
	var changed := false
	for i in _fog_alpha.size():
		var want := 0.0 if sim.fog_now[i] == 1 else (FOG_SEEN if sim.fog_seen[i] == 1 else FOG_DARK)
		var a := _fog_alpha[i]
		if absf(a - want) < 0.004:
			continue
		a = lerpf(a, want, k) if absf(a - want) > 0.02 else want
		_fog_alpha[i] = a
		var x := i % w + FOG_PAD
		var y := i / w + FOG_PAD
		data[y * stride + x * 4 + 3] = int(a * 255.0)
		changed = true
	# Decals read their textures from a shared atlas that only rebuilds when a
	# decal's texture changes identity, so updating in place never shows; hand
	# the decal a fresh texture instead, at most ~8 times a second.
	if changed:
		_fog_img.set_data(w + FOG_PAD * 2, map.grid_h + FOG_PAD * 2, false, Image.FORMAT_RGBA8, data)
		_fog_pending = true
	_fog_dirty_t += delta
	if _fog_pending and _fog_dirty_t >= 0.12:
		_fog_dirty_t = 0.0
		_fog_pending = false
		_fog_tex = ImageTexture.create_from_image(_fog_img)
		_fog_decal.texture_albedo = _fog_tex



## Explore lairs: raise a standing stone on every stone the sim placed (the
## ring is trimmed to the lair's open ground there), so what blocks is what shows.
## The stones come from the pool made ahead of the fight, so the lair's
## ground is only stood up here, never built.
func _arena_from_sim(sim: RunSim) -> void:
	_arena_prepare_sim(sim)
	_arena_build_all()
	var arena := _arena_now()
	if arena.is_empty():
		return
	var slots: Array = arena["slots"]
	var i := 0
	for o in sim.obstacles:
		var at := _to3(Vector2(o.x, o.y))
		if Vector2(o.x, o.y).distance_to(sim.map.lair) > sim.map.lair_r + 200.0:
			continue
		if i >= slots.size():
			break
		var node: Node3D = slots[i].get("node")
		if node != null:
			_arena_stand(slots[i], node, at)
		i += 1
	# The stones the fight did not need stay out of the clearing.
	for k in range(i, slots.size()):
		var spare: Node3D = slots[k].get("node")
		if spare != null:
			spare.visible = false
	arena["root"].visible = true


# --- Class-combat visuals (events from run_sim ROLE_TUNING) -----------------
# Each effect is one short-lived additive quad driven by a tween, so nothing
# lingers and an idle hunt costs no draw calls.

const FX_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform int kind = 0;          // 0 cleave arc, 1 shock ring, 2 streak, 3 glint, 4 mote
uniform float t = 0.0;         // 0..1 life
uniform float half_arc = 1.4;  // cleave half-angle (radians)
uniform vec3 color : source_color = vec3(1.0);
uniform float gain = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = 0.0;
	if (kind == 0) {
		// Crescent swept from one edge of the arc to the other, brightest at
		// the leading edge, on the outer 45% of the reach.
		float ang = atan(p.x, -p.y);
		float sweep = mix(-half_arc, half_arc, smoothstep(0.0, 0.55, t));
		float behind = clamp((sweep - ang) / (half_arc * 1.2), 0.0, 1.0);
		float inside = step(-half_arc, ang) * step(ang, sweep);
		float band = smoothstep(0.55, 0.8, r) * (1.0 - smoothstep(0.93, 1.0, r));
		// A hard bright blade line along the reach plus a hot leading edge,
		// so the swing reads as a slash at phone size, not a soft haze.
		float line = 1.0 - smoothstep(0.0, 0.035, abs(r - 0.88));
		float lead = 1.0 - smoothstep(0.0, 0.16, sweep - ang);
		a = inside * (band * 0.55 * (1.0 - behind * 0.85) + line * (1.0 - behind * 0.6) * 1.6 + lead * band * 1.4);
		a *= 1.0 - smoothstep(0.6, 1.0, t);
	} else if (kind == 1) {
		float rad = mix(0.2, 0.95, sqrt(t));
		a = (1.0 - smoothstep(0.0, 0.07, abs(r - rad))) * (1.0 - t);
		a += (1.0 - smoothstep(0.0, rad, r)) * 0.25 * (1.0 - t);
	} else if (kind == 2) {
		float across = 1.0 - smoothstep(0.0, 0.9, abs(p.x));
		a = across * smoothstep(-1.0, 0.6, p.y) * (1.0 - smoothstep(0.9, 1.0, p.y)) * (1.0 - t);
	} else if (kind == 3) {
		float star = max(1.0 - smoothstep(0.0, 0.08, abs(p.x)) , 1.0 - smoothstep(0.0, 0.08, abs(p.y))) * (1.0 - smoothstep(0.3, 1.0, r));
		a = (star + (1.0 - smoothstep(0.0, 0.45, r)) * 0.6) * sin(t * 3.14159);
	} else {
		a = (1.0 - smoothstep(0.0, 1.0, r)) * sin(t * 3.14159);
	}
	ALBEDO = color * a * gain;
}
"""
var _fx_shader: Shader


func _fx_quad(size: Vector2, kind: int, color: Color, life: float, flat := true, gain := 1.0) -> MeshInstance3D:
	if _fx_shader == null:
		_fx_shader = Shader.new()
		_fx_shader.code = FX_SHADER
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _fx_shader
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("gain", gain)
	mat.render_priority = 4
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor_root.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("t", v), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


## Gear on the ground: a tier-coloured light beam with a ground ring and a
## spinning glint (iron short and soft, steel taller and cool, rune plate a
## tall pulsing pillar). Keyed so the pickup can retire it.
const LOOT_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0);
uniform float gain = 1.0;
uniform float pulse = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float core = pow(clamp(across, 0.0, 1.0), 3.0);
	float fade = smoothstep(0.0, 0.85, UV.y);
	float p = 1.0 + pulse * 0.35 * sin(TIME * 5.0 - UV.y * 8.0);
	ALBEDO = color * (core * 1.6 + across * 0.35) * fade * gain * p;
}
"""
var _loot_shader: Shader
var _beams := {}


func loot_beam(key: String, pos: Vector2, tier: int) -> void:
	if actor_root == null:
		return
	loot_clear(key)
	if _loot_shader == null:
		_loot_shader = Shader.new()
		_loot_shader.code = LOOT_SHADER
	var c: Color = GearDB.TIER_COLORS[clampi(tier, 1, 3)]
	var root := Node3D.new()
	root.position = _to3(pos)
	actor_root.add_child(root)
	var tall: float = [0.0, 3.4, 5.4, 9.0][clampi(tier, 1, 3)]
	for k in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2([0.0, 0.8, 1.0, 1.5][clampi(tier, 1, 3)], tall)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = _loot_shader
		m.set_shader_parameter("color", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("gain", [0.0, 1.1, 1.3, 1.8][clampi(tier, 1, 3)])
		m.set_shader_parameter("pulse", 1.0 if tier == 3 else 0.0)
		m.render_priority = 3
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = tall * 0.5
		mi.rotation.y = PI * 0.5 * k
		root.add_child(mi)
	var ring := _decal(1.6 if tier < 3 else 2.2, {"ring_color": Color(c.r, c.g, c.b, 0.9), "ring_radius": 0.38, "ring_width": 0.03, "ring_glow": 0.9, "shadow_alpha": 0.0, "shadow_radius": 0.3, "rune": tier == 3, "pulse": 1.0})
	ring.position.y = 0.04
	root.add_child(ring)
	if _fx_shader == null:
		_fx_shader = Shader.new()
		_fx_shader.code = FX_SHADER
	var glint := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(0.9, 0.9)
	glint.mesh = gq
	var gm := ShaderMaterial.new()
	gm.shader = _fx_shader
	gm.set_shader_parameter("kind", 3)
	gm.set_shader_parameter("color", Vector3(c.r, c.g, c.b) * 1.3)
	gm.set_shader_parameter("gain", 1.4)
	gm.set_shader_parameter("t", 0.5)
	gm.render_priority = 5
	glint.material_override = gm
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glint.position = Vector3(0, 0.7, 0)
	root.add_child(glint)
	root.create_tween().set_loops().tween_property(glint, "rotation:y", TAU, 2.4).from(0.0)
	var bob := root.create_tween().set_loops()
	bob.tween_property(glint, "position:y", 0.95, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(glint, "position:y", 0.7, 0.6).set_trans(Tween.TRANS_SINE)
	_beams[key] = root


func loot_clear(key: String) -> void:
	if _beams.has(key):
		var n: Node = _beams[key]
		if is_instance_valid(n):
			n.queue_free()
		_beams.erase(key)


## Pickup: the beam collapses into a tier burst and a streak to the hero.
func loot_pickup(key: String, pos: Vector2, tier: int, hero_at: Vector2) -> void:
	loot_clear(key)
	if actor_root == null:
		return
	var c: Color = GearDB.TIER_COLORS[clampi(tier, 1, 3)]
	var ring := _fx_quad(Vector2(2.4, 2.4) * (1.0 + 0.3 * tier), 1, c, 0.45, true, 1.6)
	ring.position = _to3(pos) + Vector3(0, 0.1, 0)
	_spark(_to3(pos), c)
	var a := _to3(pos)
	var b := _to3(hero_at)
	var streak := _fx_quad(Vector2(0.5, maxf(a.distance_to(b), 0.4)), 2, c, 0.3, true, 1.4)
	streak.position = (a + b) * 0.5 + Vector3(0, 0.6, 0)
	streak.rotation.y = atan2(b.x - a.x, b.z - a.z) + PI


## Tank cleave: a steel crescent across the real arc and reach.
func cleave_fx(pos: Vector2, facing: float, reach: float, arc_deg: float, crit: bool) -> void:
	if actor_root == null:
		return
	var m := reach * SCALE * 2.0
	var q := _fx_quad(Vector2(m, m), 0, Color("ffd38a") if crit else Color("d8ecff"), 0.28, true, 2.6 if crit else 2.1)
	q.position = _to3(pos) + Vector3(0, 0.45, 0)
	# Quad -Y in UV maps to world -Z; the sim's facing is an angle in x/y.
	q.rotation.y = -facing - PI * 0.5
	(q.material_override as ShaderMaterial).set_shader_parameter("half_arc", deg_to_rad(arc_deg) * 0.5)


## Tank charge: a dust streak along the leap and the lunge clip.
func charge_fx(actor_id: int, from: Vector2, to: Vector2) -> void:
	if actor_root == null:
		return
	var a := _to3(from)
	var b := _to3(to)
	var len := maxf(a.distance_to(b), 0.5)
	var q := _fx_quad(Vector2(1.1, len), 2, Color("c9ab7e"), 0.45, true, 0.7)
	q.position = (a + b) * 0.5 + Vector3(0, 0.08, 0)
	q.rotation.y = atan2(b.x - a.x, b.z - a.z)
	if _dust != null:
		_dust.global_position = a + Vector3(0, 0.05, 0)
		_dust.restart()
		_dust.emitting = true
	if _bodies.has(actor_id):
		var body: Node3D = _bodies[actor_id]
		body.set_meta("lock", "attack")
		body.set_meta("lock_until", Time.get_ticks_msec() / 1000.0 + 0.24)
		body.set_meta("state", "")
		_play(body, "dodge")


## Charge landing: a stagger shockwave at the real AoE radius.
func charge_land_fx(pos: Vector2, radius: float) -> void:
	if actor_root == null:
		return
	var m := radius * SCALE * 2.0
	var q := _fx_quad(Vector2(m, m), 1, Color("e6eef7"), 0.32, true, 0.9)
	q.position = _to3(pos) + Vector3(0, 0.1, 0)
	if _dust != null:
		_dust.global_position = _to3(pos) + Vector3(0, 0.05, 0)
		_dust.restart()
		_dust.emitting = true


## A splash blooming: the orb's burst scatters over the ground it scorched.
func boom_fx(pos: Vector2, radius: float) -> void:
	if _cast_fx == null or actor_root == null:
		return
	_cast_fx.impact_burst(
		_to3(pos) + Vector3(0, 0.35, 0),
		_cast_fx.impact_color(),
		maxf(radius, 40.0) * SCALE,
		true)


## A card ability resolving: the effect blooms where it lands, in the
## ability's own colour.
func fx_burst(pos: Vector2, radius: float, col: Color) -> void:
	if _cast_fx == null or actor_root == null:
		return
	_cast_fx.impact_burst(
		_to3(pos) + Vector3(0, 0.4, 0),
		col,
		maxf(radius, 50.0) * SCALE,
		true)


## Guard: a white glint on the shield when the swing DR soaks a hit.
func guard_glint(actor_id: int) -> void:
	if not _bodies.has(actor_id) or camera == null:
		return
	var body: Node3D = _bodies[actor_id]
	var off := body.find_child("GearOff", true, false) as Node3D
	var at: Vector3 = off.global_position if off != null else body.global_position + Vector3(0, HERO_METERS * 0.5, 0)
	var q := _fx_quad(Vector2(1.3, 1.3), 3, Color("e8f4ff"), 0.22, false, 1.4)
	q.global_position = at + (camera.global_position - at).normalized() * 0.6
	q.look_at(camera.global_position, Vector3.UP)


## Lifesteal: crimson motes rise off the struck and drift into the hero.
func lifesteal_fx(actor_id: int, from: Vector2) -> void:
	if not _bodies.has(actor_id):
		return
	var body: Node3D = _bodies[actor_id]
	for i in 3:
		var q := _fx_quad(Vector2(0.38, 0.38), 4, Color("ff3a3a"), 0.5, false, 1.2)
		var start := _to3(from) + Vector3(randf_range(-0.6, 0.6), 0.8 + randf() * 0.6, randf_range(-0.6, 0.6))
		q.position = start
		if camera != null:
			q.look_at(camera.global_position, Vector3.UP)
		var tw := q.create_tween()
		tw.tween_property(q, "position", body.position + Vector3(0, HERO_METERS * 0.45, 0), 0.5).set_delay(i * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)



## Caster bolt dressing: additive halo plus a smoke trail in the bolt colour.
func _bolt_dress(node: MeshInstance3D, col: Color) -> void:
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.9, 0.9)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_color = Color(col.r, col.g, col.b, 0.7)
	hm.albedo_texture = _soft_dot()
	hm.disable_fog = true
	hq.material = hm
	halo.mesh = hq
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(halo)
	var trail := GPUParticles3D.new()
	trail.name = "Trail"
	trail.amount = 22
	trail.lifetime = 0.42
	trail.local_coords = false
	var tp := ParticleProcessMaterial.new()
	tp.gravity = Vector3(0, 0.6, 0)
	tp.scale_min = 0.7
	tp.scale_max = 1.4
	tp.spread = 180.0
	tp.initial_velocity_min = 0.05
	tp.initial_velocity_max = 0.3
	var tf := Gradient.new()
	tf.set_color(0, Color(1, 1, 1, 0.8))
	tf.set_color(1, Color(0.4, 0.4, 0.4, 0))
	var tr := GradientTexture1D.new()
	tr.gradient = tf
	tp.color_ramp = tr
	trail.process_material = tp
	var tq := QuadMesh.new()
	tq.size = Vector2(0.3, 0.3)
	var tm := hm.duplicate() as StandardMaterial3D
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	tm.vertex_color_use_as_albedo = true
	tm.albedo_color = Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.55)
	tq.material = tm
	trail.draw_pass_1 = tq
	node.add_child(trail)
