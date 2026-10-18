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
		"off": ["gear:shield_round", "gear:shield_tower", "gear:shield_tower", "gear:shield_tower"],
		# Off-hand shield pose relative to the hand socket (cm, degrees).
		"off_xf": [Vector3(0, -9, 12), Vector3(0, 0, 0)],
		"main_xf": [Vector3(0, 3, 0), Vector3(0, 180, 0)],
	},
	# Mordrek, the Bone Knight: a cursed duelist, one long blade, no shield.
	"bramble": {
		"anims": "res://assets/models/heroes/boneknight/boneknight_anims.res",
		"hide": ["sword", "scabbard_2"],
		"main": ["own:sword", "own:sword", "own:sword", "own:sword"],
		"off": ["", "", "", ""],
		"off_xf": [Vector3.ZERO, Vector3.ZERO],
		"main_xf": [Vector3(0, -8, 0), Vector3(180, 0, 0)],
		"seam": 0.25,
		"rune": Color(0.3, 1.0, 0.62),
		"spikes": true,
		# Cursed blade grows with its tier (same steel, longer reach read).
		"blade_scale": [1.0, 1.0, 1.15, 1.28],
	},
	# Gnash, the Ghoul: a feral berserker. Claws, no held gear; the tiers
	# show on the hide (pale -> ash-grey -> black-veined -> blood runes).
	"lumen": {
		"anims": "res://assets/models/heroes/ghoul/ghoul_anims.res",
		"hide": [],
		"main": ["", "", "", ""],
		"off": ["", "", "", ""],
		"off_xf": [Vector3.ZERO, Vector3.ZERO],
		"main_xf": [Vector3.ZERO, Vector3.ZERO],
		"seam": 0.4,
		"flesh": true,
		"rune": Color(1.0, 0.12, 0.1),
		"claws": true,
	},
	# Corvin, the Plague Doctor: a miasma caster. The staff, crow and bell
	# are skinned to the model's own bones; tiers ride the coat and mask.
	"ember": {
		"anims": "res://assets/models/heroes/plague/plague_anims.res",
		"hide": ["Object_8"],
		"main": ["", "", "", ""],
		"off": ["", "", "", ""],
		"off_xf": [Vector3.ZERO, Vector3.ZERO],
		"main_xf": [Vector3.ZERO, Vector3.ZERO],
		"seam": 0.5,
		"flesh": true,
		"rune": Color(0.55, 1.0, 0.2),
		# Restyled grim: the bright storybook coat goes soot and oilcloth.
		"soft_tints": [Color(0.52, 0.5, 0.46), Color(0.6, 0.6, 0.62), Color(0.3, 0.29, 0.31), Color(0.22, 0.2, 0.22)],
		"desat": 0.5,
		# Miasma bolt: sickly green glob trailing plague smoke.
		"bolt": Color(0.5, 1.0, 0.25),
		# Object_8 is the display plinth (grass disc): hidden.
	},
}

