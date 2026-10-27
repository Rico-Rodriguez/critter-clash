extends RefCounted
## The toon parts a bred pet wears over its untouched model (art lock: clean,
## crisp shapes; the model's PBR is never tinted): the head, wings and tail it
## borrowed from a parent that isn't its body breed, and a mutation's skin.
## Everything hangs under two nodes, "Parts" and "Mutation", so animation and
## VFX code can find them. Pure builders; sidekick_look.gd calls attach().
## No class_name (OTA packs): preload by path.

const SDB := preload("res://src/data/sidekick_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")

## +1 when the model faces +Z, -1 for -Z (flips every part front to back).
const FRONT := 1.0
const BONE := Color(0.95, 0.9, 0.78)
const DARK := Color(0.12, 0.1, 0.16)


## Adds the parts and the mutation skin for a bred pet's def. Anchors come from
## GEN.FRAMES of the body species; `grow` is the stage scale the model wears.
static func attach(root: Node3D, _model: Node3D, d: Dictionary, grow := 1.0) -> void:
	var g: Dictionary = d.get("genes", {})
	var body := SDB.body_of(str(d.get("breed", "")))
	var fr: Dictionary = GEN.FRAMES.get(body, GEN.FRAMES["acolyte"])
	var ref := float(SDB.ROSTER[body]["scale"]) if SDB.ROSTER.has(body) else 1.0
	var k := float(d.get("scale", ref)) * grow / ref
	var u := float(fr["u"])
	var parts: Dictionary = g.get("parts", {})
	var node := Node3D.new()
	node.name = "Parts"
	node.scale = Vector3.ONE * k
	for slot: String in GEN.PART_SLOTS:
		var donor := str(parts.get(slot, body))
		if donor == body or not GEN.PART_STYLES.has(donor):
			continue
		var col: Color = SDB.ROSTER[donor]["color"] if SDB.ROSTER.has(donor) else Color(0.8, 0.8, 0.8)
		var style := str(GEN.PART_STYLES[donor][slot])
		var s := Node3D.new()
		s.name = slot.capitalize()
		s.set_meta("style", style)
		var a: Array = fr[slot]
		match slot:
			"head":
				var hs := float(fr.get("hs", 0.8))
				s.position = Vector3(0, float(a[0]) - 0.1 * hs, float(a[1]))
				s.scale = Vector3.ONE * hs
				_head(s, style, col, u)
			"wings":
				s.position = Vector3(maxf(float(a[1]) - 0.2, 0.0), float(a[0]), 0)
				_wings(s, style, col, u)
			"tail":
				s.position = Vector3(0, float(a[0]), float(a[1]))
				_tail(s, style, col, u)
		node.add_child(s)
	if node.get_child_count() > 0:
		root.add_child(node)
	else:
		node.free()
	var mu := str(g.get("mutation", ""))
	if GEN.MUTATIONS.has(mu):
		var m := Node3D.new()
		m.name = "Mutation"
		m.set_meta("skin", mu)
		m.scale = Vector3.ONE * k
		m.position = Vector3(0, float(fr["crown"]) * k - 0.8 * k, float((fr["head"] as Array)[1]) * k * 0.5)
		_skin(m, mu, Color.html(str(GEN.MUTATIONS[mu]["color"])), 1.0)
		root.add_child(m)


## One toon primitive. kind: "box", "prism" or "ball"; size in the part's unit
## (metres); rot in degrees; mirror adds the left twin.
static func _prim(parent: Node3D, kind: String, size: Vector3, pos: Vector3, rot: Vector3, col: Color, mirror := false) -> void:
	for sgn in ([-1.0, 1.0] if mirror else [1.0]):
		var mi := MeshInstance3D.new()
		match kind:
			"box":
				var m := BoxMesh.new()
				m.size = size
				mi.mesh = m
			"prism":
				var m := PrismMesh.new()
				m.size = size
				mi.mesh = m
			_:
				var m := SphereMesh.new()
				m.radius = size.x * 0.5
				m.height = size.x
				mi.mesh = m
		mi.position = Vector3(pos.x * sgn, pos.y, pos.z * FRONT)
		mi.rotation_degrees = Vector3(rot.x * FRONT, rot.y * sgn * FRONT, rot.z * sgn)
		Fx.toon(mi, col)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


