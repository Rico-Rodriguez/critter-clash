class_name BoneScaler
extends SkeletonModifier3D
## Rescales bones after the animation has been applied, so the proportions
## hold through every clip. Used to give the KayKit characters smaller heads
## and broader chests (a grittier, more adult build). Add as a child of the
## Skeleton3D.

## Bone name -> scale vector.
var scales := {}
## Raises the hips by this much after the clip, so longer legs (a scaled
## upper leg stretches everything below it) still stand on the ground.
var lift := 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for bone_name: String in scales:
		var i := sk.find_bone(bone_name)
		if i >= 0:
			sk.set_bone_pose_scale(i, scales[bone_name])
	if lift != 0.0:
		var h := sk.find_bone("hips")
		if h >= 0:
			sk.set_bone_pose_position(h, sk.get_bone_pose_position(h) + Vector3(0, lift, 0))
