class_name Plate3D
extends RefCounted

## Real swappable plate armor for the knight heroes (pebble = Aldric,
## bramble = Mordrek). Every piece is built from primitives in skeleton
## space, baked to one ArrayMesh per material, and hung on its anchor bone
## with a BoneAttachment3D (plate is rigid, so no skinning is needed).
##
## Materials are the artist's scanned PBR sets in the armor3d.gd style
## (iron / blackened steel / rune plate / bronze / leather / bone); tiers
## read from geometry, never from a recolor shader.
##
## Gear3D.dress calls dress() in the CLEAN path. Underneath the pieces, the
## baked plate for these slots is re-materialed as gambeson padding (the
## arming doublet a knight wears under plate), so the base body stays
## stripped-down and each equipped piece owns its slot's silhouette.

const ARMOR_SLOTS := ["helm", "chest", "pauldrons", "gloves", "boots"]

## Anchor bones per hero (exact Skeleton3D names).
const BONES := {
	"pebble": {
		"hips": "hips_01", "spine": "spine_012", "chest": "chest_013",
		"neck": "neck_061", "head": "head_062",
		"shoulder.l": "L_shoulder_014", "shoulder.r": "R_shoulder_038",
		"elbow.l": "L_elbow_016", "elbow.r": "R_elbow_040",
		"wrist.l": "L_wrist_017", "wrist.r": "R_wrist_041",
		"knee.l": "L_knee_08", "knee.r": "R_knee_03",
		"ankle.l": "L_ankle_09", "ankle.r": "R_ankle_04",
		"foot.l": "L_foot_010", "foot.r": "R_foot_05",
		"toes.l": "L_toes_011", "toes.r": "R_toes_06",
	},
	"bramble": {
		"hips": "hips_01", "spine": "spine_034", "chest": "chest_035",
		"neck": "neck_084", "head": "head_085",
		"shoulder.l": "L_shoulder_036", "shoulder.r": "R_shoulder_060",
		"elbow.l": "L_elbow_038", "elbow.r": "R_elbow_062",
		"wrist.l": "L_wrist_039", "wrist.r": "R_wrist_063",
		"knee.l": "L_knee_030", "knee.r": "R_knee_025",
		"ankle.l": "L_ankle_031", "ankle.r": "R_ankle_026",
		"foot.l": "L_foot_032", "foot.r": "R_foot_027",
		"toes.l": "L_toes_033", "toes.r": "R_toes_028",
	},
}

static var _mats := {}
static var _cache := {}


## Dress the skeleton: mount a real piece for every armor slot at tier >= 1.
## Re-entrant: old Plate* attachments are freed first, so re-dressing after
## an equip/unequip swaps the meshes.
static func dress(sk: Skeleton3D, hero: String, t: Dictionary) -> void:
	if not BONES.has(hero):
		return
	for child in sk.get_children():
		if String(child.name).begins_with("Plate"):
			child.free()
	var F := _frame(sk, hero)
	for slot in ARMOR_SLOTS:
		var tier := clampi(int(t.get(slot, 0)), 0, 3)
		if tier < 1:
			continue
		match hero:
			"pebble":
				_pebble_piece(sk, slot, tier, F)
			"bramble":
				_bramble_piece(sk, slot, tier, F)


## Character frame in skeleton space: bone positions, up/lateral/facing
## directions, and a standing-height scale all pieces are authored against.
static func _frame(sk: Skeleton3D, hero: String) -> Dictionary:
	var P := {}
	for k in (BONES[hero] as Dictionary):
		var bi := sk.find_bone(String((BONES[hero] as Dictionary)[k]))
		P[k] = sk.get_bone_global_rest(bi).origin if bi >= 0 else Vector3.ZERO
	var hips: Vector3 = P["hips"]
	var head: Vector3 = P["head"]
	var up := (head - hips).normalized()
	var lat := ((P["shoulder.l"] as Vector3) - (P["shoulder.r"] as Vector3)).normalized()
	var fwd := lat.cross(up).normalized()
	var h := (head - hips).length() * 2.2
	return {"P": P, "up": up, "lat": lat, "fwd": fwd, "h": h}