static func _head(n: Node3D, style: String, col: Color, u: float) -> void:
	var c := col.lightened(0.15)
	match style:
		"horns":
			_prim(n, "prism", Vector3(0.07, 0.24, 0.07) * u, Vector3(0.1, 0.08, 0) * u, Vector3(0, 0, -24), BONE, true)
		"tuft":
			for i in 3:
				_prim(n, "prism", Vector3(0.08, 0.2 + 0.06 * int(i == 1), 0.08) * u, Vector3((i - 1) * 0.07, 0.06, 0) * u, Vector3(0, 0, (i - 1) * -14), c)
		"skull":
			_prim(n, "ball", Vector3(0.26, 0.26, 0.26) * u, Vector3(0, 0.1, 0) * u, Vector3.ZERO, BONE)
			_prim(n, "ball", Vector3(0.06, 0.06, 0.06) * u, Vector3(0.05, 0.13, 0.11) * u, Vector3.ZERO, DARK, true)
		"hood":
			_prim(n, "prism", Vector3(0.28, 0.34, 0.28) * u, Vector3(0, 0.14, 0) * u, Vector3.ZERO, c.darkened(0.15))
		"leaves":
			for i in 3:
				_prim(n, "prism", Vector3(0.1, 0.22, 0.03) * u, Vector3((i - 1) * 0.1, 0.08, 0) * u, Vector3(0, 0, (i - 1) * -32), Color(0.45, 0.82, 0.3))
		"beak":
			_prim(n, "prism", Vector3(0.12, 0.26, 0.12) * u, Vector3(0, 0.06, 0.16) * u, Vector3(90, 0, 0), Color(1.0, 0.8, 0.3))
		"crown":
			for i in 5:
				var a := TAU * i / 5.0
				_prim(n, "prism", Vector3(0.06, 0.14, 0.06) * u, Vector3(cos(a) * 0.1, 0.1, sin(a) * 0.1) * u, Vector3.ZERO, Color(1.0, 0.82, 0.3))
		"ears":
			_prim(n, "prism", Vector3(0.09, 0.26, 0.04) * u, Vector3(0.09, 0.1, 0) * u, Vector3(0, 0, -10), c.darkened(0.25), true)
		"helm":
			_prim(n, "ball", Vector3(0.3, 0.3, 0.3) * u, Vector3(0, 0.08, 0) * u, Vector3.ZERO, Color(0.75, 0.78, 0.85))
			_prim(n, "prism", Vector3(0.05, 0.2, 0.22) * u, Vector3(0, 0.26, -0.02) * u, Vector3.ZERO, col)


