class_name Roster
extends RefCounted

## Critter stats, costs, and the two habitat branches each baby can become.

const ORDER := ["ember", "pebble", "juniper", "bramble", "lumen", "pip"]
const MAX_SPARKS := 10.0
const START_SPARKS := 6.0
const SPARK_REGEN := 0.92
const MATCH_SECONDS := 180.0
const DUSK_RUSH_AT := 30.0
const MERGE_RADIUS := 1.2

const DATA := {
	"ember": {
		"name": "Ember",
		"role": "Splash",
		"cost": 4,
		"gait": "waddle",
		"card": Color(0.949, 0.490, 0.227),
		"blurb": "A pocket dragon who sneezes sparks and takes it personally.",
		"branches": ["lava", "water"],
		"base": {
			"name": "Ember",
			"blurb": "Splash breath with a short reach. Merge a twin to pick a drake.",
			"hp": 430, "dmg": 66, "period": 1.18, "range": 3.15, "speed": 2.2,
			"radius": 0.42, "sight": 5.8, "splash": 1.5, "hits_air": true, "projectile": true,
		},
		"lava": {
			"name": "Blaze Drake",
			"blurb": "Lava merge. The breath rolls wider and cinders keep burning.",
			"hp": 700, "dmg": 92, "period": 1.12, "range": 3.35, "speed": 2.3,
			"radius": 0.52, "sight": 6.2, "splash": 2.05, "hits_air": true, "projectile": true,
			"burn": 16.0, "burn_time": 2.2,
		},
		"water": {
			"name": "Mist Drake",
			"blurb": "River merge. The splash is cooler and soaks a target slow.",
			"hp": 640, "dmg": 58, "period": 1.16, "range": 3.35, "speed": 2.35,
			"radius": 0.5, "sight": 6.2, "splash": 1.8, "hits_air": true, "projectile": true,
			"slow": 0.38, "slow_time": 1.8,
		},
	},
	"pebble": {
		"name": "Pebble",
		"role": "Swarm",
		"cost": 2,
		"gait": "waddle",
		"card": Color(0.710, 0.506, 0.310),
		"blurb": "An otter with opinions about the current and very fast paws.",
		"branches": ["water", "forest"],
		"base": {
			"name": "Pebble",
			"blurb": "Cheap and quick. Two of them are a nuisance. A merge is a problem.",
			"hp": 270, "dmg": 42, "period": 0.68, "range": 1.2, "speed": 3.45,
			"radius": 0.34, "sight": 4.6,
		},
		"water": {
			"name": "Tide Otter",
			"blurb": "River merge. Faster still, and each nip leaves a chill.",
			"hp": 380, "dmg": 52, "period": 0.58, "range": 1.28, "speed": 3.85,
			"radius": 0.38, "sight": 5.0, "splash": 0.85, "slow": 0.22, "slow_time": 1.0,
		},
		"forest": {
			"name": "Moss Otter",
			"blurb": "Forest merge. A thicker coat, and the moss bites back.",
			"hp": 520, "dmg": 46, "period": 0.76, "range": 1.22, "speed": 3.05,
			"radius": 0.4, "sight": 4.8, "reflect": 0.2,
		},
	},
	"juniper": {
		"name": "Juniper",
		"role": "Ranged",
		"cost": 3,
		"gait": "walk",
		"card": Color(0.878, 0.478, 0.239),
		"blurb": "A fox who flicks seeds, stones, and rude remarks from a distance.",
		"branches": ["forest", "lava"],
		"base": {
			"name": "Juniper",
			"blurb": "Long toss. Can pester flyers the melee crowd cannot reach.",
			"hp": 310, "dmg": 56, "period": 0.98, "range": 4.75, "speed": 2.75,
			"radius": 0.36, "sight": 6.4, "hits_air": true, "projectile": true,
		},
		"forest": {
			"name": "Thorn Fox",
			"blurb": "Forest merge. Thorns travel with the shot and root a target.",
			"hp": 460, "dmg": 68, "period": 0.96, "range": 5.25, "speed": 2.8,
			"radius": 0.4, "sight": 6.6, "hits_air": true, "projectile": true,
			"slow": 0.42, "slow_time": 1.35,
		},
		"lava": {
			"name": "Cinder Fox",
			"blurb": "Lava merge. The shot pops into a small burst of embers.",
			"hp": 440, "dmg": 62, "period": 0.9, "range": 4.85, "speed": 2.85,
			"radius": 0.4, "sight": 6.5, "hits_air": true, "projectile": true,
			"splash": 1.2, "burn": 12.0, "burn_time": 2.0,
		},
	},
	"bramble": {
		"name": "Bramble",
		"role": "Tank",
		"cost": 5,
		"gait": "stomp",
		"card": Color(0.553, 0.416, 0.271),
		"blurb": "A round hedgehog who is mostly quill and stubbornness.",
		"branches": ["forest", "lava"],
		"base": {
			"name": "Bramble",
			"blurb": "Walks into the burrow fire so everyone else can keep going.",
			"hp": 1240, "dmg": 52, "period": 1.14, "range": 1.32, "speed": 1.55,
			"radius": 0.52, "sight": 4.8,
		},
		"forest": {
			"name": "Briar Guard",
			"blurb": "Forest merge. A walking thicket. Hits bounce off the briar.",
			"hp": 1900, "dmg": 66, "period": 1.1, "range": 1.4, "speed": 1.5,
			"radius": 0.6, "sight": 5.0, "reflect": 0.3,
		},
		"lava": {
			"name": "Ember Quill",
			"blurb": "Lava merge. The quills smolder and toast anyone crowding in.",
			"hp": 1640, "dmg": 60, "period": 1.06, "range": 1.38, "speed": 1.6,
			"radius": 0.58, "sight": 5.0, "aura_dps": 18.0, "aura_radius": 1.75,
		},
	},
	"lumen": {
		"name": "Lumen",
		"role": "Flyer",
		"cost": 4,
		"gait": "fly",
		"card": Color(0.949, 0.886, 0.769),
		"blurb": "An owl who treats the river like a suggestion.",
		"branches": ["forest", "water"],
		"base": {
			"name": "Lumen",
			"blurb": "Flies over the scrap. Ground swipes miss. Towers do not.",
			"hp": 330, "dmg": 50, "period": 1.1, "range": 3.65, "speed": 2.6,
			"radius": 0.38, "sight": 6.2, "hits_air": true, "projectile": true, "flying": true,
		},
		"forest": {
			"name": "Grove Owl",
			"blurb": "Forest merge. Wider wings, and nearby friends keep a brisker step.",
			"hp": 500, "dmg": 62, "period": 1.04, "range": 4.35, "speed": 2.65,
			"radius": 0.44, "sight": 6.6, "hits_air": true, "projectile": true, "flying": true,
			"slow": 0.28, "slow_time": 1.2, "aura_speed": 0.16, "aura_radius": 2.4,
		},
		"water": {
			"name": "Storm Owl",
			"blurb": "River merge. A splash of weather that slows a whole patch.",
			"hp": 470, "dmg": 54, "period": 1.0, "range": 3.75, "speed": 2.7,
			"radius": 0.44, "sight": 6.4, "hits_air": true, "projectile": true, "flying": true,
			"splash": 1.55, "slow": 0.32, "slow_time": 1.4,
		},
	},
	"pip": {
		"name": "Pip",
		"role": "Support",
		"cost": 3,
		"gait": "hop",
		"card": Color(0.498, 0.749, 0.388),
		"blurb": "A frog who keeps the glade on its feet, one hop at a time.",
		"branches": ["water", "forest"],
		"base": {
			"name": "Pip",
			"blurb": "Hops after hurt friends and patches them up. A soft slap if cornered.",
			"hp": 330, "dmg": 24, "period": 1.08, "range": 2.15, "speed": 2.5,
			"radius": 0.36, "sight": 6.5, "heal": 42.0, "heal_radius": 3.0, "support": true,
		},
		"water": {
			"name": "Lily Hopper",
			"blurb": "River merge. Bigger heals, and allies nearby move a little lighter.",
			"hp": 480, "dmg": 28, "period": 0.98, "range": 2.35, "speed": 2.65,
			"radius": 0.42, "sight": 6.8, "heal": 70.0, "heal_radius": 3.45, "support": true,
			"aura_speed": 0.14, "aura_radius": 2.6,
		},
		"forest": {
			"name": "Spore Frog",
			"blurb": "Forest merge. A cap of spores that bothers everyone standing too close.",
			"hp": 460, "dmg": 34, "period": 1.02, "range": 2.45, "speed": 2.4,
			"radius": 0.42, "sight": 6.2, "splash": 1.25, "aura_dps": 13.0, "aura_radius": 1.95,
			"slow": 0.22, "slow_time": 1.2,
		},
	},
}


static func ids() -> Array:
	return ORDER.duplicate()


static func info(species: String) -> Dictionary:
	return DATA[species]


static func cost(species: String) -> int:
	return int(DATA[species]["cost"])


static func branches(species: String) -> Array:
	return DATA[species]["branches"]


static func form_stats(species: String, form: String) -> Dictionary:
	var raw: Dictionary = DATA[species][form]
	var stats := {
		"name": raw["name"],
		"blurb": raw["blurb"],
		"hp": float(raw["hp"]),
		"dmg": float(raw["dmg"]),
		"period": float(raw["period"]),
		"range": float(raw["range"]),
		"speed": float(raw["speed"]),
		"radius": float(raw["radius"]),
		"sight": float(raw.get("sight", 5.0)),
		"splash": float(raw.get("splash", 0.0)),
		"hits_air": bool(raw.get("hits_air", false)),
		"projectile": bool(raw.get("projectile", false)),
		"flying": bool(raw.get("flying", false)),
		"heal": float(raw.get("heal", 0.0)),
		"heal_radius": float(raw.get("heal_radius", 0.0)),
		"support": bool(raw.get("support", false)),
		"reflect": float(raw.get("reflect", 0.0)),
		"slow": float(raw.get("slow", 0.0)),
		"slow_time": float(raw.get("slow_time", 0.0)),
		"burn": float(raw.get("burn", 0.0)),
		"burn_time": float(raw.get("burn_time", 0.0)),
		"aura_dps": float(raw.get("aura_dps", 0.0)),
		"aura_radius": float(raw.get("aura_radius", 0.0)),
		"aura_speed": float(raw.get("aura_speed", 0.0)),
		"gait": String(DATA[species]["gait"]),
		"role": String(DATA[species]["role"]),
		"cost": int(DATA[species]["cost"]),
		"species": species,
		"form": form,
	}
	return stats


