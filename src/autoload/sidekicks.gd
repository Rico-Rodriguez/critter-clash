extends RefCounted
## Sidekick rules on the save data: owning, the one active slot, bond kills,
## eggs and unlocks, and the migration from pets and the hero ally. Static
## functions on the save dictionary so tests can drive them directly.
## Preload by path: `const SK := preload("res://src/autoload/sidekicks.gd")`.

const SDB := preload("res://src/data/sidekick_db.gd")
const Care := preload("res://src/core/pet_care.gd")


## The save block. `owned`: {id: {"kills": int}}; `hatchery`: eggs warming,
## [{uid, kind, t0 (unix secs found), kills, seed}]; `eggs`: the old
## {egg_id: {"kills"}} (moved into the hatchery on load); `dry`: {egg_id or
## "exotic": tries without a drop}; `chests`: chests opened (the Mimic's
## goal); `migrated`: pets and ally folded in; `shop`: the egg shop's sold
## offers (egg_shop.gd); `hy_dry`: {"a+b" species pair: litters without its
## hybrid} for the hybrid pity.
static func fresh() -> Dictionary:
	return {"active": "", "owned": {}, "eggs": {}, "hatchery": [], "egg_uid": 1, "dry": {}, "chests": 0, "seen": [], "migrated": false,
		"bred_uid": 1, "rest": {}, "hy_dry": {}, "showcase": [], "shop": {}, "found": {"breeds": [], "elements": [], "patterns": [], "personalities": [], "glow": false, "variants": [], "mutations": [], "parts": []}}


static func block(d: Dictionary) -> Dictionary:
	if not (d.get("sidekicks") is Dictionary):
		d["sidekicks"] = fresh()
	var b: Dictionary = d["sidekicks"]
	for k in fresh():
		if not b.has(k):
			b[k] = fresh()[k]
	# New collection-log lists (nested, so the top-level merge above skips them).
	for k in fresh()["found"]:
		if not (b["found"] as Dictionary).has(k):
			b["found"][k] = fresh()["found"][k]
	# Eggs from before the hatchery keep their kills and start their clock now.
	if not (b["eggs"] as Dictionary).is_empty():
		for eid: String in b["eggs"].keys():
			if SDB.EGGS.has(eid):
				_add_egg(b, eid, int(Time.get_unix_time_from_system()), int(b["eggs"][eid].get("kills", 0)), hash(eid))
		b["eggs"] = {}
	sync(b)
	return b


## Registers every bred individual's def (SDB.BRED) from the save.
static func sync(b: Dictionary) -> void:
	for id: String in b["owned"]:
		var o: Dictionary = b["owned"][id]
		if o.has("breed") and (not SDB.BRED.has(id) or SDB.BRED[id]["genes"] != o["genes"]):
			SDB.BRED[id] = SDB.bred_def(str(o["breed"]), o["genes"])


# --- Eggs and the hatchery ----------------------------------------------------

static func _add_egg(b: Dictionary, kind: String, now: int, k0 := 0, sd := 0) -> Dictionary:
	var e := {"uid": int(b["egg_uid"]), "kind": kind, "t0": now, "kills": k0, "seed": sd}
	b["egg_uid"] = int(b["egg_uid"]) + 1
	b["hatchery"].append(e)
	return e


static func hatchery(d: Dictionary) -> Array:
	return block(d)["hatchery"]


static func has_egg(d: Dictionary, kind: String) -> bool:
	return hatchery(d).any(func(e): return str(e["kind"]) == kind)


static func hatchery_full(d: Dictionary) -> bool:
	return hatchery(d).size() >= SDB.HATCH_SLOTS


## Puts an egg in the hatchery. {} when it is full (the caller pays gems instead).
static func give_egg(d: Dictionary, kind: String, now: int, sd: int) -> Dictionary:
	if not SDB.EGGS.has(kind) or hatchery_full(d):
		return {}
	return _add_egg(block(d), kind, now, 0, sd)


static func find_egg(d: Dictionary, uid: int) -> Dictionary:
	for e: Dictionary in hatchery(d):
		if int(e["uid"]) == uid:
			return e
	return {}