static func _wings(n: Node3D, style: String, col: Color, u: float) -> void:
	var c := col.lightened(0.1)
	match style:
		"dragon":
			_prim(n, "prism", Vector3(0.46, 0.5, 0.05) * u, Vector3(0.24, 0.2, -0.05) * u, Vector3(0, 8, -68), c.darkened(0.4), true)
			_prim(n, "box", Vector3(0.04, 0.5, 0.04) * u, Vector3(0.2, 0.2, 0.0) * u, Vector3(0, 0, -64), BONE, true)
		"bat":
			_prim(n, "prism", Vector3(0.4, 0.44, 0.04) * u, Vector3(0.22, 0.18, -0.04) * u, Vector3(0, 8, -66), c.darkened(0.55), true)
			_prim(n, "box", Vector3(0.035, 0.44, 0.035) * u, Vector3(0.19, 0.18, 0.0) * u, Vector3(0, 0, -64), DARK, true)
		"feather":
			for i in 3:
				_prim(n, "prism", Vector3(0.12, 0.34 - 0.06 * i, 0.04) * u, Vector3(0.14 + 0.1 * i, 0.16 - 0.05 * i, -0.03 * i) * u, Vector3(0, 0, -62 - 10 * i), c, true)
		"wisp":
			_prim(n, "prism", Vector3(0.16, 0.4, 0.05) * u, Vector3(0.2, 0.14, 0) * u, Vector3(0, 0, -52), c, true)
			_prim(n, "prism", Vector3(0.1, 0.26, 0.05) * u, Vector3(0.24, 0.0, 0) * u, Vector3(0, 0, -86), c.lightened(0.2), true)
		"ribs":
			for i in 3:
				_prim(n, "box", Vector3(0.04, 0.36 - 0.06 * i, 0.04) * u, Vector3(0.14 + 0.07 * i, 0.14 - 0.04 * i, -0.02 * i) * u, Vector3(0, 0, -56 - 12 * i), BONE, true)
		"cape":
			_prim(n, "box", Vector3(0.34, 0.5, 0.03) * u, Vector3(0, -0.04, -0.14) * u, Vector3(8, 0, 0), c.darkened(0.3))
		"lid":
			_prim(n, "box", Vector3(0.3, 0.04, 0.22) * u, Vector3(0, 0.1, -0.16) * u, Vector3(-48, 0, 0), Color(1.0, 0.8, 0.3))
		"banner":
			_prim(n, "box", Vector3(0.22, 0.46, 0.03) * u, Vector3(0, 0.0, -0.15) * u, Vector3(6, 0, 0), col)
			_prim(n, "prism", Vector3(0.22, 0.1, 0.03) * u, Vector3(0, -0.28, -0.15) * u, Vector3(0, 0, 180), col)
		"leaf":
			_prim(n, "prism", Vector3(0.18, 0.4, 0.03) * u, Vector3(0.2, 0.14, 0) * u, Vector3(0, 0, -62), Color(0.45, 0.82, 0.3), true)


static func _tail(n: Node3D, style: String, col: Color, u: float) -> void:
	var c := col.lightened(0.1)
	match style:
		"spike":
			for i in 3:
				_prim(n, "prism", Vector3(0.1 - 0.025 * i, 0.2 - 0.04 * i, 0.1 - 0.025 * i) * u, Vector3(0, 0.02 + 0.02 * i, -0.1 - 0.13 * i) * u, Vector3(-80, 0, 0), c)
		"flame":
			for i in 2:
				_prim(n, "prism", Vector3(0.1, 0.26 - 0.08 * i, 0.06) * u, Vector3(0, 0.08 + 0.08 * i, -0.16 - 0.08 * i) * u, Vector3(-20, 0, 0), Color(1.0, 0.62, 0.25) if i == 0 else Color(1.0, 0.85, 0.4))
		"bone":
			for i in 3:
				_prim(n, "ball", Vector3(0.08, 0.08, 0.08) * u * (1.0 - 0.15 * i), Vector3(0, 0.0, -0.1 - 0.1 * i) * u, Vector3.ZERO, BONE)
		"plume":
			for i in 3:
				_prim(n, "prism", Vector3(0.08, 0.28, 0.04) * u, Vector3((i - 1) * 0.06, 0.1, -0.16) * u, Vector3(-30, 0, (i - 1) * -22), c.darkened(0.15))
		"vine":
			for i in 3:
				_prim(n, "ball", Vector3(0.09, 0.09, 0.09) * u * (1.0 - 0.18 * i), Vector3(0, 0.04 * i, -0.1 - 0.09 * i) * u, Vector3.ZERO, Color(0.4, 0.78, 0.3))
			_prim(n, "prism", Vector3(0.1, 0.14, 0.03) * u, Vector3(0, 0.14, -0.34) * u, Vector3(-30, 0, 0), Color(0.5, 0.9, 0.35))
		"fan":
			for i in 3:
				_prim(n, "box", Vector3(0.05, 0.03, 0.3) * u, Vector3((i - 1) * 0.07, 0.06, -0.2) * u, Vector3(0, (i - 1) * 18, 0), c)
		"chain":
			for i in 3:
				_prim(n, "box", Vector3(0.06, 0.06, 0.09) * u, Vector3(0, 0.0, -0.1 - 0.09 * i) * u, Vector3(0, 0, 45 * i), Color(1.0, 0.82, 0.3))
		"whip":
			_prim(n, "box", Vector3(0.03, 0.03, 0.3) * u, Vector3(0, 0.04, -0.2) * u, Vector3(-18, 0, 0), c.darkened(0.2))
			_prim(n, "prism", Vector3(0.07, 0.1, 0.03) * u, Vector3(0, 0.1, -0.38) * u, Vector3(-70, 0, 0), c)
		"mace":
			_prim(n, "box", Vector3(0.04, 0.04, 0.26) * u, Vector3(0, 0.02, -0.18) * u, Vector3.ZERO, Color(0.55, 0.5, 0.45))
			_prim(n, "ball", Vector3(0.16, 0.16, 0.16) * u, Vector3(0, 0.02, -0.36) * u, Vector3.ZERO, Color(0.7, 0.72, 0.8))


