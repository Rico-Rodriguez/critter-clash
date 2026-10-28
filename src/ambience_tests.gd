extends RefCounted
## Ambient life and sound (hunt/ambience.gd): the assets load and are credited,
## only Rimehollow and the Cinder Mire get a set, the critters stay under their
## caps, leave when the hero comes close, never collide, and the sound bed ducks
## under a loud fight. A real Hunt is built in the test tree and the ambience is
## stepped by hand at 20 Hz with the hero parked.

const Ambience := preload("res://src/hunt/ambience.gd")
const DT := 0.05

var ok: Callable
var h: Hunt


static func run(ok_: Callable) -> void:
	var b = new()
	b.ok = ok_
	b.assets()
	b.go()


func assets() -> void:
	var missing := []
	var names := []
	for z: String in Ambience.SETS:
		var c: Dictionary = Ambience.SETS[z]
		names.append(c["bed"])
		for s: Array in c["shots"]:
			names.append(s[0])
	names.append_array(["swamp_frog", "swamp_crow", "swamp_bubble"])
	for n: String in names:
		if Ambience.variants(n).is_empty() and not ResourceLoader.exists(Ambience.DIR + n + ".ogg"):
			missing.append(n)
	ok.call("ambience: every sound the sets name exists %s" % str(missing), missing.is_empty())
	var bad := []
	for z: String in Ambience.SETS:
		var bed := Ambience._load(str(Ambience.SETS[z]["bed"]))
		if not bed is AudioStreamOggVorbis or bed.get_length() < 8.0:
			bad.append(z)
	ok.call("ambience: each zone's bed is a loopable ogg of at least 8 s %s" % str(bad), bad.is_empty())
	var bytes := 0
	var dir := DirAccess.open(Ambience.DIR)
	for f in dir.get_files():
		if f.ends_with(".ogg"):
			bytes += FileAccess.get_file_as_bytes(Ambience.DIR + f).size()
	ok.call("ambience: the sounds stay small for the phone build (%d KB)" % (bytes / 1024), bytes < 2500 * 1024)
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	var sheet := FileAccess.get_file_as_string("res://src/lobby/lobby_ui_sheets.gd")
	var unlisted := []
	for who in ["LokiF", "Écrivain", "wipics", "EZduzziteh", "zeroisnotnull", "AntumDeluge"]:
		if not credits.contains(who):
			unlisted.append(who)
	ok.call("ambience: every source is credited in CREDITS.md %s" % str(unlisted), unlisted.is_empty())
	ok.call("ambience: the in-game credits name the ambience sources", sheet.contains("ambience") and sheet.contains("LokiF"))
	_models(credits, sheet)
	var decl := false
	for line in FileAccess.get_file_as_string("res://src/hunt/ambience.gd").split("\n"):
		decl = decl or line.begins_with("class_name")
	ok.call("ambience: the module is a plain script (no class_name)", not decl)


## Every critter is a real licensed model: wrapped scene, rigged clip, lit, credited by its author.
func _models(credits: String, sheet: String) -> void:
	var bad := []
	var nameless := []
	var authors := {"hare": "bluekiwi.dog", "owl": "Lilly!", "wolf": "ESO", "frog": "lawtrigg", "crow": "Alexei Ostapenko"}
	var life := {}
	for z: String in Ambience.SETS:
		for k: String in Ambience.SETS[z]["life"]:
			life[k] = true
	for k: String in life:
		if not Ambience.MODELS.has(k):
			if not k in ["bubble", "ring", "dragonfly"]:
				bad.append(k)
			continue
		var ps := load(Ambience.CRIT + str(Ambience.MODELS[k][0]) + ".tscn") as PackedScene
		if ps == null:
			bad.append(k)
			continue
		var m: Node = ps.instantiate()
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null or ap.get_animation_list().is_empty() or m.find_children("*", "MeshInstance3D", true, false).is_empty():
			bad.append(k)
		m.free()
		if not credits.contains(str(authors[k])) or not sheet.contains(str(authors[k])):
			nameless.append(k)
	ok.call("ambience: every critter kind is a rigged model with a clip %s" % str(bad), bad.is_empty())
	ok.call("ambience: each critter's author is in CREDITS.md and the in-game credits %s" % str(nameless), nameless.is_empty())