## Finish per tier: plate tint, soft-material (leather/cloth) tint, wear,
## runes, roughness. Cloth (tabard) takes "cloth".
const FINISH := [
	# T0 Bare: the plate shapes read as dark boiled leather over a padded
	# linen gambeson (stitching from the panel lines), no metal sheen.
	{"metal": Color(1.0, 1.0, 1.0), "soft": Color(0.5, 0.45, 0.38), "cloth": Color(0.4, 0.36, 0.3), "wear": 0.35, "rune": 0.0, "rough_mul": 0.9, "rough_add": 0.32, "gain": 0.2, "groove": 0.6, "edge_hi": 0.3, "edge_col": Color(0.55, 0.38, 0.22), "metal_cap": 0.06, "leather": 1.0},
	# T1 Dented Iron: warm, light, riveted; dark grooves, dull bevels.
	{"metal": Color(1.62, 1.42, 1.12), "soft": Color(0.74, 0.6, 0.48), "cloth": Color(0.5, 0.38, 0.27), "wear": 1.0, "rune": 0.0, "rough_mul": 1.05, "rough_add": 0.2, "gain": 0.9, "groove": 0.75, "edge_hi": 0.2, "edge_col": Color(0.7, 0.55, 0.38)},
	# T2 Blackened Steel: cool blue-black, glossy, crisp bright bevels.
	{"metal": Color(0.26, 0.29, 0.36), "soft": Color(0.3, 0.25, 0.23), "cloth": Color(0.42, 0.06, 0.05), "wear": 0.12, "rune": 0.0, "rough_mul": 0.55, "rough_add": -0.08, "gain": 1.1, "edge_hi": 1.5, "edge_col": Color(0.62, 0.74, 0.95), "edge_emit": 0.22, "metal_cap": 0.8},
	# T3 Runebound: black plate, burning rune seams, emissive blade.
	{"metal": Color(0.09, 0.08, 0.09), "soft": Color(0.22, 0.18, 0.17), "cloth": Color(0.1, 0.08, 0.08), "wear": 0.08, "rune": 0.0, "rough_mul": 0.62, "rough_add": -0.05, "gain": 1.15, "edge_hi": 0.25, "seam": 1.7, "metal_cap": 0.85},
]
const RUNE := Color(1.0, 0.32, 0.08)


static func has_kit(id: String) -> bool:
	return KITS.has(id)


static func anims(id: String) -> String:
	return str(KITS.get(id, {}).get("anims", ""))


const SLOTS := ["helm", "chest", "pauldrons", "gloves", "boots", "weapon", "offhand", "charm"]
const ARMOR_SLOTS := ["helm", "chest", "pauldrons", "gloves", "boots"]


## Per-slot tiers for a hero: {slot: tier} for all eight SLOTS, plus legacy
## "weapon"/"armor" keys ("armor" = the chest tier). Source order: the
## capture override, CC_GEAR (e.g. CC_GEAR=3, CC_GEAR=weapon:3,armor:2 or
## CC_GEAR=helm:2,chest:1), then GearDB (what the player has equipped).
static func tiers(id: String) -> Dictionary:
	var out := {}
	for sl in SLOTS:
		out[sl] = 0
	var src := {}
	if not override.is_empty():
		src = override
	elif OS.get_environment("CC_GEAR") != "":
		for part in OS.get_environment("CC_GEAR").split(","):
			var kv := part.split(":")
			if kv.size() == 2:
				src[kv[0]] = int(kv[1])
			else:
				src["weapon"] = int(part)
				src["armor"] = int(part)
	else:
		src = GearDB.tiers(id)
	return expand(src)


