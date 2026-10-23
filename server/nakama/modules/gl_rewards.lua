--[[
Every reward the server hands out, in one place so tuning never touches logic.
A reward is a list of grants; the game applies each one to the local save:
  {kind = "gold", amount = n}
  {kind = "shards", amount = n}          -- to the hero being played
  {kind = "chest", chest = "silver" | "gold" | "crypt"}
  {kind = "glow", glow = "kinship"}      -- a weapon glow for every hero
]]

local M = {}

-- How long a new account may enter a friend's code, and how many friends one
-- player can be rewarded for (the cap stops farming with throwaway accounts).
M.REDEEM_DAYS = 7
M.MAX_RECRUITS = 20

-- Entering a friend's code: the newcomer gets a head start right away; the
-- friend gets a thank-you now and more as the newcomer actually plays.
M.WELCOME = {
	{ kind = "gold", amount = 2000 },
	{ kind = "chest", chest = "gold" },
	{ kind = "shards", amount = 10 },
}
M.RECRUITER_ON_REDEEM = {
	{ kind = "gold", amount = 500 },
}

-- Milestones a recruit reaches by playing. Both players are paid each time.
-- `check(p)` reads the recruit's reported progress.
M.MILESTONES = {
	{
		id = "hunts5", text = "played 5 hunts",
		check = function(p) return (p.hunts or 0) >= 5 end,
		recruiter = { { kind = "chest", chest = "gold" }, { kind = "gold", amount = 1000 } },
		recruit = { { kind = "gold", amount = 500 } },
	},
	{
		id = "combat25", text = "reached combat level 25",
		check = function(p) return (p.combat or 0) >= 25 end,
		recruiter = { { kind = "chest", chest = "crypt" }, { kind = "shards", amount = 15 } },
		recruit = { { kind = "chest", chest = "gold" } },
	},
	{
		id = "veteran", text = "won on Veteran",
		check = function(p) return (p.best_tier_won or 0) >= 3 end,
		recruiter = { { kind = "gold", amount = 3000 } },
		recruit = { { kind = "gold", amount = 1500 } },
	},
}

-- Rewards for how many recruits have played their first 5 hunts.
M.RECRUITER_TIERS = {
	{ count = 1, text = "your first friend joined the hunt", grants = { { kind = "glow", glow = "kinship" } } },
	{ count = 3, text = "three friends hunting", grants = { { kind = "chest", chest = "crypt" }, { kind = "chest", chest = "crypt" } } },
	{ count = 5, text = "five friends hunting", grants = { { kind = "gold", amount = 10000 } } },
	{ count = 10, text = "ten friends hunting", grants = { { kind = "gold", amount = 25000 }, { kind = "chest", chest = "crypt" } } },
}

-- The weekly clan raid: the boss's health per clan member (so a clan of 5
-- and a clan of 50 both have a fair fight), the most one hunt may deal, and
-- what every member who hit it gets when it falls.
M.RAID = {
	hp_per_member = 30000,
	hp_min = 90000,
	max_hit = 20000,
	hits_per_day = 12,
	bosses = { "gravemaw", "hexer", "thorn" },
	reward = { { kind = "gold", amount = 1500 }, { kind = "chest", chest = "crypt" } },
	-- The top three hitters also get this.
	top_reward = { { kind = "shards", amount = 20 } },
}

return M