## Seconds of real time an egg has warmed. A clock set backwards counts as none.
static func egg_elapsed(e: Dictionary, now: int) -> int:
	return maxi(now - int(e["t0"]), 0)


## 0..1: whichever of time and kills is further along.
static func egg_frac(e: Dictionary, now: int) -> float:
	var ed: Dictionary = SDB.EGGS[str(e["kind"])]
	return clampf(maxf(float(egg_elapsed(e, now)) / float(ed["secs"]), float(e["kills"]) / float(ed["kills"])), 0.0, 1.0)


static func egg_ready(e: Dictionary, now: int) -> bool:
	return egg_frac(e, now) >= 1.0


## Seconds left by the clock if no more kills come (0 when ready).
static func egg_secs_left(e: Dictionary, now: int) -> int:
	if egg_ready(e, now):
		return 0
	var ed: Dictionary = SDB.EGGS[str(e["kind"])]
	return maxi(int(ed["secs"]) - egg_elapsed(e, now), 0)


## Gems to finish an egg now: one per GEM_SECS of the time left, by the
## faster of the two roads, rounded up (at least one while it isn't ready).
static func rush_cost(e: Dictionary, now: int) -> int:
	if egg_ready(e, now):
		return 0
	var ed: Dictionary = SDB.EGGS[str(e["kind"])]
	var left := (1.0 - egg_frac(e, now)) * float(ed["secs"])
	return maxi(int(ceil(left / float(SDB.GEM_SECS))), 1)


static func gems(d: Dictionary) -> int:
	return int(d.get("gems", 0))


## Spends gems to finish an egg, then hatches it. {} if it can't.
static func rush(d: Dictionary, uid: int, now: int) -> Dictionary:
	var e := find_egg(d, uid)
	if e.is_empty():
		return {}
	var cost := rush_cost(e, now)
	if gems(d) < cost:
		return {}
	d["gems"] = gems(d) - cost
	e["kills"] = int(SDB.EGGS[str(e["kind"])]["kills"])
	return hatch(d, uid, now)


## What an egg hatches into: its species, or a seeded roll from its pool that
## prefers sidekicks you don't own yet. The same egg always gives the same.
static func egg_result(d: Dictionary, e: Dictionary) -> String:
	var ed: Dictionary = SDB.EGGS[str(e["kind"])]
	if e.has("child"):
		return str(e["child"]["breed"])
	if ed.has("hatches"):
		return str(ed["hatches"])
	var pool: Array = ed["pool"]
	var fresh_pool := pool.filter(func(p): return not is_owned(d, str(p[0])))
	var use: Array = fresh_pool if not fresh_pool.is_empty() else pool
	var total := 0
	for p in use:
		total += int(p[1])
	var r := RandomNumberGenerator.new()
	r.seed = int(e["seed"])
	var pick := r.randi_range(0, total - 1)
	for p in use:
		pick -= int(p[1])
		if pick < 0:
			return str(p[0])
	return str(use[0][0])


## Hatches a ready egg: {id, kind, new (first time owned), kills (bond kills
## given when it was a duplicate)}. {} when it isn't ready.
static func hatch(d: Dictionary, uid: int, now: int) -> Dictionary:
	var e := find_egg(d, uid)
	if e.is_empty() or not egg_ready(e, now):
		return {}
	if e.has("child"):
		hatchery(d).erase(e)
		var cid := _add_bred(d, e["child"], e.get("parents", []))
		var cm := str(e["child"]["genes"].get("mutation", ""))
		return {"id": cid, "kind": str(e["kind"]), "new": true, "kills": 0, "breed": str(e["child"]["breed"]), "mutation": cm, "mutation_power": str(SDB.GEN.MUTATIONS.get(cm, {}).get("power", ""))}
	var id := egg_result(d, e)
	hatchery(d).erase(e)
	var out := {"id": id, "kind": str(e["kind"]), "new": false, "kills": 0}
	if own(d, id):
		out["new"] = true
	elif stable_room(d):
		# A species you already have hatches its own individual: a coat, genes
		# and maybe a mutation (seeded by the egg, so reloading can't reroll).
		var child := SDB.roll_wild(id, int(e["seed"]) ^ 0x5eed, mutation_chance(d, str(e["kind"])))
		_note_mutation(d, child["genes"])
		var cid := _add_bred(d, child, [])
		out["id"] = cid
		out["new"] = true
		out["wild"] = true
	else:
		block(d)["owned"][id]["kills"] = kills(d, id) + SDB.DUP_KILLS
		out["kills"] = SDB.DUP_KILLS
	out["breed"] = id if not out.get("wild", false) else str(SDB.def(str(out["id"])).get("breed", id))
	out["mutation"] = str(genes_of(d, str(out["id"])).get("mutation", ""))
	out["mutation_power"] = str(SDB.GEN.MUTATIONS.get(str(out["mutation"]), {}).get("power", ""))
	return out


