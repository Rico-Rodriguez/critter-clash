class_name GearStage
extends RefCounted
## The studio light the equipment screen and the inspect view share: a warm
## key, a cool rim and a soft blue fill, on a transparent background. Also
## how one piece is put on show (inspect view, rendered item icons).

## Camera target and distance for a worn piece, by slot.
const FRAME := {
	"helm": [Vector3(0, 1.95, 0), 3.4], "chest": [Vector3(0, 1.25, 0), 4.6],
	"legs": [Vector3(0, 0.6, 0), 4.2], "trinket": [Vector3(0, 1.2, 0), 5.0],
}
## The same for a piece shown alone (icons), framed to fill a square.
const FRAME_ALONE := {
	"helm": [Vector3(0, 2.12, 0), 1.45], "chest": [Vector3(0, 1.28, 0), 2.2], "legs": [Vector3(0, 0.42, 0), 1.45],
}


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


## Puts one piece under `pivot` and aims `cam` at it: a weapon or offhand
## floats alone, a worn piece is shown on its hero wearing nothing else.
## `zoom` < 1 frames it tighter (square icons).
## `alone` shows a worn piece by itself, on an unseen body (item icons), so
## a chest piece reads as armor and not as a portrait of the hero.
static func show_piece(pivot: Node3D, cam: Camera3D, it: Dictionary, sparks := true, zoom := 1.0, alone := false) -> void:
	var model := str(GearDB.piece(it).get("model", ""))
	if model != "":
		_show_prop(pivot, cam, it, model, sparks, zoom)
	else:
		_show_worn(pivot, cam, it, zoom, alone)


## A weapon or offhand on its own, centered and framed by its size.
static func _show_prop(pivot: Node3D, cam: Camera3D, it: Dictionary, model: String, sparks: bool, zoom: float) -> void:
	var holder := Actor.new()
	pivot.add_child(holder)
	var prop := GearLook.prop_for(model)
	holder.add_child(prop)
	holder.restyle(prop)
	var lk := GearDB.look(it)
	for mi in KK.meshes(prop):
		mi.set_instance_shader_parameter("dye", lk["dye"])
		mi.set_instance_shader_parameter("tint", GearLook.glow_of(it, 1.2))
		mi.set_instance_shader_parameter("grade", GearDB.grade(it))
		mi.set_instance_shader_parameter("accent", GearDB.accent(it))
	var box := AABB()
	var first := true
	for mi in KK.meshes(prop):
		var b: AABB = prop.transform.inverse() * mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	prop.position = -box.get_center()
	var big := maxf(box.size.y, maxf(box.size.x, box.size.z))
	cam.look_at_from_position(Vector3(0, big * 0.12, (big * 2.6 + 0.6) * zoom), Vector3.ZERO, Vector3.UP)
	var spark := GearDB.enchant(it)
	if sparks and spark.a > 0.0:
		var p := GearLook.emitter(48, 1.2, 0.07 * maxf(big, 1.0))
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box.size * 0.45
		pm.gravity = Vector3(0, 0.5, 0)
		pm.initial_velocity_max = 0.3
		pm.spread = 180.0
		pm.color = Color(spark.r, spark.g, spark.b)
		p.local_coords = true
		pivot.add_child(p)


## A worn piece on the hero, everything else bare.
static func _show_worn(pivot: Node3D, cam: Camera3D, it: Dictionary, zoom: float, alone := false) -> void:
	var cls := str(it["cls"])
	var a := Actor.new()
	pivot.add_child(a)
	a.adult_build = true
	a.build_model(DB.HEROES[cls]["model"], {}, Color(0.55, 0.68, 1.0), 0.5)
	var pre := {}
	for slot in DB.SLOTS:
		pre[slot] = {}
	pre[it["slot"]] = it
	GearLook.apply(a, cls, pre)
	if alone:
		var reg: Dictionary = a.get_meta("gl_parts", {})
		var keep := []
		for spec: String in GearDB.expand(GearDB.look(it)["parts"]):
			if reg.has(spec) and is_instance_valid(reg[spec]):
				keep.append(reg[spec])
		for mi in a.model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visible = mi in keep
	a.play(GearDB.anims(cls, Game.weapon_family(cls, {"weapon": it} if it["slot"] == "weapon" else {}))["idle"], 0.0)
	if alone and FRAME_ALONE.has(str(it["slot"])):
		var fa: Array = FRAME_ALONE[str(it["slot"])]
		var aim: Vector3 = fa[0]
		cam.look_at_from_position(aim + Vector3(0, 0.25, float(fa[1])), aim, Vector3.UP)
		return
	var fr: Array = FRAME.get(str(it["slot"]), FRAME["chest"])
	var at: Vector3 = fr[0]
	cam.look_at_from_position(at + Vector3(0, 0.15 * zoom, float(fr[1]) * zoom), at, Vector3.UP)
