class_name Armor3D
extends RefCounted

## Worn armour for the dark-fantasy animal heroes, built from primitives and
## pinned to the rig with BoneAttachment3D so it rides every clip.
## Pieces are authored in skeleton space at the rest pose (Y up, nose +Z,
## the rig's own units: AnimalMesh3D rigs are in centimetres), then
## re-expressed in each bone's frame.

static var _mats := {}


static func dress(model: Node, kind: String) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var sk := found[0] as Skeleton3D
	match kind:
		"fox_ranger":
			_fox_ranger(sk)


static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"iron":
			# Blackened, dented iron: dark albedo, metal, a hammered normal.
			m.albedo_color = Color(0.17, 0.165, 0.16)
			m.metallic = 0.15
			m.metallic_specular = 0.25
			m.roughness = 0.9
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/metal_normal.jpg")
			m.normal_scale = 1.4
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.08, 0.08, 0.08)
		"bronze":
			m.albedo_color = Color(0.5, 0.34, 0.16)
			m.metallic = 0.5
			m.roughness = 0.6
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/metal_normal.jpg")
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.1, 0.1, 0.1)
		"leather":
			# Worn oxblood leather.
			m.albedo_color = Color(0.26, 0.15, 0.09)
			m.roughness = 1.0
			m.metallic_specular = 0.12
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/rock_normal.jpg")
			m.normal_scale = 0.5
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.12, 0.12, 0.12)
		"cloth":
			m.albedo_color = Color(0.16, 0.14, 0.13)
			m.roughness = 0.95
		"fletch":
			m.albedo_color = Color(0.45, 0.08, 0.05)
			m.roughness = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[kind] = m
	return m


## Pin `mesh` to `bone`, placed at `xf` in skeleton space (rest pose).
static func _pin(sk: Skeleton3D, bone: String, mesh: Mesh, mat: String, xf: Transform3D) -> void:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	sk.add_child(att)
	var mi := MeshInstance3D.new()
	mi.name = "Armor"
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	mi.transform = sk.get_bone_global_rest(idx).affine_inverse() * xf
	att.add_child(mi)


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
	# Back lames, tail to shoulders; each overlaps the one behind it.
	var lames := [
		["RigPelvis_02", -22.0, 46.0, 7.6],
		["RigSpine1_011", -14.5, 47.4, 8.4],
		["RigSpine2_012", -6.5, 48.2, 8.8],
		["RigSpine2_012", 1.0, 48.4, 8.8],
		["RigChest_013", 8.0, 48.6, 8.4],
	]
	for l in lames:
		var z: float = l[1]
		var y: float = l[2]
		var r: float = l[3]
		_pin(sk, l[0], _sphere(r), "bronze", _xf(Vector3(0, y - 0.8, z - 1.0), Vector3(1.26, 0.27, 0.64)))
		_pin(sk, l[0], _sphere(r), "iron", _xf(Vector3(0, y, z), Vector3(1.22, 0.29, 0.62), Vector3(-0.12, 0, 0)))
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
	# Quiver low on the right flank, slung tail-ward, three arrows.
	var q_at := Vector3(-8.8, 45.0, -12.0)
	var q_rot := Vector3(-1.05, 0, 0.25)
	_pin(sk, "RigSpine1_011", _cyl(2.6, 2.2, 18.0, 10), "leather", _xf(q_at, Vector3.ONE, q_rot))
	_pin(sk, "RigSpine1_011", _cyl(2.9, 2.9, 1.4, 10), "bronze", _xf(q_at + Basis.from_euler(q_rot) * Vector3(0, 8.0, 0), Vector3.ONE, q_rot))
	for k in 3:
		var o := Basis.from_euler(q_rot) * Vector3((k - 1) * 1.1, 11.5, (k % 2) * 0.8)
		_pin(sk, "RigSpine1_011", _cyl(0.3, 0.3, 7.0, 4), "cloth", _xf(q_at + o, Vector3.ONE, q_rot))
		_pin(sk, "RigSpine1_011", _cyl(0.0, 1.0, 2.4, 3), "fletch", _xf(q_at + o + Basis.from_euler(q_rot) * Vector3(0, 3.6, 0), Vector3.ONE, q_rot))


## Feral enemies: a burning ember in each eye socket, sized from the gap
## between the rig's two eye(lid) bones so it fits any unit scale.
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
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.albedo_color = color.lightened(0.35)
	m.emission_energy_multiplier = 6.0
	for b in eyes:
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(b)
		sk.add_child(att)
		var mi := MeshInstance3D.new()
		mi.name = "GlowEye"
		mi.mesh = _sphere(r)
		mi.material_override = m
		# Eye bones sit at the socket pivot, inside the skull: push the ember
		# forward and a little outward so it shows on the surface.
		var at := sk.get_bone_global_rest(b)
		var side := (at.origin - mid).normalized()
		var push := fwd * r * 1.6 + side * r * 0.6
		if lids:
			# Lid bones hinge at the brow; the eye sits a little down the lid
			# toward its end bone, proud of the fur.
			var tip := at.origin
			for k in sk.get_bone_count():
				if sk.get_bone_parent(k) == b:
					tip = sk.get_bone_global_rest(k).origin
					break
			push = (tip - at.origin) * 0.36 + side * r * 1.0
		mi.position = at.basis.inverse() * push
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(mi)
