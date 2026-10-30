extends RefCounted
## Pets 2.0 data checks, called from tests.gd: where eggs come from (Trophy
## Road, chests, season, events, story, the egg shop), then breeds, variants,
## hybrids' parts and mutations.

const SK := preload("res://src/autoload/sidekicks.gd")
const SDB := preload("res://src/data/sidekick_db.gd")
const EggShop := preload("res://src/autoload/egg_shop.gd")
const STORY := preload("res://src/data/story_db.gd")
const GEN := preload("res://src/data/pet_gen.gd")
const PARTS := preload("res://src/core/pet_parts.gd")
const PG := preload("res://src/core/pet_graft.gd")
const SKL := preload("res://src/core/sidekick_look.gd")
const SKIN := preload("res://src/core/pet_skin.gd")

const T0 := 1_800_000_000


static func run(ok: Callable) -> void:
	_sources(ok)
	_shop(ok)
	_breeds(ok)
	_skins(ok)
	_hatch(ok)
	_log(ok)
	_carve_flags(ok)


## Carving rebuilds surfaces from their arrays: a float custom channel must
## keep its format or the surface is refused and goes missing.
static func _carve_flags(ok: Callable) -> void:
	var src := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arr[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array([0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1])
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(0), [], {}, PG._rebuild_flags(src.surface_get_format(0)))
	ok.call("carving keeps a surface with a float custom channel", src.get_surface_count() == 1 and out.get_surface_count() == 1)


static func _sources(ok: Callable) -> void:
	var keep := Game.data.duplicate(true)
	# Every egg reward names a real egg.
	var named := true
	var road_eggs := 0
	for i in DB.TROPHY_ROAD.size() + 30:
		var rw := DB.road_reward(i + 1)
		if str(rw["kind"]) == "egg":
			road_eggs += 1
			named = named and SDB.EGGS.has(str(rw["egg"]))
	ok.call("egg sources: the Trophy Road has eggs, all real", road_eggs >= 8 and named)
	ok.call("egg sources: the road keeps its length and its gates", DB.TROPHY_ROAD.size() == 42 and DB.road_gate("grove") == 2500 and DB.road_gate("vault") == 4100)
	var past := DB.TROPHY_ROAD.size()
	ok.call("egg sources: past the road, a season egg every fourth step and an exotic every twelfth", str(DB.road_reward(past + 4)["egg"]) == "season" and str(DB.road_reward(past + 12)["egg"]) == "exotic" and str(DB.road_reward(past + 1)["kind"]) == "chest")
	ok.call("egg sources: a road egg has a name", Game.road_reward_text(5 + 1) != "" and Game.road_reward_text(6) == "Brood Egg")
	# Claiming a road egg lays it; a full hatchery pays gems.
	Game.data = Game._fresh()
	Game.data["road"] = 5
	Game.data["renown"] = 700
	var lines := Game.claim_road()
	ok.call("egg sources: claiming the road egg warms it in the hatchery", SK.has_egg(Game.data, "brood") and int(Game.data["road"]) == 6 and lines.size() == 1 and str(lines[0]).contains("hatchery"))
	Game.data = Game._fresh()
	for i in SDB.HATCH_SLOTS:
		SK.give_egg(Game.data, "brood", T0, i)
	Game.data["road"] = 5
	Game.data["renown"] = 700
	Game.claim_road()
	ok.call("egg sources: a full hatchery pays the road egg as gems", SK.hatchery(Game.data).size() == SDB.HATCH_SLOTS and SK.gems(Game.data) == SDB.FULL_EGG_GEMS)
	# Chests hold eggs of their own grade.
	var cr := RandomNumberGenerator.new()
	cr.seed = 5
	var seen := {}
	var d := Game._fresh()
	for i in 400:
		d["sidekicks"]["hatchery"] = []
		for x in SK.chest_extras(d, "crypt", T0, cr):
			if str(x["type"]) == "egg":
				seen[str(x["egg"])] = true
	ok.call("egg sources: a Crypt chest can hold a Season or a Brood Egg", seen.has("season") and seen.has("brood"))
	var silver := false
	for i in 400:
		d["sidekicks"]["hatchery"] = []
		for x in SK.chest_extras(d, "silver", T0, cr):
			silver = silver or str(x["type"]) == "egg"
	ok.call("egg sources: a Silver chest rarely holds a Brood Egg", silver)
	# The season pass and the story.
	var season_eggs := []
	for n in range(1, DB.SEASON_TIERS + 1):
		var rw := DB.season_reward(n)
		if str(rw["kind"]) == "egg":
			season_eggs.append(str(rw["egg"]))
	ok.call("egg sources: the season pass holds six eggs (one exotic, one omen) and ends on the glow", season_eggs.size() == 6 and season_eggs.count("exotic") == 1 and season_eggs.has("omen") and DB.season_reward(30)["kind"] == "glow")
	var story_ok := true
	for i in STORY.count():
		story_ok = story_ok and SDB.EGGS.has(str(STORY.CHAPTERS[i]["reward"].get("egg", "")))
	ok.call("egg sources: every story chapter pays an egg", story_ok and str(STORY.CHAPTERS[STORY.count() - 1]["reward"]["egg"]) == "exotic")
	Game.data = Game._fresh()
	var first := Game.story_clear({"story": "oath", "hero": "mage"})
	ok.call("egg sources: the first clear lays the chapter's egg", str(first["egg"]) == "brood" and SK.has_egg(Game.data, "brood") and int(first["egg_gems"]) == 0)
	var again := Game.story_clear({"story": "oath", "hero": "mage"})
	ok.call("egg sources: a replay pays no second egg", SK.hatchery(Game.data).size() == 1 and str(again["egg"]) == "")
	Game.data = Game._fresh()
	for i in SDB.HATCH_SLOTS:
		SK.give_egg(Game.data, "brood", T0, i)
	var full := Game.story_clear({"story": "oath", "hero": "mage"})
	ok.call("egg sources: a full hatchery turns the story egg into gems", int(full["egg_gems"]) == SDB.FULL_EGG_GEMS and SK.gems(Game.data) >= SDB.FULL_EGG_GEMS + int(full["gems"]))
	Game.data = keep


