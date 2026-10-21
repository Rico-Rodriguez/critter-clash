class_name HubScene
extends Node3D

## The safe zone of the Barrow Lands: Barrow Haven. A Node3D root that lays
## out the camp — the spawn point in the middle, a stall either side for
## the two shops, the campfire at the centre and a gate portal per depth tier.
## Nothing fights here (WorldData marks the hub "no_combat"), so the scene
## only places the player and points them at the right counter.
##
## The camp is built in code, so the whole thing is one file: the ground, the
## fire, the two stalls, the ring of trees and the standing stones that
## mark the gates out of the camp.

## Where the player lands in the camp: the middle of the fire.
const SPAWN_POS := Vector3(0.0, 0.0, 0.0)

## The General Store stall, west of the campfire.
const GENERAL_STORE_POS := Vector3(-4.6, 0.0, -0.4)

## The Material Buyer stall, east of the campfire.
const MATERIAL_BUYER_POS := Vector3(4.6, 0.0, -0.4)

## The camp's own id, as WorldData spells it.
const HUB_ID := "hub"

## The gate markers: one per depth tier, with the tier's id, where its
## stones stand and whether the gate stands open.
var gates: Array = []

## The places of the town: the forge, the slayer post, the road, the
## stash, with the screen each one opens.
var places: Array = []

## How big the camp's ground is, in metres.
const GROUND := 46.0

## The trees and stones that ring the camp.
const RIM := [
	{"model": "tree_a", "at": Vector3(-11.0, 0.0, -7.0), "scale": 1.25},
	{"model": "tree_b", "at": Vector3(-6.5, 0.0, -10.5), "scale": 1.05},
	{"model": "tree_a", "at": Vector3(2.5, 0.0, -11.5), "scale": 1.15},
	{"model": "tree_twist", "at": Vector3(8.5, 0.0, -9.0), "scale": 1.1},
	{"model": "tree_b", "at": Vector3(12.0, 0.0, -3.5), "scale": 1.2},
	{"model": "tree_a", "at": Vector3(-12.5, 0.0, -1.5), "scale": 1.15},
	{"model": "tree_pine", "at": Vector3(-9.5, 0.0, 5.5), "scale": 1.1},
	{"model": "tree_pine", "at": Vector3(10.5, 0.0, 5.0), "scale": 1.05},
	{"model": "tree_b", "at": Vector3(13.0, 0.0, 2.0), "scale": 0.95},
	{"model": "tree_twist", "at": Vector3(-13.5, 0.0, 3.0), "scale": 1.0},
	{"model": "rock_a", "at": Vector3(-4.5, 0.0, -6.0), "scale": 0.9},
	{"model": "rock_b", "at": Vector3(5.0, 0.0, -6.5), "scale": 1.1},
	{"model": "rock_c", "at": Vector3(-7.5, 0.0, 4.0), "scale": 0.85},
	{"model": "stump", "at": Vector3(3.2, 0.0, 4.2), "scale": 1.0},
	{"model": "log", "at": Vector3(-2.6, 0.0, 5.0), "scale": 1.0},
	{"model": "bush", "at": Vector3(7.0, 0.0, 3.0), "scale": 1.2},
	{"model": "bush_flower", "at": Vector3(-6.0, 0.0, 6.2), "scale": 1.0},
]


## Announce the camp: the hub's name and where the player stands.
func _ready() -> void:
	var hub := WorldData.hub_data()
	var spawn := WorldData.hub_spawn()
	print("[HubScene] %s - spawn %s" % [str(hub.get("name", "Hub")), spawn])
	_ground()
	_fire()
	_stall(GENERAL_STORE_POS, "general_store")
	_stall(MATERIAL_BUYER_POS, "material_buyer")
	_well()
	_people()
	_places()
	_wall()
	_rim()
	_gates()


