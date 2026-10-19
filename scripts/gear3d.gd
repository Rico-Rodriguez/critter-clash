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
## Art-direction lock (2026-10-18): heroes keep the artist's PBR materials.
## The old per-tier recolour shader path stays behind this switch.
static var CLEAN: bool = OS.get_environment("CC_GEAR_LEGACY") == ""
static var _strip_cache := {}
## Icon baking (tools/slot_icons.gd): keep only this slot's body triangles.
static var SOLO := -1


## The tagged body mesh partitioned by slot tier (geometry, not tint):
##  T0 bare  - plate standing proud of the bone axis is cut away (pauldron
##             shells, horns, helm crown) and what remains wears the padded
##             underlayer (gambeson: the artist's normals, matte linen).
##  T1 iron  - the artist's plate, but still cut back (no pauldron shells,
##             no horns): a plain soldier's kit.
##  T2 steel - the artist's full plate, untouched (showcase look).
##  T3 rune  - full plate plus a faint rune-light fresnel pass.
## Cached per source mesh + tier signature.
static func _stripped(src: ArrayMesh, t: Dictionary, kit: Dictionary) -> ArrayMesh:
	if src == null:
		return src
	var strip: Array = kit.get("strip", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var tier := PackedInt32Array()
	var sig := ""
	for i in SLOTS.size():
		tier.append(clampi(int(t.get(SLOTS[i], 0)), 0, 3))
		sig += str(tier[i])
	var key := "%d:%s:%d" % [src.get_instance_id(), sig, SOLO]
	if _strip_cache.has(key):
		return _strip_cache[key]
	var top := float(kit.get("strip_top", 9.0))
	var cut := float(kit.get("helm_cut", 0.0))
	var ab := src.get_aabb()
	var cut_y := ab.position.y + ab.size.y * cut if cut > 0.0 else 1e9
	var hat_max := int(kit.get("helm_cut_max", 1))
	var cut_bare: Array = kit.get("cut_bare", [])
	# Bone-level cuts: {slot index: [[max tier, bone substrings...], ...]}:
	# vertices led by a matching bone vanish while that slot is at or below
	# max tier (Corvin's robe, shoulder plates, hat brim...).
	var bone_cut := PackedByteArray()
	var bcuts: Dictionary = kit.get("bone_cuts", {})
	var bnames: PackedStringArray = src.get_meta("bind_names", PackedStringArray())
	bone_cut.resize(bnames.size() + 1)
	for bi in bnames.size():
		for sl_i in bcuts:
			for rule: Array in bcuts[sl_i]:
				if tier[int(sl_i)] <= int(rule[0]):
					for sub in rule.slice(1):
						if str(sub) in bnames[bi]:
							bone_cut[bi + 1] = 1
	# Bare hooded head: keep the whole helm stub (it becomes the hood).
	var hooded: bool = kit.get("hood", false) and tier[0] == 0
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var fmt := src.surface_get_format(si) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		var mat := src.surface_get_material(si)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if cols.is_empty() or idx.is_empty():
			out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays, [], {}, fmt)
			out.surface_set_material(out.get_surface_count() - 1, _opaque(mat))
			continue
		var vslot := PackedByteArray()
		var kill := PackedByteArray()
		vslot.resize(verts.size())
		kill.resize(verts.size())
		for v in verts.size():
			var c := cols[v]
			var sl := clampi(int(c.r * 7.0 + 0.5), 0, 7)
			vslot[v] = sl
			var k := false
			# Bare plate kits keep their pauldron mass under the gambeson
			# (cutting it there left floating shards).
			if tier[sl] <= (hat_max if sl == 0 else 1) and not (sl == 2 and tier[sl] == 0 and kit.has("under")):
				if float(strip[sl]) > 0.0 and c.g * 0.5 > float(strip[sl]) and (sl != 2 or c.b - 0.5 > float(kit.get("pauldron_lift", -9.0))):
					k = true
				pass
			if sl == 0 and tier[0] <= hat_max and (c.b - 0.5) > top:
				k = true
			if tier[0] <= hat_max and verts[v].y > cut_y and (sl == 0 or cut_bare.is_empty()) and not (hooded and sl == 0):
				k = true
			if hooded and sl == 0 and (c.b - 0.5) <= top and verts[v].y <= cut_y and c.g < 0.99:
				k = false
			if tier[sl] == 0 and cut_bare.has(sl):
				k = true
			var bidx := int(round(c.a * 1024.0))
			if bidx > 0 and bidx < bone_cut.size() and bone_cut[bidx] == 1:
				k = true
			if SOLO >= 0 and sl != SOLO:
				k = true
			kill[v] = 1 if k else 0
		var hood: bool = kit.get("hood", false)
		var wraps: Array = kit.get("wrap_slots", [])
		var groups := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
		for tri in range(0, idx.size(), 3):
			var i0 := idx[tri]
			var i1 := idx[tri + 1]
			var i2 := idx[tri + 2]
			if kill[i0] == 1 or kill[i1] == 1 or kill[i2] == 1:
				continue
			var sl0 := vslot[i0]
			var tt := tier[sl0]
			var g := 0 if tt == 0 else (2 if tt == 3 else 1)
			if g == 0 and hood and sl0 == 0:
				g = 3
			elif g == 0 and wraps.has(sl0):
				g = 4
			groups[g].append_array([i0, i1, i2])
		for g in 5:
			if (groups[g] as PackedInt32Array).is_empty():
				continue
			var arr2 := arrays.duplicate()
			arr2[Mesh.ARRAY_INDEX] = groups[g]
			if g == 3:
				_hood_morph(arr2, groups[g], kit)
			out.add_surface_from_arrays(src.surface_get_primitive_type(si), arr2, [], {}, fmt)
			var m2: Material = _opaque(mat)
			if kit.has("under"):
				if g == 0:
					m2 = _cloth_mat("quilt", kit)
				elif g == 3:
					m2 = _cloth_mat("hood", kit)
				elif g == 4:
					m2 = _cloth_mat("wrap", kit)
			if g == 2:
				m2 = _rune_lit(mat, kit)
			out.surface_set_material(out.get_surface_count() - 1, m2)
	_strip_cache[key] = out
	return out