func go() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	h = Hunt.new()
	tree.root.add_child(h)
	h.phase = "rise"
	h._warming = false
	_zones()
	_caps()
	_flee()
	_sound()
	_gates()
	h.queue_free()


func _park(at := Vector3.ZERO) -> void:
	h.hero.position = at
	h.hero.alive = true


## A fresh set with random spawning off, so a test places exactly what it checks.
func _mk(zone: String) -> RefCounted:
	var a: RefCounted = Ambience.make(h, zone)
	a.cap = 0
	return a


func _step(a: RefCounted, secs: float) -> void:
	for i in int(secs / DT):
		a.step(DT)


func _zones() -> void:
	var extra := []
	for z in DB.ZONE_ORDER:
		var a: RefCounted = Ambience.make(h, z)
		var has: bool = a != null
		if has != (z in ["frost", "swamp"]):
			extra.append(z)
	ok.call("ambience: only Rimehollow and the Cinder Mire have a set %s" % str(extra), extra.is_empty())
	h.zone_id = "barrow"
	Ambience.tick(h, DT)
	ok.call("ambience: another zone's tick builds nothing and is remembered", h.has_meta("ambience") and not h.get_meta("ambience") is RefCounted)
	h.remove_meta("ambience")
	h.zone_id = "frost"
	Ambience.tick(h, DT)
	var a: RefCounted = h.get_meta("ambience", null)
	ok.call("ambience: the first tick builds the frost set once", a != null and a.zone == "frost")
	Ambience.tick(h, DT)
	ok.call("ambience: later ticks reuse it", h.get_meta("ambience") == a)
	a._bed.stop()
	a._bed.queue_free()
	h.remove_meta("ambience")


func _caps() -> void:
	for z in ["frost", "swamp"]:
		_park()
		var a: RefCounted = Ambience.make(h, z)
		var worst := 0
		var kinds := {}
		var out := []
		var meshes := 0
		var colliders := 0
		var over := []
		for i in 1200:
			a.step(DT)
			worst = maxi(worst, a.bits.size())
			for b in a.bits:
				kinds[b.kind] = true
				var p: Vector3 = b.node.position
				if p.x < h.arena.min_x - 3.0 or p.x > h.arena.max_x + 3.0 or p.z < h.arena.min_z - 3.0 or p.z > h.arena.max_z + 3.0:
					out.append(b.kind)
				if b.kind != "ring":  # the fish ring is eight drawn strips, not a model
					meshes = maxi(meshes, b.node.find_children("*", "MeshInstance3D", true, false).size())
				colliders += b.node.find_children("*", "CollisionObject3D", true, false).size()
			for k: String in Ambience.LIMIT:
				if a.count(k) > int(Ambience.LIMIT[k]):
					over.append(k)
		ok.call("ambience %s: never more than %d critters alive (saw %d)" % [z, a.cap, worst], worst <= a.cap and worst > 0)
		ok.call("ambience %s: never more of a kind than its limit %s" % [z, str(over)], over.is_empty())
		ok.call("ambience %s: critters stay in the arena %s" % [z, str(out)], out.is_empty())
		ok.call("ambience %s: a critter is one model (%d meshes at most), none collide" % [z, meshes], meshes <= 7 and colliders == 0)
		ok.call("ambience %s: several kinds turn up in a minute %s" % [z, str(kinds.keys())], kinds.size() >= 2)
		a._bed.stop()
		for b in a.bits:
			b.node.queue_free()
	h.low = true
	var lo: RefCounted = Ambience.make(h, "swamp")
	ok.call("ambience: Low quality keeps two critters at most", lo.cap == 2)
	lo._bed.stop()
	h.low = false