## The camp's ground: a wide disc of grass with a worn path through it.
func _ground() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = GROUND * 0.5
	disc.bottom_radius = GROUND * 0.5
	disc.height = 0.4
	disc.radial_segments = 48
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/ground_grass_color.jpg")
	mat.albedo_color = Color(0.86, 0.92, 0.72)
	mat.uv1_scale = Vector3(9.0, 9.0, 1.0)
	mat.roughness = 0.95
	mat.metallic = 0.0
	disc.material = mat
	var ground := MeshInstance3D.new()
	ground.mesh = disc
	ground.position = Vector3(0.0, -0.2, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# The worn path from the fire to the north gate, where the tier gates
	# stand: a strip of dirt so the camp has a way out.
	var path := BoxMesh.new()
	path.size = Vector3(2.6, 0.06, 12.0)
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_texture = load("res://assets/textures/path_color.jpg")
	path_mat.albedo_color = Color(0.95, 0.86, 0.68)
	path_mat.uv1_scale = Vector3(2.0, 6.0, 1.0)
	path_mat.roughness = 0.98
	path.material = path_mat
	var strip := MeshInstance3D.new()
	strip.mesh = path
	strip.position = Vector3(0.0, 0.03, -8.0)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)


## The campfire: a ring of stones, a few logs and the flame itself. The
## light that warms the camp is the scene's own Campfire node.
func _fire() -> void:
	for i in 9:
		var ang := TAU * float(i) / 9.0
		var stone := _prop("rock_c", Vector3(cos(ang) * 0.85, 0.0, sin(ang) * 0.85), 0.28)
		if stone != null:
			add_child(stone)
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.4
		var log := _prop("log", Vector3(cos(ang) * 0.22, 0.12, sin(ang) * 0.22), 0.55)
		if log != null:
			add_child(log)
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.34
	cone.height = 0.85
	cone.radial_segments = 10
	flame.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffb14a")
	mat.emission_enabled = true
	mat.emission = Color("ff7a18")
	mat.emission_energy_multiplier = 3.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = mat
	flame.position = Vector3(0.0, 0.45, 0.0)
	add_child(flame)


## A stall: a timber counter with a cloth awning over it, and the goods
## on the counter. The name is the one the camp's trade sheet uses.
func _stall(at: Vector3, shop_id: String) -> void:
	var counter := BoxMesh.new()
	counter.size = Vector3(2.4, 1.0, 1.1)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/textures/wood_color.jpg")
	wood.albedo_color = Color(0.55, 0.42, 0.28)
	wood.uv1_scale = Vector3(2.0, 1.0, 1.0)
	wood.roughness = 0.9
	counter.material = wood
	var stand := MeshInstance3D.new()
	stand.mesh = counter
	stand.position = at + Vector3(0.0, 0.5, 0.0)
	add_child(stand)
	var awning := BoxMesh.new()
	awning.size = Vector3(2.9, 0.14, 1.7)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.42, 0.16, 0.14) if shop_id == "general_store" else Color(0.16, 0.24, 0.4)
	cloth.roughness = 0.95
	awning.material = cloth
	var roof := MeshInstance3D.new()
	roof.mesh = awning
	roof.position = at + Vector3(0.0, 2.15, 0.0)
	add_child(roof)
	for i in 2:
		var post := BoxMesh.new()
		post.size = Vector3(0.16, 2.1, 0.16)
		post.material = wood
		var p := MeshInstance3D.new()
		p.mesh = post
		p.position = at + Vector3(-1.2 if i == 0 else 1.2, 1.05, 0.0)
		add_child(p)
	# The goods: a crate and a barrel on the counter.
	var crate := BoxMesh.new()
	crate.size = Vector3(0.7, 0.5, 0.6)
	crate.material = wood
	var c := MeshInstance3D.new()
	c.mesh = crate
	c.position = at + Vector3(-0.6, 1.25, 0.0)
	add_child(c)
	var barrel := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = 0.32
	bmesh.bottom_radius = 0.32
	bmesh.height = 0.7
	bmesh.radial_segments = 12
	bmesh.material = wood
	barrel.mesh = bmesh
	barrel.position = at + Vector3(0.65, 1.35, 0.0)
	add_child(barrel)


## The ring of trees and stones that closes the camp in.
func _rim() -> void:
	for entry in RIM:
		var at: Vector3 = entry["at"]
		var node := _prop(str(entry["model"]), at, float(entry["scale"]))
		if node != null:
			add_child(node)


