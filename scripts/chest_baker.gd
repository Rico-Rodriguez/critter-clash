class_name ChestBaker
extends Node

## Bakes the 3D chest (scripts/chest3d.gd) in each tone as a 256 px icon with
## a transparent background for the home chest slots.
##   godot --path . --rendering-driver vulkan -- --bake-chests
## Writes assets/sprites/chests/<tone>.png.

const SIZE := 256
const OUT := "res://assets/sprites/chests"


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var we := WorldEnvironment.new()
	we.environment = Chest3D.stage_env(0.35)
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffdcae")
	key.light_energy = 2.2
	key.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("ffb070")
	rim.light_energy = 2.0
	rim.rotation_degrees = Vector3(-25, 170, 0)
	root.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("7f96d0")
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-10, -75, 0)
	root.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0, 2.4, 5.3)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0))
	cam.current = true
	for tone in ["wood", "silver", "gold", "magic"]:
		var chest := Chest3D.new(tone)
		chest.rotation.y = -0.38
		root.add_child(chest)
		for i in 8:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, tone]))
		print("BAKED chest ", tone)
		chest.queue_free()
		await RenderingServer.frame_post_draw
