class_name Fx
extends Node3D
## Pooled visual effects for the hunt. Everything here is cosmetic: gameplay
## never waits on an effect. Every effect is built from the Supercell-style
## blocks in `vfx` (src/vfx/vfx_lib.gd): toon puffs, hit stars, sparks,
## debris, crescents, cartoon bolts, scorch marks, all batched (one draw per
## layer). The helpers below are thin, named wrappers over those blocks.
## There is no plain decorative ring: a ring only exists as the brief
## shockwave of an impact, or as a telegraph.

const TELE := preload("res://src/fx/telegraph.gdshader")
const BEAM := preload("res://src/vfx/sc_beam.gdshader")
const SOFT := preload("res://src/fx/soft.gdshader")
const TOON1 := preload("res://src/vfx/sc_toon_single.gdshader")
const VfxLib := preload("res://src/vfx/vfx_lib.gd")


var _live: Array = []
var _pools := {}
var _arc_meshes := {}
var _tele_mats := {}
var _beam_mat: ShaderMaterial
var _quad: PlaneMesh
## The element effect library (src/vfx/vfx_lib.gd). Sidekicks, skills and
## enemies call it directly: fx.vfx.impact(&"frost", pos, 2.0).
var vfx: Node3D
var _numbers: Array[Label3D] = []
var _num_i := 0
var title_font: FontVariation
var quality_low := false
var _merge := {}
var _serial := 0


func _init() -> void:
	name = "Fx"


func _ready() -> void:
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM
	vfx = VfxLib.new()
	vfx.quality_low = quality_low
	add_child(vfx)
	_quad = PlaneMesh.new()
	_quad.size = Vector2(2, 2)
	title_font = FontVariation.new()
	title_font.base_font = load("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")
	for i in 36:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.0082
		l.font = title_font
		l.font_size = 64
		l.outline_size = 18
		l.outline_modulate = Color(0.05, 0.02, 0.02, 0.95)
		l.render_priority = 10
		l.outline_render_priority = 9
		l.visible = false
		add_child(l)
		_numbers.append(l)


static var _toon1: ShaderMaterial


## Give a mesh the toon 3-band look (projectile heads, wisps, blades, rocks,
## souls). `body` is the main colour; core and rim are derived from it.
static func toon(gi: GeometryInstance3D, body: Color, wobble := 0.0) -> void:
	if _toon1 == null:
		_toon1 = ShaderMaterial.new()
		_toon1.shader = TOON1
	gi.material_override = _toon1
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rim := Color.from_hsv(fposmod(body.h - (0.03 if body.h < 0.2 or body.h > 0.9 else -0.02), 1.0), minf(body.s + 0.15, 0.9), clampf(body.v * 0.55, 0.18, 0.8))
	gi.set_instance_shader_parameter("body", Color(body.r, body.g, body.b, 1.0))
	gi.set_instance_shader_parameter("core", Color(body.r, body.g, body.b).lerp(Color(1.0, 0.98, 0.86), 0.72))
	gi.set_instance_shader_parameter("rim", rim)
	gi.set_instance_shader_parameter("wobble", wobble)


