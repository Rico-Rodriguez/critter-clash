extends RefCounted
## The real parts a bred pet wears: the head, wings and tail it borrowed from a
## parent that isn't its body breed, lifted out of that parent's own model
## (core/pet_graft.gd) and hung on the body's skeleton so they move with it.
## The body's own part is cut out first (carve), so nothing doubles up. PBR is
## never touched (art lock: clean, crisp, no tint). A slot whose donor has no
## real part (GEN.donates) draws nothing: it stays data and card text.
## Nodes: BoneAttachment3D "Graft_<slot>" > Frame (canonical axes) > the meshes
## (wings: "Wing" pivots that flap). No class_name (OTA packs): preload by path.

const SDB := preload("res://src/data/sidekick_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")
const PG := preload("res://src/core/pet_graft.gd")

const FILL_LAYER := 1 << 19
## Wing span (both wings) and tail length, as a share of the body's own height.
const SPAN := 1.5
const TAIL := 0.7
const FLAP := 0.2


## The slots this def wears a donor's real part in: [[slot, donor], ...].
static func swaps(d: Dictionary) -> Array:
	var out := []
	var g: Dictionary = d.get("genes", {})
	if g.is_empty():
		return out
	var body := SDB.body_of(str(d.get("breed", "")))
	var parts: Dictionary = g.get("parts", {})
	for slot: String in GEN.PART_SLOTS:
		var donor := str(parts.get(slot, body))
		if donor != body and GEN.donates(donor, slot) and GEN.GRAFT.has(body):
			out.append([slot, donor])
	return out


## Cuts the body's own head / wings / tail out of its fresh model, for the
## slots that get a donor's. Call before the model is lit.
static func carve(model: Node3D, d: Dictionary) -> void:
	var slots := []
	for sw: Array in swaps(d):
		slots.append(sw[0])
	if slots.is_empty():
		return
	PG.carve(model, SDB.body_of(str(d.get("breed", ""))), slots)


## Mounts the donors' parts on the model.
static func attach(model: Node3D, d: Dictionary) -> void:
	var body := SDB.body_of(str(d.get("breed", "")))
	for sw: Array in swaps(d):
		var slot: String = sw[0]
		var part := PG.part(str(sw[1]), slot)
		if part.is_empty():
			continue
		var plan := _plan(body, slot, part)
		if plan.is_empty():
			continue
		var frame := _frame(model, body, str(plan["bone"]), slot, str(sw[1]))
		for it: Dictionary in plan["items"]:
			var holder: Node3D = frame
			if slot == "wings":
				var w := Node3D.new()
				w.name = "Wing"
				w.position = it["at"]
				w.set_meta("side", int(it["side"]))
				frame.add_child(w, true)
				holder = w
				w.tree_entered.connect(_flap.bind(w, int(it["side"])), CONNECT_ONE_SHOT)
			var mi := MeshInstance3D.new()
			mi.mesh = it["mesh"]
			mi.transform = it["xf"]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.layers = 1 | FILL_LAYER
			holder.add_child(mi)


## Where and how big each piece goes, in the body's canonical frame:
## {"bone": token, "items": [{"mesh", "side", "at": Vector3, "xf": Transform3D}]}.
static func _plan(body: String, slot: String, part: Dictionary) -> Dictionary:
	var bb := PG.bounds(body)
	var h := maxf(bb.size.y, 0.3)
	var items := []
	var bone := ""
	match slot:
		"head":
			var own := PG.part(body, "head")
			if own.is_empty():
				return {}
			bone = str(GEN.GRAFT[body]["head"].get("pivot", ""))
			var ob: AABB = own["aabb"]
			var pb: AABB = part["aabb"]
			var s := clampf(ob.size.length() / maxf(pb.size.length(), 0.01), 0.25, 5.0)
			var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), ob.get_center() - pb.get_center() * s)
			for it: Dictionary in part["items"]:
				items.append({"mesh": it["mesh"], "side": 0, "at": Vector3.ZERO, "xf": xf})
		"wings":
			bone = str(GEN.MOUNT[body]["wings"])
			var a := _anchor(body, bone, bb)
			var pb: AABB = part["aabb"]
			# A wing's reach: its span, or its length when it is folded along the body.
			var reach := maxf(pb.size.x * 0.5, pb.size.z)
			var s := clampf(maxf(SPAN * h * 0.5, bb.size.x * 1.1) / maxf(reach, 0.01), 0.2, 3.0)
			for it: Dictionary in part["items"]:
				var sd := int(it["side"])
				var piv: Vector3 = it["pivot"]
				var at := Vector3(sd * bb.size.x * 0.5 * 0.5, a.y, a.z)
				items.append({"mesh": it["mesh"], "side": sd, "at": at, "xf": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), -piv * s)})
		"tail":
			bone = str(GEN.MOUNT[body]["tail"])
			var a := _anchor(body, bone, bb)
			# A real tail bone is the root; a pelvis sits mid-body, so the tail starts at the rear.
			if not bone.contains("tail"):
				a.z = bb.position.z + 0.12 * bb.size.z
			var pb: AABB = part["aabb"]
			var s := clampf(TAIL * sqrt(h * bb.size.z) / maxf(pb.size.z, 0.01), 0.2, 3.0)
			var org: Vector3 = part["origin"]
			for it: Dictionary in part["items"]:
				items.append({"mesh": it["mesh"], "side": 0, "at": Vector3.ZERO, "xf": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), a - org * s)})
	return {"bone": bone, "items": items}


## The body's anchor for `token` (its bone, else the middle of the body).
static func _anchor(body: String, token: String, bb: AABB) -> Vector3:
	var b: Variant = PG.bone_xf(body, token)
	if b != null:
		var o: Vector3 = (b as Transform3D).origin
		return Vector3(0.0, o.y, o.z)
	return Vector3(0.0, bb.position.y + bb.size.y * 0.62, bb.get_center().z)


## The node the pieces hang on: a bone attachment (so they follow the pose)
## holding a frame that turns canonical axes into the bone's, or the model
## itself for one without a skeleton / bone.
static func _frame(model: Node3D, body: String, bone: String, slot: String, donor: String) -> Node3D:
	var frame := Node3D.new()
	frame.name = "Frame"
	var skel: Skeleton3D = null
	for c in model.find_children("*", "Skeleton3D", true, false):
		skel = c as Skeleton3D
		break
	var bn := PG.bone_name(model, bone)
	var b: Variant = PG.bone_xf(body, bone)
	var holder: Node3D
	if skel != null and bn != "" and b != null:
		var att := BoneAttachment3D.new()
		att.bone_name = bn
		holder = att
		skel.add_child(att)
		frame.transform = (b as Transform3D).affine_inverse()
	else:
		holder = Node3D.new()
		model.add_child(holder)
		frame.transform = Transform3D(PG.yaw(body).inverse(), Vector3.ZERO)
	holder.name = "Graft_" + slot
	holder.set_meta("donor", donor)
	holder.add_child(frame)
	return holder.get_child(0) as Node3D


static func _flap(w: Node3D, side: int) -> void:
	var tw := w.create_tween().set_loops()
	tw.tween_property(w, "rotation:z", side * FLAP, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(w, "rotation:z", -side * FLAP * 0.5, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
