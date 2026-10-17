class_name Arena
extends Node3D

const RIVER := 1.28

var camera: Camera3D
var units_root: Node3D
var props: Node3D
var effects: Node3D
var showcase_root: Node3D
var cam_base := Vector3.ZERO
var shake := 0.0
var _packed := {}
var _ghost: Node3D
var _ghost_species := ""
var _ring: MeshInstance3D
var _clouds: Array = []
var _showcase: Array = []
var _landmarks: Array = []
var mode := "menu"
var _spark_mesh: SphereMesh


func _ready() -> void:
	_build_world()
	set_mode("menu")


func _process(dt: float) -> void:
	if shake > 0.0:
		camera.position = cam_base + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * shake
		shake = move_toward(shake, 0.0, dt * 1.6)
	else:
		camera.position = cam_base + Vector3(0, sin(Time.get_ticks_msec() * 0.00025) * 0.08, 0)
	for cloud in _clouds:
		if not is_instance_valid(cloud):
			continue
		cloud.position.x += sin(Time.get_ticks_msec() * 0.00015 + cloud.position.z) * dt * 0.15
	if mode == "menu":
		for item in _showcase:
			var n: Node3D = item["node"]
			if not is_instance_valid(n):
				continue
			var anim: CritterAnimator = item["anim"]
			var origin: Vector3 = item["origin"]
			var t := Time.get_ticks_msec() * 0.001 + float(item["phase"])
			n.position = origin + Vector3(sin(t * 0.45) * 0.55, 0, cos(t * 0.33) * 0.35)
			n.position.y = surface_y(n.position.x, n.position.z, item["fly"])
			var visual: Node3D = item["visual"]
			var dir := Vector3(cos(t * 0.45), 0, -sin(t * 0.33))
			visual.rotation.y = lerp_angle(visual.rotation.y, anim.face_yaw(dir), 0.08)
			anim.tick(dt, true)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func set_mode(next: String) -> void:
	mode = next
	for node in _landmarks:
		if is_instance_valid(node):
			node.visible = next != "match"
	if next == "menu":
		_clear_units()
		_build_showcase()
	else:
		_clear_showcase()


func habitat_at(pos: Vector3) -> String:
	if absf(pos.z) <= RIVER:
		return "water"
	if pos.x < 0.0:
		return "forest"
	return "lava"


func height_at(x: float, z: float) -> float:
	var river := clampf(1.0 - absf(z) / 1.62, 0.0, 1.0)
	river = river * river
	var bed := -0.38 * river
	var ax := absf(x)
	var az := absf(z)
	var ox := maxf(0.0, ax - 5.15)
	var oz := maxf(0.0, az - 9.45)
	var noise := sin(x * 1.7 + 0.4) * cos(z * 1.35) * 0.02
	if ax < 5.05 and az < 9.3:
		return bed + noise
	var bowl := ox * ox * 0.16 + oz * oz * 0.12
	var far := clampf((ox + oz) / 4.5, 0.0, 1.0)
	var roll := (sin(x * 0.36 + 0.8) * 0.85 + cos(z * 0.31) * 0.6) * far
	return bed * (1.0 - clampf(ox * 0.4 + oz * 0.4, 0.0, 1.0)) + bowl + roll + noise


func surface_y(x: float, z: float, flying: bool) -> float:
	var ground := 0.02
	if _on_bridge(x, z):
		ground = 0.2
	elif absf(z) < 1.15:
		ground = -0.05
	if flying:
		return ground + 1.55
	return ground


func _on_bridge(x: float, z: float) -> bool:
	if absf(z) > 1.3:
		return false
	return absf(x + 2.55) < 0.7 or absf(x - 2.55) < 0.7