## A shield bubble (warded champions): a hard-edged toon rim, see-through in
## the middle, no additive glow.
static func make_ward(radius: float) -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled;\nvoid fragment(){ float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0); if (f < 0.55) discard; ALBEDO = f > 0.8 ? vec3(0.32, 0.24, 0.7) : vec3(0.62, 0.56, 1.0); ALPHA = 0.85; }"
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	mi.mesh = sph
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _process(delta: float) -> void:
	var i := _live.size() - 1
	while i >= 0:
		var e: Dictionary = _live[i]
		e["t"] += delta
		var k: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			_live.remove_at(i)
			i -= 1
			continue
		match str(e["kind"]):
			"tele":
				(n as GeometryInstance3D).set_instance_shader_parameter("progress", k)
				var fade_in: float = clampf(e["t"] / 0.12, 0.0, 1.0)
				(n as GeometryInstance3D).set_instance_shader_parameter("fade", fade_in)
			"num":
				var l := n as Label3D
				var base: Vector3 = e["from"]
				var pop: float = 1.0 + 0.6 * pow(1.0 - minf(k * 5.0, 1.0), 2.0)
				l.scale = Vector3.ONE * pop * float(e["size"])
				l.position = base + Vector3(e["dx"] * k, 1.1 * (1.0 - pow(1.0 - k, 2.0)), 0)
				l.modulate.a = 1.0 - smoothstep(0.65, 1.0, k)
				l.outline_modulate.a = l.modulate.a * 0.95
			"beam":
				pass
			"trail":
				if n.visible:
					e["acc"] = float(e["acc"]) + delta
					if float(e["acc"]) >= float(e["every"]):
						e["acc"] = 0.0
						var tier: StringName = e["tier"]
						vfx.travel(e["el"], n.global_position, -n.global_transform.basis.z * 10.0, VfxLib.NO_TINT, tier)
			"tornado":
				if is_instance_valid(e["follow"]):
					n.position = (e["follow"] as Actor).flat_pos()
				_whirl(e, n.position, k, delta)
		if k >= 1.0:
			if e["kind"] == "num":
				n.visible = false
			elif e["kind"] != "beam" and e["kind"] != "trail":
				_release(str(e["kind"]), n)
			_live.remove_at(i)
		i -= 1


func _take(kind: String, make: Callable) -> Node3D:
	var pool: Array = _pools.get(kind, [])
	_pools[kind] = pool
	var n: Node3D = pool.pop_back() if not pool.is_empty() else make.call()
	if n.get_parent() == null:
		add_child(n)
	n.visible = true
	return n


func _release(kind: String, n: Node3D) -> void:
	n.visible = false
	var key := kind
	if n.has_meta("pool"):
		key = str(n.get_meta("pool"))
	_pools[key] = _pools.get(key, [])
	_pools[key].append(n)


