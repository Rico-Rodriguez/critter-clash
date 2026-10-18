extends SceneTree
## Desktop OTA test helper: packs files into one or more .pck files.
## godot --headless --path . --script res://tools/ota_test_pack.gd -- out.pck res://a=/abs/src [+ out2.pck ...]

func _init() -> void:
	var err := OK
	var groups: Array = [[]]
	for a in OS.get_cmdline_user_args():
		if a == "+":
			groups.append([])
		else:
			groups[-1].append(a)
	for g in groups:
		var packer := PCKPacker.new()
		var e := packer.pck_start(g[0])
		for pair in g.slice(1):
			var bits: PackedStringArray = str(pair).split("=", true, 1)
			e = maxi(e, packer.add_file(bits[0], bits[1]))
		e = maxi(e, packer.flush())
		print("OTA_TEST_PACK %s err=%d" % [g[0], e])
		err = maxi(err, e)
	quit(err)
