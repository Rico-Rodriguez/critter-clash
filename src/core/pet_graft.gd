extends RefCounted
## Real parts for bred pets: lifts a head, a pair of wings or a tail out of a
## donor species' own model (its textured mesh and its own PBR, untouched: art
## lock) as plain static meshes in the donor's model space (the 1 m wrapped
## scene, idle clip first frame). Which triangles belong to a part comes from
## GEN.GRAFT: the bones (or mesh names) that own them. `carve` removes the
## receiver's own part so nothing doubles up. Pure and cached; core/pet_parts.gd
## mounts the results. Every position here is in the species' "canonical"
## frame: its model space turned by GEN.GRAFT_YAW so it faces +Z. No class_name
## (OTA packs): preload by path.

const SDB := preload("res://src/data/sidekick_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")
const SF_DIR := "res://assets/sidekicks/"

static var _posed := {}
static var _parts := {}
static var _carved := {}
static var _bounds := {}


## The turn (about Y) that makes a species' model face +Z.
static func yaw(sp: String) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(float(GEN.GRAFT_YAW.get(sp, 0.0))))


## Every bone's model-space transform (lower-case name) on the idle pose.
static func bones(sp: String) -> Dictionary:
	if _posed.has(sp):
		return _posed[sp]
	var out := {}
	var model := _instance(sp)
	if model != null:
		_pose_idle(model, sp)
		var skel := _skeleton(model)
		if skel != null:
			var sx := Transform3D(yaw(sp), Vector3.ZERO) * _rel(skel, model)
			for i in skel.get_bone_count():
				out[skel.get_bone_name(i).to_lower()] = sx * skel.get_bone_global_pose(i)
		model.free()
	_posed[sp] = out
	return out


## A species' bone (lower-case name containing `token`) in model space, or null.
static func bone_xf(sp: String, token: String) -> Variant:
	var b: Dictionary = bones(sp)
	if token == "":
		return null
	if b.has(token):
		return b[token]
	for k: String in b:
		if k.contains(token):
			return b[k]
	return null


## The bone's full name for a token (the receiver's BoneAttachment3D needs it).
static func bone_name(model: Node, token: String) -> String:
	var skel := _skeleton(model)
	if skel == null or token == "":
		return ""
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		if n.to_lower() == token:
			return n
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		if n.to_lower().contains(token):
			return n
	return ""


static func _instance(sp: String) -> Node3D:
	if not SDB.ROSTER.has(sp):
		return null
	var spec := str(SDB.ROSTER[sp]["model"])
	if not spec.begins_with("sf:"):
		return null
	var path := SF_DIR + spec.substr(3) + ".tscn"
	if not ResourceLoader.exists(path):
		return null
	return (KK.scene(path) as PackedScene).instantiate()


static func _skeleton(model: Node) -> Skeleton3D:
	for c in model.find_children("*", "Skeleton3D", true, false):
		return c as Skeleton3D
	return null


