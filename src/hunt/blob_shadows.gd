extends MultiMeshInstance3D
## One draw call of contact shadows for every minion. Real shadow casting cost
## a draw per mesh per frame (about a third of a busy hunt); minions now skip
## it and stand on a crisp dark disc instead, the way Supercell games do.
## No class_name: content packs cannot add global classes (see tests.gd).

const MAX := 64


func _init() -> void:
	var g := Gradient.new()
	# A hard-edged disc with a short falloff: reads as a shadow, never a smear.
	g.offsets = PackedFloat32Array([0.0, 0.62, 0.8])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.36), Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = -1
	var quad := PlaneMesh.new()
	quad.size = Vector2(2, 2)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Follows the foes anywhere in the arena: skip per-frame AABB culling.
	custom_aabb = AABB(Vector3(-500, -5, -500), Vector3(1000, 10, 1000))


func update(foes: Array) -> void:
	var n := 0
	for f in foes:
		if n >= MAX:
			break
		if not is_instance_valid(f) or not f.alive or not f.visible:
			continue
		var r: float = f.radius * 1.25 * f.scale.x
		var p: Vector3 = f.global_position
		multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(r, 1, r)), Vector3(p.x, 0.04, p.z)))
		n += 1
	multimesh.visible_instance_count = n
