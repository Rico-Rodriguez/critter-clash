--[[
Gravelight's server rules, run inside Nakama (https://heroiclabs.com/nakama).

Nakama already does accounts, friends, groups (clans), chat, parties and
leaderboards. This module adds what is ours:

  * names and clan names pass the word filter; clans go through our RPCs so
    every player is in at most one;
  * chat is filtered, rate limited and closed to muted players;
  * reports, and an automatic mute when several players report the same one;
  * friend codes and referrals, with rewards paid as players really play;
  * a reward inbox ("grants") the game applies to its save;
  * cloud saves, transfer codes for a new phone, and account deletion;
  * the weekly clan raid boss;
  * progress reports that feed the leaderboards, with sanity limits.

Everything the server pays lives in gl_rewards.lua; the word list in gl_filter.lua.
]]

local nk = require("nakama")
local filter = require("gl_filter")
local rewards = require("gl_rewards")

local SYSTEM = nil -- storage owned by no player
local DAY = 86400
local CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local EMOTES = { gg = true, hi = true, thanks = true, wow = true, go = true, wait = true, help = true, lol = true, sad = true, angry = true }
local MSG_KINDS = { text = true, emote = true, invite = true, brag = true }
local SAVE_MAX = 1024 * 1024
local REPORT_REASONS = { chat = true, name = true, cheating = true, other = true }

-- --- Helpers -------------------------------------------------------------

local function now() return math.floor(nk.time() / 1000) end

local function fail(msg, code)
	error({ msg, code or 3 }) -- 3: INVALID_ARGUMENT
end

local function decode(payload)
	if payload == nil or payload == "" then
		return {}
	end
	local ok, t = pcall(nk.json_decode, payload)
	if not ok or type(t) ~= "table" then
		fail("Bad request.")
	end
	return t
end

local function encode(t) return nk.json_encode(t) end

local function need_user(context)
	if context.user_id == nil or context.user_id == "" then
		fail("Sign in first.", 16) -- UNAUTHENTICATED
	end
	return context.user_id
end

local function read_one(collection, key, user_id)
	local objs = nk.storage_read({ { collection = collection, key = key, user_id = user_id } })
	if objs and objs[1] then
		return objs[1].value, objs[1].version
	end
	return nil, nil
end

local function write_one(collection, key, user_id, value, version, read_perm)
	nk.storage_write({ {
		collection = collection, key = key, user_id = user_id, value = value,
		version = version, permission_read = read_perm or 1, permission_write = 0,
	} })
end

-- Read, change and write back, retrying when someone else wrote in between.
-- `change(value)` edits the table in place (or returns a new one).
local function update(collection, key, user_id, default, change, read_perm)
	for _ = 1, 8 do
		local value, version = read_one(collection, key, user_id)
		if value == nil then
			value = default()
			version = "*" -- only if it still doesn't exist
		end
		local out = change(value) or value
		local ok, err = pcall(write_one, collection, key, user_id, out, version, read_perm)
		if ok then
			return out
		end
		nk.logger_debug(("update %s/%s retry: %s"):format(collection, key, tostring(err)))
	end
	fail("Busy, try again.", 10) -- ABORTED
end