func _far(a: RefCounted, kind: String, at: Vector3) -> RefCounted:
	var b: RefCounted = a.spawn(kind, at)
	_step(a, 0.6)
	return b


func _flee() -> void:
	var a := _mk("frost")
	_park(Vector3(0, 0, 0))
	var hare: RefCounted = _far(a, "hare", Vector3(12, 0, 0))
	ok.call("ambience: a hare far off sits still", hare.st == "idle" and hare.node.position.distance_to(Vector3(12, 0, 0)) < 0.1)
	_park(Vector3(8, 0, 0))
	_step(a, 0.2)
	var start: Vector3 = hare.node.position
	ok.call("ambience: a hare bolts when the hero comes within 6 m", hare.st == "run")
	_step(a, 1.0)
	ok.call("ambience: it runs away from the hero", hare.node.position.distance_to(h.hero.flat_pos()) > start.distance_to(h.hero.flat_pos()) + 4.0)
	_step(a, 3.0)
	ok.call("ambience: and is gone", a.bits.is_empty())

	_park(Vector3(0, 0, 0))
	var owl: RefCounted = _far(a, "owl", Vector3(-12, 0, -2))
	var bird: Node3D = owl.parts["bird"]
	ok.call("ambience: an owl glides high over the hollow", owl.st == "glide" and bird.position.y > 1.8)
	_step(a, 1.0)
	var to_hero: Vector3 = (h.hero.flat_pos() - owl.node.position).normalized()
	var fwd := Vector3(sin(owl.node.rotation.y), 0, cos(owl.node.rotation.y))
	ok.call("ambience: it sails across, not at the hero", absf(fwd.dot(to_hero)) < 0.5)
	_step(a, 8.0)
	ok.call("ambience: and is gone", a.bits.is_empty())

	_park(Vector3(0, 0, 0))
	var wolf: RefCounted = _far(a, "wolf", Vector3(19.8, 0, 0))
	ok.call("ambience: a wolf watches from the ridge edge and faces the hero", wolf.st == "idle" and absf(wolf.node.position.x) > 19.0)
	_step(a, 2.0)
	var face := Vector3(sin(wolf.node.rotation.y), 0, cos(wolf.node.rotation.y))
	ok.call("ambience: it keeps watching at range", wolf.st == "idle" and face.dot((h.hero.flat_pos() - wolf.node.position).normalized()) > 0.7)
	_park(Vector3(16, 0, 0))
	_step(a, 1.0)
	ok.call("ambience: it trots off along the edge, away from the hero", wolf.st == "trot" and wolf.node.position.x > 19.8)
	_step(a, 4.0)
	ok.call("ambience: and is gone", a.bits.is_empty())
	a._bed.stop()

	var s := _mk("swamp")
	_park(Vector3(0, 0, 0))
	var frog: RefCounted = _far(s, "frog", Vector3(10, 0, 0))
	ok.call("ambience: a frog on its plank sits", frog.st == "idle")
	_park(Vector3(7, 0, 0))
	_step(s, 0.3)
	var hopped: bool = frog.st == "hop"
	_step(s, 1.5)
	ok.call("ambience: a frog hops away when the hero is within 4.5 m, then sinks", hopped and frog.node.position.distance_to(h.hero.flat_pos()) > 4.0)
	_step(s, 3.0)
	ok.call("ambience: and is gone", s.bits.is_empty())

	_park(Vector3(0, 0, 0))
	var fly: RefCounted = _far(s, "dragonfly", Vector3(10, 0, 0))
	ok.call("ambience: a dragonfly circles at head height", fly.st == "idle" and fly.node.position.y > 0.8)
	_park(fly.node.position)
	_step(s, 0.3)
	ok.call("ambience: it dashes off when the hero is near", fly.st == "dash")
	_step(s, 2.0)
	ok.call("ambience: and is gone", s.bits.is_empty())

	_park(Vector3(0, 0, 0))
	var crow: RefCounted = _far(s, "crow", Vector3(-12, 0, 0))
	_park(Vector3(-5, 0, 0))
	_step(s, 0.5)
	ok.call("ambience: a crow on its stump flies off when the hero comes near", crow.st == "fly")
	_step(s, 4.0)
	ok.call("ambience: and is gone", s.bits.is_empty())

	_park(Vector3(0, 0, 0))
	var bub: RefCounted = _far(s, "bubble", Vector3(6, 0, 0))
	ok.call("ambience: a methane bubble rises", bub.st == "rise" and (bub.parts["ball"] as Node3D).visible)
	_step(s, 1.2)
	ok.call("ambience: it pops into a small blue flame", bub.st == "pop" and (bub.parts["flame"] as Node3D).visible and not (bub.parts["ball"] as Node3D).visible)
	var hp: float = h.hero.hp
	_step(s, 1.0)
	ok.call("ambience: the flame is gone in a second and never hurts", s.bits.is_empty() and h.hero.hp >= hp)

	var ring: RefCounted = _far(s, "ring", Vector3(5, 0, 5))
	var w0: float = (ring.parts["ring"] as Node3D).scale.x
	_step(s, 1.0)
	ok.call("ambience: a fish ring spreads", (ring.parts["ring"] as Node3D).scale.x > w0 + 1.0)
	_step(s, 1.5)
	ok.call("ambience: and fades", s.bits.is_empty())
	s._bed.stop()


