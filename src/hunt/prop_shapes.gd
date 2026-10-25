extends RefCounted
## How each environment prop collides. Collision is 2D on XZ (see Arena:
## blocked / resolve), shared by the hero, foes, allies, ground sidekicks and
## projectiles, and the flow field the foes path by is built from the same
## shapes, so whatever blocks a walker is walked round.
##
## Every model an arena places must be listed in POLICY (the test "every prop
## type has a collision policy" fails otherwise):
##   "box"   an oriented rectangle: buildings, walls, slabs, coffins, crates
##   "round" a circle: trunks, posts, pillars, barrels, rocks
##   "walk"  no collider: ground clutter (bones, coins, candles), wall
##           dressing (banners, torches), floor tiles and bushes
## A shape's size is the model's footprint in the body band (BAND_LO..BAND_HI
## metres up, at scale 1), baked into src/data/prop_footprints.gd by
## tools/dev/bake_prop_footprints.gd, times FILL, times the placed scale.
## Anything smaller than MIN_SIZE across once placed is left walkable, so a
## pebble never snags a walker.

const FOOT := preload("res://src/data/prop_footprints.gd")
const DIRS := ["res://assets/kaykit/graveyard/", "res://assets/kaykit/dungeon/", "res://assets/kaykit/forest/"]

const BAND_LO := 0.25
const BAND_HI := 1.6
const MIN_SIZE := 0.45
## Shapes sit a touch inside the mesh so a walker's edge meets the visible
## surface rather than stopping short of it. Round shapes take the mean half
## extent, box shapes each axis.
const FILL := 0.92
## Per-model corrections: {"fill": float} or {"half": Vector2, "off": Vector2}
## (model space, scale 1) where the band footprint misreads the model.
const OVERRIDE := {
	# Leafy crowns and pine skirts reach into the band; walkers meet the
	# trunk and the lowest boughs, not the outer needles.
	"Tree_1_A_Color1.gltf": {"fill": 0.45},
	"Tree_3_A_Color1.gltf": {"fill": 0.55},
	"tree_pine_orange_large.gltf": {"fill": 0.35},
	"tree_pine_yellow_large.gltf": {"fill": 0.35},
	"tree_pine_orange_medium.gltf": {"fill": 0.4},
	"tree_pine_yellow_medium.gltf": {"fill": 0.4},
	"tree_pine_orange_small.gltf": {"fill": 0.45},
	# A lantern hangs off the post on an arm: the post alone blocks.
	"post_lantern.gltf": {"half": Vector2(0.22, 0.22), "off": Vector2.ZERO},
	"post_skull.gltf": {"half": Vector2(0.24, 0.24), "off": Vector2.ZERO},
}

const POLICY := {
	"crypt.gltf": "box",
	"arch_gate.gltf": "box",
	"wall.gltf": "box",
	"wall_arched.gltf": "box",
	"wall_broken.gltf": "box",
	"wall_cracked.gltf": "box",
	"wall_window_closed.gltf": "box",
	"fence.gltf": "box",
	"fence_broken.gltf": "box",
	"barrier.gltf": "box",
	"coffin.gltf": "box",
	"coffin_decorated.gltf": "box",
	"bench.gltf": "box",
	"bench_decorated.gltf": "box",
	"grave_A.gltf": "box",
	"grave_B.gltf": "box",
	"grave_A_destroyed.gltf": "box",
	"gravestone.gltf": "box",
	"gravemarker_A.gltf": "box",
	"gravemarker_B.gltf": "box",
	"crates_stacked.gltf": "box",
	"box_stacked.gltf": "box",
	"barrel_small_stack.gltf": "box",
	"chest.gltf": "box",
	"chest_gold.gltf": "box",
	"rubble_large.gltf": "box",
	"rubble_half.gltf": "box",
	"pillar_decorated.gltf": "box",
	"tree_pine_orange_large.gltf": "round",
	"tree_pine_yellow_large.gltf": "round",
	"tree_pine_orange_medium.gltf": "round",
	"tree_pine_yellow_medium.gltf": "round",
	"tree_pine_orange_small.gltf": "round",
	"tree_dead_large.gltf": "round",
	"tree_dead_large_decorated.gltf": "round",
	"tree_dead_medium.gltf": "round",
	"Tree_1_A_Color1.gltf": "round",
	"Tree_2_A_Color1.gltf": "round",
	"Tree_3_A_Color1.gltf": "round",
	"Tree_Bare_1_A_Color1.gltf": "round",
	"Tree_Bare_2_A_Color1.gltf": "round",
	"pillar.gltf": "round",
	"column.gltf": "round",
	"shrine.gltf": "round",
	"shrine_candles.gltf": "round",
	"barrel_large.gltf": "round",
	"pumpkin_orange.gltf": "round",
	"pumpkin_orange_jackolantern.gltf": "round",
	"lantern_standing.gltf": "round",
	"fence_pillar.gltf": "round",
	"fence_pillar_broken.gltf": "round",
	"post_lantern.gltf": "round",
	"post_skull.gltf": "round",
	"Rock_1_A_Color1.gltf": "round",
	"Rock_1_B_Color1.gltf": "round",
	"Rock_1_C_Color1.gltf": "round",
	"Rock_1_D_Color1.gltf": "round",
	"Rock_1_E_Color1.gltf": "round",
	"Rock_1_F_Color1.gltf": "round",
	"Rock_1_G_Color1.gltf": "round",
	"Rock_1_H_Color1.gltf": "round",
	"Rock_1_I_Color1.gltf": "round",
	"Rock_1_J_Color1.gltf": "round",
	"Rock_2_A_Color1.gltf": "round",
	"Rock_2_B_Color1.gltf": "round",
	"Rock_2_C_Color1.gltf": "round",
	"Rock_2_D_Color1.gltf": "round",
	"Rock_2_E_Color1.gltf": "round",
	"Rock_2_F_Color1.gltf": "round",
	"Rock_2_G_Color1.gltf": "round",
	"Rock_2_H_Color1.gltf": "round",
	"Rock_3_A_Color1.gltf": "round",
	"Rock_3_B_Color1.gltf": "round",
	"Rock_3_C_Color1.gltf": "round",
	"Rock_3_D_Color1.gltf": "round",
	"Rock_3_E_Color1.gltf": "round",
	"Rock_3_F_Color1.gltf": "round",
	"Rock_3_G_Color1.gltf": "round",
	"Rock_3_H_Color1.gltf": "round",
	"Rock_3_I_Color1.gltf": "round",
	"Rock_3_J_Color1.gltf": "round",
	"bone_A.gltf": "walk",
	"bone_B.gltf": "walk",
	"bone_C.gltf": "walk",
	"skull.gltf": "walk",
	"ribcage.gltf": "walk",
	"skull_candle.gltf": "walk",
	"candle_lit.gltf": "walk",
	"candle_melted.gltf": "walk",
	"candle_triple.gltf": "walk",
	"coin.gltf": "walk",
	"coin_stack_small.gltf": "walk",
	"coin_stack_medium.gltf": "walk",
	"coin_stack_large.gltf": "walk",
	"floor_tile_extralarge_grates.gltf": "walk",
	"floor_dirt_grave.gltf": "walk",
	"banner_patternA_red.gltf": "walk",
	"banner_patternA_yellow.gltf": "walk",
	"banner_patternB_blue.gltf": "walk",
	"torch_mounted.gltf": "walk",
	"sword_shield_gold.gltf": "walk",
	"pumpkin_yellow_small.gltf": "walk",
	"Bush_1_A_Color1.gltf": "walk",
	"Bush_1_B_Color1.gltf": "walk",
	"Bush_1_C_Color1.gltf": "walk",
	"Bush_2_A_Color1.gltf": "walk",
	"Bush_2_B_Color1.gltf": "walk",
	"Bush_2_C_Color1.gltf": "walk",
	"Bush_3_A_Color1.gltf": "walk",
	"Bush_3_B_Color1.gltf": "walk",
	"Bush_3_C_Color1.gltf": "walk",
	"Bush_4_A_Color1.gltf": "walk",
	"Bush_4_B_Color1.gltf": "walk",
	"Bush_4_C_Color1.gltf": "walk",
}


