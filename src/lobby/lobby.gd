extends Node3D
## The camp: your hero by the fire at the edge of the Barrow. Pick a hero,
## pick a difficulty, open what you brought home, and go back in.

const G := "res://assets/kaykit/graveyard/"
const D := "res://assets/kaykit/dungeon/"
const F := "res://assets/kaykit/forest/"

var main: Node
var ui: LobbyUI
var cam: Camera3D
var hero: Actor
var pet: Actor
var chest: Node3D
var chest_lid: Node3D
var fire_light: OmniLight3D
var _drag := -1
var _drag_x := 0.0
var _spin := 0.0
var _t := 0.0
const CAM_BASE := Vector3(0.0, 2.0, 5.6)
const CAM_LOOK := Vector3(0.0, 0.05, -0.4)
## 0..1 push-in toward the hero, tweened on a hero change.
var push := 0.0
var _push_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	_build_world()
	ui = preload("res://src/lobby/lobby_ui.tscn").instantiate()
	add_child(ui)
	ui.setup(self)
	show_hero(Game.hero_id(), false)
	if str(Game.data.get("pet", "")) != "":
		_spawn_pet()
	Sfx.music("home")
	if main and str(main.pending_chest) != "":
		place_chest(main.pending_chest)


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.03, 0.08)
	sm.sky_horizon_color = Color(0.12, 0.12, 0.22)
	sm.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sm.ground_horizon_color = Color(0.12, 0.12, 0.22)
	sm.sun_angle_max = 1.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.36, 0.56)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.1, 0.16)
	env.fog_density = 0.03
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.7
	moon.rotation_degrees = Vector3(-35, 150, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	add_child(moon)
	# Ground.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Arena.GROUND_SHADER
	var arena_noise := Arena.new()
	gm.set_shader_parameter("noise_a", arena_noise._noise(256, 0.012, 1))
	gm.set_shader_parameter("noise_b", arena_noise._noise(256, 0.05, 2))
	arena_noise.free()
	gm.set_shader_parameter("bounds", Vector4(-9, -14, 9, 8))
	gm.set_shader_parameter("edge_fade", 9.0)
	ground.material_override = gm
	add_child(ground)
	# The hero's stand: an old flagstone.
	_put(G + "floor_dirt.gltf", Vector3(0, -0.02, 0), 0.0, 1.8)
	# Campfire to the hero's left: ring of stones, embers, flame and light.
	var fire_at := Vector3(-1.75, 0, -0.2)
	for i in 7:
		var a := TAU * i / 7.0
		_put(F + "Rock_1_%s_Color1.gltf" % "ABCDEFG"[i], fire_at + Vector3(sin(a), 0, cos(a)) * 0.55, a, 0.45)
	_fire(fire_at)
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.25)
	fire_light.light_energy = 2.6
	fire_light.omni_range = 9.0
	fire_light.position = fire_at + Vector3(0, 0.9, 0)
	fire_light.shadow_enabled = true
	add_child(fire_light)
	# Key light on the hero from the front-right (a lantern on a post).
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.78, 0.55)
	key.light_energy = 1.5
	key.omni_range = 7.0
	key.position = Vector3(1.6, 2.4, 2.4)
	add_child(key)
	_put(G + "post_lantern.gltf", Vector3(2.6, 0, -1.2), -0.6, 1.0)
	# Camp dressing at the edges of the frame.
	_put(D + "barrel_large.gltf", Vector3(3.3, 0, -2.6), 0.3, 0.9)
	_put(D + "crates_stacked.gltf", Vector3(4.3, 0, -3.8), -0.4, 0.9)
	_put(D + "keg_decorated.gltf", Vector3(-4.4, 0, -4.4), 0.8, 0.9)
	_put(D + "sword_shield.gltf", Vector3(2.2, 0, -3.4), -0.3, 1.0)
	_put(G + "bench.gltf", Vector3(-3.4, 0, 0.2), 1.2, 0.9)
	# The Barrow behind: graves, dead trees, the crypt in the mist.
	_put(G + "crypt.gltf", Vector3(3.5, 0, -17.0), -0.3, 2.2)
	var cl := OmniLight3D.new()
	cl.light_color = Color(0.35, 1.0, 0.75)
	cl.light_energy = 2.0
	cl.omni_range = 8.0
	cl.position = Vector3(3.2, 2.5, -13.5)
	add_child(cl)
	for i in 14:
		var p := Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-12, -4.5))
		if absf(p.x) < 1.5 and p.z > -6:
			continue
		var stone: String = ["gravestone.gltf", "grave_A.gltf", "grave_B.gltf", "gravemarker_A.gltf", "gravemarker_B.gltf"][_rng.randi() % 5]
		_put(G + stone, p, _rng.randf_range(-0.3, 0.3), _rng.randf_range(1.1, 1.4))
	for tp in [Vector3(-5.5, 0, -6.5), Vector3(5.5, 0, -8), Vector3(-7, 0, -12), Vector3(8, 0, -13)]:
		_put(G + ["tree_dead_large.gltf", "tree_dead_medium.gltf", "tree_dead_large_decorated.gltf"][_rng.randi() % 3], tp, _rng.randf() * TAU, 1.6)
	for i in 18:
		var p2 := Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-22, -14))
		_put(G + ["tree_pine_orange_large.gltf", "tree_pine_yellow_large.gltf", "tree_pine_orange_medium.gltf"][_rng.randi() % 3], p2, _rng.randf() * TAU, _rng.randf_range(1.8, 2.6))
	_put(G + "fence.gltf", Vector3(-4.6, 0, -4.2), 0.2, 1.3)
	_put(G + "fence_broken.gltf", Vector3(-6.6, 0, -4.6), 0.2, 1.3)
	_put(G + "fence.gltf", Vector3(5.0, 0, -5.0), -0.15, 1.3)
	_put(G + "skull_candle.gltf", Vector3(-2.9, 0, -1.6), 0.4, 0.9)
	# A big pale moon over the crypt.
	var moon_disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(9, 9)
	moon_disc.mesh = q
	var mm := ShaderMaterial.new()
	mm.shader = Fx.SOFT
	mm.set_shader_parameter("intensity", 1.6)
	mm.set_shader_parameter("hardness", 0.9)
	moon_disc.material_override = mm
	moon_disc.position = Vector3(-6.0, 9.0, -40.0)
	add_child(moon_disc)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 46.0
	add_child(cam)
	cam.look_at_from_position(CAM_BASE, CAM_LOOK, Vector3.UP)
	cam.current = true