# --- Breeding ------------------------------------------------------------------

static func genes_of(d: Dictionary, id: String) -> Dictionary:
	var o: Dictionary = block(d)["owned"].get(id, {})
	return o.get("genes", SDB.base_genes())


static func resting(d: Dictionary, id: String, now: int) -> int:
	# Capped at the longest rest, so a clock set far ahead can't strand a pet.
	return clampi(int(block(d)["rest"].get(id, 0)) - now, 0, Care.max_rest())


## Why two sidekicks can't breed now ("" when they can).
static func breed_block(d: Dictionary, a: String, b: String, now: int) -> String:
	if a == b:
		return "Pick two different pets"
	for id in [a, b]:
		if not is_owned(d, id):
			return "Not in your stable"
		if bond(d, id) < SDB.BREED_BOND:
			return "%s needs Bond %d" % [SDB.def(id)["name"], SDB.BREED_BOND]
		if resting(d, id, now) > 0:
			return "%s is resting" % SDB.def(id)["name"]
	if hatchery_full(d):
		return "The hatchery is full"
	if not stable_room(d):
		return "Your stable is full: release a pet to make room"
	if int(d.get("gold", 0)) < SDB.BREED_GOLD:
		return "Needs %d gold" % SDB.BREED_GOLD
	return ""


## Breeds a pair: pays gold, rests both parents, and lays a Nest Egg that
## already holds the child (seeded, so reloading can't reroll it).
static func breed(d: Dictionary, a: String, b: String, now: int, sd: int) -> Dictionary:
	if breed_block(d, a, b, now) != "":
		return {}
	d["gold"] = int(d["gold"]) - SDB.BREED_GOLD
	var bl := block(d)
	# Each parent rests longer than the last time it bred (pet_care.gd).
	bl["rest"][a] = now + Care.note_bred(d, a)
	bl["rest"][b] = now + Care.note_bred(d, b)
	var e := _add_egg(bl, "nest", now, 0, sd)
	var force := hybrid_tries_left(d, a, b) == 1
	e["child"] = SDB.roll_child(a, genes_of(d, a), b, genes_of(d, b), sd, mutation_chance(d, "nest"), force)
	_note_mutation(d, e["child"]["genes"])
	_note_hybrid(d, a, b, str(e["child"]["breed"]))
	e["parents"] = [a, b]
	return e


## The hybrid pity's key for a pair: the two species, sorted.
static func _pair_key(a: String, b: String) -> String:
	var p := [SDB.species(a), SDB.species(b)]
	p.sort()
	return "%s+%s" % p


## Litters until this pair is sure to make its hybrid (1: the next one), or 0
## when the pair has no hybrid or you have already found it.
static func hybrid_tries_left(d: Dictionary, a: String, b: String) -> int:
	var hy := SDB.hybrid_for(SDB.species(a), SDB.species(b))
	if hy == "" or (block(d)["found"]["breeds"] as Array).has(hy):
		return 0
	return maxi(SDB.BREED_HYBRID_PITY - int(block(d)["hy_dry"].get(_pair_key(a, b), 0)), 1)


## Counts a litter toward the pair's hybrid pity: its hybrid clears the count.
static func _note_hybrid(d: Dictionary, a: String, b: String, got: String) -> void:
	var hy := SDB.hybrid_for(SDB.species(a), SDB.species(b))
	if hy == "":
		return
	var dry: Dictionary = block(d)["hy_dry"]
	if got == hy:
		dry.erase(_pair_key(a, b))
	else:
		dry[_pair_key(a, b)] = int(dry.get(_pair_key(a, b), 0)) + 1