# --- materials -------------------------------------------------------------
## The artist's scanned PBR sets (armor3d.gd style): albedo/normal maps with
## a modest material tint, metallic/roughness per finish. Tier identity comes
## from which material a piece uses and from its geometry, not from a shader.
static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"iron":
			# T1: worn bright iron, warm and scuffed.
			m.albedo_texture = load("res://assets/textures/armor_steel_col.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_steel_nrm.jpg")
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
			m.albedo_color = Color(0.66, 0.62, 0.56)
			m.metallic = 0.85
			m.roughness = 0.52
			m.normal_scale = 1.2
		"steel":
			# T2: blackened, oil-dark steel; edges catch the light.
			m.albedo_texture = load("res://assets/textures/armor_steel_col.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_steel_nrm.jpg")
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
			m.albedo_color = Color(0.3, 0.32, 0.38)
			m.metallic = 0.9
			m.roughness = 0.36
			m.normal_scale = 1.4
		"runeplate":
			# T3: near-black cursed plate.
			m.albedo_texture = load("res://assets/textures/armor_steel_col.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_steel_nrm.jpg")
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
			m.albedo_color = Color(0.1, 0.095, 0.105)
			m.metallic = 0.75
			m.roughness = 0.42
			m.normal_scale = 1.4
		"bronze":
			m.albedo_texture = load("res://assets/textures/armor_bronze_col.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_bronze_nrm.jpg")
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
			m.albedo_color = Color(0.62, 0.58, 0.46)
			m.metallic = 0.55
			m.roughness = 0.6
			m.normal_scale = 1.0
		"leather":
			m.albedo_texture = load("res://assets/textures/armor_leather_col.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_leather_nrm.jpg")
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
			m.albedo_color = Color(0.5, 0.4, 0.32)
			m.metallic = 0.0
			m.roughness = 0.92
			m.normal_scale = 1.2
		"bone":
			# Mordrek T1: pale grave bone.
			m.albedo_color = Color(0.78, 0.72, 0.6)
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_steel_nrm.jpg")
			m.uv1_scale = Vector3(3.0, 3.0, 1.0)
			m.metallic = 0.05
			m.roughness = 0.62
			m.normal_scale = 0.7
		"bonedark":
			# Mordrek T2: charred bone.
			m.albedo_color = Color(0.22, 0.2, 0.18)
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/armor_steel_nrm.jpg")
			m.uv1_scale = Vector3(3.0, 3.0, 1.0)
			m.metallic = 0.15
			m.roughness = 0.68
			m.normal_scale = 0.9
		"soulfire":
			# Mordrek T3 accents: cold corpse-light, kept under the bloom
			# threshold so edges stay crisp.
			m.albedo_color = Color(0.2, 0.5, 0.32)
			m.emission_enabled = true
			m.emission = Color(0.3, 1.0, 0.62)
			m.emission_energy_multiplier = 0.55
			m.roughness = 0.5
		"runeglow":
			# Aldric T3 accents: embers in the seams, under the bloom threshold.
			m.albedo_color = Color(0.5, 0.2, 0.08)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.42, 0.1)
			m.emission_energy_multiplier = 0.55
			m.roughness = 0.5
		"dark":
			# Visor slits, padding shadow.
			m.albedo_color = Color(0.04, 0.035, 0.035)
			m.roughness = 0.95
		"oxblood":
			# Horsehair crest: dark oxblood strands.
			m.albedo_color = Color(0.26, 0.035, 0.03)
			m.roughness = 0.95
			m.metallic_specular = 0.06
	_mats[kind] = m
	return m


# --- primitive baking ------------------------------------------------------
static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 5
	return c


static func _cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _cone(r: float, h: float, seg := 10) -> CylinderMesh:
	return _cyl(0.0, r, h, seg)


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 20
	t.ring_segments = 8
	return t


static func _xf(at: Vector3, scale: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), at)


