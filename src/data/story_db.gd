extends RefCounted
## The story campaign: five chapters, one per hero, each in a zone and ending
## on that zone's boss in a story form. Played on Normal with whichever hero
## you pick (the chapter's own hero earns a bonus). Short in-engine cutscenes
## open and close each chapter.
##
## Beats: {who: "hero" | "boss" | "narrator", line, cam: "wide" | "hero" | "boss"}.
## "hero" speaks as the chapter's hero (the player's own hero in the 3D scene).
## `boss` is the zone boss it builds on; `over` re-skins it for the chapter
## (name, title, lines, color, hp_mult, scale_mult). No class_name: preload it.

const CHAPTERS := [
	{
		"id": "oath", "title": "The Oath Breaks", "hero": "knight", "zone": "barrow", "boss": "gravemaw",
		"blurb": "The Barrow King wakes. The Oathsworn kept the watch, and failed it.",
		"over": {"name": "Gravemaw", "title": "the Oathbreaker", "color": Color(0.5, 0.9, 0.85), "hp_mult": 1.0, "scale_mult": 1.05,
			"wake": "the Oathbreaker wakes", "fall": "The Oathbreaker falls. The watch is kept.", "enrage_line": "\"You swore. So did I.\""},
		"intro": [
			{"who": "narrator", "line": "Gravelight Barrow. Forty winters the Oathsworn kept the watch.", "cam": "wide"},
			{"who": "hero", "line": "The lamps are out. Every grave in the row stands open.", "cam": "hero"},
			{"who": "boss", "line": "You swore to keep me beneath. I swore to rise. Which oath is older?", "cam": "boss"},
			{"who": "hero", "line": "Mine is the one I still keep.", "cam": "hero"},
		],
		"outro": [
			{"who": "narrator", "line": "The King sinks into the loam, and the lamps catch one by one.", "cam": "wide"},
			{"who": "hero", "line": "The watch holds. But something stirs in the roots to the east.", "cam": "hero"},
		],
		"reward": {"gold": 1500, "gems": 20, "shards": 30},
	},
	{
		"id": "roots", "title": "Arrows in the Roots", "hero": "ranger", "zone": "grove", "boss": "thorn",
		"blurb": "The Hollow Grove has gone quiet. Its Mother has begun to feed.",
		"over": {"name": "The Thornmother", "title": "Rootbound", "color": Color(0.75, 0.95, 0.3), "hp_mult": 1.1, "scale_mult": 1.05,
			"wake": "the Rootbound Mother uncurls", "fall": "The Rootbound Mother withers. The Grove breathes.", "enrage_line": "\"Every tree is a hand. Every hand is hungry.\""},
		"intro": [
			{"who": "narrator", "line": "The Hollow Grove. Autumn here has not ended in a hundred years.", "cam": "wide"},
			{"who": "hero", "line": "No birds. The cult tends something below the roots.", "cam": "hero"},
			{"who": "boss", "line": "Little warden. Your arrows are only twigs that forgot they were trees.", "cam": "boss"},
			{"who": "hero", "line": "Then I will remind them what they are for.", "cam": "hero"},
		],
		"outro": [
			{"who": "narrator", "line": "The roots let go. Somewhere deep, a bell rings under the stone.", "cam": "wide"},
			{"who": "hero", "line": "That bell is from the crypt. Someone is calling the dead by name.", "cam": "hero"},
		],
		"reward": {"gold": 1800, "gems": 25, "shards": 35},
	},
	{
		"id": "crypt", "title": "Ember and Hex", "hero": "mage", "zone": "depths", "boss": "hexer",
		"blurb": "A queen of the Sunken Crypt unpicks the dead and sews them back as soldiers.",
		"over": {"name": "The Hexer Queen", "title": "Ashen Weaver", "color": Color(0.85, 0.5, 1.0), "hp_mult": 1.15, "scale_mult": 1.08,
			"wake": "the Ashen Weaver rises", "fall": "The Ashen Weaver unravels. The crypt goes dark.", "enrage_line": "\"I will unpick you, thread by burning thread.\""},
		"intro": [
			{"who": "narrator", "line": "The Sunken Crypt. Torchlight, and the sound of thread being pulled.", "cam": "wide"},
			{"who": "hero", "line": "Her cult is stitching the fallen into soldiers. That is my fire's business.", "cam": "hero"},
			{"who": "boss", "line": "A witch of embers. Come, I have never worn a flame.", "cam": "boss"},
			{"who": "hero", "line": "Then be warm.", "cam": "hero"},
		],
		"outro": [
			{"who": "narrator", "line": "The threads burn back to the needle. A key falls, gold and heavy.", "cam": "wide"},
			{"who": "hero", "line": "The King's treasury. Whoever opened it left a trail of coins.", "cam": "hero"},
		],
		"reward": {"gold": 2100, "gems": 30, "shards": 40},
	},
	{
		"id": "vault", "title": "Knives in the Dark", "hero": "rogue", "zone": "vault", "boss": "warden",
		"blurb": "The Gilded Vault has a keeper, and the keeper has never lost a coin.",
		"over": {"name": "The Gilded Warden", "title": "Keeper of Every Coin", "color": Color(1.0, 0.88, 0.45), "hp_mult": 1.2, "scale_mult": 1.05,
			"wake": "the Keeper turns the key", "fall": "The Keeper kneels. Every coin is yours.", "enrage_line": "\"Nothing leaves. Nothing, nothing, nothing.\""},
		"intro": [
			{"who": "narrator", "line": "The Gilded Vault. A king's whole fortune, and one door that opens inward.", "cam": "wide"},
			{"who": "hero", "line": "Quiet halls, loud gold. I like both.", "cam": "hero"},
			{"who": "boss", "line": "Thief. I count your steps. I count your breaths. I will count your bones.", "cam": "boss"},
			{"who": "hero", "line": "Count fast.", "cam": "hero"},
		],
		"outro": [
			{"who": "narrator", "line": "The door opens outward, for the first time in a thousand years.", "cam": "wide"},
			{"who": "hero", "line": "The treasury was only the lid. The King himself is rising again.", "cam": "hero"},
		],
		"reward": {"gold": 2500, "gems": 35, "shards": 45},
	},
	{
		"id": "lightless", "title": "The Lightless King", "hero": "barbarian", "zone": "barrow", "boss": "gravemaw",
		"blurb": "The last light of Gravelight burns low. The King has come back with nothing left to lose.",
		"over": {"name": "Gravemaw", "title": "the Lightless King", "color": Color(1.0, 0.4, 0.3), "hp_mult": 1.6, "scale_mult": 1.3,
			"wake": "the Lightless King wakes", "fall": "The Lightless King falls. The lamps stay lit.", "enrage_line": "\"Put out the light. Put it out.\""},
		"intro": [
			{"who": "narrator", "line": "Gravelight Barrow, the last night. Every lamp in the row gutters.", "cam": "wide"},
			{"who": "hero", "line": "He is bigger than before. Good. I was getting bored.", "cam": "hero"},
			{"who": "boss", "line": "You carried my crypt, my grove, my vault. Now carry my dark.", "cam": "boss"},
			{"who": "hero", "line": "I carry axes. Come and be carried.", "cam": "hero"},
		],
		"outro": [
			{"who": "narrator", "line": "The dark lifts off the Barrow like a lid. The lamps hold.", "cam": "wide"},
			{"who": "hero", "line": "Quiet at last. Somebody tell the lamplighters they are out of work.", "cam": "hero"},
		],
		"reward": {"gold": 4000, "gems": 60, "shards": 80, "glow": "wraith"},
	},
]


static func count() -> int:
	return CHAPTERS.size()


static func chapter(id: String) -> Dictionary:
	for c in CHAPTERS:
		if str(c["id"]) == id:
			return c
	return {}


static func index(id: String) -> int:
	for i in CHAPTERS.size():
		if str(CHAPTERS[i]["id"]) == id:
			return i
	return -1


## A zone boss's definition as the chapter retells it: name, lines, color,
## and the hp / size multipliers. Other bosses pass through unchanged.
static func boss_def(base: Dictionary, boss_id: String, ch: Dictionary) -> Dictionary:
	if ch.is_empty() or str(ch["boss"]) != boss_id:
		return base
	var d := base.duplicate()
	var over: Dictionary = ch["over"]
	for k in ["name", "title", "wake", "fall", "enrage_line", "color"]:
		if over.has(k):
			d[k] = over[k]
	d["hp"] = float(base["hp"]) * float(over.get("hp_mult", 1.0))
	d["scale"] = float(base["scale"]) * float(over.get("scale_mult", 1.0))
	return d
