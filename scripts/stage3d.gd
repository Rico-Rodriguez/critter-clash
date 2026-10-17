class_name Stage3D
extends SubViewportContainer

## The hunt and the home pedestal, drawn in 3D. The simulation stays on the
## flat playfield. This view follows it with a tilted camera.

const SCALE := 0.02
const PITCH := 1.012291  # 58 degrees, high enough to read the ground
const DIST := 11.0
const FOV := 38.0
const BOSS_DIST := 14.5

var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
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
var _portrait: SubViewport
var _portrait_for := ""
var _grass_mats: Array = []
var _props: Array = []
var _hero_rim: OmniLight3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.size = Vector2i(720, 1280)
	add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	_lights()
	actor_root = Node3D.new()
	world_root.add_child(actor_root)
	_dust_pool()


func _process(delta: float) -> void:
	var target := Vector2i(maxi(16, int(size.x)), maxi(16, int(size.y)))
	if viewport.size != target:
		viewport.size = target
	if _mode == "pedestal" and _pedestal_hero != null:
		_pedestal_hero.position.y = 0.48 + sin(Time.get_ticks_msec() * 0.0021) * 0.04
		_pedestal_hero.rotation.y += delta * 0.35


func bind_hunt(biome_id: String) -> void:
	_mode = "hunt"
	_biome = biome_id
	viewport.transparent_bg = false
	_ground(biome_id)
	_foliage(biome_id)
	_look = _to3(Vector2(360, 700))
	_dist = DIST
	_ready_cam = false
	_frame(_look)


func bind_pedestal(hero_id: String) -> void:
	_mode = "pedestal"
	_hero_id = hero_id
	viewport.transparent_bg = false
	var env := _environment(Color("8aa0b8"), false)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("142033")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6d88b0")
	env.ambient_light_energy = 0.55
	env.fog_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.15
	env.tonemap_exposure = 0.95
	env.background_energy_multiplier = 1.0
	_apply_env(env)
	sun.light_energy = 0.22
	sun.shadow_enabled = false
	_lamp(Color("ffe0b8"), 3.4, Vector3(1.7, 2.5, 2.5), true)
	_lamp(Color("9eb6de"), 1.35, Vector3(-1.9, 1.5, 1.6), false)
	_lamp(Color("d5e4ff"), 2.6, Vector3(0.15, 2.3, -2.0), false)
	_pedestal_set()
	var body := _spawn_model(hero_id, 1.45)
	body.position = Vector3(0, 0.55, 0)
	world_root.add_child(body)
	_pedestal_hero = body
	_outline(body)
	_hide_catch(body)
	_play(body, "idle")
	_frame_on(body)


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
	for actor in sim.actors:
		if actor.alive and actor.kind == "boss":
			boss_up = true
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
	if _hero_rim != null:
		_hero_rim.visible = true
		_hero_rim.position = hero_at + Vector3(-0.9, 1.7, 0.55)
	_follow(hero_at, 1.0 / 60.0)


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
		node.position = _to3(pos) + Vector3(0.0, 0.42 + sin(gem.bob) * 0.08, 0.0)
		node.rotate_y(0.08)
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
	var gone: Array = []
	for id in _fx.keys():
		if not seen.has(id):
			gone.append(id)
	for id in gone:
		var node: Node3D = _fx[id]
		_fx.erase(id)
		node.queue_free()


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