## Basis with +Y along `d` (for orienting cylinders/cones along limbs).
static func _y_to(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Append `mesh` (transformed by `xf`) into the per-material accumulator.
## `keep` optionally drops triangles: func(centroid, normal) -> bool.
## NOTE: PackedArrays from a Dictionary are copies; we write them back.
static func _prim(acc: Dictionary, mat: String, mesh: Mesh, xf: Transform3D, keep: Callable = Callable()) -> void:
	if not acc.has(mat):
		acc[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(),
				"uv": PackedVector2Array(), "i": PackedInt32Array()}
	var a: Dictionary = acc[mat]
	var av: PackedVector3Array = a["v"]
	var an: PackedVector3Array = a["n"]
	var au: PackedVector2Array = a["uv"]
	var ai: PackedInt32Array = a["i"]
	var src := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var uvs = src[Mesh.ARRAY_TEX_UV]
	var nb := xf.basis.inverse().transposed()
	var base: int = av.size()
	var tv := PackedVector3Array()
	var tn := PackedVector3Array()
	tv.resize(verts.size())
	tn.resize(verts.size())
	for k in verts.size():
		tv[k] = xf * verts[k]
		tn[k] = (nb * norms[k]).normalized() if norms.size() > k else Vector3.UP
		av.append(tv[k])
		an.append(tn[k])
		au.append(uvs[k] if uvs != null and uvs.size() > k else Vector2.ZERO)
	var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var has_keep := keep.is_valid()
	var tris: Array = []
	if idx != null and not idx.is_empty():
		var o := 0
		while o < idx.size():
			tris.append([idx[o], idx[o + 1], idx[o + 2]])
			o += 3
	else:
		var o := 0
		while o < verts.size():
			tris.append([o, o + 1, o + 2])
			o += 3
	for t in tris:
		if has_keep:
			var c := (tv[t[0]] + tv[t[1]] + tv[t[2]]) / 3.0
			var n := (tn[t[0]] + tn[t[1]] + tn[t[2]]).normalized()
			if not bool(keep.call(c, n)):
				continue
		ai.append_array([base + t[0], base + t[1], base + t[2]])
	a["v"] = av
	a["n"] = an
	a["uv"] = au
	a["i"] = ai


## One ArrayMesh per piece: a surface per material (a handful of draws).
static func _bake(acc: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in acc:
		var a: Dictionary = acc[mat]
		if (a["i"] as PackedInt32Array).is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = a["v"]
		arr[Mesh.ARRAY_NORMAL] = a["n"]
		arr[Mesh.ARRAY_TEX_UV] = a["uv"]
		arr[Mesh.ARRAY_INDEX] = a["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(String(mat)))
	return mesh


static func _attach(sk: Skeleton3D, bone: int, label: String, mesh: ArrayMesh) -> void:
	if bone < 0 or mesh == null or mesh.get_surface_count() == 0:
		return
	var att := BoneAttachment3D.new()
	att.name = label
	att.bone_idx = bone
	sk.add_child(att)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	# Pieces are authored in skeleton space; the attachment rides the bone.
	mi.transform = sk.get_bone_global_rest(bone).affine_inverse()
	att.add_child(mi)


static func _bone(sk: Skeleton3D, hero: String, key: String) -> int:
	return sk.find_bone(String((BONES[hero] as Dictionary)[key]))

# --- pebble (Aldric, classic knight) -----------------------------------------
static func _pebble_piece(sk: Skeleton3D, slot: String, tier: int, F: Dictionary) -> void:
	match slot:
		"helm":
			_pebble_helm(sk, tier, F)
		"chest":
			_pebble_chest(sk, tier, F)
		"pauldrons":
			_pebble_pauldrons(sk, tier, F)
		"gloves":
			_pebble_gloves(sk, tier, F)
		"boots":
			_pebble_boots(sk, tier, F)


## Helm: an iron bascinet (T1), a blackened-steel helm with crest (T2), a
## horned runebound great helm (T3). Domes enclose the baked helm's crown;
## the face window leaves the artist's face plate visible.
static func _pebble_helm(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var lat: Vector3 = F["lat"]
	var head: Vector3 = P["head"]
	var neck: Vector3 = P["neck"]
	var acc := {}
	var plate: String = ["iron", "iron", "steel", "runeplate"][tier]
	var dome_c := head + up * 6.0
	var dome_r: float = [0.0, 12.5, 13.5, 14.0][tier]
	# Face window: the front of the dome below the brow line stays open.
	var face_cut := func(p: Vector3, n: Vector3) -> bool:
		var rel := p - dome_c
		if p.y < head.y + 1.5:
			return false
		if rel.dot(fwd) > 2.0 and p.y < dome_c.y + 5.0 and absf(rel.dot(lat)) < 9.0:
			return false
		return true
	_prim(acc, plate, _sphere(dome_r), _xf(dome_c, Vector3(1.02, 1.08, 1.06)), face_cut)
	# Nasal guard down the face window.
	_prim(acc, plate, _box(Vector3(2.4, 8.0, 1.4)), _xf(head + fwd * 10.5 + up * 1.0))
	if tier == 1:
		# Mail aventail curtaining the neck: leather over the coif.
		_prim(acc, "leather", _cyl(8.5, 12.5, 10.0), _xf(neck + up * 1.0 - fwd * 1.0))
	elif tier == 2:
		# Visor slit: a dark inset across the face window.
		_prim(acc, "dark", _box(Vector3(13.0, 2.6, 1.6)), _xf(head + fwd * 10.0 + up * 4.0))
		# Bronze brow band.
		_prim(acc, "bronze", _torus(11.5, 12.6),
				_xf(dome_c + up * 2.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
		# Horsehair crest front to back.
		_prim(acc, "oxblood", _capsule(2.3, 17.0),
				_xf(dome_c + up * (dome_r * 1.02), Vector3.ONE, Vector3(PI * 0.5, 0, 0)))
		# Steel gorget at the throat.
		_prim(acc, "steel", _torus(8.5, 10.5),
				_xf(neck + up * 2.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
	else:
		# The baked horns are the T3 crown (kept by the strip); the dome
		# adds the rune band and spike.
		# Burning rune band round the brow.
		for k in 5:
			var a := -0.5 + k * 0.25
			var at := dome_c + fwd * 12.6 * cos(a) + lat * 12.6 * sin(a) + up * 3.0
			_prim(acc, "runeglow", _box(Vector3(1.6, 1.6, 0.7)),
					Transform3D(Basis.from_euler(Vector3(0, a, 0)), at))
		# Rune brow spikes (small, between the baked horns).
		# Rune gorget.
		_prim(acc, "runeplate", _torus(8.5, 10.5),
				_xf(neck + up * 2.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
	_attach(sk, _bone(sk, "pebble", "head"), "PlateHelm", _bake(acc))


## Chest: a real cuirass over the gambeson — plain iron (T1), blackened
## steel with faulds and bronze waist (T2), massive runebound plate with a
## burning emblem (T3).
static func _pebble_chest(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var lat: Vector3 = F["lat"]
	var chest: Vector3 = P["chest"]
	var hips: Vector3 = P["hips"]
	var neck: Vector3 = P["neck"]
	var acc := {}
	var plate: String = ["iron", "iron", "steel", "runeplate"][tier]
	var cy := (chest.y + hips.y) * 0.5 + 8.0
	var centre := Vector3(0, cy, 2.0)
	if tier == 1:
		_prim(acc, plate, _cyl(20.0, 17.0, 50.0), _xf(centre, Vector3(1.3, 1.0, 0.95)))
		# Leather fauld skirt: two lames.
		_prim(acc, "leather", _cyl(14.5, 17.0, 9.0), _xf(centre - up * 26.0, Vector3(1.25, 1.0, 0.9)))
		_prim(acc, "leather", _cyl(17.0, 19.5, 9.0), _xf(centre - up * 34.0, Vector3(1.25, 1.0, 0.9)))
	elif tier == 2:
		_prim(acc, plate, _cyl(22.0, 18.5, 54.0), _xf(centre, Vector3(1.3, 1.0, 0.95)))
		# Plackart ridge down the front.
		_prim(acc, plate, _box(Vector3(3.2, 30.0, 2.2)), _xf(centre + fwd * 13.5 + up * 4.0))
		# Steel gorget.
		_prim(acc, plate, _torus(9.0, 11.0), _xf(neck + up * 1.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
		# Three steel fauld lames.
		for k in 3:
			_prim(acc, plate, _cyl(12.5 + k * 2.0, 14.5 + k * 2.0, 7.5),
					_xf(centre - up * (26.0 + k * 7.0), Vector3(1.2, 1.0, 0.85)))
		# Bronze waist trim.
		_prim(acc, "bronze", _torus(12.8, 13.8),
				_xf(centre - up * 20.0, Vector3(1.2, 1.0, 0.85), Vector3(PI * 0.5, 0, 0)))
	else:
		_prim(acc, plate, _cyl(23.0, 19.5, 56.0), _xf(centre, Vector3(1.3, 1.0, 0.95)))
		# Burning chest emblem: crossed rune bars.
		_prim(acc, "runeglow", _box(Vector3(1.8, 12.0, 0.8)), _xf(centre + fwd * 14.8 + up * 10.0))
		_prim(acc, "runeglow", _box(Vector3(8.0, 1.8, 0.8)), _xf(centre + fwd * 14.8 + up * 10.0))
		# Rune gorget.
		_prim(acc, plate, _torus(9.0, 11.0), _xf(neck + up * 1.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
		# Fauld lames with spikes.
		for k in 3:
			var yc := centre - up * (27.0 + k * 7.5)
			_prim(acc, plate, _cyl(13.5 + k * 2.0, 15.5 + k * 2.0, 7.5),
					_xf(yc, Vector3(1.2, 1.0, 0.85)))
			for s in 4:
				var a := s * PI * 0.5 + k * 0.4
				var at := yc + lat * cos(a) * 16.0 + fwd * sin(a) * 13.0 - up * 3.0
				_prim(acc, plate, _cone(1.1, 5.0), Transform3D(_y_to(up * 0.4 + (at - yc).normalized() * 0.9), at))
		# Glowing seam lines down the sides.
		for s in [1.0, -1.0]:
			_prim(acc, "runeglow", _box(Vector3(0.9, 34.0, 0.9)),
					_xf(centre + lat * s * 16.5 + up * 2.0))
	_attach(sk, _bone(sk, "pebble", "chest"), "PlateChest", _bake(acc))


## Pauldrons: layered shoulder cops, one lame a tier bigger each step, with
## spikes and rune-light at T3.
static func _pebble_pauldrons(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var lat: Vector3 = F["lat"]
	var fwd: Vector3 = F["fwd"]
	var plate: String = ["iron", "iron", "steel", "runeplate"][tier]
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var sh: Vector3 = P["shoulder." + side]
		var acc := {}
		var c := sh + up * 4.0 + lat * s * 2.0
		if tier == 1:
			_prim(acc, plate, _sphere(14.0), _xf(c, Vector3(1.35, 0.85, 1.35)))
		elif tier == 2:
			_prim(acc, plate, _sphere(15.0), _xf(c, Vector3(1.35, 0.9, 1.35)))
			_prim(acc, plate, _sphere(7.5), _xf(c + lat * s * 4.0 - up * 4.0, Vector3(1.2, 0.7, 1.2)))
			_prim(acc, "bronze", _torus(8.6, 9.6),
					_xf(c - up * 2.0, Vector3(1.2, 1.0, 1.2), Vector3(PI * 0.5, 0, 0)))
		else:
			_prim(acc, plate, _sphere(16.0), _xf(c, Vector3(1.4, 0.95, 1.4)))
			_prim(acc, plate, _sphere(8.5), _xf(c + lat * s * 5.0 - up * 5.0, Vector3(1.2, 0.7, 1.2)))
			_prim(acc, plate, _sphere(6.5), _xf(c + lat * s * 9.0 - up * 9.0, Vector3(1.15, 0.65, 1.15)))
			for k in 3:
				var at := c + up * (6.0 - k * 1.5) + lat * s * (k * 2.5) - fwd * 2.0
				_prim(acc, plate, _cone(1.5, 7.5), Transform3D(_y_to((up * 0.8 + lat * s * 0.45).normalized()), at))
			_prim(acc, "runeglow", _sphere(1.1), _xf(c + up * 7.5))
		_attach(sk, _bone(sk, "pebble", "shoulder." + side),
				"PlatePauldron" + side.to_upper(), _bake(acc))


## Gloves: gauntlets over the gambeson — leather cuffs (T1), steel with
## knuckle plates (T2), spiked runebound (T3).
static func _pebble_gloves(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var plate: String = ["iron", "iron", "steel", "runeplate"][tier]
	for side in ["l", "r"]:
		var wrist: Vector3 = P["wrist." + side]
		var elbow: Vector3 = P["elbow." + side]
		var acc := {}
		var dir := (wrist - elbow).normalized()
		var basis := _y_to(dir)
		if tier == 1:
			_prim(acc, "leather", _cyl(6.0, 8.5, 13.0), Transform3D(basis, wrist - dir * 4.0))
			_prim(acc, "leather", _box(Vector3(7.0, 2.8, 9.5)),
					Transform3D(Basis.from_euler(Vector3(0.35, 0, 0)), wrist + fwd * 5.0 - up * 2.5))
		elif tier == 2:
			_prim(acc, plate, _cyl(6.5, 9.0, 14.0), Transform3D(basis, wrist - dir * 4.0))
			_prim(acc, "bronze", _torus(6.4, 7.3),
					Transform3D(basis * Basis.from_euler(Vector3(PI * 0.5, 0, 0)), wrist - dir * 9.0))
			_prim(acc, plate, _box(Vector3(8.0, 2.2, 3.0)),
					Transform3D(Basis.from_euler(Vector3(0.35, 0, 0)), wrist + fwd * 6.5 - up * 1.0))
			for k in 3:
				_prim(acc, plate, _box(Vector3(2.0, 1.6, 4.5)),
						_xf(wrist + fwd * (9.5 + k * 0.4) - up * (2.5 + k * 0.9) + Vector3(k - 1, 0, 0) * 2.2))
		else:
			_prim(acc, plate, _cyl(7.0, 9.5, 15.0), Transform3D(basis, wrist - dir * 4.0))
			_prim(acc, plate, _box(Vector3(8.5, 3.0, 4.0)),
					Transform3D(Basis.from_euler(Vector3(0.35, 0, 0)), wrist + fwd * 6.5 - up * 1.0))
			for k in 4:
				var at := wrist + fwd * 8.5 - up * 0.5 + Vector3(k - 1.5, 0, 0) * 2.1
				_prim(acc, plate, _cone(1.0, 4.5), Transform3D(_y_to(fwd), at + fwd * 2.0))
			_prim(acc, "runeglow", _sphere(0.9), _xf(wrist - dir * 9.5 + up * 3.0))
		_attach(sk, _bone(sk, "pebble", "wrist." + side),
				"PlateGlove" + side.to_upper(), _bake(acc))


## Boots: greaves and sabatons — leather (T1), steel with poleyns (T2),
## massive runebound with spurs (T3).
static func _pebble_boots(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var plate: String = ["iron", "iron", "steel", "runeplate"][tier]
	for side in ["l", "r"]:
		var knee: Vector3 = P["knee." + side]
		var ankle: Vector3 = P["ankle." + side]
		var foot: Vector3 = P["foot." + side]
		var toes: Vector3 = P["toes." + side]
		var acc := {}
		var shin := (ankle - knee)
		var shin_len := shin.length()
		var sbasis := _y_to(shin.normalized())
		var smid := (knee + ankle) * 0.5
		var fwd_f := (toes - foot).normalized()
		var fmid := (foot + toes) * 0.5
		if tier == 1:
			_prim(acc, "leather", _cyl(8.0, 7.0, shin_len * 0.9), Transform3D(sbasis, smid))
			_prim(acc, "leather", _box(Vector3(7.5, 5.0, 17.0)),
					Transform3D(Basis.from_euler(Vector3(0, atan2(fwd_f.x, fwd_f.z), 0)), fmid + up * 1.0))
		elif tier == 2:
			_prim(acc, plate, _cyl(9.0, 7.5, shin_len * 0.95), Transform3D(sbasis, smid))
			_prim(acc, plate, _sphere(5.5), _xf(knee + up * 1.0, Vector3(1.0, 0.9, 1.0)))
			_prim(acc, "bronze", _torus(6.6, 7.4),
					Transform3D(sbasis * Basis.from_euler(Vector3(PI * 0.5, 0, 0)), smid + shin.normalized() * shin_len * 0.32))
			_prim(acc, plate, _box(Vector3(7.0, 4.5, 15.0)),
					Transform3D(Basis.from_euler(Vector3(0, atan2(fwd_f.x, fwd_f.z), 0)), fmid + up * 1.0))
			_prim(acc, plate, _cone(3.2, 7.0, 4),
					Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, atan2(fwd_f.x, fwd_f.z))), toes + up * 1.5))
		else:
			_prim(acc, plate, _cyl(9.5, 8.0, shin_len * 0.95), Transform3D(sbasis, smid))
			_prim(acc, plate, _sphere(6.0), _xf(knee + up * 1.0, Vector3(1.0, 0.9, 1.0)))
			for k in 3:
				var a := -0.5 + k * 0.5
				var at := knee + up * 2.0 + fwd * cos(a) * 5.0 + Vector3(sin(a) * 5.0, 0, 0)
				_prim(acc, plate, _cone(1.0, 4.5), Transform3D(_y_to((up * 0.5 + fwd * 0.85).normalized()), at))
			_prim(acc, plate, _box(Vector3(7.5, 5.0, 17.0)),
					Transform3D(Basis.from_euler(Vector3(0, atan2(fwd_f.x, fwd_f.z), 0)), fmid + up * 1.0))
			_prim(acc, plate, _cone(3.4, 10.0, 4),
					Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, atan2(fwd_f.x, fwd_f.z))), toes + fwd_f * 3.0 + up * 1.5))
			_prim(acc, "runeglow", _box(Vector3(0.8, 0.8, 12.0)),
					Transform3D(Basis.from_euler(Vector3(0, atan2(fwd_f.x, fwd_f.z), 0)), fmid + up * 3.6))
		_attach(sk, _bone(sk, "pebble", "ankle." + side),
				"PlateBoot" + side.to_upper(), _bake(acc))

# --- bramble (Mordrek, the Bone Knight) ---------------------------------------
static func _bramble_piece(sk: Skeleton3D, slot: String, tier: int, F: Dictionary) -> void:
	match slot:
		"helm":
			_bramble_helm(sk, tier, F)
		"chest":
			_bramble_chest(sk, tier, F)
		"pauldrons":
			_bramble_pauldrons(sk, tier, F)
		"gloves":
			_bramble_gloves(sk, tier, F)
		"boots":
			_bramble_boots(sk, tier, F)


## Helm: pale bone half-helm over the bare skull (T1), a charred full
## skull-helm (T2), a horned crown with soulfire eyes (T3). The baked helm
## mesh is hidden for plate kits; the skull shows through the face opening.
static func _bramble_helm(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var lat: Vector3 = F["lat"]
	var head: Vector3 = P["head"]
	var neck: Vector3 = P["neck"]
	var acc := {}
	var plate: String = ["bone", "bone", "bonedark", "bonedark"][tier]
	var dome_c := head + up * 5.0
	var dome_r: float = [0.0, 8.0, 8.8, 9.2][tier]
	var face_cut := func(p: Vector3, n: Vector3) -> bool:
		var rel := p - dome_c
		if p.y < head.y + 1.0:
			return false
		if rel.dot(fwd) > 1.0 and p.y < dome_c.y + 2.0 and absf(rel.dot(lat)) < 8.0:
			return false
		return true
	_prim(acc, plate, _sphere(dome_r), _xf(dome_c, Vector3(1.0, 1.1, 1.05)), face_cut)
	# Heavy brow ridge.
	_prim(acc, plate, _box(Vector3(10.0, 2.2, 2.5)), _xf(dome_c + fwd * 5.8 + up * 2.8))
	if tier == 1:
		# Cheek guards framing the skull.
		for s in [1.0, -1.0]:
			_prim(acc, plate, _box(Vector3(1.6, 7.0, 5.0)),
					_xf(head + lat * s * 8.5 + fwd * 4.0 - up * 2.0, Vector3.ONE, Vector3(0, s * 0.25, 0)))
		# Bone gorget.
		_prim(acc, plate, _torus(7.5, 9.5),
				_xf(neck + up * 1.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
	elif tier == 2:
		# Face plate with eye slits over the skull.
		_prim(acc, plate, _box(Vector3(12.0, 9.0, 2.0)), _xf(head + fwd * 8.0 - up * 1.0))
		for s in [1.0, -1.0]:
			_prim(acc, "dark", _box(Vector3(3.2, 1.4, 0.8)), _xf(head + lat * s * 3.4 + fwd * 9.2 + up * 2.0))
		_prim(acc, plate, _box(Vector3(2.0, 6.0, 1.6)), _xf(head + fwd * 9.4 - up * 2.0))
	else:
		# Horned crown: four horns sweeping up.
		for s in [1.0, -1.0]:
			for k in 2:
				var base: Vector3 = dome_c + lat * s * (8.0 + k * 3.5) + up * (6.0 - k * 1.0)
				var d: Vector3 = (lat * s * (0.55 - k * 0.2) + up * 0.85).normalized()
				_prim(acc, "bonedark", _cone(2.2 - k * 0.5, 10.0 - k * 2.0),
						Transform3D(_y_to(d), base + d * 4.5))
		# Soulfire eye slits.
		for s in [1.0, -1.0]:
			_prim(acc, "soulfire", _box(Vector3(3.4, 1.2, 0.8)), _xf(head + lat * s * 3.4 + fwd * 9.4 + up * 2.0))
		# Jaw guard fangs.
		for k in 3:
			var at := head + fwd * 8.5 - up * 6.5 + lat * (k - 1) * 3.0
			_prim(acc, "bonedark", _cone(0.9, 3.5), Transform3D(_y_to(-up), at))
		# Soulfire circlet.
		_prim(acc, "soulfire", _torus(10.8, 11.6),
				_xf(dome_c + up * 1.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
	_attach(sk, _bone(sk, "bramble", "head"), "PlateHelm", _bake(acc))


## Chest: a ribcage cuirass — pale bone (T1), charred with a spine ridge
## (T2), black with burning soulfire ribs (T3).
static func _bramble_chest(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var lat: Vector3 = F["lat"]
	var chest: Vector3 = P["chest"]
	var hips: Vector3 = P["hips"]
	var neck: Vector3 = P["neck"]
	var acc := {}
	var plate: String = ["bone", "bone", "bonedark", "bonedark"][tier]
	var cy := (chest.y + hips.y) * 0.5 + 7.0
	var centre := Vector3(0, cy, 5.0)
	if tier == 1:
		_prim(acc, plate, _cyl(9.0, 7.5, 34.0), _xf(centre, Vector3(1.1, 1.0, 0.8)))
		# Sternum ridge.
		_prim(acc, plate, _box(Vector3(2.6, 26.0, 1.8)), _xf(centre + fwd * 10.5 + up * 4.0))
		# Bone fauld lames.
		for k in 2:
			_prim(acc, plate, _cyl(10.5 + k * 1.8, 12.5 + k * 1.8, 7.0),
					_xf(centre - up * (22.0 + k * 6.5), Vector3(1.15, 1.0, 0.8)))
	elif tier == 2:
		_prim(acc, plate, _cyl(9.8, 8.2, 38.0), _xf(centre, Vector3(1.1, 1.0, 0.8)))
		# Vertebrae ridge down the spine.
		for k in 6:
			_prim(acc, plate, _sphere(1.8), _xf(centre - fwd * 9.5 + up * (16.0 - k * 6.0)))
		# Charred faulds.
		for k in 3:
			_prim(acc, plate, _cyl(11.5 + k * 2.0, 13.5 + k * 2.0, 7.0),
					_xf(centre - up * (24.0 + k * 6.5), Vector3(1.15, 1.0, 0.8)))
		# Bone gorget.
		_prim(acc, plate, _torus(8.0, 10.0),
				_xf(neck + up * 1.0, Vector3(1.0, 1.0, 1.0), Vector3(PI * 0.5, 0, 0)))
	else:
		_prim(acc, "bonedark", _cyl(10.5, 9.0, 40.0), _xf(centre, Vector3(1.1, 1.0, 0.8)))
		# Burning ribs across the chest.
		for k in 4:
			var yc := centre + up * (14.0 - k * 7.0)
			_prim(acc, "soulfire", _torus(11.8, 12.5),
					_xf(yc, Vector3(1.15, 1.0, 0.8), Vector3(PI * 0.5, 0, 0)))
		# Spiked faulds.
		for k in 3:
			var yc := centre - up * (25.0 + k * 7.0)
			_prim(acc, "bonedark", _cyl(12.5 + k * 2.0, 14.5 + k * 2.0, 7.0),
					_xf(yc, Vector3(1.15, 1.0, 0.8)))
			for s in 4:
				var a := s * PI * 0.5 + k * 0.5
				var at := yc + lat * cos(a) * 14.0 + fwd * sin(a) * 11.0 - up * 3.0
				_prim(acc, "bonedark", _cone(1.0, 4.5),
						Transform3D(_y_to((up * 0.4 + (at - yc).normalized() * 0.9).normalized()), at))
	_attach(sk, _bone(sk, "bramble", "chest"), "PlateChest", _bake(acc))


## Pauldrons: jagged bone spaulders, charred at T2, wreathed in soulfire
## spikes at T3 (replaces the old _exclusive bone spikes).
static func _bramble_pauldrons(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var lat: Vector3 = F["lat"]
	var fwd: Vector3 = F["fwd"]
	var plate: String = ["bone", "bone", "bonedark", "bonedark"][tier]
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var sh: Vector3 = P["shoulder." + side]
		var acc := {}
		var c := sh + up * 3.0 + lat * s * 1.5
		if tier == 1:
			_prim(acc, plate, _sphere(5.8), _xf(c, Vector3(1.2, 0.75, 1.2)))
			for k in 3:
				var at := c + up * 4.5 + lat * s * (k - 1) * 4.0
				_prim(acc, plate, _cone(1.2, 5.0), Transform3D(_y_to((up * 0.85 + lat * s * 0.3).normalized()), at))
		elif tier == 2:
			_prim(acc, plate, _sphere(6.5), _xf(c, Vector3(1.2, 0.8, 1.2)))
			_prim(acc, plate, _sphere(6.8), _xf(c + lat * s * 4.0 - up * 4.5, Vector3(1.15, 0.7, 1.15)))
			for k in 4:
				var at := c + up * 5.5 + lat * s * (k - 1.5) * 3.5
				_prim(acc, plate, _cone(1.3, 6.0), Transform3D(_y_to((up * 0.8 + lat * s * 0.35).normalized()), at))
		else:
			_prim(acc, "bonedark", _sphere(7.2), _xf(c, Vector3(1.25, 0.85, 1.25)))
			_prim(acc, "bonedark", _sphere(7.5), _xf(c + lat * s * 5.0 - up * 5.0, Vector3(1.2, 0.7, 1.2)))
			for k in 5:
				var at := c + up * (6.5 - (k % 2) * 2.0) + lat * s * (k - 2) * 3.2 - fwd * 1.5
				_prim(acc, "soulfire", _cone(1.1, 7.0), Transform3D(_y_to((up * 0.85 + lat * s * 0.3).normalized()), at))
		_attach(sk, _bone(sk, "bramble", "shoulder." + side),
				"PlatePauldron" + side.to_upper(), _bake(acc))


## Gloves: ossuary grips — bone claws (T1), charred talons (T2), soulfire
## talons (T3).
static func _bramble_gloves(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var plate: String = ["bone", "bone", "bonedark", "bonedark"][tier]
	var glow: String = "soulfire" if tier == 3 else plate
	for side in ["l", "r"]:
		var wrist: Vector3 = P["wrist." + side]
		var elbow: Vector3 = P["elbow." + side]
		var acc := {}
		var dir := (wrist - elbow).normalized()
		var basis := _y_to(dir)
		_prim(acc, plate, _cyl(4.2, 5.8, 11.0), Transform3D(basis, wrist - dir * 4.0))
		# Knuckle ridge.
		_prim(acc, plate, _box(Vector3(7.5, 2.4, 3.2)),
				Transform3D(Basis.from_euler(Vector3(0.3, 0, 0)), wrist + fwd * 6.0 - up * 1.5))
		# Talons lengthen and ignite by tier.
		var talon_len: float = [0.0, 4.0, 6.0, 8.0][tier]
		for k in 4:
			var at := wrist + fwd * 8.0 - up * (1.0 + k * 0.4) + Vector3(k - 1.5, 0, 0) * 2.0
			var d: Vector3 = (fwd * 0.9 - up * 0.45).normalized()
			_prim(acc, glow if tier == 3 and k % 2 == 0 else plate, _cone(0.9, talon_len),
					Transform3D(_y_to(d), at + d * talon_len * 0.4))
		_attach(sk, _bone(sk, "bramble", "wrist." + side),
				"PlateGlove" + side.to_upper(), _bake(acc))


## Boots: grave greaves — bone (T1), charred with knee fangs (T2), black
## with soulfire seams (T3).
static func _bramble_boots(sk: Skeleton3D, tier: int, F: Dictionary) -> void:
	var P: Dictionary = F["P"]
	var up: Vector3 = F["up"]
	var fwd: Vector3 = F["fwd"]
	var plate: String = ["bone", "bone", "bonedark", "bonedark"][tier]
	for side in ["l", "r"]:
		var knee: Vector3 = P["knee." + side]
		var ankle: Vector3 = P["ankle." + side]
		var foot: Vector3 = P["foot." + side]
		var toes: Vector3 = P["toes." + side]
		var acc := {}
		var shin := ankle - knee
		var shin_len := shin.length()
		var sbasis := _y_to(shin.normalized())
		var smid := (knee + ankle) * 0.5
		var fwd_f := (toes - foot).normalized()
		var fmid := (foot + toes) * 0.5
		var frot := Basis.from_euler(Vector3(0, atan2(fwd_f.x, fwd_f.z), 0))
		_prim(acc, plate, _cyl(5.5, 4.6, shin_len * 0.88), Transform3D(sbasis, smid))
		# Knee fangs.
		for k in (1 if tier == 1 else 3):
			var a := (k - 1) * 0.6
			var at := knee + up * 1.5 + fwd * cos(a) * 4.5 + Vector3(sin(a) * 4.5, 0, 0)
			_prim(acc, "soulfire" if tier == 3 else plate, _cone(0.9, 3.5 + k),
					Transform3D(_y_to((up * 0.5 + fwd * 0.85).normalized()), at))
		# Skeletal sabaton: toe claws.
		_prim(acc, plate, _box(Vector3(6.5, 4.2, 14.0)), Transform3D(frot, fmid + up * 1.0))
		for k in 3:
			var at := toes + Vector3(k - 1, 0, 0) * 2.2 + up * 1.0
			_prim(acc, "soulfire" if tier == 3 else plate, _cone(0.8, 4.0),
					Transform3D(_y_to(fwd_f), at + fwd_f * 2.0))
		if tier == 3:
			_prim(acc, "soulfire", _box(Vector3(0.8, 0.8, shin_len * 0.7)),
					Transform3D(sbasis, smid + fwd * 4.8))
		_attach(sk, _bone(sk, "bramble", "ankle." + side),
				"PlateBoot" + side.to_upper(), _bake(acc))


# --- bramble offhand: the parrying dirk --------------------------------------
## Built in socket space (grip at the origin, blade +Y) like the baked gear
## props; Gear3D._mount mounts it via the "plate:" source prefix.
static func prop_mesh(name: String) -> ArrayMesh:
	if _cache.has(name):
		return _cache[name]
	var acc := {}
	match name:
		"dirk_1":
			_dirk(acc, 1)
		"dirk_2":
			_dirk(acc, 2)
		"dirk_3":
			_dirk(acc, 3)
	var m := _bake(acc)
	_cache[name] = m
	return m


static func _dirk(acc: Dictionary, tier: int) -> void:
	var blade_mat: String = ["bone", "bone", "bonedark", "bonedark"][tier]
	# Blade: a flattened, slightly tapering spike, 30 cm.
	_prim(acc, blade_mat, _box(Vector3(3.0, 26.0, 1.1)), _xf(Vector3(0, 17.0, 0)))
	_prim(acc, blade_mat, _cone(1.5, 6.0, 4), Transform3D(_y_to(Vector3.UP), Vector3(0, 33.0, 0)))
	# Soulfire fuller on the rune dirk.
	if tier == 3:
		_prim(acc, "soulfire", _box(Vector3(0.7, 22.0, 0.4)), _xf(Vector3(0, 16.0, 0.65)))
	# Guard, grip, pommel.
	_prim(acc, blade_mat, _box(Vector3(9.0, 1.8, 2.6)), _xf(Vector3(0, 3.6, 0)))
	_prim(acc, "leather", _cyl(1.4, 1.4, 7.5), _xf(Vector3(0, -0.5, 0)))
	_prim(acc, "soulfire" if tier == 3 else blade_mat, _sphere(1.9), _xf(Vector3(0, -5.0, 0)))
