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
	var map: Dictionary = MAPS[args[3]]
	var clips: Dictionary = JSON.parse_string(args[4]) if args.size() > 4 else {}
	await process_frame
	var ss := _skel(src)
	var ts := _skel(dst)
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	# Source bind = rest (KayKit exports rest == bind).
	var s_rest := {}
	for b in ss.get_bone_count():
		s_rest[b] = ss.get_bone_global_rest(b)
	# Target bind from the skin; bones missing from the skin fall back to rest.
	var t_bind := {}
	for b in ts.get_bone_count():
		t_bind[b] = ts.get_bone_global_rest(b)
	for m: MeshInstance3D in dst.find_children("*", "MeshInstance3D", true, false):
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
					var basis: Basis = d * ref[b].basis.orthonormalized()
					var origin := pg * rest_local.origin
					if b == hip_t:
						origin = ref[b].origin + (sp.origin - s_rest[sb].origin) * k_pos
					g = Transform3D(basis, origin)
				else:
					var bn := ts.get_bone_name(b)
					var local_basis: Basis
					if KEEP_REST.any(func(s: String) -> bool: return s in bn) or parent < 0:
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