func project(sim_pos: Vector2) -> Vector2:
	if camera == null:
		return sim_pos
	var screen := camera.unproject_position(_to3(sim_pos) + Vector3(0, 1.1, 0))
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
	sun.light_energy = 1.05
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
	_hero_rim = OmniLight3D.new()
	_hero_rim.light_color = Color("fff4dd")
	_hero_rim.light_energy = 8.0
	_hero_rim.omni_range = 2.8
	_hero_rim.shadow_enabled = false
	_hero_rim.visible = false
	world_root.add_child(_hero_rim)
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
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.tonemap_white = 6.5
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.96
	env.adjustment_contrast = 1.28
	env.adjustment_saturation = 1.42
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
	mat.set_shader_parameter("dirt_color", load("res://assets/textures/dirt_color.jpg"))
	mat.set_shader_parameter("dirt_normal", load("res://assets/textures/dirt_normal.jpg"))
	mat.set_shader_parameter("dirt_rough", load("res://assets/textures/dirt_rough.jpg"))
	mat.set_shader_parameter("rock_color", load("res://assets/textures/rock_color.jpg"))
	mat.set_shader_parameter("rock_normal", load("res://assets/textures/rock_normal.jpg"))
	mat.set_shader_parameter("rock_rough", load("res://assets/textures/rock_rough.jpg"))
	mat.set_shader_parameter("world_span", span)
	mat.set_shader_parameter("tint", _biome_tint(biome_id))
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = mat
	mesh.position = Vector3(720.0 * SCALE * 0.5, 0, 1280.0 * SCALE * 0.5)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mesh)


func _foliage(biome_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id) + 17
	_grass_mats.clear()
	_props.clear()
	var count := 480 if _tier() == "low" else (1500 if _tier() == "medium" else 2200)
	_scatter(rng, "grass_tall", int(count * 0.5), 0.5, 0.75, true)
	_scatter(rng, "grass_short", int(count * 0.34), 0.42, 0.62, true)
	_scatter(rng, "grass_wispy", int(count * 0.2), 0.4, 0.58, true)
	_scatter(rng, "flower_a", 28, 0.45, 0.68, false)
	_scatter(rng, "flower_b", 22, 0.45, 0.68, false)
	_scatter(rng, "clover", 36, 0.4, 0.58, false)
	if biome_id != "meadow":
		_scatter(rng, "fern", 18, 0.55, 0.8, false)
	# Meadow stays oaks and bushes. Round canopies and clay rocks ship
	# without textures and read as white boulders. Palms are not in this set.
	var trees: Array = ["tree_a", "tree_b", "bush", "bush_flower"]
	match biome_id:
		"mushroom":
			trees = ["mushroom_tall", "mushroom", "tree_twist", "bush"]
		"frost":
			trees = ["tree_pine", "tree_pine_b", "bush"]
		"volcano":
			trees = ["tree_dead", "tree_twist", "rock_lava"]
	# The meadow rim uses the Sketchfab vegetation pack when it is present.
	# Other biomes keep the CC0 kit.
	var pack := biome_id == "meadow" and ResourceLoader.exists("res://assets/models/sketchfab/nature/grove.glb")
	if not pack:
		for i in (8 if _tier() == "low" else 14):
			var name: String = trees[i % trees.size()]
			var at := _rim_point(rng)
			_place_prop(name, at, rng.randf_range(1.15, 1.55), true)
	_sketchfab_nature(rng)
	for i in 8:
		var light := OmniLight3D.new()
		light.light_color = Color("ffe0a8") if i % 2 == 0 else Color("c9d8ff")
		light.light_energy = 0.85
		light.omni_range = 7.0
		light.shadow_enabled = false
		var at := _field_point(rng) if i < 5 else _rim_point(rng)
		light.position = at + Vector3(0.0, 2.8, 0.0)
		world_root.add_child(light)


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
		var at := _field_point(rng)
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
	if node is Node3D:
		var prop := node as Node3D
		prop.scale *= scale
		prop.rotation.y = randf() * TAU
	if not shadows and node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Node3D:
		_props.append(node)
	world_root.add_child(node)