## The places of the town: the forge, the slayer master's post, the
## trophy board, the stash chest and the desk. Each one stands where it
## is in the town, so a tap on it opens the screen that belongs to it.
func _places() -> void:
	places.clear()
	# The forge: an anvil on its block, with a small fire beside it.
	var anvil_at := Vector3(-5.2, 0.0, -4.6)
	_people_prop("anvil", anvil_at, Vector3(0.9, 0.55, 0.4), Vector3(0.0, 0.45, 0.0))
	_block(anvil_at + Vector3(0.0, 0.0, 0.9), 0.5)
	places.append({"id": "forge", "pos": anvil_at + Vector3(0.0, 0.8, 0.0), "name": "The Forge"})
	# The slayer master: a skull on a post.
	var slayer_at := Vector3(5.4, 0.0, -4.2)
	_people_prop("skull", slayer_at + Vector3(0.0, 1.1, 0.0), Vector3(0.42, 0.42, 0.42), Vector3.ZERO)
	_post(slayer_at, 1.2)
	places.append({"id": "slayer", "pos": slayer_at + Vector3(0.0, 1.4, 0.0), "name": "The Slayer Master"})
	# The trophy board: a board on two legs.
	var road_at := Vector3(-1.0, 0.0, -7.4)
	_people_prop("board", road_at + Vector3(0.0, 1.0, 0.0), Vector3(1.5, 1.0, 0.12), Vector3.ZERO)
	_post(road_at + Vector3(-0.6, 0.0, 0.0), 1.0)
	_post(road_at + Vector3(0.6, 0.0, 0.0), 1.0)
	places.append({"id": "trophy", "pos": road_at + Vector3(0.0, 1.2, 0.0), "name": "The Road"})
	# The stash: a chest by the wall.
	var stash_at := Vector3(2.8, 0.0, -6.2)
	_people_prop("chest", stash_at + Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.6, 0.6), Vector3.ZERO)
	places.append({"id": "stash", "pos": stash_at + Vector3(0.0, 0.7, 0.0), "name": "The Stash"})


## A simple prop for a place: a box, a sphere or a cylinder in stone or
## wood, so a place in the town is something you can see.
func _people_prop(kind: String, at: Vector3, size: Vector3, rot: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	match kind:
		"anvil":
			var m := BoxMesh.new()
			m.size = size
			mesh.mesh = m
		"skull":
			var m := SphereMesh.new()
			m.radius = size.x
			m.height = size.y * 2.0
			mesh.mesh = m
		"chest":
			var m := BoxMesh.new()
			m.size = size
			mesh.mesh = m
		_:
			var m := BoxMesh.new()
			m.size = size
			mesh.mesh = m
	var mat := StandardMaterial3D.new()
	if kind == "skull":
		mat.albedo_color = Color(0.86, 0.84, 0.76)
	elif kind == "chest":
		mat.albedo_color = Color(0.42, 0.3, 0.18)
	else:
		mat.albedo_color = Color(0.32, 0.3, 0.28)
	mat.roughness = 0.9
	mesh.material_override = mat
	mesh.position = at
	mesh.rotation = rot
	add_child(mesh)


## The block an anvil stands on.
func _block(at: Vector3, h: float) -> void:
	var mesh := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.8, h, 0.8)
	mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.3, 0.24)
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position = at + Vector3(0.0, h * 0.5, 0.0)
	add_child(mesh)


## A post, for the things that hang on one.
func _post(at: Vector3, h: float) -> void:
	var mesh := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.09
	m.bottom_radius = 0.11
	m.height = h
	m.radial_segments = 8
	mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.26, 0.18)
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position = at + Vector3(0.0, h * 0.5, 0.0)
	add_child(mesh)


