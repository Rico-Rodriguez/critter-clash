class_name GearLook
extends RefCounted
## Makes equipped gear visible on a hero. KayKit characters are not modular,
## so a piece shows up as: the main weapon changing model and size with its
## rarity (and uniques having their own look), a rarity-colored glow on the
## body parts each armor piece covers, and a glowing charm at the belt for the
## trinket. A new art pack with modular parts replaces this file's internals;
## the callers (`apply`) stay the same.

## Glow color (alpha = strength) by rarity; common gear shows no glow.
const GLOW := {
	"common": Color(0.0, 0.0, 0.0, 0.0),
	"magic": Color(0.42, 0.62, 1.0, 0.13),
	"rare": Color(1.0, 0.84, 0.32, 0.19),
	"legendary": Color(1.0, 0.5, 0.15, 0.28),
}
const WEAPON_SCALE := {"common": 1.0, "magic": 1.03, "rare": 1.07, "legendary": 1.12}
## Mesh-name suffixes (after the hero prefix, e.g. "Knight_Helmet") by slot.
const PARTS := {
	"helm": ["Helmet", "HelmetVisor", "BearHat", "Hat"],
	"chest": ["Body", "Cape", "ArmLeft", "ArmRight", "Quiver"],
	"legs": ["LegLeft", "LegRight"],
}
## The ranger's hood is part of her cape mesh.
const OVERRIDES := {
	"ranger": {"helm": ["Cape"], "chest": ["Body", "ArmLeft", "ArmRight", "Quiver"]},
}


static func glow_of(item: Dictionary, boost := 1.0) -> Color:
	if item.is_empty():
		return Color(0, 0, 0, 0)
	var c: Color = GLOW[item["rarity"]]
	return Color(c.r, c.g, c.b, c.a * boost)


## Re-dresses `actor` (built from DB.HEROES[hero_id]) in what the hero wears.
static func apply(actor: Actor, hero_id: String) -> void:
	var parts: Dictionary = PARTS.duplicate()
	parts.merge(OVERRIDES.get(hero_id, {}), true)
	for mi in actor.mesh_list():
		if not is_instance_valid(mi) or mi.get_meta("gear_ignore", false):
			continue
		var slot := _slot_of(mi, parts)
		if slot != "":
			mi.set_instance_shader_parameter("tint", glow_of(Game.equipped(hero_id, slot)))
	_weapon(actor, hero_id)
	_charm(actor, hero_id)


static func _slot_of(mi: MeshInstance3D, parts: Dictionary) -> String:
	var suffix := mi.name.get_slice("_", 1) if "_" in mi.name else ""
	for slot: String in parts:
		if suffix in parts[slot]:
			return slot
	return ""


static func _weapon(actor: Actor, hero_id: String) -> void:
	var d: Dictionary = DB.HEROES[hero_id]
	var bone: String = d["weapon_bone"]
	var item := Game.equipped(hero_id, "weapon")
	var rarity: String = item["rarity"] if not item.is_empty() else "common"
	var file: String = d["weapons"][bone]
	var looks: Array = d["weapon_looks"]
	var ri := DB.RARITIES.find(rarity)
	if ri < looks.size() and str(looks[ri]) != "":
		file = looks[ri]
	var u := str(item.get("unique", ""))
	if u != "" and DB.UNIQUES[u].has("look") and d["style"] == "melee":
		file = DB.UNIQUES[u]["look"]
	var skel: Skeleton3D = actor.model.find_child("Skeleton3D", true, false)
	for att in skel.get_children():
		if not (att is BoneAttachment3D) or (att as BoneAttachment3D).bone_name != bone:
			continue
		if att.get_meta("look", "") != file:
			for c in att.get_children():
				actor.forget(c)
				c.queue_free()
			var prop := KK.prop(KK.WEAPON_DIR + file)
			att.add_child(prop)
			actor.restyle(prop)
			att.set_meta("look", file)
		var w := att.get_child(att.get_child_count() - 1)
		if w is Node3D:
			(w as Node3D).scale = Vector3.ONE * float(WEAPON_SCALE[rarity])
		for mi in KK.meshes(att):
			mi.set_instance_shader_parameter("tint", glow_of(item, 1.2))


## The trinket is a small glowing charm hanging at the belt.
static func _charm(actor: Actor, hero_id: String) -> void:
	var skel: Skeleton3D = actor.model.find_child("Skeleton3D", true, false)
	var att: BoneAttachment3D = skel.get_node_or_null("Charm")
	var item := Game.equipped(hero_id, "trinket")
	if item.is_empty():
		if att:
			att.visible = false
		return
	if att == null:
		att = BoneAttachment3D.new()
		att.name = "Charm"
		att.bone_name = "hips"
		skel.add_child(att)
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 12
		sm.rings = 6
		orb.mesh = sm
		orb.name = "Orb"
		orb.position = Vector3(0.24, 0.02, 0.14)
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		orb.material_override = m
		att.add_child(orb)
	att.visible = true
	var col: Color = GLOW[item["rarity"]] if item["rarity"] != "common" else Color(0.85, 0.8, 0.7, 1.0)
	var orb_m: StandardMaterial3D = (att.get_node("Orb") as MeshInstance3D).material_override
	orb_m.albedo_color = Color(col.r, col.g, col.b)
	orb_m.emission = Color(col.r, col.g, col.b)
	orb_m.emission_energy_multiplier = 2.5
