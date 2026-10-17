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
	env.tonemap_exposure = 0.92
	env.background_energy_multiplier = 1.0
	_apply_env(env)
	var key := OmniLight3D.new()
	key.light_color = Color("ffe4bf")
	key.light_energy = 2.4
	key.omni_range = 8.0
	key.position = Vector3(1.4, 2.6, 2.2)
	key.shadow_enabled = true
	world_root.add_child(key)
	_pedestal_set()
	var body := _spawn_model(hero_id, 1.45)
	body.position = Vector3(0, 0.55, 0)
	world_root.add_child(body)
	_pedestal_hero = body
	_play(body, "idle")
	_frame_on(body, 0.46, 2.15)


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
	rim.light_energy = 1.55
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
	var count := 220 if _tier() == "low" else (560 if _tier() == "medium" else 820)
	_scatter(rng, "grass_tall", int(count * 0.48), 1.05, 1.65)
	_scatter(rng, "grass_short", int(count * 0.32), 0.95, 1.45)
	_scatter(rng, "grass_wispy", int(count * 0.12), 0.95, 1.4)
	_scatter(rng, "flower_a", 40, 0.9, 1.3)
	_scatter(rng, "flower_b", 32, 0.9, 1.3)
	_scatter(rng, "fern", 26, 0.9, 1.25)
	_scatter(rng, "clover", 34, 0.85, 1.2)
	var trees: Array = ["tree_a", "tree_round", "tree_blossom", "bush", "bush_flower", "rock_a", "rock_b"]
	match biome_id:
		"mushroom":
			trees = ["mushroom_tall", "mushroom", "tree_twist", "bush", "rock_a", "fern"]
		"frost":
			trees = ["tree_pine", "tree_pine_b", "rock_a", "rock_c", "bush"]
		"volcano":
			trees = ["tree_dead", "rock_lava", "rock_c", "tree_twist", "rock_b"]
	for i in (16 if _tier() == "low" else 26):
		var name: String = trees[i % trees.size()]
		var at := _rim_point(rng)
		_place_prop(name, at, rng.randf_range(1.05, 1.7), true)
	var center := _to3(Vector2(360, 640))
	for i in 12:
		var ang := float(i) / 12.0 * TAU + 0.35
		var rad := rng.randf_range(4.8, 7.6)
		var at := center + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad * 1.2)
		_place_prop(trees[i % trees.size()], at, rng.randf_range(1.1, 1.65), true)
	for i in 8:
		var light := OmniLight3D.new()
		light.light_color = Color("ffe0a8") if i % 2 == 0 else Color("c9d8ff")
		light.light_energy = 0.85
		light.omni_range = 7.0
		light.shadow_enabled = false
		var at := _field_point(rng) if i < 5 else _rim_point(rng)
		light.position = at + Vector3(0.0, 2.8, 0.0)
		world_root.add_child(light)


func _scatter(rng: RandomNumberGenerator, model: String, count: int, lo: float, hi: float) -> void:
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
	for model in ["rock_flat", "rock_a", "flower_a", "flower_b", "grass_short"]:
		var packed := load("res://assets/models/%s.glb" % model) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate()
		if node is Node3D:
			var prop := node as Node3D
			if model == "rock_flat":
				prop.position = Vector3(0, 0.15, 0)
				prop.scale *= Vector3(1.4, 0.7, 1.4)
			elif model == "rock_a":
				prop.position = Vector3(0.35, 0.0, 0.2)
				prop.scale *= 0.8
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
	root.set_meta("face", face)
	var box := _measure(model)
	var h := maxf(box.size.y, 0.05)
	var factor := meters / h
	model.scale *= factor
	model.position.y -= box.position.y * factor
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
	var name := str(clips.get(state, ""))
	if name == "" or not player.has_animation(name):
		name = str(clips.get("idle", ""))
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
	var delta_v := hero - _look
	var push := Vector3(_past(delta_v.x, 0.5), 0.0, _past(delta_v.z, 0.65))
	var target := _look + push
	var blend := 1.0 - exp(-7.0 * delta)
	_look = _look.lerp(target, blend)
	_look.x = clampf(_look.x, 2.2, 720.0 * SCALE - 2.2)
	_look.z = clampf(_look.z, 4.0, 1280.0 * SCALE - 3.2)
	_frame(_look)


func _frame(look: Vector3) -> void:
	var back := Vector3(0.0, sin(PITCH), cos(PITCH)) * _dist
	camera.position = look + back + _shake
	# Look past the hero so the body sits a little below the middle.
	camera.look_at(look + Vector3(0.0, 0.62, -_dist * 0.11), Vector3.UP)


func _frame_on(body: Node3D, height_bias: float, distance_mul: float) -> void:
	var box := _measure(body)
	var focus := body.position + box.position + box.size * Vector3(0.5, height_bias, 0.5)
	var span := maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.72)
	span = maxf(span, 0.8)
	camera.fov = 32.0
	camera.position = focus + Vector3(span * 0.42, span * 0.2, span * distance_mul)
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
	_play(body, "idle")
	var box := _measure(body)
	var focus := box.position + box.size * Vector3(0.5, 0.7, 0.5)
	var span := maxf(box.size.y, 0.5)
	cam.fov = 26.0
	cam.position = focus + Vector3(span * 0.45, span * 0.12, span * 1.05)
	cam.look_at(focus, Vector3.UP)
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
			var point: Vector3 = xf * local.get_endpoint(i)
			if not bool(acc["ok"]):
				acc["box"] = AABB(point, Vector3.ZERO)
				acc["ok"] = true
			else:
				acc["box"] = (acc["box"] as AABB).expand(point)
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


func _to3(pos: Vector2) -> Vector3:
	return Vector3(pos.x * SCALE, 0.0, pos.y * SCALE)


func _past(delta: float, limit: float) -> float:
	var excess := absf(delta) - limit
	if excess <= 0.0:
		return 0.0
	return signf(delta) * excess


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
