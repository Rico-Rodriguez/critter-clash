extends RefCounted
## Licensed boss models (assets/foes, src/data/boss_models.gd): each loads through foe_rig.gd, stays
## inside the mobile budget, stands at least twice as tall as a hero, and answers to every clip the
## combat code asks for.

const BossModels := preload("res://src/data/boss_models.gd")
const FoeRig := preload("res://src/core/foe_rig.gd")
const MAX_TRIS := 12000
const WANT := ["Skeletons_Idle", "Skeletons_Walking", "Running_A", "Melee_2H_Attack_Chop", "Melee_Dualwield_Attack_Slice",
	"Ranged_Magic_Summon", "Skeletons_Taunt", "Hit_A", "Skeletons_Death", "Spawn_Ground"]
const OWN_CLIPS := {"cinder_warlord": ["ANM_IDLE", "ANM_WALK", "ANM_RUN", "ANM_ATTACK_CRIT", "ANM_DAMAGED", "ANM_DEATH",
	"ANM_LIGHT_ATTACK_2", "ANM_ORC_LIGHT_ATTACK", "ANM_ORC_Roar"]}


static func run(ok: Callable) -> void:
	var hero := Actor.new()
	hero.build_model("Knight", {}, Color.WHITE, 0.5, Color(0, 0, 0, 0), 0.8, {})
	var hero_h := _height(hero.model, hero)
	hero.free()
	ok.call("boss models: hero height measured (%.2f m)" % hero_h, hero_h > 1.0 and hero_h < 4.0)
	for id: String in BossModels.DEFS:
		var def: Dictionary = BossModels.DEFS[id]
		var tag := "boss model %s" % id
		var a := Actor.new()
		a.build_model(str(def["model"]), {}, Color.WHITE, 0.5, Color(0, 0, 0, 0), 0.8, def)
		ok.call("%s: loads with a skeleton and meshes" % tag, a.foreign and a.model.find_child("Skeleton3D", true, false) != null and not a.mesh_list().is_empty() and FoeRig.scene_path(id) != "")
		var tris := 0
		for mi in a.mesh_list():
			for s in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		ok.call("%s: %d tris, at most %d" % [tag, tris, MAX_TRIS], tris > 1000 and tris <= MAX_TRIS)
		var lit := 0
		for mi in a.mesh_list():
			for s in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(s) is ShaderMaterial:
					lit += 1
		ok.call("%s: keeps its own PBR in the foe shader" % tag, lit > 0 and lit == a.mesh_list().map(func(m): return m.mesh.get_surface_count()).reduce(func(x, y): return x + y))
		var wrap: Node3D = (load(FoeRig.scene_path(id)) as PackedScene).instantiate()
		var pa: AABB = wrap.get_meta("posed_aabb", AABB())
		ok.call("%s: wrapped 1 m tall, feet at 0, posed bounds" % tag, absf(pa.size.y - 1.0) < 0.03 and absf(pa.position.y) < 0.03 and not wrap.get_meta("cull_aabbs", {}).is_empty())
		wrap.free()
		# Skinned Sketchfab meshes keep bind-space bounds, so the height comes from the wrapper's posed bounds.
		var h := pa.size.y * float(def["fit"]) * float(def["scale"])
		ok.call("%s: stands %.2f m, at least twice a hero (%.2f m)" % [tag, h, hero_h], h >= 2.0 * hero_h)
		var own: Array = OWN_CLIPS[id]
		var missing := []
		for c: String in own:
			var clip := a.anim.get_animation(c) if a.anim.has_animation(c) else null
			if clip == null or clip.length < 0.3:
				missing.append(c)
				continue
			# Each clip must start at 0, not sit after a stacked timeline (a frozen lead-in).
			var first := INF
			for t in clip.get_track_count():
				if clip.track_get_key_count(t) > 0:
					first = minf(first, clip.track_get_key_time(t, 0))
			if first > 0.05:
				missing.append(c + "@start")
		ok.call("%s: has its clips, each starting at 0 %s" % [tag, missing], missing.is_empty())
		var unresolved := []
		for c: String in WANT:
			if a._clip(c) == "":
				unresolved.append(c)
		ok.call("%s: combat clip names resolve %s" % [tag, unresolved], unresolved.is_empty())
		ok.call("%s: attack, taunt and death are different clips" % tag, a._clip("Melee_2H_Attack_Chop") != a._clip("Melee_Dualwield_Attack_Slice") and a._clip("Skeletons_Death") != a._clip("Skeletons_Taunt") and a._clip("Hit_A") != a._clip("Skeletons_Idle"))
		var loops := true
		for c in ["Skeletons_Idle", "Skeletons_Walking", "Running_A"]:
			loops = loops and a.anim.get_animation(a._clip(c)).loop_mode == Animation.LOOP_LINEAR
		ok.call("%s: idle, walk and run loop" % tag, loops)
		a.play("Skeletons_Idle")
		a.play("Melee_2H_Attack_Chop", 0.1, 1.0, true)
		a.set_flash(1.0)
		a.free()


## Standing height in metres of a KayKit `model` at rest, from its mesh bounds.
static func _height(model: Node3D, root: Node) -> float:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.y