## Legacy {"weapon", "armor"} expands to every slot; explicit slots win.
static func expand(t: Dictionary) -> Dictionary:
	var out := {}
	for sl in SLOTS:
		out[sl] = 0
	if t.has("armor"):
		for sl in ARMOR_SLOTS:
			out[sl] = int(t["armor"])
		out["charm"] = int(t["armor"])
	if t.has("weapon"):
		out["weapon"] = int(t["weapon"])
		if t.has("armor"):
			out["offhand"] = int(t["weapon"])
	for sl in SLOTS:
		if t.has(sl):
			out[sl] = clampi(int(t[sl]), 0, 3)
	out["armor"] = out["chest"]
	out["weapon"] = out["weapon"]
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
	t = tiers(id) if t.is_empty() else expand(t)
	var kit: Dictionary = KITS[id]
	var wt := clampi(int(t["weapon"]), 0, 3)
	var ot := clampi(int(t["offhand"]), 0, 3)
	var at := clampi(int(t["chest"]), 0, 3)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	# The model's own swords double as tier meshes; take them before hiding.
	var own := {}
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n.name in kit["hide"]:
			(n as Node3D).visible = false
			for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
				if not own.has(String(n.name)):
					own[String(n.name)] = m
	var slot_t := PackedInt32Array()
	for sl in SLOTS:
		slot_t.append(int(t[sl]))
	# Per-slot finish on the body: vertices carry their slot (COLOR.r).
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if m.skin == null or not m.visible or m.get_parent().name in kit["hide"]:
			continue
		_tag_slots(m, sk)
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var cloth := src.resource_name.to_lower().contains("cloth")
			var fm := finish(src, at, cloth)
			fm.set_shader_parameter("use_slots", 1.0)
			fm.set_shader_parameter("slot_tier", slot_t)
			fm.set_shader_parameter("seam_gain", float(kit.get("seam", 1.0)))
			if kit.get("flesh", false):
				# Hide tiers: pale -> ash grey -> charcoal -> blood-veined.
				var hide_tint: Array = kit.get("soft_tints", [Color(0.95, 0.92, 0.85), Color(0.72, 0.74, 0.74), Color(0.36, 0.33, 0.33), Color(0.26, 0.2, 0.2)])
				var tints := PackedVector3Array()
				for c: Color in hide_tint:
					tints.append(Vector3(c.r, c.g, c.b))
				fm.set_shader_parameter("t_soft_tint", tints)
				fm.set_shader_parameter("flesh", 1.0)
				fm.set_shader_parameter("desat", float(kit.get("desat", 0.0)))
				fm.set_shader_parameter("t_groove", PackedFloat32Array([0.2, 0.6, 0.45, 0.3]))
			m.set_surface_override_material(i, fm)
	var sockets: Dictionary = {}
	var lib := load(str(kit["anims"])) as AnimationLibrary
	if lib:
		sockets = lib.get_meta("sockets", {})
	var main_xf: Array = kit["main_xf"]
	if OS.get_environment("CC_MAIN_XF") != "":
		var v := OS.get_environment("CC_MAIN_XF").split_floats(",")
		main_xf = [Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5])]
	_mount(sk, sockets.get("hand_r", {}), str(kit["main"][wt]), own, wt, main_xf, "GearMain")
	if kit.has("blade_scale"):
		var gm := sk.get_node_or_null("GearMain")
		if gm and gm.get_child_count() > 0:
			(gm.get_child(0) as Node3D).scale *= float(kit["blade_scale"][wt])
	# Off-hand: nothing until one is earned (bare = no shield).
	var off_src := str(kit["off"][ot]) if ot > 0 else ""
	_mount(sk, sockets.get("hand_l", {}), off_src, own, ot, kit["off_xf"], "GearOff")
	if kit.has("rune"):
		var rc: Color = kit["rune"]
		for n in model.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			for i in mi.get_surface_override_material_count():
				var sm := mi.get_surface_override_material(i) as ShaderMaterial
				if sm and sm.shader == SHADER:
					sm.set_shader_parameter("rune_color", rc)
	model.set_meta("gear_tiers", t)
	_silhouette(model, sk, t, kit)
	_exclusive(sk, t, kit)


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
			var fm := finish(mat, tier, false, true)
			if tier == 3 and label == "GearMain":
				fm.set_shader_parameter("blade_glow", 3.2)
			mi.set_surface_override_material(i, fm)


## Tier silhouettes so pieces read at phone distance, not only by colour:
## a horsehair crest on a blackened-steel (T2+) helm and a rune-hemmed cape
## on cursed rune plate (T3 chest). Plate knights only ("silhouette" in KITS
## defaults on unless the kit is flesh).
static func _silhouette(model: Node3D, sk: Skeleton3D, t: Dictionary, kit: Dictionary) -> void:
	for old in ["GearCrest", "GearCape"]:
		var n := sk.get_node_or_null(old)
		if n:
			n.free()
	if kit.get("flesh", false) or not kit.get("silhouette", true):
		return
	var bones := {}
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).to_lower()
		for key in ["hips", "chest", "head", "l_shoulder", "r_shoulder", "l_arm", "r_arm", "l_knee", "top", "tip"]:
			if not bones.has(key) and nm.begins_with(key):
				bones[key] = i
	if not (bones.has("hips") and bones.has("head") and bones.has("l_shoulder") and bones.has("r_shoulder") and bones.has("chest")):
		return
	var P := func(k: String) -> Vector3: return sk.get_bone_global_rest(bones[k]).origin
	var hips: Vector3 = P.call("hips")
	var head: Vector3 = P.call("head")
	var up := (head - hips).normalized()
	var across: Vector3 = P.call("r_shoulder") - P.call("l_shoulder")
	var fwd := up.cross(across).normalized()
	var h := (head - hips).length() * 2.2  # rough standing height
	var rc: Color = kit.get("rune", RUNE)
	if int(t.get("helm", 0)) >= 2:
		var top: Vector3 = P.call("top") if bones.has("top") else (P.call("tip") if bones.has("tip") else head + up * h * 0.1)
		var crest := MeshInstance3D.new()
		# A horsehair brush crest: a thin flattened capsule laid front to back.
		var pm := CapsuleMesh.new()
		pm.radius = h * 0.04
		pm.height = h * 0.27
		pm.radial_segments = 12
		pm.rings = 6
		crest.mesh = pm
		# Horsehair: dark oxblood strands (hash stripes round the capsule)
		# with a darker root, so it reads as hair and not a red plastic fin.
		var cm := ShaderMaterial.new()
		cm.shader = _crest_shader()
		var cc: Color = Color(0.3, 0.035, 0.03) if int(t["helm"]) == 2 else Color(0.09, 0.06, 0.06)
		cm.set_shader_parameter("base", Vector3(cc.r, cc.g, cc.b))
		var glow: Color = rc if int(t["helm"]) == 3 else Color.BLACK
		cm.set_shader_parameter("glow", Vector3(glow.r, glow.g, glow.b) * 0.5)
		crest.material_override = cm
		var side := fwd.cross(up).normalized()
		var basis := Basis(side * 0.4, fwd, -up)
		_attach(sk, bones["head"], "GearCrest", crest, Transform3D(basis, top + up * h * 0.03 - fwd * h * 0.03))
	if int(t.get("chest", 0)) >= 3:
		var w := across.length() * 2.2
		if bones.has("l_arm") and bones.has("r_arm"):
			w = ((P.call("l_arm") as Vector3) - (P.call("r_arm") as Vector3)).length() * 0.95
		var knee: Vector3 = P.call("l_knee") if bones.has("l_knee") else hips - up * h * 0.25
		var length: float = ((P.call("chest") as Vector3) - knee).length()
		var cape := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(w, length)
		plane.subdivide_width = 6
		plane.subdivide_depth = 10
		plane.orientation = PlaneMesh.FACE_Z
		cape.mesh = plane
		var sh := Shader.new()
		sh.code = CAPE_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("rune", rc)
		mat.set_shader_parameter("len", length)
		cape.material_override = mat
		cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var basis2 := Basis(fwd.cross(up).normalized(), up, fwd)
		var at: Vector3 = (P.call("chest") as Vector3) + up * h * 0.03 - fwd * h * 0.125 - up * length * 0.5
		_attach(sk, bones["chest"], "GearCape", cape, Transform3D(basis2, at))


## Hero-exclusive tier pieces built on the rig:
##   Gnash (claws: "claws" kit key): iron -> blackened -> rune-lit talons on
##   every fingertip, driven by the weapon slot.
##   Mordrek ("spikes" kit key): bone spaulder spikes from the pauldrons slot
##   (bone -> charred -> soulfire), and a longer cursed blade at T2+.
static func _exclusive(sk: Skeleton3D, t: Dictionary, kit: Dictionary) -> void:
	for n in sk.get_children():
		if str(n.name).begins_with("GearX"):
			n.free()
	var rc: Color = kit.get("rune", RUNE)
	var hips := -1
	var head := -1
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).to_lower()
		if hips < 0 and nm.begins_with("hips"):
			hips = i
		if head < 0 and nm.begins_with("head"):
			head = i
	if hips < 0 or head < 0:
		return
	var h := (sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hips).origin).length() * 2.2
	if kit.get("claws", false) and int(t.get("weapon", 0)) > 0:
		var tier := int(t["weapon"])
		var mat := _x_mat(tier, rc, false)
		var n := 0
		for i in sk.get_bone_count():
			var nm := sk.get_bone_name(i).to_lower().rstrip("0123456789").trim_suffix("_")
			# Fingertip bones: L_point_033, R_ring4_049 ... (last joint of each finger).
			var parent := sk.get_bone_parent(i)
			if parent < 0 or sk.get_bone_children(i).size() > 0:
				continue
			var ok := false
			for f in ["point", "middle", "ring", "pink"]:
				if f in nm:
					ok = true
			if not ok:
				continue
			var tip := sk.get_bone_global_rest(i).origin
			var base := sk.get_bone_global_rest(parent).origin
			var dir := (tip - base).normalized()
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var length := h * (0.075 + 0.015 * tier)
			cm.top_radius = 0.0
			cm.bottom_radius = h * 0.013
			cm.height = length
			cm.radial_segments = 6
			cm.rings = 1
			cone.mesh = cm
			cone.material_override = mat
			var y := dir
			var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
			var z := x.cross(y)
			# Curve the talon slightly downward like a hooked claw.
			var b := Basis(x, y, z).rotated(x, -0.25)
			_attach(sk, i, "GearX%d" % n, cone, Transform3D(b, tip + dir * length * 0.4))
			n += 1
	if kit.get("spikes", false) and int(t.get("pauldrons", 0)) > 0:
		var tier := int(t["pauldrons"])
		var mat := _x_mat(tier, rc, true)
		var n := 0
		var chest := -1
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).to_lower().begins_with("chest"):
				chest = i
		for side in ["l_arm", "r_arm"]:
			var bi := -1
			for i in sk.get_bone_count():
				if sk.get_bone_name(i).to_lower().begins_with(side):
					bi = i
					break
			if bi < 0 or chest < 0:
				continue
			var at := sk.get_bone_global_rest(bi).origin
			var up := (sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hips).origin).normalized()
			var out := (at - sk.get_bone_global_rest(chest).origin)
			out = (out - up * out.dot(up)).normalized()
			for k in 2 + mini(tier, 2):
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = h * 0.014
				cm.height = h * (0.07 + 0.015 * tier) * (1.0 - 0.18 * k)
				cm.radial_segments = 7
				cm.rings = 1
				cone.mesh = cm
				cone.material_override = mat
				var y := (up * (0.9 - 0.25 * k) + out * (0.45 + 0.3 * k)).normalized()
				var fwd := up.cross(out).normalized()
				var x := y.cross(fwd).normalized()
				var z := x.cross(y)
				var base_at := at + up * h * 0.035 + out * h * (0.01 + 0.025 * k) + fwd * h * (0.02 * (k - 1))
				_attach(sk, bi, "GearX%s%d" % [side, n], cone, Transform3D(Basis(x, y, z), base_at + y * cm.height * 0.45))
				n += 1


static func _x_mat(tier: int, rc: Color, bone: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match tier:
		1:
			m.albedo_color = Color(0.82, 0.77, 0.66) if bone else Color(0.62, 0.57, 0.5)
			m.metallic = 0.0 if bone else 0.8
			m.roughness = 0.7 if bone else 0.45
		2:
			m.albedo_color = Color(0.22, 0.2, 0.19) if bone else Color(0.2, 0.23, 0.29)
			m.metallic = 0.0 if bone else 0.9
			m.roughness = 0.6 if bone else 0.3
			m.rim_enabled = true
			m.rim = 0.5
		_:
			m.albedo_color = Color(0.06, 0.05, 0.05)
			m.metallic = 0.6
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = rc
			m.emission_energy_multiplier = 1.6
	return m


const CAPE_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform vec3 rune : source_color = vec3(1.0, 0.3, 0.08);
uniform float len = 1.0;
void vertex() {
	float d = 1.0 - UV.y;            // 0 at the shoulders, 1 at the hem
	d = UV.y;
	VERTEX.x *= 1.0 + d * 0.35;      // flare toward the hem
	VERTEX.z -= d * d * len * 0.28;  // drape back off the plate
	VERTEX.z += sin(TIME * 2.2 + d * 3.0 + VERTEX.x * 4.0) * d * len * 0.04;
}
void fragment() {
	float d = UV.y;
	float folds = 0.75 + 0.25 * sin(UV.x * 40.0 + d * 3.0);
	ALBEDO = vec3(0.07, 0.025, 0.025) * folds;
	ROUGHNESS = 0.9;
	float hem = smoothstep(0.9, 0.97, d);
	float pulse = 0.7 + 0.3 * sin(TIME * 2.4 - d * 6.0);
	EMISSION = rune * (hem * 2.2 + smoothstep(0.75, 1.0, d) * 0.25) * pulse;
}
"""


static func _attach(sk: Skeleton3D, bone: int, label: String, mesh: Node3D, skel_xf: Transform3D) -> void:
	var att := BoneAttachment3D.new()
	att.name = label
	att.bone_idx = bone
	sk.add_child(att)
	mesh.transform = sk.get_bone_global_rest(bone).affine_inverse() * skel_xf
	att.add_child(mesh)


## Cool fresnel rim on every gear-shaded surface (hunt readability on dark ground).
static func set_rim(model: Node, c: Color) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var sm := mi.get_surface_override_material(i) as ShaderMaterial
			if sm and sm.shader == SHADER:
				sm.set_shader_parameter("cool_rim", Vector3(c.r, c.g, c.b))


## A tier finish built over a source PBR material.
static func finish(src: BaseMaterial3D, tier: int, cloth := false, prop := false) -> ShaderMaterial:
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
	mat.set_shader_parameter("has_normal", 1.0 if src.normal_enabled and src.normal_texture else 0.0)
	if src.normal_texture:
		mat.set_shader_parameter("normal_tex", src.normal_texture)
	var arrs := {}
	for k in ["t_metal_tint", "t_soft_tint", "t_edge_col"]:
		arrs[k] = PackedVector3Array()
	for k in ["t_wear", "t_rough_mul", "t_rough_add", "t_gain", "t_groove", "t_edge_hi", "t_edge_emit", "t_metal_cap", "t_seam", "t_leather"]:
		arrs[k] = PackedFloat32Array()
	for f: Dictionary in FINISH:
		var metal: Color = f["metal"]
		var soft: Color = f["cloth"] if cloth else f["soft"]
		var ec: Color = f.get("edge_col", Color(0.55, 0.57, 0.62))
		arrs["t_metal_tint"].append(Vector3(metal.r, metal.g, metal.b))
		arrs["t_soft_tint"].append(Vector3(soft.r, soft.g, soft.b))
		arrs["t_edge_col"].append(Vector3(ec.r, ec.g, ec.b))
		arrs["t_wear"].append(f["wear"])
		arrs["t_rough_mul"].append(f["rough_mul"])
		arrs["t_rough_add"].append(float(f["rough_add"]) if src.roughness_texture else src.roughness + maxf(float(f["rough_add"]), 0.0))
		arrs["t_gain"].append(f["gain"])
		arrs["t_groove"].append(f.get("groove", 0.0))
		arrs["t_edge_hi"].append(f.get("edge_hi", 0.0))
		arrs["t_edge_emit"].append(f.get("edge_emit", 0.0))
		arrs["t_metal_cap"].append(f.get("metal_cap", 1.0))
		arrs["t_seam"].append(f.get("seam", 0.0))
		# Props (blades, shields) never go leather: bare weapons stay steel.
		arrs["t_leather"].append(0.0 if prop else f.get("leather", 0.0))
	for k in arrs:
		mat.set_shader_parameter(k, arrs[k])
	mat.set_shader_parameter("rune_color", RUNE)
	mat.set_shader_parameter("fixed_tier", clampi(tier, 0, 3))
	mat.set_shader_parameter("use_slots", 0.0)
	if prop:
		mat.set_shader_parameter("rune_scale", 30.0)
	if src.cull_mode == BaseMaterial3D.CULL_DISABLED or cloth:
		mat.render_priority = 0
	return mat


## Slot of a skeleton bone by name (index into SLOTS).
static func bone_slot(bone: String) -> int:
	var b := bone.to_lower()
	for k in ["staff", "whisp", "smoke"]:
		if k in b:
			return 5
	if "bell" in b:
		return 6
	if "crow" in b or "accesoire" in b:
		return 7
	for k in ["head", "neck", "top", "tip", "jaw", "lip", "eye", "face"]:
		if k in b:
			return 0
	for k in ["elbow", "wrist", "hand", "thumb", "point", "middle", "ring", "pink", "joint_3", "arm_lower"]:
		if k in b:
			return 3
	for k in ["shoulder", "_arm", "arm_upper"]:
		if k in b:
			return 2
	for k in ["knee", "ankle", "foot", "toes", "leg_left_lower", "leg_right_lower"]:
		if k in b:
			return 4
	return 1


## Tagged copies of skinned meshes, shared across spawns (keyed by mesh).
static var _tagged := {}


## Writes each vertex's gear slot (by its dominant bone) into COLOR.r so the
## shader can pick that slot's tier. Done once per mesh resource.
static func _tag_slots(mi: MeshInstance3D, sk: Skeleton3D) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or src.has_meta("slot_tagged"):
		return
	var key := src.get_instance_id()
	if _tagged.has(key):
		mi.mesh = _tagged[key]
		return
	var skin := mi.skin
	var bind_slot := PackedInt32Array()
	for bi in skin.get_bind_count():
		var bname := String(skin.get_bind_name(bi))
		if bname == "":
			var bone := skin.get_bind_bone(bi)
			bname = sk.get_bone_name(bone) if bone >= 0 and bone < sk.get_bone_count() else ""
		bind_slot.append(bone_slot(bname))
	var out := ArrayMesh.new()
	for bi in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(bi))
	out.blend_shape_mode = src.blend_shape_mode
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var fmt := src.surface_get_format(si)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var nv: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := 8 if (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) else 4
		var cols := PackedColorArray()
		cols.resize(nv)
		for v in nv:
			var best := 0
			var bw := -1.0
			for k in per:
				var w := weights[v * per + k]
				if w > bw:
					bw = w
					best = bones[v * per + k]
			var slot := bind_slot[best] if best < bind_slot.size() else 1
			cols[v] = Color(slot / 7.0, 0, 0, 1)
		arrays[Mesh.ARRAY_COLOR] = cols
		# Keep custom-channel formats and the 8-weight flag; drop compression
		# (the arrays come back decompressed).
		var flags := fmt & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		var bs := src.surface_get_blend_shape_arrays(si)
		out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays, bs, {}, flags)
		out.surface_set_material(si, src.surface_get_material(si))
		out.surface_set_name(si, src.surface_get_name(si))
	out.set_meta("slot_tagged", true)
	_tagged[key] = out
	mi.mesh = out


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


static var _crest_sh: Shader


static func _crest_shader() -> Shader:
	if _crest_sh == null:
		_crest_sh = Shader.new()
		_crest_sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 base = vec3(0.3, 0.035, 0.03);
uniform vec3 glow = vec3(0.0);
float h1(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float u = UV.x * 70.0;
	float strand = mix(h1(floor(u)), h1(floor(u) + 1.0), smoothstep(0.0, 1.0, fract(u)));
	float tip = smoothstep(0.0, 0.5, UV.y) * smoothstep(1.0, 0.5, UV.y);
	ALBEDO = base * (0.45 + 0.75 * strand) * (0.55 + 0.45 * tip);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	EMISSION = glow * strand * tip;
}
"""
	return _crest_sh