static func path_of(file: String) -> String:
	for d: String in DIRS:
		if ResourceLoader.exists(d + file):
			return d + file
	return ""


## [kind, centre (Vector2, rotated and scaled), half extents (Vector2, scaled)]
## for a placed prop, or ["walk"] when it should not collide.
static func shape_for(path: String, yaw: float, scale_: float) -> Array:
	var file := path.get_file()
	var kind: String = POLICY.get(file, "walk")
	if kind == "walk" or not FOOT.FOOT.has(file):
		return ["walk"]
	var f: Array = FOOT.FOOT[file]
	var off := Vector2(f[0], f[1])
	var half := Vector2(f[2], f[3]) * FILL
	var o: Dictionary = OVERRIDE.get(file, {})
	if o.has("fill"):
		half = Vector2(f[2], f[3]) * float(o["fill"])
	if o.has("half"):
		half = o["half"]
		off = o["off"]
	half *= scale_
	if maxf(half.x, half.y) * 2.0 < MIN_SIZE:
		return ["walk"]
	# Node yaw turns +X toward -Z: rotate the model-space offset the same way.
	var c := Vector2(off.x * cos(yaw) + off.y * sin(yaw), -off.x * sin(yaw) + off.y * cos(yaw)) * scale_
	if kind == "round":
		var r := (half.x + half.y) * 0.5
		return ["round", c, Vector2(r, r)]
	return ["box", c, half]


## Footprint of the model's geometry inside the body band: [cx, cz, hx, hz].
static func measure(path: String) -> Array:
	var n: Node3D = KK.prop(path)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var q: Node = mi
		while q != n and q != null:
			t = (q as Node3D).transform * t
			q = q.get_parent()
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			# Triangles, clipped to the band, so a tall wall face with
			# vertices only at its foot and top still counts.
			var tri_n := idx.size() / 3 if not idx.is_empty() else verts.size() / 3
			for ti in tri_n:
				var a := t * verts[idx[ti * 3] if not idx.is_empty() else ti * 3]
				var b := t * verts[idx[ti * 3 + 1] if not idx.is_empty() else ti * 3 + 1]
				var cc := t * verts[idx[ti * 3 + 2] if not idx.is_empty() else ti * 3 + 2]
				var ymin := minf(a.y, minf(b.y, cc.y))
				var ymax := maxf(a.y, maxf(b.y, cc.y))
				if ymax < BAND_LO or ymin > BAND_HI:
					continue
				for v: Vector3 in [a, b, cc]:
					lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
					hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
	n.free()
	if lo.x > hi.x:
		return [0.0, 0.0, 0.0, 0.0]
	return [(lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (hi.x - lo.x) * 0.5, (hi.y - lo.y) * 0.5]
