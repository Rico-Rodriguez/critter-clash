extends Node

## Boots the glade, swaps menu / field guide / match, and bakes card portraits.

var arena: Arena
var ui: CanvasLayer
var screen: Control
var battle: Match
var portrait_root: Node
var _vps := {}
var _baked := {}
var _portrait_frames := 0
var _portraits_done := false


func _ready() -> void:
	Engine.time_scale = 1.0
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	portrait_root = Node.new()
	portrait_root.name = "Portraits"
	add_child(portrait_root)
	for species in Roster.ORDER:
		_make_portrait(species)
	show_menu()
	if OS.get_cmdline_user_args().has("--capture"):
		_capture()


func _process(_dt: float) -> void:
	if _portraits_done:
		return
	if DisplayServer.get_name() == "headless":
		_portraits_done = true
		return
	_portrait_frames += 1
	if _portrait_frames < 3:
		return
	for species in _vps.keys():
		var vp: SubViewport = _vps[species]
		var image := vp.get_texture().get_image()
		if image:
			_baked[species] = ImageTexture.create_from_image(image)
		vp.queue_free()
	_vps.clear()
	_portraits_done = true
	if is_instance_valid(battle):
		battle.refresh_portraits()


func portrait(species: String) -> Texture2D:
	if _baked.has(species):
		return _baked[species]
	if _vps.has(species):
		return (_vps[species] as SubViewport).get_texture()
	return null


func show_menu() -> void:
	Engine.time_scale = 1.0
	_drop_match()
	_clear_screen()
	arena.clear_match_actors()
	arena.set_mode("menu")
	AudioDirector.play_music()
	var menu := MainMenu.new()
	menu.play_requested.connect(start_match)
	menu.guide_requested.connect(show_collection)
	screen = menu
	ui.add_child(menu)


func show_collection() -> void:
	_clear_screen()
	var guide := Collection.new()
	guide.setup(self)
	guide.closed.connect(_on_collection_closed)
	screen = guide
	ui.add_child(guide)


func start_match() -> void:
	Engine.time_scale = 1.0
	_drop_match()
	_clear_screen()
	arena.clear_match_actors()
	arena.hide_ghost()
	arena.hide_ring()
	arena.set_mode("match")
	battle = Match.new()
	battle.name = "Match"
	battle.arena = arena
	battle.leave_match.connect(show_menu)
	battle.open_collection.connect(show_collection)
	add_child(battle)


func _on_collection_closed() -> void:
	_clear_screen()
	if is_instance_valid(battle):
		return
	show_menu()


func _drop_match() -> void:
	if not is_instance_valid(battle):
		battle = null
		return
	battle.set_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	battle.queue_free()
	battle = null


func _clear_screen() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	screen = null


func _make_portrait(species: String) -> void:
	var vp := SubViewport.new()
	vp.name = species
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	portrait_root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff3e4")
	e.ambient_light_energy = 1.05
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.6
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 160, 0)
	fill.light_color = Color("d5e2ff")
	fill.light_energy = 0.45
	world.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.72, 0.92, 2.15)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.46, 0), Vector3.UP)
	var model: Node3D = arena.packed("%s_base" % species).instantiate()
	world.add_child(model)
	StyleLib.stylize(model, 0.02, Color.WHITE, Color("ffb15a"), true)
	var anim := CritterAnimator.new()
	anim.bind(model, String(Roster.info(species)["gait"]))
	anim.tick(0.16, false)
	_fit_model(model, 1.25)
	_vps[species] = vp


func _fit_model(model: Node3D, target_height: float) -> void:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var local := model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	if first or box.size.y < 0.001:
		return
	var s := target_height / box.size.y
	model.scale = Vector3.ONE * s
	model.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)


func _capture() -> void:
	var dir := "/opt/cursor/artifacts/screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.make_dir_recursive_absolute("/workspace/captures")
	await get_tree().create_timer(1.1).timeout
	await _shot("menu")
	start_match()
	await get_tree().create_timer(0.45).timeout
	battle.sparks = 40.0
	battle._spawn_critter(0, "bramble", "base", Vector3(-2.45, 0, -2.3))
	battle._spawn_critter(0, "juniper", "base", Vector3(1.1, 0, -3.4))
	battle._spawn_critter(1, "lumen", "base", Vector3(2.4, 0, 3.3))
	battle._spawn_critter(1, "pebble", "base", Vector3(-2.3, 0, 2.6))
	battle._try_play(0, "ember", Vector3(2.35, 0, -2.55))
	battle._try_play(0, "ember", Vector3(2.35, 0, -2.55))
	await get_tree().create_timer(0.22).timeout
	await _shot("merge")
	await get_tree().create_timer(1.15).timeout
	await _shot("evolution")
	if is_instance_valid(battle.enemy_den):
		battle._hurt(battle.enemy_den, 8000.0, null, false)
	await get_tree().create_timer(0.45).timeout
	await _shot("win")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png("/opt/cursor/artifacts/screenshots/%s.png" % name)
	image.save_png("/workspace/captures/%s.png" % name)