static func _shop(ok: Callable) -> void:
	var d := Game._fresh()
	var now := T0
	var a := EggShop.offers(d, now)
	var b := EggShop.offers(Game._fresh(), now + 3600)
	ok.call("egg shop: four offers", a.size() == EggShop.SLOTS)
	var same := true
	for i in a.size():
		same = same and str(a[i]["egg"]) == str(b[i]["egg"]) and int(a[i]["price"]) == int(b[i]["price"])
	ok.call("egg shop: the same day shows the same shelf", same)
	var real := true
	for of: Dictionary in a:
		real = real and SDB.EGGS.has(str(of["egg"])) and int(of["price"]) > 0 and str(of["cur"]) in ["gold", "gems"]
	ok.call("egg shop: every offer is a real egg with a price", real)
	var changed := false
	for day in range(1, 12):
		var o := EggShop.offers(d, now + day * EggShop.DAY)
		changed = changed or str(o[1]["egg"]) != str(a[1]["egg"]) or str(o[2]["egg"]) != str(a[2]["egg"])
	ok.call("egg shop: the daily slots rotate", changed)
	var week_same := true
	var wk := (now / EggShop.WEEK) * EggShop.WEEK
	for day in 7:
		week_same = week_same and str(EggShop.offers(d, wk + day * EggShop.DAY)[3]["egg"]) == "omen"
	ok.call("egg shop: the weekly slot holds all week", week_same and bool(a[3]["weekly"]))
	# Buying.
	ok.call("egg shop: no gold, no gems, no egg", EggShop.buy(d, 0, now, 1).is_empty() and EggShop.buy(d, 1, now, 1).is_empty() and SK.hatchery(d).is_empty())
	d["gold"] = 10000
	d["gems"] = 500
	var gold0 := int(d["gold"])
	var got := EggShop.buy(d, 0, now, 77)
	ok.call("egg shop: buying pays and lays the egg", str(got["egg"]) == str(a[0]["egg"]) and int(d["gold"]) == gold0 - int(a[0]["price"]) and SK.hatchery(d).size() == 1)
	ok.call("egg shop: an offer sells once a day", EggShop.buy(d, 0, now + 60, 78).is_empty() and bool(EggShop.offers(d, now + 60)[0]["sold"]) and EggShop.buy_block(d, 0, now + 60) == "Sold out")
	ok.call("egg shop: it is back the next day", not bool(EggShop.offers(d, now + EggShop.DAY)[0]["sold"]) and (SK.block(d)["shop"] as Dictionary).size() == 1)
	var gems0 := SK.gems(d)
	var wk_buy := EggShop.buy(d, 3, now, 79)
	ok.call("egg shop: the weekly omen egg costs gems", str(wk_buy["egg"]) == "omen" and SK.gems(d) == gems0 - int(a[3]["price"]) and SK.has_egg(d, "omen"))
	EggShop.buy(d, 0, now + EggShop.DAY, 80)
	ok.call("egg shop: old days are forgotten", (SK.block(d)["shop"] as Dictionary).size() == 2)
	var f := Game._fresh()
	f["gold"] = 99999
	f["gems"] = 99999
	for i in SDB.HATCH_SLOTS:
		SK.give_egg(f, "brood", now, i)
	ok.call("egg shop: a full hatchery blocks it without charging", EggShop.buy(f, 1, now, 1).is_empty() and int(f["gems"]) == 99999 and EggShop.buy_block(f, 1, now) == "The hatchery is full")
	ok.call("egg shop: a bad slot is refused", EggShop.buy_block(f, 9, now) != "" and EggShop.buy(f, -1, now, 1).is_empty())
	# A species egg you own is never offered.
	var o := Game._fresh()
	SK.own(o, "drake")
	SK.own(o, "bat")
	var never := true
	for day in 60:
		var offs := EggShop.offers(o, now + day * EggShop.DAY)
		never = never and str(offs[2]["egg"]) == "season"
	ok.call("egg shop: no species egg for a pet you already have", never)
	# Through the Game, with a save.
	Game.memory_only = true
	var keep := Game.data.duplicate(true)
	Game.data = Game._fresh()
	Game.data["gold"] = 5000
	var sh := Game.egg_shop()
	var bought := Game.buy_egg(0)
	ok.call("egg shop: Game.buy_egg works on the save", sh.size() == 4 and not bought.is_empty() and int(Game.data["gold"]) < 5000)
	Game.data = keep


