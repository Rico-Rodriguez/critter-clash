class_name Gear3D
extends RefCounted

## Visible, tiered gear on humanoid hero rigs. Loot drives it: the equipped
## weapon's rarity picks the main-hand and off-hand meshes, the equipped
## armour's rarity picks the plate finish (helm, pauldrons, chest, tabard).
## Tier 0 is the starter kit (nothing equipped), then common, rare, epic:
##   0 Squire's kit      worn iron, linen tabard, short sword, round shield
##   1 Dented Iron       scuffed bright iron, rust, bastard sword, heater
##   2 Blackened Steel   dark oiled plate, crimson tabard, tower shield
##   3 Runebound         black plate etched with burning runes, the cursed
##                       Black Blade of Oarimaar
## Each hero's kit is exclusive (KITS). Hand sockets come from the retarget
## bake (tools/retarget.gd stores them on the clip library).

const GEAR := "res://assets/models/gear/"
const SHADER := preload("res://shaders/gear_tier.gdshader")

## Capture/bake override, e.g. CC_GEAR=weapon:3,armor:2 or CC_GEAR=3.
static var override := {}

const TIER_NAMES := ["Squire's Kit", "Dented Iron", "Blackened Steel", "Runebound"]

const KITS := {
	"pebble": {
		"anims": "res://assets/models/heroes/paladin/paladin_anims.res",
		"hide": ["BastardScabbard", "swordscabbard", "shortsword", "bastardsword"],
		"main": ["own:shortsword", "own:bastardsword", "own:bastardsword", "gear:blade_oarimaar"],
		"off": ["gear:shield_round", "gear:shield_heater", "gear:shield_tower", "gear:shield_tower"],
		# Off-hand shield pose relative to the hand socket (cm, degrees).
		"off_xf": [Vector3(0, -9, 12), Vector3(0, 0, 0)],
		"main_xf": [Vector3(0, 3, 0), Vector3(0, 180, 0)],
	},
}

## Finish per tier: plate tint, soft-material (leather/cloth) tint, wear,
## runes, roughness. Cloth (tabard) takes "cloth".
const FINISH := [
	{"metal": Color(0.78, 0.76, 0.72), "soft": Color(0.82, 0.78, 0.7), "cloth": Color(0.72, 0.68, 0.6), "wear": 0.55, "rune": 0.0, "rough_mul": 1.05, "rough_add": 0.08, "gain": 0.85},
	{"metal": Color(1.35, 1.3, 1.22), "soft": Color(0.74, 0.6, 0.48), "cloth": Color(0.5, 0.38, 0.27), "wear": 1.0, "rune": 0.0, "rough_mul": 1.0, "rough_add": 0.12, "gain": 1.0},
	{"metal": Color(0.3, 0.29, 0.29), "soft": Color(0.42, 0.34, 0.3), "cloth": Color(0.42, 0.06, 0.05), "wear": 0.18, "rune": 0.0, "rough_mul": 0.72, "rough_add": -0.04, "gain": 1.1},
	{"metal": Color(0.16, 0.14, 0.15), "soft": Color(0.25, 0.2, 0.19), "cloth": Color(0.1, 0.08, 0.08), "wear": 0.1, "rune": 1.0, "rough_mul": 0.66, "rough_add": -0.05, "gain": 1.15},
]
const RUNE := Color(1.0, 0.32, 0.08)


static func has_kit(id: String) -> bool:
	return KITS.has(id)


static func anims(id: String) -> String:
	return str(KITS.get(id, {}).get("anims", ""))


## Gear tiers for a hero from the save: rarity of the equipped weapon/armour.
static func tiers(id: String) -> Dictionary:
	var out := {"weapon": 0, "armor": 0}
	if not override.is_empty():
		out.merge(override, true)
		return out
	var env := OS.get_environment("CC_GEAR")
	if env != "":
		for part in env.split(","):
			var kv := part.split(":")
			if kv.size() == 2:
				out[kv[0]] = int(kv[1])
			else:
				out["weapon"] = int(part)
				out["armor"] = int(part)
		return out
	var save: Variant = Engine.get_main_loop().root.get_node_or_null("/root/SaveGame") if Engine.get_main_loop() is SceneTree else null
	if save == null or not save.data.has("heroes") or not save.data["heroes"].has(id):
		return out
	for slot in ["weapon", "armor"]:
		var uid := int(save.data["heroes"][id].get(slot, 0))
		if uid <= 0:
			continue
		var piece: Dictionary = save.find_gear(uid)
		out[slot] = rarity_tier(str(piece.get("rarity", "")))
	return out


static func rarity_tier(rarity: String) -> int:
	match rarity:
		"common":
			return 1
		"rare":
			return 2
		"epic", "legendary":
			return 3
	return 0


## Hide the model's own loose weapons and scabbards (Gear3D mounts tiers).
static func hide_own(model: Node3D, id: String) -> void:
	if not KITS.has(id):
		return
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n.name in KITS[id]["hide"]:
			(n as Node3D).visible = false


