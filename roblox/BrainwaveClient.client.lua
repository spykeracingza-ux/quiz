-- Brainwave (Roblox) — client
-- Lives in StarterPlayer > StarterPlayerScripts. Builds the whole quiz UI in code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Q = require(ReplicatedStorage:WaitForChild("BrainwaveQuestions"))
local Api = ReplicatedStorage:WaitForChild("BrainwaveRemotes"):WaitForChild("Api")

---------------------------------------------------------------- style
local C = {
	bg = Color3.fromRGB(13, 27, 42), card = Color3.fromRGB(23, 46, 70), deep = Color3.fromRGB(13, 27, 42),
	line = Color3.fromRGB(37, 66, 95), ink = Color3.fromRGB(238, 243, 248), muted = Color3.fromRGB(157, 176, 196),
	accent = Color3.fromRGB(255, 122, 138), accent2 = Color3.fromRGB(255, 180, 162), dark = Color3.fromRGB(42, 11, 18),
	c = Color3.fromRGB(62, 207, 142), u = Color3.fromRGB(74, 168, 255), r = Color3.fromRGB(192, 132, 252),
	x = Color3.fromRGB(91, 107, 124), danger = Color3.fromRGB(255, 93, 108),
}
local TIERNAME = { c = "Common", u = "Uncommon", r = "Rare", x = "No points" }
local HEX = { c = "#3ecf8e", u = "#4aa8ff", r = "#c084fc" }
local BOLD = Enum.Font.GothamBold
local MED = Enum.Font.GothamMedium
local REG = Enum.Font.Gotham

local function make(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, ch in ipairs(children or {}) do ch.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(r) return make("UICorner", { CornerRadius = UDim.new(0, r or 14) }) end
local function stroke(col) return make("UIStroke", { Color = col or C.line, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function pad(n) return make("UIPadding", { PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n), PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n) }) end
local function list(gap, align)
	return make("UIListLayout", { Padding = UDim.new(0, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Center })
end

local order = 0
local function nextOrder() order += 1 return order end

local function label(text, size, font, color, props)
	local p = {
		BackgroundTransparency = 1, Text = text, TextSize = size or 16, Font = font or REG,
		TextColor3 = color or C.ink, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(),
	}
	for k, v in pairs(props or {}) do p[k] = v end
	return make("TextLabel", p)
end

local function button(text, primary, props)
	local p = {
		Text = text, TextSize = 18, Font = BOLD, AutoButtonColor = true,
		BackgroundColor3 = primary and C.accent or C.card, TextColor3 = primary and C.dark or C.ink,
		Size = UDim2.new(1, 0, 0, 50), LayoutOrder = nextOrder(),
	}
	for k, v in pairs(props or {}) do p[k] = v end
	local b = make("TextButton", p, { corner(14) })
	if not primary then stroke().Parent = b end
	return b
end

local function card(parent, props)
	local p = {
		BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(), Parent = parent,
	}
	for k, v in pairs(props or {}) do p[k] = v end
	return make("Frame", p, { corner(18), stroke(), pad(18), list(10) })
end

---------------------------------------------------------------- root
local gui = make("ScreenGui", { Name = "Brainwave", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
make("Frame", { BackgroundColor3 = C.bg, Size = UDim2.fromScale(1, 1), Parent = gui }, {
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(29, 59, 92), C.bg) }),
})

local shell = make("ScrollingFrame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line, BorderSizePixel = 0, Parent = gui,
}, { make("UIPadding", { PaddingTop = UDim.new(0, 54), PaddingBottom = UDim.new(0, 40) }) })

