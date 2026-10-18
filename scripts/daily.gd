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

## A daily can be played on a biome the player has not unlocked yet ("daily
## access"): a sealed biome is open just for the day, and never unlocks the
## biome, grants clear credit or counts toward progress. When the day's biome
## is above the player's progress we hand out a mild "Daily pass" so the taste
## of a later biome is fair. The Daily row flags it.
const PASS_HP_MUL := 1.15


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


## Every biome rides the daily rotation, sealed or not, so all players share
## one map on a given day. The rotation is a fixed cycle over Catalog.BIOMES
## keyed by the UTC day number: it visits every biome and never lands on the
## same one two days in a row (with two or more biomes).
static func biome_for(key: String) -> String:
	var count := Catalog.BIOMES.size()
	if count <= 0:
		return "meadow"
	return str(Catalog.BIOMES[int(posmod(_day_number(key), count))]["id"])


## Days since the Unix epoch for a "YYYY-MM-DD" key. Pure calendar math, so it
## stays stable across machines and cannot drift with the engine's hash.
static func _day_number(key: String) -> int:
	var parts := key.split("-")
	if parts.size() != 3:
		return 0
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
	})
	return int(unix) / 86400


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
