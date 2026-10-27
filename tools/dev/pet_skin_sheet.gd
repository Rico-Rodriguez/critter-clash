extends RefCounted
## The "petskins" capture shot: one species in every mutation and coat, at phone
## size, drawn in the main viewport by src/main.gd (--capture --shots=petskins
## --skinsp=bonelet[,drake...] [--skinmode=grid|solo:<mutation>:<pattern>:<0|1>]).
## tools/dev/pet_skin_sheet.sh does the xvfb + compat-renderer run.
const SDB := preload("res://src/data/sidekick_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")
const SKL := preload("res://src/core/sidekick_look.gd")

## [label, mutation, pattern, glow]
const CELLS := [
	["plain", "", "plain", false], ["gilded", "gilded", "plain", false], ["frost", "frostborn", "plain", false],
	["storm", "stormtouched", "plain", false], ["voidborn", "voidborn", "plain", false], ["ember", "emberheart", "plain", false],
	["verdant", "verdant", "plain", false], ["spots", "", "spots", false], ["stripes", "", "stripes", false],
	["glow", "", "plain", true], ["gild+stripe", "gilded", "stripes", false], ["frost+spot+glow", "frostborn", "spots", true],
	["storm+glow", "stormtouched", "plain", true], ["void+stripe", "voidborn", "stripes", false], ["ember+spot", "emberheart", "spots", false],
]
## Sheet zoom per species: how far apart the cells sit and how wide the camera looks.
const ZOOM := {"drake": 1.25, "crow": 1.6, "wisp": 1.5, "mimic": 1.2, "sapling": 1.2, "barrow_squire": 1.0, "hexling": 1.0, "bonelet": 0.8, "acolyte": 0.9, "shade": 0.9, "bat": 1.2}
const ACCENTS := ["ffd24a", "6ee7ff", "ff6ea8", "9dff6e", "ff8a3d"]


static func shoot(main: Node, sps: PackedStringArray, mode: String) -> void:
	for sp in sps:
		await _sheet(main, sp, mode)


static func _gen(i: int, cell: Array) -> Dictionary:
	var g := SDB.base_genes()
	g["mutation"] = cell[1]
	g["pattern"] = cell[2]
	g["glow"] = cell[3]
	g["accent"] = ACCENTS[i % ACCENTS.size()]
	return g


static func _sheet(main: Node, sp: String, mode: String) -> void:
	main._set_screen_now("lobby")
	var lob: Node = main.current
	lob.ui.visible = false
	lob.hero.visible = false
	for c in lob.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
		elif c is WorldEnvironment:
			c.queue_free()
	var vp := Node3D.new()
	main.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.75, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.19, 0.2)
	gm.roughness = 1.0
	ground.material_override = gm
	vp.add_child(ground)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var cells: Array = CELLS
	var cols := 3
	var k: float = ZOOM.get(sp, 1.0)
	var solo := mode.begins_with("solo")
	if solo:
		var p := mode.split(":")
		cells = [["solo", p[1], p[2], p[3] == "1"]]
		cols = 1
	var rows := int(ceil(cells.size() / float(cols)))
	for i in cells.size():
		var cell: Array = cells[i]
		var id := "x%d" % (700 + i)
		SDB.BRED[id] = SDB.bred_def(sp, _gen(i, cell))
		var look: Dictionary = SKL.build(id, false)
		var m: Node3D = look["root"]
		vp.add_child(m)
		var cx := (i % cols - (cols - 1) * 0.5) * 1.3 * k
		var cz := (i / cols - (rows - 1) * 0.5) * 3.0 * k
		m.position = Vector3(cx, 0, cz)
		m.rotation.y = 0.5
		if look["anim"] != null and str(look["idle"]) != "":
			(look["anim"] as AnimationPlayer).play(str(look["idle"]))
		if not solo:
			var lb := Label3D.new()
			lb.text = str(cell[0])
			lb.font_size = 40
			lb.pixel_size = 0.0045 * k
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.position = Vector3(cx, 0.02, cz + 0.9 * k)
			vp.add_child(lb)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	if solo:
		cam.size = 1.5 * k
		cam.look_at_from_position(Vector3(0, 1.1, 3.0) + Vector3(0, 0, 0), Vector3(0, 0.45, 0), Vector3.UP)
	else:
		cam.size = 4.0 * k
		var tilt := deg_to_rad(30.0)
		cam.look_at_from_position(Vector3(0, sin(tilt) * 20.0, cos(tilt) * 20.0), Vector3.ZERO, Vector3.UP)
	cam.far = 60.0
	cam.make_current()
	await main._wait(1.5)
	await main._save("skins_%s%s" % [sp, "" if mode == "grid" else "_" + mode.replace(":", "_")])
	vp.queue_free()