local col = make("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(1, -28, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = shell,
}, { make("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }), list(14) })

-- header
local header = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder(), Parent = col })
make("TextLabel", {
	BackgroundTransparency = 1, RichText = true, Font = BOLD, TextSize = 28, TextColor3 = C.ink,
	Text = 'Brain<font color="#ff7a8a">wave</font>', Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
local whoLabel = make("TextLabel", {
	BackgroundTransparency = 1, Font = MED, TextSize = 13, TextColor3 = C.muted, Text = player.DisplayName,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
})

local screens = {}
local function screen(name)
	local f = make("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 100, Visible = false, Parent = col }, { list(14) })
	screens[name] = f
	return f
end
local function show(name)
	for n, f in pairs(screens) do f.Visible = (n == name) end
	shell.CanvasPosition = Vector2.new()
end

local function call(action, arg)
	local ok, res = pcall(function() return Api:InvokeServer(action, arg) end)
	if not ok or type(res) ~= "table" then return { error = "Couldn't reach the server" } end
	return res
end

local profile = nil

---------------------------------------------------------------- AGE screen
local ageScreen = screen("Age")
local ageCard = card(ageScreen)
label("How old are you?", 26, BOLD, C.ink, { Parent = ageCard })
label("Questions are picked to suit your age. You can change this later.", 15, REG, C.muted, { Parent = ageCard })
local ageGrid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = ageCard }, {
	make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 96), CellPadding = UDim2.new(0, 12, 0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local ageError = label("", 14, MED, C.danger, { Parent = ageCard })
local goHome -- forward declaration

for i, key in ipairs(Q.ORDER) do
	local a = Q.AGES[key]
	local b = make("TextButton", { Text = "", BackgroundColor3 = C.deep, LayoutOrder = i, AutoButtonColor = true, Parent = ageGrid }, { corner(14), stroke(), pad(10), list(2, Enum.HorizontalAlignment.Left) })
	label(a.emoji, 26, BOLD, C.ink, { Parent = b })
	label(a.name, 17, BOLD, C.ink, { Parent = b })
	label(a.range, 13, REG, C.muted, { Parent = b })
	b.Activated:Connect(function()
		local res = call("setAge", key)
		if res.error then ageError.Text = res.error return end
		profile = res.profile
		goHome()
	end)
end

---------------------------------------------------------------- HOME screen
local home = screen("Home")
local heroCard = card(home)
local ageBadge = label("", 13, MED, C.muted, { Parent = heroCard })
local hello = label("", 28, BOLD, C.ink, { Parent = heroCard })
local sub = label("", 15, REG, C.muted, { Parent = heroCard })
local playBtn = button("Play today's round", true, { Parent = heroCard })
local practiceBtn = button("Practice round", false, { Parent = heroCard })
local changeAgeBtn = button("Change age group", false, { Parent = heroCard, Size = UDim2.new(1, 0, 0, 40), TextSize = 15 })
local homeError = label("", 14, MED, C.danger, { Parent = heroCard })

local statsRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70), LayoutOrder = nextOrder(), Parent = heroCard }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local statVals = {}
for i, name in ipairs({ "Streak", "Best", "Days played" }) do
	local f = make("Frame", { BackgroundColor3 = C.deep, Size = UDim2.new(1 / 3, -7, 1, 0), LayoutOrder = i, Parent = statsRow }, { corner(12) })
	statVals[name] = make("TextLabel", { BackgroundTransparency = 1, Font = BOLD, TextSize = 24, TextColor3 = C.ink, Text = "0", Size = UDim2.new(1, 0, 0.6, 0), Parent = f })
	make("TextLabel", { BackgroundTransparency = 1, Font = MED, TextSize = 11, TextColor3 = C.muted, Text = string.upper(name), Position = UDim2.new(0, 0, 0.58, 0), Size = UDim2.new(1, 0, 0.35, 0), Parent = f })
end
local resetBtn = button("Reset my daily round (test)", false, { Parent = heroCard, Size = UDim2.new(1, 0, 0, 38), TextSize = 14, TextColor3 = C.accent2, Visible = false })

local lbCard = card(home)
label("Today's leaderboard", 20, BOLD, C.ink, { Parent = lbCard })
local tabs = make("Frame", { BackgroundColor3 = C.deep, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder(), Parent = lbCard }, {
	corner(12), pad(4), make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local tabMine = make("TextButton", { Text = "My age", Font = BOLD, TextSize = 14, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.card, TextColor3 = C.ink, LayoutOrder = 1, Parent = tabs }, { corner(9) })
local tabAll = make("TextButton", { Text = "Everyone", Font = BOLD, TextSize = 14, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.deep, TextColor3 = C.muted, LayoutOrder = 2, Parent = tabs }, { corner(9) })
local lbSub = label("", 13, REG, C.muted, { Parent = lbCard })
local lbList = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = lbCard }, { list(0) })

local scoreCard = card(home)
label("How scoring works", 18, BOLD, C.ink, { Parent = scoreCard })
label(string.format('<font color="%s">■ Common +10</font>   <font color="%s">■ Uncommon +25</font>   <font color="%s">■ Rare +50</font>', HEX.c, HEX.u, HEX.r), 14, MED, C.ink, { Parent = scoreCard, RichText = true })
label("Every prompt has lots of right answers — the rarer yours is, the more it scores. Small spelling slips are fine, and if your answer isn't on the list you get one more try. Beat the clock!", 14, REG, C.muted, { Parent = scoreCard })

local lbScope = "mine"
local lbToken = 0

local function renderBoard(rows)
	for _, ch in ipairs(lbList:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	if #rows == 0 then
		label("No scores yet today — be the first!", 15, REG, C.muted, { Parent = lbList })
		return
	end
	local medals = { "🥇", "🥈", "🥉" }
	for i, r in ipairs(rows) do
		local me = r.userId == player.UserId
		local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, Parent = lbList })
		make("TextLabel", {
			BackgroundTransparency = 1, Font = me and BOLD or MED, TextSize = 16, TextColor3 = me and C.accent2 or C.ink,
			Text = (medals[i] or (i .. ".")) .. "  " .. r.name, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.75, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
		})
		make("TextLabel", {
			BackgroundTransparency = 1, Font = BOLD, TextSize = 17, TextColor3 = me and C.accent2 or C.ink, Text = tostring(r.score),
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.25, 0, 1, 0), Parent = row,
		})
		if i < #rows then
			make("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), Parent = row })
		end
	end
end

local function loadBoard()
	lbToken += 1
	local token = lbToken
	local scopeName = (lbScope == "all") and "All age groups" or (profile and profile.age and Q.AGES[profile.age].name or "")
	lbSub.Text = scopeName .. " · Round #" .. (profile and profile.dayNum or "")
	local res = call("leaderboard", lbScope)
	if token ~= lbToken then return end
	if res.rows then renderBoard(res.rows) end
end

local function setTab(scope)
	lbScope = scope
	tabMine.BackgroundColor3 = scope == "mine" and C.card or C.deep
	tabMine.TextColor3 = scope == "mine" and C.ink or C.muted
	tabAll.BackgroundColor3 = scope == "all" and C.card or C.deep
	tabAll.TextColor3 = scope == "all" and C.ink or C.muted
	task.spawn(loadBoard)
end
tabMine.Activated:Connect(function() setTab("mine") end)
tabAll.Activated:Connect(function() setTab("all") end)

-- refresh the board every 20 s while home is open
task.spawn(function()
	while true do
		task.wait(20)
		if screens.Home.Visible and profile then loadBoard() end
	end
end)

function goHome()
	homeError.Text = ""
	if not profile.age then show("Age") return end
	local a = Q.AGES[profile.age]
	ageBadge.Text = a.emoji .. "  " .. a.name .. " · " .. a.range
	local done = profile.doneToday
	hello.Text = done and ("Nice one, " .. player.DisplayName .. "!") or ("Ready, " .. player.DisplayName .. "?")
	sub.Text = done and ("You scored " .. tostring(profile.todayScore) .. " on Round #" .. profile.dayNum .. ". A new round drops at 02:00 SA time.")
		or ("Round #" .. profile.dayNum .. " — 7 prompts against the clock. Go rare or go home.")
	playBtn.Text = done and "Today's round done ✓" or "Play today's round"
	playBtn.Active = not done
	playBtn.AutoButtonColor = not done
	playBtn.BackgroundColor3 = done and C.line or C.accent
	statVals["Streak"].Text = tostring(profile.streak or 0)
	statVals["Best"].Text = tostring(profile.best or 0)
	statVals["Days played"].Text = tostring(profile.days or 0)
	resetBtn.Visible = profile.canReset == true
	show("Home")
	task.spawn(loadBoard)
end

---------------------------------------------------------------- GAME screen
local game_ = screen("Game")
local progress = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8), LayoutOrder = nextOrder(), Parent = game_ }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local pips = {}
for i = 1, 7 do
	pips[i] = make("Frame", { BackgroundColor3 = C.line, Size = UDim2.new(1 / 7, -6, 1, 0), LayoutOrder = i, Parent = progress }, { corner(6) })
end

local gCard = card(game_)
local topRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextOrder(), Parent = gCard })
local gLabel = make("TextLabel", { BackgroundTransparency = 1, Font = MED, TextSize = 13, TextColor3 = C.muted, Text = "", Size = UDim2.new(0.75, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = topRow })
local gTime = make("TextLabel", { BackgroundTransparency = 1, Font = BOLD, TextSize = 15, TextColor3 = C.ink, Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.25, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = topRow })
local barBack = make("Frame", { BackgroundColor3 = C.line, Size = UDim2.new(1, 0, 0, 8), LayoutOrder = nextOrder(), Parent = gCard }, { corner(6) })
local barFill = make("Frame", { BackgroundColor3 = C.accent, Size = UDim2.fromScale(1, 1), Parent = barBack }, { corner(6) })
local gPrompt = label("", 28, BOLD, C.ink, { Parent = gCard })

local answerArea = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = gCard }, { list(10) })
local input = make("TextBox", {
	PlaceholderText = "Type your answer…", Text = "", ClearTextOnFocus = false, Font = MED, TextSize = 18,
	TextColor3 = C.ink, PlaceholderColor3 = C.muted, BackgroundColor3 = C.deep, Size = UDim2.new(1, 0, 0, 52),
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), Parent = answerArea,
}, { corner(12), stroke(), make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
local hint = label("", 14, MED, C.accent2, { Parent = answerArea })
local btnRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = nextOrder(), Parent = answerArea }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local skipBtn = button("Skip", false, { Parent = btnRow, Size = UDim2.new(1 / 3, -5, 1, 0), LayoutOrder = 1 })
local goBtn = button("Lock it in", true, { Parent = btnRow, Size = UDim2.new(2 / 3, -5, 1, 0), LayoutOrder = 2 })