func show_ghost(species: String, pos: Vector3, ok: bool, form: String = "base") -> void:
	var key := "%s:%s" % [species, form]
	if _ghost == null or _ghost_species != key:
		if is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = Node3D.new()
		effects.add_child(_ghost)
		var visual := Node3D.new()
		_ghost.add_child(visual)
		var model := packed("%s_%s" % [species, form]).instantiate()
		visual.scale = Vector3.ONE * 2.05
		visual.add_child(model)
		StyleLib.stylize(model, 0.012, Color.WHITE, Color.WHITE, true)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var geo := mi as GeometryInstance3D
			geo.transparency = 0.34
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost_species = key
	_ghost.visible = true
	_ghost.position = Vector3(pos.x, surface_y(pos.x, pos.z, species == "lumen"), pos.z)
	var tint := Color(1, 1, 1) if ok else Color(1.2, 0.5, 0.46)
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override
		if mat is ShaderMaterial:
			mat.set_shader_parameter("team_tint", tint)


func hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false


func show_ring(pos: Vector3, color: Color, scale: float) -> void:
	_ring.visible = true
	_ring.position = Vector3(pos.x, surface_y(pos.x, pos.z, false) + 0.06, pos.z)
	_ring.scale = Vector3.ONE * scale
	var mat := _ring.material_override as ShaderMaterial
	var c := Color(color.r, color.g, color.b, 0.85)
	mat.set_shader_parameter("albedo", c)
	mat.set_shader_parameter("energy", 1.3)


func hide_ring() -> void:
	_ring.visible = false


func burst(pos: Vector3, color: Color, big: bool = false) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.amount = 22 if big else 12
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 78.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 3.8 if big else 2.6
	p.gravity = Vector3(0, -5.5, 0)
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	p.color = color
	p.position = pos + Vector3(0, 0.45, 0)
	effects.add_child(p)
	p.emitting = true
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.25
	tor.outer_radius = 0.38
	ring.mesh = tor
	ring.material_override = StyleLib.flat_material(Color(color.r, color.g, color.b, 0.9), 1.6)
	ring.position = pos + Vector3(0, 0.2, 0)
	effects.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(3.4, 1.0, 3.4) if big else Vector3(2.2, 1.0, 2.2), 0.38)
	tw.parallel().tween_property(ring, "position:y", pos.y + 0.5, 0.38)
	tw.tween_callback(func() -> void:
		ring.queue_free()
		p.queue_free()
	)


func clear_match_actors() -> void:
	_clear_units()
	hide_ghost()
	hide_ring()


func _clear_units() -> void:
	for child in units_root.get_children():
		child.queue_free()


func _clear_showcase() -> void:
	for child in showcase_root.get_children():
		child.queue_free()
	_showcase.clear()