## Why a pet can't be released ("" when it can): only bred or hatched
## individuals go, never a species' own pet or the one at your side.
static func release_block(d: Dictionary, id: String) -> String:
	if not is_owned(d, id) or not str(id).begins_with("x"):
		return "Only bred and hatched pets can be released"
	if active(d) == id:
		return "Send it home before releasing it"
	return ""


## You own a pet of this breed: its species pet, or any bred one.
static func owns_species(d: Dictionary, sp: String) -> bool:
	return count_of_species(d, sp) > 0


## How many of this breed you own.
static func count_of_species(d: Dictionary, sp: String) -> int:
	return (block(d)["owned"] as Dictionary).keys().filter(func(i): return SDB.species(str(i)) == sp).size()


## Your best pet of a breed for a pair: ready to breed first, then the most bonded.
static func best_of_species(d: Dictionary, sp: String) -> String:
	var now := int(Time.get_unix_time_from_system())
	var best := ""
	var score := -1
	for id: String in block(d)["owned"]:
		if SDB.species(id) != sp:
			continue
		var sc := kills(d, id) + (1_000_000 if resting(d, id, now) == 0 and bond(d, id) >= SDB.BREED_BOND else 0)
		if sc > score:
			best = id
			score = sc
	return best


## {breed: [mutations]} carried by the pets you own.
static func breed_mutations(d: Dictionary) -> Dictionary:
	var out := {}
	for id: String in block(d)["owned"]:
		var m := str(genes_of(d, id).get("mutation", ""))
		if m == "":
			continue
		var sp := SDB.species(id)
		if not out.has(sp):
			out[sp] = []
		if not (out[sp] as Array).has(m):
			out[sp].append(m)
	return out


## A pet you own of this breed with this mutation, or "".
static func mutated_one(d: Dictionary, sp: String, m: String) -> String:
	for id: String in block(d)["owned"]:
		if SDB.species(id) == sp and str(genes_of(d, id).get("mutation", "")) == m:
			return id
	return ""


## What a pair's next litter can hatch: [[breed, chance], ...], parents first,
## then the hybrid; the chances add up to 1 (SDB.roll_child, plus the pity).
static func litter_odds(d: Dictionary, a: String, b: String) -> Array:
	var sa := SDB.species(a)
	var sb := SDB.species(b)
	if sa == sb:
		return [[sa, 1.0]]
	var hy := SDB.hybrid_for(sa, sb)
	if hy == "":
		return [[sa, 0.5], [sb, 0.5]]
	if hybrid_tries_left(d, a, b) == 1:
		return [[sa, 0.0], [sb, 0.0], [hy, 1.0]]
	var each := (1.0 - SDB.BREED_HYBRID) * 0.5
	return [[sa, each], [sb, each], [hy, SDB.BREED_HYBRID]]


## The chance the pair's next litter carries a mutation: a parent's own
## (MUTATION_INHERIT) or else a fresh one at the nest's chance.
static func litter_mutation_chance(d: Dictionary, a: String, b: String) -> float:
	var p := mutation_chance(d, "nest")
	var held := str(genes_of(d, a).get("mutation", "")) != "" or str(genes_of(d, b).get("mutation", "")) != ""
	return SDB.GEN.MUTATION_INHERIT + (1.0 - SDB.GEN.MUTATION_INHERIT) * p if held else p


## Releases a bred pet for RELEASE_GOLD, freeing its stable room. Returns the
## gold given (0 when it can't go).
static func release(d: Dictionary, id: String) -> int:
	if release_block(d, id) != "":
		return 0
	var b := block(d)
	b["owned"].erase(id)
	b["rest"].erase(id)
	(b["showcase"] as Array).erase(id)
	if b.get("bcount") is Dictionary:
		(b["bcount"] as Dictionary).erase(id)
	SDB.BRED.erase(id)
	d["gold"] = int(d.get("gold", 0)) + SDB.RELEASE_GOLD
	return SDB.RELEASE_GOLD