local resultArea = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Visible = false, Parent = gCard }, { list(10) })
local tierBox = make("Frame", { BackgroundColor3 = C.deep, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = resultArea }, { corner(14), pad(14), list(4) })
local tierSmall = label("", 15, MED, C.ink, { Parent = tierBox, TextXAlignment = Enum.TextXAlignment.Center })
local tierBig = label("", 24, BOLD, C.ink, { Parent = tierBox, TextXAlignment = Enum.TextXAlignment.Center })
local revealText = label("", 14, REG, C.ink, { Parent = resultArea, RichText = true })
local nextBtn = button("Next", true, { Parent = resultArea })

local round = nil
local timerToken = 0
local busy = false

local function esc(s)
	return (string.gsub(s or "", "[<>&\"']", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;", ['"'] = "&quot;", ["'"] = "&apos;" }))
end

local submit -- forward

local function startTimer(seconds)
	timerToken += 1
	local token = timerToken
	local deadline = os.clock() + seconds
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = C.accent
	task.spawn(function()
		while token == timerToken do
			local left = math.max(0, deadline - os.clock())
			gTime.Text = "⏱ " .. math.ceil(left) .. "s"
			barFill.Size = UDim2.fromScale(left / seconds, 1)
			barFill.BackgroundColor3 = left <= 5 and C.danger or C.accent
			if left <= 0 and not busy then
				submit(true)
				return
			end
			task.wait(0.1)
		end
	end)
end
local function stopTimer() timerToken += 1 end

local function showQuestion(q)
	round.index = q.index
	for i = 1, 7 do
		pips[i].BackgroundColor3 = (i < q.index) and C.accent or (i == q.index and C.accent2 or C.line)
	end
	gLabel.Text = (q.daily and ("Round #" .. q.dayNum) or "Practice") .. " · " .. q.index .. " of " .. q.total .. " · " .. q.score .. " pts"
	gPrompt.Text = q.q .. "…"
	input.Text = ""
	hint.Text = ""
	answerArea.Visible = true
	resultArea.Visible = false
	busy = false
	startTimer(q.time)
	task.defer(function() input:CaptureFocus() end)
end

local function showResult(res)
	stopTimer()
	answerArea.Visible = false
	resultArea.Visible = true
	local t = res.tier
	tierBox.BackgroundColor3 = C.deep
	tierBig.TextColor3 = C[t]
	tierSmall.Text = res.show or (res.timeout and "Out of time ⏰" or "Not on the list")
	tierBig.Text = (t == "x") and "No points" or (TIERNAME[t] .. " +" .. res.points)
	local rv = res.reveal
	local more = (rv.more > 0) and ('  <font color="#9db0c4">+' .. rv.more .. " more</font>") or ""
	revealText.Text = string.format(
		'<b><font color="%s">COMMON</font></b>  %s\n<b><font color="%s">UNCOMMON</font></b>  %s\n<b><font color="%s">RARE</font></b>  %s%s',
		HEX.c, esc(table.concat(rv.c, ", ")), HEX.u, esc(table.concat(rv.u, ", ")), HEX.r, esc(table.concat(rv.r, ", ")), more)
	gLabel.Text = string.gsub(gLabel.Text, "%d+ pts$", res.score .. " pts")
	nextBtn.Text = res.last and "See my score" or "Next"
	round.last = res.last
end

function submit(timeout, skip)
	if busy or not round then return end
	local text = input.Text
	if not timeout and not skip and string.gsub(text, "%s", "") == "" then return end
	busy = true
	if timeout or skip then stopTimer() end
	local res = call("answer", { text = text, timeout = timeout == true, skip = skip == true })
	if res.error then
		hint.Text = res.error
		busy = false
		return
	end
	if res.retry then
		hint.Text = "Hmm, that's not on our list — one more try!"
		input.Text = ""
		busy = false
		task.defer(function() input:CaptureFocus() end)
		return
	end
	showResult(res)
end

goBtn.Activated:Connect(function() submit(false) end)
skipBtn.Activated:Connect(function() submit(false, true) end)
input.FocusLost:Connect(function(enter)
	if enter and answerArea.Visible then submit(false) end
end)

---------------------------------------------------------------- END screen
local endScreen = screen("End")
local eCard = card(endScreen)
local eLabel = label("", 13, MED, C.muted, { Parent = eCard, TextXAlignment = Enum.TextXAlignment.Center })
local eScore = label("0", 64, BOLD, C.accent, { Parent = eCard, TextXAlignment = Enum.TextXAlignment.Center })
label("out of 350", 13, REG, C.muted, { Parent = eCard, TextXAlignment = Enum.TextXAlignment.Center })
local squares = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), Parent = eCard }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local sq = {}
for i = 1, 7 do sq[i] = make("Frame", { BackgroundColor3 = C.x, Size = UDim2.fromOffset(32, 32), LayoutOrder = i, Parent = squares }, { corner(7) }) end
local eMsg = label("", 15, REG, C.muted, { Parent = eCard, TextXAlignment = Enum.TextXAlignment.Center })
local eHome = button("Back home", true, { Parent = eCard })
local eListCard = card(endScreen)
label("Your answers", 18, BOLD, C.ink, { Parent = eListCard })
local eList = label("", 14, REG, C.ink, { Parent = eListCard, RichText = true })