func _pedestal_set() -> void:
	var dais := MeshInstance3D.new()
	var stone := CylinderMesh.new()
	stone.top_radius = 1.05
	stone.bottom_radius = 1.28
	stone.height = 0.46
	stone.radial_segments = 24
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color("6a5c50")
	rock_mat.roughness = 0.9
	dais.mesh = stone
	dais.material_override = rock_mat
	dais.position = Vector3(0.0, 0.2, 0.0)
	world_root.add_child(dais)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.6
	disc.bottom_radius = 2.6
	disc.height = 0.08
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color("3d4a38")
	pad_mat.roughness = 0.95
	pad.mesh = disc
	pad.material_override = pad_mat
	pad.position = Vector3(0.0, 0.02, 0.0)
	world_root.add_child(pad)
	for model in ["rock_a", "flower_a", "flower_b", "grass_short"]:
		var packed := load("res://assets/models/%s.glb" % model) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate()
		if node is Node3D:
			var prop := node as Node3D
			if model == "rock_a":
				prop.position = Vector3(0.55, 0.0, 0.35)
				prop.scale *= 0.55
				_paint_rock(node)
			else:
				prop.position = Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.6, 0.6))
				prop.scale *= randf_range(0.7, 1.05)
		world_root.add_child(node)


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
	var meters := 1.05
	if actor.kind == "boss":
		meters = 2.7
	elif actor.kind != "hero":
		meters = clampf(actor.radius / 40.0, 0.62, 0.92)
	var body := _spawn_model(actor.sprite, meters)
	if actor.kind == "hero" and actor.team == 0:
		_outline(body)
	body.rotation.y = _yaw(actor.facing, body)
	actor_root.add_child(body)
	_bodies[actor.id] = body
	return body


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
	var h := maxf(box.size.y, 0.05)
	var factor := meters / h
	model.scale *= factor
	# Feet on the ground, and the body centered. Sketchfab rigs often sit
	# far from the origin (Mixamo hips, FBX axes).
	var center := box.get_center()
	model.position.y -= box.position.y * factor
	model.position.x -= center.x * factor
	model.position.z -= center.z * factor
	_hide_catch(model)
	_tint(model, Cast3D.tint(sprite))
	return root


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
	camera.look_at(look + Vector3(0.0, 1.05, 0.0), Vector3.UP)


func _frame_on(body: Node3D) -> void:
	var box := _measure_local(body)
	var focus := body.position + box.position + box.size * Vector3(0.5, 0.42, 0.5)
	var span := maxf(box.size.x, maxf(box.size.y, box.size.z))
	span = maxf(span, 1.0)
	# The stage is a short window, and the dragon's wings pass the rest pose.
	camera.fov = 34.0
	var dist := span * 5.2
	camera.position = focus + Vector3(dist * 0.42, dist * 0.32, dist)
	camera.look_at(focus, Vector3.UP)


func _place_mark(at: Vector3) -> void:
	if _mark == null:
		_mark = Node3D.new()
		var blob := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.orientation = QuadMesh.FACE_Y
		quad.size = Vector2(1.45, 0.95)
		blob.mesh = quad
		var shade := StandardMaterial3D.new()
		shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shade.albedo_color = Color(0, 0, 0, 0.55)
		shade.cull_mode = BaseMaterial3D.CULL_DISABLED
		blob.material_override = shade
		blob.position.y = 0.025
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mark.add_child(blob)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.52
		torus.outer_radius = 0.68
		torus.rings = 8
		torus.ring_segments = 28
		ring.mesh = torus
		var gold := StandardMaterial3D.new()
		gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gold.albedo_color = Color(1.0, 0.8, 0.32, 0.92)
		gold.emission_enabled = true
		gold.emission = Color("ffd27a")
		gold.emission_energy_multiplier = 0.45
		ring.material_override = gold
		ring.position.y = 0.04
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mark.add_child(ring)
		actor_root.add_child(_mark)
	_mark.visible = true
	_mark.position = at


