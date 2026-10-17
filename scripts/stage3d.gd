class_name Stage3D
extends Control

## The hunt and the home pedestal, drawn in 3D. The simulation stays on the
## flat playfield. This view follows it with a tilted camera.

const SCALE := 0.02
const PITCH := 1.012291  # 58 degrees, high enough to read the ground
## The follow camera sits far back so a wave is on screen well before it
## reaches the hero: about 7 m of ground across at the hero, 3x the old view.
const DIST := 20.0
const FOV := 40.0
const BOSS_DIST := 25.0
## Aim below the ground plane to centre the hero rather than sit it low.
const AIM := -2.0
## On-screen size targets. With the camera at DIST these put the hero near
## 13% of the screen height; the boss is about 2.6 times the hero.
const HERO_METERS := 2.5
const PEDESTAL_TOP := 0.34
const BOSS_METERS := 6.4
## Highest render density over the logical canvas (device px per canvas px).
const MAX_DENSITY := 1.65

var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var _flash_mat: ShaderMaterial
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
var _pet: Node3D
var _pet_ready := false
var _dust: GPUParticles3D
var _sparks: Array = []
var _mark: Node3D
var _grass_mats: Array = []
var _props: Array = []
var _pings: Dictionary = {}
var _decal_shader: Shader
var _view: TextureRect
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


func _process(delta: float) -> void:
	var density := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, MAX_DENSITY)
	var target := Vector2i(maxi(16, int(size.x * density)), maxi(16, int(size.y * density)))
	if fixed_px != Vector2i.ZERO:
		target = fixed_px
	if viewport.size != target:
		viewport.size = target
	if _mode == "pedestal" and _pedestal_hero != null:
		_pedestal_hero.position.y = PEDESTAL_TOP + absf(sin(Time.get_ticks_msec() * 0.0021)) * 0.03
		_pedestal_hero.rotation.y = -float(_pedestal_hero.get_meta("face", PI)) + 0.45 + sin(Time.get_ticks_msec() * 0.0005) * 0.22
		if _ped_dist > 0.0:
			# A slow handheld drift so the glade breathes and parallaxes.
			var t := Time.get_ticks_msec() * 0.001
			var drift := Vector3(sin(t * 0.31) * 0.08 * _ped_dist, sin(t * 0.23 + 1.3) * 0.025 * _ped_dist, 0.0)
			camera.position = _ped_focus + _ped_dir * _ped_dist + drift
			camera.look_at(_ped_focus + drift * 0.2, Vector3.UP)


func bind_hunt(biome_id: String) -> void:
	_mode = "hunt"
	_biome = biome_id
	viewport.transparent_bg = false
	_ground(biome_id)
	_foliage(biome_id)
	_biome_mood(biome_id)
	_look = _to3(Vector2(360, 700))
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
	env.ambient_light_color = Color("c8a888")
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_density = 0.06
	env.fog_light_color = Color(0.5, 0.36, 0.26)
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.06
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.08
	_apply_env(env)
	sun.light_color = Color("ffb874")
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	sun.rotation_degrees = Vector3(-24, 38, 0)
	_lamp(Color("ffd6a0"), 2.2, Vector3(-1.8, 2.6, -1.8), false)
	_lamp(Color("8fb0ff"), 1.0, Vector3(-2.2, 1.8, 1.6), false)
	# Rim: a hot back light behind the hero carves its silhouette from the forest.
	_lamp(Color("ffc27a"), 3.2, Vector3(1.2, 2.8, -2.0), false, 3.6)
	_lamp(Color("ffe2b8"), 1.6, Vector3(-1.4, 2.4, -1.6), false, 3.2)
	_pedestal_set()
	var body := _spawn_model(hero_id, 1.5)
	body.position = Vector3(0, PEDESTAL_TOP, 0)
	body.rotation.y = -float(body.get_meta("face", PI)) + 0.45
	world_root.add_child(body)
	_pedestal_hero = body
	_outline(body)
	_hide_catch(body)
	var clips: Dictionary = body.get_meta("clips")
	if clips.has("perch"):
		var player: AnimationPlayer = body.get_meta("player")
		if player != null and player.has_animation(str(clips["perch"])):
			player.get_animation(str(clips["perch"])).loop_mode = Animation.LOOP_PINGPONG
	_play(body, "perch" if clips.has("perch") else "idle")
	_frame_on(body)
	_reframe_posed(body)


