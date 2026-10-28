extends RefCounted
## Model specs for the biome-rebuild foes (src/data/next_foes.gd) that stand on a licensed or custom
## model instead of a KayKit skeleton. Kept apart from next_foes.gd so the art stream ships them
## without touching the foe script; `fold(id, def)` merges one in. Same keys as boss_models.gd:
## `model` ("glb:<id>" = assets/foes/<id>.tscn with its own clips, "proc:<id>" = a static mesh moved
## by FoeRig's generated clips tuned by `proc`), `fit` (height in metres at scale 1.0, times the
## def's own `scale`), `clips` (class -> clip name or names), `alias` (exact KayKit clip name -> clip).
## The foe defs' `anim` maps keep naming KayKit clips; FoeRig maps them through the classes.
##
## Foes with no entry here (rh_imp, rh_effigy, rh_seer, rh_caller, cm_imp, cm_hag, cm_frog, cm_bogfin,
## cm_wasp) stay on their KayKit skeletons: no in-tone, cleanly licensed model fits them yet.

## Frost Wolf. "Wolf" by Quaternius (CC0), palette-merged to one material (tools/art/palette_merge.py).
const WOLF := {
	"model": "glb:wolf", "fit": 1.8,
	"clips": {"idle": ["Idle", "Idle_2"], "walk": "Walk", "run": "Gallop", "attack": "Attack", "taunt": "Idle_2_HeadLow",
		"spawn": "Jump_ToIdle", "hit": ["Idle_HitReact_Left", "Idle_HitReact_Right"], "die": "Death"},
}

## Wail Wraith. "Ghost Skull" by Quaternius (CC0), recoloured frost blue (palette_merge.py --recolor).
const WRAITH := {
	"model": "glb:wraith", "fit": 2.2,
	"clips": {"idle": "Flying_Idle", "walk": "Flying_Idle", "run": "Fast_Flying", "attack": ["Headbutt", "Punch"], "cast": "Headbutt",
		"taunt": "No", "spawn": "Flying_Idle", "hit": "HitReact", "die": "Death"},
}

## Pyre Shaman. "Ghost Skull" by Quaternius (CC0), palette-merged and decimated to one material.
const SHAMAN := {
	"model": "glb:ghost_skull", "fit": 2.1,
	"clips": {"idle": "Flying_Idle", "walk": "Flying_Idle", "run": "Fast_Flying", "attack": ["Punch", "Headbutt"], "cast": "Headbutt",
		"taunt": "Yes", "spawn": "Flying_Idle", "hit": "HitReact", "die": "Death"},
}

## Rime Yeti. "Lowpoly bigfoot" by Sololopenko (CC BY 4.0), decimated; clips added by tools/art/boss_clips.py.
const YETI := {
	"model": "glb:yeti", "fit": 2.1,
	"clips": {"idle": "Idle", "walk": "Walk", "run": "Run", "attack": ["Attack", "Slam"], "cast": "Roar", "taunt": "Roar",
		"spawn": "Roar", "hit": "Hit", "die": "Death"},
	"alias": {"Melee_2H_Attack_Chop": "Slam", "Melee_1H_Attack_Chop": "Attack"},
}

## Crystal Shardling: custom Blender model (tools/art/make_foes.py), CC0. Its Orbit* shards turn.
const SHARD := {"model": "proc:shard", "fit": 1.8, "proc": {"bob": 0.1, "rate": 0.5, "lean": 0.1, "lunge": 0.4}}

## Methane Bloat: custom Blender model (tools/art/make_foes.py), CC0.
const BLOAT := {"model": "proc:bloat", "fit": 1.5, "proc": {"bob": 0.12, "rate": 0.4, "lean": 0.08, "lunge": 0.5}}

## Sporecap: custom Blender model (tools/art/make_foes.py), CC0.
const SPORE := {"model": "proc:spore", "fit": 1.2, "proc": {"bob": 0.05, "rate": 0.7, "lean": 0.3, "lunge": 0.4}}

const DEFS := {"rh_wolf": WOLF, "rh_wraith": WRAITH, "rh_yeti": YETI, "rh_shard": SHARD,
	"cm_shaman": SHAMAN, "cm_bloat": BLOAT, "cm_spore": SPORE}


## `def` (a NextFoes def) with the model keys of foe `id` folded in; a def with no entry comes back as is.
## The def keeps its own `scale`, `anim`, `brain`, and the rest.
static func fold(id: String, def: Dictionary) -> Dictionary:
	if not DEFS.has(id):
		return def
	var out := def.duplicate()
	var m: Dictionary = DEFS[id]
	for k in m:
		out[k] = m[k]
	out["weapons"] = {}
	return out
