extends SceneTree
func _init():
	GearDB.store_override = {}
	var ok := true
	ok = ok and GearDB.all_items().size() == (8+8+7+8)*3
	ok = ok and not GearDB.equip("pebble", "pebble.helm.1")
	ok = ok and GearDB.grant("pebble.helm.1") and GearDB.grant("pebble.helm.3")
	GearDB.add_xp("pebble", "defence", GearDB.xp_for_level(40))
	ok = ok and not GearDB.grant("lumen.offhand.1") and not GearDB.grant("pebble.helm.0")
	ok = ok and GearDB.equip("pebble", "pebble.helm.3") and not GearDB.equip("bramble", "pebble.helm.1")
	ok = ok and GearDB.equipped("pebble")["helm"] == "pebble.helm.3" and GearDB.equipped("pebble")["chest"] == ""
	ok = ok and str(GearDB.owned("pebble")) == str(["pebble.helm.3", "pebble.helm.1"])
	ok = ok and GearDB.slot_tier("pebble", "helm") == 3 and GearDB.slot_tier("pebble", "boots") == 0
	print(GearDB.item("pebble.helm.3"), " ", GearDB.stats("pebble"))
	GearDB.unequip("pebble", "helm")
	ok = ok and GearDB.slot_tier("pebble", "helm") == 0
	ok = ok and GearDB.xp_for_level(2) == 83 and GearDB.xp_for_level(99) == 13034431 and GearDB.level_for_xp(1154) == 10
	ok = ok and GearDB.level("lumen", "hitpoints") == 10 and GearDB.level("lumen", "defence") == 1
	GearDB.grant("bramble.helm.2")
	ok = ok and GearDB.can_equip("bramble", "bramble.helm.2")["reason"] == "Requires Defence 20" and not GearDB.equip("bramble", "bramble.helm.2")
	ok = ok and GearDB.add_xp("bramble", "defence", GearDB.xp_for_level(20)) == 19 and GearDB.equip("bramble", "bramble.helm.2")
	ok = ok and GearDB.requirements("ember.weapon.3") == {"magic": 40} and GearDB.requirements("pebble.helm.1").is_empty()
	print(GearDB.level_bonus("pebble"))
	print("GEARDB ", "PASS" if ok else "FAIL")
	quit()
