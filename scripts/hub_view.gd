class_name HubView
extends Control

## The camp seen behind the hub menu: a SubViewport with its own world, a
## camera on the fire, and the player's hero standing in it. The menu is
## drawn over the top of it, so the hub reads as a place the player is
## standing in rather than a list of buttons.
##
## The gates in the camp can be tapped: a tap on a lit standing stone walks
## the hero through it.

## Emitted when a gate in the camp is tapped: the depth tier's id.
signal gate_tapped(tier_id: String)

## Emitted when a place in the camp is tapped: the screen it opens.
signal place_tapped(place_id: String)

## The camp scene: the ground, the fire, the stalls and the rim of trees.
const CAMP := preload("res://scenes/hub_scene.tscn")

## How tall the hero stands in the camp, in metres. The hunt stage scales
## heroes to a taller, camera-far read; here the camera is close, so the
## hero keeps his own size.
const HERO_METERS := 1.9

## Where the camera stands and what it looks at. The look point is low and
## near, so the fire and the ground fill the frame and the sky is only a
## band above the treeline.
const CAM_POS := Vector3(0.0, 6.2, 8.8)
const CAM_LOOK := Vector3(0.0, 0.9, -1.4)

var viewport: SubViewport
var camera: Camera3D
var world_root: Node3D
var camp: HubScene
var _hero: Node3D
var _t := 0.0

## True while the player walks the hero around the town.
var walking := false
## Where the hero is walking to, in the town's ground plane (x, z). INF
## when he stands still.
var _walk_to := Vector2.INF
## The way the stick points, in the town's ground plane (x, z).
var _drive := Vector2.ZERO
## How fast the hero walks, in metres a second.
const WALK_SPEED := 5.6
## How far the hero may walk from the middle of the plaza: the town wall.
const PLAZA_RADIUS := 8.4
## How close the hero has to be for a door or a place to be the one under
## him.
const NEAR_RADIUS := 3.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.use_debanding = true
	viewport.size = Vector2i(720, 640)
	add_child(viewport)
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	camp = CAMP.instantiate() as HubScene
	world_root.add_child(camp)
	_lights()
	camera = Camera3D.new()
	# A wide lens: the town is 20 m across and the frame is a portrait one,
	# so a narrow lens would only ever show the middle of the plaza.
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 120.0
	camera.position = CAM_POS
	camera.current = true
	world_root.add_child(camera)
	_environment()
	camera.look_at(CAM_LOOK, Vector3.UP)
	_spawn_hero()


func _process(delta: float) -> void:
	# The viewport follows the control, so the camp is drawn at the size
	# it is shown at and never stretched.
	var density := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	var target := Vector2i(maxi(16, int(size.x * density)), maxi(16, int(size.y * density)))
	if viewport.size != target:
		viewport.size = target
	_t += delta
	if walking:
		_step_walk(delta)
		return
	# The camera drifts a little, so the camp breathes behind the menu.
	var drift := Vector3(sin(_t * 0.21) * 0.16, sin(_t * 0.17) * 0.05, 0.0)
	camera.position = CAM_POS + drift
	camera.look_at(CAM_LOOK + Vector3(drift.x * 0.3, 0.0, 0.0), Vector3.UP)


## The hero walks to where the player tapped, and stands still when he is
## there. The town is a place, so he keeps to the plaza and walks around
## what stands in it.
func _step_walk(delta: float) -> void:
	if _hero == null:
		return
	# The stick points the way: up on the screen is north, into the town.
	if _drive.length() > 0.05:
		_walk_to = Vector2.INF
		_walk_by(_drive, delta)
		_camera_follows()
		return
	if _walk_to == Vector2.INF:
		_play("idle")
		_camera_follows()
		return
	var here: Vector3 = _hero.position
	var flat := Vector2(here.x, here.z)
	var to := _walk_to - flat
	if to.length() < 0.3:
		_walk_to = Vector2.INF
		_play("idle")
		_camera_follows()
		return
	_walk_by(to.normalized(), delta)
	_camera_follows()


## Walks the hero a step in a direction, around what stands in the plaza.
func _walk_by(want: Vector2, delta: float) -> void:
	if _hero == null:
		return
	var here: Vector3 = _hero.position
	var flat := Vector2(here.x, here.z)
	var dir := _avoid(flat, want)
	flat += dir * WALK_SPEED * delta
	if flat.length() > PLAZA_RADIUS:
		flat = flat.normalized() * PLAZA_RADIUS
	here.x = flat.x
	here.z = flat.y
	here.y = 0.0
	_hero.position = here
	_hero.rotation.y = atan2(dir.x, dir.y)
	_play("walk")


