class_name GearStage
extends RefCounted
## The studio light the equipment screen and the inspect view share: a warm
## key, a cool rim and a soft blue fill, on a transparent background.


static func light(vp: SubViewport, with_floor := true) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.7)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, 40, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 1.0
	rim.rotation_degrees = Vector3(-20, -150, 0)
	vp.add_child(rim)
	if not with_floor:
		return
	var floor_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.1
	cyl.height = 0.08
	floor_m.mesh = cyl
	floor_m.position = Vector3(0, -0.04, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.1, 0.1)
	fm.roughness = 0.9
	floor_m.material_override = fm
	vp.add_child(floor_m)