func _put(path: String, pos: Vector3, yaw: float, sc: float) -> Node3D:
	var n := KK.prop(path)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * sc
	add_child(n)
	return n


func _fire(at: Vector3) -> void:
	for spec in [[Color(1.0, 0.55, 0.15), 0.5, 1.6, 26, 0.55], [Color(1.0, 0.85, 0.4), 0.35, 1.1, 18, 0.35]]:
		var p := GPUParticles3D.new()
		p.amount = spec[3]
		p.lifetime = 0.9
		p.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = spec[4] * 0.5
		pm.direction = Vector3.UP
		pm.spread = 12.0
		pm.initial_velocity_min = spec[2] * 0.6
		pm.initial_velocity_max = spec[2]
		pm.gravity = Vector3(0, 0.6, 0)
		pm.color = spec[0]
		var sc := Curve.new()
		sc.add_point(Vector2(0, 1))
		sc.add_point(Vector2(1, 0.1))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 0.3, 0.1, 0))
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		pm.color_ramp = rt
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(spec[1], spec[1])
		var m := ShaderMaterial.new()
		m.shader = Fx.SOFT
		m.set_shader_parameter("intensity", 3.0)
		q.material = m
		p.draw_pass_1 = q
		p.position = at + Vector3(0, 0.15, 0)
		add_child(p)
	var sparks := GPUParticles3D.new()
	sparks.amount = 14
	sparks.lifetime = 2.2
	sparks.local_coords = false
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3.UP
	sm.spread = 25.0
	sm.initial_velocity_min = 0.8
	sm.initial_velocity_max = 1.8
	sm.gravity = Vector3(0, 0.2, 0)
	sm.turbulence_enabled = true
	sm.turbulence_noise_strength = 0.5
	sm.color = Color(1.0, 0.6, 0.25)
	sparks.process_material = sm
	var sq := QuadMesh.new()
	sq.size = Vector2(0.06, 0.06)
	var smat := ShaderMaterial.new()
	smat.shader = Fx.SOFT
	smat.set_shader_parameter("intensity", 4.0)
	sq.material = smat
	sparks.draw_pass_1 = sq
	sparks.position = at + Vector3(0, 0.4, 0)
	add_child(sparks)


