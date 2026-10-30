extends RefCounted
## The "petcompare" capture shot: the Knight beside a row of pets, for judging
## whether pets and heroes read as one art style (--capture --shots=petcompare
## --petrow=today|kaykit).
const SKL := preload("res://src/core/sidekick_look.gd")
const SDB := preload("res://src/data/sidekick_db.gd")

## [KayKit model, scale, tint (or null)] standing in for each species.
const KAYKIT := {
	"bonelet": ["Skeleton_Minion", 0.62, null],
	"hexling": ["Skeleton_Mage", 0.62, null],
	"acolyte": ["Skeleton_Rogue", 0.62, Color(0.75, 0.95, 0.6)],
	"barrow_squire": ["Knight", 0.6, null],
	"shade": ["Rogue_Hooded", 0.62, Color(0.45, 0.4, 0.75)],
	"sapling": ["Sapling", 0.8, null],
}


static func shoot(main: Node, row: String) -> void:
	main._set_screen_now("lobby")
	var lob: Node = main.current
	lob.ui.visible = false
	lob.hero.visible = false
	for c in lob.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
		elif c is WorldEnvironment:
			c.queue_free()
	var stage := Node3D.new()
	main.add_child(stage)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.19, 0.16)
	ground.material_override = gm
	stage.add_child(ground)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.78, 0.75)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	stage.add_child(cam)
	cam.make_current()
	var hero := KK.character("Knight", {"handslot.r": "knight_sword_0.gltf"})
	stage.add_child(hero)
	hero.position = Vector3(0, 0, -0.6)
	KK.anim_player(hero).play("Idle_A")
	var ids: Array = SDB.ORDER.filter(func(k): return not SDB.def(k).get("hidden", false)) if row == "today" else ([row.trim_prefix("solo_").trim_prefix("pet_")] if row.begins_with("solo_") or row.begins_with("pet_") else KAYKIT.keys())
	var n := ids.size()
	for i in n:
		var id: String = ids[i]
		var m: Node3D
		if row == "today" or row.begins_with("pet_"):
			var b: Dictionary = SKL.build(id, _a("petstage", "1") == "2")
			stage.set_meta("look", b)
			m = b["root"]
			if row.begins_with("pet_"):
				m.position.y = float(SDB.def(id).get("fly", 0.0)) * 0.5
			if b["anim"] != null and str(b["idle"]) != "":
				(b["anim"] as AnimationPlayer).play(str(b["idle"]))
		else:
			var spec: Array = KAYKIT[id]
			var src: String = spec[0]
			if src.begins_with("res://"):
				m = (load(src) as PackedScene).instantiate()
			else:
				m = KK.character(src)
				KK.anim_player(m).play("Idle_A")
			m.scale = Vector3.ONE * float(spec[1])
			if spec[2] != null:
				for mi in KK.meshes(m):
					mi.set_instance_shader_parameter("tint", spec[2])
					var mat := (mi.mesh.surface_get_material(0) as BaseMaterial3D)
					if mat:
						var mt := mat.duplicate() as BaseMaterial3D
						mt.albedo_color = spec[2]
						mi.material_override = mt
		stage.add_child(m)
		# Two rows in front of the hero, a little apart.
		var per := ceili(n / 2.0)
		var r := i / per
		var c := i % per
		var y := m.position.y
		m.position = (Vector3((c - (per - 1) * 0.5) * 1.15, 0, 0.9 + r * 1.1) if n > 1 else Vector3(0.75, 0, 0.3)) + Vector3(0, y, 0)
		m.rotation.y = 0.25 if n > 1 else 0.5
	if n > 1:
		cam.look_at_from_position(Vector3(0, 3.4, 12.5), Vector3(0, 0.9, 0.6), Vector3.UP)
	else:
		hero.position.x = -0.55
		cam.look_at_from_position(Vector3(1.2, 2.4, 7.0), Vector3(0, 0.8, 0), Vector3.UP)
		if _a("petclose", "") != "":
			var foc: Vector3 = stage.get_child(stage.get_child_count() - 1).position + Vector3(0, 0.5, 0)
			cam.look_at_from_position(foc + Vector3(0.9, 0.9, 3.2), foc, Vector3.UP)
		var clip: String = _a("petclip", "")
		if clip != "":
			var look: Dictionary = stage.get_meta("look")
			SKL.play(look, clip)
			await main._wait(float(_a("petat", "0.3")))
			(look["anim"] as AnimationPlayer).pause()
	await main._wait(1.5)
	await main._save("petcompare_" + row)


## A --key=value user argument, or `def`.
static func _a(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return def