# --- Breeds, variants, parts, mutations ---------------------------------------------

static func _breeds(ok: Callable) -> void:
	# Handmade data is complete and real.
	var data_ok := true
	for id: String in SDB.ORDER:
		var vs: Array = GEN.variants(id)
		var ids := vs.map(func(v): return v["id"])
		data_ok = data_ok and GEN.VARIANTS.has(id) and vs.size() == 4 and ids.size() == (ids as Array).filter(func(x): return ids.count(x) == 1).size()
		for v: Dictionary in vs:
			data_ok = data_ok and Color.html(str(v["color"])) != Color() and SDB.GENE_RANGE.has(str(v["lean"]))
		data_ok = data_ok and GEN.PART_STYLES.has(id)
		for slot: String in GEN.PART_SLOTS:
			data_ok = data_ok and (GEN.PART_NAMES[slot] as Dictionary).has(GEN.PART_STYLES[id][slot])
	ok.call("breeds: every species has 4 coats and a head, wings and tail", data_ok)
	var hy_ok := SDB.BREED_ORDER.size() == 8
	for k: String in SDB.BREED_ORDER:
		var p: Array = SDB.BREEDS[k]["pair"]
		hy_ok = hy_ok and SDB.hybrid_for(str(p[0]), str(p[1])) == k and SDB.hybrid_for(str(p[1]), str(p[0])) == k
		hy_ok = hy_ok and SDB.ROSTER.has(str(p[0])) and SDB.ROSTER.has(str(p[1])) and SDB.CLIPS.has(str(p[0])) and SDB.BREEDS[k].has("echo") and SDB.body_of(k) == str(p[0])
	ok.call("breeds: 8 hybrids, each pair finds its breed either way", hy_ok)
	var mu_ok := GEN.MUTATION_ORDER.size() == GEN.MUTATIONS.size()
	for m: String in GEN.MUTATION_ORDER:
		mu_ok = mu_ok and GEN.MUTATIONS.has(m) and str(GEN.MUTATIONS[m]["power"]) != ""
	ok.call("breeds: six mutations, each with a power", mu_ok and GEN.MUTATIONS.size() == 6)
	# Rolls are seeded and shaped right.
	var ga := SDB.base_genes()
	var c1 := SDB.roll_child("drake", ga, "bonelet", ga, 77)
	var c2 := SDB.roll_child("drake", ga, "bonelet", ga, 77)
	ok.call("breeds: the same seed rolls the same child, parts and all", c1 == c2 and (c1["genes"]["parts"] as Dictionary).size() == 3)
	var shape := true
	var mixed := 0
	var coats := {}
	for sd in 300:
		var c := SDB.roll_child("drake", ga, "bonelet", ga, sd)
		var g: Dictionary = c["genes"]
		shape = shape and not GEN.variant(str(c["breed"]), str(g["variant"])).is_empty() and str(g["accent"]) == str(GEN.variant(str(c["breed"]), str(g["variant"]))["color"])
		coats[str(c["breed"]) + str(g["variant"])] = true
		var donors := (g["parts"] as Dictionary).values()
		shape = shape and donors.all(func(x): return x == "drake" or x == "bonelet")
		if donors.has("drake") and donors.has("bonelet"):
			mixed += 1
		for k in SDB.GENE_RANGE:
			var rg: Vector2 = SDB.GENE_RANGE[k]
			shape = shape and float(g[k]) >= rg.x and float(g[k]) <= rg.y
	ok.call("breeds: children take parts from both parents and wear a real coat", shape and mixed > 100 and coats.size() >= 8)
	# Mutations: rare, inherited, applied.
	var none := 0
	var all := 0
	for sd in 200:
		none += int(str(SDB.roll_child("wisp", ga, "bat", ga, sd, 0.0)["genes"]["mutation"]) != "")
		all += int(str(SDB.roll_child("wisp", ga, "bat", ga, sd, 1.0)["genes"]["mutation"]) != "")
	ok.call("breeds: mutation chance 0 never mutates, 1 always does", none == 0 and all == 200)
	var gm := SDB.base_genes()
	gm["mutation"] = "frostborn"
	var kept := 0
	for sd in 400:
		kept += int(str(SDB.roll_child("wisp", gm, "bat", ga, sd, 0.0)["genes"]["mutation"]) == "frostborn")
	ok.call("breeds: a mutated parent passes it on about a quarter of the time", kept > 60 and kept < 140)
	var wolds := SDB.roll_wild("crow", 5, 0.0)
	var base_d := SDB.bred_def("crow", SDB.base_genes())
	var gs := SDB.base_genes()
	gs["mutation"] = "stormtouched"
	var sd_def := SDB.bred_def("crow", gs)
	ok.call("breeds: stormtouched casts sooner, reaches farther and chains one more", float(sd_def["ability"]["cd"]) < float(base_d["ability"]["cd"]) and float(sd_def["reach"]) > float(base_d["reach"]) and int(sd_def["ability"]["chain"]) == int(base_d["ability"]["chain"]) + 1 and str(sd_def["name"]).begins_with("Stormtouched") and str(sd_def["skin"]) == "stormtouched")
	var gv := SDB.base_genes()
	gv["mutation"] = "verdant"
	var snare := SDB.bred_def("sapling", gv)
	ok.call("breeds: verdant doubles a snare's hold", is_equal_approx(float(snare["ability"]["hold"]), float(SDB.ROSTER["sapling"]["ability"]["hold"]) * 2.0))
	ok.call("breeds: a mutation lifts the grade", SDB.grade(gs, "crow") > SDB.grade(SDB.base_genes(), "crow") and SDB.rarity("zz_none") == 0)
	var notes: Array = sd_def["notes"]
	ok.call("breeds: a pet's card lists its mutation", notes.size() == 1 and str(notes[0]).begins_with("Stormtouched"))
	# Wild hatches.
	var w1 := SDB.roll_wild("crow", 91)
	ok.call("breeds: a wild roll is seeded and close to 1", w1 == SDB.roll_wild("crow", 91) and absf(float(w1["genes"]["dmg"]) - 1.0) <= 0.2 and not GEN.variant("crow", str(w1["genes"]["variant"])).is_empty() and wolds["genes"]["mutation"] == "")
	# Old genomes with none of the new keys still build.
	var old := {"dmg": 1.1, "haste": 1.0, "reach": 1.0, "size": 1.0, "element": "fire", "pattern": "spots", "accent": "ff0000", "glow": false, "personality": "keen", "echo": ""}
	var od := SDB.bred_def("drake", old)
	ok.call("breeds: a pet saved before pets 2.0 still builds", not od.is_empty() and (od["notes"] as Array).is_empty() and not od.has("skin"))
	# Real parts: lifted from the donor's own model and hung on the body's.
	ok.call("breeds: a pet saved before pets 2.0 wears no borrowed part", PARTS.swaps(od).is_empty())
	var gp := SDB.base_genes()
	gp["parts"] = {"head": "bonelet", "wings": "bat", "tail": "drake"}
	gp["mutation"] = "gilded"
	gp["pattern"] = "spots"
	gp["glow"] = true
	SDB.BRED["x98"] = SDB.bred_def("drake", gp)
	var look: Dictionary = SKL.build("x98", false)
	var lr: Node3D = look["root"]
	var gh := lr.find_child("Graft_head", true, false)
	var gw := lr.find_child("Graft_wings", true, false)
	ok.call("breeds: borrowed head and wings hang on the body's skeleton, an own tail adds nothing", gh != null and gw != null and gh is BoneAttachment3D and lr.find_child("Graft_tail", true, false) == null and gw.get_child(0).get_child_count() == 2)
	var prim := 0
	var real := 0
	for n in lr.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is PrimitiveMesh:
			prim += 1
		elif mi.mesh != null and mi.visible:
			real += 1
	ok.call("breeds: no orb, box or prism anywhere on a bred pet (traits, parts and mutation are data and card text)", prim == 0 and real >= 3 and lr.get_node_or_null("Traits") == null and lr.get_node_or_null("Mutation") == null and lr.get_node_or_null("Parts") == null)
	var meshes_ok := true
	for gn: Node in [gh, gw]:
		for n in gn.find_children("*", "MeshInstance3D", true, false):
			var m := (n as MeshInstance3D).mesh
			meshes_ok = meshes_ok and m is ArrayMesh and m.surface_get_material(0) is BaseMaterial3D and (m as ArrayMesh).get_aabb().size.length() > 0.02
	ok.call("breeds: a borrowed part is the donor's own mesh with its own PBR", meshes_ok)
	var wing_sides := []
	for n in gw.find_children("Wing*", "Node3D", true, false):
		wing_sides.append(int(n.get_meta("side")))
	wing_sides.sort()
	ok.call("breeds: wings come as a left and a right pivot", wing_sides == [-1, 1])
	lr.free()
	# The body's own head is cut out where the donor's goes on.
	var own_tris := _tris(SKL.build("drake", false)["root"])
	var carved_tris := _tris(SKL.build("x98", false)["root"])
	ok.call("breeds: the body's own head and wings are cut out so nothing doubles up", carved_tris < own_tris and carved_tris > own_tris / 2)
	SDB.BRED.erase("x98")
	# Every part a species can lend builds on every body: real meshes of sane size.
	var every := true
	var count := 0
	for sp: String in SDB.ORDER:
		for slot: String in GEN.PART_SLOTS:
			if not GEN.donates(sp, slot):
				continue
			count += 1
			var pt := PG.part(sp, slot)
			var sz: Vector3 = pt["aabb"].size if not pt.is_empty() else Vector3.ZERO
			every = every and not pt.is_empty() and sz.length() > 0.05 and sz.length() < 8.0 and (pt["items"] as Array).size() >= (2 if slot == "wings" else 1)
	ok.call("breeds: every part in GEN.GRAFT extracts (%d of them)" % count, every and count == GEN.donor_parts())
	var all_ok := true
	for body: String in SDB.ORDER:
		for sp: String in SDB.ORDER:
			var gq := SDB.base_genes()
			gq["parts"] = {"head": sp, "wings": sp, "tail": sp}
			SDB.BRED["x97"] = SDB.bred_def(body, gq)
			var lk: Dictionary = SKL.build("x97", false)
			var want: int = PARTS.swaps(SDB.BRED["x97"]).size()
			var got := (lk["root"] as Node3D).find_children("Graft_*", "", true, false).size()
			all_ok = all_ok and got == want and want == (0 if sp == body else _donor_slots(sp))
			(lk["root"] as Node3D).free()
	SDB.BRED.erase("x97")
	ok.call("breeds: every body takes every donor's parts (a slot with no real part draws nothing)", all_ok)
	# A slot with no real part stays data and card text only.
	var gx := SDB.base_genes()
	gx["parts"] = {"head": "drake", "wings": "hexling", "tail": "bonelet"}
	var xd := SDB.bred_def("crow", gx)
	ok.call("breeds: a part with no real donor model is on the card but never drawn", PARTS.swaps(xd).size() == 1 and (xd["notes"] as Array).size() == 3)
	# Rolls only hand out parts that exist.
	var rolled := true
	for sd in 120:
		var ch: Dictionary = SDB.roll_child("hexling", SDB.base_genes(), "acolyte", SDB.base_genes(), sd, 0.0)
		for slot: String in GEN.PART_SLOTS:
			var donor := str(ch["genes"]["parts"][slot])
			rolled = rolled and (donor == SDB.body_of(str(ch["breed"])) or GEN.donates(donor, slot))
	ok.call("breeds: a rolled child never gets a part that can't be shown", rolled)


