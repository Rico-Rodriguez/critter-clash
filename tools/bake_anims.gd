extends SceneTree
## Bakes every Rig_Medium clip from the KayKit animation files into one
## AnimationLibrary resource, with loop flags set on the cycles.
## godot --headless --path . -s res://tools/bake_anims.gd

const FILES := ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "CombatRanged", "Special", "Simulation"]
const LOOPING := [
	"Idle_A", "Idle_B", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C",
	"Melee_2H_Idle", "Melee_Unarmed_Idle", "Melee_Blocking", "Ranged_Bow_Idle", "Ranged_Bow_Aiming_Idle",
	"Ranged_Magic_Spellcasting", "Ranged_1H_Aiming", "Ranged_2H_Aiming", "Running_HoldingBow",
	"Running_Strafe_Left", "Running_Strafe_Right", "Walking_Backwards", "Skeletons_Idle",
	"Skeletons_Walking", "Skeletons_Inactive_Floor_Pose", "Skeletons_Inactive_Standing_Pose",
	"Melee_2H_Attack_Spinning",
]


func _init() -> void:
	var out := AnimationLibrary.new()
	for f in FILES:
		var ps: PackedScene = load("res://assets/kaykit/animations/Rig_Medium_%s.glb" % f)
		var inst := ps.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		for lib_name in ap.get_animation_library_list():
			var l := ap.get_animation_library(lib_name)
			for a in l.get_animation_list():
				if a == "T-Pose" or out.has_animation(a):
					continue
				var anim: Animation = l.get_animation(a).duplicate(true)
				anim.loop_mode = Animation.LOOP_LINEAR if a in LOOPING else Animation.LOOP_NONE
				out.add_animation(a, anim)
		inst.free()
	var names := out.get_animation_list()
	print("baked ", names.size(), " clips; sample track: ", out.get_animation(names[0]).track_get_path(0))
	var err := ResourceSaver.save(out, "res://assets/kaykit/animations/rig_medium_lib.res")
	print("save: ", error_string(err))
	quit(0 if err == OK else 1)
