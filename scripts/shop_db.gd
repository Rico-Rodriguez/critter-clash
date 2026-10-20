class_name ShopDB
extends RefCounted

## Hub shops data layer. Two shops with distinct identities:
## 1) General Store — buys anything at base price; sells potions, food, starter tools.
## 2) Material Buyer — pays premium prices for gathered materials only; sells nothing.
##
## Prices are coins. The save keeps no shop state; stock is static data.
## Tests and tools may point the API at a scratch dict via store_override.

## --- Shop identity ------------------------------------------------------------

enum ShopID { GENERAL, MATERIAL_BUYER }
const SHOP_KEYS: Array[String] = ["general", "material_buyer"]
const SHOP_NAMES: Array[String] = ["General Store", "Material Buyer"]
const SHOP_BLUBS: Array[String] = [
	"Buys anything at base price. Sells potions, food, and starter tools.",
	"Pays premium prices for gathered materials. Does not sell anything.",
]

## Shop flags (what the shop can do).
const CAN_BUY := 1
const CAN_SELL := 2

const SHOP_FLAGS: Array[int] = [
	CAN_BUY | CAN_SELL,   # General Store
	CAN_BUY,              # Material Buyer (only buys)
]

## --- General Store stock (what it sells) --------------------------------------

## item id -> {name, price, kind, detail}
## kinds: "potion", "food", "tool"
const GENERAL_STOCK: Dictionary = {
	# Potions
	"health_potion": {"name": "Health Potion", "price": 25, "kind": "potion", "detail": "Heal 50 health instantly."},
	"mana_potion": {"name": "Mana Potion", "price": 30, "kind": "potion", "detail": "Restore 40 mana instantly."},
	"strength_tonic": {"name": "Strength Tonic", "price": 60, "kind": "potion", "detail": "Damage +20% for 30s."},
	"speed_elixir": {"name": "Speed Elixir", "price": 55, "kind": "potion", "detail": "Move speed +25% for 30s."},
	# Food
	"bread": {"name": "Bread", "price": 8, "kind": "food", "detail": "Heal 15 health."},
	"cheese": {"name": "Cheese", "price": 12, "kind": "food", "detail": "Heal 22 health."},
	"meat_pie": {"name": "Meat Pie", "price": 20, "kind": "food", "detail": "Heal 35 health."},
	"stew": {"name": "Hearty Stew", "price": 35, "kind": "food", "detail": "Heal 55 health."},
	# Starter tools (one-time unlocks / conveniences)
	"gathering_satchel": {"name": "Gathering Satchel", "price": 150, "kind": "tool", "detail": "+10 material capacity."},
	"loot_magnet": {"name": "Loot Magnet", "price": 200, "kind": "tool", "detail": "Gems attracted from farther away."},
	"camp_bell": {"name": "Camp Bell", "price": 120, "kind": "tool", "detail": "Camp chests unlock 25% faster."},
}

## --- Material Buyer premium prices --------------------------------------------
## material id -> price multiplier over MaterialDB.base_price
## Only materials the bag can hold are listed here.
const MATERIAL_PREMIUM: Dictionary = {
	# Boss materials (4 per biome)
	"meadow_fiber": 1.5,
	"pollen": 1.5,
	"boar_bristle": 1.5,
	"flower_crown": 1.5,
	"cap_bits": 1.5,
	"spore_dust": 1.5,
	"toad_cap": 1.5,
	"giant_cap": 1.5,
	"frost_wool": 1.5,
	"ice_shard": 1.5,
	"hare_fluff": 1.5,
	"aurora_shard": 1.5,
	"ash_clump": 1.5,
	"ember_ore": 1.5,
	"salamander_scale": 1.5,
	"heart_of_ash": 1.5,
	# Gathered resources (Woodcutting)
	"willow_logs": 2.0,
	"oak_logs": 2.0,
	"sporewood_logs": 2.0,
	"barrowwood_logs": 2.0,
	"frostpine_logs": 2.0,
	"glacierheart_logs": 2.0,
	"cinderwood_logs": 2.0,
	"emberbark_logs": 2.0,
	# Gathered resources (Fishing)
	"brook_fish": 2.0,
	"pool_fish": 2.0,
	"spore_carp": 2.0,
	"underroot_eel": 2.0,
	"glacier_fish": 2.0,
	"frostspring_crab": 2.0,
	"magma_fish": 2.0,
	"emberdeep_fish": 2.0,
	# Gathered resources (Mining)
	"copper_ore": 2.0,
	"tin_ore": 2.0,
	"iron_ore": 2.0,
	"coal": 2.0,
	"silver_ore": 2.0,
	"gold_ore": 2.0,
	"cinderore": 2.0,
	"runebound_shard": 2.0,
}