func _sound() -> void:
	var a := _mk("frost")
	ok.call("ambience: the bed is playing, looped, on a bus that exists", a._bed != null and a._bed.playing and (a._bed.stream as AudioStreamOggVorbis).loop and AudioServer.get_bus_index(a._bed.bus) >= 0)
	var quiet: float = a._bed.volume_db
	var was: float = Sfx.intensity
	Sfx.intensity = 0.0
	_step(a, 6.0)
	var calm: float = a._bed.volume_db
	ok.call("ambience: the bed fades in from silence (%.0f to %.0f dB)" % [quiet, calm], quiet <= -39.0 and calm > quiet + 10.0)
	Sfx.intensity = 1.0
	_step(a, 4.0)
	var loud: float = a._bed.volume_db
	Sfx.intensity = was
	ok.call("ambience: a loud fight ducks the bed (%.1f to %.1f dB)" % [calm, loud], loud < calm - 6.0)
	for i in 12:
		a.play("swamp_frog", -9.0, Vector3(5, 0, 5))
	ok.call("ambience: at most %d one-shots at a time (%d)" % [Ambience.VOICES, a._voices], a._voices <= Ambience.VOICES)
	var made := 0
	for c in h.world.get_children():
		if c is AudioStreamPlayer3D:
			made += 1
			c.stop()
			c.queue_free()
	a._voices = 0
	ok.call("ambience: a one-shot is positional (3D)", made >= 1)
	a._bed.stop()


func _gates() -> void:
	var a: RefCounted = Ambience.make(h, "swamp")
	_park()
	h.hero.alive = false
	a._spawn_t = 0.0
	_step(a, 2.0)
	ok.call("ambience: nothing new appears once the hero is down", a.bits.is_empty())
	h.hero.alive = true
	h._ended = true
	_step(a, 2.0)
	ok.call("ambience: nor after the hunt has ended", a.bits.is_empty())
	h._ended = false
	var lacking := []
	for z: String in Ambience.SETS:
		for k: String in Ambience.SETS[z]["life"]:
			if not Ambience.LIMIT.has(k) or not Ambience.MIN_D.has(k):
				lacking.append(k)
	ok.call("ambience: every kind a set can pick has a limit and a minimum distance %s" % str(lacking), lacking.is_empty())
	a._bed.stop()