## A flat arc mesh around +Z, inner/outer radius 0.55/1.0 (scale it).
func _arc(deg: int) -> ArrayMesh:
	if _arc_meshes.has(deg):
		return _arc_meshes[deg]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 24
	var half := deg_to_rad(deg) * 0.5
	for s in seg:
		var a0 := -half + (2.0 * half) * s / seg
		var a1 := -half + (2.0 * half) * (s + 1) / seg
		var u0 := float(s) / seg
		var u1 := float(s + 1) / seg
		var pts := [
			[Vector3(sin(a0), 0, cos(a0)) * 0.45, Vector2(u0, 0)],
			[Vector3(sin(a0), 0, cos(a0)), Vector2(u0, 1)],
			[Vector3(sin(a1), 0, cos(a1)), Vector2(u1, 1)],
			[Vector3(sin(a1), 0, cos(a1)) * 0.45, Vector2(u1, 0)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(pts[idx][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[idx][0])
	var m := st.commit()
	_arc_meshes[deg] = m
	return m


## A sword swing: a solid crescent sweeping `deg` around the facing `yaw`
## (white leading edge into the colour), then a few sparks off its tip.
func slash(pos: Vector3, yaw: float, radius: float, deg: float, color: Color, mirror := false, dur := 0.2) -> void:
	var half := deg_to_rad(clampf(deg, 30.0, 360.0)) * 0.5
	var a0 := yaw - half
	var a1 := yaw + half
	if mirror:
		var t := a0
		a0 = a1
		a1 = t
	vfx.crescent(pos, radius * 0.95, a0, a1, radius * 0.32, Color(color.r, color.g, color.b, 1.0), maxf(dur, 0.14) * 1.2, 0.9)


## A burst of fire: a front of flame tongues racing out over the ground,
## a cluster of flames, sparks and embers, and a scorch decal left behind.
## `wall` false (small, frequent bursts) skips the racing front.
## `tier` light (basic-attack fireballs, frequent procs): a small flicker of
## flame only, no front, no scorch, no light.
func flame_burst(pos: Vector3, radius: float, wall := true, color := Color(1.0, 0.55, 0.18), tier: StringName = &"skill") -> void:
	if tier == &"light":
		vfx.impact(&"fire", pos, radius * 0.6, color, tier)
		return
	if wall and not quality_low:
		vfx.nova(&"fire", pos, radius, clampf(0.3 + radius * 0.05, 0.32, 0.6), color, tier)
	vfx.impact(&"fire", pos, radius * 0.6, color, tier)


## Burnt ground that fades over `dur` seconds.
func scorch(pos: Vector3, radius: float, dur := 2.6) -> void:
	vfx.decal(&"fire", pos, radius, dur)


## The Hellfire Wisp: a churning toon fireball with a white-hot core. No
## light, no additive shell. The caller owns the node.
func make_wisp() -> Node3D:
	var root := Node3D.new()
	var ball := MeshInstance3D.new()
	var ss := SphereMesh.new()
	ss.radius = 0.36
	ss.height = 0.8
	ss.radial_segments = 16
	ss.rings = 8
	ball.mesh = ss
	ball.position.y = 0.1
	toon(ball, Color(1.0, 0.6, 0.14), 0.05)
	root.add_child(ball)
	return root


## Ground warning. shape: 0 circle (size = radius), 1 cone (size = radius,
## cone = half angle), 2 lane (size = Vector2 half width, length). The fill
## completes after `dur`. Returns the node so the caller can cancel it.
## `element` themes the rim (cracked fire edge, frost rime, thorns, stone...):
## leave it empty for the plain red danger edge of enemy attacks.
func telegraph(shape: int, pos: Vector3, yaw: float, size: Vector2, dur: float, cone := 0.6, element: StringName = &"") -> MeshInstance3D:
	var edge: String = VfxLib.EDGES.get(element, "danger")
	var n := _take("tele_" + edge, func():
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		mi.material_override = _tele_mat(edge, element)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "tele_" + edge)
		return mi)
	n.rotation = Vector3(0, yaw, 0)
	if shape == 2:
		# Lane from pos forward along yaw.
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		n.position = pos + fwd * size.y * 0.5 + Vector3(0, 0.04, 0)
		n.scale = Vector3(size.x, 1, size.y * 0.5)
	else:
		n.position = pos + Vector3(0, 0.04, 0)
		n.scale = Vector3(size.x, 1, size.x)
	var gi := n as GeometryInstance3D
	gi.set_instance_shader_parameter("shape", float(shape))
	gi.set_instance_shader_parameter("size", size.y if shape == 2 else size.x)
	gi.set_instance_shader_parameter("cone", cone)
	gi.set_instance_shader_parameter("progress", 0.0)
	gi.set_instance_shader_parameter("fade", 0.0)
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "tele"})
	return n


func _tele_mat(edge: String, element: StringName) -> ShaderMaterial:
	if not _tele_mats.has(edge):
		var m := ShaderMaterial.new()
		m.shader = TELE
		m.render_priority = -1
		m.set_shader_parameter("edge", load(VfxLib.TEX % ("edge_" + edge)))
		if edge != "danger":
			var c: Color = VfxLib.COLORS.get(element, Color(1.0, 0.18, 0.1))
			m.set_shader_parameter("color", c)
		_tele_mats[edge] = m
	return _tele_mats[edge]


func cancel(n: Node3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	for i in _live.size():
		if _live[i]["node"] == n:
			_live.remove_at(i)
			break
	_release("tele_danger", n)


## Loot pillar. Lives until the caller frees it with release_beam.
func beam(pos: Vector3, color: Color, height := 7.0) -> MeshInstance3D:
	var n := _take("beam", func():
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.3
		cyl.height = 1.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		cyl.radial_segments = 10
		mi.mesh = cyl
		mi.material_override = _beam_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "beam")
		return mi)
	n.position = pos + Vector3(0, height * 0.5, 0)
	n.scale = Vector3(1, height, 1)
	(n as GeometryInstance3D).set_instance_shader_parameter("tint", color)
	(n as GeometryInstance3D).set_instance_shader_parameter("strength", 1.0)
	return n


## A whirlwind around `follow` for `dur` seconds (the Barbarian): solid
## crescents sweeping round at varied heights and radii, widening upward,
## with puffs flung off the edge. No cone shader.
func tornado(follow: Actor, color: Color, dur: float) -> void:
	var n := _take("tornado", func():
		var holder := Node3D.new()
		holder.set_meta("pool", "tornado")
		return holder)
	n.position = follow.flat_pos()
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "tornado", "follow": follow, "c": color, "acc": 0.0, "spin": randf() * TAU})