func sync_hunt(sim: RunSim, alpha: float) -> void:
	if _mode != "hunt":
		return
	var seen := {}
	var hero_at := _look
	for actor in sim.actors:
		if not actor.alive and actor.kind != "hero":
			continue
		seen[actor.id] = true
		var body := _body_for(actor)
		var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
		body.position = _to3(pos)
		body.rotation.y = lerp_angle(body.rotation.y, _yaw(actor.facing, body), 0.4)
		_anim(body, actor)
		if actor.kind == "hero" and actor.team == 0:
			hero_at = body.position
			_step_dust(body, actor, sim)
	var boss_up := false
	var boss_at := Vector3.ZERO
	for actor in sim.actors:
		if actor.alive and actor.kind == "boss":
			boss_up = true
			boss_at = _to3(actor.pos)
	_dist = lerpf(_dist, BOSS_DIST if boss_up else DIST, 0.08)
	var drop: Array = []
	for id in _bodies.keys():
		if seen.has(id):
			continue
		var body: Node3D = _bodies[id]
		if bool(body.get_meta("dying", false)):
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
	for actor in sim.actors:
		if actor.kind == "hero" and actor.team == 0 and actor.alive:
			_place_mark(_to3(actor.prev.lerp(actor.pos, alpha)))
			break
	for mat in _grass_mats:
		(mat as ShaderMaterial).set_shader_parameter("hero", hero_at)
	_open_around(hero_at)
	var focus := hero_at
	if boss_up:
		# Lean the view toward the boss so its telegraphs stay on screen.
		var lean := (boss_at - hero_at) * 0.45
		lean.y = 0.0
		focus = hero_at + lean.limit_length(4.0)
	_follow(focus, 1.0 / 60.0)


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
		node.position = _to3(pos) + Vector3(0.0, 0.3 + sin(gem.bob) * 0.06, 0.0)
		node.rotate_y(0.05)
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
	body.set_meta("lock_until", Time.get_ticks_msec() / 1000.0 + 0.38)
	_play(body, "attack")


func hurt(actor_id: int) -> void:
	if not _bodies.has(actor_id):
		return
	var body: Node3D = _bodies[actor_id]
	if str(body.get_meta("lock", "")) == "death":
		return
	body.set_meta("lock", "hit")
	body.set_meta("lock_until", Time.get_ticks_msec() / 1000.0 + 0.22)
	_play(body, "hit")
	_spark(body.position, Color("ffb15a"))
	_flash(body)


## A brief additive white pulse over the whole body: the classic hit flash.
func _flash(body: Node3D) -> void:
	if _flash_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_back, depth_draw_never;\nuniform float amount = 0.6;\nvoid fragment() {\n\tALBEDO = vec3(1.0, 0.86, 0.72) * amount;\n}\n"
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = sh
	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if not str(m.name).begins_with("Catch"):
			(m as MeshInstance3D).material_overlay = _flash_mat
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		for m in meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = null)


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
	sun.light_color = Color("f6c98a")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 42.0
	sun.shadow_bias = 0.04
	sun.rotation_degrees = Vector3(-48, 38, 0)
	world_root.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("c5dcff")
	rim.light_energy = 1.7
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-18, -150, 0)
	world_root.add_child(rim)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.08
	camera.far = 80.0
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
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.5
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.12 if high else 0.08
	env.glow_strength = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.ssao_enabled = high
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.35
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
	var holder := WorldEnvironment.new()
	holder.name = "World"
	holder.environment = env
	world_root.add_child(holder)
	camera.environment = env


