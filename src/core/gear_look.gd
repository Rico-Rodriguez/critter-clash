class_name GearLook
extends RefCounted
## Dresses a hero in what it wears. KayKit characters share one skeleton, so
## their body parts can be lifted from one character onto another: a Knight in
## the Mage's hat, a Barbarian in the Ranger's tunic. Which parts, which dye
## and which weapon model each piece shows is decided by GearDB; this file only
## does the dressing. With nothing equipped a hero wears its class's own
## outfit and the first weapon, helm and offhand of its line, so a new Knight
## looks like a knight; `preview` with an empty slot shows it truly bare.
##
## `apply` can take `preview` ({slot: item}) to show a piece the player has not
## equipped yet, which is how the equipment screen lets you try things on.

## Glow color (alpha = strength) by rarity; common gear shows no glow.
const GLOW := {
	"common": Color(0.0, 0.0, 0.0, 0.0),
	"magic": Color(0.42, 0.62, 1.0, 0.13),
	"rare": Color(1.0, 0.84, 0.32, 0.19),
	"legendary": Color(1.0, 0.5, 0.15, 0.28),
}


static func glow_of(item: Dictionary, boost := 1.0) -> Color:
	if item.is_empty():
		return Color(0, 0, 0, 0)
	var c: Color = GLOW[item["rarity"]]
	return Color(c.r, c.g, c.b, c.a * boost)


## Set around an `apply` call ({"outfit": k, "skin": k}) to show a look the hero does not own,
## as the shop's preview does. Empty otherwise.
static var look_override := {}


static func _look(key: String, hero_id: String) -> String:
	return str(look_override[key]) if look_override.has(key) else str(Game.hero(hero_id).get(key, ""))


## Re-dresses `actor` (built from DB.HEROES[hero_id]). `preview` replaces what
## is worn in the slots it names (an empty dictionary there means "bare").
static func apply(actor: Actor, hero_id: String, preview := {}) -> void:
	var skel: Skeleton3D = actor.model.find_child("Skeleton3D", true, false)
	var worn := {}
	var starter := {}
	for slot in DB.SLOTS:
		worn[slot] = preview[slot] if preview.has(slot) else Game.equipped(hero_id, slot)
		starter[slot] = worn[slot].is_empty() and not preview.has(slot)
		if starter[slot] and slot in ["weapon", "helm", "trinket"]:
			worn[slot] = {"slot": slot, "cls": hero_id, "mat": 0, "rarity": "common", "unique": "", "stats": {}}
	var own_head := "%s_Head" % DB.HEROES[hero_id]["model"].replace("Rogue_Hooded", "RogueHooded")
	# Everything dressable goes away, then the wanted parts come back.
	for mi in skel.get_children():
		if mi is MeshInstance3D and mi.name != own_head:
			mi.visible = false
		elif mi is BoneAttachment3D and str(mi.name).begins_with("Part_"):
			for c in mi.get_children():
				(c as Node3D).visible = false
	var head := skel.get_node_or_null(own_head) as MeshInstance3D
	if head:
		head.visible = true
	var basic := Color(GearDB.BASIC_DYE)
	var own: String = DB.HEROES[hero_id]["model"]
	_dress(actor, skel, hero_id, worn["chest"], "chest", ["T:" + own] if starter["chest"] else ["T:Rogue_Hooded"], Color(0, 0, 0, 0) if starter["chest"] else basic)
	_dress(actor, skel, hero_id, worn["legs"], "legs", ["L:" + own] if starter["legs"] else ["L:Rogue_Hooded"], Color(0, 0, 0, 0) if starter["legs"] else basic)
	_dress(actor, skel, hero_id, worn["helm"], "helm", [], Color(0, 0, 0, 0))
	if not worn["trinket"].is_empty() and GearDB.piece(worn["trinket"]).has("parts"):
		_dress(actor, skel, hero_id, worn["trinket"], "trinket", [], Color(0, 0, 0, 0))
	if head and not _hood_on(worn["helm"], hero_id):
		head.visible = true
	_hands(actor, skel, hero_id, worn)
	_outfit(actor, skel, _look("outfit", hero_id))


