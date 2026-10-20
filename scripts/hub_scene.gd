class_name HubScene
extends Node3D

## The safe zone of the Barrow Lands: Barrow Haven. A Node3D root that lays
## out the camp — the spawn point in the middle, a stall either side for the
## two shops, the campfire at the centre and a gate portal per depth tier.
## Nothing fights here (WorldData marks the hub "no_combat"), so the scene
## only places the player and points them at the right counter.

## Where the player lands in the camp: the middle of the fire.
const SPAWN_POS := Vector3(0.0, 0.0, 0.0)

## The General Store stall, west of the campfire.
const GENERAL_STORE_POS := Vector3(-6.0, 0.0, 0.0)

## The Material Buyer stall, east of the campfire.
const MATERIAL_BUYER_POS := Vector3(6.0, 0.0, 0.0)

## The camp's own id, as WorldData spells it.
const HUB_ID := "hub"


## Announce the camp: the hub's name and where the player stands.
func _ready() -> void:
	var hub := WorldData.hub_data()
	var spawn := WorldData.hub_spawn()
	print("[HubScene] %s - spawn %s" % [str(hub.get("name", "Hub")), spawn])


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