func _ground(biome_id: String) -> void:
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	var pad := 28.0
	var span := Vector2(720.0 * SCALE + pad * 2.0, 1280.0 * SCALE + pad * 2.0)
	plane.size = span
	plane.subdivide_width = 96
	plane.subdivide_depth = 120
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("grass_color", load("res://assets/textures/grass_color.jpg"))
	mat.set_shader_parameter("grass_normal", load("res://assets/textures/grass_normal.jpg"))
	mat.set_shader_parameter("grass_rough", load("res://assets/textures/grass_rough.jpg"))
	mat.set_shader_parameter("lush_color", load("res://assets/textures/lush_color.jpg"))
	mat.set_shader_parameter("lush_normal", load("res://assets/textures/lush_normal.jpg"))
	mat.set_shader_parameter("dirt_color", load("res://assets/textures/path_color.jpg"))
	mat.set_shader_parameter("dirt_normal", load("res://assets/textures/path_normal.jpg"))
	mat.set_shader_parameter("dirt_rough", load("res://assets/textures/path_rough.jpg"))
	mat.set_shader_parameter("world_span", span)
	mat.set_shader_parameter("tint", _biome_tint(biome_id))
	mat.set_shader_parameter("dirt_tint", _dirt_tint(biome_id))
	mat.set_shader_parameter("snow", 0.75 if biome_id == "frost" else 0.0)
	mat.set_shader_parameter("ash", 0.85 if biome_id == "volcano" else 0.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = mat
	mesh.position = Vector3(720.0 * SCALE * 0.5, 0, 1280.0 * SCALE * 0.5)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mesh)


## Distance in meters to the dirt trails the terrain shader paints, without
## the shader's wobble. Grass and props keep off the trails with it.
static func path_dist(w: Vector2) -> float:
	var a := absf(w.x - (7.2 + sin(w.y * 0.23 + 0.6) * 2.6))
	var b := absf(w.y - (13.0 + sin(w.x * 0.31 + 1.8) * 2.2))
	var c := absf(w.x - (3.4 + w.y * 0.18)) + maxf(w.y - 11.0, 0.0) * 4.0
	return minf(minf(a, b), c)


func _foliage(biome_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id) + 17
	_grass_mats.clear()
	_props.clear()
	var count := 360 if _tier() == "low" else (900 if _tier() == "medium" else 1300)
	_scatter(rng, "grass_short", int(count * 0.55), 0.4, 0.6, true)
	_scatter(rng, "grass_wispy", int(count * 0.25), 0.38, 0.55, true)
	if not biome_id in ["frost", "volcano"]:
		_scatter(rng, "flower_a", 34, 0.5, 0.75, false)
		_scatter(rng, "flower_b", 30, 0.5, 0.75, false)
	_scatter(rng, "clover", 40, 0.45, 0.62, false)
	_scatter(rng, "fern", 22 if biome_id == "meadow" else 34, 0.6, 0.9, false)
	var trees: Array = ["tree_a", "tree_b", "bush_flower", "tree_a"]
	match biome_id:
		"mushroom":
			trees = ["mushroom_tall", "mushroom", "tree_twist", "bush"]
		"frost":
			trees = ["tree_pine", "tree_pine_b", "bush"]
		"volcano":
			trees = ["tree_dead", "tree_dead", "rock_lava"]
	var pack := biome_id == "meadow" and ResourceLoader.exists("res://assets/models/sketchfab/nature/grove.glb")
	if not pack:
		for i in (8 if _tier() == "low" else 14):
			var name: String = trees[i % trees.size()]
			var at := _rim_point(rng)
			_place_prop(name, at, rng.randf_range(1.15, 1.55), true)
	if not biome_id in ["frost", "volcano"]:
		# The leafy, blossoming nature pack belongs in green biomes only.
		_sketchfab_nature(rng)
	_field_props(rng)


## Mid-field set dressing a Diablo floor needs: mossy rocks, fallen logs,
## stumps, mushroom clusters, and flower beds, kept off the trails.
func _field_props(rng: RandomNumberGenerator) -> void:
	var kit := [
		["rock_a", 0.55, 0.95, 5], ["rock_b", 0.45, 0.8, 5], ["rock_c", 0.6, 1.0, 3],
		["pebble_rock", 0.5, 0.8, 6], ["pebble_rock_b", 0.45, 0.7, 5],
		["log", 0.9, 1.3, 4], ["stump", 0.45, 0.65, 4],
		["mushroom", 0.4, 0.6, 7], ["mushroom_shelf", 0.35, 0.5, 3],
		["bush_flower", 0.7, 1.0, 6], ["flower_b", 0.7, 0.95, 6], ["flower_a", 0.7, 0.95, 6],
	]
	if _tier() == "low":
		for row in kit:
			row[3] = maxi(1, int(row[3]) / 2)
	if _biome in ["frost", "volcano"]:
		# No blossoms on snow or ash.
		kit = kit.filter(func(row: Array) -> bool: return not ("flower" in str(row[0])))
	for row in kit:
		for _n in int(row[3]):
			var at := _off_path_point(rng, 1.5)
			_place_prop(str(row[0]), at, rng.randf_range(float(row[1]), float(row[2])), str(row[0]).begins_with("rock") or str(row[0]) in ["log", "stump"])