## Every mutation and coat pattern changes a real pet's materials: the artist's
## own StandardMaterial3Ds become shared variant ShaderMaterials (and nothing is
## stuck on).
static func _skins(ok: Callable) -> void:
	var variants: Array = []
	for m: String in GEN.MUTATION_ORDER:
		variants.append({"name": m, "mutation": m, "pattern": "plain", "glow": false})
	variants.append({"name": "spots", "mutation": "", "pattern": "spots", "glow": false})
	variants.append({"name": "stripes", "mutation": "", "pattern": "stripes", "glow": false})
	variants.append({"name": "glow", "mutation": "", "pattern": "plain", "glow": true})
	ok.call("skins: six mutations, two drawn coats and glow are all variants", variants.size() == 9 and GEN.MUTATION_ORDER.size() == 6)
	var uniforms := {}
	for u: Dictionary in SKIN.SHADER.get_shader_uniform_list():
		uniforms[u["name"]] = true
	var changed := true
	var stray := ""
	var plain_clean := true
	var all_converted := true
	var distinct := true
	var shared := true
	var per_pet := true
	var seen := 0
	for sp: String in SDB.ORDER:
		var pg := SDB.base_genes()
		SDB.BRED["x96"] = SDB.bred_def(sp, pg)
		var plain: Node3D = SKL.build("x96", false)["root"]
		for n in plain.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			plain_clean = plain_clean and not (mi.material_override is ShaderMaterial)
			for i in mi.get_surface_override_material_count():
				plain_clean = plain_clean and not (mi.get_surface_override_material(i) is ShaderMaterial)
		var plain_ids := _skin_ids(plain)
		plain.free()
		var ids_by_variant := {}
		for v: Dictionary in variants:
			var g := SDB.base_genes()
			g["mutation"] = v["mutation"]
			g["pattern"] = v["pattern"]
			g["glow"] = v["glow"]
			g["accent"] = "ff8a3d"
			SDB.BRED["x96"] = SDB.bred_def(sp, g)
			var pet: Node3D = SKL.build("x96", false)["root"]
			var want := SKIN.variant(g)
			var got := 0
			for n in pet.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.mesh == null:
					continue
				for i in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(i)
					if mat is BaseMaterial3D:
						all_converted = false
						stray = "%s/%s" % [sp, mi.name]
						continue
					var sm := mat as ShaderMaterial
					if sm == null or sm.shader != SKIN.SHADER:
						continue
					got += 1
					changed = changed and int(sm.get_shader_parameter("mutation")) == int(want["mutation"]) \
						and int(sm.get_shader_parameter("pattern")) == int(want["pattern"]) \
						and (float(sm.get_shader_parameter("glow_on")) > 0.5) == bool(want["glow"])
					for u: String in ["albedo", "mutation", "pattern", "glow_on", "mut_color", "pat_scale", "tex_albedo"]:
						changed = changed and uniforms.has(u)
				if mi.get_instance_shader_parameter("accent") != null and not Color.html("ff8a3d").is_equal_approx(mi.get_instance_shader_parameter("accent")):
					per_pet = false
			var ids := _skin_ids(pet)
			ids_by_variant[v["name"]] = ids
			changed = changed and got > 0 and ids != plain_ids
			seen += got
			pet.free()
		# Every variant draws with materials no other variant (or the plain pet) uses.
		var all_ids: Array = [plain_ids]
		for v: Dictionary in variants:
			var ids: Array = ids_by_variant[v["name"]]
			for other: Array in all_ids:
				for id in ids:
					distinct = distinct and not other.has(id)
			all_ids.append(ids)
		# The same variant on a second pet is the same material objects, whatever its accent.
		var g2 := SDB.base_genes()
		g2["mutation"] = "gilded"
		g2["accent"] = "6ee7ff"
		SDB.BRED["x96"] = SDB.bred_def(sp, g2)
		var other_pet: Node3D = SKL.build("x96", false)["root"]
		shared = shared and _skin_ids(other_pet) == ids_by_variant["gilded"]
		other_pet.free()
	SDB.BRED.erase("x96")
	ok.call("skins: every mutation, coat and glow puts its own shader materials on a pet of every species (%d surfaces)" % seen, changed and seen > 0)
	ok.call("skins: every surface of every species converts, none is left as the artist made it (%s)" % stray, all_converted)
	ok.call("skins: each variant's materials are its own, none shared with another variant or the plain pet", distinct)
	ok.call("skins: two pets in one variant share their materials (accent is per instance)", shared and per_pet)
	ok.call("skins: a plain pet keeps the artist's materials", plain_clean)