static func _add_bred(d: Dictionary, child: Dictionary, parents: Array) -> String:
	var b := block(d)
	var id := "x%d" % int(b["bred_uid"])
	b["bred_uid"] = int(b["bred_uid"]) + 1
	b["owned"][id] = {"kills": 0, "breed": str(child["breed"]), "genes": (child["genes"] as Dictionary).duplicate(true), "parents": parents.duplicate()}
	SDB.BRED[id] = SDB.bred_def(str(child["breed"]), child["genes"])
	if str(b["active"]) == "":
		b["active"] = id
	_discover(b, child)
	return id


## The collection log: breeds and traits ever hatched.
static func _discover(b: Dictionary, child: Dictionary) -> void:
	var f: Dictionary = b["found"]
	var g: Dictionary = child["genes"]
	for pair in [["breeds", str(child["breed"])], ["elements", str(g["element"])], ["patterns", str(g["pattern"])], ["personalities", str(g["personality"])]]:
		if str(pair[1]) != "" and not (f[pair[0]] as Array).has(pair[1]):
			f[pair[0]].append(pair[1])
	if bool(g["glow"]):
		f["glow"] = true
	var breed := str(child["breed"])
	var vid := str(g.get("variant", ""))
	if vid != "" and not (f["variants"] as Array).has("%s:%s" % [breed, vid]):
		f["variants"].append("%s:%s" % [breed, vid])
	if str(g.get("mutation", "")) != "" and not (f["mutations"] as Array).has(str(g["mutation"])):
		f["mutations"].append(str(g["mutation"]))
	var body := SDB.body_of(breed)
	for slot: String in SDB.GEN.PART_SLOTS:
		var donor := str((g.get("parts", {}) as Dictionary).get(slot, body))
		if donor != body and SDB.GEN.donates(donor, slot) and not (f["parts"] as Array).has("%s:%s" % [slot, donor]):
			f["parts"].append("%s:%s" % [slot, donor])


# --- Mutations and the collection log -------------------------------------------

## The chance the next rolled pet carries a mutation: the base, times the egg's
## multiplier, plus pity for every roll since the last one; certain at the pity.
static func mutation_chance(d: Dictionary, kind: String) -> float:
	var dry := int(block(d)["dry"].get("mutation", 0))
	if dry + 1 >= SDB.MUTATION_PITY:
		return 1.0
	var mult := float((SDB.EGGS.get(kind, {}) as Dictionary).get("mut", SDB.MUTATION_NEST if kind == "nest" else 1.0))
	return minf(SDB.MUTATION_BASE * mult + SDB.MUTATION_STEP * dry, 1.0)


## Counts a rolled pet toward the mutation pity: a mutation resets it.
static func _note_mutation(d: Dictionary, g: Dictionary) -> void:
	var dry: Dictionary = block(d)["dry"]
	dry["mutation"] = 0 if str(g.get("mutation", "")) != "" else int(dry.get("mutation", 0)) + 1


## Room for another individual in the stable.
static func stable_room(d: Dictionary) -> bool:
	return bred_ids(d).size() < SDB.STABLE_MAX


## The collection log: {section: {"have": n, "total": n}} for breeds, variants,
## mutations and parts, plus {"glow": bool}. Variants count each breed's coats
## (base species owned count as "classic" on their own, so only the coats seen
## on rolled pets are listed in `found`).
static func collection(d: Dictionary) -> Dictionary:
	var f: Dictionary = block(d)["found"]
	var variants_total := 0
	for id: String in SDB.ORDER:
		variants_total += SDB.GEN.variants(id).size()
	variants_total += SDB.BREED_ORDER.size() * SDB.GEN.VARIANTS_HYBRID.size()
	return {
		"breeds": {"have": breeds_found(d).size(), "total": SDB.ORDER.size() + SDB.BREED_ORDER.size()},
		"variants": {"have": (f["variants"] as Array).size(), "total": variants_total},
		"mutations": {"have": (f["mutations"] as Array).size(), "total": SDB.GEN.MUTATION_ORDER.size()},
		"parts": {"have": (f["parts"] as Array).filter(func(e): return SDB.GEN.donates(str(e).split(":")[1], str(e).split(":")[0])).size(), "total": SDB.GEN.donor_parts()},
		"glow": bool(f["glow"]),
	}


