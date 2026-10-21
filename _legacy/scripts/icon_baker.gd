class_name IconBaker
extends Node

## Renders every collection-log item as a small lit 3D prop on a transparent
## background: gold coins, leather purses, tied fibre bundles, crystals,
## mushroom caps, forged gear. Built from primitives and the game's own nature
## models, so the icons share the hunt's materials and light.
##   godot --path . --rendering-driver vulkan -- --bake-icons
## Writes assets/sprites/items/<drop id>.png (256 px).

const SIZE := 256
const OUT := "res://assets/sprites/items"

var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _prop: Node3D


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	_lights()
	for drop in Catalog.DROPS:
		if str(drop.get("kind", "")) == "pet":
			continue
		await _bake(drop)


func _lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aa6c0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.08
	var holder := WorldEnvironment.new()
	holder.environment = env
	_root.add_child(holder)
	# Warm key high left, cool fill, hot rim from behind: forge light.
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe6c4")
	key.light_energy = 2.3
	key.rotation_degrees = Vector3(-42, 35, 0)
	key.shadow_enabled = true
	_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("8fa8e0")
	fill.light_energy = 0.6
	fill.rotation_degrees = Vector3(-12, -70, 0)
	_root.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("ffcf9a")
	rim.light_energy = 2.6
	rim.rotation_degrees = Vector3(-18, 175, 0)
	_root.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 24.0
	_cam.current = true
	_root.add_child(_cam)


func _bake(drop: Dictionary) -> void:
	if _prop != null:
		_prop.queue_free()
	_prop = Node3D.new()
	_root.add_child(_prop)
	_build(drop, _prop)
	await get_tree().process_frame
	# Frame the prop: centre its bounds, fit the larger side.
	var box := _bounds(_prop)
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.1)
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 0.92
	var dir := Vector3(0.0, 0.42, 1.0).normalized()
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, str(drop["id"])]))
	print("ICON ", drop["id"])


func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# --- materials -------------------------------------------------------------