func portrait_of(hero_id: String) -> Texture2D:
	if _portrait != null and _portrait_for == hero_id:
		return _portrait.get_texture()
	_portrait_for = hero_id
	var host := Node.new()
	host.name = "PortraitHost"
	add_child(host)
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2c4a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8eabcf")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.25
	var holder := WorldEnvironment.new()
	holder.environment = env
	root.add_child(holder)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe2b8")
	key.light_energy = 1.45
	key.rotation_degrees = Vector3(-32, 36, 0)
	key.shadow_enabled = true
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("b7d0ff")
	rim.light_energy = 0.9
	rim.rotation_degrees = Vector3(-12, -150, 0)
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.current = true
	root.add_child(cam)
	var body := _spawn_model(hero_id, 1.2)
	root.add_child(body)
	_hide_catch(body)
	_play(body, "idle")
	var box := _measure_local(body)
	var center := box.position + box.size * 0.5
	var forward := Vector3(0.0, 0.0, 1.0)
	var marker := _find_named(body, "Forward")
	if marker != null:
		var aimed := _local_point(marker, body)
		aimed.y = 0.0
		if aimed.length() > 0.05:
			forward = aimed.normalized()
	var head := center + forward * maxf(box.size.z, box.size.x) * 0.28 + Vector3(0.0, box.size.y * 0.18, 0.0)
	var aim := _head_point(body)
	if aim.length() > 0.001 or _has_head(body):
		var flat := Vector3(aim.x - center.x, 0.0, aim.z - center.z)
		if flat.length() > 0.02:
			forward = flat.normalized()
		head = aim
	cam.fov = 18.0
	cam.position = head + forward * maxf(box.size.y, 0.6) * 1.15 + Vector3(0.0, box.size.y * 0.08, 0.0)
	cam.look_at(head, Vector3.UP)
	_portrait = vp
	return vp.get_texture()


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
	mat.emission_enabled = true
	mat.roughness = 0.28
	if kind == "gem":
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		mesh_node.mesh = sphere
		mat.albedo_color = Color("7dff5a")
		mat.emission = Color("b6f27a")
		mat.emission_energy_multiplier = 1.6
	elif kind == "arrow":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 0.55
		mesh_node.mesh = cyl
		mat.albedo_color = Color("f4e2b0")
		mat.emission = Color("ffe08a")
		mat.emission_energy_multiplier = 0.35
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.2 if kind == "bash" else 0.16
		sphere.height = sphere.radius * 2.0
		mesh_node.mesh = sphere
		var col := Color("ff9a3c")
		if kind == "enemy":
			col = Color("ff5a3c")
		elif kind == "bash":
			col = Color("ffe08a")
		mat.albedo_color = col
		mat.emission = col
		mat.emission_energy_multiplier = 2.1
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


func _lamp(color: Color, energy: float, pos: Vector3, shadows: bool) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 8.0
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
		var target := rng.randf_range(2.1, 3.3)
		if "bush" in low:
			target = rng.randf_range(0.55, 0.95)
		elif "stone" in low:
			target = rng.randf_range(0.35, 0.6)
		elif "rock_medium" in low or "rock-medium" in low:
			target = rng.randf_range(0.7, 1.15)
		elif "rock" in low:
			target = rng.randf_range(1.05, 1.7)
		elif "dead" in low:
			target = rng.randf_range(1.5, 2.3)
		var box := _measure(prop)
		var fit := target / maxf(box.size.y, 0.05)
		prop.scale *= fit
		box = _measure(prop)
		var dest := _rim_point(rng)
		var mid := box.get_center()
		prop.position += Vector3(dest.x - mid.x, -box.position.y, dest.z - mid.z)
		_props.append(prop)
	lib.visible = false


func _paint_rock(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/rock_color.jpg")
		mat.albedo_color = Color("8d847c")
		mat.roughness = 0.92
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_paint_rock(child)


func _outline(root: Node) -> void:
	var shader: Shader = load("res://shaders/outline.gdshader")
	_outline_walk(root, shader)


func _outline_walk(node: Node, shader: Shader) -> void:
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
				shell.set_shader_parameter("grow", maxf(height * 0.018, 0.001))
				shell.set_shader_parameter("line_color", Color("ffe6a8"))
				mat.next_pass = shell
				mesh.set_surface_override_material(i, mat)
	for child in node.get_children():
		_outline_walk(child, shader)


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


func _tier() -> String:
	if OS.has_feature("mobile") or OS.get_name() == "iOS":
		return "medium"
	if _software():
		return "medium"
	return "high"


func _software() -> bool:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	return "llvmpipe" in name or "lavapipe" in name or "swiftshader" in name