## Instance ids of the variant materials on a model.
static func _skin_ids(root: Node3D) -> Array:
	var ids := []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is ShaderMaterial and not ids.has(mat.get_instance_id()):
				ids.append(mat.get_instance_id())
	ids.sort()
	return ids


## Triangles in every mesh of a model, hidden ones left out.
static func _tris(root: Node3D) -> int:
	var n := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.get_parent().name.begins_with("Frame") or mi.get_parent().name.begins_with("Wing"):
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


static func _donor_slots(sp: String) -> int:
	return (GEN.GRAFT.get(sp, {}) as Dictionary).size()


# --- Hatching individuals, mutation pity, cooldown growth, the stable ------------------

static func _hatch(ok: Callable) -> void:
	var d := Game._fresh()
	SK.migrate(d)
	var e := SK.give_egg(d, "ember", T0, 1234)
	var first := SK.hatch(d, int(e["uid"]), T0 + 9 * 3600)
	ok.call("hatching: a first-time species is the plain original", first["id"] == "drake" and not first.has("wild") and SDB.def("drake").get("genes") == null)
	var d2 := Game._fresh()
	SK.migrate(d2)
	SK.own(d2, "wisp")
	var held := SK.give_egg(d2, "brood", T0, 0)
	held["kind"] = "ember"
	held["seed"] = 55
	SK.own(d2, "drake")
	var h1 := SK.hatch(d2, int(held["uid"]), T0 + 9 * 3600)
	ok.call("hatching: an owned species hatches its own individual, kills untouched", bool(h1["wild"]) and SDB.species(str(h1["id"])) == "drake" and SK.kills(d2, "drake") == 0 and str(h1["id"]).begins_with("x"))
	# Seeded: the same egg on the same save rolls the same individual.
	var d3 := Game._fresh()
	SK.migrate(d3)
	SK.own(d3, "drake")
	var e3 := SK.give_egg(d3, "ember", T0, 55)
	var h3 := SK.hatch(d3, int(e3["uid"]), T0 + 9 * 3600)
	ok.call("hatching: the same egg seed gives the same individual", d2["sidekicks"]["owned"][h1["id"]]["genes"] == d3["sidekicks"]["owned"][h3["id"]]["genes"])
	# Pity: each unmutated roll raises the chance; a mutation resets it.
	d3["sidekicks"]["dry"]["mutation"] = 0
	var base_p := SK.mutation_chance(d3, "brood")
	d3["sidekicks"]["dry"]["mutation"] = 10
	var p10 := SK.mutation_chance(d3, "brood")
	d3["sidekicks"]["dry"]["mutation"] = SDB.MUTATION_PITY - 1
	var p59 := SK.mutation_chance(d3, "brood")
	ok.call("hatching: mutation pity climbs and is certain at the pity", is_equal_approx(base_p, SDB.MUTATION_BASE) and p10 > base_p and is_equal_approx(p59, 1.0) and SK.mutation_chance(d3, "exotic") <= 1.0)
	d3["sidekicks"]["dry"]["mutation"] = 0
	ok.call("hatching: exotic eggs and nests beat the base chance", SK.mutation_chance(d3, "exotic") > SK.mutation_chance(d3, "omen") and SK.mutation_chance(d3, "omen") > base_p and SK.mutation_chance(d3, "nest") > base_p)
	d3["sidekicks"]["dry"]["mutation"] = SDB.MUTATION_PITY - 1
	var e4 := SK.give_egg(d3, "brood", T0, 8)
	e4["kind"] = "ember"
	var h4 := SK.hatch(d3, int(e4["uid"]), T0 + 9 * 3600)
	ok.call("hatching: the pity hatch is mutated and resets the count", str(h4["mutation"]) != "" and int(d3["sidekicks"]["dry"]["mutation"]) == 0 and (d3["sidekicks"]["found"]["mutations"] as Array).has(str(h4["mutation"])))
	ok.call("hatching: the result carries the mutation's power line for the reveal", str(h4["mutation_power"]) == str(GEN.MUTATIONS[str(h4["mutation"])]["power"]))
	var e5 := SK.give_egg(d3, "ember", T0, 9)
	SK.hatch(d3, int(e5["uid"]), T0 + 9 * 3600)
	ok.call("hatching: an unmutated roll counts toward the pity", int(d3["sidekicks"]["dry"]["mutation"]) in [0, 1])
	# A full stable falls back to bond kills.
	var d6 := Game._fresh()
	SK.migrate(d6)
	SK.own(d6, "drake")
	for i in SDB.STABLE_MAX:
		d6["sidekicks"]["owned"]["x%d" % (i + 1)] = {"kills": 0, "breed": "wisp", "genes": SDB.base_genes(), "parents": []}
	var e6 := SK.give_egg(d6, "ember", T0, 3)
	var h6 := SK.hatch(d6, int(e6["uid"]), T0 + 9 * 3600)
	ok.call("hatching: a full stable pays bond kills instead", not SK.stable_room(d6) and int(h6["kills"]) == SDB.DUP_KILLS and SK.kills(d6, "drake") == SDB.DUP_KILLS and not bool(h6.get("wild", false)))
	d6["gold"] = SDB.BREED_GOLD
	for id in ["drake", "x1"]:
		d6["sidekicks"]["owned"][id]["kills"] = 900
	ok.call("breeding: a full stable can't breed more", SK.breed_block(d6, "drake", "x1", T0) .begins_with("Your stable is full"))
	# Cooldown grows with every litter.


