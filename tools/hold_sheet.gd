extends SceneTree
## How a hero holds each weapon family and offhand: one column per family,
## rows for the idle pose, mid-run, mid-swing and the super; a last row holds
## each offhand model. Uses GearLook's own hold and clip choices, so it shows
## what the game does.
## tools/dev/godot-gpu.sh --resolution 1500x2000 -s res://tools/hold_sheet.gd -- --hero=mage --mat=3 --yaw=35 --out=/abs/path.png

func _init() -> void:
	var out := "/tmp/hold.png"
	var hero := "knight"
	var mat := 3
	var yaw := 35.0
	# --only=staff,tome: just those families (and no offhand row), zoomed in.
	var only: Array[String] = []
	# --rot=x,y,z / --at=x,y,z: try a grip on the main weapon without editing GearDB.HOLDS.
	var rot_try := ""
	var at_try := ""
	var bone_try := ""
	var offat_try := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hero="):
			hero = a.substr(7)
		elif a.begins_with("--mat="):
			mat = int(a.substr(6))
		elif a.begins_with("--yaw="):
			yaw = float(a.substr(6))
		elif a.begins_with("--rot="):
			rot_try = a.substr(6)
		elif a.begins_with("--offat="):
			offat_try = a.substr(8)
		elif a.begins_with("--bone="):
			bone_try = a.substr(7)
		elif a.begins_with("--at="):
			at_try = a.substr(5)
		elif a.begins_with("--only="):
			only.assign(a.substr(7).split(","))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.7)
	e.ambient_light_energy = 0.8
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-35, -25, 0)
	world.add_child(sun)
	var d: Dictionary = DB.HEROES[hero]
	var fams: Array = DB.HERO_FAMILIES[hero] if only.is_empty() else only
	# The hero's offhand at this set, shown with every family.
	var off_model := ""
	for st: Dictionary in GearDB.LINES[hero]["trinket"]:
		if int(st["from"]) <= mat:
			off_model = str(st.get("model", ""))
	var offs: Array[String] = []
	for st: Dictionary in GearDB.LINES[hero]["trinket"]:
		for m in [st] + st.get("alts", []):
			var mm := str(m.get("model", ""))
			if mm != "" and not offs.has(mm):
				offs.append(mm)
	var poses := [["idle", 0.0], ["run", 0.3], ["attack", 0.45], ["super", 0.45]]
	for row in poses.size() + (1 if only.is_empty() else 0):
		var cols: int = fams.size() if row < poses.size() else offs.size()
		for col in cols:
			var ch := KK.character(d["model"])
			world.add_child(ch)
			ch.position = Vector3(col * 2.3 - 5.75, -row * 3.4, 0)
			ch.rotation_degrees.y = yaw
			var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false)
			var fam: String = fams[col] if row < poses.size() else str(fams[0])
			var anims := GearDB.anims(hero, fam)
			var clip: String
			var t: float
			if row < poses.size():
				var pose: Array = poses[row]
				var c: Variant = anims[pose[0]]
				clip = str(c[0]) if c is Array else str(c)
				t = pose[1]
				var hold := GearDB.weapon_hold(hero, fam)
				if rot_try != "" or at_try != "":
					var r := rot_try.split_floats(",") if rot_try != "" else PackedFloat64Array([0, 0, 0])
					var at := at_try.split_floats(",") if at_try != "" else PackedFloat64Array([0, 0, 0])
					hold["xf"] = GearDB._grip_xf(Vector3(r[0], r[1], r[2]), Vector3(at[0], at[1], at[2]))
				var lk := GearDB.family_look(fam, mat)
				if bone_try != "":
					hold["bone"] = bone_try
				_attach(skel, hold["bone"], str(lk["model"]), float(lk["scale"]), hold["xf"])
				if hold["dual"]:
					_attach(skel, "handslot.l", str(lk["model"]), float(lk["scale"]), hold["xf_l"])
				elif off_model != "":
					var oh := GearDB.offhand_hold(hero, off_model, fam)
					_attach(skel, oh["bone"], off_model, oh["scale"], oh["xf"])
			else:
				clip = str(anims["idle"])
				t = 0.0
				var oh := GearDB.offhand_hold(hero, offs[col])
				if offat_try != "":
					var oa := offat_try.split_floats(",")
					oh["xf"] = Transform3D(Basis(), Vector3(oa[0], oa[1], oa[2]))
				_attach(skel, oh["bone"], offs[col], oh["scale"], oh["xf"])
			var ap := KK.anim_player(ch)
			ap.play(clip)
			ap.seek(ap.current_animation_length * t, true)
			ap.pause()
			var lbl := Label3D.new()
			lbl.text = (fam if row < poses.size() else offs[col].get_basename()) + "\n" + clip
			lbl.font_size = 36
			lbl.pixel_size = 0.004
			lbl.position = ch.position + Vector3(0, -0.15, 0.6)
			world.add_child(lbl)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 18.0 if only.is_empty() else 3.4 * poses.size() * 1.05
	world.add_child(cam)
	var mid := -6.6 if only.is_empty() else -3.4 * (poses.size() - 1) / 2.0 + 1.0
	var cx := 0.0 if only.is_empty() else (fams.size() - 1) * 2.3 / 2.0 - 5.75
	cam.look_at_from_position(Vector3(cx, mid + 0.6, 20), Vector3(cx, mid, 0))
	for f in 10:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit()


func _attach(skel: Skeleton3D, bone: String, model: String, sc: float, xf: Transform3D) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var p := _prop(model)
	att.add_child(p)
	p.transform = xf
	p.scale = Vector3.ONE * sc


# GearLook.prop_for, which needs the Game autoload a tool doesn't have.
func _prop(model: String) -> Node3D:
	if not model.begins_with("kit:"):
		return KK.prop(KK.WEAPON_DIR + model)
	var r := Node3D.new()
	for part: Array in GearDB.KITS[model.trim_prefix("kit:")]:
		var n := KK.prop("res://assets/kaykit/" + str(part[0]))
		var rot: Vector3 = part[2]
		var sc: Vector3 = part[3] if part[3] is Vector3 else Vector3.ONE * float(part[3])
		n.transform = Transform3D(Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(sc), part[1])
		r.add_child(n)
	return r