func _build_showcase() -> void:
	_clear_showcase()
	var specs := [
		["ember", "base", -1.5, -3.4, false],
		["juniper", "base", 1.7, -4.3, false],
		["lumen", "base", -2.5, -1.8, true],
		["pip", "base", 0.4, -2.6, false],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		var holder := Node3D.new()
		showcase_root.add_child(holder)
		var visual := Node3D.new()
		holder.add_child(visual)
		var model := packed("%s_%s" % [spec[0], spec[1]]).instantiate()
		visual.scale = Vector3.ONE * 2.05
		visual.add_child(model)
		StyleLib.stylize(model, 0.014, Color.WHITE, Color("ffb15a"), true)
		var anim := CritterAnimator.new()
		anim.bind(model, Roster.info(spec[0])["gait"])
		var origin := Vector3(spec[2], 0, spec[3])
		holder.position = origin
		_showcase.append({"node": holder, "visual": visual, "anim": anim, "origin": origin, "phase": i * 1.3, "fly": spec[4]})


func packed(kind: String) -> PackedScene:
	if not _packed.has(kind):
		_packed[kind] = load("res://assets/models/%s.glb" % kind)
	return _packed[kind]


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e7a56a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9eb4d8")
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.tonemap_white = 5.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0035
	env.fog_light_color = Color("e8b07a")
	env.fog_aerial_perspective = 0.08
	env.ssao_enabled = true
	env.ssao_radius = 0.85
	env.ssao_intensity = 1.6
	env.ssao_power = 1.8
	env.ssao_detail = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.62
	env.glow_strength = 0.8
	env.glow_hdr_threshold = 1.05
	env.glow_bloom = 0.14
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	camera = Camera3D.new()
	camera.fov = 36.0
	cam_base = Vector3(0.15, 12.4, -10.6)
	camera.position = cam_base
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0.45, 0.15), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -36, 0)
	sun.light_color = Color("ffd7a2")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 48.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.35
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 140, 0)
	fill.light_color = Color("7ea6ee")
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	add_child(fill)

	var sky := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 46.0
	sphere.height = 92.0
	sphere.radial_segments = 24
	sphere.rings = 12
	sky.mesh = sphere
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.material_override = sky_mat
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)

	var ground := MeshInstance3D.new()
	ground.mesh = _ground_mesh()
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/ground.gdshader")
	ground.material_override = gmat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var water := MeshInstance3D.new()
	water.mesh = _water_mesh()
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	water.material_override = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	effects = Node3D.new()
	effects.name = "Effects"
	add_child(effects)
	showcase_root = Node3D.new()
	showcase_root.name = "Showcase"
	add_child(showcase_root)

	_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.58
	_ring.mesh = tor
	_ring.material_override = StyleLib.flat_material(Color(1, 1, 1, 0.8), 1.2)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	effects.add_child(_ring)

	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.08
	_spark_mesh.height = 0.16
	_spark_mesh.radial_segments = 8
	_spark_mesh.rings = 4
	_spark_mesh.material = StyleLib.flat_material(Color.WHITE, 1.4)

	_dress()
	_particles()