func _whirl(e: Dictionary, at: Vector3, k: float, delta: float) -> void:
	if k >= 0.95:
		return
	e["spin"] = float(e["spin"]) - delta * 9.0
	e["acc"] = float(e["acc"]) + delta
	if float(e["acc"]) < (0.09 if quality_low else 0.05):
		return
	e["acc"] = 0.0
	var c: Color = e["c"]
	var h := randf_range(0.2, 2.6)
	var r := lerpf(0.9, 2.3, h / 2.6) * randf_range(0.9, 1.1)
	var a: float = float(e["spin"]) + randf() * TAU
	vfx.crescent(at, r, a, a - randf_range(1.6, 2.4), randf_range(0.22, 0.4), c, 0.2, h)
	var out := Vector3(sin(a), 0, cos(a))
	vfx.puff_el(VfxLib.element_for(c), at + out * r + Vector3(0, h, 0), randf_range(0.25, 0.4), out * 3.0 + Vector3(0, 1.0, 0), 0.3, c)


func release_beam(n: Node3D) -> void:
	if n and is_instance_valid(n):
		_release("beam", n)


## Damage number. Pass `key` (the target) and rapid hits on it merge into one
## growing number instead of stacking a pile of them.
func number(pos: Vector3, amount: int, color: Color, size := 1.0, key: Object = null) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if key != null:
		var m: Dictionary = _merge.get(key.get_instance_id(), {})
		if not m.is_empty() and now < float(m["until"]):
			var ml: Label3D = m["label"]
			if ml.visible and ml.get_meta("serial", -1) == m["serial"]:
				m["total"] = int(m["total"]) + amount
				m["until"] = now + 0.3
				ml.text = str(m["total"])
				for e in _live:
					if e["node"] == ml:
						e["t"] = minf(float(e["t"]), 0.12)
				return
	var l := _numbers[_num_i]
	_num_i = (_num_i + 1) % _numbers.size()
	for e in _live:
		if e["node"] == l:
			_live.erase(e)
			break
	l.text = str(amount)
	l.modulate = color
	l.visible = true
	var from := pos + Vector3(randf_range(-0.3, 0.3), 1.9, 0)
	l.position = from
	_serial += 1
	l.set_meta("serial", _serial)
	if key != null:
		_merge[key.get_instance_id()] = {"label": l, "total": amount, "until": now + 0.3, "serial": _serial}
	_live.append({"node": l, "t": 0.0, "dur": 0.75, "kind": "num", "from": from, "size": size, "dx": randf_range(-0.5, 0.5)})


func text(pos: Vector3, s: String, color: Color, size := 0.8, dur := 1.1) -> void:
	var l := _numbers[_num_i]
	_num_i = (_num_i + 1) % _numbers.size()
	for e in _live:
		if e["node"] == l:
			_live.erase(e)
			break
	l.text = s
	l.modulate = color
	l.visible = true
	var from := pos + Vector3(0, 2.4, 0)
	l.position = from
	_live.append({"node": l, "t": 0.0, "dur": dur, "kind": "num", "from": from, "size": size, "dx": 0.0})


# --- Small hit pieces ---------------------------------------------------

## A hit pop: a small spiky star and fat sparks thrown out of `pos`.
func burst(pos: Vector3, color: Color, count := 10, speed := 6.0, up := 0.5) -> void:
	var p := pos + Vector3(0, 0.9, 0)
	vfx.star(p, clampf(0.25 + count * 0.025, 0.3, 0.7), color, 0.13, 5.0)
	vfx.sparks(p, clampi(count / 2, 2, 8), speed, color, 0.3, up + 0.2)


## Small toon embers rising from `pos` (wakes, burning, buffs).
func embers_at(pos: Vector3, color: Color, count := 6, radius := 0.6) -> void:
	var el := VfxLib.element_for(color)
	for i in clampi(count / 2, 1, 6):
		var o := Vector3(randf_range(-1, 1), randf_range(0.0, 0.6), randf_range(-1, 1)) * radius
		vfx.puff_el(el, pos + Vector3(0, 0.5, 0) + o, randf_range(0.12, 0.22), Vector3(0, 1.6, 0), randf_range(0.3, 0.45), color, randf() * 0.08)


