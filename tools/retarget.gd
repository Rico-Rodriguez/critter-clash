extends SceneTree
## Bakes humanoid clips from a source rig onto a target rig (offline tool).
##   godot --headless --path . -s res://tools/retarget.gd -- <src.glb> <dst.glb> <out.res> <map>
## World-space delta retarget: each mapped bone keeps the source's rotation
## away from its bind pose, applied to the target's bind pose after the
## target's limbs are swung to match the source silhouette (A-pose -> T-pose).
## Unmapped bones keep the target's rest (finger grip) or bind (neck, collars).

const MAPS := {
	# KayKit (CC0) -> DJMaesen knight rig (Paladin, Skeleton Lord, Ghoul).
	"kaykit_djm": {
		"hips": "hips_01", "spine": "spine_012", "chest": "chest_013", "head": "head_062",
		"upperarm.l": "L_arm_015", "lowerarm.l": "L_elbow_016", "hand.l": "L_wrist_017",
		"upperarm.r": "R_arm_039", "lowerarm.r": "R_elbow_040", "hand.r": "R_wrist_041",
		"upperleg.l": "L_leg_07", "lowerleg.l": "L_knee_08", "foot.l": "L_ankle_09", "toes.l": "L_foot_010",
		"upperleg.r": "R_leg_02", "lowerleg.r": "R_knee_03", "foot.r": "R_ankle_04", "toes.r": "R_foot_05",
	},
	# KayKit -> BeardenInc Plague Doctor (no toes or fingers; staff on its own bone).
	"kaykit_plague": {
		"hips": "b_Pelvis_03", "spine": "b_Belly_010", "chest": "b_Chest_011", "head": "b_Face_013",
		"upperarm.l": "b_Arm_Upper_Left_015", "lowerarm.l": "b_Arm_Lower_Left_016", "hand.l": "b_Hand_Left_00",
		"upperarm.r": "b_Arm_Upper_Right_023", "lowerarm.r": "b_Arm_Lower_Right_024", "hand.r": "b_Hand_Right_025",
		"upperleg.l": "b_Leg_Left_Upper_04", "lowerleg.l": "b_Leg_Left_Lower_05", "foot.l": "b_Foot_Left_06",
		"upperleg.r": "b_Leg_rIGHT_Upper_07", "lowerleg.r": "b_Leg_Right_Lower_08", "foot.r": "b_Foot_Right_09",
	},
	# KayKit -> Vasian-Digital3D Troll Cave (boss): Unreal-style mannequin names.
	"kaykit_troll": {
		"hips": "Hips_09", "spine": "Spine1_026", "chest": "Spine3_028", "head": "Head_061",
		"upperarm.l": "LeftArm_032", "lowerarm.l": "LeftForeArm_033", "hand.l": "LeftHand_036",
		"upperarm.r": "RightArm_089", "lowerarm.r": "RightForeArm_091", "hand.r": "RightHand_092",
		"upperleg.l": "LeftUpLeg_0118", "lowerleg.l": "LeftLeg_0119", "foot.l": "LeftFoot_0121", "toes.l": "LeftToeBase_0122",
		"upperleg.r": "RightUpLeg_010", "lowerleg.r": "RightLeg_011", "foot.r": "RightFoot_013", "toes.r": "RightToeBase_014",
	},
}
## Limb chains whose bind directions are swung to match: [src a, src b] -> target follows map.
const SWING := [["upperarm.l", "lowerarm.l"], ["lowerarm.l", "hand.l"], ["upperarm.r", "lowerarm.r"], ["lowerarm.r", "hand.r"],
	["upperleg.l", "lowerleg.l"], ["lowerleg.l", "foot.l"], ["upperleg.r", "lowerleg.r"], ["lowerleg.r", "foot.r"]]
const KEEP_REST := ["thumb", "point", "middle", "ring", "pink", "Joint_3"]