## The ways out of the town: a gate in the town wall at the north and one
## at the south. The north barrier leads deeper, the south one to the
## shallow ground, and the one that stands open is lit, so the town shows
## the way out at a glance.
func _gates() -> void:
	gates.clear()
	var cleared: Dictionary = SaveGame.data.get("tiers_cleared", {})
	for gate in WorldData.town_gates(cleared):
		var gate_id := str(gate["id"])
		var tier_id := str(gate["tier"])
		var open := bool(gate["open"])
		# The north gate stands in the north wall, the south one in the
		# south wall, and the town is between them.
		var at := Vector3(0.0, 0.0, -9.5) if gate_id == "north" else Vector3(0.0, 0.0, 9.5)
		var pair: Array = []
		for side in [-1.0, 1.0]:
			var stone := _prop("rock_a", at + Vector3(1.1 * side, 0.0, 0.0), 1.4)
			if stone != null:
				add_child(stone)
				pair.append(stone)
		# The lit mark of an open gate: a standing shaft of light between
		# the two stones, so the way out is the one that glows.
		if open and pair.size() == 2:
			var glow := OmniLight3D.new()
			glow.light_color = Color("ffc27a")
			glow.light_energy = 3.2
			glow.omni_range = 7.0
			glow.position = at + Vector3(0.0, 1.8, 0.0)
			glow.shadow_enabled = false
			add_child(glow)
			var shaft := MeshInstance3D.new()
			var beam := CylinderMesh.new()
			beam.top_radius = 0.45
			beam.bottom_radius = 0.7
			beam.height = 3.0
			shaft.mesh = beam
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.82, 0.52, 0.1)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.78, 0.45)
			mat.emission_energy_multiplier = 0.4
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shaft.mesh.material = mat
			shaft.position = at + Vector3(0.0, 1.5, 0.0)
			add_child(shaft)
		gates.append({"id": gate_id, "tier": tier_id, "name": str(gate["name"]), "pos": at, "open": open})


## The town wall: a ring of standing stone round the town, with a gap at
## the north and a gap at the south for the two gates. It is what makes
## the town a place inside the world and not an open field.
func _wall() -> void:
	var radius := 10.0
	for i in 40:
		var ang := TAU * float(i) / 40.0
		# The gaps: north (straight ahead) and south (behind).
		var deg := rad_to_deg(ang)
		if absf(deg) < 14.0 or absf(absf(deg) - 180.0) < 14.0:
			continue
		var at := Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		var kind := "rock_a" if i % 3 == 0 else "rock_b"
		var stone := _prop(kind, at, 1.5)
		if stone != null:
			stone.rotation.y = ang + PI * 0.5


## The well in the middle of the plaza: the stone rim, the water and the
## little roof over it.
func _well() -> void:
	var rim := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.05
	tube.bottom_radius = 1.15
	tube.height = 0.9
	tube.radial_segments = 16
	rim.mesh = tube
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.44, 0.42, 0.38)
	stone.roughness = 0.95
	rim.mesh.material = stone
	rim.position = Vector3(-2.6, 0.45, 2.0)
	add_child(rim)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.92
	disc.bottom_radius = 0.92
	disc.height = 0.05
	disc.radial_segments = 16
	water.mesh = disc
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.09, 0.14, 0.18)
	wet.metallic = 0.3
	wet.roughness = 0.15
	water.mesh.material = wet
	water.position = Vector3(-2.6, 0.9, 2.0)
	add_child(water)


## The people of the town: the critters that keep the place. A stall
## keeper behind each stall, one by the fire, one at the gate. They are
## the old cast, and they never become heroes.
func _people() -> void:
	var keepers := [
		{"sprite": "sprout", "at": Vector3(-4.6, 0.0, 0.9)},
		{"sprite": "beetle", "at": Vector3(4.6, 0.0, 0.9)},
		{"sprite": "moth", "at": Vector3(2.0, 0.0, -2.0)},
		{"sprite": "boarlet", "at": Vector3(-1.6, 0.0, -6.5)},
	]
	for person in keepers:
		var sprite := str(person["sprite"])
		var path := Cast3D.model(sprite)
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node3D
		if node == null:
			continue
		add_child(node)
		var box := _measure(node)
		var h: float = maxf(box.size.y, 0.05)
		var scale := 0.9 / h
		node.scale = Vector3.ONE * scale
		node.position = (person["at"] as Vector3) + Vector3(0.0, -box.position.y * scale, 0.0)
		node.rotation.y = PI * 0.85