## Ground dust: chunky toon smoke puffs kicked out along the ground.
func puff(pos: Vector3, color := Color(0.32, 0.27, 0.22, 0.55), count := 6, spread := 0.8, speed := 1.4) -> void:
	var c := Color(minf(color.r * 2.0, 1.0), minf(color.g * 2.0, 1.0), minf(color.b * 2.0, 1.0))
	var rim := Vector2(fposmod(c.h - 0.02, 1.0), clampf(c.v * 0.45, 0.15, 0.5))
	for i in mini(clampi(count / 2, 2, 8), VfxLib.MAX_PER_CALL):
		var dir := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
		vfx.puff(pos + dir * randf() * spread + Vector3(0, 0.25, 0), randf_range(0.28, 0.45) * clampf(spread, 0.6, 1.6), dir * speed * randf_range(0.6, 1.1) + Vector3(0, 0.6, 0), randf_range(0.35, 0.5), c, rim, randf() * 0.05)


## A small star glint (pickups, procs).
func flare(pos: Vector3, color: Color) -> void:
	vfx.star(pos + Vector3(0, 0.9, 0), 0.35, color, 0.14, 4.0)


## Bones: toon bone chunks hopping out and bouncing.
func bone_burst(pos: Vector3, count := 6, force := 5.0) -> void:
	if quality_low:
		count = mini(count, 3)
	vfx.debris(pos + Vector3(0, 0.6, 0), count, force * 0.8, &"shadow")


## Chain lightning: forked, flickering bolts between the points (pooled).
## light tier: unforked and brief (basic chain attacks).
func lightning(points: PackedVector3Array, color := Color(0.6, 0.8, 1.0), tier: StringName = &"skill") -> void:
	if tier == &"light":
		vfx.bolt(points, color, false, 0.05, 0.14)
	else:
		vfx.bolt(points, color, true, 0.07 if tier == &"skill" else 0.09, 0.22 if tier == &"skill" else 0.3)


# --- Sky effects: lightning strikes, meteors, falling arrows ---------------

static var _fall_cache := {}


## A strike from the sky onto `at`: a fat cartoon bolt, flash, shockwave,
## star, sparks, rubble and a crack. Pass the colour (gold holy, blue storm).
func sky_bolt(at: Vector3, color := Color(1.0, 0.9, 0.55), width := 0.2, height := 15.0) -> void:
	# Pooled, re-forking and capped (VfxLib.sky); always big tier.
	vfx.sky(at, color, width, height)


## Something falling onto `to` after `delay`, taking `dur` to arrive: a "meteor"
## or an "arrow". `land` runs on impact.
func fall(kind: String, to: Vector3, delay: float, dur: float, land: Callable) -> void:
	var n := _take("fall_" + kind, func(): return _make_faller(kind))
	var from := to + (Vector3(-9.0, 16.0, -10.0) if kind == "meteor" else Vector3(0.4, 12.0, 0.8))
	n.visible = false
	n.position = from
	n.look_at(to, Vector3.UP)
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func():
		n.visible = true
		_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "trail", "acc": 0.0, "every": 0.025 if kind == "meteor" else 0.06,
			"el": &"fire" if kind == "meteor" else &"physical", "tier": &"skill" if kind == "meteor" else &"light"}))
	tw.tween_property(n, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_release("fall_" + kind, n)
		if land.is_valid():
			land.call())


func _make_faller(kind: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("pool", "fall_" + kind)
	if kind == "meteor":
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 10
		sm.rings = 6
		rock.mesh = sm
		rock.scale = Vector3(1, 1, 1.5)
		toon(rock, Color(1.0, 0.55, 0.12), 0.04)
		root.add_child(rock)
	else:
		var a := KK.prop("res://assets/kaykit/weapons/ammo_arrow.gltf")
		a.scale = Vector3.ONE * 2.2
		a.rotation = Vector3(0, 0, 0)
		root.add_child(a)
	return root