## The camera follows the hero, a little behind and above him, so the town
## can be bigger than one screen.
func _camera_follows() -> void:
	if _hero == null:
		return
	var here: Vector3 = _hero.position
	var want := Vector3(here.x, CAM_POS.y, here.z + CAM_POS.z)
	camera.position = camera.position.lerp(want, 0.12)
	var look := Vector3(here.x, CAM_LOOK.y, here.z + CAM_LOOK.z)
	camera.look_at(look, Vector3.UP)


## The way the stick points, in the town's ground plane.
func set_drive(v: Vector2) -> void:
	_drive = v


## The direction to walk, with the things in the plaza pushed out of the
## way: the stalls, the well and the places.
func _avoid(here: Vector2, dir: Vector2) -> Vector2:
	var out := dir
	for o in _obstacles():
		var at := Vector2(o.x, o.z)
		var away := here - at
		var d := away.length()
		if d > 2.2 or d < 0.01:
			continue
		out += away / d * (1.0 - d / 2.2) * 1.4
	return out.normalized() if out.length() > 0.01 else dir


## The things in the plaza the hero walks around.
func _obstacles() -> Array:
	var out: Array = []
	if camp == null:
		return out
	for place in camp.list_places():
		var at: Vector3 = place["pos"]
		out.append(Vector3(at.x, 0.0, at.z))
	out.append(Vector3(-4.6, 0.0, -0.4))
	out.append(Vector3(4.6, 0.0, -0.4))
	out.append(Vector3(-2.6, 0.0, 2.0))
	return out


## Plays a clip on the hero, if the rig has it.
func _play(clip: String) -> void:
	if _hero == null or clip == _playing:
		return
	var player := _hero.find_children("*", "AnimationPlayer", true, false)
	if player.is_empty():
		return
	var ap: AnimationPlayer = player[0]
	if not ap.has_animation(clip):
		return
	ap.play(clip)
	_playing = clip


## The clip the hero is playing.
var _playing := ""


## Sends the hero to a spot in the town, in the town's ground plane.
func walk_to(at: Vector2) -> void:
	_walk_to = at


## Stops the hero where he is.
func stop() -> void:
	_walk_to = Vector2.INF


## Where the hero stands, in the town's ground plane (x, z).
func hero_pos() -> Vector2:
	if _hero == null:
		return Vector2.ZERO
	return Vector2(_hero.position.x, _hero.position.z)


## The ground under a tap, in the town's ground plane (x, z). INF when the
## tap missed the ground.
func ground_at(screen: Vector2) -> Vector2:
	if camera == null:
		return Vector2.INF
	var density := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	var vp := Vector2(screen.x * density, screen.y * density)
	var from := camera.project_ray_origin(vp)
	var dir := camera.project_ray_normal(vp)
	if absf(dir.y) < 0.001:
		return Vector2.INF
	var t := -from.y / dir.y
	if t <= 0.0:
		return Vector2.INF
	return Vector2(from.x + dir.x * t, from.z + dir.z * t)


## The door or the place the hero is standing at, or {} when he is
## between them.
func near() -> Dictionary:
	if _hero == null or camp == null:
		return {}
	var here := Vector2(_hero.position.x, _hero.position.z)
	var best: Dictionary = {}
	var best_d := NEAR_RADIUS
	for gate in camp.list_gate_markers():
		var at: Vector3 = gate["pos"]
		var d := here.distance_to(Vector2(at.x, at.z))
		if d < best_d:
			best_d = d
			best = {
				"kind": "gate", "id": str(gate.get("tier", "")),
				"name": str(gate.get("name", "")), "open": bool(gate.get("open", false)),
			}
	for place in camp.list_places():
		var at: Vector3 = place["pos"]
		var d := here.distance_to(Vector2(at.x, at.z))
		if d < best_d:
			best_d = d
			best = {"kind": "place", "id": str(place.get("id", "")), "name": str(place.get("name", ""))}
	return best