## Tests and tools may point the API at a scratch dict instead of the save.
static var store_override: Variant = null

static func _store() -> Dictionary:
	var data: Dictionary
	if store_override != null:
		data = store_override
	else:
		var tree := Engine.get_main_loop() as SceneTree
		var save: Node = tree.root.get_node_or_null("/root/SaveGame") if tree else null
		if save == null:
			store_override = {}
			data = store_override
		else:
			data = save.data
	return data

static func _persist() -> void:
	if store_override != null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("/root/SaveGame") if tree else null
	if save and save.has_method("_write"):
		save._write()

# --- Public API ---------------------------------------------------------------

## All shop ids in order.
static func shop_ids() -> Array[String]:
	return SHOP_KEYS.duplicate()

## Shop display name.
static func shop_name(id: String) -> String:
	var idx := SHOP_KEYS.find(id)
	return SHOP_NAMES[idx] if idx >= 0 else id

## Shop blurb text.
static func shop_blurb(id: String) -> String:
	var idx := SHOP_KEYS.find(id)
	return SHOP_BLUBS[idx] if idx >= 0 else ""

## True when the shop can buy from the player.
static func can_buy(id: String) -> bool:
	var idx := SHOP_KEYS.find(id)
	return idx >= 0 and (SHOP_FLAGS[idx] & CAN_BUY) != 0

## True when the shop sells to the player.
static func can_sell(id: String) -> bool:
	var idx := SHOP_KEYS.find(id)
	return idx >= 0 and (SHOP_FLAGS[idx] & CAN_SELL) != 0

## What the General Store sells: array of {id, name, price, kind, detail}.
static func general_stock() -> Array:
	var out: Array = []
	for key in GENERAL_STOCK:
		var entry: Dictionary = GENERAL_STOCK[key].duplicate()
		entry["id"] = key
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"])
	)
	return out

## General Store item by id, or {} if not sold here.
static func general_item(id: String) -> Dictionary:
	if not GENERAL_STOCK.has(id):
		return {}
	var entry: Dictionary = GENERAL_STOCK[id].duplicate()
	entry["id"] = id
	return entry

## Price the General Store sells an item for.
static func general_sell_price(id: String) -> int:
	return int(GENERAL_STOCK.get(id, {}).get("price", 0))

## Price the General Store buys an item for (always base price).
## For materials, base price comes from MaterialDB.
## For anything else, returns 0 (shop won't buy it).
static func general_buy_price(id: String) -> int:
	if MaterialDB.is_material(id):
		return MaterialDB.price(id)
	return 0

## Material Buyer price for a material (premium over base), or 0 if not a buyer item.
static func material_buyer_price(id: String) -> int:
	var base := MaterialDB.price(id)
	if base <= 0:
		return 0
	var mult: float = float(MATERIAL_PREMIUM.get(id, 1.0))
	return int(round(float(base) * mult))

## All material ids the Material Buyer pays premium for, in stable order.
static func material_buyer_ids() -> Array:
	var out: Array = []
	for id in MATERIAL_PREMIUM:
		if MaterialDB.is_material(id):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var pa := MaterialDB.price(a)
		var pb := MaterialDB.price(b)
		if pa != pb:
			return pa < pb
		return a < b
	)
	return out

