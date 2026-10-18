extends SceneTree
## Rendered gear slot icons: each hero's piece alone (the rest of the body is
## stripped by the bare-slot discard), framed on its bones, transparent.
## xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/slot_icons.gd [-- hero ...]
## Writes assets/sprites/gear/<hero>.<slot>.<tier>.png (160 px).
const PX := 160
const BONES := {
	"helm": [["head"]],
	"chest": [["chest", "spine"]],
	"pauldrons": [["l_shoulder", "leftshoulder", "shoulder_l", "shoulder.l"], ["r_shoulder", "rightshoulder", "shoulder_r", "shoulder.r"]],
	"gloves": [["r_hand", "righthand", "hand_r", "hand.r"]],
	"boots": [["l_foot", "leftfoot", "foot_l", "foot.l", "l_ankle"], ["r_foot", "rightfoot", "foot_r", "foot.r", "r_ankle"]],
}
const SPAN := {"helm": 0.2, "chest": 0.34, "pauldrons": 0.36, "gloves": 0.16, "boots": 0.3, "weapon": 0.0, "offhand": 0.0, "charm": 0.0}


func _bone(sk: Skeleton3D, keys: Array) -> int:
	for k in keys:
		for b in sk.get_bone_count():
			if sk.get_bone_name(b).to_lower().begins_with(k) or sk.get_bone_name(b).to_lower().contains(k):
				return b
	return -1


func _init() -> void:
	var heroes: Array = Array(OS.get_cmdline_user_args())
	if heroes.is_empty():
		heroes = ["pebble", "bramble", "lumen", "ember"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/gear"))
	# Every tier-0 slot discards (nearly) all its vertices: the piece stands alone.
	OS.set_environment("CC_STRIP", "0.0001,0.0001,0.0001,0.0001,0.0001,0.0001,0.0001,0.0001")
	OS.set_environment("CC_STRIP_TOP", "-1.0")
	var vp := SubViewport.new()
	vp.size = Vector2i(PX * 2, PX * 2)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.64, 0.72)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 2.0
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 1.6
	rim.light_color = Color("9cc4ff")
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	for id in heroes:
		for slot in GearDB.HERO_SLOTS.get(id, []):
			for t in range(1, 4):
				var r: Node3D = load(Cast3D.HEROES[id]).instantiate()
				vp.add_child(r)
				Gear3D.hide_own(r, id)
				var tiers := {}
				for sl in Gear3D.SLOTS:
					tiers[sl] = 0
				tiers[slot] = t
				Gear3D.dress(r, id, tiers)
				var sk: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
				var lo := 1e9
				var hi := -1e9
				for b in sk.get_bone_count():
					var y := (sk.global_transform * sk.get_bone_global_pose(b).origin).y
					lo = minf(lo, y)
					hi = maxf(hi, y)
				var hgt := (hi - lo) * 1.08
				r.scale = Vector3.ONE * (180.0 / maxf(hgt, 0.001))
				r.position.y = -lo * r.scale.y
				var ap: AnimationPlayer = r.find_children("*", "AnimationPlayer", true, false)[0]
				ap.play("idle")
				ap.seek(ap.get_animation("idle").length * 0.3, true)
				ap.pause()
				await process_frame
				await process_frame
				var focus := Vector3(0, 100, 0)
				var span := 40.0
				if BONES.has(slot):
					var pts: Array[Vector3] = []
					for keys in BONES[slot]:
						var b := _bone(sk, keys)
						if b >= 0:
							pts.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
					if not pts.is_empty():
						focus = Vector3.ZERO
						for p in pts:
							focus += p
						focus /= pts.size()
					if slot == "helm":
						focus.y += 9.0
					span = 180.0 * float(SPAN[slot])
				else:
					var node := sk.get_node_or_null({"weapon": "GearMain", "offhand": "GearOff", "charm": "GearCharm"}[slot])
					var box := AABB()
					var first := true
					if node:
						for v in node.find_children("*", "VisualInstance3D", true, false):
							var gb: AABB = (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
							box = gb if first else box.merge(gb)
							first = false
					if first:
						r.queue_free()
						continue
					focus = box.get_center()
					span = maxf(box.size.length() * 0.75, 12.0)
				var dist := span * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.15
				cam.position = focus + Vector3(0.35, 0.15, 1.0).normalized() * dist
				cam.look_at(focus)
				for k in 4:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				img.resize(PX, PX, Image.INTERPOLATE_LANCZOS)
				img.save_png("res://assets/sprites/gear/%s.%s.%d.png" % [id, slot, t])
				r.queue_free()
				await process_frame
	quit()
