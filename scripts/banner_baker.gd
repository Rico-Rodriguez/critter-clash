class_name BannerBaker
extends Node

## Renders each biome's map banner from the real hunt scene: the biome's
## ground, foliage, and props with its boss standing in the clearing, shot
## low and cinematic. Run after the hunt look changes:
##   godot --path . -- --bake-banners
## Writes assets/sprites/arenas/<biome>_banner.png (1080x480).

const SIZE := Vector2i(1080, 480)
const OUT := "res://assets/sprites/arenas"


func run() -> void:
	for entry in Catalog.BIOMES:
		await _bake(entry)


func _bake(entry: Dictionary) -> void:
	var id := str(entry["id"])
	var stage := Stage3D.new()
	stage.fixed_px = SIZE
	stage.size = Vector2(SIZE)
	add_child(stage)
	stage.viewport.msaa_3d = Viewport.MSAA_8X
	stage.bind_hunt(id)
	var look := stage._to3(Vector2(360, 640))
	var boss := stage._spawn_model(str(entry["boss"]), Stage3D.BOSS_METERS * 0.58)
	boss.position = look + Vector3(1.2, 0, -1.0)
	boss.rotation.y = -float(boss.get_meta("face", PI)) + 0.5
	stage.world_root.add_child(boss)
	stage._outline(boss, Color("2a0c08"), 0.008)
	stage._play(boss, "idle")
	# A few of the biome's critters around the boss for scale and life.
	var skins: Array = entry.get("skins", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in mini(3, skins.size()):
		var m := stage._spawn_model(str(skins[i]), Stage3D.HERO_METERS * 0.55)
		m.position = look + Vector3(-2.6 + i * 1.3, 0, 0.6 + rng.randf() * 0.8)
		m.rotation.y = -float(m.get_meta("face", PI)) + rng.randf_range(-0.6, 0.6)
		stage.world_root.add_child(m)
		stage._play(m, "idle")
	# Low three-quarter shot across the clearing toward the boss.
	stage._mode = "banner"
	stage.camera.fov = 34.0
	stage.camera.position = look + Vector3(-1.2, 3.2, 10.5)
	stage.camera.look_at(look + Vector3(0.4, 2.0, -1.0), Vector3.UP)
	# Thicker air for the banner so the field edge melts into the sky.
	var holder := stage.world_root.get_node_or_null("World") as WorldEnvironment
	if holder != null:
		holder.environment.fog_density *= 4.0
		holder.environment.fog_sky_affect = 0.85
		holder.environment.adjustment_enabled = true
		holder.environment.adjustment_contrast = 1.12
		holder.environment.glow_enabled = true
		holder.environment.glow_intensity = 0.3
	# Cinematic grade: a low sun raking across the clearing from behind the
	# boss (rim light on every silhouette), and the far field softly defocused.
	stage.sun.rotation_degrees = Vector3(-16, 160, 0)
	stage.sun.light_energy *= 1.25
	stage.sun.shadow_enabled = true
	if id == "meadow":
		stage.sun.light_color = Color("ffb26a")
		if holder != null:
			var env := holder.environment
			env.fog_light_color = Color(0.86, 0.62, 0.42)
			env.ambient_light_color = Color("b8a07e")
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_energy = 0.85
			env.fog_sky_affect = 0.4
			env.background_energy_multiplier = 0.55
			env.adjustment_saturation = 1.05
			env.tonemap_exposure = 0.95
	# Front fill from over the camera so faces are not lost against the sun.
	stage._lamp(Color("ffe2c0"), 3.0, stage.camera.position + Vector3(0.0, 1.0, -4.0), false, 14.0)
	var cam_fx := CameraAttributesPractical.new()
	cam_fx.dof_blur_far_enabled = true
	cam_fx.dof_blur_far_distance = 17.0
	cam_fx.dof_blur_far_transition = 12.0
	cam_fx.dof_blur_amount = 0.06
	stage.camera.attributes = cam_fx
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := stage.viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path("%s/%s_banner.png" % [OUT, id]))
	print("BANNER ", id)
	stage.queue_free()
	await get_tree().process_frame
