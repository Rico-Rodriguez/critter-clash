extends RefCounted
## The rotating egg shop: three daily offers and one weekly feature, picked by
## seeded rolls from the day and week number, so every reload (and every
## device) shows the same shelf. Static functions on the save dictionary.
## Preload by path: `const EggShop := preload("res://src/autoload/egg_shop.gd")`.

const SK := preload("res://src/autoload/sidekicks.gd")
const SDB := preload("res://src/data/sidekick_db.gd")

const DAY := 86400
const WEEK := 7 * DAY
const SLOTS := 4
## Per slot, what it may sell: [egg, currency, price, weight]. Slots 0-2 turn
## over daily, slot 3 weekly. A species egg you already own or hold is skipped.
const SHELF := [
	[["brood", "gold", 2500, 1]],
	[["brood", "gems", 30, 3], ["season", "gems", 90, 2]],
	[["season", "gems", 90, 3], ["ember", "gems", 150, 1], ["grove", "gems", 150, 1]],
	[["omen", "gems", 160, 1]],
]


## The day and week now, and the seconds until each turns over.
static func rotation(now: int) -> Dictionary:
	return {"day": now / DAY, "week": now / WEEK, "day_left": DAY - now % DAY, "week_left": WEEK - now % WEEK}


static func _id(slot: int, now: int) -> int:
	return now / WEEK if slot == SLOTS - 1 else now / DAY


static func _key(slot: int, now: int) -> String:
	return "%d:%d" % [slot, _id(slot, now)]


## A slot's egg, currency and price for this rotation.
static func _pick(d: Dictionary, slot: int, now: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash("egg-shop-%d-%d" % [slot, _id(slot, now)])
	var opts: Array = (SHELF[slot] as Array).filter(func(o: Array) -> bool:
		var ed: Dictionary = SDB.EGGS[str(o[0])]
		return not (ed.has("hatches") and (SK.is_owned(d, str(ed["hatches"])) or SK.has_egg(d, str(o[0])))))
	if opts.is_empty():
		opts = [["season", "gems", 90, 1]]
	var total := 0
	for o: Array in opts:
		total += int(o[3])
	var pick := r.randi_range(0, total - 1)
	for o: Array in opts:
		pick -= int(o[3])
		if pick < 0:
			return o
	return opts[0]


## The shelf: [{slot, egg, cur ("gold"|"gems"), price, sold, weekly, left (s), why}].
## `why` is "" when it can be bought now, else the reason it can't.
static func offers(d: Dictionary, now: int) -> Array:
	var rot := rotation(now)
	var out := []
	for i in SLOTS:
		var o := _pick(d, i, now)
		# A sold offer keeps showing what was bought, even if the pick moves on.
		var bought := str(SK.block(d)["shop"].get(_key(i, now), ""))
		if bought != "":
			for so: Array in SHELF[i]:
				if str(so[0]) == bought:
					o = so
		var weekly := i == SLOTS - 1
		var of := {"slot": i, "egg": str(o[0]), "cur": str(o[1]), "price": int(o[2]), "weekly": weekly,
			"left": int(rot["week_left"] if weekly else rot["day_left"]), "sold": _sold(d, i, now)}
		of["why"] = _block(d, of)
		out.append(of)
	return out


static func _sold(d: Dictionary, slot: int, now: int) -> bool:
	return str(SK.block(d)["shop"].get(_key(slot, now), "")) != ""


static func _block(d: Dictionary, of: Dictionary) -> String:
	if bool(of["sold"]):
		return "Sold out"
	if SK.hatchery_full(d):
		return "The hatchery is full"
	if str(of["cur"]) == "gold" and int(d.get("gold", 0)) < int(of["price"]):
		return "Needs %d gold" % int(of["price"])
	if str(of["cur"]) == "gems" and SK.gems(d) < int(of["price"]):
		return "Needs %d gems" % int(of["price"])
	return ""


## Why a slot can't be bought now ("" when it can).
static func buy_block(d: Dictionary, slot: int, now: int) -> String:
	if slot < 0 or slot >= SLOTS:
		return "No such offer"
	return str(offers(d, now)[slot]["why"])


## Buys a slot: pays, lays the egg in the hatchery and marks it sold until the
## shelf turns over. Returns {egg, uid, cur, price}, or {} when it can't.
static func buy(d: Dictionary, slot: int, now: int, sd: int) -> Dictionary:
	if buy_block(d, slot, now) != "":
		return {}
	var of: Dictionary = offers(d, now)[slot]
	if str(of["cur"]) == "gold":
		d["gold"] = int(d["gold"]) - int(of["price"])
	else:
		d["gems"] = SK.gems(d) - int(of["price"])
	var e := SK.give_egg(d, str(of["egg"]), now, sd)
	var shop: Dictionary = SK.block(d)["shop"]
	# Old rotations are forgotten, so the record stays small.
	for k: String in shop.keys():
		if not _live(k, now):
			shop.erase(k)
	shop[_key(slot, now)] = str(of["egg"])
	return {"egg": str(of["egg"]), "uid": int(e["uid"]), "cur": str(of["cur"]), "price": int(of["price"])}


static func _live(key: String, now: int) -> bool:
	var parts := key.split(":")
	var slot := int(parts[0])
	return int(parts[1]) == _id(slot, now)
