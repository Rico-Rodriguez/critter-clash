extends RefCounted
## Rule checks for the boss entrance (called from tests.gd): the shot never
## jumps from one frame to the next, ends on the camera's fight framing, and
## SKIP is a glide (the clock jumps to the whip back), never a cut. Every boss
## with an entrance also ships its sting, and the shared fallback exists.

const BI := preload("res://src/hunt/boss_intro.gd")
const DT := 1.0 / 60.0


static func run(ok: Callable) -> void:
	var boss := Vector3(0, 0, -14)
	var hero := Vector3(1, 0, 4)
	var home := hero.lerp(boss, 0.25)
	for id in BI.STYLE:
		var prev: Dictionary = BI.shot(id, 0.0, boss, hero)
		var worst_f := 0.0
		var worst_z := 0.0
		var worst_p := 0.0
		for i in int(BI.LENGTH / DT) + 1:
			var s: Dictionary = BI.shot(id, float(i) * DT, boss, hero)
			worst_f = maxf(worst_f, (s["focus"] as Vector3).distance_to(prev["focus"]))
			worst_z = maxf(worst_z, absf(float(s["zoom"]) - float(prev["zoom"])))
			worst_p = maxf(worst_p, absf(float(s["pitch"]) - float(prev["pitch"])))
			prev = s
		ok.call("boss entrance '%s' camera moves smoothly" % id, worst_f < 0.5 and worst_z < 0.03 and worst_p < 1.5)
		var end: Dictionary = BI.shot(id, BI.LENGTH, boss, hero)
		ok.call("boss entrance '%s' ends on the fight framing" % id, (end["focus"] as Vector3).distance_to(home) < 0.01 and absf(float(end["pitch"])) < 0.01)
		var mid: Dictionary = BI.shot(id, BI.SLAM_AT, boss, hero)
		ok.call("boss entrance '%s' holds low and close on the boss" % id, float(mid["pitch"]) > 8.0 and float(mid["zoom"]) < 0.9 and (mid["focus"] as Vector3).distance_to(boss) < 0.5)
		ok.call("boss entrance '%s' ships its sting" % id, ResourceLoader.exists("res://assets/audio/sfx/boss_sting_%s.ogg" % id))
	ok.call("boss entrance has a shared fallback sting", ResourceLoader.exists("res://assets/audio/sfx/boss_sting_1.ogg"))
	ok.call("name card shows only between the slam and the whip back", BI.card_alpha(0.5) == 0.0 and BI.card_alpha(1.8) == 1.0 and BI.card_alpha(BI.LENGTH) == 0.0)
	ok.call("letterbox bars come in and leave", BI.bars(0.0) == 0.0 and BI.bars(1.5) == 1.0 and BI.bars(BI.LENGTH) == 0.0)
	var src := GDScript.new()
	src.source_code = "extends Node\nvar phase := \"boss_intro\"\nvar phase_t := 0.8\n"
	src.reload()
	var h: Node = src.new()
	var intro: Node = BI.new()
	intro.hunt = h
	intro.skip()
	ok.call("skipping jumps to the whip back", is_equal_approx(float(h.phase_t), BI.WHIP_AT))
	h.phase_t = 3.0
	intro.skip()
	ok.call("skipping late never rewinds", is_equal_approx(float(h.phase_t), 3.0))
	h.free()
	intro.free()
	_sting(ok)


## The slam plays the boss's own sting, and an unknown boss gets the shared one.
static func _sting(ok: Callable) -> void:
	var cam_src := GDScript.new()
	cam_src.source_code = "extends Node\nvar punch := 0.0\nfunc add_trauma(_v: float) -> void:\n\tpass\n"
	cam_src.reload()
	var hunt_src := GDScript.new()
	hunt_src.source_code = "extends Node\nvar cam: Node\n"
	hunt_src.reload()
	var h: Node = hunt_src.new()
	h.cam = cam_src.new()
	var intro: Node = BI.new()
	intro.hunt = h
	for id in ["gravemaw", "nobody"]:
		var want: String = "boss_sting_" + id if id == "gravemaw" else "boss_sting"
		Sfx._last.erase(want)
		intro.boss_id = id
		intro._slam()
		ok.call("boss entrance '%s' slam plays %s" % [id, want], Sfx._last.has(want))
	# The slam also roars and heats the music: leave Sfx as the next test expects.
	Sfx._last.erase("boss_roar")
	Sfx.intensity = 0.0
	h.cam.free()
	h.free()
	intro.free()
