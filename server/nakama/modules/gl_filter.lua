--[[
Text checks for everything players type: names, clan names, clan
descriptions and chat. Words on the block list are masked (chat) or refused
(names). Links and contact details are refused everywhere: they are how spam
and grooming start, and Apple's rules for user content expect us to stop them.

The list is short on purpose and matched on a squashed copy of the text
(lower case, leetspeak undone, repeats and separators removed), which catches
"f.u.c.k" and "fuuuck" without a huge list. Extend BLOCK as reports come in.
]]

local M = {}

-- Stems: a word containing one of these is blocked.
local BLOCK = {
	"fuck", "shit", "cunt", "bitch", "whore", "slut", "dick", "cock", "pussy",
	"nigg", "nigga", "fag", "retard", "rape", "nazi", "hitler", "kys",
	"killyourself", "porn", "penis", "vagina", "asshole", "bastard", "twat",
	"wank", "spic", "chink", "kike", "tranny", "molest", "pedo",
}

-- Whole words only: too short or too common to match inside other words.
local BLOCK_WORDS = { ["ass"] = true, ["cum"] = true, ["sex"] = true, ["fag"] = true, ["hoe"] = true }

local LEET = { ["0"] = "o", ["1"] = "i", ["3"] = "e", ["4"] = "a", ["5"] = "s", ["7"] = "t", ["8"] = "b", ["@"] = "a", ["$"] = "s", ["!"] = "i", ["|"] = "l", ["+"] = "t" }

-- Runs of one letter cut to one ("fuuuck" -> "fuck"). By hand: Nakama's Lua
-- has no back-references in patterns.
local function dedupe(s)
	local out, last = {}, ""
	for i = 1, #s do
		local c = s:sub(i, i)
		if c ~= last then
			out[#out + 1] = c
		end
		last = c
	end
	return table.concat(out)
end

-- Lower case, leet undone, everything but letters dropped, repeats cut.
function M.squash(s)
	s = string.lower(s)
	s = s:gsub(".", function(c) return LEET[c] or c end)
	s = s:gsub("[^a-z]", "")
	return dedupe(s)
end

local DEDUPED = {}
for i, w in ipairs(BLOCK) do
	DEDUPED[i] = dedupe(w)
end

local function stem_hit(sq)
	for _, wsq in ipairs(DEDUPED) do
		if sq:find(wsq, 1, true) then
			return true
		end
	end
	return false
end

-- True when the text holds a blocked word.
function M.is_rude(s)
	if stem_hit(M.squash(s)) then
		return true
	end
	for word in string.lower(s):gmatch("[%a%d@$!|+]+") do
		local sq = M.squash(word)
		if BLOCK_WORDS[sq] or stem_hit(sq) then
			return true
		end
	end
	return false
end

-- Links, emails, handles and phone numbers.
function M.has_contact(s)
	local l = string.lower(s)
	if l:find("https?://") or l:find("www%.") then
		return true
	end
	for _, tld in ipairs({ "com", "net", "org", "gg", "io", "me", "xyz", "co", "app", "ly", "tv", "link" }) do
		if l:find("%a%s*[%.,]%s*" .. tld .. "%f[%A]") or l:find("%a%s+dot%s+" .. tld .. "%f[%A]") then
			return true
		end
	end
	if l:find("[%w%._%-]+@[%w%-]+") and l:find("@[%w%-]+%.") then
		return true
	end
	if l:find("discord") or l:find("snap") and l:find("chat") or l:find("insta") or l:find("telegram") or l:find("whatsapp") then
		return true
	end
	-- Seven or more digits in a row (spaces and dashes allowed) reads as a phone number.
	local digits = l:gsub("[%s%-%.%(%)]", "")
	if digits:find("%d%d%d%d%d%d%d") then
		return true
	end
	return false
end

-- Chat: blocked words become asterisks, word by word, so the rest still reads.
function M.mask(s)
	return (s:gsub("[^%s]+", function(word)
		local sq = M.squash(word)
		if BLOCK_WORDS[sq] or stem_hit(sq) then
			return string.rep("*", math.min(#word, 8))
		end
		return word
	end))
end

-- Trims, folds runs of spaces and drops control characters.
function M.clean(s)
	s = tostring(s or "")
	s = s:gsub("[%c]", " ")
	s = s:gsub("%s+", " ")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

-- A player or clan name: 3 to max characters of letters, digits, spaces,
-- _ - ' and no blocked words. Returns the cleaned name or nil and why.
function M.name(s, max)
	s = M.clean(s)
	local n = utf8 and utf8.len(s) or #s
	if n == nil or n < 3 then
		return nil, "Names need at least 3 letters."
	end
	if n > max then
		return nil, "That name is too long."
	end
	if not s:match("^[%w _%-']+$") then
		return nil, "Use letters, numbers, spaces, - _ and ' only."
	end
	if M.is_rude(s) or M.has_contact(s) then
		return nil, "Pick another name."
	end
	return s
end

return M
