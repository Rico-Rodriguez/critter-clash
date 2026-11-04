extends RefCounted
## Model specs for bosses that use a licensed foreign rig (foe_rig.gd), kept apart from db.gd so
## the art stream can ship them without touching the boss script. A boss entry in DB.BOSSES takes
## `model`, `fit`, `clips` and `alias` from here and keeps its own `scale`: the model stands
## `fit * scale` metres tall (feet on the ground), `fit` being the height at scale 1.0.
##
## "clips" maps a class to the rig's clip names (first present wins); "alias" maps an exact KayKit
## clip name the combat code asks for to a clip. Classes the rig lacks fall back along
## FoeRig.CHAIN (a boss with no cast clip casts with its attack or its roar).

## Cinder Mire boss. Our own dark-plate orc, built in code by tools/blender/foes/cinder_warlord.py
## (assets/foes/cinder_warlord.tscn).
const CINDER_WARLORD := {
	"model": "glb:cinder_warlord", "fit": 1.9, "scale": 3.0,
	"clips": {
		"idle": "Idle", "walk": "Walk", "run": "Run",
		"attack": ["Attack_Chop", "Attack_Slash", "Attack_Spin"],
		"cast": "Roar", "taunt": "Roar", "spawn": "Roar",
		"hit": "Hit", "die": "Die",
	},
	"alias": {
		"Melee_2H_Attack_Chop": "Attack_Chop", "Melee_Dualwield_Attack_Slice": "Attack_Slash",
		"Melee_2H_Attack_Spin": "Attack_Spin",
	},
}

const DEFS := {"cinder_warlord": CINDER_WARLORD}