## `n`'s transform relative to `model` (the model itself is identity).
static func _rel(n: Node, model: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != model:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Poses the model on its idle clip's first frame without a scene tree: reads
## each 3D track's value at t=0 and sets it on the bone or node it drives.
static func _pose_idle(model: Node3D, sp: String) -> void:
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if ap == null:
		return
	var want := str(SDB.CLIPS.get(sp, {}).get("idle", ""))
	var clip := ""
	for n: String in ap.get_animation_list():
		if want != "" and (n == want or n.ends_with("|" + want) or n.ends_with("/" + want)):
			clip = n
			break
	if clip == "" and ap.get_animation_list().size() > 0:
		clip = ap.get_animation_list()[0]
	if clip == "":
		return
	var anim := ap.get_animation(clip)
	var base: Node = ap.get_node_or_null(ap.root_node)
	if base == null:
		base = model
	for t in anim.get_track_count():
		var ty := anim.track_get_type(t)
		if ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_SCALE_3D:
			continue
		var p := anim.track_get_path(t)
		var node := base.get_node_or_null(NodePath(p.get_concatenated_names()))
		if node == null:
			continue
		var bone := p.get_concatenated_subnames()
		if node is Skeleton3D and bone != "":
			var sk := node as Skeleton3D
			var bi := sk.find_bone(bone)
			if bi < 0:
				continue
			match ty:
				Animation.TYPE_POSITION_3D:
					sk.set_bone_pose_position(bi, anim.position_track_interpolate(t, 0.0))
				Animation.TYPE_ROTATION_3D:
					sk.set_bone_pose_rotation(bi, anim.rotation_track_interpolate(t, 0.0))
				_:
					sk.set_bone_pose_scale(bi, anim.scale_track_interpolate(t, 0.0))
		elif node is Node3D and bone == "":
			var n3 := node as Node3D
			match ty:
				Animation.TYPE_POSITION_3D:
					n3.position = anim.position_track_interpolate(t, 0.0)
				Animation.TYPE_ROTATION_3D:
					n3.quaternion = anim.rotation_track_interpolate(t, 0.0)
				_:
					n3.scale = anim.scale_track_interpolate(t, 0.0)


static func _has_token(name_: String, tokens: Array) -> bool:
	var l := name_.to_lower()
	for t: String in tokens:
		if l.contains(t):
			return true
	return false


## Which of a surface's vertices the spec owns, and where they sit (and face)
## in model space on the idle pose. {"sel": PackedByteArray, "pos", "nrm", "tan"}.
static func _vertex_data(model: Node3D, mi: MeshInstance3D, arrays: Array, spec: Dictionary, rot := Basis.IDENTITY) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := verts.size()
	var nrm_in: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var tan_in: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var sel := PackedByteArray()
	sel.resize(n)
	var pos := PackedVector3Array()
	pos.resize(n)
	var nrm := PackedVector3Array()
	nrm.resize(n)
	var tan := PackedFloat32Array()
	tan.resize(tan_in.size())
	var by_mesh := _has_token(str(mi.name), spec.get("meshes", []))
	var inc: Array = spec.get("bones", [])
	var exc: Array = spec.get("not", [])
	var bi_arr: Variant = arrays[Mesh.ARRAY_BONES]
	var wt_arr: Variant = arrays[Mesh.ARRAY_WEIGHTS]
	var skel: Skeleton3D = null
	if mi.skin != null and not mi.skeleton.is_empty():
		skel = mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skel != null and bi_arr != null and (bi_arr as PackedInt32Array).size() >= n and wt_arr != null:
		var bi_a: PackedInt32Array = bi_arr
		var wt_a: PackedFloat32Array = wt_arr
		var stride := bi_a.size() / n
		var sx := Transform3D(rot, Vector3.ZERO) * _rel(skel, model)
		var skin := mi.skin
		var bm: Array[Transform3D] = []
		var hit := PackedByteArray()
		for b in skin.get_bind_count():
			var bn := skin.get_bind_name(b)
			var bone := skel.find_bone(bn) if bn != "" else skin.get_bind_bone(b)
			if bone < 0:
				bm.append(Transform3D.IDENTITY)
				hit.append(0)
				continue
			bm.append(sx * skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
			var nm := skel.get_bone_name(bone)
			hit.append(1 if _has_token(nm, inc) and not _has_token(nm, exc) else 0)
		for v in n:
			var p := Vector3.ZERO
			var nn := Vector3.ZERO
			var tt := Vector3.ZERO
			var w := 0.0
			for k in stride:
				var wt := wt_a[v * stride + k]
				if wt <= 0.0:
					continue
				var b := bi_a[v * stride + k]
				if b >= bm.size():
					continue
				var m := bm[b]
				p += (m * verts[v]) * wt
				if nrm_in.size() > v:
					nn += (m.basis * nrm_in[v]) * wt
				if tan_in.size() >= 4 * v + 4:
					tt += (m.basis * Vector3(tan_in[4 * v], tan_in[4 * v + 1], tan_in[4 * v + 2])) * wt
				if hit[b] == 1:
					w += wt
			pos[v] = p
			nrm[v] = nn.normalized()
			if tan.size() >= 4 * v + 4:
				var tn := tt.normalized()
				tan[4 * v] = tn.x
				tan[4 * v + 1] = tn.y
				tan[4 * v + 2] = tn.z
				tan[4 * v + 3] = tan_in[4 * v + 3]
			sel[v] = 1 if (w >= 0.5 or by_mesh) else 0
	else:
		var xf := Transform3D(rot, Vector3.ZERO) * _rel(mi, model)
		for v in n:
			pos[v] = xf * verts[v]
			if nrm_in.size() > v:
				nrm[v] = (xf.basis * nrm_in[v]).normalized()
			if tan.size() >= 4 * v + 4:
				var tn := (xf.basis * Vector3(tan_in[4 * v], tan_in[4 * v + 1], tan_in[4 * v + 2])).normalized()
				tan[4 * v] = tn.x
				tan[4 * v + 1] = tn.y
				tan[4 * v + 2] = tn.z
				tan[4 * v + 3] = tan_in[4 * v + 3]
			sel[v] = 1 if by_mesh else 0
	return {"sel": sel, "pos": pos, "nrm": nrm, "tan": tan}


static func _indices(arrays: Array, n: int) -> PackedInt32Array:
	if arrays[Mesh.ARRAY_INDEX] != null and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
		return arrays[Mesh.ARRAY_INDEX]
	var idx := PackedInt32Array()
	idx.resize(n)
	for i in n:
		idx[i] = i
	return idx


static func _lit(mat: Material, sp: String) -> Material:
	if mat is BaseMaterial3D:
		var SKL = load("res://src/core/sidekick_look.gd")
		if SKL == null:
			return mat
		return SKL.lit_material(mat as BaseMaterial3D, str(SDB.ROSTER[sp]["model"]).substr(3) in SKL.KEEP_EMISSION)
	return mat


## The part `slot` of species `sp`: {"items": [{"mesh": ArrayMesh, "side": -1|0|1,
## "pivot": Vector3}], "aabb": AABB, "origin": Vector3} in model space, or {}
## when the spec has none / the model can't give it.
static func part(sp: String, slot: String) -> Dictionary:
	var key := sp + "/" + slot
	if _parts.has(key):
		return _parts[key]
	var out := {}
	var spec: Dictionary = (GEN.GRAFT.get(sp, {}) as Dictionary).get(slot, {})
	if not spec.is_empty():
		out = _extract(sp, spec)
	_parts[key] = out
	return out


static func _extract(sp: String, spec: Dictionary) -> Dictionary:
	var model := _instance(sp)
	if model == null:
		return {}
	_pose_idle(model, sp)
	var pieces := []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vd := _vertex_data(model, mi, arrays, spec, yaw(sp))
			var piece := _pick(arrays, vd, true)
			if piece.is_empty():
				continue
			piece["mat"] = _lit(mi.get_active_material(s), sp)
			pieces.append(piece)
	model.free()
	if pieces.is_empty():
		return {}
	var origin := Vector3.ZERO
	var ob: Variant = bone_xf(sp, str(spec.get("pivot", "")))
	if ob != null:
		origin = (ob as Transform3D).origin
	var items := []
	var all := AABB()
	var first := true
	for piece: Dictionary in pieces:
		var groups: Array = _split_sides(piece) if bool(spec.get("split", false)) else [piece]
		for g: Dictionary in groups:
			var mesh := _mesh_of(g)
			if mesh == null:
				continue
			var bb := mesh.get_aabb()
			var pv := origin
			if int(g.get("side", 0)) != 0:
				pv = Vector3(float(g["side"]) * _min_abs_x(g["pos"]), origin.y, origin.z)
			items.append({"mesh": mesh, "side": int(g.get("side", 0)), "pivot": pv})
			all = bb if first else all.merge(bb)
			first = false
	if items.is_empty():
		return {}
	return {"items": items, "aabb": all, "origin": origin}


static func _min_abs_x(pos: PackedVector3Array) -> float:
	var m := 1e9
	for p in pos:
		m = minf(m, absf(p.x))
	return m


## The triangles with at least two selected corners (`keep` = true) or with
## fewer (false), as a compact piece: pos, nrm, uv, uv2, tan, idx.
static func _pick(arrays: Array, vd: Dictionary, keep: bool) -> Dictionary:
	var pos: PackedVector3Array = vd["pos"]
	var n := pos.size()
	var sel: PackedByteArray = vd["sel"]
	var idx := _indices(arrays, n)
	var remap := PackedInt32Array()
	remap.resize(n)
	remap.fill(-1)
	var out_idx := PackedInt32Array()
	var order := PackedInt32Array()
	for t in idx.size() / 3:
		var a := idx[3 * t]
		var b := idx[3 * t + 1]
		var c := idx[3 * t + 2]
		var cnt := int(sel[a]) + int(sel[b]) + int(sel[c])
		if (cnt >= 2) != keep:
			continue
		for v in [a, b, c]:
			if remap[v] < 0:
				remap[v] = order.size()
				order.append(v)
			out_idx.append(remap[v])
	if out_idx.is_empty():
		return {}
	var nrm: PackedVector3Array = vd["nrm"]
	var tan: PackedFloat32Array = vd["tan"]
	var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: Variant = arrays[Mesh.ARRAY_TEX_UV2]
	var o_pos := PackedVector3Array()
	var o_nrm := PackedVector3Array()
	var o_tan := PackedFloat32Array()
	var o_uv := PackedVector2Array()
	var o_uv2 := PackedVector2Array()
	for v in order:
		o_pos.append(pos[v])
		o_nrm.append(nrm[v])
		if uv != null:
			o_uv.append((uv as PackedVector2Array)[v])
		if uv2 != null:
			o_uv2.append((uv2 as PackedVector2Array)[v])
		if tan.size() >= 4 * v + 4:
			for k in 4:
				o_tan.append(tan[4 * v + k])
	return {"idx": out_idx, "pos": o_pos, "nrm": o_nrm, "tan": o_tan, "uv": o_uv, "uv2": o_uv2}


## Splits a piece into its +x and -x triangles (by centroid), each with side = +-1.
static func _split_sides(piece: Dictionary) -> Array:
	var pos: PackedVector3Array = piece["pos"]
	var idx: PackedInt32Array = piece["idx"]
	var uv: PackedVector2Array = piece["uv"]
	var uv2: PackedVector2Array = piece["uv2"]
	var out := []
	for side in [-1, 1]:
		var sel := PackedByteArray()
		sel.resize(pos.size())
		for t in idx.size() / 3:
			var cx := (pos[idx[3 * t]].x + pos[idx[3 * t + 1]].x + pos[idx[3 * t + 2]].x) / 3.0
			if (cx > 0.0) == (side > 0):
				for k in 3:
					sel[idx[3 * t + k]] = 1
		var vd := {"pos": pos, "nrm": piece["nrm"], "tan": piece["tan"], "sel": sel}
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_INDEX] = idx
		arrays[Mesh.ARRAY_TEX_UV] = uv if uv.size() > 0 else null
		arrays[Mesh.ARRAY_TEX_UV2] = uv2 if uv2.size() > 0 else null
		var sub := _pick(arrays, vd, true)
		if sub.is_empty():
			continue
		sub["side"] = side
		sub["mat"] = piece["mat"]
		out.append(sub)
	return out


static func _mesh_of(piece: Dictionary) -> ArrayMesh:
	if piece.is_empty() or (piece["pos"] as PackedVector3Array).size() < 3:
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = piece["pos"]
	arrays[Mesh.ARRAY_NORMAL] = piece["nrm"]
	if (piece["uv"] as PackedVector2Array).size() > 0:
		arrays[Mesh.ARRAY_TEX_UV] = piece["uv"]
	if (piece["uv2"] as PackedVector2Array).size() > 0:
		arrays[Mesh.ARRAY_TEX_UV2] = piece["uv2"]
	if (piece["tan"] as PackedFloat32Array).size() > 0:
		arrays[Mesh.ARRAY_TANGENT] = piece["tan"]
	arrays[Mesh.ARRAY_INDEX] = piece["idx"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, piece["mat"])
	return m


## The body without its swappable parts: the canonical bounds of every vertex no
## slot spec of `sp` owns (a flying pet's span doesn't count its wings).
static func bounds(sp: String) -> AABB:
	if _bounds.has(sp):
		return _bounds[sp]
	var out := AABB()
	var model := _instance(sp)
	if model != null:
		_pose_idle(model, sp)
		var specs := _specs(sp, GEN.PART_SLOTS)
		var first := true
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				var sel := _owned(model, mi, arrays, specs)
				var vd := _vertex_data(model, mi, arrays, {"bones": [], "meshes": []}, yaw(sp))
				var pos: PackedVector3Array = vd["pos"]
				for v in pos.size():
					if sel[v] == 0:
						out = AABB(pos[v], Vector3.ZERO) if first else out.expand(pos[v])
						first = false
		model.free()
	_bounds[sp] = out
	return out


static func _specs(sp: String, slots: Array) -> Array:
	var out := []
	for slot: String in slots:
		var spec: Dictionary = (GEN.GRAFT.get(sp, {}) as Dictionary).get(slot, {})
		if not spec.is_empty():
			out.append(spec)
	return out


## 1 where any of `specs` owns the vertex.
static func _owned(model: Node3D, mi: MeshInstance3D, arrays: Array, specs: Array) -> PackedByteArray:
	var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var sel := PackedByteArray()
	sel.resize(n)
	for spec: Dictionary in specs:
		var one: PackedByteArray = _vertex_data(model, mi, arrays, spec)["sel"]
		for v in n:
			if one[v] == 1:
				sel[v] = 1
	return sel


## Cuts the receiver's own `slots` out of its (just instanced) model, so a
## borrowed part replaces them instead of sitting over them. Meshes are built
## once per species and slot set, skin and materials kept; a mesh that is
## wholly the part (the mimic's lid) is hidden.
static func carve(model: Node3D, sp: String, slots: Array) -> void:
	var specs := _specs(sp, slots)
	if specs.is_empty():
		return
	var key := sp + "|" + ",".join(slots)
	var cache: Dictionary = _carved.get(key, {})
	var fresh := cache.is_empty()
	# Selection runs on a private copy posed like extraction does.
	var probe: Node3D = _instance(sp)
	if probe != null and fresh:
		_pose_idle(probe, sp)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var path := str(model.get_path_to(mi))
		if fresh:
			cache[path] = _carve_mesh(probe, probe.get_node_or_null(NodePath(path)) as MeshInstance3D, specs)
		var m: Variant = cache.get(path, "keep")
		if m is ArrayMesh:
			var old := mi.mesh
			mi.mesh = m
			for s in old.get_surface_count():
				mi.mesh.surface_set_material(s, old.surface_get_material(s))
		elif str(m) == "hide":
			mi.visible = false
	if probe != null:
		probe.free()
	_carved[key] = cache


## The flags add_surface_from_arrays needs to take a surface's arrays back:
## 8 bone weights and each custom channel's format. Without the custom formats
## a model with CUSTOM0-3 data is refused ("Invalid array format for surface")
## and that surface goes missing from the carved mesh.
static func _rebuild_flags(fmt: int) -> int:
	var flags := fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	for sh in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
		flags |= fmt & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << int(sh))
	return flags


## The mesh without the triangles the specs own; "keep" when it has none and
## "hide" when nothing would be left.
static func _carve_mesh(model: Node3D, mi: MeshInstance3D, specs: Array) -> Variant:
	if mi == null:
		return "keep"
	var out := ArrayMesh.new()
	var kept_any := false
	var touched := false
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var sel := _owned(model, mi, arrays, specs)
		var idx := _indices(arrays, n)
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			var c := int(sel[idx[3 * t]]) + int(sel[idx[3 * t + 1]]) + int(sel[idx[3 * t + 2]])
			if c < 2:
				keep.append_array(idx.slice(3 * t, 3 * t + 3))
		if keep.size() == idx.size():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _rebuild_flags(mi.mesh.surface_get_format(s)))
			kept_any = true
			continue
		touched = true
		if keep.is_empty():
			keep = PackedInt32Array([0, 0, 0])
		else:
			kept_any = true
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _rebuild_flags(mi.mesh.surface_get_format(s)))
	if not touched:
		return "keep"
	if not kept_any:
		return "hide"
	out.custom_aabb = mi.mesh.get_aabb()
	return out
