extends RefCounted
## What you do for a pet that isn't a stat: its name, and how often it may
## breed. Static functions on the save dictionary, so tests can drive them.
## No class_name (see CLAUDE.md): `const Care := preload("res://src/core/pet_care.gd")`.
##
## Save keys live inside the sidekicks block and are added lazily, so an old
## save loads untouched: `bcount` {pet id: times it has bred} and, on a pet's
## own entry, `name` (its nickname).

## How long a pet rests after breeding, by how many times it had bred before:
## the first litter 8 h, then 12, 18, 24, 36, and 48 h from then on.
const REST_HOURS := [8, 12, 18, 24, 36, 48]

const NAME_MIN := 2
const NAME_MAX := 14

## Whole words that are blocked on their own (too short to block inside a word:
## "Peacock" and "Cucumber" are fine).
const BAN_WORDS := ["ass", "cum", "cock", "dick", "anus", "rape", "tit", "tits", "sex", "piss", "fag", "hoe", "nazi", "spic", "boob", "boobs", "pedo", "cuck"]
## Blocked anywhere in the name, even spaced out or spelled with digits.
const BAN_ANY := ["fuck", "shit", "cunt", "bitch", "nigg", "faggot", "whore", "slut", "penis", "vagina", "asshole", "bastard", "twat", "wank",
		"porn", "kike", "chink", "retard", "dildo", "hitler", "rapist", "molest", "jizz", "blowjob"]
const LEET := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s", "!": "i", "+": "t"}


# --- Breeding rest ---------------------------------------------------------------

static func _counts(d: Dictionary) -> Dictionary:
	if not (d.get("sidekicks") is Dictionary):
		return {}
	var b: Dictionary = d["sidekicks"]
	if not (b.get("bcount") is Dictionary):
		b["bcount"] = {}
	return b["bcount"]


## Times this pet has bred.
static func bred_times(d: Dictionary, id: String) -> int:
	return int(_counts(d).get(id, 0))


## Seconds a pet rests after a litter, when it had bred `times` before.
static func rest_secs(times: int) -> int:
	return int(REST_HOURS[clampi(times, 0, REST_HOURS.size() - 1)]) * 3600


## The rest this pet's next litter will cost it.
static func next_rest(d: Dictionary, id: String) -> int:
	return rest_secs(bred_times(d, id))


static func max_rest() -> int:
	return rest_secs(REST_HOURS.size())


## Counts a litter and returns the rest earned.
static func note_bred(d: Dictionary, id: String) -> int:
	var secs := next_rest(d, id)
	_counts(d)[id] = bred_times(d, id) + 1
	return secs


## True when the pet is already on the longest rest there is.
static func at_cap(d: Dictionary, id: String) -> bool:
	return bred_times(d, id) >= REST_HOURS.size() - 1


## "8h", "36h": a rest in whole hours for the UI.
static func hours_text(secs: int) -> String:
	return "%dh" % int(ceil(float(secs) / 3600.0))


# --- Names -----------------------------------------------------------------------

## The name a pet answers to: its nickname, else `fallback` (its breed name).
static func shown_name(d: Dictionary, id: String, fallback: String) -> String:
	var nick := nickname(d, id)
	return nick if nick != "" else fallback


static func nickname(d: Dictionary, id: String) -> String:
	if not (d.get("sidekicks") is Dictionary):
		return ""
	var o: Dictionary = (d["sidekicks"].get("owned", {}) as Dictionary).get(id, {})
	return str(o.get("name", ""))


## Cleans a typed name (trims, one space between words) and says if it will do.
## {ok, name, err}. An empty name is fine: it clears the nickname.
static func check_name(raw: String) -> Dictionary:
	var n := " ".join(raw.strip_edges().split(" ", false))
	if n == "":
		return {"ok": true, "name": "", "err": ""}
	if n.length() < NAME_MIN:
		return {"ok": false, "name": n, "err": "At least %d letters" % NAME_MIN}
	if n.length() > NAME_MAX:
		return {"ok": false, "name": n, "err": "At most %d characters" % NAME_MAX}
	for i in n.length():
		var c := n.unicode_at(i)
		var fine := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 32 or c == 39 or c == 45 or c == 46 or (c >= 0xC0 and c <= 0x24F and c != 0xD7 and c != 0xF7)
		if not fine:
			return {"ok": false, "name": n, "err": "Letters, numbers, spaces, ' - . only"}
	var c0 := n.unicode_at(0)
	if c0 < 48 or (c0 > 57 and c0 < 65) or (c0 > 90 and c0 < 97) or (c0 > 122 and c0 < 0xC0):
		return {"ok": false, "name": n, "err": "Start with a letter or number"}
	if is_rude(n):
		return {"ok": false, "name": n, "err": "That name isn't allowed"}
	return {"ok": true, "name": n, "err": ""}


## A small filter, not a perfect one: strong words anywhere (even spaced out or
## written with digits), short ones only as whole words.
static func is_rude(text: String) -> bool:
	var low := text.to_lower()
	var plain := ""
	for i in low.length():
		var ch := low.substr(i, 1)
		plain += str(LEET.get(ch, ch))
	var letters := ""
	for i in plain.length():
		var cu := plain.unicode_at(i)
		if cu >= 97 and cu <= 122:
			letters += plain.substr(i, 1)
	for w: String in BAN_ANY:
		if letters.contains(w):
			return true
	var words := PackedStringArray()
	var cur := ""
	for i in plain.length():
		var cu2 := plain.unicode_at(i)
		if cu2 >= 97 and cu2 <= 122:
			cur += plain.substr(i, 1)
		elif cur != "":
			words.append(cur)
			cur = ""
	if cur != "":
		words.append(cur)
	for w in words:
		if BAN_WORDS.has(w):
			return true
	return false


## Names a pet. False (and nothing changes) when the name fails `check_name` or
## the pet isn't yours. An empty name clears it.
static func set_name(d: Dictionary, id: String, raw: String) -> bool:
	var r := check_name(raw)
	if not bool(r["ok"]) or not (d.get("sidekicks") is Dictionary):
		return false
	var owned: Dictionary = d["sidekicks"].get("owned", {})
	if not owned.has(id):
		return false
	if str(r["name"]) == "":
		(owned[id] as Dictionary).erase("name")
	else:
		(owned[id] as Dictionary)["name"] = str(r["name"])
	return true
