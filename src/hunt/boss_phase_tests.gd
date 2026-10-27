extends RefCounted
## Rule checks for the boss phases (called from tests.gd): every boss has a
## crown element, the breaks are ordered, the break camera never jumps and ends
## where the fight camera sits, and every boss runs its own script.

const DT := 1.0 / 60.0


static func run(ok: Callable) -> void:
	ok.call("boss phases break in descending order inside the bar", Boss.PHASE_AT.size() == 2 and Boss.PHASE_AT[0] > Boss.PHASE_AT[1] and Boss.PHASE_AT[1] > 0.0 and Boss.PHASE_AT[0] < 1.0)
	var bad := []
	for id in DB.BOSSES:
		if not (StringName(DB.BOSSES[id].get("el", "")) in Fx.VfxLib.ELEMENTS):
			bad.append(id)
	ok.call("every boss names a crown element %s" % [bad], bad.is_empty())
	var boss := Vector3(0, 0, -14)
	var hero := Vector3(1, 0, 4)
	var prev: Dictionary = Boss.shift_look(0.0, boss, hero)
	var worst_f := 0.0
	var worst_z := 0.0
	var worst_p := 0.0
	for i in int(Boss.SHIFT_LEN / DT) + 1:
		var s: Dictionary = Boss.shift_look(float(i) * DT, boss, hero)
		worst_f = maxf(worst_f, (s["focus"] as Vector3).distance_to(prev["focus"]))
		worst_z = maxf(worst_z, absf(float(s["zoom"]) - float(prev["zoom"])))
		worst_p = maxf(worst_p, absf(float(s["pitch"]) - float(prev["pitch"])))
		prev = s
	ok.call("phase break camera moves smoothly", worst_f < 0.5 and worst_z < 0.03 and worst_p < 1.5)
	var end: Dictionary = Boss.shift_look(Boss.SHIFT_LEN, boss, hero)
	ok.call("phase break camera ends on the fight framing", (end["focus"] as Vector3).distance_to(hero.lerp(boss, 0.25)) < 0.01 and absf(float(end["pitch"])) < 0.01)
	var mid: Dictionary = Boss.shift_look(Boss.SHIFT_BEAT, boss, hero)
	ok.call("phase break camera closes on the boss at the climax", (mid["focus"] as Vector3).distance_to(boss) < 0.01 and float(mid["zoom"]) < 0.9)
	for path in ["boss_king", "boss_thorn", "boss_hexer", "boss_warden", "boss_rime", "boss_cinder"]:
		var sc: GDScript = load("res://src/hunt/%s.gd" % path)
		ok.call("%s runs the phased boss base" % path, sc != null and sc.get_base_script() == preload("res://src/hunt/boss.gd"))
