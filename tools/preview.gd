extends SceneTree
## Model/animation preview: lines up the cast under the night lighting and
## writes a PNG. gv -s res://tools/preview.gd -- --out=/abs/path.png

func _init() -> void:
	var out := "/tmp/preview.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.6)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.7, 0.78, 1.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, -35, 0)
	world.add_child(sun)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.6, 0.3)
	warm.light_energy = 2.5
	warm.omni_range = 9.0
	warm.position = Vector3(0, 2.5, 2.5)
	world.add_child(warm)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.16, 0.2, 0.14)
	ground.material_override = gm
	world.add_child(ground)
	var cast := [
		["Knight", {"handslot.r": "sword_1handed.gltf", "handslot.l": "shield_badge_color.gltf"}, "Melee_1H_Attack_Chop"],
		["Barbarian", {"handslot.r": "axe_2handed.gltf"}, "Melee_2H_Idle"],
		["Ranger", {"handslot.l": "bow_withString.gltf"}, "Ranged_Bow_Aiming_Idle"],
		["Mage", {"handslot.r": "staff.gltf"}, "Ranged_Magic_Spellcasting"],
		["Skeleton_Minion", {"handslot.r": "Skeleton_Blade.gltf"}, "Skeletons_Walking"],
		["Skeleton_Warrior", {"handslot.r": "Skeleton_Axe.gltf", "handslot.l": "Skeleton_Shield_Large_A.gltf"}, "Idle_A"],
		["Skeleton_Rogue", {"handslot.r": "Skeleton_Crossbow.gltf"}, "Ranged_1H_Aiming"],
		["Skeleton_Mage", {"handslot.r": "Skeleton_Staff.gltf"}, "Skeletons_Taunt"],
	]
	var i := 0
	for c in cast:
		var ch := KK.character(c[0], c[1])
		world.add_child(ch)
		ch.position = Vector3((i % 4) * 1.6 - 2.4, 0, (i / 4) * -2.2)
		KK.anim_player(ch).play(c[2])
		i += 1
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 5.5, 7.5), Vector3(0, 0.8, -1.0))
	for f in 40:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit()
