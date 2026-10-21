class_name GatheringRules
extends RefCounted

## The gathering interaction layer (docs/gathering.md): the rules of working
## a resource node. The data lives in GatheringDB (what a node is, what a
## depth tier asks for); this file holds the rules the run applies to it:
##
##   channel  how long one gather takes, and what it is worth
##   danger   who may work a node at all
##   charges  how many gathers a node pays before it is spent
##
## The rules do not move during a run, so they are static: the sim asks them
## and the screen shows what they say. A biome node (GatheringDB.NODES) is
## gated by the gathering level it asks for; a depth node
## (GatheringDB.DEPTH_TIERS) is gated by danger, and the skill only makes it
## faster and worth more.

# --- The channel --------------------------------------------------------------

## A gather at the surface (depth 0) by a beginner (skill level 1).
const CHANNEL_BASE := 1.8
## Extra seconds per depth tier: the deeper the node, the longer it takes.
const CHANNEL_PER_DEPTH := 0.6
## Seconds the gathering skill shaves off a channel, per level.
const CHANNEL_PER_LEVEL := 0.02
## The most the skill can ever shave: a master still has to work the node.
const CHANNEL_MAX_CREDIT := 1.2
## The shortest a channel ever gets.
const CHANNEL_MIN := 0.5

# --- The take -----------------------------------------------------------------

## The skill's bonus on the take: every SKILL_BONUS_STEP levels of the
## gathering skill add SKILL_BONUS_GAIN more of what the node yields.
const SKILL_BONUS_STEP := 25
const SKILL_BONUS_GAIN := 0.5
## The most the rules ever multiply a node's take by: the deepest tier with
## the deepest skill would otherwise pay a small fortune per gather.
const YIELD_MAX_FACTOR := 5.0


## The depth tier a node belongs to, or "" for a biome node. A biome node is
## gated by its skill; a depth node is gated by danger.
static func tier_of(node: Dictionary) -> String:
	return str(node.get("tier", ""))


## True when the node is a depth-tier node: it stands in the depths, it is
## gated by danger and it pays a number of charges before it is spent.
static func is_depth(node: Dictionary) -> bool:
	return not tier_of(node).is_empty()


## How deep the node stands: 0 at the surface, 3 in the abyss.
static func depth_of(node: Dictionary) -> int:
	return int(node.get("depth", 0))


## How long one gather of this node takes, in seconds. The depth sets the
## base and the skill shaves it: a master works the same node faster.
static func channel_time(node: Dictionary, skill_level: int) -> float:
	var base := CHANNEL_BASE + float(depth_of(node)) * CHANNEL_PER_DEPTH
	var credit := minf(CHANNEL_MAX_CREDIT, float(maxi(skill_level, 1) - 1) * CHANNEL_PER_LEVEL)
	return maxf(CHANNEL_MIN, base - credit)


## The skill's bonus on the take: the deeper the skill, the more a single
## gather pulls out of the node.
static func skill_bonus(skill_level: int) -> float:
	var lv := maxi(skill_level, 1)
	return 1.0 + SKILL_BONUS_GAIN * float(floori(float(lv - 1) / float(SKILL_BONUS_STEP)))


## What one gather of the node is worth before the skill has its say: the
## tier's own yield. A biome node has no tier and is worth one.
static func base_yield(node: Dictionary) -> int:
	if not is_depth(node):
		return 1
	return maxi(1, GatheringDB.tier_yield(tier_of(node)))


## The multiplier the rules put on what a node pays: the tier's yield times
## the skill's bonus.
static func yield_factor(node: Dictionary, skill_level: int) -> float:
	return minf(YIELD_MAX_FACTOR, float(base_yield(node)) * skill_bonus(skill_level))


## What a gather of this node is worth: the base take the node rolled, scaled
## by the rules. A gather always pays at least one.
static func yield_amount(base: int, node: Dictionary, skill_level: int) -> int:
	return maxi(1, int(round(float(maxi(base, 1)) * yield_factor(node, skill_level))))


# --- The danger gate ----------------------------------------------------------

## The combat standing a node's tier demands, or 0 for a biome node (which
## asks for a gathering level, not for standing).
static func danger_need(node: Dictionary) -> int:
	if not is_depth(node):
		return 0
	return maxi(0, GatheringDB.tier_need(tier_of(node)))


## The danger rating of the node's tier (0 for a biome node).
static func danger_of(node: Dictionary) -> int:
	if not is_depth(node):
		return 0
	return GatheringDB.tier_danger(tier_of(node))


## True when the hero is too weak for the node: the deeper the tier, the
## harder the monsters that walk it, so a hero below the tier's standing is
## turned away from its nodes.
static func danger_blocked(node: Dictionary, combat_level: int) -> bool:
	var need := danger_need(node)
	if need <= 0:
		return false
	return combat_level < need


## What the refusal says: the standing the tier asks for.
static func danger_reason(node: Dictionary) -> String:
	var need := danger_need(node)
	if need <= 0:
		return ""
	return "Needs Combat %d" % need


# --- The charges --------------------------------------------------------------

## How many gathers a node pays before it is spent. A biome node pays one
## and then respawns; a depth node pays its tier's charges and only then
## waits out its respawn, coming back whole.
static func charges_for(node: Dictionary) -> int:
	if not is_depth(node):
		return 1
	return maxi(1, GatheringDB.tier_charges(tier_of(node)))


# --- The whole gate -----------------------------------------------------------

## Why this hero may not work the node, or "" when they may. The skill gate
## is the node's own (a biome node asks for a gathering level); the danger
## gate is the tier's (the deeper it is, the harder the monsters that walk
## it, so a hero too weak for the tier is turned away).
static func blocked_reason(node: Dictionary, skill_level: int, combat_level: int) -> String:
	if node.is_empty():
		return "Unknown node"
	if node.has("level") and skill_level < int(node["level"]):
		return "Needs %s %d" % [GatheringDB.skill_name(str(node["skill"])), int(node["level"])]
	if danger_blocked(node, combat_level):
		return danger_reason(node)
	return ""