## Breeds known: base sidekicks owned plus every breed hatched.
static func breeds_found(d: Dictionary) -> Array:
	var out := []
	for id: String in SDB.ORDER:
		if is_owned(d, id):
			out.append(id)
	for k: String in block(d)["found"]["breeds"]:
		if not out.has(k):
			out.append(k)
	return out


## Bred individuals you own, oldest first.
static func bred_ids(d: Dictionary) -> Array:
	var out := (block(d)["owned"] as Dictionary).keys().filter(func(i): return str(i).begins_with("x"))
	out.sort_custom(func(x, y): return int(str(x).substr(1)) < int(str(y).substr(1)))
	return out


# --- The showcase ----------------------------------------------------------------

## Owned sidekicks, rarest first, then the most bonded.
static func by_rarity(d: Dictionary) -> Array:
	var ids: Array = []
	for id: String in block(d)["owned"]:
		if SDB.exists(id):
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra := SDB.rarity(a)
		var rb := SDB.rarity(b)
		if ra != rb:
			return ra > rb
		var ka := kills(d, a)
		var kb := kills(d, b)
		return ka > kb if ka != kb else a < b)
	return ids


## What the showcase shows: the ones you pinned, then your rarest to fill it.
static func showcase(d: Dictionary) -> Array:
	var out: Array = []
	for id in block(d)["showcase"]:
		if is_owned(d, str(id)) and not str(id) in out:
			out.append(str(id))
	for id: String in by_rarity(d):
		if out.size() >= SDB.SHOWCASE_SLOTS:
			break
		if not id in out:
			out.append(id)
	return out.slice(0, SDB.SHOWCASE_SLOTS)


static func is_pinned(d: Dictionary, id: String) -> bool:
	return id in block(d)["showcase"]


## Pins a sidekick to the showcase (or unpins it). False when it's not yours or the case is full.
static func pin(d: Dictionary, id: String) -> bool:
	var pins: Array = block(d)["showcase"]
	if id in pins:
		pins.erase(id)
		return true
	if not is_owned(d, id) or pins.size() >= SDB.SHOWCASE_SLOTS:
		return false
	pins.append(id)
	return true


## Hatches every ready egg. Returns the hatch results.
static func hatch_ready(d: Dictionary, now: int) -> Array:
	var out := []
	for e: Dictionary in hatchery(d).duplicate():
		if egg_ready(e, now):
			out.append(hatch(d, int(e["uid"]), now))
	return out


## The odds of an exotic egg from the next boss (or elite), given the bosses
## already felled this hunt without one. 1.0 at the pity.
static func exotic_chance(d: Dictionary, boss: bool, bosses_this_hunt: int) -> float:
	if hatchery_full(d):
		return 0.0
	if boss and int(block(d)["dry"].get("exotic", 0)) + bosses_this_hunt + 1 >= SDB.EXOTIC_PITY:
		return 1.0
	var lucky := 2.0 if str(SDB.def(active(d)).get("perk", "")) == "lucky" else 1.0
	return (SDB.EXOTIC_BOSS if boss else SDB.EXOTIC_ELITE) * lucky


## Gives a reward egg (the Trophy Road, the season pass, events, the story, a
## chest). A full hatchery pays FULL_EGG_GEMS gems instead, so a reward is never
## lost. Returns {egg, uid (0 when none was laid), gems}.
static func award_egg(d: Dictionary, kind: String, now: int, sd: int) -> Dictionary:
	var e := give_egg(d, kind, now, sd)
	if not e.is_empty():
		return {"egg": kind, "uid": int(e["uid"]), "gems": 0}
	d["gems"] = gems(d) + SDB.FULL_EGG_GEMS
	return {"egg": kind, "uid": 0, "gems": SDB.FULL_EGG_GEMS}