static var _opaque_cache := {}

## Alpha-blended artist cloth (Corvin's coat) composites as a pale ghost
## over the Heroes backdrop and sorts badly in the hunt: cut it out
## instead (crisp edges, same texture).
static func _opaque(mat: Material) -> Material:
	var bm := mat as BaseMaterial3D
	if bm == null or bm.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		return mat
	var k := bm.get_instance_id()
	if not _opaque_cache.has(k):
		var o := bm.duplicate() as BaseMaterial3D
		o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		o.alpha_scissor_threshold = 0.5
		o.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		_opaque_cache[k] = o
	return _opaque_cache[k]


## Bare head: the boxy helm stub is pulled onto an ellipsoid round the head
## (a padded linen hood) with a recessed, shadowed face opening. Works on
## this surface's own vertex copy, blended in above the neck.
static func _hood_morph(arr: Array, idx: PackedInt32Array, kit: Dictionary) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var used := {}
	for i in idx:
		used[i] = true
	if used.is_empty():
		return
	var box := AABB()
	var first := true
	for i in used:
		if first:
			box = AABB(verts[i], Vector3.ZERO)
			first = false
		else:
			box = box.expand(verts[i])
	var c := box.get_center()
	var rad := box.size * 0.5 * Vector3(0.8, 0.9, 0.84)
	rad = rad.max(Vector3.ONE * 0.0001)
	var fwd: Vector3 = kit.get("fwd", Vector3(0, 0, 1))
	var neck := box.position.y + box.size.y * 0.12
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(Color(1, 1, 1))
	for i in used:
		var p := verts[i]
		var d := (p - c) / rad
		if d.length() < 0.0001:
			continue
		var dn := d.normalized()
		var w := smoothstep(neck, neck + box.size.y * 0.3, p.y)
		var face := dn.dot(fwd) > 0.5 and dn.y < 0.45 and dn.y > -0.6
		var target := c + dn * rad * (0.72 if face else 1.0)
		verts[i] = p.lerp(target, w)
		var n2 := (dn / rad).normalized()
		if nrm.size() > i:
			nrm[i] = nrm[i].lerp(n2, w).normalized()
		if face and w > 0.5:
			cols[i] = Color(0.06, 0.05, 0.05)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TANGENT] = null


static var _cloth_cache := {}
static var _cloth_tex := {}

## Quilted gambeson / linen hood / cloth wraps for bare slots: a small
## generated textile (diamond quilting, or diagonal wrap bands) mapped
## triplanar, so the baked plate engraving no longer shows through.
static func _cloth_mat(kind: String, kit: Dictionary) -> Material:
	var key := kind + str(kit.get("under"))
	if _cloth_cache.has(key):
		return _cloth_cache[key]
	var m := StandardMaterial3D.new()
	var tint: Color = kit.get("under", Color(0.44, 0.37, 0.29))
	if kind == "wrap":
		tint = kit.get("wrap", Color(0.66, 0.6, 0.5))
	elif kind == "hood":
		tint = kit.get("hood_col", tint.lightened(0.08))
	var pat := "wrap" if kind == "wrap" else "quilt"
	m.albedo_color = tint
	m.albedo_texture = _textile(pat, false)
	m.normal_enabled = true
	m.normal_texture = _textile(pat, true)
	m.normal_scale = 1.0
	m.roughness = 0.93
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * float(kit.get("quilt_scale", 0.09 if pat == "quilt" else 0.16))
	m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if kind == "hood":
		m.vertex_color_use_as_albedo = true
	_cloth_cache[key] = m
	return m


static func _textile(pat: String, normal: bool) -> Texture2D:
	var key := pat + str(normal)
	if _cloth_tex.has(key):
		return _cloth_tex[key]
	const N := 128
	var hgt := PackedFloat32Array()
	hgt.resize(N * N)
	for y in N:
		for x in N:
			var u := float(x) / N
			var v := float(y) / N
			var h := 0.0
			if pat == "quilt":
				# Diamond quilting: puffed cells, sunk stitch lines.
				var a := absf(fposmod(u + v, 0.5) - 0.25) / 0.25
				var b := absf(fposmod(u - v, 0.5) - 0.25) / 0.25
				h = smoothstep(0.0, 0.35, minf(a, b) * 0.0 + minf(1.0 - a, 1.0 - b))
				h = sqrt(clampf(h, 0.0, 1.0))
			else:
				# Linen wraps: diagonal bands with a weave ripple.
				var w := fposmod(v * 4.0 + u * 1.0, 1.0)
				h = smoothstep(0.0, 0.12, w) * smoothstep(1.0, 0.82, w)
				h *= 0.85 + 0.15 * sin(u * TAU * 24.0)
			hgt[y * N + x] = h
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var h := hgt[y * N + x]
			if normal:
				var dx := hgt[y * N + (x + 1) % N] - hgt[y * N + (x - 1 + N) % N]
				var dy := hgt[((y + 1) % N) * N + x] - hgt[((y - 1 + N) % N) * N + x]
				var n := Vector3(-dx * 2.2, -dy * 2.2, 1.0).normalized()
				img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
			else:
				var g := 0.62 + 0.38 * h
				var fleck := 0.97 + 0.03 * sin(float(x * 7 + y * 13))
				img.set_pixel(x, y, Color(g * fleck, g * fleck, g * fleck))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cloth_tex[key] = tex
	return tex


static var _gambeson_cache := {}

