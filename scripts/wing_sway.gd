class_name WingSway
extends SkeletonModifier3D

## Procedural idle for the home showcase: a slow breathing fold of the wings
## layered on top of whatever clip plays, so the dragon never stands stiff.
## Runs after the AnimationPlayer has posed the skeleton.

var t := 0.0
var _bones: Array = []  # [index, side, depth]


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		if not n.begins_with("wing") or n.contains("_end"):
			continue
		var side := 1.0 if n.contains(".l") else -1.0
		var depth := 0.0 if n.begins_with("wingbase") else (1.0 if n.begins_with("wingwrist") else 2.0)
		_bones.append([i, side, depth])


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	t += get_process_delta_time() if is_inside_tree() else 0.016
	# Slow breath (~4 s) with a lazier secondary ripple out to the tips.
	var breath := sin(t * 1.55)
	for b in _bones:
		var i: int = b[0]
		var side: float = b[1]
		var depth: float = b[2]
		var phase := breath * (0.09 - depth * 0.02) + sin(t * 1.55 - depth * 0.6) * 0.04 * depth
		var q := sk.get_bone_pose_rotation(i)
		var extra := Quaternion(Vector3(0, 0, 1), phase * side) * Quaternion(Vector3(1, 0, 0), phase * 0.6)
		sk.set_bone_pose_rotation(i, q * extra)