func _off_path_point(rng: RandomNumberGenerator, keep: float) -> Vector3:
	var at := _field_point(rng)
	for _try in 12:
		if path_dist(Vector2(at.x, at.z)) > keep:
			return at
		at = _field_point(rng)
	return at


func _scatter(rng: RandomNumberGenerator, model: String, count: int, lo: float, hi: float, sway: bool) -> void:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return
	var probe := packed.instantiate()
	var source := _first_mesh(probe)
	if source == null or source.mesh == null:
		probe.free()
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = false
	multi.mesh = source.mesh
	multi.instance_count = count
	var posed := _chain(source, probe)
	for i in count:
		var at := _off_path_point(rng, 1.0)
		var s := rng.randf_range(lo, hi)
		var spin := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		multi.set_instance_transform(i, Transform3D(spin, at) * posed)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if sway:
		var grass := _grass_material(source)
		node.material_override = grass
		_grass_mats.append(grass)
	world_root.add_child(node)
	probe.free()


func _place_prop(model: String, at: Vector3, scale: float, shadows: bool) -> void:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return
	var node := packed.instantiate()
	node.position = at
	if model in ["log", "stump"]:
		_bark(node)
	if node is Node3D:
		var prop := node as Node3D
		prop.scale *= scale
		prop.rotation.y = randf() * TAU
	if not shadows and node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Node3D:
		_props.append(node)
	world_root.add_child(node)


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
		_place_prop(str(row[0]), row[1], float(row[2]), true)
	for i in 70:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.6, 4.5)
		_place_prop("grass_short" if i % 3 else "clover", Vector3(cos(ang) * r, 0, sin(ang) * r), rng.randf_range(0.5, 0.8), false)
	for i in 14:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.5, 1.15)
		_place_prop("grass_short", Vector3(cos(ang) * r, PEDESTAL_TOP, sin(ang) * r), rng.randf_range(0.35, 0.5), false)
	# A real forest edge behind the glade: layered trees, then a dense band
	# of bushes and tall grass, so the backdrop has depth instead of flat fog.
	var trees := ["tree_a", "tree_b", "tree_pine", "tree_pine_b", "tree_a", "tree_b"]
	for i in 16:
		var x := lerpf(-9.0, 9.0, float(i) / 15.0) + rng.randf_range(-0.6, 0.6)
		var z := -6.5 - rng.randf_range(0.0, 4.5) - absf(x) * 0.1
		_place_prop(trees[i % trees.size()], Vector3(x, 0, z), rng.randf_range(2.4, 3.4), true)
	for i in 18:
		var x := rng.randf_range(-7.5, 7.5)
		var z := rng.randf_range(-5.8, -3.6)
		_place_prop("bush_flower", Vector3(x, 0, z), rng.randf_range(1.1, 1.8), true)
	for i in 120:
		var ang := rng.randf_range(PI * 0.95, TAU * 1.02)
		var r := rng.randf_range(2.2, 6.5)
		var kind := "grass_tall" if i % 3 == 0 else ("grass_wispy" if i % 3 == 1 else "fern")
		_place_prop(kind, Vector3(cos(ang) * r, 0, sin(ang) * r), rng.randf_range(0.7, 1.15), false)
	for i in 26:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.7, 3.6)
		_place_prop(["flower_a", "flower_b", "flower_warm", "pebble_rock_b"][i % 4], Vector3(cos(ang) * r, 0, sin(ang) * r), rng.randf_range(0.4, 0.65), false)


func _field_point(rng: RandomNumberGenerator) -> Vector3:
	return _to3(Vector2(rng.randf_range(48.0, 672.0), rng.randf_range(190.0, 1140.0)))


func _rim_point(rng: RandomNumberGenerator) -> Vector3:
	var edge := rng.randi() % 4
	var x := rng.randf_range(30.0, 690.0)
	var y := rng.randf_range(150.0, 1180.0)
	match edge:
		0:
			x = rng.randf_range(16.0, 150.0)
		1:
			x = rng.randf_range(570.0, 700.0)
		2:
			y = rng.randf_range(140.0, 280.0)
		_:
			y = rng.randf_range(1000.0, 1220.0)
	return _to3(Vector2(x, y))


