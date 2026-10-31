extends RefCounted
## How a bred pet shows the head, wings and tail it inherited from a parent that
## isn't its body breed. The pet stays its body parent, one whole animal: the
## inherited region takes the donor's colours (pet_graft.regions marks it,
## fx/pet_skin.gdshader recolours it) and wears a small designed trait of the
## donor's (horns, a crest, a lure...; tools/blender/pets/traits.py). A body
## without that part (a mimic's wings) wears only the trait. A slot whose donor
## has no real part (GEN.donates) draws nothing: it stays data and card text.
## Nodes: BoneAttachment3D "Graft_<slot>" > Frame (canonical axes) > the trait.
## No class_name (OTA packs): preload by path.

const SDB := preload("res://src/data/sidekick_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")
const PG := preload("res://src/core/pet_graft.gd")

const FILL_LAYER := 1 << 19
const TRAITS := "res://assets/sidekicks/pet_traits.glb"
## Trait size, as a share of what it sits on: the head's width, the back's
## width, the body's length.
const HEAD := 0.55
const WINGS := 0.8
const TAIL := 0.35

static var _trait_meshes := {}


## The slots this def inherits from a donor that has that part: [[slot, donor], ...].
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


## Marks the body's own regions for the slots it inherited, before the model
## is lit (the colours themselves are tints() on the skin).
static func regions(model: Node3D, d: Dictionary) -> void:
	var body := SDB.body_of(str(d.get("breed", "")))
	for sw: Array in swaps(d):
		if (GEN.GRAFT[body] as Dictionary).has(sw[0]):
			PG.regions(model, body)
			return


## The skin's recolour per inherited region the body has: {slot: Color}, rgb
## the donor's colour for that part and a its body's own brightness there.
static func tints(d: Dictionary) -> Dictionary:
	var out := {}
	var body := SDB.body_of(str(d.get("breed", "")))
	for sw: Array in swaps(d):
		var own := str((GEN.REGION_COLOR.get(body, {}) as Dictionary).get(sw[0], ""))
		var donor := str((GEN.REGION_COLOR.get(str(sw[1]), {}) as Dictionary).get(sw[0], ""))
		if own == "" or donor == "":
			continue
		var o := Color.html(own).srgb_to_linear()
		var c := Color.html(donor).srgb_to_linear()
		out[sw[0]] = Color(c.r, c.g, c.b, maxf(o.get_luminance(), 0.02))
	return out


## Mounts each inherited part's trait on the model.
static func attach(model: Node3D, d: Dictionary) -> void:
	var body := SDB.body_of(str(d.get("breed", "")))
	for sw: Array in swaps(d):
		var slot: String = sw[0]
		var mesh := trait_mesh(str(sw[1]), slot)
		if mesh == null:
			continue
		var at := _place(body, slot)
		var frame := _frame(model, body, str(at["bone"]), slot, str(sw[1]))
		var mi := MeshInstance3D.new()
		mi.name = "Trait"
		mi.mesh = mesh
		mi.transform = at["xf"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.layers = 1 | FILL_LAYER
		frame.add_child(mi)


## The donor's designed trait for `slot` (null when it has none).
static func trait_mesh(donor: String, slot: String) -> Mesh:
	if _trait_meshes.is_empty():
		var sc := load(TRAITS) as PackedScene
		if sc != null:
			var n := sc.instantiate()
			for c in n.find_children("*", "MeshInstance3D", true, false):
				_trait_meshes[str(c.name)] = (c as MeshInstance3D).mesh
			n.free()
	return _trait_meshes.get(donor + "_" + slot)


## Where a trait sits on `body` and how big: {"bone": token, "xf": Transform3D}
## in the body's canonical frame (+Z forward, +Y up, metres of its idle pose).
static func _place(body: String, slot: String) -> Dictionary:
	var bb := PG.bounds(body)
	var own := PG.region_box(body, slot)
	var has_own := own.size != Vector3.ZERO
	var at := Vector3.ZERO
	var size := 1.0
	var bone := ""
	match slot:
		"head":
			var box := own if has_own else AABB(bb.position + Vector3(0, bb.size.y * 0.7, bb.size.z * 0.5), bb.size * Vector3(1, 0.3, 0.5))
			bone = str((GEN.GRAFT[body]["head"]["bones"] as Array)[0]) if has_own else str(GEN.MOUNT[body]["wings"])
			at = Vector3(box.get_center().x, box.end.y - box.size.y * 0.08, box.get_center().z)
			size = maxf(box.size.x, bb.size.x * 0.35) * HEAD
		"wings":
			bone = str(GEN.MOUNT[body]["wings"])
			at = _anchor(body, bone, bb)
			at.y = maxf(at.y, bb.position.y + bb.size.y * 0.55)
			size = bb.size.x * WINGS
		"tail":
			if has_own:
				bone = _last_bone(body, "tail")
				at = Vector3(own.get_center().x, own.get_center().y, own.position.z + own.size.z * 0.08)
			else:
				bone = str(GEN.MOUNT[body]["tail"])
				at = _anchor(body, bone, bb)
				if not bone.contains("tail"):
					at.z = bb.position.z + 0.12 * bb.size.z
			size = bb.size.z * TAIL
	return {"bone": bone, "xf": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at)}


## The last bone in a chain (the tail's tip): the highest-numbered match.
static func _last_bone(body: String, token: String) -> String:
	var best := ""
	for k: String in PG.bones(body):
		if k.contains(token) and k > best:
			best = k
	return best


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