## A node's bounds, in its own space.
func _measure(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box



## The camp's gates, one per depth tier: the tier's id, where its stones
## stand and whether the gate stands open.
func list_gate_markers() -> Array:
	return gates


## The places of the town, with the screen each one opens.
func list_places() -> Array:
	return places


## Loads a camp prop and drops it on the ground.
func _prop(model: String, at: Vector3, scale: float) -> Node3D:
	var packed := load("res://assets/models/%s.glb" % model) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.position = at
	node.scale = Vector3.ONE * scale
	node.rotation.y = at.x * 0.7 + at.z * 0.3
	return node


## The spawn point in world space: the hub's 2D spawn lifted off the ground.
func spawn_position() -> Vector3:
	var spawn := WorldData.hub_spawn()
	return Vector3(spawn.x, 0.0, spawn.y)


## Opens a shop stall and hands back its trade sheet: what the stall sells,
## what it buys, and the result of the trade when one was asked for.
## The General Store sells its stock and buys materials at the base price;
## the Material Buyer only buys materials, at the premium rate.
## Pass an item id to trade: a stocked id is bought from the stall, a
## material id is sold to it, and "all" sells the whole bag.
func open_shop(shop_id: String, item_id: String = "", amount: int = -1) -> Dictionary:
	var key := _shop_key(shop_id)
	if key == "":
		return {
			"ok": false,
			"reason": "No such stall",
			"shop": shop_id,
			"name": shop_id,
			"blurb": "",
			"can_buy": false,
			"can_sell": false,
			"stock": [],
			"buys": [],
			"coins": 0,
		}
	var sheet := {
		"ok": true,
		"reason": "",
		"shop": key,
		"name": ShopDB.shop_name(key),
		"blurb": ShopDB.shop_blurb(key),
		"can_buy": ShopDB.can_buy(key),
		"can_sell": ShopDB.can_sell(key),
		"stock": [],
		"buys": [],
		"coins": 0,
	}
	if ShopDB.can_sell(key):
		sheet["stock"] = ShopDB.general_stock()
	if ShopDB.can_buy(key):
		sheet["buys"] = _buyable_ids(key)
	if item_id == "":
		return sheet
	return _trade(sheet, key, item_id, amount)


## The gate portals that lead out of the hub, one per depth tier, named as
## the tiers are: the treeline first, the lair last.
func list_gates() -> Array:
	var gates: Array = []
	for tier_id in WorldData.tier_order():
		gates.append(WorldData.tier_name(str(tier_id)))
	return gates


## Runs the trade for an open stall and folds the result into the sheet.
## The stall sells what it stocks, and buys materials out of the bag.
func _trade(sheet: Dictionary, key: String, item_id: String, amount: int) -> Dictionary:
	if item_id == "all":
		var coins := ShopDB.sell_all_to_shop(key)
		sheet["coins"] = coins
		if coins <= 0:
			sheet["ok"] = false
			sheet["reason"] = "Nothing to sell"
		return sheet
	if ShopDB.can_sell(key) and not ShopDB.general_item(item_id).is_empty():
		var bought := ShopDB.buy_from_general(item_id)
		sheet["ok"] = bool(bought.get("ok", false))
		sheet["reason"] = str(bought.get("reason", ""))
		sheet["coins"] = int(bought.get("coins_spent", 0))
		return sheet
	if ShopDB.can_buy(key) and MaterialDB.is_material(item_id):
		var paid := ShopDB.sell_to_shop(key, item_id, amount)
		sheet["coins"] = paid
		if paid <= 0:
			sheet["ok"] = false
			sheet["reason"] = "Nothing to sell"
		return sheet
	sheet["ok"] = false
	sheet["reason"] = "This stall does not trade that"
	return sheet


## The hub names its stalls "general_store"; the shop database calls the same
## counter "general". Both spellings open the same stall.
func _shop_key(shop_id: String) -> String:
	var key := str(shop_id)
	if key == "general_store":
		key = "general"
	return key if ShopDB.shop_ids().has(key) else ""


## The materials a stall will take. The General Store takes any material at
## the base price; the Material Buyer pays the premium rate and takes only
## what it lists.
func _buyable_ids(key: String) -> Array:
	if key == "material_buyer":
		return ShopDB.material_buyer_ids()
	return MaterialDB.all_ids()