## Buy from player: deduct from materials bag, add coins to wallet.
## Returns coins paid (0 if nothing sold).
## General Store buys materials at base price; Material Buyer at premium.
## Non-materials are never bought (return 0).
static func sell_to_shop(shop_id: String, material_id: String, amount: int = -1) -> int:
	if not can_buy(shop_id):
		return 0
	if not MaterialDB.is_material(material_id):
		return 0
	var save := _save_node()
	if save == null:
		return 0
	var have := int((save as Node).data.get("materials", {}).get(material_id, 0))
	if have <= 0:
		return 0
	var unit: int
	if shop_id == "general":
		unit = MaterialDB.price(material_id)
	elif shop_id == "material_buyer":
		unit = material_buyer_price(material_id)
	else:
		return 0
	if unit <= 0:
		return 0
	var sold := have if amount < 0 else mini(amount, have)
	if sold <= 0:
		return 0
	var coins := unit * sold
	if sold >= have:
		(save as Node).data["materials"].erase(material_id)
	else:
		(save as Node).data["materials"][material_id] = have - sold
	(save as Node).data["coins"] = int((save as Node).data.get("coins", 0)) + coins
	_persist()
	return coins

## Sell all materials in bag to a shop. Returns total coins.
static func sell_all_to_shop(shop_id: String) -> int:
	if not can_buy(shop_id):
		return 0
	var save := _save_node()
	if save == null:
		return 0
	var total := 0
	var mats: Dictionary = (save as Node).data.get("materials", {})
	for id in mats.keys():
		var count := int(mats[id])
		if count <= 0:
			continue
		var unit: int
		if shop_id == "general":
			unit = MaterialDB.price(id)
		elif shop_id == "material_buyer":
			unit = material_buyer_price(id)
		else:
			continue
		if unit <= 0:
			continue
		total += unit * count
	if total > 0:
		(save as Node).data["materials"] = {}
		(save as Node).data["coins"] = int((save as Node).data.get("coins", 0)) + total
		_persist()
	return total

## Buy from General Store: deduct coins, grant item (for tools) or log purchase.
## For potions/food, this would add to a consumable bag (not yet implemented);
## for tools, grant a permanent unlock. Returns {ok, reason, coins_spent}.
static func buy_from_general(item_id: String) -> Dictionary:
	var item := general_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "Not sold here", "coins_spent": 0}
	var price := int(item["price"])
	var save := _save_node()
	if save == null:
		return {"ok": false, "reason": "Save unavailable", "coins_spent": 0}
	var wallet := int((save as Node).data.get("coins", 0))
	if wallet < price:
		return {"ok": false, "reason": "Not enough coins", "coins_spent": 0}
	# Tools are permanent unlocks stored in data["shop_unlocks"].
	var kind := str(item["kind"])
	if kind == "tool":
		var unlocks: Dictionary = (save as Node).data.get("shop_unlocks", {})
		if typeof(unlocks) != TYPE_DICTIONARY:
			unlocks = {}
			(save as Node).data["shop_unlocks"] = unlocks
		if unlocks.has(item_id) and bool(unlocks[item_id]):
			return {"ok": false, "reason": "Already owned", "coins_spent": 0}
		unlocks[item_id] = true
	# Potions/food would go to a consumable bag; for now just spend coins.
	(save as Node).data["coins"] = wallet - price
	_persist()
	return {"ok": true, "reason": "", "coins_spent": price}

## Check if a tool from General Store is unlocked.
static func is_tool_unlocked(tool_id: String) -> bool:
	var save := _save_node()
	if save == null:
		return false
	var unlocks: Dictionary = (save as Node).data.get("shop_unlocks", {})
	return bool(unlocks.get(tool_id, false))

## All unlocked tool ids.
static func unlocked_tools() -> Array[String]:
	var save := _save_node()
	if save == null:
		return []
	var unlocks: Dictionary = (save as Node).data.get("shop_unlocks", {})
	var out: Array[String] = []
	for id in unlocks:
		if bool(unlocks[id]):
			out.append(str(id))
	return out

static func _save_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/SaveGame") if tree else null