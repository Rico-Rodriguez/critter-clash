class_name Session
extends RefCounted

## A hunt request. RunSim consumes this and never touches the scene tree.
## Launch UI only builds solo hunts.
## Co-op: two hero ids, both on team 0, two move vectors.
## Duels: the second hero is placed on a rival team. A future DuelAi
## (RunBot.steer) supplies that hero's move. Clans are not simulated;
## the save keeps clan_id for a later roster.

enum Mode { SOLO, COOP, DUEL }

var mode: int = Mode.SOLO
var biome_id: String = "meadow"
## The network id of the peer this session belongs to. Empty in solo play;
## a multiplayer session carries the id the server assigned (see
## MULTIPLAYER_NOTES.md).
var network_id: String = ""
var hero_ids: PackedStringArray = PackedStringArray()
var seed: int = 0
## Set only for a Daily Challenge run: the UTC day key and its modifiers.
var daily_key: String = ""
var modifiers: Array = []


static func solo(biome_id: String, hero_id: String) -> Session:
	var session := Session.new()
	session.mode = Mode.SOLO
	session.biome_id = biome_id
	session.hero_ids = PackedStringArray([hero_id])
	session.seed = randi()
	return session


## The seeded Daily Challenge for a Unix time: one biome, one seed and one
## or two run modifiers, all derived from the UTC day key.
static func daily(hero_id: String, unix: int) -> Session:
	var key := Daily.today_key(unix)
	var session := Session.new()
	session.mode = Mode.SOLO
	session.biome_id = Daily.biome_for(key)
	session.hero_ids = PackedStringArray([hero_id])
	session.seed = Daily.seed_for(key)
	session.daily_key = key
	session.modifiers = Daily.modifiers_for(key)
	return session


static func coop(biome_id: String, hero_a: String, hero_b: String) -> Session:
	var session := Session.new()
	session.mode = Mode.COOP
	session.biome_id = biome_id
	session.hero_ids = PackedStringArray([hero_a, hero_b])
	session.seed = randi()
	return session


static func duel(biome_id: String, hero_a: String, hero_b: String) -> Session:
	var session := Session.new()
	session.mode = Mode.DUEL
	session.biome_id = biome_id
	session.hero_ids = PackedStringArray([hero_a, hero_b])
	session.seed = randi()
	return session
