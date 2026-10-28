extends SceneTree
## Contact sheet of a prop kit in a zone's real hunt lighting, a Knight beside it for scale.
## Run (software GL is fine):
##   godot --rendering-method gl_compatibility --resolution 1600x900 -s res://tools/art/kit_sheet.gd -- \
##     --kit=rime --zone=frost --names=cliff_a,cliff_b,pine_a --out=/abs/sheet.png [--cols=6] [--title="..."] [--pitch=-28] [--yaw=20]
## Pieces stand in a grid, left to right; each carries its name and triangle count.

const KitModels := preload("res://src/data/kit_models.gd")
const GROUND_SHADER := preload("res://src/fx/ground.gdshader")
const HERO_WEAPONS := {"handslot.r": "sword_1handed.gltf", "handslot.l": "shield_badge_color.gltf"}


func _noise(size: int, freq: float, seed_: int) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	nt.width = size
	nt.height = size
	nt.seamless = true
	nt.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.frequency = freq
	fn.seed = seed_
	fn.fractal_octaves = 3
	nt.noise = fn
	return nt


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		t += (m.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return t


func _init() -> void:
	var a := {"kit": "rime", "zone": "frost", "names": "", "out": "/tmp/kit_sheet.png", "cols": "6", "title": "", "pitch": "-30", "yaw": "18", "gap": "1.2", "ground": "1", "zoom": "0.62"}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and s.contains("="):
			a[s.get_slice("=", 0).substr(2)] = s.get_slice("=", 1)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	var ze: Dictionary = DB.zone(str(a["zone"]))["env"]
	var w := Node3D.new()
	root.add_child(w)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ze["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ze["ambient"]
	env.ambient_light_energy = ze["ambient_e"]
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = bool(ze.get("glow", true))
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = ze["sun"]
	sun.light_energy = ze["sun_e"]
	sun.rotation_degrees = ze["sun_rot"]
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	w.add_child(sun)
	if str(a["ground"]) == "1":
		var gi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(150, 150)
		gi.mesh = pm
		var gm := ShaderMaterial.new()
		gm.shader = GROUND_SHADER
		gm.set_shader_parameter("noise_a", _noise(256, 0.012, 1))
		gm.set_shader_parameter("noise_b", _noise(256, 0.05, 2))
		gm.set_shader_parameter("path_mask", ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_L8)))
		gm.set_shader_parameter("bounds", Vector4(-70, -70, 70, 70))
		for k: String in ze.get("ground", {}):
			gm.set_shader_parameter(k, ze["ground"][k])
		gi.material_override = gm
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.add_child(gi)
	var names: Array = str(a["names"]).split(",", false) if str(a["names"]) != "" else KitModels.names(str(a["kit"]))
	names.sort()
	var cols := int(a["cols"])
	var gap := float(a["gap"])
	var x := 0.0
	var row_h := 0.0
	var row_w := 0.0
	var y0 := 0.0
	var max_w := 0.0
	var placed: Array = []
	for i in names.size():
		var m: Mesh = KitModels.mesh(str(a["kit"]), str(names[i]))
		if m == null:
			print("MISSING ", names[i])
			continue
		var bb := m.get_aabb()
		if i % cols == 0 and i > 0:
			y0 -= row_h + 1.6
			max_w = maxf(max_w, x)
			x = 0.0
			row_h = 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = m
		var cx := x + bb.size.x * 0.5 - (bb.position.x + bb.size.x * 0.5)
		mi.position = Vector3(x + bb.size.x * 0.5 - (bb.position.x + bb.size.x * 0.5), 0, y0 * -1.0 * -1.0)
		mi.position = Vector3(x + bb.size.x * 0.5 - (bb.position.x + bb.size.x * 0.5), 0, y0)
		w.add_child(mi)
		var lab := Label3D.new()
		lab.text = "%s\n%d tris  %.1f x %.1f m" % [names[i], _tris(m), bb.size.x, bb.size.y]
		lab.font_size = 36
		lab.pixel_size = 0.006
		lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lab.rotation_degrees = Vector3(-60, 0, 0)
		lab.position = Vector3(x + bb.size.x * 0.5, 0.02, y0 + maxf(bb.size.z * 0.5, 0.6) + 0.5)
		lab.modulate = Color(1, 1, 1)
		lab.outline_size = 12
		lab.no_depth_test = true
		w.add_child(lab)
		x += bb.size.x + gap
		row_h = maxf(row_h, bb.size.z)
		placed.append(bb)
	max_w = maxf(max_w, x)
	var rows := int(ceil(float(names.size()) / cols))
	var hero := KK.character("Knight", HERO_WEAPONS)
	w.add_child(hero)
	hero.position = Vector3(-1.4, 0, 0)
	KK.anim_player(hero).play("Idle_A")
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.fov = 38.0
	var cx2 := max_w * 0.5 - 0.6
	var cz := y0 * 0.5
	var span := maxf(max_w, 8.0) + 3.0
	var pitch := deg_to_rad(float(a["pitch"]))
	var yaw := deg_to_rad(float(a["yaw"]))
	var dist := span * float(a.get("zoom", "0.62"))
	var dir := Vector3(sin(yaw) * cos(-pitch), sin(-pitch), cos(yaw) * cos(-pitch))
	cam.position = Vector3(cx2, 1.6, cz) + dir * dist
	cam.look_at(Vector3(cx2, 1.4, cz))
	for i in 24:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(str(a["out"]))
	print("WROTE ", a["out"])
	quit()