local function new_code(len)
	local t = {}
	for i = 1, len do
		local n = math.random(1, #CODE_CHARS)
		t[i] = CODE_CHARS:sub(n, n)
	end
	return table.concat(t)
end

local function account_age(user_id)
	local acc = nk.account_get_id(user_id)
	local ct = acc.user.create_time
	if type(ct) ~= "number" then
		return 0
	end
	if ct > 1e12 then
		ct = ct / 1000
	end
	return now() - ct, acc
end

-- The one clan a player is in (state 0 superadmin, 1 admin, 2 member), or nil.
local function clan_of(user_id)
	local groups = nk.user_groups_list(user_id, 10, nil, "")
	for _, ug in ipairs(groups or {}) do
		if ug.state ~= nil and ug.state <= 2 then
			return ug.group, ug.state
		end
	end
	return nil, nil
end

local function private(user_id)
	return read_one("profile", "private", user_id) or {}
end

-- --- Reward inbox --------------------------------------------------------

-- Puts a reward in a player's inbox and pings them if they are online.
local function give(user_id, grants, reason, text)
	if grants == nil or #grants == 0 then
		return
	end
	local id = nk.uuid_v4()
	write_one("grants", id, user_id, { grants = grants, reason = reason, text = text, at = now() })
	pcall(nk.notification_send, user_id, text, { reason = reason, grant = id }, 100, nil, true)
end

local function list_grants(context, _)
	local uid = need_user(context)
	local objs = nk.storage_list(uid, "grants", 100, "")
	local out = {}
	for _, o in ipairs(objs or {}) do
		table.insert(out, { id = o.key, grants = o.value.grants, reason = o.value.reason, text = o.value.text, at = o.value.at })
	end
	table.sort(out, function(a, b) return (a.at or 0) < (b.at or 0) end)
	return encode({ grants = out })
end

-- The game applied these; drop them. Applied first, acked second, so a lost
-- reply means the grant shows again and the game skips the ids it has seen.
local function ack_grants(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local del = {}
	for _, id in ipairs(p.ids or {}) do
		if type(id) == "string" and #id <= 64 then
			table.insert(del, { collection = "grants", key = id, user_id = uid })
		end
	end
	if #del > 0 then
		nk.storage_delete(del)
	end
	return encode({ ok = true })
end

-- --- Accounts ------------------------------------------------------------

-- Every player gets a short code: friends add them by it, and a new player
-- who enters it is their recruit. It doubles as the Nakama username, so the
-- standard "add friend by username" works with it.
local function ensure_code(user_id)
	local priv = private(user_id)
	if priv.code then
		return priv.code
	end
	for _ = 1, 20 do
		local code = new_code(6)
		local ok = pcall(write_one, "ref_codes", code, SYSTEM, { user_id = user_id }, "*", 0)
		if ok then
			local ok2 = pcall(nk.account_update_id, user_id, nil, code)
			if ok2 then
				update("profile", "private", user_id, function() return {} end, function(v) v.code = code end)
				return code
			end
			nk.storage_delete({ { collection = "ref_codes", key = code, user_id = SYSTEM } })
		end
	end
	fail("Could not make a friend code.", 13)
end

local function public_profile(user_id)
	return read_one("profile", "public", user_id) or {}
end

-- A player's shown name, never empty.
local function display(user_id, fallback)
	local n = nk.account_get_id(user_id).user.display_name
	if n == nil or n == "" then
		return fallback
	end
	return n
end

-- What the camp needs after signing in, in one call.
local function bootstrap(context, payload)
	local uid = need_user(context)
	local code = ensure_code(uid)
	local age, acc = account_age(uid)
	local priv = private(uid)
	local clan, role = clan_of(uid)
	local mod = read_one("mod", uid, SYSTEM) or {}
	local recruits = read_one("profile", "recruits", uid) or { list = {} }
	return encode({
		user_id = uid,
		code = code,
		name = acc.user.display_name or "",
		referred = priv.referred_by ~= nil,
		can_redeem = priv.referred_by == nil and age < rewards.REDEEM_DAYS * DAY,
		recruits = #(recruits.list or {}),
		clan = clan and { id = clan.id, name = clan.name, role = role } or nil,
		muted_until = mod.muted_until or 0,
		server_time = now(),
	})
end

local function set_name(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local name, why = filter.name(p.name or "", 16)
	if not name then
		fail(why)
	end
	nk.account_update_id(uid, nil, nil, name)
	update("profile", "public", uid, function() return {} end, function(v) v.name = name end, 2)
	return encode({ name = name })
end

-- The game reports progress after each hunt. Numbers only ever go up, by no
-- more than real play allows; they feed the leaderboards and referral
-- milestones, so a hacked save can't farm rewards for a friend.
local LIMITS = { hunts = 3, wins = 3 }

-- Marks the recruiter tiers reached by `done_count` in `paid` and returns
-- the ones newly reached (paid after the write lands, never inside a retry).
local function new_recruiter_tiers(done_count, paid)
	local out = {}
	for _, tier in ipairs(rewards.RECRUITER_TIERS) do
		local key = "tier" .. tier.count
		if done_count >= tier.count and not paid[key] then
			paid[key] = true
			table.insert(out, tier)
		end
	end
	return out
end

local function check_milestones(uid, prog)
	local priv = private(uid)
	if not priv.referred_by then
		return
	end
	local recruiter = priv.referred_by
	local name = display(uid, "Your friend")
	for _, m in ipairs(rewards.MILESTONES) do
		local done = (priv.milestones or {})[m.id]
		if not done and m.check(prog) then
			local claimed = false
			update("profile", "private", uid, function() return {} end, function(v)
				claimed = false
				v.milestones = v.milestones or {}
				if not v.milestones[m.id] then
					v.milestones[m.id] = now()
					claimed = true
				end
			end)
			if claimed then
				give(uid, m.recruit, "milestone", "Friend bonus: you " .. m.text)
				local paid = false
				local tiers = {}
				update("profile", "recruits", recruiter, function() return { list = {}, paid = {} } end, function(v)
					paid = false
					tiers = {}
					v.paid = v.paid or {}
					for _, r in ipairs(v.list or {}) do
						if r.id == uid and r.rewarded then
							r.done = r.done or {}
							r.done[m.id] = true
							paid = true
						end
					end
					if paid and m.id == "hunts5" then
						local n = 0
						for _, r in ipairs(v.list) do
							if r.done and r.done.hunts5 then
								n = n + 1
							end
						end
						tiers = new_recruiter_tiers(n, v.paid)
					end
				end)
				if paid then
					give(recruiter, m.recruiter, "milestone", name .. " " .. m.text .. ". Thanks for bringing them!")
				end
				for _, tier in ipairs(tiers) do
					give(recruiter, tier.grants, "recruiter_tier", "Referral reward: " .. tier.text)
				end
			end
		end
	end
end

local function report_progress(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	-- One report per 10 seconds is plenty; more is a script.
	if nk.localcache_get("rp:" .. uid) then
		return encode({ ok = true, throttled = true })
	end
	nk.localcache_put("rp:" .. uid, "1", 10)
	local t = now()
	local prog = update("profile", "public", uid, function() return {} end, function(v)
		local since = math.max(1, t - (v.at or t - 3600))
		for _, k in ipairs({ "hunts", "wins" }) do
			local old = v[k] or 0
			local want = math.floor(tonumber(p[k]) or old)
			-- A hunt takes a couple of minutes; allow a few at once for catch-up.
			local most = old + LIMITS[k] + math.floor(since / 60)
			v[k] = math.max(old, math.min(want, most))
		end
		v.combat = math.max(v.combat or 3, math.min(math.floor(tonumber(p.combat) or 3), 140))
		v.power = math.max(0, math.min(math.floor(tonumber(p.power) or 0), 200000))
		v.best_tier_won = math.max(v.best_tier_won or 0, math.min(math.floor(tonumber(p.best_tier_won) or 0), 8))
		if type(p.hero) == "string" and #p.hero <= 16 then
			v.hero = p.hero
		end
		v.at = t
	end, 2)
	local acc = nk.account_get_id(uid)
	prog.name = acc.user.display_name
	pcall(nk.leaderboard_record_write, "power", uid, acc.user.display_name or acc.user.username, prog.power, 0, { hero = prog.hero, combat = prog.combat })
	pcall(nk.leaderboard_record_write, "combat", uid, acc.user.display_name or acc.user.username, prog.combat, prog.power, { hero = prog.hero })
	check_milestones(uid, prog)
	return encode({ ok = true })
end

local function profiles(context, payload)
	need_user(context)
	local p = decode(payload)
	local reads = {}
	for i, id in ipairs(p.ids or {}) do
		if i > 100 then
			break
		end
		table.insert(reads, { collection = "profile", key = "public", user_id = id })
	end
	local out = {}
	if #reads > 0 then
		for _, o in ipairs(nk.storage_read(reads) or {}) do
			out[o.user_id] = o.value
		end
	end
	return encode({ profiles = out })
end

-- --- Referrals -----------------------------------------------------------

local function redeem(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local code = string.upper(filter.clean(p.code or "")):gsub("[^A-Z0-9]", "")
	if #code ~= 6 then
		fail("Codes are 6 letters and numbers.")
	end
	local priv = private(uid)
	if priv.referred_by then
		fail("You already entered a friend's code.")
	end
	local age = account_age(uid)
	if age > rewards.REDEEM_DAYS * DAY then
		fail(("Friend codes work in your first %d days."):format(rewards.REDEEM_DAYS))
	end
	local ref = read_one("ref_codes", code, SYSTEM)
	if not ref then
		fail("No hunter has that code.")
	end
	local rid = ref.user_id
	if rid == uid then
		fail("That's your own code!")
	end
	if private(rid).referred_by == uid then
		fail("You brought them in, so they can't bring you.")
	end
	local ok_mark = false
	update("profile", "private", uid, function() return {} end, function(v)
		ok_mark = false
		if not v.referred_by then
			v.referred_by = rid
			v.referred_at = now()
			ok_mark = true
		end
	end)
	if not ok_mark then
		fail("You already entered a friend's code.")
	end
	local rname = display(rid, "your friend")
	local myname = display(uid, "A new hunter")
	give(uid, rewards.WELCOME, "welcome", "Welcome gift from " .. rname .. "'s invite")
	local rewarded = false
	update("profile", "recruits", rid, function() return { list = {}, paid = {} } end, function(v)
		v.list = v.list or {}
		local paid_n = 0
		for _, r in ipairs(v.list) do
			if r.rewarded then
				paid_n = paid_n + 1
			end
		end
		rewarded = paid_n < rewards.MAX_RECRUITS
		table.insert(v.list, { id = uid, at = now(), rewarded = rewarded, done = {} })
	end)
	if rewarded then
		give(rid, rewards.RECRUITER_ON_REDEEM, "recruit", myname .. " joined with your code!")
	end
	-- Friends straight away: a request each way is an accepted friendship.
	local ok1, e1 = pcall(nk.friends_add, uid, context.username, { rid }, nil)
	local ok2, e2 = pcall(nk.friends_add, rid, nk.account_get_id(rid).user.username, { uid }, nil)
	if not (ok1 and ok2) then
		nk.logger_warn("referral friends: " .. tostring(e1) .. " / " .. tostring(e2))
	end
	return encode({ ok = true, friend = rname })
end

local function recruits(context, _)
	local uid = need_user(context)
	local v = read_one("profile", "recruits", uid) or { list = {} }
	local ids = {}
	for _, r in ipairs(v.list or {}) do
		table.insert(ids, r.id)
	end
	local names = {}
	if #ids > 0 then
		for _, u in ipairs(nk.users_get_id(ids) or {}) do
			local id = u.user_id or u.id
			if id then
				names[id] = u.display_name or u.username
			end
		end
	end
	local out = {}
	for _, r in ipairs(v.list or {}) do
		table.insert(out, { id = r.id, name = names[r.id] or "Hunter", done = r.done or {}, rewarded = r.rewarded })
	end
	local steps = {}
	for _, m in ipairs(rewards.MILESTONES) do
		table.insert(steps, { id = m.id, text = m.text })
	end
	local tiers = {}
	for _, t in ipairs(rewards.RECRUITER_TIERS) do
		table.insert(tiers, { count = t.count, text = t.text, paid = (v.paid or {})["tier" .. t.count] == true })
	end
	return encode({ list = out, steps = steps, tiers = tiers, max = rewards.MAX_RECRUITS })
end

-- --- Cloud save, new phone, deletion ------------------------------------------

local function save_put(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	if type(p.data) ~= "string" or #p.data > SAVE_MAX then
		fail("Save too large.")
	end
	local cur = read_one("save", "main", uid)
	if cur then
		write_one("save", "prev", uid, cur, nil)
	end
	write_one("save", "main", uid, { data = p.data, at = now(), hunts = tonumber(p.hunts) or 0 }, nil)
	return encode({ ok = true, at = now() })
end

local function save_get(context, _)
	local uid = need_user(context)
	local cur = read_one("save", "main", uid)
	return encode(cur or {})
end

local function transfer_make(context, _)
	local uid = need_user(context)
	for _ = 1, 10 do
		local code = new_code(8)
		local ok = pcall(write_one, "transfer", code, SYSTEM, { user_id = uid, exp = now() + DAY }, "*", 0)
		if ok then
			return encode({ code = code, expires = now() + DAY })
		end
	end
	fail("Try again.", 13)
end

-- Called from the new phone, signed in as a fresh throwaway account made by
-- its own key: that account is deleted and the key is linked to the old one,
-- so signing in again lands on the old account. The old phone keeps working.
local function transfer_use(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local code = string.upper(filter.clean(p.code or "")):gsub("[^A-Z0-9]", "")
	local key = tostring(p.key or "")
	if #key < 16 or #key > 128 then
		fail("Bad device key.")
	end
	local t = read_one("transfer", code, SYSTEM)
	if not t or (t.exp or 0) < now() then
		fail("That code is wrong or has expired. Make a new one on your old phone.")
	end
	if t.user_id == uid then
		fail("This phone is already on that account.")
	end
	nk.storage_delete({ { collection = "transfer", key = code, user_id = SYSTEM } })
	local priv = private(uid)
	if priv.code then
		nk.storage_delete({ { collection = "ref_codes", key = priv.code, user_id = SYSTEM } })
	end
	nk.account_delete_id(uid, false)
	nk.link_device(t.user_id, key)
	return encode({ ok = true })
end

local function delete_account(context, _)
	local uid = need_user(context)
	local priv = private(uid)
	if priv.code then
		nk.storage_delete({ { collection = "ref_codes", key = priv.code, user_id = SYSTEM } })
	end
	pcall(nk.leaderboard_record_delete, "power", uid)
	pcall(nk.leaderboard_record_delete, "combat", uid)
	nk.account_delete_id(uid, false)
	return encode({ ok = true })
end

-- --- Clans ---------------------------------------------------------------------

local BADGES = 12

local function clan_text(desc)
	desc = filter.clean(desc or "")
	if #desc > 140 then
		fail("Keep the description under 140 letters.")
	end
	if filter.is_rude(desc) or filter.has_contact(desc) then
		fail("Pick other words for the description.")
	end
	return desc
end

local function clan_create(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	if clan_of(uid) then
		fail("Leave your clan first.")
	end
	local name, why = filter.name(p.name or "", 20)
	if not name then
		fail(why)
	end
	local desc = clan_text(p.desc)
	local badge = math.max(0, math.min(BADGES - 1, math.floor(tonumber(p.badge) or 0)))
	local min_combat = math.max(0, math.min(126, math.floor(tonumber(p.min_combat) or 0)))
	local ok, g = pcall(nk.group_create, uid, name, uid, "en", desc, "", p.open ~= false, { badge = badge, min_combat = min_combat }, 50)
	if not ok then
		fail("A clan with that name already exists.")
	end
	return encode({ id = g.id, name = g.name })
end

local function clan_edit(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local clan, role = clan_of(uid)
	if not clan or role > 1 then
		fail("Only leaders and elders can edit the clan.")
	end
	local meta = clan.metadata or {}
	if type(meta) == "string" then
		meta = nk.json_decode(meta)
	end
	if p.badge ~= nil then
		meta.badge = math.max(0, math.min(BADGES - 1, math.floor(tonumber(p.badge) or 0)))
	end
	if p.min_combat ~= nil then
		meta.min_combat = math.max(0, math.min(126, math.floor(tonumber(p.min_combat) or 0)))
	end
	local desc = nil
	if p.desc ~= nil then
		desc = clan_text(p.desc)
	end
	local open = nil
	if p.open ~= nil then
		open = p.open == true
	end
	nk.group_update(clan.id, nil, nil, nil, nil, desc, nil, open, meta, nil)
	return encode({ ok = true })
end

-- Clans may only be made and changed through the RPCs above (names are
-- filtered, one clan each); joining checks the one-clan rule and the clan's
-- minimum combat level.
local function before_create_group(_, _) error("Use clan_create.") end
local function before_update_group(_, _) error("Use clan_edit.") end

local function before_join_group(context, payload)
	if clan_of(context.user_id) then
		error("Leave your clan first.")
	end
	local gid = payload.group_id
	local groups = nk.groups_get_id({ gid })
	local g = groups and groups[1]
	if g then
		local meta = g.metadata or {}
		if type(meta) == "string" then
			meta = nk.json_decode(meta)
		end
		local need = tonumber(meta.min_combat) or 0
		if need > 0 and (public_profile(context.user_id).combat or 0) < need then
			error(("This clan asks for combat level %d."):format(need))
		end
	end
	return payload
end

-- --- Chat ------------------------------------------------------------------------

local function muted_until(uid)
	local m = nk.localcache_get("mute:" .. uid)
	if m then
		return tonumber(m) or 0
	end
	local mod = read_one("mod", uid, SYSTEM) or {}
	local untl = mod.muted_until or 0
	nk.localcache_put("mute:" .. uid, tostring(untl), 60)
	return untl
end

-- Everything typed into chat passes here: muted players are refused, the
-- pace is limited, links and contact details are refused, rude words masked.
local function before_chat(context, envelope)
	local uid = context.user_id
	local m = muted_until(uid)
	if m > now() then
		error(("You are muted for %d more minutes after reports from other players."):format(math.ceil((m - now()) / 60)))
	end
	local t = nk.time()
	local last = tonumber(nk.localcache_get("chat:" .. uid) or "0")
	if t - last < 1000 then
		error("Slow down a little.")
	end
	nk.localcache_put("chat:" .. uid, tostring(t), 60)
	local minute = math.floor(t / 60000)
	local n = tonumber(nk.localcache_get("chatn:" .. uid .. ":" .. minute) or "0") + 1
	if n > 20 then
		error("Slow down a little.")
	end
	nk.localcache_put("chatn:" .. uid .. ":" .. minute, tostring(n), 70)
	local msg = envelope.channel_message_send
	local ok, c = pcall(nk.json_decode, msg.content or "")
	if not ok or type(c) ~= "table" or not MSG_KINDS[c.t] then
		error("That message can't be sent.")
	end
	local out = { t = c.t }
	if c.t == "text" then
		local body = filter.clean(c.body)
		if #body == 0 or #body > 200 then
			error("Messages are 1 to 200 letters.")
		end
		if filter.has_contact(body) then
			error("Links and contact details can't be shared in chat.")
		end
		out.body = filter.mask(body)
	elseif c.t == "emote" then
		if not EMOTES[c.id] then
			error("Unknown emote.")
		end
		out.id = c.id
	elseif c.t == "invite" then
		if type(c.party) ~= "string" or #c.party > 80 then
			error("Bad invite.")
		end
		out.party = c.party
		out.mode = tostring(c.mode or ""):sub(1, 16)
		out.zone = tostring(c.zone or ""):sub(1, 16)
		out.tier = math.floor(tonumber(c.tier) or 0)
		out.hero = tostring(c.hero or ""):sub(1, 16)
	elseif c.t == "brag" then
		out.item = filter.mask(filter.clean(c.item or "")):sub(1, 48)
		out.rarity = tostring(c.rarity or ""):sub(1, 12)
	end
	msg.content = nk.json_encode(out)
	return envelope
end

local function before_chat_update(_, _) error("Messages can't be edited.") end

-- --- Reports and mutes --------------------------------------------------------------

local function report(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local target = tostring(p.user_id or "")
	if target == "" or target == uid then
		fail("Pick a player to report.")
	end
	local reason = REPORT_REASONS[p.reason] and p.reason or "other"
	write_one("reports", target .. ":" .. uid, SYSTEM, {
		target = target, by = uid, reason = reason, at = now(),
		message = filter.clean(p.message or ""):sub(1, 300),
	}, nil, 0)
	nk.logger_warn(("REPORT %s by %s: %s"):format(target, uid, reason))
	-- Several different players reporting within three days mutes for a day;
	-- twice that many, a week. A name reported three times is reset.
	update("mod", target, SYSTEM, function() return { reporters = {}, names = {} } end, function(v)
		v.reporters = v.reporters or {}
		v.names = v.names or {}
		v.reporters[uid] = now()
		if reason == "name" then
			v.names[uid] = now()
		end
		local recent, recent_names = 0, 0
		for k, at in pairs(v.reporters) do
			if now() - at < 3 * DAY then
				recent = recent + 1
			else
				v.reporters[k] = nil
			end
		end
		for _, at in pairs(v.names) do
			if now() - at < 7 * DAY then
				recent_names = recent_names + 1
			end
		end
		if recent >= 6 then
			v.muted_until = math.max(v.muted_until or 0, now() + 7 * DAY)
		elseif recent >= 3 then
			v.muted_until = math.max(v.muted_until or 0, now() + DAY)
		end
		if recent_names >= 3 and not v.name_reset then
			v.name_reset = now()
			pcall(nk.account_update_id, target, nil, nil, "Hunter" .. math.random(1000, 9999))
		end
		pcall(nk.localcache_delete, "mute:" .. target)
	end, 0)
	return encode({ ok = true })
end

-- --- Clan raid -------------------------------------------------------------------

local WEEK = 7 * DAY

local function raid_key(clan_id) return clan_id .. ":" .. math.floor(now() / WEEK) end

local function member_count(clan_id)
	local users = nk.group_users_list(clan_id, 100, nil, "")
	local n = 0
	for _, gu in ipairs(users or {}) do
		if gu.state <= 2 then
			n = n + 1
		end
	end
	return math.max(1, n)
end

local function new_raid(clan_id)
	local week = math.floor(now() / WEEK)
	local hp = math.max(rewards.RAID.hp_min, member_count(clan_id) * rewards.RAID.hp_per_member)
	return {
		boss = rewards.RAID.bosses[(week % #rewards.RAID.bosses) + 1],
		max = hp, hp = hp, hits = {}, names = {}, fallen = 0, week = week,
	}
end

local function raid_view(r, uid)
	local top = {}
	for id, dmg in pairs(r.hits or {}) do
		table.insert(top, { id = id, name = (r.names or {})[id] or "Hunter", dmg = dmg })
	end
	table.sort(top, function(a, b) return a.dmg > b.dmg end)
	while #top > 10 do
		table.remove(top)
	end
	return {
		boss = r.boss, hp = r.hp, max = r.max, fallen = r.fallen,
		mine = (r.hits or {})[uid] or 0, top = top,
		ends = (r.week + 1) * WEEK, reward = rewards.RAID.reward,
	}
end

local function raid_status(context, _)
	local uid = need_user(context)
	local clan = clan_of(uid)
	if not clan then
		return encode({ none = true })
	end
	local r = read_one("raid", raid_key(clan.id), SYSTEM)
	if not r then
		r = update("raid", raid_key(clan.id), SYSTEM, function() return new_raid(clan.id) end, function(v) return v end, 0)
	end
	return encode(raid_view(r, uid))
end

local function raid_hit(context, payload)
	local uid = need_user(context)
	local p = decode(payload)
	local clan = clan_of(uid)
	if not clan then
		return encode({ none = true })
	end
	local today = math.floor(now() / DAY)
	local count_key = "raid_hits"
	local n = 0
	update("profile", count_key, uid, function() return {} end, function(v)
		if v.day ~= today then
			v.day = today
			v.n = 0
		end
		v.n = v.n + 1
		n = v.n
	end)
	if n > rewards.RAID.hits_per_day then
		fail("You've hit the raid boss enough today. Come back tomorrow!")
	end
	local tier = math.max(0, math.min(8, math.floor(tonumber(p.tier) or 0)))
	local cap = math.floor(rewards.RAID.max_hit * (1 + tier * 0.25))
	local dmg = math.max(0, math.min(math.floor(tonumber(p.damage) or 0), cap))
	local name = display(uid, "Hunter")
	local fell = false
	local r = update("raid", raid_key(clan.id), SYSTEM, function() return new_raid(clan.id) end, function(v)
		fell = false
		if (v.fallen or 0) > 0 then
			return
		end
		v.hits = v.hits or {}
		v.names = v.names or {}
		v.hits[uid] = (v.hits[uid] or 0) + dmg
		v.names[uid] = name
		v.hp = math.max(0, v.hp - dmg)
		if v.hp == 0 then
			v.fallen = now()
			fell = true
		end
	end, 0)
	if fell then
		local view = raid_view(r, uid)
		for i, t in ipairs(view.top) do
			if i <= 3 then
				give(t.id, rewards.RAID.top_reward, "raid_top", "Top raider bonus")
			end
		end
		for id, _ in pairs(r.hits) do
			give(id, rewards.RAID.reward, "raid", "Your clan felled the raid boss!")
		end
		local ok, channel = pcall(nk.channel_id_build, nil, clan.id, 3)
		if ok and channel then
			pcall(nk.channel_message_send, channel, { t = "raid", body = name .. " landed the final blow! The raid boss has fallen." }, nil, nil, true)
		end
	end
	return encode(raid_view(r, uid))
end

-- --- Wiring ------------------------------------------------------------------------

pcall(nk.leaderboard_create, "power", true, "desc", "best", nil, {}, false)
pcall(nk.leaderboard_create, "combat", true, "desc", "best", nil, {}, false)

nk.register_rpc(bootstrap, "bootstrap")
nk.register_rpc(set_name, "set_name")
nk.register_rpc(report_progress, "report_progress")
nk.register_rpc(profiles, "profiles")
nk.register_rpc(list_grants, "list_grants")
nk.register_rpc(ack_grants, "ack_grants")
nk.register_rpc(redeem, "redeem")
nk.register_rpc(recruits, "recruits")
nk.register_rpc(save_put, "save_put")
nk.register_rpc(save_get, "save_get")
nk.register_rpc(transfer_make, "transfer_make")
nk.register_rpc(transfer_use, "transfer_use")
nk.register_rpc(delete_account, "delete_account")
nk.register_rpc(clan_create, "clan_create")
nk.register_rpc(clan_edit, "clan_edit")
nk.register_rpc(report, "report")
nk.register_rpc(raid_status, "raid_status")
nk.register_rpc(raid_hit, "raid_hit")

nk.register_req_before(before_create_group, "CreateGroup")
nk.register_req_before(before_update_group, "UpdateGroup")
nk.register_req_before(before_join_group, "JoinGroup")
-- Names change only through set_name (filtered).
nk.register_req_before(function(_, _) error("Use set_name.") end, "UpdateAccount")
nk.register_rt_before(before_chat, "ChannelMessageSend")
nk.register_rt_before(before_chat_update, "ChannelMessageUpdate")

nk.logger_info("Gravelight module loaded")