func _ground_mesh() -> ArrayMesh:
	var nx := 88
	var nz := 100
	var x0 := -16.0
	var x1 := 16.0
	var z0 := -18.0
	var z1 := 18.0
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	for j in nz + 1:
		for i in nx + 1:
			var x := lerpf(x0, x1, float(i) / nx)
			var z := lerpf(z0, z1, float(j) / nz)
			var y := height_at(x, z)
			positions.append(Vector3(x, y, z))
			colors.append(_tint(x, z, y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var a := i + j * (nx + 1)
			var b := a + 1
			var c := a + (nx + 1)
			var d := c + 1
			_tri(st, positions, colors, a, b, d)
			_tri(st, positions, colors, a, d, c)
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, positions: PackedVector3Array, colors: PackedColorArray, i0: int, i1: int, i2: int) -> void:
	st.set_color(colors[i0])
	st.add_vertex(positions[i0])
	st.set_color(colors[i1])
	st.add_vertex(positions[i1])
	st.set_color(colors[i2])
	st.add_vertex(positions[i2])


func _tint(x: float, z: float, h: float) -> Color:
	var hab := "water"
	if absf(z) > RIVER:
		hab = "forest" if x < 0.0 else "lava"
	var n := sin(x * 3.2 + z) * 0.5 + 0.5
	var col := Color("7f8e98")
	var heat := 0.0
	if hab == "water":
		col = Color("6d838e").lerp(Color("9aaba8"), n)
	elif hab == "forest":
		col = Color("2f8a3a").lerp(Color("67c45a"), n)
		if absf(x + 2.55) < 0.48 and absf(z) < 9.2:
			col = col.lerp(Color("c9a56e"), 0.78)
		if absf(x) < 0.85 and absf(z) > 6.4:
			col = col.lerp(Color("d2b48a"), 0.45)
	else:
		var crack := sin(x * 6.2 + z * 1.7) + sin(z * 5.1 - x)
		heat = clampf((crack - 1.05) * 0.85, 0.0, 1.0)
		col = Color("5a342c").lerp(Color("2a1c1a"), n * 0.55)
		if absf(x - 2.55) < 0.48 and absf(z) > RIVER and absf(z) < 9.2:
			col = col.lerp(Color("b08968"), 0.62)
			heat *= 0.2
	if h > 0.45:
		col = col.lerp(Color("b7a898"), clampf((h - 0.45) / 1.4, 0.0, 1.0))
		heat *= 0.2
	return Color(col.r, col.g, col.b, heat)


func _water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 36
	var nz := 10
	for j in nz:
		for i in nx:
			var x0 := lerpf(-7.4, 7.4, float(i) / nx)
			var x1 := lerpf(-7.4, 7.4, float(i + 1) / nx)
			var z0 := lerpf(-1.7, 1.7, float(j) / nz)
			var z1 := lerpf(-1.7, 1.7, float(j + 1) / nz)
			var y := -0.02
			st.add_vertex(Vector3(x0, y, z0))
			st.add_vertex(Vector3(x1, y, z0))
			st.add_vertex(Vector3(x1, y, z1))
			st.add_vertex(Vector3(x0, y, z0))
			st.add_vertex(Vector3(x1, y, z1))
			st.add_vertex(Vector3(x0, y, z1))
	st.generate_normals()
	return st.commit()


func _dress() -> void:
	# Stone bridges carry the two lanes across the river.
	_prop("bridge", -2.55, 0.0, 0.0, 1.15)
	_prop("bridge", 2.55, 0.0, PI, 1.15)
	_prop("path_small", -1.15, 0.15, 0.4, 1.0)
	_prop("path_small", 1.2, -0.2, 1.1, 1.0)
	# Dens and burrows. Doors face the center of the glade.
	_structure_prop("den", 0.0, -8.2, PI, "ffb15a")
	_structure_prop("den", 0.0, 8.2, 0.0, "9eb6f2")
	_structure_prop("burrow", -2.75, -5.85, PI, "ffb15a")
	_structure_prop("burrow", 2.75, -5.85, PI, "ffb15a")
	_structure_prop("burrow", -2.75, 5.85, 0.0, "9eb6f2")
	_structure_prop("burrow", 2.75, 5.85, 0.0, "9eb6f2")

	# Forest shoulder. Models are already sized, so scale stays near 1.
	_prop("tree_a", -6.6, -2.4, 0.4, 1.15)
	_prop("tree_b", -7.2, 2.6, 1.2, 1.05)
	_prop("tree_pine", -6.4, -6.8, 0.3, 1.1)
	_prop("tree_pine_b", -7.5, 6.4, 0.8, 1.0)
	_prop("tree_twist", -6.2, 9.2, 0.5, 1.05)
	_prop("bush", -4.6, -7.0, 0.2, 1.1)
	_prop("bush_flower", -4.9, 3.4, 1.0, 1.05)
	_prop("bush", -5.2, 0.15, 0.6, 1.0)
	_prop("mushroom", -4.3, -3.1, 0.4, 1.2)
	_prop("mushroom_shelf", -4.55, 1.6, 0.9, 1.15)
	_prop("fern", -3.7, -4.4, 0.3, 1.2)
	_prop("fern", -4.15, 5.2, 0.7, 1.1)
	_prop("clover", -3.2, -6.2, 0.2, 1.3)
	_prop("flower_a", -3.5, -7.5, 0.4, 1.15)
	_prop("flower_b", -1.2, -7.3, 1.1, 1.0)
	_prop("grass_tall", -3.6, -2.2, 0.4, 1.15)
	_prop("grass_short", -4.2, 2.4, 0.8, 1.2)
	_prop("grass_wispy", -5.4, -1.15, 0.3, 1.1)
	_prop("grass_wispy", -4.5, 1.15, 1.0, 1.05)
	_prop("pebble_rock", -5.1, 0.05, 0.5, 1.2)
	_prop("rock_a", -5.6, 4.6, 0.4, 1.15)
	_prop("tree_a", -3.2, -10.8, 0.7, 1.2)
	_prop("tree_b", -4.4, 11.0, 0.2, 1.1)

	# Lava shoulder.
	_prop("tree_dead", 6.7, -3.2, 0.5, 1.1)
	_prop("tree_dead", 7.3, 4.8, 1.1, 0.95)
	_prop("tree_pine", 6.5, 8.6, 0.4, 0.85)
	_prop("rock_lava", 4.6, -2.5, 0.5, 1.25)
	_prop("rock_lava", 4.85, 1.9, 1.3, 1.05)
	_prop("rock_c", 4.4, 5.5, 0.2, 1.15)
	_prop("rock_b", 6.3, -6.6, 0.8, 1.3)
	_prop("rock_a", 5.6, 7.2, 0.4, 1.1)
	_prop("flower_lava", 3.55, -7.4, 0.6, 1.1)
	_prop("grass_short", 4.4, -4.2, 0.3, 1.0)
	_prop("pebble_rock_b", 5.3, 0.15, 0.4, 1.3)
	_prop("path_small", 4.1, 0.35, 0.2, 1.0)
	_prop("tree_twist", 3.8, -10.6, 0.4, 1.05)
	_prop("tree_pine_b", 4.2, 10.8, 1.0, 1.0)

	# Framing hills of trees behind each den, kept off the lanes.
	_prop("flower_a", -0.85, -9.1, 0.5, 1.05)
	_prop("flower_b", 0.95, -9.0, 1.2, 0.95)
	_prop("flower_a", -0.9, 9.05, 0.3, 1.0)
	_prop("flower_lava", 1.05, 9.0, 0.8, 1.0)
	_prop("grass_tall", -1.6, -7.6, 0.2, 1.0)
	_prop("grass_tall", 1.55, 7.5, 0.7, 1.0)
	_prop("rock_b", -1.7, 8.4, 0.4, 0.9)
	_prop("rock_lava", 1.65, -8.35, 0.6, 0.85)


func _prop(kind: String, x: float, z: float, rot: float, scale: float) -> void:
	var node := packed(kind).instantiate()
	var y := height_at(x, z)
	node.position = Vector3(x, y, z)
	node.rotation.y = rot
	node.scale = Vector3.ONE * scale
	var outline := 0.008 if kind.begins_with("tree") else 0.0
	StyleLib.stylize(node, outline, Color.WHITE, Color.WHITE, false)
	if kind.begins_with("flower") or kind.begins_with("grass") or kind.begins_with("pebble_rock") or kind == "fern" or kind == "clover" or kind.begins_with("mushroom") or kind.begins_with("rock") or kind.begins_with("path"):
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(node)


func _structure_prop(kind: String, x: float, z: float, rot: float, flag_hex: String) -> void:
	var node := packed(kind).instantiate()
	node.position = Vector3(x, height_at(x, z), z)
	node.rotation.y = rot
	node.scale = Vector3.ONE * 1.28
	StyleLib.stylize(node, 0.02, Color.WHITE, Color(flag_hex), false)
	props.add_child(node)
	_landmarks.append(node)


func _particles() -> void:
	_motes(Vector3(-4.8, 0.6, -2.0), Color("d8ff9a"), 16, Vector3(3.5, 1.2, 8.0), 0.15, "flies")
	_motes(Vector3(5.2, 0.5, 1.0), Color("ffb15a"), 18, Vector3(3.2, 1.4, 8.0), 0.55, "embers")
	_motes(Vector3(-6.0, 1.6, -2.2), Color("f7c6d6"), 10, Vector3(1.5, 1.0, 1.5), -0.25, "petals")


func _motes(pos: Vector3, color: Color, amount: int, box: Vector3, gravity_y: float, _tag: String) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.amount = amount
	p.lifetime = 5.5
	p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 40
	p.gravity = Vector3(0, gravity_y, 0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.55
	p.color = color
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(p)