## Dress a spawned hero model. Call after the model is sized (sockets ride
## the skeleton, so scale does not matter).
static func dress(model: Node3D, id: String, t: Dictionary = {}) -> void:
	if not KITS.has(id):
		return
	if t.is_empty():
		t = tiers(id)
	var kit: Dictionary = KITS[id]
	var wt := clampi(int(t.get("weapon", 0)), 0, 3)
	var at := clampi(int(t.get("armor", 0)), 0, 3)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	# The model's own swords double as tier meshes; take them before hiding.
	var own := {}
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n.name in kit["hide"]:
			(n as Node3D).visible = false
			for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
				if not own.has(String(n.name)):
					own[String(n.name)] = m
	# Plate finish on the body and tabard.
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if m.skin == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var cloth := src.resource_name.to_lower().contains("cloth")
			m.set_surface_override_material(i, finish(src, at, cloth))
	var sockets: Dictionary = {}
	var lib := load(str(kit["anims"])) as AnimationLibrary
	if lib:
		sockets = lib.get_meta("sockets", {})
	_mount(sk, sockets.get("hand_r", {}), str(kit["main"][wt]), own, wt, kit["main_xf"], "GearMain")
	_mount(sk, sockets.get("hand_l", {}), str(kit["off"][wt]), own, wt, kit["off_xf"], "GearOff")
	model.set_meta("gear_tiers", {"weapon": wt, "armor": at})


static func _mount(sk: Skeleton3D, socket: Dictionary, src: String, own: Dictionary, tier: int, adj: Array, label: String) -> void:
	if socket.is_empty() or src == "":
		return
	var old := sk.get_node_or_null(label)
	if old:
		old.queue_free()
	var att := BoneAttachment3D.new()
	att.name = label
	att.bone_name = str(socket["bone"])
	sk.add_child(att)
	var holder := Node3D.new()
	holder.transform = (socket["xf"] as Transform3D) * Transform3D(Basis.from_euler(adj[1] * PI / 180.0), adj[0])
	att.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	if src.begins_with("own:"):
		var m: MeshInstance3D = own.get(src.substr(4))
		if m == null:
			return
		mi.mesh = m.mesh
	else:
		mi.mesh = load(GEAR + src.substr(5) + ".res")
	holder.add_child(mi)
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if mat:
			mi.set_surface_override_material(i, finish(mat, tier, false, true))


## A tier finish built over a source PBR material.
static func finish(src: BaseMaterial3D, tier: int, cloth := false, prop := false) -> ShaderMaterial:
	var f: Dictionary = FINISH[clampi(tier, 0, 3)]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("base_color", Vector3(src.albedo_color.r, src.albedo_color.g, src.albedo_color.b))
	if src.metallic_texture:
		mat.set_shader_parameter("metal_tex", src.metallic_texture)
		mat.set_shader_parameter("metal_ch", _ch(src.metallic_texture_channel))
	else:
		mat.set_shader_parameter("metal_floor", src.metallic)
	if src.roughness_texture:
		mat.set_shader_parameter("rough_tex", src.roughness_texture)
		mat.set_shader_parameter("rough_ch", _ch(src.roughness_texture_channel))
	else:
		mat.set_shader_parameter("rough_ch", Vector4.ZERO)
		mat.set_shader_parameter("rough_add", src.roughness)
	mat.set_shader_parameter("has_normal", 1.0 if src.normal_enabled and src.normal_texture else 0.0)
	if src.normal_texture:
		mat.set_shader_parameter("normal_tex", src.normal_texture)
	var metal: Color = f["metal"]
	var soft: Color = f["cloth"] if cloth else f["soft"]
	mat.set_shader_parameter("metal_tint", Vector3(metal.r, metal.g, metal.b))
	mat.set_shader_parameter("soft_tint", Vector3(soft.r, soft.g, soft.b))
	mat.set_shader_parameter("wear", f["wear"])
	mat.set_shader_parameter("rune", f["rune"])
	mat.set_shader_parameter("rune_color", RUNE)
	mat.set_shader_parameter("rough_mul", f["rough_mul"])
	if src.roughness_texture:
		mat.set_shader_parameter("rough_add", f["rough_add"])
	mat.set_shader_parameter("metal_gain", f["gain"])
	if prop:
		# Props have their own UV scale; runes a touch larger on blades and shields.
		mat.set_shader_parameter("rune_scale", 30.0)
	if tier == 3:
		mat.set_shader_parameter("edge_glow", Vector3(0.06, 0.012, 0.004))
	if src.cull_mode == BaseMaterial3D.CULL_DISABLED or cloth:
		mat.render_priority = 0
	return mat


static func _ch(c: int) -> Vector4:
	match c:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return Vector4(1, 0, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0, 0, 0, 1)
	return Vector4(0.333, 0.333, 0.333, 0)
