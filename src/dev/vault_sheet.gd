extends RefCounted
## Contact sheet of the Gilded Vault's dark plate remake (capture.gd, shot "vaultsheet"):
## the dark Knight for scale, the Warden with his arms, then the guard, as the hunt builds them.
##   -- --shots=vaultsheet --view=all|boss|foes|back|old

const GearLook := preload("res://src/core/gear_look.gd")


## Lays the figures out on `root` and aims a camera; the caller waits a moment, then saves.
static func stage(root: Node3D, env: Environment, view: String) -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	env.background_color = Color(0.13, 0.12, 0.11)
	if view == "arms":
		_arms(root, cam)
		return
	var row: Array = [["hero"]]
	if view in ["", "all", "boss", "back"]:
		row.append(["boss", "warden"])
	if view in ["", "all", "foes", "back"]:
		for k in ["gildedguard", "vaultbow", "vaultbrute", "vaulthound"]:
			row.append(["foe", k])
	if view == "old":
		# What the Vault fielded before: the plain skeletons of the same roles.
		row = [["hero"]]
		for k in ["warrior", "rogue", "brute", "hound"]:
			row.append(["foe", k])
	var n := row.size()
	for i in n:
		var spec: Array = row[i]
		var a := Actor.new()
		root.add_child(a)
		var sc := 1.0
		var idle := "Idle_A"
		if spec[0] == "hero":
			a.adult_build = true
			a.build_model(DB.HEROES["knight"]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
			var pre := {}
			for slot in DB.SLOTS:
				pre[slot] = Game.make_item("knight", slot, 6, "rare")
			GearLook.apply(a, "knight", pre)
		elif spec[0] == "boss":
			var bd: Dictionary = DB.BOSSES[str(spec[1])]
			a.build_model(str(bd["model"]), bd["weapons"], bd["color"], 0.55, Color(bd["color"], 1.0), 0.8, bd)
			sc = float(bd["scale"])
		else:
			var d: Dictionary = DB.enemy(str(spec[1]))
			a.build_model(str(d["model"]), d["weapons"], Color(0.45, 0.6, 1.0), 0.45, Color(1.0, 0.55, 0.15, 1.0), 0.8, d)
			sc = float(d["scale"])
			idle = str(d["anim"]["idle"])
			if d.has("tint"):
				a.set_tint(d["tint"])
		a.scale = Vector3.ONE * sc
		var x := (i - (n - 1) * 0.5) * (2.6 if view != "boss" else 3.4)
		a.position = Vector3(x, 0, 0)
		a.rotation.y = (0.3 if i < n / 2 else -0.3) + (PI if view == "back" else 0.0)
		a.play(idle, 0.0)
	var wide := 18.0 if n > 5 else 10.5
	cam.look_at_from_position(Vector3(0, 2.4, wide), Vector3(0, 1.6, 0), Vector3.UP)


## The weapons a guard might hold, side by side with their file names, for choosing.
static func _arms(root: Node3D, cam: Camera3D) -> void:
	var names := ["knight_sword_0", "knight_sword_1", "knight_sword_2", "knight_sword_3", "knight_sword_4", "knight_off_0", "knight_off_1", "knight_off_2", "knight_off_3", "knight_off_4",
		"knight_mace_2", "knight_mace_3", "knight_mace_4", "knight_warhammer_2", "knight_warhammer_3", "knight_warhammer_4", "barb_axe_3", "barb_axe_4", "barb_halberd_3", "barb_halberd_4",
		"axe_2handed", "hammer_B", "hammer_C", "crossbow_1handed", "ranger_crossbow_3", "ranger_crossbow_4", "dagger", "rogue_daggers_3", "warden_key", "warden_door"]
	for i in names.size():
		var p := KK.prop(KK.WEAPON_DIR + names[i] + ".gltf")
		root.add_child(p)
		p.position = Vector3((i % 10 - 4.5) * 1.1, 1.9 - (i / 10) * 2.1, 0)
		var lb := Label3D.new()
		lb.text = names[i]
		lb.font_size = 40
		lb.pixel_size = 0.004
		lb.position = p.position + Vector3(0, -0.85, 0.1)
		root.add_child(lb)
	cam.look_at_from_position(Vector3(0, 0, 13.5), Vector3(0, 0, 0), Vector3.UP)