func show_hero(id: String, cheer := true) -> void:
	if hero:
		hero.queue_free()
	var d: Dictionary = DB.HEROES[id]
	hero = Actor.new()
	add_child(hero)
	hero.build_model(d["model"], d["weapons"], Color(0.55, 0.68, 1.0), 0.45)
	GearLook.apply(hero, id)
	hero.rotation.y = 0.3 + _spin
	if cheer and cam:
		if _push_tween:
			_push_tween.kill()
		_push_tween = create_tween()
		_push_tween.tween_property(self, "push", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_push_tween.tween_property(self, "push", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if cheer and Game.hero(id)["unlocked"]:
		hero.play("Cheering", 0.0)
		hero.anim.queue(d["anim"]["idle"])
		hero.cur_anim = ""
	else:
		hero.play(d["anim"]["idle"], 0.0)


## Re-dresses the camp hero after a gear change, with a short white flash.
func refresh_gear() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	GearLook.apply(hero, Game.hero_id())
	var t := create_tween()
	t.tween_method(hero.set_flash, 0.9, 0.0, 0.3)


func place_chest(kind: String) -> void:
	if chest:
		chest.queue_free()
	var c: Dictionary = DB.CHESTS[kind]
	chest = KK.prop(D + c["model"] + ".gltf")
	chest.position = Vector3(1.25, 0, 0.9)
	chest.rotation.y = -0.5
	chest.scale = Vector3.ONE * 0.85
	add_child(chest)
	chest_lid = chest.find_child("*lid*", true, false)
	var glow := OmniLight3D.new()
	glow.light_color = c["color"]
	glow.light_energy = 1.5
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.8, 0.3)
	chest.add_child(glow)
	ui.show_chest(kind)
	Sfx.play("chest_land", 0.0)


func open_chest_fx() -> void:
	# Bring the chest to center stage, in front of the hero.
	var mv := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	mv.tween_property(chest, "position", Vector3(0.0, 0.0, 1.7), 0.35)
	mv.tween_property(chest, "rotation:y", 0.0, 0.35)
	mv.tween_property(chest, "scale", Vector3.ONE * 1.05, 0.35)
	await mv.finished
	if chest_lid:
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(chest_lid, "rotation:x", -1.9, 0.45)
	var col: Color = DB.CHESTS.get(main.pending_chest if main else "silver", DB.CHESTS["silver"])["color"]
	var burst := OmniLight3D.new()
	burst.light_color = col
	burst.light_energy = 8.0
	burst.omni_range = 7.0
	burst.position = chest.position + Vector3(0, 1.2, 0)
	add_child(burst)
	var t2 := create_tween()
	t2.tween_property(burst, "light_energy", 1.5, 1.2)


func remove_chest() -> void:
	if chest:
		var c := chest
		chest = null
		var t := create_tween()
		t.tween_property(c, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(c.queue_free)
	if main:
		main.pending_chest = ""


func _spawn_pet() -> void:
	pet = Actor.new()
	add_child(pet)
	pet.build_model("Skeleton_Minion", {}, Color(0.5, 0.7, 1.0), 0.4, Color(1.0, 0.6, 0.2, 1.0))
	pet.model.scale = Vector3.ONE * 0.42
	pet.position = Vector3(-0.85, 0, 0.6)
	pet.rotation.y = 0.5
	pet.play("Skeletons_Idle")


func open_sheet(name_: String) -> void:
	ui.open_sheet(name_)


func start_hunt() -> void:
	if main:
		main.go("hunt")


func _process(dt: float) -> void:
	_t += dt
	if cam:
		# A slow sideways drift keeps the camp alive; the push-in sells a swap.
		var drift := sin(_t * TAU / 12.0) * 0.15
		var pos := CAM_BASE + Vector3(drift, 0, 0) + (CAM_LOOK - CAM_BASE).normalized() * 0.4 * push
		cam.look_at_from_position(pos, CAM_LOOK, Vector3.UP)
	if fire_light:
		fire_light.light_energy = 2.6 * (1.0 + 0.14 * sin(_t * 11.0) + 0.08 * sin(_t * 27.0))
	if hero and _drag < 0:
		_spin = lerpf(_spin, 0.0, 1.0 - exp(-1.5 * dt))
	if hero:
		hero.rotation.y = 0.3 + _spin
	if chest and not ui.chest_opening:
		chest.position.y = 0.04 + 0.04 * sin(_t * 3.0)


func _unhandled_input(e: InputEvent) -> void:
	# Drag on the open 3D area to turn the hero.
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _drag < 0 and t.position.y < get_viewport().get_visible_rect().size.y * 0.55:
			_drag = t.index
			_drag_x = t.position.x
		elif not t.pressed and t.index == _drag:
			_drag = -1
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _drag:
			_spin += (d.position.x - _drag_x) * 0.012
			_drag_x = d.position.x