func _body_for(actor: RunSim.Actor) -> Node3D:
	if _bodies.has(actor.id):
		return _bodies[actor.id]
	var meters := HERO_METERS
	if actor.kind == "boss":
		meters = BOSS_METERS
	elif actor.kind != "hero":
		# Rank-and-file critters stand roughly hero height so they read.
		meters = clampf(actor.radius / 40.0, 0.5, 0.66) * HERO_METERS
	var body := _spawn_model(actor.sprite, meters)
	# Outlines keep silhouettes readable from the far camera: a dark hairline
	# on the hero (its ring marks it), deep red for anything hostile.
	if actor.kind == "hero" and actor.team == 0:
		_outline(body, Color("1a0806"), 0.008)
	elif actor.kind == "boss":
		_outline(body, Color("4a0a0a"), 0.012)
	elif actor.kind != "hero":
		_outline(body, Color("5a0d0d"), 0.018)
	if actor.kind != "hero":
		# Hostiles stand in a thin red ground ring so they read as threats at a
		# glance; the boss gets a heavy shadow and a wide pulsing telegraph.
		var boss := actor.kind == "boss"
		var blob := _decal(meters * (0.95 if boss else 1.1), {
			"ring_color": Color(0.9, 0.14, 0.08, 0.7 if boss else 0.55),
			"ring_radius": 0.4, "ring_width": 0.018 if boss else 0.035, "ring_glow": 0.18 if boss else 0.25,
			"shadow_alpha": 0.72 if boss else 0.42, "shadow_radius": 0.36 if boss else 0.42,
			"pulse": 1.0 if boss else 0.0,
		})
		blob.position.y = 0.03
		body.add_child(blob)
	body.rotation.y = _yaw(actor.facing, body)
	actor_root.add_child(body)
	_bodies[actor.id] = body
	if actor.kind == "hero" and actor.team == 0:
		_center_posed(body, 0.45)
	return body


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
	root.set_meta("face", face)
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
	return root


## Sketchfab exports pack AO, roughness, and metal into one map. Godot reads
## the blue channel as metal, so the dragon came in as polished chrome that
## only reflected the sky. Critters are painted fur, scale, and cloth: no
## metal, a soft sheen, and the normal map only where it carries detail.
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
			if opts.has("albedo_tex") and mat.albedo_texture != null:
				mat.albedo_texture = load(str(opts["albedo_tex"]))
			var lift: Color = opts.get("albedo", Color.WHITE)
			mat.albedo_color = mat.albedo_color * lift
			if opts.has("rim"):
				mat.rim_enabled = true
				mat.rim = float(opts["rim"])
				mat.rim_tint = 0.35
			mesh.set_surface_override_material(i, mat)
	for child in node.get_children():
		_fix_pbr(child, sprite)


func _anim(body: Node3D, actor: RunSim.Actor) -> void:
	var lock := str(body.get_meta("lock", ""))
	var until := float(body.get_meta("lock_until", 0.0))
	var now := Time.get_ticks_msec() / 1000.0
	if lock == "death" or not actor.alive:
		body.set_meta("lock", "death")
		_play(body, "death")
		return
	if lock != "" and now < until:
		return
	if lock != "":
		body.set_meta("lock", "")
	if actor.vel.length() > 18.0:
		_play(body, "run")
	else:
		_play(body, "idle")


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
		body.rotation.z = 1.15
		body.position.y -= 0.15
	elif state == "hit":
		body.scale = Vector3(1.08, 0.9, 1.08)


func _yaw(facing: float, body: Node3D) -> float:
	var face := float(body.get_meta("face", PI))
	var dir := Vector2(cos(facing), sin(facing))
	return atan2(dir.x, dir.y) - face


