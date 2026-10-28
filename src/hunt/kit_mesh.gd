extends RefCounted
## Places the zone kits' meshes (KitModels, built in Blender): one MultiMesh node, one draw call,
## per mesh. Pass a null material to keep the mesh's own. Preloaded by path, no class_name.
## Crisp PBR: no tint or fog.


## One MultiMesh node (one draw) of `xfs` copies of `mesh`.
static func batch(parent: Node3D, mesh: Mesh, material: Material, xfs: Array, shadow := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi
