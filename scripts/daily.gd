class_name Daily
extends RefCounted

## Seeded Daily Challenge: one deterministic hunt per UTC day, a couple of
## named run modifiers, and the local score. Everything derives from the
## date key, so every player on the same day gets the same map and quirks.

## Simple named run modifiers. RunSim reads the id from Session.modifiers.
const MODIFIERS: Array = [
	{"id": "swarming", "name": "Swarming", "desc": "+30% camp size"},
	{"id": "glass", "name": "Glass", "desc": "heroes +25% damage, -25% health"},
	{"id": "hasty", "name": "Hasty Foes", "desc": "+20% foe speed"},
]


## "YYYY-MM-DD" for the given Unix time, in UTC.
static func today_key(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## Stable positive seed for a key. FNV-1a written out here so it cannot
## drift with the engine's String.hash() across versions.
static func seed_for(key: String) -> int:
	var h := 0x811c9dc5
	for b in key.to_utf8_buffer():
		h = (h ^ int(b)) & 0xFFFFFFFF
		h = (h * 0x01000193) & 0xFFFFFFFF
	var out := h & 0x7FFFFFFF
	return out if out != 0 else 1


## Rotates over the biomes that are open by default (no gate, no prereq).
static func biome_for(key: String) -> String:
	var open: Array = []
	for entry in Catalog.BIOMES:
		if int(entry.get("gate", 0)) == 0 and str(entry.get("need", "")) == "":
			open.append(str(entry["id"]))
	if open.is_empty():
		open.append("meadow")
	return str(open[seed_for(key) % open.size()])


## One or two modifiers, chosen deterministically from the key.
static func modifiers_for(key: String) -> Array:
	var h := seed_for(key)
	var start := h % MODIFIERS.size()
	var count := 1 + int((h >> 5) % 2)
	var out: Array = []
	for i in count:
		out.append(MODIFIERS[(start + i) % MODIFIERS.size()])
	return out


## Local daily score, documented so the local board is easy to reason about:
##   win bonus ...... 5000 (a clear always beats a failed attempt)
##   time bonus ..... up to 1500 on a clear; faster is more, capped at 300 s
##   kills .......... 50 each
##   level .......... 200 per run level
##   health left .... up to 1000, scaled by hp / max_hp
## A loss still scores on kills/level/health, so the board can rank tries.
static func score(result: Dictionary) -> int:
	var total := 0
	if bool(result.get("win", false)):
		total += 5000
		total += int(round(maxf(0.0, 300.0 - float(result.get("time", 300.0))) * 5.0))
	total += int(result.get("kills", 0)) * 50
	total += int(result.get("level", 1)) * 200
	var hp := maxf(0.0, float(result.get("hp", 0.0)))
	var max_hp := maxf(1.0, float(result.get("max_hp", 1.0)))
	total += int(round(clampf(hp / max_hp, 0.0, 1.0) * 1000.0))
	return maxi(0, total)