## The camp's light: a warm fire at the centre, a cool moon overhead and a
## dim fill so the far side of the camp keeps its shape.
func _lights() -> void:
	var fire := OmniLight3D.new()
	fire.light_color = Color("ffa54a")
	fire.light_energy = 14.0
	fire.omni_range = 22.0
	fire.omni_attenuation = 1.4
	fire.position = Vector3(0.0, 1.1, 0.0)
	fire.shadow_enabled = false
	world_root.add_child(fire)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("9fb6e8")
	moon.light_energy = 2.2
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-52.0, 128.0, 0.0)
	world_root.add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("ffd7a8")
	fill.light_energy = 1.1
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-18.0, -60.0, 0.0)
	world_root.add_child(fill)


## The camp's air: a night sky, cool fog and no bloom, so the fire is the
## only warm thing in the picture.
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	var tex := load("res://assets/textures/sky.hdr")
	if tex:
		panorama.panorama = tex
	sky.sky_material = panorama
	env.sky = sky
	env.background_energy_multiplier = 0.55
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.35
	env.ambient_light_color = Color("8fa4d8")
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.35
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.05
	env.glow_strength = 0.4
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.24, 0.28, 0.42)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.2
	var holder := WorldEnvironment.new()
	holder.name = "World"
	holder.environment = env
	world_root.add_child(holder)
	camera.environment = env


## The player's hero, standing by the fire in the camp. The class scene
## carries its own clip library, so the idle clip plays as it does in the
## hunt.
func _spawn_hero() -> void:
	var hero_id := SaveGame.featured_id()
	var path := Cast3D.model(hero_id)
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var hero := packed.instantiate() as Node3D
	if hero == null:
		return
	world_root.add_child(hero)
	# The hero wears what the player equipped: the armor, the shield and
	# the blade, hung on the rig's own bones.
	Gear3D.dress(hero, hero_id, Gear3D.tiers(hero_id))
	var box := _measure(hero)
	var h: float = maxf(box.size.y, 0.05)
	hero.scale = Vector3.ONE * (HERO_METERS / h)
	hero.position = Vector3(0.0, -box.position.y * (HERO_METERS / h), 1.7)
	hero.rotation.y = PI
	_hero = hero
	var player := hero.find_children("*", "AnimationPlayer", true, false)
	if player.size() > 0:
		var ap: AnimationPlayer = player[0]
		if ap.has_animation("idle"):
			ap.play("idle")
			ap.seek(0.0, true)


## Puts another hero in the camp: the one the player just chose. The old
## one steps out of the firelight.
func set_hero(hero_id: String) -> void:
	if _hero != null:
		_hero.queue_free()
		_hero = null
	_spawn_hero()


## The camp's gate under a tap, or "" when the tap missed every stone. The
## stones are three-dimensional, so the tap is matched against where each
## one stands on the screen.
func gate_at(tap: Vector2) -> String:
	if camp == null or camera == null:
		return ""
	var density := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	var best := ""
	var best_d := 70.0
	for gate in camp.list_gate_markers():
		var world: Vector3 = gate["pos"]
		if camera.is_position_behind(world):
			continue
		var on_screen := camera.unproject_position(world + Vector3(0.0, 1.4, 0.0))
		var d := Vector2(on_screen.x / density, on_screen.y / density).distance_to(tap)
		if d < best_d:
			best_d = d
			best = str(gate.get("tier", ""))
	return best


## The place of the town under a tap, or "" when the tap missed them all.
## The places are three-dimensional, so the tap is matched against where
## each one stands on the screen.
func place_at(tap: Vector2) -> String:
	if camp == null or camera == null:
		return ""
	var density := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	var best := ""
	var best_d := 70.0
	for place in camp.list_places():
		var world: Vector3 = place["pos"]
		if camera.is_position_behind(world):
			continue
		var on_screen := camera.unproject_position(world)
		var d := Vector2(on_screen.x / density, on_screen.y / density).distance_to(tap)
		if d < best_d:
			best_d = d
			best = str(place.get("id", ""))
	return best


## A tap on the camp: on a gate stone it walks the hero through it, and
## on a place it opens the screen that belongs to it.
func _gui_input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tap:
		return
	var at := Vector2.ZERO
	if event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	var tier_id := gate_at(at)
	if tier_id != "":
		accept_event()
		AudioDirector.sfx("ui_tap")
		AudioDirector.haptic("medium")
		gate_tapped.emit(tier_id)
		return
	var place_id := place_at(at)
	if place_id != "":
		accept_event()
		AudioDirector.sfx("ui_tap")
		AudioDirector.haptic("light")
		place_tapped.emit(place_id)
		return


## The hero's bounds, in his own space.
func _measure(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box
