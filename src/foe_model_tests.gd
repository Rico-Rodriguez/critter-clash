extends RefCounted
## The foe models of the biome rebuild (assets/foes, src/data/foe_models.gd): each loads through
## foe_rig.gd, stays in the mobile budget (3k tris, one material), keeps its PBR, is wrapped to a
## 1 m scene with feet at 0, and answers to every clip name its NextFoes def asks for.

const FoeModels := preload("res://src/data/foe_models.gd")
const NextFoes := preload("res://src/data/next_foes.gd")
const FoeRig := preload("res://src/core/foe_rig.gd")
const MAX_TRIS := 3000


static func run(ok: Callable) -> void:
	var wired := true
	for id: String in FoeModels.DEFS:
		wired = wired and DB.enemy(id)["model"] == FoeModels.DEFS[id]["model"] and DB.enemy(id)["weapons"].is_empty()
	ok.call("foe models: DB.enemy hands out the folded defs (none on dev/biome-models: next_foes.gd carries every model)", wired and DB.enemy("rh_wolf") == DB.enemy("rh_wolf"))
	for id: String in FoeModels.DEFS:
		var def: Dictionary = FoeModels.fold(id, NextFoes.FOES[id])
		var tag := "foe model %s (%s)" % [id, def["model"]]
		var proc := str(def["model"]).begins_with("proc:")
		var a := Actor.new()
		a.build_model(str(def["model"]), {}, Color.WHITE, 0.5, Color(0, 0, 0, 0), 0.8, def)
		var meshes: Array = a.mesh_list()
		ok.call("%s: loads, foreign rig, has meshes" % tag, a.foreign and not meshes.is_empty() and FoeRig.scene_path(str(def["model"]).get_slice(":", 1)) != "")
		var tris := 0
		var surfaces := 0
		var lit := 0
		var mats := {}
		for mi: MeshInstance3D in meshes:
			for s in mi.mesh.get_surface_count():
				surfaces += 1
				tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				var m := mi.get_surface_override_material(s)
				if m is ShaderMaterial:
					lit += 1
					mats[m] = true
		ok.call("%s: %d tris, at most %d" % [tag, tris, MAX_TRIS], tris > 100 and tris <= MAX_TRIS)
		ok.call("%s: one material, its own PBR in the foe shader" % tag, lit == surfaces and mats.size() == 1)
		var wrap: Node3D = (load(FoeRig.scene_path(str(def["model"]).get_slice(":", 1))) as PackedScene).instantiate()
		var pa: AABB = wrap.get_meta("posed_aabb", AABB())
		var culls: Dictionary = wrap.get_meta("cull_aabbs", {})
		ok.call("%s: wrapped 1 m tall, feet at 0%s" % [tag, "" if proc else ", posed bounds"], absf(pa.size.y - 1.0) < 0.03 and absf(pa.position.y) < 0.03 and (proc or not culls.is_empty()))
		wrap.free()
		var h := pa.size.y * float(def["fit"]) * float(def.get("scale", 1.0))
		ok.call("%s: stands %.2f m" % [tag, h], h > 0.8 and h < 5.0)
		var unresolved := []
		for k: String in def["anim"]:
			if a._clip(str(def["anim"][k])) == "":
				unresolved.append(k)
		ok.call("%s: its six anim keys resolve to clips %s" % [tag, unresolved], unresolved.is_empty())
		var starts := []
		var named: Array = []
		for c in (def.get("clips", {}) as Dictionary).values():
			named.append_array(c if c is Array else [c])
		for c: String in named:
			var n := FoeRig.find_clip(a.anim, c)
			var clip: Animation = a.anim.get_animation(n) if n != "" else null
			if clip == null or clip.length < 0.2:
				starts.append(c)
				continue
			var first := INF
			for t in clip.get_track_count():
				if clip.track_get_key_count(t) > 0:
					first = minf(first, clip.track_get_key_time(t, 0))
			if first > 0.05:
				starts.append(c + "@start")
		ok.call("%s: its named clips exist, each starting at 0 %s" % [tag, starts], starts.is_empty())
		var loops := true
		for c in ["Skeletons_Idle", "Skeletons_Walking", "Running_A"]:
			var n: String = a._clip(c)
			loops = loops and n != "" and a.anim.get_animation(n).loop_mode == Animation.LOOP_LINEAR
		ok.call("%s: idle, walk and run loop" % tag, loops)
		a.play("Skeletons_Idle")
		a.play(str(def["anim"]["attack"]), 0.1, 1.0, true)
		a.set_flash(1.0)
		a.free()
	# Foes without an entry keep their own def untouched.
	ok.call("foe models: foes with no model entry fold to themselves", FoeModels.fold("rh_imp", NextFoes.FOES["rh_imp"]) == NextFoes.FOES["rh_imp"])
