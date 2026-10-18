extends SceneTree
func _init():
	GearDB.store_override = {}
	var ok := true
	ok = ok and GearDB.all_items().size() == (8+8+7+8)*3
	ok = ok and not GearDB.equip("pebble", "pebble.helm.1")
	ok = ok and GearDB.grant("pebble.helm.1") and GearDB.grant("pebble.helm.3")
	ok = ok and not GearDB.grant("lumen.offhand.1") and not GearDB.grant("pebble.helm.0")
	ok = ok and GearDB.equip("pebble", "pebble.helm.3") and not GearDB.equip("bramble", "pebble.helm.1")
	ok = ok and GearDB.equipped("pebble")["helm"] == "pebble.helm.3" and GearDB.equipped("pebble")["chest"] == ""
	ok = ok and str(GearDB.owned("pebble")) == str(["pebble.helm.3", "pebble.helm.1"])
	ok = ok and GearDB.slot_tier("pebble", "helm") == 3 and GearDB.slot_tier("pebble", "boots") == 0
	print(GearDB.item("pebble.helm.3"), " ", GearDB.stats("pebble"))
	GearDB.unequip("pebble", "helm")
	ok = ok and GearDB.slot_tier("pebble", "helm") == 0
	print("GEARDB ", "PASS" if ok else "FAIL")
	quit()