func _follow(hero: Vector3, delta: float) -> void:
	if not _ready_cam:
		_look = hero
		_ready_cam = true
	else:
		_look = _look.lerp(hero, 1.0 - exp(-12.0 * delta))
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
	var view_h := h / 0.6
	var dist := view_h * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	# Sit the hero a touch below center, clear of the logo plate above it.
	var focus := box.get_center() + Vector3(0, view_h * 0.135, 0)
	var dir := Vector3(0.0, 0.3, 1.0).normalized()
	camera.position = focus + dir * dist
	camera.look_at(focus, Vector3.UP)
	_ped_focus = focus
	_ped_dir = dir
	_ped_dist = dist
	_pedestal_atmos(box)
	# No depth of field: on this renderer it smeared the hero along with the
	# glade. Warm fog does the separation instead.
	camera.attributes = null


## Life for the glade: slanted shafts of sun through the canopy and a slow
## drift of fireflies and pollen around the hero.
func _pedestal_atmos(box: AABB) -> void:
	var c := box.get_center()
	var ray_shader := Shader.new()
	ray_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.48, 1.0);
uniform float strength = 0.9;
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
	flies.amount = 46
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
	dot.size = Vector2(0.08, 0.08)
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
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


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
	return node


## The hero's selection ring: a soft contact shadow under a smooth gold ring.
func _place_mark(at: Vector3) -> void:
	if _mark == null:
		_mark = _decal(HERO_METERS * 0.82, {
			"ring_color": Color(1.0, 0.86, 0.42, 0.95),
			"ring_radius": 0.4,
			"ring_width": 0.04,
			"ring_glow": 0.45,
			"shadow_alpha": 0.5,
			"shadow_radius": 0.34,
			"pulse": 1.0,
		})
		_mark.position.y = 0.035
		actor_root.add_child(_mark)
	_mark.visible = true
	_mark.position = Vector3(at.x, 0.035, at.z)


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


func _measure(node: Node) -> AABB:
	var acc := {"ok": false, "box": AABB()}
	_measure_into(node, Transform3D.IDENTITY, acc)
	if not bool(acc["ok"]):
		return AABB(Vector3.ZERO, Vector3(0.4, 1.0, 0.4))
	return acc["box"]


func _measure_into(node: Node, parent: Transform3D, acc: Dictionary) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
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
		gem.radius = 0.1
		gem.height = 0.26
		mesh_node.mesh = gem
		mat.albedo_color = Color("2ee87a")
		mat.emission_enabled = true
		mat.emission = Color("1fd468")
		mat.emission_energy_multiplier = 0.55
		mat.rim_enabled = true
		mat.rim = 0.6
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
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.15
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


func _lamp(color: Color, energy: float, pos: Vector3, shadows: bool, reach := 8.0) -> void:
	var light := OmniLight3D.new()
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


func _open_around(hero: Vector3) -> void:
	for node in _props:
		var prop := node as Node3D
		if prop == null:
			continue
		var flat := Vector2(prop.position.x - hero.x, prop.position.z - hero.z)
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
	var count := 8 if _tier() == "low" else 16
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


func _paint_rock(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/rock_color.jpg")
		mat.albedo_color = Color("8d847c")
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
		mat.roughness = 0.92
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_paint_rock(child)


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
			env.fog_light_color = Color(0.42, 0.32, 0.52)
			env.fog_density = 0.006
			env.ambient_light_color = Color("a890c8")
			sun.light_color = Color("e0b8ff")
			sun.light_energy = 1.1
			grass = Vector3(0.78, 0.84, 1.0)
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
	for mat in _grass_mats:
		(mat as ShaderMaterial).set_shader_parameter("biome_tint", grass)


func _biome_tint(biome_id: String) -> Vector3:
	match biome_id:
		"mushroom":
			return Vector3(0.78, 0.88, 1.05)
		"frost":
			return Vector3(0.84, 0.92, 1.08)
		"volcano":
			return Vector3(1.08, 0.78, 0.62)
		_:
			return Vector3(0.95, 1.02, 0.9)


func _dirt_tint(biome_id: String) -> Vector3:
	match biome_id:
		"frost":
			return Vector3(0.95, 0.98, 1.05)
		"volcano":
			return Vector3(0.7, 0.55, 0.5)
		_:
			return Vector3(1.0, 0.94, 0.86)


func _tier() -> String:
	if OS.has_feature("mobile") or OS.get_name() == "iOS":
		return "medium"
	if _software():
		return "medium"
	return "high"


func _software() -> bool:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	return "llvmpipe" in name or "lavapipe" in name or "swiftshader" in name
