extends Node3D
## The hunt, part 1 (see hunt.gd): every field of a running hunt, and the
## small queries and helpers the other parts share (foes near a point,
## objective text, scaling, feel, the sidekick, live skill level-ups).

signal finished(result: Dictionary)

const HUD_SCENE := preload("res://src/ui/hud.tscn")
const MAX_FOES := 44

var tier_i := 0
var zone_id := "barrow"
## "horde" (fill the soul meter) or "trial" (the Long Road, room by room).
var mode := "horde"
var trial_rooms := 0
var trial_seed := 1
var _spawn_q: Array = []
## Tiers added to the metal of everything that drops (deeper zones, trial depth).
var loot_bonus := 0
var zone: Dictionary
var rerolls_left := 1
var tier: Dictionary
var hero_id := "knight"
var arena: Arena
var fx: Fx
var cam: HuntCam
var hud: Hud
var world: Node3D
var hero: Hero
var boss: Boss
## The sidekick at your side (sidekick.gd), or null.
var sidekick: Node3D
var ally: Ally
## Party partners (partner.gd), one per other player in a party hunt.
var partners: Array = []
var foes: Array[Enemy] = []
## The fallen, still lying where they died (see DB.CORPSE_MAX).
var corpses: Array[Enemy] = []
var projs: Array[Proj] = []
var pickups: Array[Pickup] = []
var cards := {}
var time := 0.0
var phase := "rise"
var phase_t := 0.0
var souls := 0
var souls_goal := 110
var run_level := 1
var run_xp := 0
var kills := 0
var elites_killed := 0
var gold := 0
var items: Array = []
var uniques: Array = []
var dmg_dealt := 0.0
var foe_speed_mult := 1.0
var spawn_t := 1.5
var elite_marks := [0.28, 0.58, 0.86]
## Banked level-up picks (the "+N" badge over the super button).
var pending_levels := 0
## True while the level-up cards are on screen.
var card_open := false
var bot := false
var low := false
var result := {}
var _proj_pool := {}
var _real_hitstop := 0.0
var _skill_base := {}
var _skill_shown := {}
var _skill_t := 0.0
var _bot: HuntBot
var _ended := false
var _warming := false
var patches: Array = []
var shrines: Array = []
## The first surge comes early so a new player meets the horde in the first minute.
var surge_marks := [0.15, 0.45, 0.75]
var surge_queue: Array = []
var calm_t := 0.0
var _storming := false
var robber_wanted := false
var robber_spawned := false
## Pacts taken this hunt (see DB.PACTS), and whether the mid-hunt offer is spent.
var pacts: Array[String] = []
## The weekly omen this hunt carries ({} when off), see DB.WEEKLY_OMENS.
var omen := {}
var dashes := 0
var boss_time := 9999.0
var pact_offered := false
var curse_t := 0.0
## The Wilderness: the ring's radius now, its mesh, the rival count.
var ring_r := 34.0
var ring_mesh: MeshInstance3D
var rivals_total := 0
var rivals_spawned := false
var _ring_hurt_t := 0.0
var _ring_stage := 0
var depth := 1
var depth_t := 0.0
## Boss Rush: which boss is next, and the breather before it.
var rush_i := 0
var rush_wait := 0.0
var cur_boss := ""
var cur_boss_power := 1.0
var streak := 0
var perfect_dodges := 0
var banished: Array[String] = []
## Bosses killed this hunt (kill counts and dry streaks), and the rift's boss.
var bosses_killed: Array[String] = []
var rift_boss := ""
var banishes_left := DB.BANISHES
## Burning ground from Pyre: {pos, r, t, dps, tick}.
var pyres: Array = []
var _erupt_t := 6.0
## The ritual event: its callers, the sigil's center, seconds left (0 = none).
var ritual_callers: Array = []
var ritual_at := Vector3.ZERO
var ritual_t := 0.0
var ritual_done := false
var _ritual_tele: MeshInstance3D
var _xp_frac := 0.0
var streak_t := 0.0


func _weak_device() -> bool:
	var name_ := RenderingServer.get_video_adapter_name().to_lower()
	return name_.contains("mali-g5") or name_.contains("adreno (tm) 5") or name_.contains("powervr")


# --- Foe queries and spawning -------------------------------------------

