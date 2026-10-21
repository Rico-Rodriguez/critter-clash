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

## The camp scene: the ground, the fire, the stalls and the rim of trees.
const CAMP := preload("res://scenes/hub_scene.tscn")

## How tall the hero stands in the camp, in metres. The hunt stage scales
## heroes to a taller, camera-far read; here the camera is close, so the
## hero keeps his own size.
const HERO_METERS := 1.9

## Where the camera stands and what it looks at. The look point is low and
## near, so the fire and the ground fill the frame and the sky is only a
## band above the treeline.
const CAM_POS := Vector3(0.0, 3.15, 7.6)
const CAM_LOOK := Vector3(0.0, 0.35, -0.4)

var viewport: SubViewport
var camera: Camera3D
var world_root: Node3D
var camp: HubScene
var _hero: Node3D
var _t := 0.0


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
	camera.fov = 46.0
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
	# The camera drifts a little, so the camp breathes behind the menu.
	_t += delta
	var drift := Vector3(sin(_t * 0.21) * 0.16, sin(_t * 0.17) * 0.05, 0.0)
	camera.position = CAM_POS + drift
	camera.look_at(CAM_LOOK + Vector3(drift.x * 0.3, 0.0, 0.0), Vector3.UP)


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
		if not bool(gate.get("open", false)):
			continue
		var world: Vector3 = gate["pos"]
		if camera.is_position_behind(world):
			continue
		var on_screen := camera.unproject_position(world + Vector3(0.0, 1.4, 0.0))
		var d := Vector2(on_screen.x / density, on_screen.y / density).distance_to(tap)
		if d < best_d:
			best_d = d
			best = str(gate.get("tier", ""))
	return best


## A tap on the camp: on a gate stone it walks the hero through it.
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
	if tier_id == "":
		return
	accept_event()
	AudioDirector.sfx("ui_tap")
	AudioDirector.haptic("medium")
	gate_tapped.emit(tier_id)


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
