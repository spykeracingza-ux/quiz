-- Brainwave (Roblox) — server
-- Lives in ServerScriptService. Picks the daily prompts, checks every answer on the
-- server (so scores can't be faked), runs the timer, and saves profiles and
-- daily leaderboards in DataStores.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Q = require(ReplicatedStorage:WaitForChild("BrainwaveQuestions"))

local remotes = Instance.new("Folder")
remotes.Name = "BrainwaveRemotes"
remotes.Parent = ReplicatedStorage
local Api = Instance.new("RemoteFunction")
Api.Name = "Api"
Api.Parent = remotes

local ROUND = 7
local MAX_SCORE = 350
local PTS = { c = 10, u = 25, r = 50, x = 0 }
local TIME = { kids = 40, juniors = 30, teens = 25, adults = 20 }
local GRACE = 3 -- seconds of network allowance on the timer
local EPOCH = 1794787200 -- 2026-11-16 00:00 UTC = round #1

local profileStore = DataStoreService:GetDataStore("BrainwaveProfiles_v1")

---------------------------------------------------------------- dates
local function today() return os.date("!%Y-%m-%d") end
local function yesterday() return os.date("!%Y-%m-%d", os.time() - 86400) end
local function dayNum() return math.floor((os.time() - EPOCH) / 86400) + 1 end

---------------------------------------------------------------- matching
local ACCENTS = {
	["á"]="a",["à"]="a",["â"]="a",["ä"]="a",["ã"]="a",["å"]="a",
	["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",
	["í"]="i",["ì"]="i",["î"]="i",["ï"]="i",
	["ó"]="o",["ò"]="o",["ô"]="o",["ö"]="o",["õ"]="o",
	["ú"]="u",["ù"]="u",["û"]="u",["ü"]="u",
	["ç"]="c",["ć"]="c",["č"]="c",["ñ"]="n",["ž"]="z",["š"]="s",
	["É"]="e",["Á"]="a",["Ö"]="o",["Ü"]="u",
}

local function key(s)
	s = string.lower(s)
	for from, to in pairs(ACCENTS) do
		s = string.gsub(s, from, to)
	end
	s = string.gsub(s, "&", " and ")
	s = string.gsub(s, "[%-_%.]", " ")
	s = string.gsub(s, "[^%w%+# ]", "")
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if string.sub(s, 1, 4) == "the " then s = string.sub(s, 5)
	elseif string.sub(s, 1, 3) == "an " then s = string.sub(s, 4)
	elseif string.sub(s, 1, 2) == "a " then s = string.sub(s, 3) end
	s = string.gsub(s, " ", "")
	return s
end

local function stripPlural(x)
	if string.sub(x, -2) == "es" then return string.sub(x, 1, -3) end
	if string.sub(x, -1) == "s" then return string.sub(x, 1, -2) end
	return x
end

local function lev(a, b)
	if math.abs(#a - #b) > 2 then return 9 end
	local prev = {}
	for j = 0, #b do prev[j] = j end
	for i = 1, #a do
		local cur = { [0] = i }
		local ca = string.byte(a, i)
		for j = 1, #b do
			local cost = (ca == string.byte(b, j)) and 0 or 1
			cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
		end
		prev = cur
	end
	return prev[#b]
end

local parsedCache = {}
local function parsePrompt(p)
	if parsedCache[p] then return parsedCache[p] end
	local list = {}
	for _, tier in ipairs({ "c", "u", "r" }) do
		for _, entry in ipairs(p[tier]) do
			local aliases = string.split(entry, "/")
			local keys = {}
			for _, al in ipairs(aliases) do table.insert(keys, key(al)) end
			table.insert(list, { show = aliases[1], tier = tier, keys = keys })
		end
	end
	parsedCache[p] = list
	return list
end

local function judge(p, input)
	local k = key(input)
	if k == "" then return nil end
	local list = parsePrompt(p)
	local sk = stripPlural(k)
	for _, a in ipairs(list) do
		for _, x in ipairs(a.keys) do
			if x == k or stripPlural(x) == sk then return a end
		end
	end
	if #k >= 5 then
		local tol = (#k >= 9) and 2 or 1
		local best, bd = nil, 9
		for _, a in ipairs(list) do
			for _, x in ipairs(a.keys) do
				if #x >= 4 then
					local d = lev(k, x)
					if d < bd then bd, best = d, a end
				end
			end
		end
		if bd <= tol then return best end
	end
	return nil
end

local function reveal(p)
	local out = { c = {}, u = {}, r = {}, more = 0 }
	for _, a in ipairs(parsePrompt(p)) do
		if a.tier == "r" and #out.r >= 6 then
			out.more += 1
		else
			table.insert(out[a.tier], a.show)
		end
	end
	return out
end

---------------------------------------------------------------- picking prompts
local function hash(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 2147483647 end
	return h
end

local function shuffled(t, rng)
	local a = table.clone(t)
	for i = #a, 2, -1 do
		local j = rng:NextInteger(1, i)
		a[i], a[j] = a[j], a[i]
	end
	return a
end

local function pick(age, seed)
	local rng = seed and Random.new(hash(seed)) or Random.new()
	local sa, other = {}, {}
	for _, p in ipairs(Q.BANK[age]) do
		table.insert(p.sa and sa or other, p)
	end
	sa, other = shuffled(sa, rng), shuffled(other, rng)
	local nSa = math.min(#sa, 3 + rng:NextInteger(0, 1)) -- 3 or 4 South Africa prompts
	local chosen = {}
	for i = 1, nSa do table.insert(chosen, sa[i]) end
	for i = 1, ROUND - nSa do table.insert(chosen, other[i]) end
	return shuffled(chosen, rng)
end

---------------------------------------------------------------- profiles
local profiles = {}  -- [player] = profile table
local sessions = {}  -- [player] = current round

local function defaultProfile()
	return { age = nil, best = 0, days = 0, streak = 0, lastDay = nil, todayScore = nil, todayTiers = nil }
end

local function loadProfile(player)
	local data
	for attempt = 1, 3 do
		local ok, res = pcall(function() return profileStore:GetAsync("u" .. player.UserId) end)
		if ok then data = res break end
		task.wait(1)
	end
	local p = defaultProfile()
	if type(data) == "table" then
		for k, v in pairs(data) do p[k] = v end
	end
	return p
end

local function saveProfile(player)
	local p = profiles[player]
	if not p then return end
	pcall(function()
		profileStore:SetAsync("u" .. player.UserId, p)
	end)
end

local function setLeaderstats(player)
	local p = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not (p and ls) then return end
	ls.Today.Value = (p.lastDay == today() and p.todayScore) or 0
	ls.Streak.Value = p.streak or 0
end

local function canReset(player)
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

local function publicProfile(player)
	local p = profiles[player]
	local t = today()
	local streak = p.streak or 0
	if p.lastDay ~= t and p.lastDay ~= yesterday() then streak = 0 end
	return {
		age = p.age, best = p.best, days = p.days, streak = streak,
		doneToday = (p.lastDay == t and p.todayScore ~= nil),
		todayScore = (p.lastDay == t) and p.todayScore or nil,
		dayNum = dayNum(), canReset = canReset(player),
		name = player.DisplayName,
	}
end

---------------------------------------------------------------- leaderboards
local boardCache = {} -- [storeName] = { at = clock, rows = {} }
local nameCache = {}

local function boardName(day, age) return "BW_" .. day .. "_" .. age end

local function writeBoards(player, score)
	local t = today()
	local age = profiles[player].age
	for _, scope in ipairs({ age, "all" }) do
		pcall(function()
			DataStoreService:GetOrderedDataStore(boardName(t, scope)):SetAsync(tostring(player.UserId), score)
		end)
		boardCache[boardName(t, scope)] = nil
	end
end

local function nameFor(userId)
	if nameCache[userId] then return nameCache[userId] end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then nameCache[userId] = plr.DisplayName return plr.DisplayName end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	nameCache[userId] = ok and n or "Player"
	return nameCache[userId]
end

local function readBoard(scope)
	local name = boardName(today(), scope)
	local cached = boardCache[name]
	if cached and os.clock() - cached.at < 20 then return cached.rows end
	local rows = {}
	local ok = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(name):GetSortedAsync(false, scope == "all" and 20 or 10)
		for _, e in ipairs(pages:GetCurrentPage()) do
			local uid = tonumber(e.key)
			table.insert(rows, { userId = uid, name = nameFor(uid), score = e.value })
		end
	end)
	if ok then boardCache[name] = { at = os.clock(), rows = rows } end
	return rows
end

---------------------------------------------------------------- API
local handlers = {}

local function questionPayload(player)
	local s = sessions[player]
	local p = s.prompts[s.i]
	s.tries = 0
	s.deadline = os.clock() + s.time
	return { index = s.i, total = ROUND, q = p.q, time = s.time, score = s.score, daily = s.daily, dayNum = dayNum() }
end

function handlers.profile(player)
	return { ok = true, profile = publicProfile(player) }
end

function handlers.setAge(player, age)
	if type(age) ~= "string" or not Q.AGES[age] then return { error = "Pick an age group" } end
	if sessions[player] then return { error = "Finish your round first" } end
	profiles[player].age = age
	task.spawn(saveProfile, player)
	return { ok = true, profile = publicProfile(player) }
end

function handlers.start(player, daily)
	local p = profiles[player]
	if not p.age then return { error = "Pick an age group first" } end
	daily = daily == true
	if daily and p.lastDay == today() then return { error = "You've already played today's round" } end
	local seed = daily and (today() .. ":" .. p.age) or nil
	sessions[player] = {
		daily = daily, age = p.age, prompts = pick(p.age, seed),
		i = 1, score = 0, tiers = {}, results = {}, time = TIME[p.age] or 25,
	}
	return { ok = true, question = questionPayload(player) }
end

function handlers.answer(player, arg)
	local s = sessions[player]
	if not s or s.answered then return { error = "No question open" } end
	arg = type(arg) == "table" and arg or {}
	local text = type(arg.text) == "string" and string.sub(arg.text, 1, 60) or ""
	local late = os.clock() > s.deadline + GRACE
	local timeout = arg.timeout == true or late
	local p = s.prompts[s.i]
	local hit = (not late) and judge(p, text) or nil

	if not hit and not timeout and text ~= "" and s.tries == 0 and arg.skip ~= true then
		s.tries = 1
		return { ok = true, retry = true }
	end

	local tier = hit and hit.tier or "x"
	s.score += PTS[tier]
	table.insert(s.tiers, tier)
	table.insert(s.results, { q = p.q, show = hit and hit.show or nil, tier = tier })
	s.answered = true
	return {
		ok = true, tier = tier, show = hit and hit.show or nil, points = PTS[tier],
		score = s.score, timeout = timeout and not hit, reveal = reveal(p), last = (s.i == ROUND),
	}
end

function handlers.next(player)
	local s = sessions[player]
	if not s or not s.answered or s.i >= ROUND then return { error = "Nothing to move to" } end
	s.i += 1
	s.answered = false
	return { ok = true, question = questionPayload(player) }
end

function handlers.finish(player)
	local s = sessions[player]
	if not s or #s.tiers < ROUND then return { error = "Round not finished" } end
	sessions[player] = nil
	local p = profiles[player]
	local saved = false
	if s.daily and p.lastDay ~= today() then
		local score = math.clamp(s.score, 0, MAX_SCORE)
		p.streak = (p.lastDay == yesterday()) and ((p.streak or 0) + 1) or 1
		p.lastDay = today()
		p.todayScore = score
		p.todayTiers = table.concat(s.tiers)
		p.days = (p.days or 0) + 1
		p.best = math.max(p.best or 0, score)
		task.spawn(saveProfile, player)
		task.spawn(writeBoards, player, score)
		setLeaderstats(player)
		saved = true
	end
	return { ok = true, score = s.score, tiers = s.tiers, results = s.results, daily = s.daily, saved = saved, profile = publicProfile(player) }
end

function handlers.leaderboard(player, scope)
	local p = profiles[player]
	scope = (scope == "all") and "all" or p.age
	if not scope then return { ok = true, rows = {} } end
	local rows = readBoard(scope)
	-- Show this player's own fresh score straight away, even before the store catches up.
	if p.lastDay == today() and p.todayScore and (scope == "all" or scope == p.age) then
		local found = false
		for _, r in ipairs(rows) do if r.userId == player.UserId then found = true end end
		if not found then
			rows = table.clone(rows)
			table.insert(rows, { userId = player.UserId, name = player.DisplayName, score = p.todayScore })
			table.sort(rows, function(a, b) return a.score > b.score end)
		end
	end
	return { ok = true, rows = rows, scope = scope }
end

function handlers.resetToday(player)
	if not canReset(player) then return { error = "Not allowed" } end
	local p = profiles[player]
	p.lastDay, p.todayScore, p.todayTiers = nil, nil, nil
	sessions[player] = nil
	task.spawn(saveProfile, player)
	for _, scope in ipairs({ p.age or "all", "all" }) do
		pcall(function()
			DataStoreService:GetOrderedDataStore(boardName(today(), scope)):RemoveAsync(tostring(player.UserId))
		end)
		boardCache[boardName(today(), scope)] = nil
	end
	setLeaderstats(player)
	return { ok = true, profile = publicProfile(player) }
end

Api.OnServerInvoke = function(player, action, arg)
	if not profiles[player] then
		local t0 = os.clock()
		while not profiles[player] and os.clock() - t0 < 10 do task.wait(0.2) end
		if not profiles[player] then return { error = "Still loading — try again" } end
	end
	local fn = handlers[action]
	if not fn then return { error = "Unknown action" } end
	local ok, res = pcall(fn, player, arg)
	if not ok then
		warn("[Brainwave]", action, res)
		return { error = "Something went wrong" }
	end
	return res
end

---------------------------------------------------------------- players
local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local todayV = Instance.new("IntValue"); todayV.Name = "Today"; todayV.Parent = ls
	local streakV = Instance.new("IntValue"); streakV.Name = "Streak"; streakV.Parent = ls
	ls.Parent = player

	profiles[player] = loadProfile(player)
	setLeaderstats(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, plr) end

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	profiles[player] = nil
	sessions[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do saveProfile(player) end
end)