func nearest_foe(from: Vector3, max_d: float) -> Actor:
	var best: Actor = null
	var bd := max_d
	for f in foes:
		if not f.alive or f.state == "spawn":
			continue
		var d := Vector2(f.position.x - from.x, f.position.z - from.z).length() - f.radius
		if d < bd:
			bd = d
			best = f
	if boss and boss.alive and boss.state != "intro":
		var db := Vector2(boss.position.x - from.x, boss.position.z - from.z).length() - boss.radius
		if db < bd:
			best = boss
	return best


## Live foes (and the boss) whose center is within `r` of `p`.
func foes_near(p: Vector3, r: float) -> Array:
	var out := []
	var r2 := r * r
	for f in foes:
		if not f.alive or f.state == "spawn":
			continue
		var dx := f.position.x - p.x
		var dz := f.position.z - p.z
		if dx * dx + dz * dz <= r2:
			out.append(f)
	if boss and boss.alive and boss.state != "intro":
		var dx2 := boss.position.x - p.x
		var dz2 := boss.position.z - p.z
		if sqrt(dx2 * dx2 + dz2 * dz2) <= r + boss.radius:
			out.append(boss)
	return out


func on_screen(p: Vector3, margin := 0.0) -> bool:
	var vp := get_viewport().get_visible_rect()
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p + Vector3(0, 1, 0))
	return s.x > -margin * 40.0 and s.x < vp.size.x + margin * 40.0 and s.y > 80.0 and s.y < vp.size.y - 40.0


## How far along the hunt is, 0 to 1: it paces what spawns and how tough foes
## are. In the Descent it follows the depth; the soul bar shows `objective_fill`.
func progress() -> float:
	if mode == "descent":
		return clampf(0.12 + (depth - 1) * 0.07, 0.0, 1.0)
	if _rushlike():
		return 0.5
	if mode == "wild":
		return clampf(time / 240.0, 0.05, 1.0)
	return clampf(float(souls) / float(souls_goal), 0.0, 1.0)


## What the top bar shows.
func objective_fill() -> float:
	if mode == "descent":
		return clampf(depth_t / DB.DESCENT_TIME, 0.0, 1.0)
	if _rushlike():
		return float(rush_i) / rush_order().size()
	if mode == "wild":
		return float(rivals_alive()) / float(maxi(rivals_total, 1))
	return progress()


func spawn_foe(kind: String, at: Vector3, elite := false, affix := "") -> Enemy:
	# A zone's own faction stands in for the skeletons of the same role.
	kind = str(zone.get("faction", {}).get(kind, kind))
	var e := Enemy.new()
	world.add_child(e)
	e.position = at
	e.rotation.y = Actor.yaw_to(at, hero.position)
	e.setup(self, kind, scaled_tier(), elite, affix)
	foes.append(e)
	fx.puff(at, Color(0.28, 0.23, 0.18, 0.75), 7, 0.7, 1.6)
	if on_screen(at):
		fx.bone_burst(at, 2, 3.0)
	return e


func _room_active() -> bool:
	for r: Dictionary in arena.trial.get("rooms", []):
		if str(r["state"]) == "active":
			return true
	return false


func brute_count() -> int:
	var n := 0
	for f in foes:
		if f.alive and f.kind == "brute":
			n += 1
	return n


func necro_count() -> int:
	var n := 0
	for f in foes:
		if f.alive and f.kind == "necro":
			n += 1
	return n


func _pick_kind(p: float) -> String:
	var w := {
		"minion": 1.0,
		"warrior": 0.28 if p > 0.12 else 0.0,
		"rogue": 0.3 if p > 0.22 else 0.0,
		"mage": 0.2 if p > 0.42 else 0.0,
		"hound": 0.2 if p > 0.2 else 0.0,
		"brute": 0.07 if p > 0.4 and brute_count() < 2 else 0.0,
		"bomber": 0.22 if p > 0.3 else 0.0,
		"necro": 0.12 if p > 0.55 and necro_count() < 2 else 0.0,
	}
	for k in zone["weights"]:
		w[k] = float(w[k]) * float(zone["weights"][k])
	var total := 0.0
	for k in w:
		total += w[k]
	var r := randf() * total
	for k in w:
		r -= w[k]
		if r <= 0.0:
			return k
	return "minion"


var boss_at := 0.0
var rooms_cleared := 0


# --- Objectives ---------------------------------------------------------------