func _mat(c: Color, rough := 0.6, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _gold() -> StandardMaterial3D:
	return _mat(Color("c99a3e"), 0.42, 0.9)


func _iron() -> StandardMaterial3D:
	return _mat(Color("6b6660"), 0.38, 0.9)


func _leather(c := Color("6a3f22")) -> StandardMaterial3D:
	return _mat(c, 0.78, 0.0)


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cyl(r: float, h: float, top := -1.0, seg := 32) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top < 0.0 else top
	c.height = h
	c.radial_segments = seg
	return c


func _sphere(r: float, seg := 32, rings := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return s


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _model(parent: Node3D, name: String, tint: Color, pos := Vector3.ZERO, scl := 1.0, glow := 0.0) -> Node3D:
	var path := "res://assets/models/%s.glb" % name
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	if tint.a > 0.0:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _mat(tint, 0.35, 0.1, glow)
	return n


# --- props ----------------------------------------------------------------

func _build(drop: Dictionary, p: Node3D) -> void:
	var id := str(drop["id"])
	var col := Color(str(drop.get("color", "f0b429")))
	match str(drop.get("kind", "")):
		"coins":
			if id.ends_with("pouch"):
				_pouch(p)
			else:
				_coins(p, 4)
		"cards":
			_cards(p, str(drop.get("hero", "ember")))
		"gear":
			_gear(p, id, col)
		_:
			_material(p, id, col)


func _coin(p: Node3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	_mesh(p, _cyl(0.5, 0.09, -1.0, 40), _gold(), pos, rot)
	_mesh(p, _cyl(0.38, 0.1, -1.0, 40), _mat(Color("a87a2e"), 0.5, 0.9), pos, rot)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.4
	lip.outer_radius = 0.5
	lip.rings = 40
	_mesh(p, lip, _mat(Color("d8ad52"), 0.35, 0.9), pos + Vector3(0, 0.03, 0), rot, Vector3(1, 0.5, 1))


func _coins(p: Node3D, n: int) -> void:
	for i in n:
		_coin(p, Vector3(sin(i * 1.7) * 0.04, i * 0.095, cos(i * 2.3) * 0.04))
	_coin(p, Vector3(0.62, 0.32, 0.18), Vector3(0, 20, 72))
	_coin(p, Vector3(-0.5, 0.05, 0.35), Vector3(8, 0, 6))


func _pouch(p: Node3D) -> void:
	var sack := _mesh(p, _sphere(0.6, 9, 8), _leather(Color("5a3420")), Vector3(0, 0.52, 0), Vector3(0, 12, 0), Vector3(1.08, 0.86, 1.0))
	sack.name = "Sack"
	_mesh(p, _cyl(0.24, 0.18, 0.2), _leather(Color("55311a")), Vector3(0, 1.08, 0))
	_mesh(p, _cyl(0.32, 0.22, 0.42), _leather(Color("7a4a28")), Vector3(0, 1.26, 0))
	var tie := TorusMesh.new()
	tie.inner_radius = 0.2
	tie.outer_radius = 0.27
	_mesh(p, tie, _gold(), Vector3(0, 1.1, 0))
	_coin(p, Vector3(0.72, 0.06, 0.3), Vector3(6, 0, 4))
	_coin(p, Vector3(0.62, 0.15, 0.42), Vector3(0, 30, 12))


func _cards(p: Node3D, hero: String) -> void:
	var tex: Texture2D = null
	var path := "res://assets/sprites/portraits/%s.png" % hero
	if ResourceLoader.exists(path):
		tex = load(path)
	for i in 2:
		var holder := Node3D.new()
		holder.position = Vector3(-0.22 + i * 0.36, 0.0, -0.05 + i * 0.12)
		holder.rotation_degrees = Vector3(-6, 0, 12 - i * 22)
		p.add_child(holder)
		_mesh(holder, _box(0.82, 1.16, 0.05), _gold(), Vector3.ZERO)
		_mesh(holder, _box(0.72, 1.06, 0.06), _mat(Color("2a1a12"), 0.7), Vector3.ZERO)
		var face := QuadMesh.new()
		face.size = Vector2(0.68, 0.84)
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = tex
		fm.albedo_color = Color.WHITE if tex else Color("8a5a3a")
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.roughness = 0.6
		_mesh(holder, face, fm, Vector3(0, 0.06, 0.035))
		var plate := _mesh(holder, _box(0.68, 0.14, 0.02), _mat(Color("5a1c14"), 0.6), Vector3(0, -0.44, 0.04))
		plate.name = "Plate"


func _material(p: Node3D, id: String, col: Color) -> void:
	if "shard" in id or "ore" in id:
		# A faceted crystal cluster on a dark stone.
		var glow := 0.55 if "ember" in id or "aurora" in id else 0.18
		_mesh(p, _sphere(0.5, 7, 4), _mat(Color("3a3430"), 0.9), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.2, 0.45, 1.0))
		var spikes := [[0.0, 1.25, 0.0, 0.0], [-0.32, 0.85, -14.0, 20.0], [0.34, 0.9, 16.0, -18.0], [0.1, 0.7, 4.0, -36.0], [-0.12, 0.6, -24.0, 40.0]]
		for k in spikes:
			var h: float = k[1]
			var spike := _cyl(0.17, h, 0.0, 6)
			var holder := Node3D.new()
			holder.position = Vector3(k[0], 0.15, 0.0)
			holder.rotation_degrees = Vector3(k[3], 0, k[2])
			p.add_child(holder)
			var m := _mat(col.darkened(0.3), 0.12, 0.2, glow)
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_mesh(holder, spike, m, Vector3(0, h * 0.5, 0))
	elif "cap" in id:
		# A cut mushroom cap with pale spots on a short stem.
		var cap_col := col.darkened(0.15)
		var big := id == "giant_cap"
		var n := 3 if id == "cap_bits" else 1
		for i in n:
			var o := Vector3((i - (n - 1) * 0.5) * 0.7, 0, (i % 2) * 0.25)
			var sc := 1.25 if big else (0.65 if n > 1 else 1.0)
			_mesh(p, _cyl(0.16 * sc, 0.55 * sc, 0.13 * sc), _mat(Color("e6d6b8"), 0.8), o + Vector3(0, 0.27 * sc, 0))
			_mesh(p, _sphere(0.55 * sc), _mat(cap_col, 0.55), o + Vector3(0, 0.55 * sc, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			var srng := RandomNumberGenerator.new()
			srng.seed = hash(id) + i
			for j in 6:
				var a := srng.randf() * TAU
				var r := srng.randf_range(0.12, 0.42) * sc
				var y := sqrt(maxf(0.0, 1.0 - pow(r / (0.55 * sc), 2.0))) * 0.55 * 0.55 * sc
				_mesh(p, _sphere(0.07 * sc, 12, 6), _mat(Color("efe2c8"), 0.7), o + Vector3(cos(a) * r, 0.55 * sc + y, sin(a) * r), Vector3.ZERO, Vector3(1, 0.4, 1))
	elif id == "heart_of_ash":
		_mesh(p, _sphere(0.55, 7, 5), _mat(Color("2a1a16"), 0.85), Vector3(0, 0.55, 0))
		_mesh(p, _sphere(0.36, 6, 4), _mat(Color("ff5a22"), 0.4, 0.0, 2.2), Vector3(0.12, 0.62, 0.32))
	elif "scale" in id:
		for i in 3:
			_mesh(p, _sphere(0.42, 6, 4), _mat(col.darkened(i * 0.12), 0.32, 0.3), Vector3(i * 0.3 - 0.3, 0.1 + i * 0.05, -i * 0.12), Vector3(-60, i * 25, 0), Vector3(1, 0.22, 1.25))
	elif id == "flower_crown":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.48
		ring.outer_radius = 0.6
		_mesh(p, ring, _mat(Color("4e7a34"), 0.75), Vector3.ZERO, Vector3(0, 0, 0))
		for i in 7:
			var a := TAU * i / 7.0
			var c: Color = [Color("f2d35a"), Color("e8e0d0"), Color("d87a5a")][i % 3]
			_mesh(p, _sphere(0.13), _mat(c, 0.55), Vector3(cos(a) * 0.54, 0.08, sin(a) * 0.54))
	elif "dust" in id or id == "pollen" or "clump" in id:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		var glow := 0.6 if id != "ash_clump" else 0.0
		_mesh(p, _cyl(0.55, 0.22, 0.62), _leather(Color("4a2c18")), Vector3(0, 0.0, 0))
		for i in 18:
			var a := rng.randf() * TAU
			var r := rng.randf() * 0.42
			_mesh(p, _sphere(rng.randf_range(0.08, 0.16), 12, 6), _mat(col.darkened(rng.randf() * 0.25), 0.7, 0.0, glow), Vector3(cos(a) * r, 0.16 + (0.45 - r) * 0.5 * rng.randf(), sin(a) * r))
	else:
		# Fibre, wool, bristle, fluff: a bound bundle.
		var fluffy := "wool" in id or "fluff" in id
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		if fluffy:
			for i in 9:
				_mesh(p, _sphere(rng.randf_range(0.22, 0.32), 16, 8), _mat(col.darkened(0.4 + rng.randf() * 0.15), 1.0), Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.15, 0.45), rng.randf_range(-0.2, 0.2)))
		else:
			for i in 14:
				_mesh(p, _cyl(0.035, 1.5, 0.012, 8), _mat(col.darkened(rng.randf() * 0.3), 0.8), Vector3(rng.randf_range(-0.14, 0.14), 0.3, rng.randf_range(-0.1, 0.1)), Vector3(rng.randf_range(-6, 6), 0, 90 + rng.randf_range(-14, 14)))
		var band := TorusMesh.new()
		band.inner_radius = 0.22 if not fluffy else 0.3
		band.outer_radius = 0.28 if not fluffy else 0.36
		_mesh(p, band, _leather(Color("8a5a30")), Vector3(0, 0.3, 0), Vector3(0, 0, 90))


func _gear(p: Node3D, id: String, col: Color) -> void:
	if "bell" in id:
		_mesh(p, _cyl(0.5, 0.75, 0.28), _gold(), Vector3(0, 0.38, 0))
		_mesh(p, _sphere(0.28), _gold(), Vector3(0, 0.78, 0))
		_mesh(p, _cyl(0.56, 0.08), _mat(Color("c8963c"), 0.3, 1.0), Vector3(0, 0.02, 0))
		var loop := TorusMesh.new()
		loop.inner_radius = 0.08
		loop.outer_radius = 0.13
		_mesh(p, loop, _iron(), Vector3(0, 1.08, 0), Vector3(90, 0, 0))
		_mesh(p, _sphere(0.11), _mat(col, 0.3, 0.0, 0.8 if "storm" in id else 0.0), Vector3(0, -0.06, 0))
	elif "charm" in id or "bead" in id:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.36
		ring.outer_radius = 0.48
		_mesh(p, ring, _gold(), Vector3(0, 0.5, 0), Vector3(90, 0, 0))
		_mesh(p, _sphere(0.34, 8, 6), _mat(col.darkened(0.3), 0.15, 0.1, 0.45), Vector3(0, 0.5, 0.02))
		_mesh(p, _cyl(0.035, 0.5), _iron(), Vector3(0, 1.12, 0))
	elif "shell" in id or "plate" in id or "coat" in id or "wrap" in id:
		var face := col.darkened(0.35) if "plate" not in id else Color("4a4440")
		_mesh(p, _sphere(0.62, 32, 16), _mat(face, 0.5, 0.4 if "plate" in id else 0.0), Vector3(0, 0.62, 0), Vector3(90, 0, 0), Vector3(0.95, 0.32, 1.12))
		var rim := TorusMesh.new()
		rim.inner_radius = 0.56
		rim.outer_radius = 0.66
		_mesh(p, rim, _gold() if "plate" not in id else _iron(), Vector3(0, 0.62, -0.02), Vector3(90, 0, 0), Vector3(0.95, 1.0, 1.12))
		_mesh(p, _sphere(0.14, 16, 8), _gold(), Vector3(0, 0.62, 0.2))
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			_mesh(p, _sphere(0.05, 12, 6), _gold(), Vector3(cos(a) * 0.52, 0.62 + sin(a) * 0.6, 0.12))
	elif "mallet" in id:
		_mesh(p, _cyl(0.06, 1.6), _leather(Color("5a3620")), Vector3(0, 0.3, 0), Vector3(0, 0, -28))
		_mesh(p, _box(0.5, 0.5, 0.8), _iron(), Vector3(0.38, 1.0, 0), Vector3(0, 90, -28))
		_mesh(p, _box(0.54, 0.12, 0.84), _mat(col, 0.4, 0.2, 0.6), Vector3(0.38, 1.0, 0), Vector3(0, 90, -28))
	elif "wand" in id:
		_mesh(p, _cyl(0.05, 1.5, 0.03), _leather(Color("6a4428")), Vector3(0, 0.35, 0), Vector3(0, 0, -25))
		_mesh(p, _sphere(0.18, 10, 6), _mat(col, 0.2, 0.0, 1.6), Vector3(0.34, 1.08, 0))
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.06
		hoop.outer_radius = 0.1
		_mesh(p, hoop, _gold(), Vector3(0.25, 0.88, 0), Vector3(0, 0, -25))
	elif "sling" in id:
		_mesh(p, _cyl(0.06, 0.8), _leather(Color("6a4428")), Vector3(0, 0.0, 0))
		_mesh(p, _cyl(0.05, 0.75), _leather(Color("6a4428")), Vector3(-0.22, 0.65, 0), Vector3(0, 0, 32))
		_mesh(p, _cyl(0.05, 0.75), _leather(Color("6a4428")), Vector3(0.22, 0.65, 0), Vector3(0, 0, -32))
		_mesh(p, _cyl(0.012, 0.9), _mat(Color("d8d0c0"), 0.8), Vector3(0, 0.98, 0.0), Vector3(0, 0, 90))
		_mesh(p, _sphere(0.14), _mat(col, 0.25, 0.0, 0.6), Vector3(0, 0.95, 0.12))
		var wrap := TorusMesh.new()
		wrap.inner_radius = 0.06
		wrap.outer_radius = 0.1
		_mesh(p, wrap, _gold(), Vector3(0, 0.3, 0))
	else:
		# Claw: three curved talons on a bound grip.
		_mesh(p, _cyl(0.16, 0.5), _leather(), Vector3(0, 0.0, 0), Vector3(0, 0, 0))
		for i in 3:
			var x := (i - 1) * 0.2
			_mesh(p, _cyl(0.09, 0.9, 0.0, 12), _mat(Color("e8dcc4"), 0.4), Vector3(x, 0.62, 0.04 * i), Vector3(0, 0, -14 + i * 14 + 18))
		_mesh(p, _cyl(0.2, 0.1), _gold(), Vector3(0, 0.25, 0))