## Padded underlayer for bare slots: the artist's normal map (so quilting
## and seams stay crisp) on a matte, desaturated linen/leather albedo.
static func _gambeson(src: BaseMaterial3D, kit: Dictionary) -> Material:
	if src == null:
		return src
	var k := src.get_instance_id()
	if _gambeson_cache.has(k):
		return _gambeson_cache[k]
	var m := StandardMaterial3D.new()
	var tint: Color = kit.get("under", Color(0.42, 0.36, 0.29))
	m.albedo_color = tint
	var tex := src.albedo_texture
	if tex:
		var img := tex.get_image()
		if img:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_L8)
			img.convert(Image.FORMAT_RGBA8)
			img.adjust_bcs(1.35, 1.5, 1.0)
			img.generate_mipmaps()
			m.albedo_texture = ImageTexture.create_from_image(img)
	m.metallic = 0.0
	m.roughness = 0.88
	m.normal_enabled = src.normal_enabled
	m.normal_texture = src.normal_texture
	m.normal_scale = src.normal_scale
	m.texture_filter = src.texture_filter
	_gambeson_cache[k] = m
	return m


static var _rune_cache := {}

## T3: the artist's material untouched plus a faint fresnel rune-light pass.
static func _rune_lit(src: Material, kit: Dictionary) -> Material:
	if src == null:
		return src
	var k := src.get_instance_id()
	if _rune_cache.has(k):
		return _rune_cache[k]
	var m := src.duplicate() as Material
	var rim := ShaderMaterial.new()
	rim.shader = preload("res://shaders/rune_rim.gdshader")
	rim.set_shader_parameter("rune_color", kit.get("rune", RUNE))
	m.next_pass = rim
	_rune_cache[k] = m
	return m

const TIER_NAMES := ["Squire's Kit", "Dented Iron", "Blackened Steel", "Runebound"]

