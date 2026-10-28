extends Node
## Not a class_name (see item_icons.gd). Chests and eggs rendered once per
## kind, off screen and one per frame, then cached for the session. Until the
## render is ready (and on headless runs) the flat icon stands in.

const DUNGEON := "res://assets/kaykit/dungeon/"
const SKDB := preload("res://src/data/sidekick_db.gd")
const SIZE := 256

static var _cache := {}
static var _inst: Node

var _vp: SubViewport
var _queue: Array = []
var _waiting := {}
var _busy := false


static func chest(kind: String, size_: float) -> TextureRect:
	return _rect("chest|" + kind, size_, "locked-chest", DB.CHESTS[kind]["color"])


static func egg(kind: String, size_: float) -> TextureRect:
	return _rect("egg|" + kind, size_, "egg-clutch", Color(SKDB.EGGS[kind]["color"]))


static func _rect(k: String, size_: float, flat: String, flat_tint: Color) -> TextureRect:
	var t := Ui.icon_rect(flat, size_, flat_tint)
	if DisplayServer.get_name() == "headless":
		return t
	if _cache.has(k):
		_show(t, _cache[k])
		return t
	_instance().request(k, t)
	return t


static func _show(t: TextureRect, tex: Texture2D) -> void:
	t.texture = tex
	t.modulate = Color.WHITE
	t.self_modulate = Color.WHITE


static func _instance():
	if _inst == null or not is_instance_valid(_inst):
		_inst = load("res://src/ui/prop_icons.gd").new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


func request(k: String, t: TextureRect) -> void:
	if not _waiting.has(k):
		_waiting[k] = []
		_queue.append(k)
	_waiting[k].append(weakref(t))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)


## Trims the empty margin to a padded square, so a tiny skeleton and a wide
## dragon both fill their tile.
static func _crop(img: Image) -> Image:
	var r := img.get_used_rect()
	if r.size.x < 4 or r.size.y < 4:
		return img
	var side := int(maxi(r.size.x, r.size.y) * 1.08) + 2
	var c := r.get_center()
	var x := clampi(c.x - side / 2, 0, maxi(img.get_width() - side, 0))
	var y := clampi(c.y - side / 2, 0, maxi(img.get_height() - side, 0))
	var out := img.get_region(Rect2i(x, y, mini(side, img.get_width() - x), mini(side, img.get_height() - y)))
	return out


## An egg built in code: a tall oval in the egg's colour, darker speckles and a
## faint glow of its own colour.
static func _egg_mesh(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	body.mesh = sm
	body.scale = Vector3(0.82, 1.15, 0.82)
	body.position.y = 0.58
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.lerp(Color.WHITE, 0.18)
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.25
	body.material_override = mat
	root.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(col.to_html())
	var spot := StandardMaterial3D.new()
	spot.albedo_color = col.darkened(0.45)
	spot.roughness = 0.6
	for i in 9:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.9), rng.randf_range(0.1, 1)).normalized()
		var d := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = rng.randf_range(0.04, 0.085)
		ds.height = ds.radius * 2.0
		d.mesh = ds
		d.scale = Vector3(1, 1, 0.5)
		d.position = body.position + Vector3(dir.x * 0.5 * 0.82, dir.y * 0.5 * 1.15, dir.z * 0.5 * 0.82)
		d.look_at_from_position(d.position, d.position + dir, Vector3.UP)
		d.material_override = spot
		root.add_child(d)
	return root


func _process(_dt: float) -> void:
	if not _busy and not _queue.is_empty():
		_render(_queue.pop_front())


func _render(k: String) -> void:
	_busy = true
	Ui.clear(_vp)
	GearStage.light(_vp, false)
	var kind := k.get_slice("|", 1)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	if k.begins_with("chest|"):
		var c: Dictionary = DB.CHESTS[kind]
		var m := KK.prop(DUNGEON + str(c["model"]) + ".gltf")
		m.rotation.y = -0.55
		_vp.add_child(m)
		var glow := OmniLight3D.new()
		glow.light_color = c["color"]
		glow.light_energy = 1.8
		glow.omni_range = 4.0
		glow.position = Vector3(0, 1.2, 1.2)
		_vp.add_child(glow)
		cam.look_at_from_position(Vector3(0, 1.5, 3.4), Vector3(0, 0.45, 0), Vector3.UP)
	else:
		var col: Color = SKDB.EGGS[kind]["color"]
		_vp.add_child(_egg_mesh(col))
		var glow := OmniLight3D.new()
		glow.light_color = col.lerp(Color.WHITE, 0.3)
		glow.light_energy = 1.2
		glow.omni_range = 4.0
		glow.position = Vector3(0.8, 1.0, 1.6)
		_vp.add_child(glow)
		cam.look_at_from_position(Vector3(0, 0.75, 3.0), Vector3(0, 0.55, 0), Vector3.UP)
	# One frame for the pose to apply, one for the draw.
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img != null and not img.is_empty():
		var tex := ImageTexture.create_from_image(_crop(img))
		_cache[k] = tex
		for w in _waiting.get(k, []):
			var t = w.get_ref()
			if t != null:
				_show(t, tex)
	_waiting.erase(k)
	Ui.clear(_vp)
	_busy = false