local function finishRound()
	local res = call("finish")
	if res.error then
		hint.Text = res.error
		return
	end
	profile = res.profile or profile
	eLabel.Text = res.daily and ("Round #" .. profile.dayNum .. " · " .. Q.AGES[profile.age].name) or "Practice round"
	eScore.Text = tostring(res.score)
	local rares = 0
	for i, t in ipairs(res.tiers) do
		sq[i].BackgroundColor3 = C[t]
		if t == "r" then rares += 1 end
	end
	local msg
	if res.score >= 250 then msg = "Legendary. Your brain lives off the beaten track."
	elseif rares >= 2 then msg = rares .. " rare answers — proper deep cuts!"
	elseif res.score >= 120 then msg = "Solid round! Try going rarer tomorrow."
	else msg = "Every round makes you sharper. Go again tomorrow!" end
	if res.daily then msg ..= res.saved and "  Score saved ✓" or "  (You'd already played today, so this didn't count.)" end
	eMsg.Text = msg
	local lines = {}
	for _, r in ipairs(res.results) do
		local colr = HEX[r.tier] or "#9db0c4"
		local ans = r.show and esc(r.show) or '<font color="#9db0c4">no points</font>'
		table.insert(lines, string.format('<font color="%s">■</font> <b>%s</b> — %s', colr, esc(r.q), ans))
	end
	eList.Text = table.concat(lines, "\n")
	round = nil
	show("End")
end

nextBtn.Activated:Connect(function()
	if not round or busy then return end
	busy = true
	if round.last then
		finishRound()
		busy = false
		return
	end
	local res = call("next")
	if res.error then hint.Text = res.error busy = false return end
	showQuestion(res.question)
end)

eHome.Activated:Connect(function() goHome() end)

---------------------------------------------------------------- start / buttons
local function startRound(daily)
	homeError.Text = ""
	local res = call("start", daily)
	if res.error then homeError.Text = res.error return end
	round = { daily = daily }
	show("Game")
	showQuestion(res.question)
end

playBtn.Activated:Connect(function()
	if profile and not profile.doneToday then startRound(true) end
end)
practiceBtn.Activated:Connect(function() startRound(false) end)
changeAgeBtn.Activated:Connect(function()
	ageError.Text = ""
	show("Age")
end)
resetBtn.Activated:Connect(function()
	local res = call("resetToday")
	if res.error then homeError.Text = res.error return end
	profile = res.profile
	goHome()
end)

---------------------------------------------------------------- boot
local loading = label("Loading…", 18, MED, C.muted, { Parent = col, LayoutOrder = 99, TextXAlignment = Enum.TextXAlignment.Center })
local res
for attempt = 1, 5 do
	res = call("profile")
	if res.profile then break end
	task.wait(2)
end
loading:Destroy()
if res and res.profile then
	profile = res.profile
	whoLabel.Text = player.DisplayName
	goHome()
else
	label("Couldn't load your profile. Please rejoin.", 16, MED, C.danger, { Parent = col, TextXAlignment = Enum.TextXAlignment.Center })
end