func objective_title() -> String:
	match mode:
		"trial":
			return "THE LONG ROAD"
		"descent":
			return "DEPTH"
		"rush":
			return "BOSS RUSH"
		"rift":
			return "THE RIFT"
		"wild":
			return "THE WILDERNESS"
	return "SOULS"


func objective_text() -> String:
	if mode == "descent":
		return "Depth %d" % depth
	if mode == "wild":
		return "%d rivals · ring %dm" % [rivals_alive(), int(ring_r)]
	if _rushlike():
		return "Boss %d / %d" % [mini(rush_i + 1, rush_order().size()), rush_order().size()]
	if mode != "trial":
		return "%d / %d" % [souls, souls_goal]
	if boss != null:
		return "The boss"
	return "Room %d / %d" % [mini(rooms_cleared + 1, trial_rooms), trial_rooms]


## Where the autopilot should walk next on the Long Road: the gap of the room
## it stands in (once clear), else the middle of the room.
func trial_goal() -> Vector3:
	var rooms: Array = arena.trial["rooms"]
	var i := arena.room_at(hero.position.z)
	if i < 0 or i >= rooms.size():
		return Vector3(0, 0, arena.boss_spawn.z + 10.0)
	var r: Dictionary = rooms[i]
	return Vector3(float(r["gap_x"]), 0, float(r["lo"]) - 4.0)


func _room_alive(r: Dictionary) -> int:
	var n := 0
	for f in r["foes"]:
		if is_instance_valid(f) and f.alive:
			n += 1
	return n


## No class_name for new scripts (the IPA bakes the list): preloaded by path.
const BossWarden := preload("res://src/hunt/boss_warden.gd")

func _make_boss() -> Boss:
	var b: Boss
	if cur_boss == "warden":
		b = BossWarden.new()
	else:
		b = BossHexer.new() if cur_boss == "hexer" else (BossThorn.new() if cur_boss == "thorn" else Boss.new())
	b.boss_id = cur_boss
	return b


# --- Rivals -------------------------------------------------------------------

func rivals_alive() -> int:
	var n := 0
	for f in foes:
		if is_instance_valid(f) and f.alive and f.kind.begins_with("rival_"):
			n += 1
	return n


# --- Mode helpers and scaling -------------------------------------------------

## The tier the foes of this moment are built from: the Descent makes
## everything tougher with depth, the second lap of the Rush hits harder.
func scaled_tier() -> Dictionary:
	var fh := pact_sum("foe_hp")
	var fd := pact_sum("foe_dmg")
	if fd != 0.0 and mode != "descent" and not _rushlike():
		var td := tier.duplicate()
		td["hp"] = float(tier["hp"]) * (1.0 + fh)
		td["dmg"] = float(tier["dmg"]) * (1.0 + fd)
		return td
	if mode == "descent" and depth > 1:
		var t := tier.duplicate()
		t["hp"] = float(tier["hp"]) * (1.0 + DB.DESCENT_HP * (depth - 1)) * (1.0 + fh)
		t["dmg"] = float(tier["dmg"]) * (1.0 + DB.DESCENT_DMG * (depth - 1)) * (1.0 + fd)
		return t
	if fh > 0.0 and not _rushlike():
		var tp := tier.duplicate()
		tp["hp"] = float(tier["hp"]) * (1.0 + fh)
		return tp
	if _rushlike() and cur_boss_power > 1.0:
		var t2 := tier.duplicate()
		t2["hp"] = float(tier["hp"]) * cur_boss_power
		t2["dmg"] = float(tier["dmg"]) * (1.0 + (cur_boss_power - 1.0) * 0.6)
		return t2
	return tier


## Boss Rush and the rift run the same rules: bosses in a row, no soul phase.
func _rushlike() -> bool:
	return mode == "rush" or mode == "rift"


func rush_order() -> Array:
	return [[rift_boss, DB.RIFT_POWER]] if mode == "rift" else DB.RUSH_ORDER


## The music of the moment: the Descent and rifts have their own; zones may too.
func music_track() -> String:
	if mode == "descent":
		return "descent"
	if mode == "rift":
		return "rift"
	return str(zone.get("music", "hunt"))


## A one-time callout the first time a player meets something (saved).
func tip(key: String, text: String, icon_name := "round-star") -> void:
	if bot or Game.data["tips"].has(key):
		return
	Game.data["tips"][key] = true
	hud.event(text, Color(1.0, 0.92, 0.6), icon_name)