const KITS := {
	"pebble": {
		"anims": "res://assets/models/heroes/paladin/paladin_anims.res",
		"hide": ["BastardScabbard", "swordscabbard", "shortsword", "bastardsword"],
		# Bare = empty-handed; the first sword is an earned piece.
		"main": ["", "own:shortsword", "own:bastardsword", "gear:blade_oarimaar"],
		# Bare slots strip the baked plate (x hero height from the bone axis):
		# helm, chest, pauldrons, gloves, boots, weapon, offhand, charm.
		"strip": [0.07, 0.0, 0.07, 0.0, 0.0, 0.0, 0.0, 0.0],
		"strip_top": 0.15,
		"helm_cut": 0.95,
		# The tabard/cape (artist cloth mesh) is earned with steel chest.
		"cloth_node": "cloth_1",
		# Bare head reads as a padded linen hood; bare hands/feet as wraps.
		"hood": true,
		"wrap_slots": [3, 4],
		"under": Color(0.22, 0.18, 0.14),
		"hood_col": Color(0.26, 0.22, 0.18),
		"wrap": Color(0.4, 0.35, 0.28),
		"quilt_scale": 0.2,
		# Pauldron shells sit above the shoulder bone; the upper arm stays.
		"pauldron_lift": 0.015,
		# Tier silhouettes: iron = hornless, crownless helm, no pauldron
		# shells, short sword, round wooden shield; steel = full plate
		# (still hornless), bastard sword, heater; rune = horned helm,
		# Oarimaar blade, tower shield.
		"helm_cut_max": 2,
		"rune_pauldron": "pauldron_ancient",
		"rune_pauldron_xf": [Vector3(0.075, 0.06, 0.04), Vector3(0, 0, -20), 1.3],
		"amulet_out": 0.13,
		"off": ["", "gear:shield_round", "gear:shield_heater", "gear:shield_tower"],
		# Off-hand shield pose relative to the hand socket (cm, degrees).
		"off_xf": [Vector3(0, -9, 12), Vector3(0, 0, 0)],
		"main_xf": [Vector3(0, 3, 0), Vector3(0, 180, 0)],
	},
	# Mordrek, the Bone Knight: a cursed duelist, one long blade, no shield.
	"bramble": {
		"anims": "res://assets/models/heroes/boneknight/boneknight_anims.res",
		# The bone-plate albedo is pale, so blackened steel would read as
		# frosted ice; damp the T2 metal tint for this kit only.
		"metal_mul": [1.0, 1.0, 0.4, 1.0],
		"hide": ["sword", "scabbard_2"],
		"main": ["", "own:sword", "own:sword", "own:sword"],
		"off": ["", "", "", ""],
		"off_xf": [Vector3.ZERO, Vector3.ZERO],
		"main_xf": [Vector3(0, -8, 0), Vector3(180, 0, 0)],
		"seam": 0.25,
		"rune": Color(0.3, 1.0, 0.62),
		"spikes": true,
		# Bare: the skull shows; the horned helm is the earned head piece.
		"helm_mesh": "helm",
		"strip": [0.0, 0.0, 0.07, 0.0, 0.0, 0.0, 0.0, 0.0],
		"cloth_node": "body",
		"under": Color(0.24, 0.22, 0.21),
		"hood": true,
		"hood_col": Color(0.2, 0.19, 0.19),
		"wrap_slots": [3, 4],
		"wrap": Color(0.36, 0.33, 0.3),
		"quilt_scale": 0.2,
		# Charm hangs at the belt buckle, not floating by the hand.
		"amulet_y": 0.1,
		"amulet_out": 0.12,
		# Spiked pauldrons are the rune silhouette, not an iron one.
		"spikes_tier": 3,
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
		# Caster kit from his own geometry, no plate: bare = no hat, empty
		# hands (staff, bell and crow are earned: weapon, offhand, charm).
		"cut_bare": [5, 6, 7],
		"helm_cut": 0.86,
		"helm_cut_max": 0,
		# Robe steps (chest): bare = no cape or skirt panels, iron adds the
		# skirt, steel the full cape. Pauldrons: his steel shoulder plates
		# only from steel; below that they are cut back.
		"bone_cuts": {1: [[0, "skirt", "lowercloth"], [1, "cape"]]},
		"strip": [0.0, 0.0, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0],
		"pauldron_lift": 0.0,
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
	# T0 Bare: a dark quilted gambeson and hood (stitching from the panel
	# lines), matte, no metal at all; bare helms also lose their horns.
	{"metal": Color(0.5, 0.44, 0.38), "soft": Color(0.34, 0.29, 0.25), "cloth": Color(0.3, 0.26, 0.22), "wear": 0.35, "rune": 0.0, "rough_mul": 0.9, "rough_add": 0.4, "gain": 0.1, "groove": 0.85, "edge_hi": 0.08, "edge_col": Color(0.45, 0.33, 0.22), "metal_cap": 0.0, "leather": 1.0},
	# T1 Dented Iron: warm, light, riveted; dark grooves, dull bevels.
	{"metal": Color(1.62, 1.42, 1.12), "soft": Color(0.74, 0.6, 0.48), "cloth": Color(0.5, 0.38, 0.27), "wear": 1.0, "rune": 0.0, "rough_mul": 1.05, "rough_add": 0.2, "gain": 0.9, "groove": 0.75, "edge_hi": 0.2, "edge_col": Color(0.7, 0.55, 0.38)},
	# T2 Blackened Steel: cool blue-black, glossy, crisp bright bevels.
	{"metal": Color(0.4, 0.44, 0.52), "soft": Color(0.3, 0.25, 0.23), "cloth": Color(0.42, 0.06, 0.05), "wear": 0.12, "rune": 0.0, "rough_mul": 0.7, "rough_add": -0.02, "gain": 1.1, "edge_hi": 1.05, "edge_col": Color(0.62, 0.74, 0.95), "edge_emit": 0.22, "metal_cap": 0.8},
	# T3 Runebound: black plate, burning rune seams, emissive blade.
	{"metal": Color(0.09, 0.08, 0.09), "soft": Color(0.22, 0.18, 0.17), "cloth": Color(0.1, 0.08, 0.08), "wear": 0.08, "rune": 0.0, "rough_mul": 0.62, "rough_add": -0.05, "gain": 1.15, "edge_hi": 0.25, "edge_col": Color(1.0, 0.36, 0.12), "edge_emit": 0.6, "seam": 1.9, "metal_cap": 0.85},
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
	if kit.has("helm_mesh"):
		# Shown while materials are assigned; hidden below if the slot is bare.
		for n: Node in model.find_children(str(kit["helm_mesh"]), "MeshInstance3D", true, false):
			(n as MeshInstance3D).visible = true
	var slot_t := PackedInt32Array()
	for sl in SLOTS:
		slot_t.append(int(t[sl]))
	# Showcase look (art-direction lock): the artist's PBR materials render
	# untouched. Tiers read from geometry: bare slots strip the baked plate
	# (CPU triangle cut, cached per mesh + bare mask), earned pieces mount.
	if CLEAN:
		for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if m.skin == null or m.get_parent().name in kit["hide"]:
				continue
			if not m.has_meta("src_mesh"):
				m.set_meta("src_mesh", m.mesh)
			m.mesh = m.get_meta("src_mesh")
			for i in m.get_surface_override_material_count():
				m.set_surface_override_material(i, null)
			_tag_slots(m, sk)
			m.mesh = _stripped(m.mesh as ArrayMesh, t, kit)
			if m.is_inside_tree() and sk.is_inside_tree() and not sk.has_meta("mesh_basis"):
				# Mesh space -> skeleton space (Sketchfab rigs are often Z-up).
				sk.set_meta("mesh_basis", (sk.global_transform.affine_inverse().basis * m.global_transform.basis).orthonormalized())
	else:
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
				var fm := finish(src, at, cloth, false, kit.get("metal_mul", []))
				fm.set_shader_parameter("use_slots", 1.0)
				fm.set_shader_parameter("slot_tier", slot_t)
				fm.set_shader_parameter("seam_gain", float(kit.get("seam", 1.0)))
				# Empty slots strip baked plate beyond this axis distance (x h).
				var strip: Array = kit.get("strip", [])
				if strip.is_empty() and OS.get_environment("CC_STRIP") != "":
					strip = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
				if not strip.is_empty():
					var sr := PackedFloat32Array(strip)
					if OS.get_environment("CC_STRIP") != "":
						var ov := OS.get_environment("CC_STRIP").split_floats(",")
						for k in mini(ov.size(), sr.size()):
							sr[k] = ov[k]
					fm.set_shader_parameter("strip_r", sr)
					var top := float(kit.get("strip_top", 9.0))
					if OS.get_environment("CC_STRIP_TOP") != "":
						top = float(OS.get_environment("CC_STRIP_TOP"))
					fm.set_shader_parameter("strip_top", top)
					var cut := float(kit.get("helm_cut", 0.0))
					if OS.get_environment("CC_HELM_CUT") != "":
						cut = float(OS.get_environment("CC_HELM_CUT"))
					if cut > 0.0:
						var ab := m.mesh.get_aabb()
						fm.set_shader_parameter("helm_cut_y", ab.position.y + ab.size.y * cut)
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
	if kit.has("helm_mesh"):
		for n: Node in model.find_children(str(kit["helm_mesh"]), "MeshInstance3D", true, false):
			(n as MeshInstance3D).visible = int(t["helm"]) > 0
	if CLEAN and kit.has("cloth_node"):
		for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var cm := m.get_meta("src_mesh", m.mesh) as Mesh
			if cm and cm.get_surface_count() > 0 and cm.surface_get_material(0) and cm.surface_get_material(0).resource_name.to_lower().contains("cloth"):
				m.visible = int(t["chest"]) >= 2 and (SOLO < 0 or SOLO == 1)
	model.set_meta("gear_tiers", t)
	if not CLEAN:
		_silhouette(model, sk, t, kit)
		_rune_embers(sk, t)
	_exclusive(sk, t, kit)
	if CLEAN:
		_amulet(sk, t, kit)
		_rune_pauldrons(sk, t, kit)
	else:
		_charm(sk, t)


static func _mount(sk: Skeleton3D, socket: Dictionary, src: String, own: Dictionary, tier: int, adj: Array, label: String) -> void:
	var old := sk.get_node_or_null(label)
	if old:
		old.name = label + "_old"
		old.queue_free()
	if socket.is_empty() or src == "":
		return
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
		# True scale: the artist's sword node carries its own scale in the
		# GLB hierarchy (it read as a toy blade without it).
		mi.set_meta("own_len", (m.global_transform.basis * m.mesh.get_aabb().size).length() if m.is_inside_tree() else 0.0)
	else:
		mi.mesh = load(GEAR + src.substr(5) + ".res")
	holder.add_child(mi)
	if mi.has_meta("own_len") and float(mi.get_meta("own_len")) > 0.0 and mi.is_inside_tree():
		# True scale: match the artist's sword length in the world (the
		# socket chain shrank it to a toy blade).
		var now := (mi.global_transform.basis * mi.mesh.get_aabb().size).length()
		if now > 0.0001:
			mi.scale *= float(mi.get_meta("own_len")) / now
	if CLEAN:
		# Crisp, not smeared: emissive blade runes stay under the bloom
		# threshold and keep their edges.
		for i in mi.mesh.get_surface_count():
			var bm := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if bm and bm.emission_enabled:
				var cm := bm.duplicate() as BaseMaterial3D
				cm.emission_energy_multiplier = minf(cm.emission_energy_multiplier, 0.6)
				mi.set_surface_override_material(i, cm)
		return
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
		var cc: Color = Color(0.26, 0.035, 0.03) if int(t["helm"]) == 2 else Color(0.09, 0.06, 0.06)
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
	if kit.get("spikes", false) and int(t.get("pauldrons", 0)) >= int(kit.get("spikes_tier", 1)):
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


## Spins its children around the hero (the charm wisp).
class Orbit extends Node3D:
	var speed := 1.6

	func _process(delta: float) -> void:
		rotate_object_local(Vector3.UP, delta * speed)


## The charm slot shows on every hero: an equipped charm becomes a glowing
## wisp in its tier colour circling at chest height (two at rune tier), so a
## trinket the size of a coin still reads in the hunt.
static func _charm(sk: Skeleton3D, t: Dictionary) -> void:
	var old := sk.get_node_or_null("GearCharm")
	if old:
		old.free()
	var tier := int(t.get("charm", 0))
	if tier <= 0:
		return
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
	var hp := sk.get_bone_global_rest(hips).origin
	var hd := sk.get_bone_global_rest(head).origin
	var up := (hd - hp).normalized()
	var h := (hd - hp).length() * 2.2
	var c: Color = GearDB.TIER_COLORS[clampi(tier, 1, 3)]
	var orbit := Orbit.new()
	orbit.speed = 1.4 + 0.4 * tier
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = c.lightened(0.45)
	var halo_tex := GradientTexture2D.new()
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.9))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	halo_tex.gradient = g
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Keep the skeleton's scale (rigs in cm would make the halo huge).
	halo.billboard_keep_scale = true
	halo.albedo_texture = halo_tex
	halo.no_depth_test = false
	for k in (2 if tier >= 3 else 1):
		var ang := PI * k
		var at := Vector3(cos(ang), 0.0, sin(ang)) * h * 0.52
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = h * ((0.014 + 0.003 * tier) if CLEAN else (0.03 + 0.006 * tier))
		sm.height = sm.radius * 2.0
		sm.radial_segments = 16 if CLEAN else 8
		sm.rings = 8 if CLEAN else 4
		gem.mesh = sm
		gem.material_override = core
		gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gem.position = at
		orbit.add_child(gem)
		if CLEAN:
			continue
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * h * (0.07 + 0.012 * tier)
		glow.mesh = q
		glow.material_override = halo
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = at
		orbit.add_child(glow)
	_attach(sk, hips, "GearCharm", orbit, Transform3D(Basis(), hp + up * h * 0.16))


## Rune-tier pauldrons: the Ancient Pauldron prop (CC-BY) layered over each
## shoulder, mirrored, so rune plate changes the silhouette at hunt range.
static func _rune_pauldrons(sk: Skeleton3D, t: Dictionary, kit: Dictionary) -> void:
	for nm in ["GearPauldronL", "GearPauldronR"]:
		var old := sk.get_node_or_null(nm)
		if old:
			old.name = nm + "_old"
			old.queue_free()
	var src := str(kit.get("rune_pauldron", ""))
	if src == "" or int(t.get("pauldrons", 0)) < int(kit.get("rune_pauldron_tier", 3)):
		return
	var path := GEAR + src + ".res"
	if not ResourceLoader.exists(path):
		return
	var mesh: Mesh = load(path)
	var hips := -1
	var head := -1
	for i in sk.get_bone_count():
		var b := sk.get_bone_name(i).to_lower()
		if hips < 0 and b.begins_with("hips"):
			hips = i
		if head < 0 and b.begins_with("head"):
			head = i
	if hips < 0 or head < 0:
		return
	var h := (sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hips).origin).length() * 2.2
	var xf: Array = kit.get("rune_pauldron_xf", [Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 1.0])
	for side in ["l", "r"]:
		var bi := -1
		for i in sk.get_bone_count():
			var b := sk.get_bone_name(i).to_lower()
			if ("shoulder" in b or "clavicle" in b) and (b.begins_with(side + "_") or b.ends_with("_" + side) or b.ends_with("." + side) or ("left" if side == "l" else "right") in b):
				bi = i
				break
		if bi < 0:
			continue
		var at := sk.get_bone_global_rest(bi).origin
		var sx := 1.0 if side == "r" else -1.0
		var off: Vector3 = xf[0]
		var mb: Basis = sk.get_meta("mesh_basis", Basis())
		# Model's right is -X when it faces +Z.
		var right := (mb * Vector3(-1, 0, 0)).normalized()
		var up := (mb * Vector3.UP).normalized()
		var fw := (mb * Vector3(0, 0, 1)).normalized()
		var pos := at + (right * off.x * sx + up * off.y + fw * off.z) * h
		var eul: Vector3 = xf[1]
		var b3 := mb * Basis.from_euler(Vector3(eul.x, eul.y * sx, eul.z * sx) * PI / 180.0)
		# Prop is baked in centimetres; the rig may be in metres.
		var k := float(xf[2]) * h / 180.0
		b3 = b3 * Basis.from_scale(Vector3(k * sx, k, k))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var holder := Node3D.new()
		holder.add_child(mi)
		_attach(sk, bi, "GearPauldron" + side.to_upper(), holder, Transform3D(b3, pos))