## The worn outfit's dye over every body part: what the hero wears keeps its
## shape and its own light and dark, the cloth takes the color. Heads, weapons
## and hands-held props keep their own colors.
static func _outfit(actor: Actor, skel: Skeleton3D, key: String) -> void:
	if not DB.OUTFITS.has(key):
		return
	var o: Dictionary = DB.OUTFITS[key]
	var dye: Color = o["dye"]
	var grade := Vector4(float(o["polish"]), float(o["shimmer"]), 0.0, 0.0)
	for mi: MeshInstance3D in _body_meshes(skel):
		mi.set_instance_shader_parameter("dye", Color(dye, float(o["mix"])))
		mi.set_instance_shader_parameter("grade", grade)
		mi.set_instance_shader_parameter("accent", dye.lightened(0.35))


## Visible dressable meshes on the skeleton, not the head and not what is held.
static func _body_meshes(skel: Skeleton3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in skel.get_children():
		if c is MeshInstance3D and c.visible and not str(c.name).ends_with("_Head"):
			out.append(c)
		elif c is BoneAttachment3D and str(c.name).begins_with("Part_"):
			for m in c.get_children():
				if m is MeshInstance3D and m.visible:
					out.append(m)
	return out


static func _hood_on(item: Dictionary, hero_id: String) -> bool:
	return not item.is_empty() and bool(GearDB.look(item)["hood"])


static func _dress(actor: Actor, skel: Skeleton3D, hero_id: String, item: Dictionary, slot: String, fallback: Array, fallback_dye: Color) -> void:
	var parts: Array = fallback
	var dye := fallback_dye
	var glow := Color(0, 0, 0, 0)
	var hood := false
	if not item.is_empty():
		var lk := GearDB.look(item)
		parts = lk["parts"]
		dye = lk["dye"]
		hood = lk["hood"]
		glow = glow_of(item)
	var gr := GearDB.grade(item)
	var acc := GearDB.accent(item)
	parts = GearDB.expand(parts)
	for spec: String in parts:
		var mi := _part(actor, skel, spec)
		if mi == null:
			continue
		mi.visible = true
		# Our own props carry their colors; only lifted KayKit parts take the dye.
		var da := 0.0 if spec.begins_with("P:") else dye.a * (0.4 if hood else 1.0)
		mi.set_instance_shader_parameter("dye", Color(dye, da))
		mi.set_instance_shader_parameter("tint", glow)
		mi.set_instance_shader_parameter("grade", gr)
		mi.set_instance_shader_parameter("accent", acc)
	if hood:
		var own := skel.get_node_or_null("%s_Head" % DB.HEROES[hero_id]["model"].replace("Rogue_Hooded", "RogueHooded")) as MeshInstance3D
		# The Rogue's hood IS her own head mesh: hiding it would leave her headless.
		if own and not (parts as Array).any(func(sp): return _part(actor, skel, sp) == own):
			own.visible = false


## The mesh for a part spec like "Mage/Hat": the hero's own if it has one by
## that name, otherwise lifted from the other character's file (once).
static func _part(actor: Actor, skel: Skeleton3D, spec: String) -> MeshInstance3D:
	var reg: Dictionary = actor.get_meta("gl_parts", {})
	actor.set_meta("gl_parts", reg)
	if reg.has(spec) and is_instance_valid(reg[spec]):
		return reg[spec]
	if spec.begins_with("P:"):
		reg[spec] = _prop_part(actor, skel, spec)
		return reg[spec]
	var nm := GearDB.mesh_name(spec)
	var found := skel.get_node_or_null(nm) as MeshInstance3D
	if found == null:
		var src := spec.get_slice("/", 0)
		var sc: Node = KK.scene(KK.CHAR_DIR + src + ".glb").instantiate()
		var mi := sc.find_child(nm, true, false) as MeshInstance3D
		if mi == null:
			sc.free()
			return null
		# Hats, hoods and capes on the skeletons are rigid, pinned to a bone,
		# not skinned: they go on a bone attachment of their own.
		var bone := ""
		if mi.get_parent() is BoneAttachment3D:
			bone = (mi.get_parent() as BoneAttachment3D).bone_name
		var xf := mi.transform
		mi.get_parent().remove_child(mi)
		sc.free()
		if bone != "":
			var att := BoneAttachment3D.new()
			att.name = "Part_" + nm
			att.bone_name = bone
			skel.add_child(att)
			att.add_child(mi)
			mi.transform = xf.translated(GearDB.PART_NUDGE.get(spec, Vector3.ZERO))
		else:
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
		actor.restyle(skel)
		found = mi
	reg[spec] = found
	return found


## A "P:file@bone" part: one of our rigid props (assets/kaykit/gear/),
## pinned to a bone on an attachment of its own.
static func _prop_part(actor: Actor, skel: Skeleton3D, spec: String) -> MeshInstance3D:
	var file := spec.substr(2).get_slice("@", 0)
	var bone := spec.get_slice("@", 1)
	var sc := KK.prop(GearDB.GEAR_DIR + file)
	var mi: MeshInstance3D = KK.meshes(sc)[0] if not KK.meshes(sc).is_empty() else null
	if mi == null:
		sc.free()
		return null
	var xf := mi.transform
	mi.get_parent().remove_child(mi)
	sc.free()
	var att := BoneAttachment3D.new()
	att.name = "Part_%s_%s" % [file.get_basename(), bone.replace(".", "_")]
	att.bone_name = bone
	skel.add_child(att)
	att.add_child(mi)
	mi.transform = xf
	actor.restyle(att)
	return mi


## Weapon in the main hand, offhand piece in the other (or on the back).
static func _hands(actor: Actor, skel: Skeleton3D, hero_id: String, worn: Dictionary) -> void:
	var line: Dictionary = GearDB.LINES[hero_id]
	var w: Dictionary = worn["weapon"]
	var file: String = line["starter"]
	var scale_ := 1.0
	var dye := Color(0, 0, 0, 0)
	if not w.is_empty():
		var lk := GearDB.look(w)
		file = lk["model"]
		scale_ = lk["scale"]
		dye = lk["dye"]
	var sk := _look("skin", hero_id)
	if DB.WEAPON_SKINS.has(sk):
		file = DB.WEAPON_SKINS[sk]["model"]
		scale_ = DB.WEAPON_SKINS[sk]["scale"]
		dye = Color(0, 0, 0, 0)
	var glow := glow_of(w, 1.2)
	# A bought or earned weapon glow outshines the rarity glow.
	var hg := str(Game.hero(hero_id).get("glow", ""))
	if DB.GLOWS.has(hg):
		glow = DB.GLOWS[hg]["color"]
	var fam := Game.weapon_family(hero_id, {"weapon": w})
	var hold := GearDB.weapon_hold(hero_id, fam)
	_hold(actor, skel, "GearMain", hold["bone"], file, scale_, dye, glow, hold["xf"], GearDB.grade(w), GearDB.accent(w))
	var spark := GearDB.enchant(w)
	if DB.GLOWS.has(hg) and spark.a > 0.0:
		spark = Color(Color(DB.GLOWS[hg]["color"]), spark.a)
	_sparks(skel, "GearMain", spark)
	# Twin weapons: the same one again in the other hand.
	var dual := bool(hold["dual"])
	_hold(actor, skel, "GearDual", "handslot.l", file if dual else "", scale_, dye, glow, hold["xf_l"], GearDB.grade(w), GearDB.accent(w))
	if dual:
		_sparks(skel, "GearDual", spark)
	_aura(actor, GearDB.aura(worn, hero_id))
	# A two-handed weapon leaves no hand for the offhand (Game.equip took it off).
	var off: Dictionary = {} if Game.two_hands(hero_id, w) else worn["trinket"]
	var st := GearDB.piece(off) if not off.is_empty() else {}
	var model := str(st.get("model", ""))
	# A pair already fills the off hand: an offhand held there (the Rogue's
	# parrying dagger) is still worn, just not drawn over the twin.
	if dual and model != "" and str(GearDB.offhand_hold(hero_id, model)["bone"]) == "handslot.l":
		model = ""
	if model == "":
		_hold(actor, skel, "GearOff", "handslot.l", "", 1.0, Color(0, 0, 0, 0), Color(0, 0, 0, 0), Transform3D.IDENTITY)
		_sparks(skel, "GearOff", Color(0, 0, 0, 0))
		return
	var olk := GearDB.look(off)
	var oh := GearDB.offhand_hold(hero_id, model)
	_hold(actor, skel, "GearOff", oh["bone"], model, float(olk["scale"]) * float(oh["scale"]), olk["dye"], glow_of(off, 1.2), oh["xf"], GearDB.grade(off), GearDB.accent(off))
	_sparks(skel, "GearOff", GearDB.enchant(off) * Color(1, 1, 1, 0.6))


static func _hold(actor: Actor, skel: Skeleton3D, att_name: String, bone: String, file: String, scale_: float, dye: Color, glow: Color, xf: Transform3D, grade := Vector4.ZERO, accent := Color(1, 1, 1)) -> void:
	var att := skel.get_node_or_null(att_name) as BoneAttachment3D
	if att == null:
		att = BoneAttachment3D.new()
		att.name = att_name
		att.bone_name = bone
		skel.add_child(att)
	elif att.bone_name != bone:
		att.bone_name = bone
	if file == "":
		att.visible = false
		return
	att.visible = true
	if att.get_meta("look", "") != file:
		for c in att.get_children():
			actor.forget(c)
			c.queue_free()
		var prop := prop_for(file)
		att.add_child(prop)
		actor.restyle(prop)
		att.set_meta("look", file)
	var node := att.get_child(att.get_child_count() - 1) as Node3D
	if node:
		node.transform = xf
		node.scale = Vector3.ONE * scale_
	for mi in KK.meshes(att):
		mi.set_instance_shader_parameter("dye", dye)
		mi.set_instance_shader_parameter("tint", glow)
		mi.set_instance_shader_parameter("grade", grade)
		mi.set_instance_shader_parameter("accent", accent)


## The model of a weapon or offhand: a KayKit weapon file, or "kit:name", put
## together from several props (GearDB.KITS).
static func prop_for(model: String) -> Node3D:
	if not model.begins_with("kit:"):
		return KK.prop(KK.WEAPON_DIR + model)
	var root := Node3D.new()
	for part: Array in GearDB.KITS[model.trim_prefix("kit:")]:
		var n := KK.prop("res://assets/kaykit/" + str(part[0]))
		var rot: Vector3 = part[2]
		var sc: Vector3 = part[3] if part[3] is Vector3 else Vector3.ONE * float(part[3])
		n.transform = Transform3D(Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(sc), part[1])
		root.add_child(n)
	return root


## Sparks drifting off a fine weapon (one emitter per hand, made once, then
## only recolored). World-space, so a swing leaves a trail of them.
static func _sparks(skel: Skeleton3D, att_name: String, col: Color) -> void:
	var att := skel.get_node_or_null(att_name) as BoneAttachment3D
	if att == null:
		return
	var p := att.get_node_or_null("Sparks") as GPUParticles3D
	if col.a <= 0.0 or not att.visible:
		if p:
			p.emitting = false
			p.visible = false
		return
	if p == null:
		p = emitter(32, 0.9, 0.09)
		p.name = "Sparks"
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.05, 0.4, 0.05)
		pm.gravity = Vector3(0, 0.9, 0)
		pm.initial_velocity_min = 0.05
		pm.initial_velocity_max = 0.35
		pm.spread = 180.0
		p.position = Vector3(0, 0.45, 0)
		att.add_child(p)
	p.visible = true
	p.emitting = true
	p.amount_ratio = clampf(col.a, 0.25, 1.0)
	(p.process_material as ParticleProcessMaterial).color = Color(col.r, col.g, col.b, 1.0)


## A full set of fine gear: motes rising from a ring at the feet.
static func _aura(actor: Actor, col: Color) -> void:
	var p := actor.get_node_or_null("GearAura") as GPUParticles3D
	if col.a <= 0.0:
		if p:
			p.emitting = false
			p.visible = false
		return
	if p == null:
		p = emitter(56, 1.6, 0.075)
		p.name = "GearAura"
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = 0.62
		pm.emission_ring_inner_radius = 0.5
		pm.emission_ring_height = 0.05
		pm.gravity = Vector3(0, 1.1, 0)
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.3
		pm.direction = Vector3.UP
		pm.spread = 15.0
		p.position = Vector3(0, 0.08, 0)
		actor.add_child(p)
	p.visible = true
	p.emitting = true
	p.amount_ratio = clampf(0.35 + col.a * 0.65, 0.0, 1.0)
	(p.process_material as ParticleProcessMaterial).color = Color(col.r, col.g, col.b, 1.0)


static func emitter(amount: int, life: float, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.2))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _spark_mat()
	p.draw_pass_1 = q
	return p


static var _mat: ShaderMaterial


static func _spark_mat() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://src/vfx/sc_mote.gdshader")
	return _mat
