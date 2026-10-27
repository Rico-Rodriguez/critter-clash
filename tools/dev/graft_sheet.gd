extends SceneTree
## Review sheet for core/pet_graft.gd: every donor's head, wings and tail as
## extracted (their own textures), one PNG per species in $OUT.
## tools/dev/graft_sheet.sh does the xvfb + compat-renderer run.
const SDB := preload("res://src/data/sidekick_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")
const PG := preload("res://src/core/pet_graft.gd")
const SIZE := 420

func _init() -> void:
	var out := OS.get_environment("OUT")
	var only := OS.get_environment("SP")
	DirAccess.make_dir_recursive_absolute(out)
	for sp: String in SDB.ORDER:
		if only != "" and sp != only:
			continue
		var imgs := []
		for slot: String in GEN.PART_SLOTS:
			imgs.append(await _shot(sp, slot, 0))
			imgs.append(await _shot(sp, slot, 1))
		var sheet := Image.create(SIZE * 3, SIZE * 2, false, Image.FORMAT_RGBA8)
		for i in imgs.size():
			if imgs[i] != null:
				sheet.blit_rect(imgs[i], Rect2i(0, 0, SIZE, SIZE), Vector2i((i / 2) * SIZE, (i % 2) * SIZE))
		sheet.save_png("%s/graft_%s.png" % [out, sp])
		print("SHEET ", sp)
	quit()

func _shot(sp: String, slot: String, view: int) -> Image:
	var part := PG.part(sp, slot)
	if part.is_empty():
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = false
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var aabb: AABB = part["aabb"]
	for it: Dictionary in part["items"]:
		var mi := MeshInstance3D.new()
		mi.mesh = it["mesh"]
		vp.add_child(mi)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var c := aabb.get_center()
	var r := aabb.size.length() * 1.5
	# view 0: from the front (+z) 3/4; view 1: from the side (+x)
	var dir := Vector3(0.5, 0.35, 1.0).normalized() if view == 0 else Vector3(1.0, 0.2, 0.0)
	cam.look_at_from_position(c + dir * r, c, Vector3.UP)
	cam.fov = 40
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
