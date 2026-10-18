extends SceneTree
## Boss clip library: the model's own clips under canonical names plus the
## death/hit clips retargeted from KayKit (tools/retarget.gd output).
##   godot --headless --path . -s res://tools/boss_bake.gd -- <model.glb> <retarget.res> <out.res> '<{"idle":"Native clip",...}>'
## The scene next to the model (e.g. troll.tscn) points its AnimationPlayer at <out.res>.
## <model.glb> must still hold its clips: the shipped troll.glb was stripped
## (tools/glb_strip.py), so bake from the original Sketchfab download.
## Gravemaw:
##   USE_REST=1 retarget.gd -- res://_src/kaykit/Barbarian.glb <troll.glb> /tmp/troll_kk.res kaykit_troll '{"death":"Death_A","hit":"Hit_A"}'
##   boss_bake.gd -- <troll.glb> /tmp/troll_kk.res res://assets/models/sketchfab/boss/troll_anims.res
##     '{"idle":"Frames_003","run":"Frames_002","walk":"Frames000","attack":"Frames_006","swipe":"Frames_004","roar":"Frames_008","stagger":"Frames_009"}'
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var model: Node = (load(args[0]) as PackedScene).instantiate()
	var kk: AnimationLibrary = load(args[1])
	var want: Dictionary = JSON.parse_string(args[3])
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := AnimationLibrary.new()
	for key in want.keys():
		var src := ap.get_animation(str(want[key]))
		if src == null:
			push_error("missing clip %s" % want[key])
			continue
		var a := src.duplicate(true) as Animation
		a.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "run", "walk"] else Animation.LOOP_NONE
		lib.add_animation(key, a)
		print("native ", key, " <- ", want[key], " %.2fs" % a.length)
	for n in kk.get_animation_list():
		if not lib.has_animation(n):
			var a := kk.get_animation(n).duplicate(true) as Animation
			a.loop_mode = Animation.LOOP_NONE
			lib.add_animation(n, a)
			print("retarget ", n, " %.2fs" % a.length)
	print("save ", ResourceSaver.save(lib, args[2], ResourceSaver.FLAG_COMPRESS))
	model.free()
	quit()