## A mutation's skin: crisp toon shapes in its colour. Positions are the
## model's own space (u = height).
static func _skin(n: Node3D, id: String, col: Color, u: float) -> void:
	match id:
		"gilded":
			for i in 8:
				var an := TAU * i / 8.0
				_prim(n, "ball", Vector3(0.07, 0.07, 0.07) * u, Vector3(cos(an) * 0.17, 0.9, sin(an) * 0.17) * u, Vector3.ZERO, col)
			_prim(n, "ball", Vector3(0.13, 0.13, 0.13) * u, Vector3(0.24, 0.6, 0) * u, Vector3.ZERO, col, true)
		"frostborn":
			for i in 5:
				_prim(n, "prism", Vector3(0.08, 0.3 - 0.03 * (i % 3), 0.08) * u, Vector3((i - 2) * 0.07, 0.78 - 0.07 * (i % 2), -0.12) * u, Vector3(-20, 0, (i - 2) * -14), col.lightened(0.2))
		"stormtouched":
			_prim(n, "prism", Vector3(0.06, 0.3, 0.06) * u, Vector3(0.12, 0.92, 0) * u, Vector3(0, 0, -28), Color(0.95, 0.97, 1.0), true)
			_prim(n, "prism", Vector3(0.05, 0.18, 0.05) * u, Vector3(0.2, 1.0, 0) * u, Vector3(0, 0, 20), col, true)
		"voidborn":
			for i in 3:
				var a := TAU * i / 3.0
				_prim(n, "ball", Vector3(0.13, 0.13, 0.13) * u, Vector3(cos(a) * 0.42, 0.6 + 0.12 * i, sin(a) * 0.42) * u, Vector3.ZERO, col)
		"emberheart":
			_prim(n, "prism", Vector3(0.16, 0.26, 0.1) * u, Vector3(0, 0.5, 0.2) * u, Vector3.ZERO, Color(1.0, 0.62, 0.2))
			_prim(n, "prism", Vector3(0.06, 0.14, 0.05) * u, Vector3(0.12, 0.56, 0.16) * u, Vector3(0, 0, -20), col, true)
		"verdant":
			for i in 4:
				_prim(n, "prism", Vector3(0.1, 0.22, 0.03) * u, Vector3((i - 1.5) * 0.09, 0.8, -0.12) * u, Vector3(-18, 0, (i - 1.5) * -22), col)
			_prim(n, "ball", Vector3(0.1, 0.1, 0.1) * u, Vector3(0, 0.98, -0.1) * u, Vector3.ZERO, Color(1.0, 0.6, 0.8))