## A chest's egg and gems, already given: [{type: "gems"|"egg", ...}].
static func chest_extras(d: Dictionary, kind: String, now: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	var g := int(SDB.CHEST_GEMS.get(kind, 0))
	if g > 0:
		d["gems"] = gems(d) + g
		out.append({"type": "gems", "amount": g})
	var roll := rng.randf()
	var acc := 0.0
	for pair: Array in SDB.CHEST_EGGS.get(kind, []):
		acc += float(pair[1])
		if roll < acc:
			var e := give_egg(d, str(pair[0]), now, rng.randi())
			if not e.is_empty():
				out.append({"type": "egg", "egg": str(pair[0])})
			break
	return out


## Pets and the hero ally from before sidekicks, folded in once (safe to run
## on every load: the `migrated` flag stops a second pass, so no save version
## is needed). Boss pets become sidekicks, the followed pet is the one at your
## side, and the hero ally is gone (co-op partners are unaffected).
static func migrate(d: Dictionary) -> void:
	var b := block(d)
	if bool(b["migrated"]):
		return
	var pets: Array = d.get("pets", []) if d.get("pets") is Array else []
	for pid in pets:
		var sid := str(SDB.PET_TO_SIDEKICK.get(str(pid), ""))
		if sid != "":
			own(d, sid)
	var followed := str(SDB.PET_TO_SIDEKICK.get(str(d.get("pet", "")), ""))
	if followed != "" and is_owned(d, followed):
		b["active"] = followed
	d["ally"] = ""
	check_unlocks(d)
	b["migrated"] = true


static func is_owned(d: Dictionary, id: String) -> bool:
	return block(d)["owned"].has(id)


## Adds a sidekick. The first one owned goes straight to your side.
static func own(d: Dictionary, id: String) -> bool:
	if not SDB.exists(id) or is_owned(d, id):
		return false
	var b := block(d)
	b["owned"][id] = {"kills": 0}
	if str(b["active"]) == "":
		b["active"] = id
	return true


static func active(d: Dictionary) -> String:
	var a := str(block(d)["active"])
	return a if is_owned(d, a) else ""


## "" sends the sidekick home (no one at your side).
static func set_active(d: Dictionary, id: String) -> bool:
	if id != "" and not is_owned(d, id):
		return false
	block(d)["active"] = id
	return true


static func kills(d: Dictionary, id: String) -> int:
	if not is_owned(d, id):
		return 0
	return int(block(d)["owned"][id].get("kills", 0))


static func bond(d: Dictionary, id: String) -> int:
	return SDB.bond_level(kills(d, id))


static func stage(d: Dictionary, id: String) -> int:
	return SDB.stage_of(bond(d, id))


static func evolved(d: Dictionary, id: String) -> bool:
	return bond(d, id) >= SDB.BOND_EVOLVE


## Unlocks by plain goals (boss kills, trophies, chests). Returns ids gained.
static func check_unlocks(d: Dictionary) -> Array:
	var out := []
	var b := block(d)
	var st: Dictionary = d.get("stats", {})
	for id: String in SDB.ORDER:
		if is_owned(d, id):
			continue
		var u: Dictionary = SDB.ROSTER[id]["unlock"]
		var got := false
		match str(u["kind"]):
			"boss_kills":
				got = int(st.get("boss_kills", 0)) >= int(u["n"])
			"renown":
				got = int(d.get("renown", 0)) >= int(u["n"])
			"chests":
				got = int(b["chests"]) >= int(u["n"])
			"pet":
				got = (d.get("pets", []) as Array).has(str(u["unique"])) if d.get("pets") is Array else false
		if got and own(d, id):
			out.append(id)
	return out


## A chest was opened: counts toward the Gilded Mimic.
static func note_chest(d: Dictionary) -> Array:
	var b := block(d)
	b["chests"] = int(b["chests"]) + 1
	return check_unlocks(d)


## Progress toward a locked sidekick, for the sheet: [text, fill 0..1].
static func progress(d: Dictionary, id: String) -> Array:
	var u: Dictionary = SDB.ROSTER[id]["unlock"]
	var b := block(d)
	var st: Dictionary = d.get("stats", {})
	match str(u["kind"]):
		"boss_kills":
			return ["Slay a boss", clampf(float(st.get("boss_kills", 0)) / float(u["n"]), 0.0, 1.0)]
		"renown":
			return ["Trophy Road %s / %s" % [int(d.get("renown", 0)), int(u["n"])], clampf(float(d.get("renown", 0)) / float(u["n"]), 0.0, 1.0)]
		"chests":
			return ["Open chests %d / %d" % [int(b["chests"]), int(u["n"])], clampf(float(b["chests"]) / float(u["n"]), 0.0, 1.0)]
		"pet":
			return [str(SDB.ROSTER[id]["how"]), 0.0]
		"egg":
			var eid := str(u["egg"])
			var e: Dictionary = SDB.EGGS[eid]
			for he: Dictionary in b["hatchery"]:
				if str(he["kind"]) == eid:
					return ["%s in the hatchery" % e["name"], egg_frac(he, int(Time.get_unix_time_from_system()))]
			return [str(SDB.ROSTER[id]["how"]), 0.0]
	return ["", 0.0]


## A hidden sidekick shows as ??? until its egg is found.
static func hidden(d: Dictionary, id: String) -> bool:
	if not SDB.ROSTER.has(id) or not bool(SDB.ROSTER[id].get("hidden", false)) or is_owned(d, id):
		return false
	var u: Dictionary = SDB.ROSTER[id]["unlock"]
	return not (str(u.get("kind", "")) == "egg" and has_egg(d, str(u["egg"])))


## Applies a finished hunt: bond kills to the sidekick at your side, warmth to
## held eggs (hatching any that are ready), egg drops, and goal unlocks.
## Returns {id, kills, bond_from, bond_to, evolved, egg, hatched [], unlocked []}.
static func after_hunt(d: Dictionary, r: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := block(d)
	var out := {"id": "", "kills": 0, "bond_from": 0, "bond_to": 0, "evolved": false, "stage_from": 0, "stage_to": 0, "egg": "", "hatched": [], "unlocked": []}
	var k := maxi(int(r.get("kills", 0)), 0)
	var a := active(d)
	if a != "" and k > 0:
		var before := bond(d, a)
		var gain := int(round(k * (1.25 if str(SDB.def(a).get("perk", "")) == "loyal" else 1.0)))
		b["owned"][a]["kills"] = kills(d, a) + gain
		out["id"] = a
		out["kills"] = gain
		out["bond_from"] = before
		out["bond_to"] = bond(d, a)
		out["stage_from"] = SDB.stage_of(before)
		out["stage_to"] = SDB.stage_of(int(out["bond_to"]))
		out["evolved"] = before < SDB.BOND_EVOLVE and int(out["bond_to"]) >= SDB.BOND_EVOLVE
	# Eggs warm with every kill; ready ones hatch.
	var now := int(r.get("now", Time.get_unix_time_from_system()))
	for e: Dictionary in b["hatchery"]:
		e["kills"] = int(e["kills"]) + k
	# Exotic eggs found in the hunt (rolled there, with the pity counted here).
	var ex := int(r.get("exotic", 0))
	var nb := (r.get("bosses", []) as Array).size()
	b["dry"]["exotic"] = 0 if ex > 0 else int(b["dry"].get("exotic", 0)) + nb
	for i in ex:
		if not give_egg(d, "exotic", now, rng.randi()).is_empty():
			out["exotic"] = int(out.get("exotic", 0)) + 1
	# Species egg drops on a win (or a boss felled in the Descent).
	if r.get("win", false) or nb > 0:
		for eid: String in SDB.EGGS:
			var e: Dictionary = SDB.EGGS[eid]
			if not e.has("hatches") or not e.has("chance"):
				continue
			if is_owned(d, str(e["hatches"])) or has_egg(d, eid) or hatchery_full(d):
				continue
			var eligible := false
			if e.has("boss"):
				eligible = (r.get("bosses", []) as Array).has(str(e["boss"]))
			elif e.has("zone"):
				eligible = r.get("win", false) and str(r.get("zone", "")) == str(e["zone"])
			if not eligible:
				continue
			var dry := int(b["dry"].get(eid, 0))
			if dry + 1 >= int(e["pity"]) or rng.randf() < float(e["chance"]):
				give_egg(d, eid, now, rng.randi())
				b["dry"][eid] = 0
				out["egg"] = eid
			else:
				b["dry"][eid] = dry + 1
	for h: Dictionary in hatch_ready(d, now):
		out["hatched"].append(str(h["id"]))
	out["unlocked"] = check_unlocks(d)
	return out