# --- The collection log and old saves --------------------------------------------------

static func _log(ok: Callable) -> void:
	var d := Game._fresh()
	SK.migrate(d)
	var c0 := SK.collection(d)
	ok.call("log: a new save has nothing found, with real totals", int(c0["variants"]["have"]) == 0 and int(c0["variants"]["total"]) == 11 * 4 + 8 * 4 and int(c0["mutations"]["total"]) == 6 and int(c0["parts"]["total"]) == GEN.donor_parts() and GEN.donor_parts() == 19 and int(c0["breeds"]["total"]) == 19)
	var child := {"breed": "cinderbone", "genes": SDB.base_genes()}
	child["genes"]["variant"] = "bright"
	child["genes"]["mutation"] = "gilded"
	child["genes"]["parts"] = {"head": "bonelet", "wings": "drake", "tail": "drake"}
	d["sidekicks"]["owned"]["x1"] = {"kills": 0, "breed": "cinderbone", "genes": child["genes"], "parents": []}
	SK._discover(d["sidekicks"], child)
	var c1 := SK.collection(d)
	ok.call("log: a rolled pet logs its coat, mutation and borrowed parts", int(c1["variants"]["have"]) == 1 and int(c1["mutations"]["have"]) == 1 and int(c1["parts"]["have"]) == 1 and (d["sidekicks"]["found"]["parts"] as Array).has("head:bonelet"))
	# A save from before the new log lists still loads and gains them.
	var old := Game._fresh()
	(old["sidekicks"]["found"] as Dictionary).erase("variants")
	(old["sidekicks"]["found"] as Dictionary).erase("mutations")
	(old["sidekicks"]["found"] as Dictionary).erase("parts")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(old))
	SK.migrate(saved)
	var fb: Dictionary = saved["sidekicks"]["found"]
	ok.call("log: an old save gains the new lists on load", fb.has("variants") and fb.has("mutations") and fb.has("parts") and int(SK.collection(saved)["parts"]["have"]) == 0)
	# A pet and its mutation survive a save round trip.
	var rt: Dictionary = JSON.parse_string(JSON.stringify(d))
	SDB.BRED.clear()
	SK.migrate(rt)
	ok.call("log: a mutated pet comes back from the save with its skin", str(SDB.def("x1").get("skin", "")) == "gilded" and str(SDB.def("x1")["name"]).begins_with("Gilded"))
	SDB.BRED.clear()