## Charm, showcase style: a real pendant on the chest (gilt medallion with
## a cut gem, chain bail), sized up per tier; T3's gem is lit from within.
static func _amulet(sk: Skeleton3D, t: Dictionary, kit: Dictionary) -> void:
	for nm in ["GearCharm"]:
		var old := sk.get_node_or_null(nm)
		if old:
			old.name = nm + "_old"
			old.queue_free()
	var tier := int(t.get("charm", 0))
	if tier <= 0:
		return
	var chest := -1
	var hips := -1
	var head := -1
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).to_lower()
		if hips < 0 and nm.begins_with("hips"):
			hips = i
		if head < 0 and nm.begins_with("head"):
			head = i
		if nm.begins_with("chest") or nm.begins_with("upperchest") or nm.begins_with("spine2"):
			chest = i
	if hips < 0 or head < 0:
		return
	if chest < 0:
		chest = sk.get_bone_parent(sk.get_bone_parent(head)) if sk.get_bone_parent(head) >= 0 else hips
	var hp := sk.get_bone_global_rest(hips).origin
	var hd := sk.get_bone_global_rest(head).origin
	var h := (hd - hp).length() * 2.2
	var mb: Basis = sk.get_meta("mesh_basis", Basis())
	var fwd: Vector3 = (mb * (kit.get("fwd", Vector3(0, 0, 1)) as Vector3)).normalized()
	var upv: Vector3 = (mb * Vector3.UP).normalized()
	var at := hp.lerp(hd, float(kit.get("amulet_y", 0.62))) + fwd * h * float(kit.get("amulet_out", 0.085))
	var r := h * (0.026 + 0.006 * tier)
	var gilt := StandardMaterial3D.new()
	gilt.albedo_color = [Color(0.55, 0.5, 0.45), Color(0.62, 0.62, 0.66), Color(0.78, 0.6, 0.3), Color(0.8, 0.62, 0.32)][tier]
	gilt.metallic = 1.0
	gilt.roughness = 0.32
	var gem := StandardMaterial3D.new()
	gem.albedo_color = (GearDB.TIER_COLORS[clampi(tier, 1, 3)] as Color).darkened(0.2)
	gem.metallic = 0.0
	gem.roughness = 0.08
	gem.metallic_specular = 0.9
	if tier >= 3:
		gem.emission_enabled = true
		gem.emission = gem.albedo_color
		gem.emission_energy_multiplier = 0.8
	var root := Node3D.new()
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = r * 0.22
	cm.radial_segments = 32
	disc.mesh = cm
	disc.material_override = gilt
	disc.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(disc)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.86
	tm.outer_radius = r * 1.08
	tm.rings = 32
	tm.ring_segments = 10
	rim.mesh = tm
	rim.material_override = gilt
	rim.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(rim)
	var stone := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 0.5
	sm.height = r * 0.5
	sm.radial_segments = 6 if tier < 3 else 8
	sm.rings = 3
	stone.mesh = sm
	stone.material_override = gem
	stone.position = Vector3(0, 0, r * 0.12)
	root.add_child(stone)
	var bail := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = r * 0.16
	bm.outer_radius = r * 0.28
	bail.mesh = bm
	bail.material_override = gilt
	bail.position = Vector3(0, r * 1.2, 0)
	bail.rotation = Vector3(0, PI * 0.5, PI * 0.5)
	root.add_child(bail)
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var basis := Basis.looking_at(-fwd, upv)
	_attach(sk, chest, "GearCharm", root, Transform3D(basis, at))


