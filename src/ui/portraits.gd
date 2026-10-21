class_name Portraits
extends RefCounted
## Head-and-shoulders renders of each hero, drawn once into textures and cached.
## Until they exist (or when there is no GPU, as in the headless checks) callers
## fall back to the hero's flat icon.

const SIZE := 256

static var _cache := {}
static var _building := false


static func tex(id: String) -> Texture2D:
	return _cache.get(id)


static func ready_all() -> bool:
	return _cache.size() >= DB.HERO_ORDER.size()


## Renders every missing portrait. Safe to call repeatedly; returns when done.
static func build(host: Node) -> void:
	if _building or ready_all() or DisplayServer.get_name() == "headless":
		return
	_building = true
	for id in DB.HERO_ORDER:
		if not is_instance_valid(host) or not host.is_inside_tree():
			break
		_cache[id] = await _render(host, id)
	_building = false


## Re-renders one hero after a gear change.
static func rebuild(host: Node, id: String) -> void:
	if not ready_all() or DisplayServer.get_name() == "headless":
		return
	_cache[id] = await _render(host, id)


static func _render(host: Node, id: String) -> Texture2D:
	var d: Dictionary = DB.HEROES[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.7)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-35, 40, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 0.9
	rim.rotation_degrees = Vector3(-20, -150, 0)
	vp.add_child(rim)
	var hero := Actor.new()
	vp.add_child(hero)
	hero.build_model(d["model"], d["weapons"], Color(0.55, 0.68, 1.0), 0.5)
	GearLook.apply(hero, id)
	hero.rotation.y = 0.35
	hero.play(d["anim"]["idle"], 0.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.55, 1.78, 2.6), Vector3(0, 1.5, 0), Vector3.UP)
	host.add_child(vp)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return ImageTexture.create_from_image(img)
