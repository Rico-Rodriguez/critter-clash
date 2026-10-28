extends RefCounted
## Model specs for bosses that use a licensed foreign rig (foe_rig.gd), kept apart from db.gd so
## the art stream can ship them without touching the boss script. A boss entry in DB.BOSSES takes
## `model`, `fit`, `clips` and `alias` from here and keeps its own `scale`: the model stands
## `fit * scale` metres tall (feet on the ground), `fit` being the height at scale 1.0.
##
## "clips" maps a class to the rig's clip names (first present wins); "alias" maps an exact KayKit
## clip name the combat code asks for to a clip. Classes the rig lacks fall back along
## FoeRig.CHAIN (a boss with no cast clip casts with its attack or its roar).

## Cinder Mire boss. "Low-poly orc" by Riltariki (CC BY 4.0), assets/foes/cinder_warlord.tscn.
const CINDER_WARLORD := {
	"model": "glb:cinder_warlord", "fit": 1.9, "scale": 3.0,
	"clips": {
		"idle": "ANM_IDLE", "walk": "ANM_WALK", "run": "ANM_RUN",
		"attack": ["ANM_ORC_LIGHT_ATTACK", "ANM_LIGHT_ATTACK_2", "ANM_ATTACK_CRIT"],
		"cast": "ANM_ORC_Roar", "taunt": "ANM_ORC_Roar", "spawn": "ANM_ORC_Roar",
		"hit": "ANM_DAMAGED", "die": "ANM_DEATH",
	},
	"alias": {
		"Melee_2H_Attack_Chop": "ANM_ATTACK_CRIT", "Melee_Dualwield_Attack_Slice": "ANM_LIGHT_ATTACK_2",
		"Melee_2H_Attack_Spin": "ANM_ORC_LIGHT_ATTACK",
	},
}

const DEFS := {"cinder_warlord": CINDER_WARLORD}
