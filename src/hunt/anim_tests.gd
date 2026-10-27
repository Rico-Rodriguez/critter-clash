extends RefCounted
## Rule checks for the hero animation set (called from tests.gd). The tree is
## stepped by hand at 60 fps while a scripted hero starts, stops, turns,
## fidgets and cheers; a pop shows up as one frame moving a joint far more
## than any frame of steady running does.

const HeroAnim := preload("res://src/hunt/hero_anim.gd")
const JOINTS := ["foot.l", "foot.r", "hand.l", "hand.r", "head", "hips", "chest"]
const DT := 1.0 / 60.0

var _ok: Callable


static func run(ok: Callable) -> void:
	var t = (load("res://src/hunt/anim_tests.gd") as GDScript).new()
	t._ok = ok
	t._all()


func _pets() -> void:
	var PL := preload("res://src/hunt/pet_life.gd")
	# Every fidget starts and ends at the neutral pose, so none can pop.
	for kind in PL.FIDGETS:
		var a: Dictionary = PL.fidget(kind, 0.0)
		var b: Dictionary = PL.fidget(kind, 1.0)
		var calm := true
		for k in a:
			calm = calm and absf(float(a[k]) - float(PL.neutral()[k])) < 0.01 and absf(float(b[k]) - float(PL.neutral()[k])) < 0.01
		_ok.call("pet fidget '%s' starts and ends neutral" % kind, calm)
	_ok.call("pet pop-in grows from nearly nothing to full size", float(PL.born(0.0)["s"]) < 0.1 and float(PL.born(PL.BORN_TIME)["s"]) == 1.0 and float(PL.born(PL.BORN_TIME * 0.7)["s"]) > 0.9)
	# Stepped at 60 fps the layer never jumps further than a hop's own speed.
	var life: Dictionary = PL.new_life(3)
	var prev: Dictionary = PL.step(life, DT, true, "")
	var worst := 0.0
	var moods := ["", "", "", "", "", "", "wary", "cheer", "cheer", "droop", ""]
	var seen := {}
	for i in 60 * 44:
		var mood: String = moods[i / (60 * 4)]
		var cur: Dictionary = PL.step(life, DT, true, mood)
		for k in ["y", "pitch", "roll"]:
			worst = maxf(worst, absf(float(cur[k]) - float(prev[k])))
		# The pop-in is meant to grow fast; it just must not skip.
		worst = maxf(worst, absf(float(cur["s"]) - float(prev["s"])) * 0.6)
		if str(life["kind"]) != "":
			seen[life["kind"]] = true
		prev = cur
	print("ANIM pets worst per-frame jump %.3f, fidgets seen %s" % [worst, seen.keys()])
	_ok.call("pet body language never jumps in a frame", worst < 0.12)
	_ok.call("an idle pet fidgets in more than one way", seen.size() >= 2)
	var d := PL.step(PL.new_life(1), DT, true, "cheer")
	var life2: Dictionary = PL.new_life(1)
	life2["age"] = 5.0
	var top := 0.0
	for i in 120:
		top = maxf(top, float(PL.step(life2, DT, false, "cheer")["y"]))
	_ok.call("a cheering pet leaves the ground", top > 0.2 and d != null)


func _all() -> void:
	_pets()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	for hid in DB.HERO_ORDER:
		var a := Actor.new()
		root.add_child(a)
		a.build_model(DB.HEROES[hid]["model"], {}, Color.WHITE, 0.3)
		var ha = HeroAnim.new()
		ha.attach(a, GearDB.anims(hid, ""), hid)
		ha.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var skel: Skeleton3D = a.model.find_child("Skeleton3D", true, false)
		var speed := float(DB.HEROES[hid]["speed"])
		var st := {"vel": Vector3.ZERO, "yaw": 0.0, "prev": _pose(skel), "prev2": _pose(skel), "worst": 0.0}
		# Warm up in steady idle, then measure each situation's worst frame.
		_run(ha, a, skel, st, 0.5, Vector3.ZERO, 0.0)
		st["worst"] = 0.0
		_run(ha, a, skel, st, 2.0, Vector3(0, 0, speed), 0.0, hid + " start")
		var start_worst: float = st["worst"]
		st["worst"] = 0.0
		_run(ha, a, skel, st, 1.5, Vector3(0, 0, speed), 0.0)
		var steady: float = st["worst"]
		st["worst"] = 0.0
		_run(ha, a, skel, st, 1.0, Vector3.ZERO, 0.0, hid + " stop")
		var stop_worst: float = st["worst"]
		st["worst"] = 0.0
		_run(ha, a, skel, st, 0.8, Vector3.ZERO, 11.0, hid + " turn")
		var turn_worst: float = st["worst"]
		st["worst"] = 0.0
		ha.quirk()
		_run(ha, a, skel, st, 3.0, Vector3.ZERO, 0.0, hid + " quirk")
		var quirk_worst: float = st["worst"]
		st["worst"] = 0.0
		ha.victory()
		_run(ha, a, skel, st, 4.0, Vector3.ZERO, 0.0, hid + " win")
		var win_worst: float = st["worst"]
		print("ANIM %s steady=%.3f start=%.3f stop=%.3f turn=%.3f quirk=%.3f win=%.3f" % [hid, steady, start_worst, stop_worst, turn_worst, quirk_worst, win_worst])
		var cap := maxf(steady * 1.5, 0.25)
		_ok.call("%s starts running without a pop" % hid, start_worst <= cap)
		_ok.call("%s stops without a pop" % hid, stop_worst <= cap)
		_ok.call("%s turns on the spot without a pop" % hid, turn_worst <= cap)
		_ok.call("%s eases into a fidget" % hid, quirk_worst <= cap)
		_ok.call("%s eases into its victory pose" % hid, win_worst <= cap)
		a.free()


func _run(ha, a: Actor, skel: Skeleton3D, st: Dictionary, secs: float, want: Vector3, spin: float, label := "") -> void:
	st["wd"] = 0.0
	var vel: Vector3 = st["vel"]
	var yaw: float = st["yaw"]
	var n := int(secs / DT)
	for i in n:
		vel = vel.move_toward(want, 60.0 * DT)
		yaw += spin * DT
		a.rotation.y = yaw
		ha.tick(DT, vel, 5.5, yaw, false)
		ha.tree.advance(DT)
		# A pop is one frame moving a joint far further than its neighbours do.
		var p := _pose(skel)
		var d := 0.0
		var prev: PackedVector3Array = st["prev"]
		var prev2: PackedVector3Array = st["prev2"]
		for j in p.size():
			var dj := p[j].distance_to(prev[j])
			if dj > float(st["wd"]):
				st["wd"] = dj
				st["wj"] = JOINTS[j]
				st["wi"] = i
			d = maxf(d, dj)
		st["worst"] = maxf(float(st["worst"]), d)
		st["prev2"] = prev
		st["prev"] = p
	st["vel"] = vel
	st["yaw"] = yaw
	if label != "":
		print("ANIM   %s worst %.3f at %s frame %d" % [label, st["wd"], st.get("wj"), st.get("wi")])


func _pose(skel: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in JOINTS:
		var i := skel.find_bone(j)
		out.append(skel.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO)
	return out
