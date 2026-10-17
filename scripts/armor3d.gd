class_name Armor3D
extends RefCounted

## Worn armour for the dark-fantasy animal heroes, built from primitives and
## baked into ONE skinned mesh (one surface per material) bound rigidly to
## the rig's bones, so it rides every clip for a handful of draws.
## Pieces are authored in skeleton space at the rest pose (Y up, nose +Z,
## the rig's own units: AnimalMesh3D rigs are in centimetres), then
## re-expressed in each bone's frame.

static var _mats := {}
static var _build := {}
static var _binds := {}


static func dress(model: Node, kind: String) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var sk := found[0] as Skeleton3D
	_build = {}
	_binds = {}
	match kind:
		"fox_ranger":
			_fox_ranger(sk)
	_finish(sk)


## Bake everything _pin collected into a skinned mesh under the skeleton.
static func _finish(sk: Skeleton3D) -> void:
	if _build.is_empty():
		return
	var skin := Skin.new()
	var order: Array = _binds.keys()
	order.sort_custom(func(a, b): return _binds[a] < _binds[b])
	for b in order:
		skin.add_bind(b, sk.get_bone_global_rest(b).affine_inverse())
	var mesh := ArrayMesh.new()
	var mats: Array = []
	for kind in _build:
		var acc: Dictionary = _build[kind]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = acc["v"]
		arr[Mesh.ARRAY_NORMAL] = acc["n"]
		arr[Mesh.ARRAY_TEX_UV] = acc["uv"]
		arr[Mesh.ARRAY_BONES] = acc["b"]
		arr[Mesh.ARRAY_WEIGHTS] = acc["w"]
		arr[Mesh.ARRAY_INDEX] = acc["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mats.append(_mat(kind))
	var mi := MeshInstance3D.new()
	mi.name = "Armor"
	mi.mesh = mesh
	for i in mats.size():
		mi.set_surface_override_material(i, mats[i])
	mi.skin = skin
	sk.add_child(mi)
	mi.skeleton = mi.get_path_to(sk)
	_build = {}


static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"iron", "bronze", "leather":
			# Scanned CC0 PBR sets (ambientCG): worn steel, tarnished bronze,
			# creased leather. Mapped by the primitives' own UVs so nothing
			# swims while the rig moves.
			var tex: String = {"iron": "armor_steel", "bronze": "armor_bronze", "leather": "armor_leather"}[kind]
			m.albedo_texture = load("res://assets/textures/%s_col.jpg" % tex)
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/%s_nrm.jpg" % tex)
			if kind == "leather":
				m.roughness_texture = load("res://assets/textures/%s_rgh.jpg" % tex)
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.uv1_scale = Vector3(3.0, 2.0, 1.0)
			match kind:
				"iron":
					# Blackened, oil-dark steel; edges catch a little light.
					m.albedo_color = Color(0.3, 0.29, 0.28)
					m.metallic = 0.45
					m.roughness = 0.74
					m.normal_scale = 1.6
				"bronze":
					m.albedo_color = Color(0.58, 0.54, 0.42)
					m.metallic = 0.5
					m.roughness = 0.68
					m.normal_scale = 1.2
				"leather":
					m.albedo_color = Color(0.55, 0.42, 0.36)
					m.metallic_specular = 0.25
					m.roughness = 1.0
					m.normal_scale = 1.4
		"cloth":
			m.albedo_color = Color(0.16, 0.14, 0.13)
			m.roughness = 0.95
		"fletch":
			m.albedo_color = Color(0.45, 0.08, 0.05)
			m.roughness = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[kind] = m
	return m


## Add `mesh` rigidly bound to `bone`, placed at `xf` in skeleton space
## (rest pose).
static func _pin(sk: Skeleton3D, bone: String, mesh: Mesh, mat: String, xf: Transform3D) -> void:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return
	if not _binds.has(idx):
		_binds[idx] = _binds.size()
	var bind: int = _binds[idx]
	if not _build.has(mat):
		_build[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
				"b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
	var acc: Dictionary = _build[mat]
	var src := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var uvs = src[Mesh.ARRAY_TEX_UV]
	var nb := xf.basis.inverse().transposed()
	var base: int = (acc["v"] as PackedVector3Array).size()
	for k in verts.size():
		acc["v"].append(xf * verts[k])
		acc["n"].append((nb * norms[k]).normalized())
		acc["uv"].append(uvs[k] if uvs != null else Vector2.ZERO)
		acc["b"].append_array([bind, 0, 0, 0])
		acc["w"].append_array([1.0, 0.0, 0.0, 0.0])
	var idxs = src[Mesh.ARRAY_INDEX]
	if idxs == null:
		for k in verts.size():
			acc["i"].append(base + k)
	else:
		for k in (idxs as PackedInt32Array):
			acc["i"].append(base + k)


static func _xf(at: Vector3, scale: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scale), at)


static func _caps(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


static func _cyl(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 20
	t.ring_segments = 8
	return t


## A ranger's barding for the AnimalMesh3D fox (spine y43-44 from pelvis
## z-21 to chest z5, neck z22-25, head y51 z28). Overlapping blackened iron
## lames run down the back like a pangolin's scales, each with a bronze lip,
## over a dark gambeson; a lamellar neck guard, collar pauldrons, a brow helm
## with a nasal spike, and a quiver strapped to the right flank.
static func _fox_ranger(sk: Skeleton3D) -> void:
	# Gambeson: a low quilted pad the plates sit on, mostly sunk in the fur.
	_pin(sk, "RigSpine2_012", _sphere(10.0), "leather", _xf(Vector3(0, 44.5, -5.0), Vector3(1.0, 0.42, 2.0)))
	# Back lames, tail to shoulders: faceted arched steel bands (lorica
	# style), each overlapping the one behind, with a bronze lip on the
	# leading edge. [bone, z, arch centre y, radius]
	var lames := [
		["RigPelvis_02", -21.0, 38.5, 9.0],
		["RigSpine1_011", -14.5, 39.6, 9.6],
		["RigSpine2_012", -8.0, 40.2, 10.0],
		["RigSpine2_012", -1.5, 40.4, 10.0],
		["RigChest_013", 5.0, 40.4, 9.8],
	]
	for l in lames:
		var z: float = l[1]
		var cy: float = l[2]
		var r: float = l[3]
		var band := Transform3D(Basis.from_euler(Vector3(PI * 0.5 - 0.14, 0, 0)), Vector3.ZERO)
		_pin(sk, l[0], _cyl(r, r, 7.2, 12), "iron", Transform3D(Basis.from_scale(Vector3(1.0, 0.92, 1.0)), Vector3(0, cy, z)) * band)
		_pin(sk, l[0], _cyl(r + 0.45, r + 0.45, 1.3, 12), "bronze", Transform3D(Basis.from_scale(Vector3(1.0, 0.92, 1.0)), Vector3(0, cy + 0.5, z + 3.3)) * band)
	# Lamellar neck guard: three narrowing scales up the nape.
	var neck := [["RigNeck1_019", 19.0, 49.0, 6.4], ["RigNeck2_00", 22.5, 51.2, 5.6], ["RigNeck2_00", 25.5, 53.0, 4.8]]
	for l in neck:
		_pin(sk, l[0], _sphere(l[3]), "iron", _xf(Vector3(0, l[2], l[1]), Vector3(1.0, 0.34, 0.7), Vector3(-0.35, 0, 0)))
	# Collar pauldrons ride the shoulder blades, two lames a side.
	for side in [-1.0, 1.0]:
		var bone := "RigLFLegCollarbone_014" if side > 0 else "RigRFLegCollarbone_029"
		_pin(sk, bone, _sphere(5.4), "iron", _xf(Vector3(side * 7.0, 45.5, 14.5), Vector3(0.55, 0.85, 1.0), Vector3(0, 0, side * 0.5)))
		_pin(sk, bone, _sphere(4.6), "bronze", _xf(Vector3(side * 7.8, 42.0, 15.0), Vector3(0.5, 0.7, 0.95), Vector3(0, 0, side * 0.5)))
	# Chamfron: a riveted face plate down the brow and muzzle bridge, with a
	# bronze lip and a short brow spike, the way war-horses were barded.
	var cham := Vector3(0, 57.0, 35.0)
	_pin(sk, "RigHead_020", _sphere(8.4), "bronze", Transform3D(Basis.from_euler(Vector3(0.45, 0, 0)) * Basis.from_scale(Vector3(0.5, 0.22, 1.0)), cham + Vector3(0, -0.5, 0)))
	_pin(sk, "RigHead_020", _sphere(8.0), "iron", Transform3D(Basis.from_euler(Vector3(0.45, 0, 0)) * Basis.from_scale(Vector3(0.44, 0.3, 1.0)), cham))
	_pin(sk, "RigHead_020", _cyl(0.0, 1.2, 5.0, 6), "iron", _xf(Vector3(0, 58.6, 31.5), Vector3.ONE, Vector3(-0.35, 0, 0)))
	# Belly straps: two flat leather girths that hold the barding on.
	for z in [-1.0, 9.0]:
		_pin(sk, "RigChest_013" if z > 4.0 else "RigSpine2_012", _torus(9.6, 10.5), "leather", _xf(Vector3(0, 41.5, z), Vector3(0.78, 0.98, 1.0), Vector3(PI * 0.5, 0, 0)))
	# Rivet rows along each band's arch.
	for l in lames:
		var lz: float = l[1]
		var cy2: float = l[2]
		var lr: float = l[3]
		for k in 5:
			var th := (k - 2) * 0.32
			_pin(sk, l[0], _rivet(), "bronze", _xf(Vector3(sin(th) * (lr + 0.2), cy2 + cos(th) * (lr + 0.2) * 0.92, lz + 1.6)))
	# Quiver: a scanned leather quiver (Finley Searle, CC-BY) slung low on
	# the right flank, nocks pointing back over the haunch.
	_pin_scene(sk, "RigSpine1_011", QUIVER, "quiver",
			Transform3D(Basis.from_euler(Vector3(-1.1, 0, 0.3)) * Basis.from_scale(Vector3.ONE * 10.5), Vector3(-9.6, 44.5, -11.0)))


const QUIVER := "res://assets/models/sketchfab/armor/quiver.glb"


static func _rivet() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.75
	s.height = 1.1
	s.radial_segments = 6
	s.rings = 3
	return s


## Bake every mesh of a scanned prop into the armour (its own material),
## centred on its bounds; loose arrows lying beside the quiver are dropped
## and the quivered ones pushed up so their fletching shows.
static func _pin_scene(sk: Skeleton3D, bone: String, path: String, mat: String, xf: Transform3D) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene := (load(path) as PackedScene).instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var body: AABB
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh.get_aabb().size.x > 0.3:
			body = mi.mesh.get_aabb()
	var centre := body.get_center()
	for m in meshes:
		var mi := m as MeshInstance3D
		var box := mi.mesh.get_aabb()
		if box.end.z < 0.0:
			continue
		if not _mats.has(mat):
			var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
			var dm := src.duplicate() as StandardMaterial3D if src else StandardMaterial3D.new()
			dm.albedo_color = Color(0.72, 0.66, 0.6)
			dm.roughness = 0.95
			dm.metallic = 0.0
			_mats[mat] = dm
		var lift := Vector3(0, 0.55, 0) if box.size.x < 0.1 else Vector3.ZERO
		_pin(sk, bone, mi.mesh, mat, xf * Transform3D(Basis(), lift - centre))
	scene.free()


## Eye size multiplier: big enough to read at the far hunt camera; the
## portrait baker drops it to 1 for close-ups.
static var eye_scale := 1.8


static func glow_eyes(model: Node, color: Color) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var sk := found[0] as Skeleton3D
	var eyes: Array[int] = []
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b).to_lower()
		if "eye" in n and not "end" in n and not "brow" in n:
			eyes.append(b)
	var balls := eyes.filter(func(b: int) -> bool: return not "lid" in sk.get_bone_name(b).to_lower())
	if balls.size() >= 2:
		eyes.assign(balls)
	if eyes.size() < 2:
		return
	# The pair farthest apart is one left and one right.
	var best := [eyes[0], eyes[1]]
	var far := -1.0
	for i in eyes.size():
		for j in range(i + 1, eyes.size()):
			var dd := sk.get_bone_global_rest(eyes[i]).origin.distance_to(sk.get_bone_global_rest(eyes[j]).origin)
			if dd > far:
				far = dd
				best = [eyes[i], eyes[j]]
	eyes.assign([best[0], best[1]])
	var a := sk.get_bone_global_rest(eyes[0]).origin
	var c := sk.get_bone_global_rest(eyes[1]).origin
	var mid := (a + c) * 0.5
	var head := mid
	for b in sk.get_bone_count():
		if "head" in sk.get_bone_name(b).to_lower():
			head = sk.get_bone_global_rest(b).origin
			break
	var fwd := (mid - head).normalized() if mid.distance_to(head) > 0.0001 else Vector3.ZERO
	# Lid-only rigs (the bear) pivot deeper in the socket than eyeball bones.
	var lids := not balls.size() >= 2
	var r := maxf(a.distance_to(c) * (0.2 if lids else 0.11), 0.0001)
	var hb := -1
	for b in sk.get_bone_count():
		if "head" in sk.get_bone_name(b).to_lower():
			hb = b
			break
	if hb < 0:
		hb = sk.get_bone_parent(eyes[0])
	# Both embers go in one mesh on the head bone: one draw per critter.
	r *= eye_scale
	var head_rest := sk.get_bone_global_rest(hb)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ball := _sphere(r)
	ball.radial_segments = 10
	ball.rings = 6
	for b in eyes:
		var at := sk.get_bone_global_rest(b)
		var side := (at.origin - mid).normalized()
		# Eye bones sit at the socket pivot, inside the skull: push the ember
		# forward and a little outward so it shows on the surface.
		var push := fwd * r * 1.2 + side * r * 0.5
		if lids:
			# Lid bones hinge at the brow; the eye sits a little down the lid
			# toward its end bone, proud of the fur.
			var tip := at.origin
			for k in sk.get_bone_count():
				if sk.get_bone_parent(k) == b:
					tip = sk.get_bone_global_rest(k).origin
					break
			push = (tip - at.origin) * 0.36 + side * r * 0.8
		st.append_from(ball, 0, head_rest.affine_inverse() * Transform3D(Basis(), at.origin + push))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.35)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 6.0
	var att := BoneAttachment3D.new()
	att.bone_name = sk.get_bone_name(hb)
	sk.add_child(att)
	var mi := MeshInstance3D.new()
	mi.name = "GlowEye"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)