## Rune chest (T3): a small wisp of embers rising off the plate (the edges
## carry the main read). One draw call.
static func _rune_embers(sk: Skeleton3D, t: Dictionary) -> void:
	var old := sk.get_node_or_null("GearEmbers")
	if old:
		old.free()
	if int(t.get("chest", 0)) < 3:
		return
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
	var hp := sk.get_bone_global_rest(hips).origin
	var hd := sk.get_bone_global_rest(head).origin
	var up := (hd - hp).normalized()
	var h := (hd - hp).length() * 2.2
	var p := CPUParticles3D.new()
	p.amount = 7
	p.lifetime = 2.2
	p.preprocess = 2.2
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(h * 0.12, h * 0.2, h * 0.08)
	p.direction = up
	p.spread = 25.0
	p.gravity = up * h * 0.12
	p.initial_velocity_min = h * 0.06
	p.initial_velocity_max = h * 0.16
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2.ONE * h * 0.022
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.42, 0.16)
	q.material = m
	p.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.75, 0.4, 1.0))
	grad.set_color(1, Color(1.0, 0.2, 0.06, 0.0))
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(sk, hips, "GearEmbers", p, Transform3D(Basis(), hp + up * h * 0.12))


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
static func finish(src: BaseMaterial3D, tier: int, cloth := false, prop := false, metal_mul: Array = []) -> ShaderMaterial:
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
	for fi in FINISH.size():
		var f: Dictionary = FINISH[fi]
		var metal: Color = f["metal"]
		if fi < metal_mul.size():
			metal = metal * float(metal_mul[fi])
		var soft: Color = f["cloth"] if cloth else f["soft"]
		var ec: Color = f.get("edge_col", Color(0.55, 0.57, 0.62))
		arrs["t_metal_tint"].append(Vector3(metal.r, metal.g, metal.b))
		arrs["t_soft_tint"].append(Vector3(soft.r, soft.g, soft.b))
		arrs["t_edge_col"].append(Vector3(ec.r, ec.g, ec.b))
		arrs["t_wear"].append(f["wear"])
		arrs["t_rough_mul"].append(f["rough_mul"])
		var damp := 1.0 - (float(metal_mul[fi]) if fi < metal_mul.size() else 1.0)
		arrs["t_rough_add"].append((float(f["rough_add"]) if src.roughness_texture else src.roughness + maxf(float(f["rough_add"]), 0.0)) + damp * 0.35)
		arrs["t_gain"].append(f["gain"])
		arrs["t_groove"].append(f.get("groove", 0.0))
		arrs["t_edge_hi"].append(float(f.get("edge_hi", 0.0)) * (float(metal_mul[fi]) if fi < metal_mul.size() else 1.0))
		arrs["t_edge_emit"].append(float(f.get("edge_emit", 0.0)) * (float(metal_mul[fi]) if fi < metal_mul.size() else 1.0))
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
	var horn_bind: Array[bool] = []
	for bi in skin.get_bind_count():
		var bname := String(skin.get_bind_name(bi))
		if bname == "":
			var bone := skin.get_bind_bone(bi)
			bname = sk.get_bone_name(bone) if bone >= 0 and bone < sk.get_bone_count() else ""
		bind_slot.append(bone_slot(bname))
		var lb := bname.to_lower()
		horn_bind.append(lb.begins_with("top") or lb.begins_with("tip") or lb.contains("horn"))
	# COLOR.g / COLOR.b: each vertex's horizontal / vertical offset from its
	# dominant bone (mesh space, Y up, in units of the mesh height), so a bare
	# slot can strip plate that stands proud of the body (helm horns).
	var hh := maxf(src.get_aabb().size.y, 0.001)
	var out := ArrayMesh.new()
	for bi in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(bi))
	out.blend_shape_mode = src.blend_shape_mode
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var fmt := src.surface_get_format(si)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nv: int = verts.size()
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
			var p := Vector3.ZERO
			if best < skin.get_bind_count():
				p = verts[v] - skin.get_bind_pose(best).affine_inverse().origin
			var radial := clampf(Vector2(p.x, p.z).length() / hh * 2.0, 0.0, 1.0)
			if slot == 0:
				# Head: only the side-to-side spread counts, so the visor and
				# crown stay while horns (which sweep out sideways) go.
				radial = clampf(absf(p.x) / hh * 2.0, 0.0, 1.0)
			if best < horn_bind.size() and horn_bind[best]:
				radial = 1.0
			var along := clampf(p.y / hh + 0.5, 0.0, 1.0)
			# COLOR.a: dominant bind + 1 (/ 1024) for bone-level bare cuts.
			cols[v] = Color(slot / 7.0, radial, along, float(best + 1) / 1024.0)
		arrays[Mesh.ARRAY_COLOR] = cols
		# Keep custom-channel formats and the 8-weight flag; drop compression
		# (the arrays come back decompressed).
		var flags := fmt & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		var bs := src.surface_get_blend_shape_arrays(si)
		out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays, bs, {}, flags)
		out.surface_set_material(si, src.surface_get_material(si))
		out.surface_set_name(si, src.surface_get_name(si))
	out.set_meta("slot_tagged", true)
	var bnames := PackedStringArray()
	for bi in skin.get_bind_count():
		var bn := String(skin.get_bind_name(bi))
		if bn == "":
			var bone := skin.get_bind_bone(bi)
			bn = sk.get_bone_name(bone) if bone >= 0 and bone < sk.get_bone_count() else ""
		bnames.append(bn.to_lower())
	out.set_meta("bind_names", bnames)
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
uniform vec3 base : source_color = vec3(0.3, 0.035, 0.03);
uniform vec3 glow : source_color = vec3(0.0);
float h1(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float u = UV.x * 70.0;
	float strand = mix(h1(floor(u)), h1(floor(u) + 1.0), smoothstep(0.0, 1.0, fract(u)));
	float tip = smoothstep(0.0, 0.5, UV.y) * smoothstep(1.0, 0.5, UV.y);
	// Horsehair is matte: a low sheen so strong showcase lights keep it
	// oxblood instead of washing it to salmon.
	ALBEDO = base * (0.35 + 0.55 * strand) * (0.5 + 0.4 * tip);
	ROUGHNESS = 0.95;
	SPECULAR = 0.06;
	EMISSION = glow * strand * tip;
}
"""
	return _crest_sh


## ---- Procedural caster gear (Corvin, the plague doctor) ------------------
## Simple primitive-built pieces for the caster hero: robes, mask, hat,
## gloves and staff. Tiers are strings: "apprentice" (dull), "adept"
## (richer colours), "master" (glowing accents). apply_caster_visual swaps
## the worn set on a spawned hero model.

const CASTER_SLOTS := ["robes", "mask", "hat", "gloves", "staff"]
const CASTER_TIERS := ["apprentice", "adept", "master"]
const CASTER_GLOW := Color(0.55, 1.0, 0.2)


## Normalize a tier value: a string tier name or a 1..3 int.
static func _caster_tier(t: Variant) -> String:
	if typeof(t) == TYPE_INT:
		return CASTER_TIERS[clampi(int(t), 1, 3) - 1]
	var s := str(t).to_lower()
	return s if CASTER_TIERS.has(s) else ""


## Tier-driven material: apprentice is dull and rough, adept is a richer
## dye with a slight sheen, master keeps the dark base but lights up.
static func _caster_mat(base: Color, tier: String, accent := Color(0.0, 0.0, 0.0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if tier == "adept":
		m.albedo_color = base.lightened(0.1)
		m.roughness = 0.55
	elif tier == "master":
		m.albedo_color = base
		m.roughness = 0.7
	else:
		m.albedo_color = base.darkened(0.15)
		m.roughness = 0.95
	if tier == "master" and accent.get_luminance() > 0.0:
		m.emission_enabled = true
		m.emission = accent
		m.emission_energy_multiplier = 1.4
	return m


## Dark cloth for robes and hats.
static func _caster_cloth(tier: String, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base: Color = col
	if tier == "adept":
		m.roughness = 0.85
	elif tier == "master":
		base = col.lightened(0.06)
	else:
		base = col.darkened(0.35)
	m.albedo_color = base
	m.roughness = 0.93
	m.metallic = 0.0
	return m


## A primitive-built caster piece for Corvin. Sized in metres for a 1.8 m
## hero; apply_caster_visual scales it to the rig.
static func build_caster_piece(hero_id: String, slot: String, tier: String) -> Node3D:
	var root := Node3D.new()
	root.name = "GearCaster_%s" % slot
	var t := _caster_tier(tier)
	if hero_id != "ember" or t == "":
		return root
	var glow := CASTER_GLOW if t == "master" else Color(0.0, 0.0, 0.0)
	match slot:
		"robes":
			# A tapered skirt of dark cloth: narrow at the chest, flared hem.
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.42
			cyl.height = 1.05
			cyl.radial_segments = 14
			cyl.rings = 4
			var mi := MeshInstance3D.new()
			mi.mesh = cyl
			mi.material_override = _caster_cloth(t, Color(0.16, 0.14, 0.15))
			mi.position.y = 0.72
			root.add_child(mi)
			if t == "master":
				# Glowing rune hem round the flare.
				var hem := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.41
				tm.outer_radius = 0.44
				tm.rings = 24
				tm.ring_segments = 6
				hem.mesh = tm
				hem.material_override = _caster_mat(Color(0.1, 0.1, 0.1), t, CASTER_GLOW)
				hem.position.y = 0.22
				root.add_child(hem)
		"mask":
			# Bone-white beak mask: a flattened sphere over the face.
			var sph := SphereMesh.new()
			sph.radius = 0.105
			sph.height = 0.21
			sph.radial_segments = 16
			sph.rings = 8
			var mi := MeshInstance3D.new()
			mi.mesh = sph
			mi.scale = Vector3(1.0, 1.15, 0.62)
			mi.material_override = _caster_mat(Color(0.78, 0.74, 0.63), t, glow)
			root.add_child(mi)
		"hat":
			# Wide-brim plague hat: a flat brim disc under a low cone.
			var brim := CylinderMesh.new()
			brim.top_radius = 0.21
			brim.bottom_radius = 0.21
			brim.height = 0.025
			brim.radial_segments = 18
			var brim_mi := MeshInstance3D.new()
			brim_mi.mesh = brim
			brim_mi.material_override = _caster_cloth(t, Color(0.12, 0.11, 0.1))
			brim_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(brim_mi)
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.135
			cone.height = 0.16
			cone.radial_segments = 12
			cone.rings = 2
			var cone_mi := MeshInstance3D.new()
			cone_mi.mesh = cone
			cone_mi.material_override = _caster_cloth(t, Color(0.12, 0.11, 0.1))
			cone_mi.position.y = 0.09
			root.add_child(cone_mi)
			if t == "master":
				var band := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.135
				tm.outer_radius = 0.15
				tm.rings = 20
				tm.ring_segments = 5
				band.mesh = tm
				band.material_override = _caster_mat(Color(0.1, 0.1, 0.1), t, CASTER_GLOW)
				band.position.y = 0.01
				root.add_child(band)
		"gloves":
			# Dark leather gloves: a small box (mount on each hand to pair).
			var box := BoxMesh.new()
			box.size = Vector3(0.11, 0.14, 0.06)
			var mi := MeshInstance3D.new()
			mi.mesh = box
			mi.material_override = _caster_mat(Color(0.17, 0.13, 0.1), t, glow)
			root.add_child(mi)
		"staff":
			# Ebon wood shaft topped by a crystal orb on the glowing tiers.
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.02
			shaft.bottom_radius = 0.028
			shaft.height = 1.55
			shaft.radial_segments = 8
			shaft.rings = 2
			var s := MeshInstance3D.new()
			s.mesh = shaft
			s.material_override = _caster_mat(Color(0.24, 0.17, 0.12), t)
			s.position.y = 0.78
			root.add_child(s)
			var orb := SphereMesh.new()
			orb.radius = 0.075
			orb.height = 0.15
			orb.radial_segments = 14
			orb.rings = 7
			var o := MeshInstance3D.new()
			o.mesh = orb
			var crystal: Color = [Color(0.35, 0.42, 0.3), Color(0.3, 0.55, 0.25), CASTER_GLOW][int(clampi(CASTER_TIERS.find(t), 0, 2))]
			o.material_override = _caster_mat(crystal, "apprentice" if t == "apprentice" else t, glow)
			o.position.y = 1.66
			root.add_child(o)
	return root


## Swap Corvin's caster pieces from an equipped dict: {slot: tier} where a
## slot is one of CASTER_SLOTS and the value is "apprentice"/"adept"/"master"
## (missing or empty = not worn). Pieces mount on the rig's bones sized from
## the hero's height; previous GearCaster* nodes are replaced first.
static func apply_caster_visual(hero_node: Node3D, equipped: Dictionary) -> void:
	for old in hero_node.find_children("GearCaster*", "Node3D", true, false):
		(old as Node3D).queue_free()
	var sk: Skeleton3D = null
	for n in hero_node.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	if sk == null:
		return
	var hips := -1
	var head := -1
	var chest := -1
	var hand := -1
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).to_lower()
		if hips < 0 and nm.begins_with("hips"):
			hips = i
		if head < 0 and nm.begins_with("head"):
			head = i
		if chest < 0 and (nm.begins_with("chest") or nm.begins_with("spine")):
			chest = i
		if hand < 0 and "hands" in nm:
			hand = i
	if hips < 0 or head < 0:
		return
	var hp := sk.get_bone_global_rest(hips).origin
	var hd := sk.get_bone_global_rest(head).origin
	var up := (hd - hp).normalized()
	var h := (hd - hp).length() * 2.2
	var k := h / 1.8
	for sl in CASTER_SLOTS:
		var t := _caster_tier(equipped.get(sl, ""))
		if t == "":
			continue
		var piece := build_caster_piece("ember", sl, t)
		var bone := head
		var at := Vector3.ZERO
		match sl:
			"robes":
				bone = chest if chest >= 0 else hips
			"mask":
				at = up * 0.05 * k
			"hat":
				at = up * 0.14 * k
			"gloves", "staff":
				bone = hand if hand >= 0 else hips
		var side := up.cross(Vector3(1, 0, 0) if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3(0, 0, 1)).normalized()
		var basis := (Basis(side, up, side.cross(up)) as Basis) * Basis.from_scale(Vector3.ONE * k)
		_attach(sk, bone, "GearCaster_%s" % sl, piece, Transform3D(basis, sk.get_bone_global_rest(bone).origin + at))
