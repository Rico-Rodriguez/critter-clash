class_name PortraitBaker
extends Node

## Renders every critter's 3D model to a transparent PNG, so cards, the
## collection log, and the hunt medallion show the same textured model the
## hunt does. Run once after a model changes:
##   godot --path . --rendering-driver vulkan -- --bake-portraits
## Writes assets/sprites/portraits/<id>.png (full body, 3/4 view) and
## <id>_head.png (head close-up for the hunt medallion).

const SIZE := 512
const OUT := "res://assets/sprites/portraits"

var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _stage: Stage3D
var _turn_override := 0.0


func run(only: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage = Stage3D.new()
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
	var ids: Array = only if not only.is_empty() else Catalog.CRITTERS.keys()
	for id in ids:
		await _bake(str(id), false)
		await _bake(str(id), true)
	_stage.free()


var _env: Environment
var _key: DirectionalLight3D


func _lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c8e0")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	_env = env
	var holder := WorldEnvironment.new()
	holder.environment = env
	_root.add_child(holder)
	var key := DirectionalLight3D.new()
	_key = key
	key.light_color = Color("fff0d8")
	key.light_energy = 1.9
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.shadow_enabled = true
	_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("a9c4ff")
	fill.light_energy = 0.7
	fill.rotation_degrees = Vector3(-10, -60, 0)
	_root.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("fff6e0")
	rim.light_energy = 2.2
	rim.rotation_degrees = Vector3(-20, 180, 0)
	_root.add_child(rim)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 22.0
	_root.add_child(_cam)


func _bake(id: String, head: bool) -> void:
	# The dragon's source albedo is one flat red, so its form has to come
	# from light: less flat ambient, a harder key, the rim does the rest.
	var dragon := Cast3D.model(id).ends_with("sketchfab/ember.glb")
	_env.ambient_light_energy = 0.38 if dragon else 0.75
	_env.adjustment_saturation = 0.95 if dragon else 1.12
	_key.light_energy = 2.6 if dragon else 1.9
	# A cooler key keeps the dragon's reds in wine rather than orange.
	_key.light_color = Color("f4ecf4") if dragon else Color("fff0d8")
	var body: Node3D
	if id.begins_with("prop:"):
		# Props sheet for art review: --only=prop:log,prop:stump
		body = Node3D.new()
		var packed := load("res://assets/models/%s.glb" % id.substr(5)) as PackedScene
		if packed:
			body.add_child(packed.instantiate())
		id = id.replace(":", "_").replace("/", "_")
	else:
		body = _stage._spawn_model(id, 1.0)
	_root.add_child(body)
	_stage._hide_catch(body)
	var face := float(body.get_meta("face", PI))
	# Nose toward the camera, turned a little for a 3/4 read.
	body.rotation.y = -face + (0.55 if head else Cast3D.portrait_turn(id)) + _turn_override
	var clips: Dictionary = body.get_meta("clips", {})
	# Full-body cards use the standing perch pose; the head crop keeps the
	# idle, where the head sits above the wings.
	_stage._play(body, "perch" if clips.has("perch") and not head else "idle")
	var player: AnimationPlayer = body.get_meta("player")
	if player != null and player.is_playing():
		player.seek(Cast3D.portrait_time(id), true)
		player.pause()
	await get_tree().process_frame
	# Orthographic, so a pixel box maps straight back to a camera window.
	# Pass one sees the whole critter from far out, pass two fills the frame.
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var dir := Vector3(0.0, 0.32, 1.0).normalized()
	var center := Vector3(0.0, 0.5, 0.0)
	var window := 4.0
	_aim(center, window, dir)
	var img := await _grab()
	var used := img.get_used_rect()
	if used.size.x < 2 or used.size.y < 2:
		push_warning("portrait %s is empty" % id)
		body.queue_free()
		return
	var pick := Rect2(used)
	var window_k := Cast3D.head_window(id)
	if head and window_k.size != Vector2.ZERO:
		pick = Rect2(Vector2(used.position) + Vector2(used.size) * window_k.position, Vector2(used.size) * window_k.size)
	elif head:
		var band := int(used.size.y * Cast3D.head_share(id))
		var top := img.get_region(Rect2i(used.position.x, used.position.y, used.size.x, maxi(band, 2)))
		var crown := top.get_used_rect()
		pick = Rect2(Vector2(used.position) + Vector2(crown.position), Vector2(crown.size))
	var side := maxf(pick.size.x, pick.size.y) * (1.08 if head else 1.1)
	var mid := pick.get_center()
	var px := window / float(SIZE)
	var right := _cam.global_transform.basis.x
	var up := _cam.global_transform.basis.y
	var shift := right * (mid.x - SIZE * 0.5) * px - up * (mid.y - SIZE * 0.5) * px
	_aim(center + shift, side * px, dir)
	img = await _grab()
	var name := "%s_head.png" % id if head else "%s.png" % id
	if _turn_override != 0.0:
		name = "turn%d_%s" % [int(_turn_override * 10), name]
	img.save_png(ProjectSettings.globalize_path("%s/%s" % [OUT, name]))
	print("portrait ", name)
	body.queue_free()
	await get_tree().process_frame


func _aim(look: Vector3, window: float, dir: Vector3) -> void:
	_cam.size = window
	_cam.position = look + dir * 20.0
	_cam.near = 0.05
	_cam.far = 60.0
	_cam.look_at(look, Vector3.UP)


func _grab() -> Image:
	for _i in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Mesh boxes in body space. Skinned meshes report their bind pose, which is
## what the paused first frame shows closely enough for framing.
func _visual_box(body: Node3D) -> AABB:
	var acc := {"ok": false, "box": AABB()}
	_walk(body, body.global_transform.affine_inverse(), acc)
	if not bool(acc["ok"]):
		return AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	return acc["box"]


func _walk(node: Node, inv: Transform3D, acc: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).visible and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		var xf := inv * mi.global_transform
		var local := mi.mesh.get_aabb()
		for i in 8:
			var p := xf * local.get_endpoint(i)
			if not bool(acc["ok"]):
				acc["box"] = AABB(p, Vector3.ZERO)
				acc["ok"] = true
			else:
				acc["box"] = (acc["box"] as AABB).expand(p)
	for child in node.get_children():
		_walk(child, inv, acc)