func _skel(n: Node) -> Skeleton3D:
	return n.find_children("*", "Skeleton3D", true, false)[0]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: Node3D = load(args[0]).instantiate()
	var dst: Node3D = load(args[1]).instantiate()
	root.add_child(src)
	root.add_child(dst)
	var map: Dictionary = (MAPS[args[3]] as Dictionary).duplicate()
	var clips: Dictionary = JSON.parse_string(args[4]) if args.size() > 4 else {}
	await process_frame
	var ss := _skel(src)
	var ts := _skel(dst)
	# DJMaesen rigs share bone names but number them per model
	# (L_wrist_017 vs L_wrist_039): match on the name without the suffix.
	var strip := func(n: String) -> String:
		var rx := RegEx.create_from_string("_\\d+$")
		return rx.sub(n, "")
	for k in map.keys():
		if ts.find_bone(map[k]) >= 0:
			continue
		for b in ts.get_bone_count():
			if strip.call(ts.get_bone_name(b)) == strip.call(map[k]):
				map[k] = ts.get_bone_name(b)
				break
	print("MAP ", map)
	# Optional grip donor (env GRIP_DONOR=res://...glb): a rig with the same
	# bone names whose rest pose holds a closed grip; its finger rotations
	# replace this rig's open-hand rest.
	var grip := {}
	if OS.get_environment("GRIP_DONOR") != "":
		var donor: Node3D = load(OS.get_environment("GRIP_DONOR")).instantiate()
		var dsk := _skel(donor)
		for b in ts.get_bone_count():
			var bn := ts.get_bone_name(b)
			if not KEEP_REST.any(func(k: String) -> bool: return k in bn):
				continue
			for d in dsk.get_bone_count():
				if strip.call(dsk.get_bone_name(d)) == strip.call(bn):
					grip[b] = dsk.get_bone_rest(d).basis.orthonormalized()
					break
		print("grip bones ", grip.size())
		donor.free()
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	# Source bind = rest (KayKit exports rest == bind).
	var s_rest := {}
	for b in ss.get_bone_count():
		s_rest[b] = ss.get_bone_global_rest(b)
	# Target bind from the skin; bones missing from the skin fall back to rest.
	var t_bind := {}
	for b in ts.get_bone_count():
		t_bind[b] = ts.get_bone_global_rest(b)
	# USE_REST=1: rigs whose skin binds live in a scaled mesh space (Troll
	# Cave) retarget against the skeleton rest instead.
	var binds: Array = [] if OS.get_environment("USE_REST") == "1" else dst.find_children("*", "MeshInstance3D", true, false)
	for m: MeshInstance3D in binds:
		if m.skin == null:
			continue
		for i in m.skin.get_bind_count():
			var bi := m.skin.get_bind_bone(i)
			if bi < 0:
				bi = ts.find_bone(m.skin.get_bind_name(i))
			if bi >= 0:
				t_bind[bi] = m.skin.get_bind_pose(i).affine_inverse()
	var ref := t_bind.duplicate()
	var sidx := func(n: String) -> int: return ss.find_bone(n)
	var tidx := func(n: String) -> int: return ts.find_bone(map[n])
	# Swing limbs so the target reference matches the source silhouette.
	for pair in SWING:
		if not map.has(pair[0]) or not map.has(pair[1]):
			continue  # legless rigs skip the leg chains
		var ta: int = tidx.call(pair[0])
		var tb: int = tidx.call(pair[1])
		var dt: Vector3 = (ref[tb].origin - ref[ta].origin).normalized()
		var ds: Vector3 = (s_rest[sidx.call(pair[1])].origin - s_rest[sidx.call(pair[0])].origin).normalized()
		var q := Quaternion(dt, ds)
		var pivot: Vector3 = (ref[ta] as Transform3D).origin
		for b in ts.get_bone_count():
			if b == ta or _descends(ts, b, ta):
				var g: Transform3D = ref[b]
				ref[b] = Transform3D(Basis(q) * g.basis, pivot + q * (g.origin - pivot))
	var pairs := []  # [t_bone, s_bone]
	for k in map.keys():
		pairs.append([ts.find_bone(map[k]), ss.find_bone(k)])
	var t_of := {}
	for p in pairs:
		t_of[p[0]] = p[1]
	var hip_t := ts.find_bone(map["hips"])
	var hip_s := ss.find_bone("hips")
	var k_pos: float = ref[hip_t].origin.y / maxf(s_rest[hip_s].origin.y, 0.001)
	# Rigs whose skeleton space is turned against the source's (Unreal-style
	# Z-up exports under a rotated root): deltas are carried into the
	# target's skeleton space, and hip travel scales by leg length.
	var axes: Basis = ts.global_transform.basis.orthonormalized().inverse() * ss.global_transform.basis.orthonormalized()
	var turned := not axes.is_equal_approx(Basis.IDENTITY)
	# K_LEGS=1: rigs whose origin is not at the feet (the werewolf's hips sit
	# at y = 0) scale hip travel by hip-to-foot length instead of hip height.
	if (turned or OS.get_environment("K_LEGS") == "1") and map.has("foot.l"):
		var tl: float = (ref[hip_t].origin - ref[ts.find_bone(map["foot.l"])].origin).length()
		var sl: float = (s_rest[hip_s].origin - s_rest[ss.find_bone("foot.l")].origin).length()
		k_pos = tl / maxf(sl, 0.0001)
	print("axes turned ", turned, " k_pos ", k_pos)
	var skel_path := String(dst.get_path_to(ts))
	var lib := AnimationLibrary.new()
	# Hand sockets: the source's weapon slot carried over in world orientation,
	# offset scaled by forearm length, stored relative to the target hand bone.
	var sockets := {}
	for side in ["l", "r"]:
		var sh := ss.find_bone("hand." + side)
		var sl := ss.find_bone("handslot." + side)
		if sh < 0 or sl < 0:
			continue
		var th := ts.find_bone(map["hand." + side])
		var tel := ts.find_bone(map["lowerarm." + side])
		var s_fore: float = ((s_rest[sh] as Transform3D).origin - (s_rest[ss.find_bone("lowerarm." + side)] as Transform3D).origin).length()
		var t_fore: float = ((ref[th] as Transform3D).origin - (ref[tel] as Transform3D).origin).length()
		var k := t_fore / maxf(s_fore, 0.0001)
		var gs: Transform3D = s_rest[sl]
		var g := Transform3D(gs.basis.orthonormalized(), (ref[th] as Transform3D).origin + (gs.origin - (s_rest[sh] as Transform3D).origin) * k)
		sockets["hand_" + side] = {"bone": map["hand." + side], "xf": (ref[th] as Transform3D).affine_inverse() * g, "k": k}
	lib.set_meta("sockets", sockets)
	print("sockets ", sockets)
	var fps := 30.0
	for want in clips.keys():
		var name: String = clips[want]
		var a_src := ap.get_animation(name)
		var anim := Animation.new()
		anim.length = a_src.length
		var tracks := {}
		for b in ts.get_bone_count():
			var bn := ts.get_bone_name(b)
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, NodePath(skel_path + ":" + bn))
			tracks[b] = tr
		var ptr := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(ptr, NodePath(skel_path + ":" + ts.get_bone_name(hip_t)))
		var n := int(ceil(a_src.length * fps)) + 1
		for i in n:
			var t := minf(float(i) / fps, a_src.length)
			ap.play(name)
			ap.seek(t, true)
			ap.pause()
			var gnew := {}
			for b in ts.get_bone_count():
				var parent := ts.get_bone_parent(b)
				var pg: Transform3D = gnew[parent] if parent >= 0 else Transform3D()
				var rest_local := ts.get_bone_rest(b)
				var g: Transform3D
				if t_of.has(b):
					var sb: int = t_of[b]
					var sp := ss.get_bone_global_pose(sb)
					var d: Basis = sp.basis.orthonormalized() * (s_rest[sb] as Transform3D).basis.orthonormalized().inverse()
					if turned:
						d = axes * d * axes.inverse()
					var basis: Basis = d * ref[b].basis.orthonormalized()
					var origin := pg * rest_local.origin
					if b == hip_t:
						origin = ref[b].origin + (axes * (sp.origin - s_rest[sb].origin) if turned else (sp.origin - s_rest[sb].origin)) * k_pos
					g = Transform3D(basis, origin)
				else:
					var bn := ts.get_bone_name(b)
					var local_basis: Basis
					if grip.has(b):
						local_basis = grip[b]
					elif KEEP_REST.any(func(s: String) -> bool: return s in bn) or parent < 0:
						local_basis = rest_local.basis.orthonormalized()
					else:
						var pref: Transform3D = ref[parent]
						local_basis = (pref.basis.orthonormalized().inverse() * ref[b].basis.orthonormalized())
					g = Transform3D(pg.basis.orthonormalized() * local_basis, pg * rest_local.origin)
				gnew[b] = g
				var lb: Basis = pg.basis.orthonormalized().inverse() * g.basis
				anim.rotation_track_insert_key(tracks[b], t, lb.get_rotation_quaternion())
				if b == hip_t:
					anim.position_track_insert_key(ptr, t, pg.affine_inverse() * g.origin)
		if want in ["idle", "walk", "run", "block"]:
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(want, anim)
		print("baked ", want, " <- ", name, " ", n, " frames")
	ResourceSaver.save(lib, args[2])
	quit()


func _descends(sk: Skeleton3D, b: int, anc: int) -> bool:
	var p := sk.get_bone_parent(b)
	while p >= 0:
		if p == anc:
			return true
		p = sk.get_bone_parent(p)
	return false
