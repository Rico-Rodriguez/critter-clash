extends RefCounted
## Builds a sidekick's model, unmodified (art lock: the pack's own PBR
## materials, no tint, rim or glow). Returns {"root": Node3D, "anim":
## AnimationPlayer or null, "idle": clip, "move": clip, "attack": clip}.

const SDB := preload("res://src/data/sidekick_db.gd")
const Q_DIR := "res://assets/quaternius/"
## Licensed hero-quality replacements (CC0 / CC-BY, see CREDITS.md): "sf:name".
const SF_DIR := "res://assets/sidekicks/"


static func build(id: String, evolved := false) -> Dictionary:
	var d: Dictionary = SDB.ROSTER[id]
	var spec := str(d["evolved_model"]) if evolved and d.has("evolved_model") else str(d["model"])
	var grow := SDB.EVOLVE_SCALE if evolved else 1.0
	var out := {"root": null, "anim": null, "idle": "", "move": "", "attack": ""}
	var root := Node3D.new()
	root.name = "SidekickModel"
	var model: Node3D
	if spec.begins_with("kk:"):
		model = KK.character(spec.substr(3))
		model.scale = Vector3.ONE * float(d["scale"]) * grow
		out["anim"] = KK.anim_player(model)
		out["idle"] = "Skeletons_Idle"
		out["move"] = "Running_A"
		out["attack"] = "Skeletons_Idle"
	elif spec.begins_with("prop:"):
		model = KK.prop(spec.substr(5))
		_fit(model, float(d["scale"]) * grow)
	else:
		# "sf:" scenes wrap a licensed glb pre-scaled to 1 m (tools/art/wrap_sidekicks.gd).
		var path := SF_DIR + spec.substr(3) + ".tscn" if spec.begins_with("sf:") else Q_DIR + spec.substr(2) + ".glb"
		var ps: PackedScene = KK.scene(path)
		model = ps.instantiate()
		if spec.begins_with("sf:"):
			# Skinned imports carry bind-space mesh bounds that _fit can't read.
			model.scale = Vector3.ONE * float(d["scale"]) * grow
		else:
			_fit(model, float(d["scale"]) * grow)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		if ap:
			out["anim"] = ap
			out["idle"] = _clip(ap, ["Flying_Idle", "Bat_Flying", "Idle"])
			out["move"] = _clip(ap, ["Fast_Flying", "Bat_Flying", "Walk"])
			out["attack"] = _clip(ap, ["Punch", "Headbutt", "Bat_Attack", "Bite_Front"])
			for n in [out["idle"], out["move"]]:
				if n != "":
					ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	root.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	out["root"] = root
	return out


static func _clip(ap: AnimationPlayer, wants: Array) -> String:
	for w: String in wants:
		for n: String in ap.get_animation_list():
			if n == w or n.ends_with("|" + w) or n.ends_with("/" + w):
				return n
	return ""


## Scales a model so its rest-pose height is `h` metres, feet on the ground.
static func _fit(model: Node3D, h: float) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != model:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y <= 0.001:
		return
	var k := h / box.size.y
	model.scale = Vector3.ONE * k
	model.position.y = -box.position.y * k


static func play(look: Dictionary, which: String, blend := 0.15, speed := 1.0) -> void:
	var ap: AnimationPlayer = look.get("anim")
	var clip := str(look.get(which, ""))
	if ap == null or clip == "" or not ap.has_animation(clip):
		return
	if ap.current_animation == clip and which != "attack":
		return
	ap.play(clip, blend, speed)