## How cunning foes are on this tier: 0 Normal, 1 Veteran, 2 Nightmare, 3 Abyss.
func ai() -> float:
	return float(tier.get("ai", 0.0))


## Multiplier on passive healing (regen, leech, heal-on-hit cards).
func heal_mult() -> float:
	return float(tier.get("heal", 1.0))


## Total of one pact modifier over the pacts taken.
func pact_sum(key: String) -> float:
	var n := 0.0 if omen.is_empty() else float(omen["mod"].get(key, 0.0))
	for id in pacts:
		n += float(DB.PACTS[id]["mod"].get(key, 0.0))
	return n


# --- Skills (live level-ups) --------------------------------------------------

func skill_xp_gained() -> Dictionary:
	var total := dmg_dealt * DB.XP_PER_DAMAGE * float(tier["xp"])
	var out := {}
	for s in DB.STYLE_SKILLS[str(hero.def["skill"])]:
		out[s] = int(total / 3.0)
	return out


func _check_skill_levels() -> void:
	var g := skill_xp_gained()
	for s in g:
		var lvl := DB.level_for_xp(int(_skill_base[s]) + int(g[s]))
		if lvl > int(_skill_shown[s]):
			_skill_shown[s] = lvl
			hud.skill_toast(s, lvl)
			Sfx.play("skill_level", -2.0)


# --- Sidekick --------------------------------------------------------------

const SidekickNode := preload("res://src/hunt/sidekick.gd")
const SK := preload("res://src/autoload/sidekicks.gd")


func _spawn_sidekick() -> void:
	var sid := SK.active(Game.data)
	if sid == "":
		return
	sidekick = SidekickNode.new()
	world.add_child(sidekick)
	sidekick.setup(self, sid, SK.kills(Game.data, sid))


## Sidekick cards are in the pool only with that sidekick at Bond 5+.
func sidekick_card_open(c: Dictionary) -> bool:
	if not c.has("sidekick"):
		return true
	return sidekick != null and str(sidekick.id) == str(c["sidekick"]) and int(sidekick.bond) >= SK.SDB.BOND_CARDS


func hitstop(t: float) -> void:
	if phase == "victory" or phase == "defeat":
		return
	Engine.time_scale = 0.05
	_real_hitstop = maxf(_real_hitstop, t)


## A modal (level-up cards, pact, pause) is about to pause the tree. Hunt's
## _process, which winds a hitstop or slow-mo back to 1x, stops with it, so a
## hitstop still running here froze Engine.time_scale at 0.05-0.35 for the
## whole modal and every unpaused tween crawled. End it before pausing.
func end_hitstop() -> void:
	_real_hitstop = 0.0
	if phase != "victory" and phase != "defeat":
		Engine.time_scale = 1.0


## Level-up cards are never offered once the run is over: a win (the final
## boss is dead, souls still flying in), a death, or the hunt has ended.
func cards_blocked() -> bool:
	return _ended or phase == "victory" or phase == "defeat" or hero == null or not hero.alive


func shake(v: float) -> void:
	cam.add_trauma(v)


## A super goes off: the camera pushes in, the hero's
## color, its name rises over the hero, and the world holds its breath.
func super_moment(at: Vector3) -> void:
	var col: Color = hero.def["color"]
	cam.punch = 0.1
	fx.text(at + Vector3(0, 2.6, 0), str(hero.def["super_name"]).to_upper(), col.lightened(0.35), 1.3, 1.0)
	hitstop(0.06)


## A legendary falls: a pillar of light, the world slows a moment, its name.
func _legendary_moment(at: Vector3, it: Dictionary) -> void:
	var col := DB.rarity_color(it["rarity"])
	fx.sky_bolt(at, col.lightened(0.3), 0.5, 18.0)
	fx.vfx.impact(&"level", at, 2.4, col.lightened(0.3), &"big")
	cam.punch = maxf(cam.punch, 0.06)
	if phase != "victory":
		Engine.time_scale = 0.35
		_real_hitstop = maxf(_real_hitstop, 0.35)
	hud.event("%s!" % str(it["name"]), col.lightened(0.2), "crowned-skull")


func banner(text: String, color := Color(1, 0.85, 0.5), sub := "") -> void:
	hud.banner(text, color, sub)