static func form_name(species: String, form: String) -> String:
	return String(DATA[species][form]["name"])


static func resolve_form(species: String, habitat: String, pos: Vector3) -> String:
	var options: Array = DATA[species]["branches"]
	if options.has(habitat):
		return habitat
	var best: String = options[0]
	var best_d := 1e9
	for key in options:
		var d := _dist_to_habitat(pos.x, pos.z, String(key))
		if d < best_d:
			best_d = d
			best = String(key)
	return best


static func _dist_to_habitat(x: float, z: float, habitat: String) -> float:
	var in_river := absf(z) <= 1.28
	if habitat == "water":
		return maxf(0.0, absf(z) - 1.28)
	if habitat == "forest":
		if x < 0.0 and not in_river:
			return 0.0
		if x < 0.0:
			return 1.28 - absf(z)
		if not in_river:
			return x
		return sqrt(x * x + pow(1.28 - absf(z), 2.0))
	# lava: x >= 0 and outside the river
	if x >= 0.0 and not in_river:
		return 0.0
	if x >= 0.0:
		return 1.28 - absf(z)
	if not in_river:
		return -x
	return sqrt(x * x + pow(1.28 - absf(z), 2.0))


static func habitat_label(habitat: String) -> String:
	match habitat:
		"forest":
			return "Forest"
		"water":
			return "Water"
		"lava":
			return "Lava"
		_:
			return "Stone"


static func habitat_color(habitat: String) -> Color:
	match habitat:
		"forest":
			return Color("7dbe6a")
		"water":
			return Color("6ec8e0")
		"lava":
			return Color("ff7a45")
		_:
			return Color("d7c3a3")


const DEN := {
	"hp": 3400.0, "dmg": 68.0, "period": 0.9, "range": 6.05, "radius": 1.15, "sight": 6.05,
}
const BURROW := {
	"hp": 1800.0, "dmg": 40.0, "period": 0.85, "range": 5.15, "radius": 0.82, "sight": 5.15,
}
