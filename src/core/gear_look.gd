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
	var head := skel.get_node_or_null(own_head) as MeshInstance3D
	if head:
		head.visible = true
	var basic := Color(GearDB.BASIC_DYE)
	var own: String = DB.HEROES[hero_id]["model"]
	_dress(actor, skel, hero_id, worn["chest"], "chest", ["T:" + own] if starter["chest"] else ["T:Rogue_Hooded"], Color(0, 0, 0, 0) if starter["chest"] else basic)
	_dress(actor, skel, hero_id, worn["legs"], "legs", ["L:" + own] if starter["legs"] else ["L:Rogue_Hooded"], Color(0, 0, 0, 0) if starter["legs"] else basic)
	_dress(actor, skel, hero_id, worn["helm"], "helm", [], Color(0, 0, 0, 0))
	if not worn["trinket"].is_empty() and GearDB.stage(hero_id, "trinket", int(worn["trinket"].get("mat", 0))).has("parts"):
		_dress(actor, skel, hero_id, worn["trinket"], "trinket", [], Color(0, 0, 0, 0))
	if head and not _hood_on(worn["helm"], hero_id):
		head.visible = true
	_hands(actor, skel, hero_id, worn)


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
	parts = GearDB.expand(parts)
	for spec: String in parts:
		var mi := _part(actor, skel, spec)
		if mi == null:
			continue
		mi.visible = true
		mi.set_instance_shader_parameter("dye", Color(dye, dye.a * (0.4 if hood else 1.0)))
		mi.set_instance_shader_parameter("tint", glow)
	if hood:
		var own := skel.get_node_or_null("%s_Head" % DB.HEROES[hero_id]["model"].replace("Rogue_Hooded", "RogueHooded")) as MeshInstance3D
		if own:
			own.visible = false


## The mesh for a part spec like "Mage/Hat": the hero's own if it has one by
## that name, otherwise lifted from the other character's file (once).
static func _part(actor: Actor, skel: Skeleton3D, spec: String) -> MeshInstance3D:
	var reg: Dictionary = actor.get_meta("gl_parts", {})
	actor.set_meta("gl_parts", reg)
	if reg.has(spec) and is_instance_valid(reg[spec]):
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
		mi.get_parent().remove_child(mi)
		sc.free()
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		actor.restyle(skel)
		found = mi
	reg[spec] = found
	return found


## Weapon in the main hand, offhand piece in the other (or on the back).
static func _hands(actor: Actor, skel: Skeleton3D, hero_id: String, worn: Dictionary) -> void:
	var d: Dictionary = DB.HEROES[hero_id]
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
	var glow := glow_of(w, 1.2)
	# A bought or earned weapon glow outshines the rarity glow.
	var hg := str(Game.hero(hero_id).get("glow", ""))
	if DB.GLOWS.has(hg):
		glow = DB.GLOWS[hg]["color"]
	_hold(actor, skel, "GearMain", str(d["weapon_bone"]), file, scale_, dye, glow, Transform3D.IDENTITY)
	var off: Dictionary = worn["trinket"]
	var st := GearDB.stage(hero_id, "trinket", int(off.get("mat", 0))) if not off.is_empty() else {}
	var model := str(st.get("model", ""))
	if model == "":
		_hold(actor, skel, "GearOff", "handslot.l", "", 1.0, Color(0, 0, 0, 0), Color(0, 0, 0, 0), Transform3D.IDENTITY)
		return
	var olk := GearDB.look(off)
	var bone := str(line["offhand_bone"])
	var xf := Transform3D.IDENTITY
	if bone == "back":
		bone = "chest"
		xf = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(-90)), Vector3(0, -0.05, -0.28))
	_hold(actor, skel, "GearOff", bone, model, olk["scale"], olk["dye"], glow_of(off, 1.2), xf)


static func _hold(actor: Actor, skel: Skeleton3D, att_name: String, bone: String, file: String, scale_: float, dye: Color, glow: Color, xf: Transform3D) -> void:
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
		var prop := KK.prop(KK.WEAPON_DIR + file)
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
