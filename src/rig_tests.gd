extends RefCounted
## Foreign-rig foes and bosses (foe_rig.gd): a "glb:" model keeps its own
## clips, a "proc:" model moves by generated clips, and the combat code's
## KayKit clip names reach either.

const FoeRig := preload("res://src/core/foe_rig.gd")
const WYRM := "glb:res://assets/quaternius/wyrm.glb"
const BAT := "glb:res://assets/sidekicks/bat.tscn"
const SHARD := "proc:res://assets/kaykit/weapons/Skeleton_Arrow.gltf"
const KK_CLIPS := ["Skeletons_Idle", "Skeletons_Walking", "Running_A", "Melee_2H_Attack_Chop", "Melee_Dualwield_Attack_Slice",
	"Ranged_Magic_Summon", "Ranged_Magic_Spellcasting", "Skeletons_Taunt", "Skeletons_Taunt_Longer", "Hit_A",
	"Skeletons_Death", "Death_A", "Skeletons_Awaken_Standing", "Spawn_Ground"]


static func run(ok: Callable) -> void:
	_classes(ok)
	_glb(ok)
	_proc(ok)


static func _classes(ok: Callable) -> void:
	var cls := {"Skeletons_Idle": "idle", "Skeletons_Walking": "walk", "Running_A": "run", "Melee_2H_Attack_Chop": "attack",
		"Ranged_Magic_Summon": "cast", "Skeletons_Taunt_Longer": "taunt", "Hit_A": "hit", "Death_A": "die",
		"Skeletons_Awaken_Standing": "spawn", "Ranged_1H_Aiming": "idle", "Ranged_Bow_Draw": "cast", "Throw": "attack"}
	var bad := []
	for k: String in cls:
		if FoeRig.class_of(k) != cls[k]:
			bad.append(k)
	ok.call("foe rig: KayKit clip names map to classes %s" % [bad], bad.is_empty())
	ok.call("foe rig: model specs are told apart", FoeRig.is_foreign("glb:wolf") and FoeRig.is_foreign("proc:shard") and not FoeRig.is_foreign("skeleton_warrior"))


static func _actor(spec: String, def: Dictionary) -> Actor:
	var a := Actor.new()
	a.build_model(spec, {}, Color.WHITE, 0.5, Color(0, 0, 0, 0), 0.8, def)
	return a


static func _glb(ok: Callable) -> void:
	for spec: String in [WYRM, BAT]:
		var a := _actor(spec, {"fit": 2.0})
		ok.call("foe rig %s: builds with its own clips" % spec, a.foreign and a.anim != null and a.anim.get_animation_list().size() > 2 and a.model.find_child("Skeleton3D", true, false) != null)
		var missing := []
		for c in KK_CLIPS:
			var real := a._clip(c)
			if c in ["Skeletons_Idle", "Skeletons_Walking", "Hit_A"] and real == "":
				missing.append(c)
		ok.call("foe rig %s: idle, walk and hit resolve %s" % [spec, missing], missing.is_empty())
		a.play("Skeletons_Idle")
		ok.call("foe rig %s: play keeps the caller's name and runs the rig's clip" % spec, a.cur_anim == "Skeletons_Idle" and a.anim.current_animation == a._clip("Skeletons_Idle") and a.anim.current_animation != "")
		ok.call("foe rig %s: clip length is the rig's" % spec, absf(a.anim_length("Skeletons_Idle") - a.anim.get_animation(a._clip("Skeletons_Idle")).length) < 0.0001)
		var lit := 0
		for mi in a.mesh_list():
			for s in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(s) is ShaderMaterial:
					lit += 1
		ok.call("foe rig %s: keeps its own PBR in the foe shader" % spec, lit > 0)
		a.set_flash(1.0)
		a.hit_flash()
		a.play("Melee_2H_Attack_Chop", 0.1, 1.0, true)
		a.free()
	# An explicit clip table wins over name guessing.
	var b := _actor(WYRM, {"clips": {"idle": "Fast_Flying"}, "alias": {"Skeletons_Taunt": "Headbutt"}})
	var fly := FoeRig.find_clip(b.anim, "Fast_Flying")
	ok.call("foe rig: def clips and alias override the guess %s" % fly, fly != "" and b._clip("Skeletons_Idle") == fly and b._clip("Skeletons_Taunt") == FoeRig.find_clip(b.anim, "Headbutt"))
	var wy := _actor(WYRM, {})
	ok.call("foe rig: wyrm clips are guessed by name", wy._clip("Skeletons_Idle").ends_with("Flying_Idle") and wy._clip("Skeletons_Walking").ends_with("Fast_Flying") and wy._clip("Melee_2H_Attack_Chop").ends_with("Headbutt") and wy._clip("Hit_A").ends_with("HitReact") and wy._clip("Skeletons_Death").ends_with("Death"))
	wy.free()
	b.free()
	# A missing model must not crash a hunt.
	var m := _actor("glb:no_such_foe", {})
	ok.call("foe rig: a missing model stands in a capsule", m.foreign and m.model != null and m.anim != null and m.model.find_children("*", "MeshInstance3D", true, false).size() > 0)
	m.free()


static func _proc(ok: Callable) -> void:
	var a := _actor(SHARD, {"proc": {"hover": 0.5}})
	var names := a.anim.get_animation_list()
	var want := ["idle", "walk", "run", "attack", "cast", "taunt", "hit", "spawn", "die"]
	var missing := []
	for c in want:
		if not a.anim.has_animation(c):
			missing.append(c)
	ok.call("foe rig proc: generated clips for every class %s" % [missing], missing.is_empty() and names.size() >= want.size())
	ok.call("foe rig proc: KayKit names reach the generated clips", a._clip("Skeletons_Walking") == "walk" and a._clip("Ranged_Magic_Summon") == "cast" and a._clip("Skeletons_Death") == "die" and a._clip("Skeletons_Awaken_Standing") == "spawn")
	ok.call("foe rig proc: idle and walk loop, attack does not", a.anim.get_animation("idle").loop_mode == Animation.LOOP_LINEAR and a.anim.get_animation("walk").loop_mode == Animation.LOOP_LINEAR and a.anim.get_animation("attack").loop_mode == Animation.LOOP_NONE)
	var body := a.model.get_node("Body") as Node3D
	var holder := Node3D.new()
	holder.add_child(a)
	a.play("Melee_2H_Attack_Chop", 0.0, 1.0, true)
	a.anim.advance(0.3)
	ok.call("foe rig proc: the lunge moves the body, not the model root", body.position.z > 0.3 and a.model.position == Vector3.ZERO)
	a.anim.stop()
	a.play("Skeletons_Idle", 0.0)
	a.anim.advance(0.4)
	ok.call("foe rig proc: idle hovers", body.position.y > 0.45)
	a.squash(Vector3(0.1, 0, 0))
	a.tick_common(0.016)
	ok.call("foe rig proc: the body springs still work", a.model.scale.x != 1.0)
	holder.free()
	# A rig with no clip for a name fakes a one-shot with the springs.
	var w := _actor(WYRM, {"clips": {}})
	w.play("Not_A_Clip_At_All", 0.0, 1.0, true)
	ok.call("foe rig: an unknown clip name is ignored", w.anim.current_animation != "Not_A_Clip_At_All")
	w.free()
