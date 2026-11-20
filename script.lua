local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
if not LP then return end
local pg = LP:WaitForChild("PlayerGui", 15)
if not pg then return end

local Cam = workspace.CurrentCamera
while not Cam do
	Cam = workspace.CurrentCamera
	task.wait()
end

if pg:FindFirstChild("DarkfulBQMStreetUI") then
	pcall(function() pg.DarkfulBQMStreetUI:Destroy() end)
end

local KEYS_URL = "https://raw.githubusercontent.com/ali14almoot-cell/key/refs/heads/main/key"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1573011451206176879/3CIjKfCC-tu197kkXX5DQAd10zYqqQix8r9gdK6GcjEA6JY-MSgovt-ysa4dF3q6Z_Iw"
local SAVE_FILE = "DarkDestroyer_KeyState_" .. tostring(LP.UserId) .. ".json"

local keysDb, activeKey, keyExpireAt, isFetchingKeys = {}, nil, nil, false
local langChosen, lang = false, "ar"
local remoteBannedUsers = {}

local function trim(s)
	return string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1")
end

local function parseStandaloneBanLine(line)
	local prefix, target = string.match(line, "^([%a\216-\219][\216-\219\128-\191%w_%-]*)%s+(.+)$")
	if not prefix or not target then return nil end
	local lpPrefix = string.lower(trim(prefix))
	if lpPrefix == "بان" or lpPrefix == "ban" then
		local cleanTarget = string.lower(trim(target))
		if cleanTarget ~= "" then
			return cleanTarget
		end
	end
	return nil
end

local function isLocalPlayerBanned()
	local myName = string.lower(tostring(LP.Name or ""))
	local myDisplay = string.lower(tostring(LP.DisplayName or ""))
	local myId = tostring(LP.UserId or "")
	return (myName ~= "" and remoteBannedUsers[myName] == true)
		or (myDisplay ~= "" and remoteBannedUsers[myDisplay] == true)
		or (myId ~= "" and remoteBannedUsers[myId] == true)
end

local function enforceBanLock()
	if not isLocalPlayerBanned() then return false end
	activeKey, keyExpireAt = nil, nil
	pcall(function()
		if pg:FindFirstChild("DarkfulBQMStreetUI") then
			pg.DarkfulBQMStreetUI:Destroy()
		end
	end)
	pcall(function()
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
	end)
	return true
end

local DUR_MAP = {
	s = 1, sec = 1, secs = 1,
	m = 60, min = 60, mins = 60,
	h = 3600, hr = 3600, hrs = 3600,
	w = 604800, week = 604800, weeks = 604800,
	mo = 2592000, month = 2592000, months = 2592000,
	y = 31536000, year = 31536000, years = 31536000
}

local function parseDuration(durText)
	local t = string.lower(trim(durText))
	if t == "" then return 86400, false end
	if t == "inf" or t == "infinite" or t == "lifetime" or t == "perm" then return nil, true end
	local num = tonumber(string.match(t, "^(%d+)"))
	local unit = string.match(t, "[a-z]+$") or "d"
	if not num or num <= 0 then return 86400, false end
	return num * (DUR_MAP[unit] or 86400), false
end

local function loadRemoteKeys()
	if isFetchingKeys or type(game.HttpGet) ~= "function" then return end
	isFetchingKeys = true
	pcall(function()
		local ok, raw = pcall(function() return game:HttpGet(KEYS_URL, true) end)
		if ok and type(raw) == "string" and trim(raw) ~= "" then
			local freshKeys, freshBans = {}, {}
			for line in string.gmatch(raw, "[^\r\n]+") do
				local clean = trim(line)
				if clean ~= "" and string.sub(clean, 1, 1) ~= "#" then
					local banTarget = parseStandaloneBanLine(clean)
					if banTarget then
						freshBans[banTarget] = true
					else
						local row, idx = {}, 0
						for p in string.gmatch(clean, "[^|]+") do
							idx += 1
							row[idx] = trim(p)
						end
						if row[1] and row[1] ~= "" then
							freshKeys[string.lower(row[1])] = {
								key = row[1],
								duration = (row[2] and row[2] ~= "") and row[2] or "1d",
								status = (row[3] and row[3] ~= "") and string.lower(row[3]) or "active",
								lockedUser = (row[4] and row[4] ~= "") and row[4] or nil
							}
						end
					end
				end
			end
			keysDb = freshKeys
			remoteBannedUsers = freshBans
		end
	end)
	isFetchingKeys = false
	enforceBanLock()
end
pcall(loadRemoteKeys)
if enforceBanLock() then return end

local function isKeyAllowedForPlayer(entry)
	if not entry.lockedUser or entry.lockedUser == "" then return true end
	local target = string.lower(trim(entry.lockedUser))
	return (string.lower(tostring(LP.Name or "")) == target) or (tostring(LP.UserId or "") == target)
end

local function getHttpFunc()
	if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
	if type(http_request) == "function" then return http_request end
	if type(request) == "function" then return request end
end

local function getRemainingText(ak, exp)
	if not ak then
		return (not langChosen) and "الوقت المتبقي: غير مفعل | LEFT: INACTIVE" or ((lang == "ar") and "الوقت المتبقي: غير مفعل" or "LEFT: INACTIVE")
	end
	if ak.infinite or not exp then
		return (not langChosen) and "الوقت المتبقي: مفتوح | LEFT: LIFETIME" or ((lang == "ar") and "الوقت المتبقي: مفتوح" or "LEFT: LIFETIME")
	end
	local rem = math.max(0, math.floor(exp - os.time()))
	local d, h, m, s = math.floor(rem / 86400), math.floor((rem % 86400) / 3600), math.floor((rem % 3600) / 60), rem % 60
	if not langChosen then
		return d > 0 and string.format("متبقي: %dي %02dس | LEFT: %dd %02dh", d, h, d, h)
			or string.format("متبقي: %02d:%02d:%02d | LEFT: %02d:%02d:%02d", h, m, s, h, m, s)
	end
	local prefix = (lang == "ar") and "الوقت المتبقي: " or "LEFT: "
	return d > 0 and string.format("%s%dي %02dس %02dد", prefix, d, h, m) or string.format("%s%02d:%02d:%02d", prefix, h, m, s)
end

local function sendKeyWebhook(keyUsed, remText)
	local reqFunc = getHttpFunc()
	if not reqFunc or WEBHOOK_URL == "" then return end
	task.spawn(function()
		local payload = {
			content = "**DARK DESTROYER KEY LOG**",
			embeds = {{
				title = "Key Activated",
				color = 15407656,
				fields = {
					{name = "Player", value = tostring(LP.Name) .. " (" .. tostring(LP.UserId) .. ")", inline = true},
					{name = "Key", value = tostring(keyUsed), inline = true},
					{name = "Remaining", value = tostring(remText), inline = true},
					{name = "PlaceId", value = tostring(game.PlaceId), inline = true},
					{name = "JobId", value = tostring(game.JobId), inline = false}
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
			}}
		}
		pcall(function()
			reqFunc({Url = WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)})
		end)
	end)
end

local function readSavedState()
	if type(isfile) == "function" and type(readfile) == "function" then
		local ok, exists = pcall(isfile, SAVE_FILE)
		if ok and exists then
			local rOk, content = pcall(readfile, SAVE_FILE)
			if rOk and type(content) == "string" and content ~= "" then
				local dOk, decoded = pcall(function() return HttpService:JSONDecode(content) end)
				if dOk and type(decoded) == "table" then return decoded end
			end
		end
	end
	return {}
end

local function writeSavedState(tbl)
	if type(writefile) == "function" then
		pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(tbl)) end)
	end
end

local function activateKeyEntry(entry)
	local secs, isInf = parseDuration(entry.duration)
	local state = readSavedState()
	local kLower = string.lower(entry.key)
	local now = os.time()

	if isInf then
		activeKey, keyExpireAt = {key = entry.key, infinite = true}, nil
		state[kLower] = {key = entry.key, infinite = true, expireAt = nil}
		writeSavedState(state)
		return true
	end

	local saved = state[kLower]
	if saved and type(saved.expireAt) == "number" then
		if saved.expireAt > now then
			activeKey, keyExpireAt = {key = entry.key, infinite = false}, saved.expireAt
			return true
		end
		return false, "EXPIRED"
	end

	local exp = now + secs
	activeKey, keyExpireAt = {key = entry.key, infinite = false}, exp
	state[kLower] = {key = entry.key, infinite = false, expireAt = exp}
	writeSavedState(state)
	return true
end

local SG = Instance.new("ScreenGui")
SG.Name = "DarkfulBQMStreetUI"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.DisplayOrder = 100
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = pg

local origLight = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
	FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows
}

local SFX = {click = 6895079853, on = 6042053626, off = 6042053309, tab = 6895079853, open = 6042053626, close = 6042053309, ok = 6026984224, err = 6042053309, save = 6026984224, reset = 6042053309}
local function snd(id, pitch, vol)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume, s.PlaybackSpeed, s.Parent = vol or 2.0, pitch or 1, SG
		s:Play()
		s.Ended:Connect(function() s:Destroy() end)
	end)
end

local function drag(top, gui)
	local d, inp, s0, p0
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			d, s0, p0 = true, i.Position, gui.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end)
		end
	end)
	top.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then inp = i end
	end)
	UIS.InputChanged:Connect(function(i)
		if i == inp and d then
			local delta = i.Position - s0
			gui.Position = UDim2.new(p0.X.Scale, p0.X.Offset + delta.X, p0.Y.Scale, p0.Y.Offset + delta.Y)
		end
	end)
end

local themes = {
	{nameEn = "Crimson Neon", nameAr = "أحمر نيون", accent = Color3.fromRGB(235, 22, 40), soft = Color3.fromRGB(255, 75, 95), dim = Color3.fromRGB(115, 16, 26)},
	{nameEn = "Royal Gold", nameAr = "ذهبي ملكي", accent = Color3.fromRGB(235, 175, 35), soft = Color3.fromRGB(255, 215, 95), dim = Color3.fromRGB(115, 82, 16)},
	{nameEn = "Frost Cyan", nameAr = "سماوي جليدي", accent = Color3.fromRGB(0, 195, 255), soft = Color3.fromRGB(110, 228, 255), dim = Color3.fromRGB(14, 78, 118)},
	{nameEn = "Violet Pulse", nameAr = "بنفسجي نيون", accent = Color3.fromRGB(165, 65, 255), soft = Color3.fromRGB(205, 130, 255), dim = Color3.fromRGB(70, 22, 115)},
	{nameEn = "Toxic Green", nameAr = "أخضر نيون", accent = Color3.fromRGB(25, 225, 115), soft = Color3.fromRGB(105, 255, 165), dim = Color3.fromRGB(15, 95, 50)},
	{nameEn = "Rose Blaze", nameAr = "وردي مشتعل", accent = Color3.fromRGB(245, 55, 145), soft = Color3.fromRGB(255, 125, 185), dim = Color3.fromRGB(115, 20, 68)}
}
local themeIdx, fontIdx = 1, 1
local Accent, SoftAccent, DimAccent = themes[1].accent, themes[1].soft, themes[1].dim
local Dark, Card = Color3.fromRGB(8, 8, 12), Color3.fromRGB(15, 15, 22)

local fontStyles = {
	{nameEn = "Gotham Bold", nameAr = "قوثام عريض", font = Enum.Font.GothamBlack},
	{nameEn = "Code Mono", nameAr = "خط رقمي", font = Enum.Font.Code},
	{nameEn = "Arial Bold", nameAr = "خط واضح", font = Enum.Font.ArialBold}
}
local ActiveFont = fontStyles[1].font

local neonStrokes, animatedGradients, accentTexts, accentFills, scrollBars, styledLabels, activeToggles = {}, {}, {}, {}, {}, {}, {}

local function gradSeq()
	return ColorSequence.new({ColorSequenceKeypoint.new(0, SoftAccent), ColorSequenceKeypoint.new(0.5, Accent), ColorSequenceKeypoint.new(1, DimAccent)})
end

local function tw(obj, props, t, style, dir)
	pcall(function()
		TweenService:Create(obj, TweenInfo.new(t or 0.12, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
	end)
end

local function attachStyle(obj, baseColorFn)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		pcall(function() obj.Font = ActiveFont end)
		styledLabels[#styledLabels + 1] = obj
	end
	if not obj:IsA("TextButton") then return end
	local sc = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", obj)
	sc.Scale = 1
	local st = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", obj)
	st.Color, st.Thickness = Accent, 1.4

	obj.MouseEnter:Connect(function()
		pcall(function()
			tw(sc, {Scale = 1.02}, 0.12)
			tw(st, {Color = SoftAccent, Thickness = 1.8}, 0.12)
			if not activeToggles[obj] then
				local b = baseColorFn and baseColorFn() or Color3.fromRGB(24, 15, 24)
				tw(obj, {BackgroundColor3 = Color3.new(math.min(1, b.R + 0.06), math.min(1, b.G + 0.06), math.min(1, b.B + 0.07))}, 0.12)
			end
		end)
	end)
	obj.MouseLeave:Connect(function()
		pcall(function()
			tw(sc, {Scale = 1}, 0.14)
			tw(st, {Color = Accent, Thickness = 1.4}, 0.14)
			if not activeToggles[obj] then
				tw(obj, {BackgroundColor3 = baseColorFn and baseColorFn() or Color3.fromRGB(24, 15, 24)}, 0.14)
			end
		end)
	end)
	obj.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			pcall(function() tw(sc, {Scale = 0.96}, 0.08) end)
		end
	end)
	obj.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			pcall(function() tw(sc, {Scale = 1}, 0.14, Enum.EasingStyle.Back) end)
		end
	end)
end

local function ui(cls, props, rad, col, thick, isNeon, animBorder, baseColorFn)
	local o = Instance.new(cls)
	for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
	if props.Parent then o.Parent = props.Parent end
	if rad then Instance.new("UICorner", o).CornerRadius = UDim.new(0, rad) end
	if col then
		local st = Instance.new("UIStroke", o)
		st.Color, st.Thickness = col, thick or 1
		if isNeon then
			neonStrokes[#neonStrokes + 1] = st
			if animBorder then
				local g = Instance.new("UIGradient", st)
				g.Color, g.Rotation = gradSeq(), 0
				animatedGradients[#animatedGradients + 1] = g
			end
		end
	end
	attachStyle(o, baseColorFn)
	return o
end

local function paintBtn(b, active)
	if not b then return end
	activeToggles[b] = active
	b.BackgroundColor3 = active and Accent or Color3.fromRGB(24, 13, 21)
end

local TopTimerBar = ui("Frame", {Parent = SG, Size = UDim2.new(0, 300, 0, 34), Position = UDim2.new(0.5, -150, 0, 10), BackgroundColor3 = Dark, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 12}, 10, Accent, 2.0, true, true)
local TopTimerLbl = ui("TextLabel", {Parent = TopTimerBar, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = "الوقت المتبقي: غير مفعل | LEFT: INACTIVE", TextColor3 = SoftAccent, TextSize = 11, Font = ActiveFont, ZIndex = 13})
accentTexts[#accentTexts + 1] = TopTimerLbl
drag(TopTimerBar, TopTimerBar)

local StopSpecTopBtn = ui("TextButton", {Parent = SG, Size = UDim2.new(0, 195, 0, 36), Position = UDim2.new(0.5, -97, 0, 50), BackgroundColor3 = Accent, Text = "إيقاف السبكتيت | STOP SPECTATE", TextColor3 = Color3.new(1, 1, 1), TextSize = 11, Font = ActiveFont, Visible = false, ZIndex = 30}, 10, SoftAccent, 1.8, true, true, function() return Accent end)

local Auth = ui("Frame", {Parent = SG, Size = UDim2.new(0, 356, 0, 216), Position = UDim2.new(0.5, -178, 0.5, -108), BackgroundColor3 = Color3.fromRGB(10, 10, 15), BorderSizePixel = 0, Active = true, Visible = true, ZIndex = 15}, 18, Accent, 2.5, true, true)
local AuthTitle = ui("TextLabel", {Parent = Auth, Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0, 12, 0, 14), BackgroundTransparency = 1, Text = "داركفول // DARK DESTROYER", TextColor3 = SoftAccent, TextSize = 15, Font = ActiveFont, ZIndex = 16})
accentTexts[#accentTexts + 1] = AuthTitle

local Pass = ui("TextBox", {Parent = Auth, Size = UDim2.new(1, -44, 0, 44), Position = UDim2.new(0, 22, 0, 68), BackgroundColor3 = Color3.fromRGB(18, 18, 27), PlaceholderText = "اكتب الرمز هنا | ENTER KEY", PlaceholderColor3 = Color3.fromRGB(135, 135, 150), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = ActiveFont, ClearTextOnFocus = false, ZIndex = 16}, 12, DimAccent, 1.4)

local realPass = ""
Pass:GetPropertyChangedSignal("Text"):Connect(function()
	local t = Pass.Text
	if #t < #realPass then realPass = string.sub(realPass, 1, #t)
	elseif #t > #realPass then
		local added = string.gsub(string.sub(t, #realPass + 1), "%*", "")
		if added ~= "" then realPass = realPass .. added end
	end
	local masked = string.rep("*", #realPass)
	if Pass.Text ~= masked then Pass.Text = masked end
end)

local Enter = ui("TextButton", {Parent = Auth, Size = UDim2.new(1, -44, 0, 44), Position = UDim2.new(0, 22, 0, 128), BackgroundColor3 = Accent, Text = "دخول | ENTER", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = ActiveFont, ZIndex = 16}, 12, nil, nil, nil, nil, function() return Accent end)
accentFills[#accentFills + 1] = Enter

local LangBox = ui("Frame", {Parent = SG, Size = UDim2.new(0, 366, 0, 206), Position = UDim2.new(0.5, -183, 0.5, -103), BackgroundColor3 = Color3.fromRGB(10, 10, 15), BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 18}, 18, Accent, 2.5, true, true)
local LangTitle = ui("TextLabel", {Parent = LangBox, Size = UDim2.new(1, -24, 0, 36), Position = UDim2.new(0, 12, 0, 14), BackgroundTransparency = 1, Text = "اختر اللغة | CHOOSE LANGUAGE", TextColor3 = SoftAccent, TextSize = 14, Font = ActiveFont, ZIndex = 19})
accentTexts[#accentTexts + 1] = LangTitle

local EnBtn = ui("TextButton", {Parent = LangBox, Size = UDim2.new(0, 156, 0, 120), Position = UDim2.new(0, 18, 0, 62), BackgroundColor3 = Color3.fromRGB(22, 28, 48), Text = "ENGLISH", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = ActiveFont, ZIndex = 20}, 12, Accent, 1.5, true, false, function() return Color3.fromRGB(22, 28, 48) end)
local ArBtn = ui("TextButton", {Parent = LangBox, Size = UDim2.new(0, 156, 0, 120), Position = UDim2.new(1, -174, 0, 62), BackgroundColor3 = Color3.fromRGB(16, 68, 36), Text = "عربي سعودي", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = ActiveFont, ZIndex = 20}, 12, Accent, 1.5, true, false, function() return Color3.fromRGB(16, 68, 36) end)

local UpdateCard = ui("Frame", {Parent = SG, Size = UDim2.new(0, 400, 0, 332), Position = UDim2.new(0.5, -200, 0.5, -166), BackgroundColor3 = Color3.fromRGB(11, 10, 17), BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 40}, 18, Accent, 2.5, true, true)
local UpdateHeader = ui("Frame", {Parent = UpdateCard, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Color3.fromRGB(18, 14, 26), ZIndex = 41}, 12, DimAccent, 1.4)
local UpdateTitle = ui("TextLabel", {Parent = UpdateHeader, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = "التحديث الجديد // NEW UPDATE", TextColor3 = SoftAccent, TextSize = 14, Font = ActiveFont, ZIndex = 42})
accentTexts[#accentTexts + 1] = UpdateTitle

local UpdateListHolder = ui("Frame", {Parent = UpdateCard, Size = UDim2.new(1, -24, 0, 206), Position = UDim2.new(0, 12, 0, 64), BackgroundColor3 = Color3.fromRGB(15, 14, 22), ZIndex = 41}, 12, DimAccent, 1.2)
ui("UIListLayout", {Parent = UpdateListHolder, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
ui("UIPadding", {Parent = UpdateListHolder, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})

local updateLineLabels = {}
for idx = 1, 5 do
	local row = ui("Frame", {Parent = UpdateListHolder, Size = UDim2.new(1, 0, 0, 33), BackgroundColor3 = Color3.fromRGB(22, 18, 30), BackgroundTransparency = 0.15, ZIndex = 42}, 8, DimAccent, 1.0)
	local lbl = ui("TextLabel", {Parent = row, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 7, 0, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(245, 245, 250), TextSize = 11, Font = ActiveFont, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 43})
	styledLabels[#styledLabels + 1] = lbl
	updateLineLabels[idx] = lbl
end

local UpdateContinueBtn = ui("TextButton", {Parent = UpdateCard, Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0, 12, 1, -54), BackgroundColor3 = Accent, Text = "متابعة // CONTINUE", TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = ActiveFont, ZIndex = 42}, 11, SoftAccent, 1.5, true, false, function() return Accent end)
accentFills[#accentFills + 1] = UpdateContinueBtn
drag(UpdateCard, UpdateCard)

local Welc = ui("TextLabel", {Parent = SG, Size = UDim2.new(0, 440, 0, 86), Position = UDim2.new(0.5, -220, 0.22, 0), BackgroundColor3 = Color3.fromRGB(12, 9, 16), TextColor3 = SoftAccent, TextSize = 17, Font = ActiveFont, Text = "حياك الله | WELCOME TO DARK DESTROYER", Visible = false, ZIndex = 35}, 16, Accent, 2.5, true, true)
accentTexts[#accentTexts + 1] = Welc

local Main = ui("Frame", {Parent = SG, Size = UDim2.new(0, 404, 0, 560), Position = UDim2.new(0.5, -202, 0.5, -280), BackgroundColor3 = Dark, BorderSizePixel = 0, Visible = false, Active = true, ClipsDescendants = true, ZIndex = 8}, 18, Accent, 2.6, true, true)
local Top = ui("Frame", {Parent = Main, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(18, 12, 20), BackgroundTransparency = 0.15, Active = true, ZIndex = 9}, 18)
local TopTitle = ui("TextLabel", {Parent = Top, Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.new(0, 18, 0, 0), BackgroundTransparency = 1, Text = "داركفول // DD", TextColor3 = SoftAccent, TextSize = 14, Font = ActiveFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10})
accentTexts[#accentTexts + 1] = TopTitle

local KeyBadge = ui("TextLabel", {Parent = Top, Size = UDim2.new(0.45, -8, 1, 0), Position = UDim2.new(0.42, 0, 0, 0), BackgroundTransparency = 1, Text = "LEFT: INACTIVE", TextColor3 = Color3.fromRGB(220, 220, 235), TextSize = 10, Font = ActiveFont, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10})
local Close = ui("TextButton", {Parent = Top, Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0.5, -15), BackgroundColor3 = Accent, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = ActiveFont, ZIndex = 11}, 9, nil, nil, nil, nil, function() return Accent end)
accentFills[#accentFills + 1] = Close

local DeepBanner = ui("Frame", {Parent = Main, Size = UDim2.new(1, -24, 0, 54), Position = UDim2.new(0, 12, 0, 62), BackgroundColor3 = Color3.fromRGB(12, 12, 18), BackgroundTransparency = 0.2, ClipsDescendants = true, ZIndex = 9}, 12, Accent, 1.6, true, true)
local BannerLbl = ui("TextLabel", {Parent = DeepBanner, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "بصمة داركفول // DARK DESTROYER - BQM", TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = ActiveFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10})

local TabBar = ui("Frame", {Parent = Main, Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0, 12, 0, 122), BackgroundColor3 = Color3.fromRGB(14, 14, 22), BackgroundTransparency = 0.15, ZIndex = 9}, 11, DimAccent, 1.4, true, true)
ui("UIListLayout", {Parent = TabBar, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})

local Pages = ui("Frame", {Parent = Main, Size = UDim2.new(1, -24, 1, -176), Position = UDim2.new(0, 12, 0, 170), BackgroundTransparency = 1, ZIndex = 9})

local activeTabBtn = nil
local function page(canvasH)
	local sf = ui("ScrollingFrame", {Parent = Pages, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, canvasH or 760), ScrollBarThickness = 4, ScrollBarImageColor3 = Accent, Visible = false, ZIndex = 9})
	scrollBars[#scrollBars + 1] = sf
	ui("UIListLayout", {Parent = sf, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
	return sf
end

local AimP, GenP, EspP, SetP = page(480), page(440), page(290), page(330)
AimP.Visible = true

local tabs = {}
local function tab(name, p)
	local b = ui("TextButton", {Parent = TabBar, Size = UDim2.new(1 / 4, -5, 1, -8), Position = UDim2.new(0, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(22, 22, 34), BackgroundTransparency = 0.1, Text = name, TextColor3 = Color3.fromRGB(210, 210, 225), TextSize = 10, Font = ActiveFont, ZIndex = 10}, 8, nil, nil, nil, nil, function()
		return (activeTabBtn == b) and Accent or Color3.fromRGB(22, 22, 34)
	end)
	tabs[#tabs + 1] = {b = b, p = p}
	b.MouseButton1Click:Connect(function()
		snd(SFX.tab, 1.25, 1.3)
		activeTabBtn = b
		for _, t in ipairs(tabs) do
			local act = t.p == p
			t.p.Visible, t.b.BackgroundColor3 = act, act and Accent or Color3.fromRGB(22, 22, 34)
			t.b.TextColor3 = act and Color3.new(1, 1, 1) or Color3.fromRGB(185, 185, 200)
		end
	end)
	return b
end

local t0 = tab("ايم بوت | AIM", AimP)
activeTabBtn = t0
t0.BackgroundColor3, t0.TextColor3 = Accent, Color3.new(1, 1, 1)
local t1, t2, t3 = tab("عام | GEN", GenP), tab("كشف | ESP", EspP), tab("اعدادات | SET", SetP)

local Tog = ui("TextButton", {Parent = SG, Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 22, 0.4, 0), BackgroundColor3 = Color3.fromRGB(14, 9, 17), Text = "د م | DD", TextColor3 = SoftAccent, TextSize = 12, Font = ActiveFont, Visible = false, ZIndex = 25}, 999, Accent, 2.5, true, true, function() return Color3.fromRGB(14, 9, 17) end)
accentTexts[#accentTexts + 1] = Tog

local function btn(p, txt)
	return ui("TextButton", {Parent = p, Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Color3.fromRGB(24, 13, 21), BackgroundTransparency = 0.14, Text = txt, TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = ActiveFont, ZIndex = 10}, 10, Accent, 1.4, true, false, function() return Color3.fromRGB(24, 13, 21) end)
end

local sliders = {}
local function sld(p, getLabelFn, mn, mx, def, cb)
	local f = ui("Frame", {Parent = p, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Card, BackgroundTransparency = 0.18, ZIndex = 10}, 10, DimAccent, 1.3)
	local lbl = ui("TextLabel", {Parent = f, Size = UDim2.new(1, -18, 0, 20), Position = UDim2.new(0, 10, 0, 6), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(245, 245, 250), TextSize = 11, Font = ActiveFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11})
	styledLabels[#styledLabels + 1] = lbl
	local bar = ui("TextButton", {Parent = f, Size = UDim2.new(1, -22, 0, 10), Position = UDim2.new(0, 11, 0, 36), BackgroundColor3 = Color3.fromRGB(32, 32, 46), Text = "", AutoButtonColor = false, ZIndex = 11}, 999, nil, nil, nil, nil, function() return Color3.fromRGB(32, 32, 46) end)
	local fill = ui("Frame", {Parent = bar, Size = UDim2.new((def - mn) / (mx - mn), 0, 1, 0), BackgroundColor3 = Accent, BorderSizePixel = 0, ZIndex = 12}, 999)
	accentFills[#accentFills + 1] = fill
	local curVal = def
	local function updLbl() lbl.Text = getLabelFn(curVal) end
	local function setVal(v)
		local r = math.clamp((v - mn) / (mx - mn), 0, 1)
		fill.Size = UDim2.new(r, 0, 1, 0)
		curVal = mn + (mx - mn) * r
		updLbl()
		cb(curVal)
	end
	updLbl()
	sliders[#sliders + 1] = {def = def, setVal = setVal, updLbl = updLbl}
	local act = false
	local function upd(i) setVal(mn + (mx - mn) * math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then act = true; upd(i) end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then act = false end
	end)
	UIS.InputChanged:Connect(function(i)
		if act and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
	end)
end

local SpecListFrame = ui("Frame", {Parent = SG, Size = UDim2.new(0, 265, 0, 315), Position = UDim2.new(0.5, 215, 0.5, -157), BackgroundColor3 = Dark, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 20}, 14, Accent, 2.2, true, true)
local SpecHeader = ui("Frame", {Parent = SpecListFrame, Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Color3.fromRGB(18, 12, 20), Active = true, ZIndex = 21}, 14)
local SpecTitle = ui("TextLabel", {Parent = SpecHeader, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = "قائمة اللاعبين | SPECTATE", TextColor3 = SoftAccent, TextSize = 11, Font = ActiveFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22})
accentTexts[#accentTexts + 1] = SpecTitle
local SpecCloseBtn = ui("TextButton", {Parent = SpecHeader, Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -32, 0.5, -13), BackgroundColor3 = Accent, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 11, Font = ActiveFont, ZIndex = 23}, 7, nil, nil, nil, nil, function() return Accent end)
accentFills[#accentFills + 1] = SpecCloseBtn
local SpecStopBtn = ui("TextButton", {Parent = SpecListFrame, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 48), BackgroundColor3 = Color3.fromRGB(45, 16, 24), Text = "إيقاف السبكتيت | STOP SPECTATE", TextColor3 = Color3.new(1, 1, 1), TextSize = 11, Font = ActiveFont, ZIndex = 22}, 8, Accent, 1.4, true, false, function() return Color3.fromRGB(45, 16, 24) end)
local SpecScroll = ui("ScrollingFrame", {Parent = SpecListFrame, Size = UDim2.new(1, -16, 1, -94), Position = UDim2.new(0, 8, 0, 88), BackgroundTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4, ScrollBarImageColor3 = Accent, ZIndex = 21})
scrollBars[#scrollBars + 1] = SpecScroll
ui("UIListLayout", {Parent = SpecScroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
drag(SpecHeader, SpecListFrame)

local fovV, flyV = 210, 55
local riflePower, rpgPower = 20, 22
local aimModes = {"Normal", "RPG"}
local aimModeIdx = 1
local aimOn, wallAimOn, fovOn, noclipOn, flyOn, jumpOn, brightOn, specOn, stealthOn, hlOn, espOn, wallEspOn, healthEspOn, distEspOn =
	false, false, false, false, false, false, false, false, false, false, false, false, false, false

local function isHoldingRpg()
	local char = LP.Character
	if not char then return false end
	for _, ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") or ch:IsA("Model") then
			local nm = string.lower(tostring(ch.Name or ""))
			if string.find(nm, "rpg", 1, true) or string.find(nm, "rocket", 1, true) or string.find(nm, "launcher", 1, true) then
				return true
			end
		end
	end
	return false
end

local AimB, WallAimB, ModeB, PartB, FovB =
	btn(AimP, "ايم بوت | Aimbot: OFF"), btn(AimP, "خلف الجدار | Wall Aim: OFF"),
	btn(AimP, "نظام التسبيق | Mode: Normal"), btn(AimP, "الهدف | Target: Head"),
	btn(AimP, "دائرة المجال | FOV: OFF")

sld(AimP, function(v) return (not langChosen and "حجم المجال | FOV Size" or ((lang == "ar") and "حجم المجال" or "FOV Size")) .. ": " .. string.format("%.0f", v) end, 50, 450, fovV, function(v) fovV = v end)

local NoclipB, FlyB, JumpB, BrightB, SpecB, StealthB =
	btn(GenP, "اختراق الجدران | Noclip: OFF"), btn(GenP, "طيران + اختراق | Fly: OFF"),
	btn(GenP, "قفز لا نهائي | Inf Jump: OFF"), btn(GenP, "اضاءة كاملة | Fullbright: OFF"),
	btn(GenP, "سبكتيت | Spectate: OFF"), btn(GenP, "وضع الشبح | Stealth: OFF")

sld(GenP, function(v) return (not langChosen and "سرعة الطيران | Fly Speed" or ((lang == "ar") and "سرعة الطيران" or "Fly Speed")) .. ": " .. string.format("%.0f", v) end, 20, 200, flyV, function(v) flyV = v end)

local HlB, EspB, WallEspB, HealthEspB, DistEspB =
	btn(EspP, "تحديد اللاعبين | Highlight: OFF"), btn(EspP, "كشف الاسلحة | Weapons ESP: OFF"),
	btn(EspP, "كشف ورا الجدار | Wall ESP: OFF"), btn(EspP, "كشف الصحة | Health ESP: OFF"),
	btn(EspP, "كشف المسافة | Dist ESP: OFF")

local ShowUpdateB, ThemeB, FontB, SaveB, LoadB, ResetB =
	btn(SetP, "واجهة التحديث الجديد | New Update"), btn(SetP, "الثيم | Theme: Crimson Neon"),
	btn(SetP, "الخط | Font: Gotham Bold"), btn(SetP, "حفظ الاعدادات | Save Config"),
	btn(SetP, "تحميل الاعدادات | Load Config"), btn(SetP, "تصفير الاعدادات | Reset Config")

local BrandInfoLbl = ui("TextLabel", {Parent = SetP, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Card, BackgroundTransparency = 0.18, Text = "DARKFUL // DARK DESTROYER - BQM | SMG: 20 | RPG: 22", TextColor3 = Color3.fromRGB(235, 235, 245), TextSize = 11, Font = ActiveFont, TextWrapped = true, ZIndex = 10}, 10, DimAccent, 1.3)
styledLabels[#styledLabels + 1] = BrandInfoLbl

local parts, pIdx = {"Head", "Body"}, 1

local FovGui = ui("Frame", {Parent = SG, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 6}, 999, Accent, 2.2, true, true)

local MAX_I, MAX_D = 6, 2500
local espMap, infoEspMap, savedCfg, lock, specTarget = {}, {}, nil, nil, nil

local safeKeywords = {"safe", "spawn", "lobby", "peace", "zone", "protect", "shield", "greenzone", "no_pvp", "nopvp", "سلام", "امان", "سباون"}

local function isInSafeOrSpawnZone(char)
	if not char then return false end
	local ok, res = pcall(function()
		local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		if not hrp then return false end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = {char}
		for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(hrp.Position), Vector3.new(8, 8, 8), overlap)) do
			local n = string.lower(tostring(part.Name or ""))
			local pn = part.Parent and string.lower(tostring(part.Parent.Name or "")) or ""
			for _, kw in ipairs(safeKeywords) do
				if string.find(n, kw, 1, true) or string.find(pn, kw, 1, true) then return true end
			end
			if part.Transparency >= 0.85 and part.CanCollide == false and part.Size.Magnitude > 14 then return true end
		end
		return false
	end)
	return ok and res or false
end

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true

local function rayClearToPoint(char, targetPos)
	if not char or not targetPos then return false end
	local ok, res = pcall(function()
		local origin = Cam.CFrame.Position
		local delta = targetPos - origin
		if delta.Magnitude <= 0.4 then return true end
		local excl = {}
		if LP.Character then excl[#excl + 1] = LP.Character end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character and plr.Character ~= char then excl[#excl + 1] = plr.Character end
		end
		visParams.FilterDescendantsInstances = excl
		local hit = workspace:Raycast(origin, delta.Unit * math.max(0, delta.Magnitude - 0.8), visParams)
		return (not hit) or (hit.Instance and hit.Instance:IsDescendantOf(char))
	end)
	return ok and res or false
end

local function isTargetNotBehindWall(char, primaryPart)
	if not char or not primaryPart then return false end
	if rayClearToPoint(char, primaryPart.Position) then return true end
	for _, altName in ipairs({"Head", "HumanoidRootPart"}) do
		local alt = char:FindFirstChild(altName)
		if alt and alt ~= primaryPart and rayClearToPoint(char, alt.Position) then return true end
	end
	return false
end

local function getAimPart(char)
	if parts[pIdx] == "Head" then
		return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	end
	return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end

local function getFloorPointUnderTarget(char, basePos)
	local ok, pos = pcall(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local excl = {}
		if char then excl[#excl + 1] = char end
		if LP.Character then excl[#excl + 1] = LP.Character end
		rayParams.FilterDescendantsInstances = excl
		local hit = workspace:Raycast(basePos + Vector3.new(0, 1.5, 0), Vector3.new(0, -18, 0), rayParams)
		if hit and hit.Position then
			return hit.Position + Vector3.new(0, 0.35, 0)
		end
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			return Vector3.new(basePos.X, hrp.Position.Y - 2.6, basePos.Z)
		end
		return basePos - Vector3.new(0, 2.5, 0)
	end)
	return ok and pos or (basePos - Vector3.new(0, 2.5, 0))
end

local function computeSmartAimPoint(char, targetPart, originPos)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local rawVel = targetPart.AssemblyLinearVelocity
	if rawVel.Magnitude < 0.35 and hrp then
		rawVel = hrp.AssemblyLinearVelocity
	end

	local horizVel = Vector3.new(rawVel.X, 0, rawVel.Z)
	local moveDir = hum and hum.MoveDirection or Vector3.zero
	local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
	if horizVel.Magnitude < 0.75 and flatMove.Magnitude > 0.05 then
		local spdEst = (hum and hum.WalkSpeed and hum.WalkSpeed > 2) and hum.WalkSpeed or 16
		horizVel = flatMove.Unit * spdEst
	end

	local speedMag = horizVel.Magnitude
	local dist = (targetPart.Position - originPos).Magnitude
	local useRpg = (aimModes[aimModeIdx] == "RPG") or isHoldingRpg()

	if useRpg then
		local baseFloor = getFloorPointUnderTarget(char, targetPart.Position)
		if speedMag < 0.6 then
			return baseFloor
		end
		local distFactor = math.clamp(dist / 65, 0.2, 1.35)
		local speedFactor = math.clamp(speedMag / 18, 0.25, 1.55)
		local leadTime = math.clamp((dist / (rpgPower * 8)) * distFactor * speedFactor, 0.01, 0.26)
		local predictedFoot = baseFloor + (horizVel * leadTime)
		return getFloorPointUnderTarget(char, predictedFoot)
	else
		if speedMag < 0.6 then
			local aimPos = targetPart.Position
			if hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) and hrp then
				aimPos = Vector3.new(aimPos.X, hrp.Position.Y + 1.4, aimPos.Z)
			end
			return aimPos
		end

		local distFactor = math.clamp(dist / 80, 0.15, 1.2)
		local speedFactor = math.clamp(speedMag / 20, 0.2, 1.35)
		local leadTime = math.clamp((dist / (riflePower * 26)) * distFactor * speedFactor, 0.005, 0.13)
		local aimPos = targetPart.Position + (horizVel * leadTime)
		if hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) and hrp then
			aimPos = Vector3.new(aimPos.X, hrp.Position.Y + 1.4, aimPos.Z)
		end
		return aimPos
	end
end

local Overlay = Instance.new("Frame")
Overlay.Name, Overlay.Size, Overlay.BackgroundTransparency, Overlay.ZIndex, Overlay.Parent = "Darkful2DEspOverlay", UDim2.new(1, 0, 1, 0), 1, 5, SG

local tiers = {
	omega = Color3.fromRGB(255, 50, 95), legendary = Color3.fromRGB(255, 195, 35), epic = Color3.fromRGB(185, 85, 255),
	rare = Color3.fromRGB(70, 180, 255), uncommon = Color3.fromRGB(85, 235, 125), common = Color3.fromRGB(220, 220, 230)
}

local guns = {"ak47","ak-47","crossbow","rpg","pumpkin launcher","draco","mp5","m16","anaconda","skorpion","scorpion","aug","awp","awm","m249","m24","double barrel","remington","uzi","glock","m4","m4a1","m4a4","ak74","ak-74","scar","famas","galil","hk416","ar15","ar-15","fal","mp7","mp9","mp40","mac","mac10","mac-10","p90","vector","thompson","deagle","desert eagle","revolver","colt","1911","m1911","beretta","m9","usp","tec9","tec-9","shotgun","pump","mossberg","spas","m870","m1014","aa12","saiga","sniper","barrett","m82","m107","m40","m200","intervention","dragunov","svd","kar98","kar98k","rocket","launcher","bazooka","grenade launcher","gun","rifle","pistol","smg","carbine","firearm","minigun"}
local bad = {"ammo","bullet","bullets","shell","shells","arrow","arrows","rocketarrow","mag","magazine","clip","casing","round","rounds","fish","fishing","rod","bait","lure","bucket","bass","coelacanth","dolphinfish","perch","prawn","worm","seed","seeds","soil","fertilizer","water","watering","can","pot","pots","farm","farming","hack","food","drink","heal","med","bandage","potion","sword","katana","blade","dagger","karambit","butterfly","balisong","machete","axe","hatchet","tomahawk","cleaver","scythe","spear","halberd","rapier","sabre","saber","bat","crowbar","pipe","wrench","hammer","mallet","club","pan","shank","shiv","bayonet"}

local function isGun(o)
	if not o or not (o:IsA("Tool") or o:IsA("Model")) then return false end
	local n = string.lower(tostring(o.Name or ""))
	if n == "" or n == "fists" then return false end
	for _, k in ipairs(bad) do if string.find(n, k, 1, true) then return false end end
	for _, w in ipairs(guns) do if string.find(n, w, 1, true) then return true end end
	return false
end

local function normImg(r)
	if type(r) ~= "string" then return nil end
	local num = string.match(r, "rbxassetid://(%d+)") or string.match(r, "id=(%d+)") or string.match(r, "^(%d+)$")
	return (num and tonumber(num) > 1000) and ("rbxassetid://" .. num) or nil
end

local function gunImg(o)
	if not o then return nil end
	if o:IsA("Tool") then
		local t = normImg(o.TextureId)
		if t then return t end
	end
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			local x = normImg(d.Image)
			if x then return x end
		elseif d:IsA("Decal") then
			local x = normImg(d.Texture)
			if x then return x end
		end
	end
end

local function rarCol(o, idx)
	if o then
		local nm = string.lower(tostring(o.Name or ""))
		if string.find(nm, "anaconda", 1, true) or string.find(nm, "m249", 1, true) or string.find(nm, "minigun", 1, true) then return tiers.omega end
		if string.find(nm, "ak47", 1, true) or string.find(nm, "ak-47", 1, true) or string.find(nm, "rpg", 1, true) or string.find(nm, "mp5", 1, true) or string.find(nm, "m16", 1, true) or string.find(nm, "awp", 1, true) then return tiers.legendary end
		if string.find(nm, "aug", 1, true) or string.find(nm, "draco", 1, true) or string.find(nm, "shotgun", 1, true) or string.find(nm, "spas", 1, true) then return tiers.epic end
		if string.find(nm, "uzi", 1, true) or string.find(nm, "glock", 1, true) or string.find(nm, "deagle", 1, true) then return tiers.rare end
	end
	local fb = {tiers.legendary, tiers.epic, tiers.omega, tiers.rare, tiers.uncommon, tiers.common}
	return fb[((idx - 1) % #fb) + 1]
end

local function getEsp(plr)
	if espMap[plr] and espMap[plr].h and espMap[plr].h.Parent then return espMap[plr] end
	local h = Instance.new("Frame")
	h.Size, h.AnchorPoint, h.BackgroundTransparency, h.Visible, h.ZIndex, h.Parent = UDim2.new(0, MAX_I * 74, 0, 38), Vector2.new(0.5, 0.5), 1, false, 5, Overlay
	local layout = Instance.new("UIListLayout", h)
	layout.FillDirection, layout.HorizontalAlignment, layout.VerticalAlignment, layout.Padding = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center, UDim.new(0, 4)

	local slots = {}
	for i = 1, MAX_I do
		local box = Instance.new("Frame")
		box.Size, box.BackgroundColor3, box.BackgroundTransparency, box.BorderSizePixel, box.Visible, box.ZIndex, box.Parent = UDim2.new(0, 70, 0, 26), Color3.fromRGB(13, 13, 20), 0.12, 0, false, 6, h
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)
		local st = Instance.new("UIStroke", box)
		st.Thickness, st.Color = 1.8, tiers.legendary
		local img = Instance.new("ImageLabel")
		img.Size, img.Position, img.BackgroundTransparency, img.ScaleType, img.Visible, img.ZIndex, img.Parent = UDim2.new(1, -4, 1, -4), UDim2.new(0, 2, 0, 2), 1, Enum.ScaleType.Fit, false, 7, box
		local lbl = Instance.new("TextLabel")
		lbl.Size, lbl.Position, lbl.BackgroundTransparency, lbl.TextColor3, lbl.TextSize, lbl.Font, lbl.TextTruncate, lbl.Visible, lbl.ZIndex, lbl.Parent = UDim2.new(1, -4, 1, 0), UDim2.new(0, 2, 0, 0), 1, Color3.new(1, 1, 1), 9, ActiveFont, Enum.TextTruncate.AtEnd, false, 7, box
		styledLabels[#styledLabels + 1] = lbl
		slots[i] = {box = box, st = st, img = img, lbl = lbl}
	end
	espMap[plr] = {h = h, slots = slots}
	return espMap[plr]
end

local function clearInfoEsp(p)
	local d = infoEspMap[p]
	if d then
		pcall(function() if d.lbl then d.lbl:Destroy() end end)
		infoEspMap[p] = nil
	end
end

local function getInfoEsp(plr)
	local cur = infoEspMap[plr]
	if cur and cur.lbl and cur.lbl.Parent then return cur end
	clearInfoEsp(plr)
	local lbl = Instance.new("TextLabel")
	lbl.Size, lbl.AnchorPoint, lbl.BackgroundColor3, lbl.BackgroundTransparency, lbl.TextColor3, lbl.TextSize, lbl.Font, lbl.Visible, lbl.ZIndex, lbl.Parent =
		UDim2.fromOffset(165, 34), Vector2.new(0.5, 1), Color3.fromRGB(12, 12, 20), 0.25, Color3.new(1, 1, 1), 11, ActiveFont, false, 5, Overlay
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 7)
	styledLabels[#styledLabels + 1] = lbl
	infoEspMap[plr] = {lbl = lbl}
	return infoEspMap[plr]
end

local function plrGuns(plr)
	local out, seen = {}, {}
	local function add(o)
		if #out >= MAX_I or not isGun(o) then return end
		local n, k = tostring(o.Name or ""), string.lower(tostring(o.Name or ""))
		if k ~= "" and not seen[k] then
			seen[k] = true
			out[#out + 1] = {o = o, n = n, img = gunImg(o)}
		end
	end
	if plr.Character then for _, c in ipairs(plr.Character:GetChildren()) do add(c) end end
	if plr:FindFirstChild("Backpack") then for _, c in ipairs(plr.Backpack:GetChildren()) do add(c) end end
	return out
end

local function hideAllWeaponsEsp()
	for _, e in pairs(espMap) do
		if e and e.h then
			e.h.Visible = false
			if e.slots then for _, sl in ipairs(e.slots) do if sl and sl.box then sl.box.Visible = false end end end
		end
	end
end

local function clearPlayerHighlights()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("Highlight") then
			pcall(function() p.Character.Highlight:Destroy() end)
		end
	end
end

local function stopSpectate()
	specTarget, specOn, StopSpecTopBtn.Visible = nil, false, false
	pcall(function()
		if LP.Character and LP.Character:FindFirstChild("Humanoid") then Cam.CameraSubject = LP.Character.Humanoid end
	end)
end

Players.PlayerRemoving:Connect(function(p)
	if lock == p then lock = nil end
	if specTarget == p then stopSpectate() end
	clearInfoEsp(p)
	if espMap[p] then
		pcall(function() if espMap[p].h then espMap[p].h:Destroy() end end)
		espMap[p] = nil
	end
end)

local function refreshSpectateList()
	for _, ch in ipairs(SpecScroll:GetChildren()) do
		if ch:IsA("TextButton") then ch:Destroy() end
	end
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			count += 1
			local sel = specOn and specTarget == p
			local itemBtn = ui("TextButton", {
				Parent = SpecScroll, Size = UDim2.new(1, -4, 0, 34),
				BackgroundColor3 = sel and Accent or Color3.fromRGB(24, 15, 26),
				Text = (sel and "▶ " or "") .. p.DisplayName .. " (@" .. p.Name .. ")",
				TextColor3 = Color3.new(1, 1, 1), TextSize = 11, Font = ActiveFont,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22
			}, 8, sel and SoftAccent or DimAccent, 1.3, false, false, function()
				return (specOn and specTarget == p) and Accent or Color3.fromRGB(24, 15, 26)
			end)
			itemBtn.MouseButton1Click:Connect(function()
				snd(SFX.on, 1.15, 1.6)
				specTarget, specOn, StopSpecTopBtn.Visible = p, true, true
				pcall(function()
					if p.Character and p.Character:FindFirstChild("Humanoid") then Cam.CameraSubject = p.Character.Humanoid end
				end)
				refreshSpectateList()
				syncUI()
			end)
		end
	end
	SpecScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(0, count * 40))
end

local function applyTheme()
	local th = themes[themeIdx]
	Accent, SoftAccent, DimAccent = th.accent, th.soft, th.dim
	for _, st in ipairs(neonStrokes) do if st and st.Parent then st.Color = Accent end end
	for _, tx in ipairs(accentTexts) do if tx and tx.Parent then tx.TextColor3 = SoftAccent end end
	for _, fl in ipairs(accentFills) do if fl and fl.Parent then fl.BackgroundColor3 = Accent end end
	for _, sb in ipairs(scrollBars) do if sb and sb.Parent then sb.ScrollBarImageColor3 = Accent end end
	for _, t in ipairs(tabs) do t.b.BackgroundColor3 = (t.b == activeTabBtn) and Accent or Color3.fromRGB(22, 22, 34) end
	for b, act in pairs(activeToggles) do if b and b.Parent then b.BackgroundColor3 = act and Accent or Color3.fromRGB(24, 13, 21) end end
	for _, grad in ipairs(animatedGradients) do if grad and grad.Parent then grad.Color = gradSeq() end end
	ThemeB.Text = not langChosen and ("الثيم | Theme: " .. th.nameEn) or ((lang == "ar") and ("الثيم: " .. th.nameAr) or ("Theme: " .. th.nameEn))
end

local function applyFontStyle()
	local fs = fontStyles[fontIdx]
	ActiveFont = fs.font
	for _, lbl in ipairs(styledLabels) do if lbl and lbl.Parent then pcall(function() lbl.Font = ActiveFont end) end end
	FontB.Text = not langChosen and ("الخط | Font: " .. fs.nameEn) or ((lang == "ar") and ("الخط: " .. fs.nameAr) or ("Font: " .. fs.nameEn))
end

local function applyLang()
	local notes = (lang == "en") and {
		"1. Aimbot tuning + RPG & Normal weapon modes (SMG: 20 | RPG: 22)",
		"2. Movement & core fixes across gameplay",
		"3. Wall ESP added & improved detection",
		"4. Reduced system & script load",
		"5. Less lag & crash protection"
	} or {
		"١. تعديل الايم بوت ووضع خيارين للربج والسلاح العادي (رشاش: 20 | ربج: 22)",
		"٢. تعديل أخطاء المشي والباقي",
		"٣. تعديل وإضافة خيار الكشف ورا الجدار",
		"٤. تخفيف الضغط",
		"٥. تخفيف اللاق والكراش"
	}
	for i = 1, 5 do
		if updateLineLabels[i] then updateLineLabels[i].Text = notes[i] end
	end

	local map = not langChosen and {
		AuthTitle = "داركفول // DARK DESTROYER", Pass = "اكتب الرمز هنا | ENTER KEY", Enter = "دخول | ENTER", LangTitle = "اختر اللغة | CHOOSE LANGUAGE",
		Welc = "حياك الله | WELCOME TO DARK DESTROYER", TopTitle = "داركفول // DD", BannerLbl = "بصمة داركفول // DARK DESTROYER - BQM",
		SpecTitle = "قائمة اللاعبين | SPECTATE", SpecStopBtn = "إيقاف السبكتيت | STOP SPECTATE", StopSpecTopBtn = "إيقاف السبكتيت | STOP SPECTATE",
		Tog = "د م | DD", t0 = "ايم بوت | AIM", t1 = "عام | GEN", t2 = "كشف | ESP", t3 = "اعدادات | SET",
		UpdateTitle = "التحديث الجديد // NEW UPDATE", UpdateContinueBtn = "متابعة // CONTINUE", ShowUpdateB = "التحديث الجديد | New Update",
		SaveB = "حفظ الاعدادات | Save Config", LoadB = "تحميل الاعدادات | Load Config", ResetB = "تصفير الاعدادات | Reset Config"
	} or ((lang == "ar") and {
		AuthTitle = "داركفول // دارك المدمر", Pass = "اكتب الرمز هنا", Enter = "دخول", LangTitle = "اختر اللغة",
		Welc = "حياك الله في دارك المدمر", TopTitle = "داركفول", BannerLbl = "بصمة داركفول // دارك المدمر - BQM",
		SpecTitle = "قائمة اللاعبين", SpecStopBtn = "ستوب سبكتيت", StopSpecTopBtn = "ستوب سبكتيت",
		Tog = "د م", t0 = "ايم بوت", t1 = "عام", t2 = "كشف", t3 = "اعدادات",
		UpdateTitle = "التحديث الجديد", UpdateContinueBtn = "دخول إلى السكربت", ShowUpdateB = "واجهة التحديث الجديد",
		SaveB = "حفظ الاعدادات", LoadB = "تحميل الاعدادات", ResetB = "تصفير الاعدادات"
	} or {
		AuthTitle = "DARKFUL // DARK DESTROYER", Pass = "ENTER KEY", Enter = "ENTER", LangTitle = "CHOOSE LANGUAGE",
		Welc = "WELCOME TO DARK DESTROYER", TopTitle = "DARKFUL // DD", BannerLbl = "DARKFUL BRAND | DARK DESTROYER - BQM",
		SpecTitle = "SPECTATE LIST", SpecStopBtn = "STOP SPECTATE", StopSpecTopBtn = "STOP SPECTATE",
		Tog = "DD", t0 = "AIMBOT", t1 = "GENERAL", t2 = "ESP", t3 = "SETTINGS",
		UpdateTitle = "NEW UPDATE", UpdateContinueBtn = "CONTINUE", ShowUpdateB = "New Update Panel",
		SaveB = "Save Config", LoadB = "Load Config", ResetB = "Reset Config"
	})

	AuthTitle.Text, Pass.PlaceholderText, Enter.Text, LangTitle.Text = map.AuthTitle, map.Pass, map.Enter, map.LangTitle
	Welc.Text, TopTitle.Text, BannerLbl.Text = map.Welc, map.TopTitle, map.BannerLbl
	SpecTitle.Text, SpecStopBtn.Text, StopSpecTopBtn.Text = map.SpecTitle, map.SpecStopBtn, map.StopSpecTopBtn
	Tog.Text, t0.Text, t1.Text, t2.Text, t3.Text = map.Tog, map.t0, map.t1, map.t2, map.t3
	UpdateTitle.Text, UpdateContinueBtn.Text, ShowUpdateB.Text = map.UpdateTitle, map.UpdateContinueBtn, map.ShowUpdateB
	SaveB.Text, LoadB.Text, ResetB.Text = map.SaveB, map.LoadB, map.ResetB

	applyTheme()
	applyFontStyle()
	for _, s in ipairs(sliders) do s.updLbl() end
end

function syncUI()
	if enforceBanLock() then return end
	local t = parts[pIdx]
	local tAr = (t == "Head") and "الرأس" or "الجسم"
	local m = aimModes[aimModeIdx]
	local mAr = (m == "RPG") and "ربج (22)" or "عادي (20)"
	local function lbl(arTxt, enTxt, on)
		if not langChosen then return arTxt .. " | " .. enTxt .. ": " .. (on and "ON" or "OFF") end
		return (lang == "ar") and (arTxt .. ": " .. (on and "شغال" or "طافي")) or (enTxt .. ": " .. (on and "ON" or "OFF"))
	end

	AimB.Text = lbl("ايم بوت", "Aimbot", aimOn)
	WallAimB.Text = lbl("خلف الجدار", "Wall Aim", wallAimOn)
	ModeB.Text = not langChosen and ("التسبيق | Mode: " .. m) or ((lang == "ar") and ("التسبيق: " .. mAr) or ("Mode: " .. m))
	PartB.Text = not langChosen and ("الهدف | Target: " .. t) or ((lang == "ar") and ("الهدف: " .. tAr) or ("Target: " .. t))
	FovB.Text = lbl("دائرة المجال", "FOV Circle", fovOn)
	NoclipB.Text = lbl("اختراق الجدران", "Noclip", noclipOn)
	FlyB.Text = lbl("طيران + اختراق", "Fly + Noclip", flyOn)
	JumpB.Text = lbl("قفز لا نهائي", "Infinite Jump", jumpOn)
	BrightB.Text = lbl("اضاءة كاملة", "Fullbright", brightOn)
	SpecB.Text = specOn and ((not langChosen and "سبكتيت | Spec: " or ((lang == "ar") and "سبكتيت: " or "Spectate: ")) .. (specTarget and specTarget.Name or "ON"))
		or (not langChosen and "سبكتيت | Spectate: OFF" or ((lang == "ar") and "سبكتيت: اختر لاعب" or "Spectate: Select Player"))
	StealthB.Text = lbl("وضع الشبح", "Stealth Mode", stealthOn)
	HlB.Text = lbl("تحديد اللاعبين", "Highlight ESP", hlOn)
	EspB.Text = lbl("كشف الاسلحة", "Weapons ESP", espOn)
	WallEspB.Text = lbl("كشف ورا الجدار", "Wall ESP", wallEspOn)
	HealthEspB.Text = lbl("كشف الصحة", "Health ESP", healthEspOn)
	DistEspB.Text = lbl("كشف المسافة", "Distance ESP", distEspOn)

	StopSpecTopBtn.Visible = specOn and not stealthOn
	FovGui.Visible = fovOn and not stealthOn
	local toggleMap = {
		[AimB] = aimOn, [WallAimB] = wallAimOn, [FovB] = fovOn, [NoclipB] = noclipOn,
		[FlyB] = flyOn, [JumpB] = jumpOn, [BrightB] = brightOn, [SpecB] = specOn,
		[StealthB] = stealthOn, [HlB] = hlOn, [EspB] = espOn, [WallEspB] = wallEspOn,
		[HealthEspB] = healthEspOn, [DistEspB] = distEspOn
	}
	for b, act in pairs(toggleMap) do paintBtn(b, act) end

	applyTheme()
	applyFontStyle()

	if stealthOn then
		Main.Visible, SpecListFrame.Visible, UpdateCard.Visible, TopTimerBar.Visible, StopSpecTopBtn.Visible, Tog.Visible = false, false, false, false, false, true
		hlOn, espOn, wallEspOn, healthEspOn, distEspOn = false, false, false, false, false
		clearPlayerHighlights()
		hideAllWeaponsEsp()
		for p in pairs(infoEspMap) do clearInfoEsp(p) end
	end

	if not specOn and LP.Character and LP.Character:FindFirstChild("Humanoid") and Cam.CameraSubject ~= LP.Character.Humanoid then
		pcall(function() Cam.CameraSubject = LP.Character.Humanoid end)
	end
	if not aimOn then
		lock = nil
	end
	if not brightOn then
		pcall(function()
			Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows =
				origLight.Brightness, origLight.ClockTime, origLight.FogEnd, origLight.GlobalShadows
		end)
	end
	if not hlOn then clearPlayerHighlights() end
	if not espOn then hideAllWeaponsEsp() end
	if not healthEspOn and not distEspOn and not wallEspOn then for p in pairs(infoEspMap) do clearInfoEsp(p) end end
end

local function bindToggle(button, getter, setter)
	button.MouseButton1Click:Connect(function()
		local nv = not getter()
		setter(nv)
		syncUI()
		snd(nv and SFX.on or SFX.off, nv and 1.15 or 0.95, 1.6)
	end)
end

bindToggle(AimB, function() return aimOn end, function(v) aimOn = v end)
bindToggle(WallAimB, function() return wallAimOn end, function(v) wallAimOn = v end)
bindToggle(FovB, function() return fovOn end, function(v) fovOn = v end)
bindToggle(NoclipB, function() return noclipOn end, function(v) noclipOn = v end)
bindToggle(FlyB, function() return flyOn end, function(v)
	flyOn = v
	if not v and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
		pcall(function() LP.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero end)
	end
end)
bindToggle(JumpB, function() return jumpOn end, function(v) jumpOn = v end)
bindToggle(BrightB, function() return brightOn end, function(v) brightOn = v end)
bindToggle(StealthB, function() return stealthOn end, function(v)
	stealthOn = v
	if not v then Main.Visible, TopTimerBar.Visible = true, (activeKey ~= nil) end
end)
bindToggle(HlB, function() return hlOn end, function(v) hlOn = v end)
bindToggle(EspB, function() return espOn end, function(v) espOn = v end)
bindToggle(WallEspB, function() return wallEspOn end, function(v) wallEspOn = v end)
bindToggle(HealthEspB, function() return healthEspOn end, function(v) healthEspOn = v end)
bindToggle(DistEspB, function() return distEspOn end, function(v) distEspOn = v end)

ModeB.MouseButton1Click:Connect(function() aimModeIdx = aimModeIdx % #aimModes + 1; syncUI(); snd(SFX.on, 1.15, 1.5) end)
PartB.MouseButton1Click:Connect(function() pIdx = pIdx % #parts + 1; syncUI(); snd(SFX.on, 1.1, 1.5) end)

SpecB.MouseButton1Click:Connect(function() snd(SFX.click, 1.2, 1.6); refreshSpectateList(); SpecListFrame.Visible = not SpecListFrame.Visible end)
SpecStopBtn.MouseButton1Click:Connect(function() snd(SFX.off, 1.0, 1.5); stopSpectate(); refreshSpectateList(); syncUI() end)
StopSpecTopBtn.MouseButton1Click:Connect(function() snd(SFX.off, 1.0, 1.5); stopSpectate(); refreshSpectateList(); syncUI() end)
SpecCloseBtn.MouseButton1Click:Connect(function() snd(SFX.close, 0.95, 1.5); SpecListFrame.Visible = false end)

ShowUpdateB.MouseButton1Click:Connect(function()
	snd(SFX.click, 1.2, 1.6)
	UpdateCard.Visible = not UpdateCard.Visible
end)

UpdateContinueBtn.MouseButton1Click:Connect(function()
	snd(SFX.open, 1.1, 1.8)
	UpdateCard.Visible = false
	Main.Visible, Tog.Visible = true, true
end)

ThemeB.MouseButton1Click:Connect(function() snd(SFX.click, 1.2, 1.6); themeIdx = (themeIdx % #themes) + 1; applyTheme() end)
FontB.MouseButton1Click:Connect(function() snd(SFX.click, 1.2, 1.6); fontIdx = (fontIdx % #fontStyles) + 1; applyFontStyle() end)

local function finishEntry(chosenLang)
	if enforceBanLock() then return end
	langChosen, lang = true, chosenLang
	applyLang()
	syncUI()
	snd(SFX.ok, 1.05, 2.2)
	LangBox.Visible, Welc.Visible = false, true
	task.wait(0.8)
	Welc.Visible, UpdateCard.Visible, Tog.Visible = false, true, true
	snd(SFX.open, 1.1, 1.8)
end

EnBtn.MouseButton1Click:Connect(function() snd(SFX.click, 1.2, 1.5); finishEntry("en") end)
ArBtn.MouseButton1Click:Connect(function() snd(SFX.click, 1.2, 1.5); finishEntry("ar") end)

local function resetPassPrompt(ph)
	snd(SFX.err, 0.9, 1.8)
	realPass, Pass.Text, Pass.PlaceholderText = "", "", ph
end

local function checkKeyEntry()
	snd(SFX.click, 1.1, 1.5)
	pcall(loadRemoteKeys)
	if enforceBanLock() then return end
	local raw = trim(realPass)
	if raw == "" then raw = trim(Pass.Text) end
	local entry = keysDb[string.lower(trim(string.match(raw, "^([^|]+)") or raw))]
	if entry and entry.status == "active" then
		if not isKeyAllowedForPlayer(entry) then resetPassPrompt("حساب غير مسموح | WRONG ACCOUNT"); return end
		local okAct, reason = activateKeyEntry(entry)
		if okAct then
			local tStr = getRemainingText(activeKey, keyExpireAt)
			KeyBadge.Text, TopTimerLbl.Text, TopTimerBar.Visible = tStr, tStr, true
			sendKeyWebhook(entry.key, tStr)
			realPass, Pass.Text, Auth.Visible, LangBox.Visible = "", "", false, true
			snd(SFX.ok, 1.1, 1.6)
		else
			resetPassPrompt("منتهي | " .. (reason or "EXPIRED"))
		end
	else
		resetPassPrompt("رمز غلط | INVALID KEY")
	end
end

Enter.MouseButton1Click:Connect(checkKeyEntry)
Pass.FocusLost:Connect(function(enter) if enter then checkKeyEntry() end end)

Tog.MouseButton1Click:Connect(function()
	if enforceBanLock() then return end
	if stealthOn then
		stealthOn, Main.Visible, TopTimerBar.Visible = false, true, (activeKey ~= nil)
		syncUI()
		snd(SFX.open, 1.1, 1.8)
		return
	end
	Main.Visible = not Main.Visible
	if not Main.Visible then SpecListFrame.Visible = false; UpdateCard.Visible = false end
	snd(Main.Visible and SFX.open or SFX.close, Main.Visible and 1.1 or 0.95, 1.8)
end)

Close.MouseButton1Click:Connect(function() snd(SFX.close, 0.95, 1.8); Main.Visible, SpecListFrame.Visible, UpdateCard.Visible = false, false, false end)
drag(Top, Main); drag(Auth, Auth); drag(LangBox, LangBox); drag(Tog, Tog)

LP.CharacterAdded:Connect(function()
	if enforceBanLock() then return end
	if specOn then stopSpectate() end
end)

SaveB.MouseButton1Click:Connect(function()
	savedCfg = {
		aimOn = aimOn, wallAimOn = wallAimOn, fovOn = fovOn, noclipOn = noclipOn, flyOn = flyOn, jumpOn = jumpOn, brightOn = brightOn,
		stealthOn = stealthOn, hlOn = hlOn, espOn = espOn, wallEspOn = wallEspOn, healthEspOn = healthEspOn, distEspOn = distEspOn,
		aimModeIdx = aimModeIdx, pIdx = pIdx, themeIdx = themeIdx, fontIdx = fontIdx, fovV = fovV, flyV = flyV
	}
	snd(SFX.save, 1.2, 1.8)
end)

LoadB.MouseButton1Click:Connect(function()
	if not savedCfg then snd(SFX.err, 0.95, 1.5); return end
	aimOn, wallAimOn, fovOn, noclipOn, flyOn, jumpOn, brightOn =
		savedCfg.aimOn or false, savedCfg.wallAimOn or false, savedCfg.fovOn or false, savedCfg.noclipOn or false, savedCfg.flyOn or false, savedCfg.jumpOn or false, savedCfg.brightOn or false
	stealthOn, hlOn, espOn, wallEspOn, healthEspOn, distEspOn =
		savedCfg.stealthOn or false, savedCfg.hlOn or false, savedCfg.espOn or false, savedCfg.wallEspOn or false, savedCfg.healthEspOn or false, savedCfg.distEspOn or false
	aimModeIdx, pIdx, themeIdx, fontIdx = savedCfg.aimModeIdx or 1, savedCfg.pIdx or 1, savedCfg.themeIdx or 1, savedCfg.fontIdx or 1
	fovV, flyV = savedCfg.fovV or 210, savedCfg.flyV or 55
	local vals = {fovV, flyV}
	for idx, s in ipairs(sliders) do if vals[idx] then s.setVal(vals[idx]) end end
	syncUI()
	snd(SFX.save, 1.25, 1.8)
end)

ResetB.MouseButton1Click:Connect(function()
	aimOn, wallAimOn, fovOn, noclipOn, flyOn, jumpOn, brightOn, stealthOn, hlOn, espOn, wallEspOn, healthEspOn, distEspOn =
		false, false, false, false, false, false, false, false, false, false, false, false, false
	stopSpectate()
	aimModeIdx, pIdx, themeIdx, fontIdx = 1, 1, 1, 1
	for _, s in ipairs(sliders) do s.setVal(s.def) end
	syncUI()
	snd(SFX.reset, 0.9, 1.8)
end)

UIS.JumpRequest:Connect(function()
	if jumpOn and LP.Character and LP.Character:FindFirstChild("Humanoid") then
		pcall(function() LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
	end
end)

local function valid(p)
	if not p or p == LP or not p.Parent then return false end
	local char = p.Character
	if not char or not char.Parent or char:FindFirstChildOfClass("ForceField") then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 1 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function evaluateAimCandidate(p, ctr, cp)
	if not valid(p) then return nil end
	local char = p.Character
	if char and isInSafeOrSpawnZone(char) then return nil end
	local targetPart = getAimPart(char)
	if not targetPart then return nil end
	if not wallAimOn and not isTargetNotBehindWall(char, targetPart) then return nil end
	local sp, on = Cam:WorldToViewportPoint(targetPart.Position)
	if not on or sp.Z <= 0 then return nil end
	local screenDist = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
	if screenDist > fovV then return nil end
	local worldDist = (targetPart.Position - cp).Magnitude
	local priorityScore = (screenDist * 0.55) + (worldDist * 1.45)
	return {
		plr = p,
		char = char,
		part = targetPart,
		screenDist = screenDist,
		worldDist = worldDist,
		priorityScore = priorityScore,
		aimPos = computeSmartAimPoint(char, targetPart, cp)
	}
end

local timerTick, infoTick, banPollTick, gradAngle = 0, 0, 0, 0

RunService.RenderStepped:Connect(function(dt)
	local stepDt = math.clamp(dt or 0.016, 0.004, 0.05)
	timerTick, infoTick, banPollTick = timerTick + stepDt, infoTick + stepDt, banPollTick + stepDt
	gradAngle = (gradAngle + stepDt * 75) % 360

	if banPollTick >= 5.0 then
		banPollTick = 0
		task.spawn(loadRemoteKeys)
	end
	if enforceBanLock() then return end

	for i = 1, #animatedGradients do
		local g = animatedGradients[i]
		if g and g.Parent then g.Rotation = gradAngle end
	end

	if timerTick >= 0.5 then
		timerTick = 0
		if activeKey and not activeKey.infinite and keyExpireAt and os.time() >= keyExpireAt then
			activeKey, TopTimerBar.Visible, Main.Visible, SpecListFrame.Visible, UpdateCard.Visible, StopSpecTopBtn.Visible, Tog.Visible, Auth.Visible =
				nil, false, false, false, false, false, false, true
			Pass.PlaceholderText = "منتهي | EXPIRED"
		else
			local tStr = getRemainingText(activeKey, keyExpireAt)
			KeyBadge.Text, TopTimerLbl.Text = tStr, tStr
		end
	end

	pcall(function()
		if not Cam or not Cam.Parent then Cam = workspace.CurrentCamera; if not Cam then return end end

		if specOn then
			if specTarget and specTarget.Parent and specTarget.Character and specTarget.Character:FindFirstChild("Humanoid") then
				Cam.CameraSubject = specTarget.Character.Humanoid
			else
				stopSpectate(); syncUI()
			end
		end

		FovGui.Position, FovGui.Size = UDim2.new(0, Cam.ViewportSize.X / 2, 0, Cam.ViewportSize.Y / 2), UDim2.new(0, fovV * 2, 0, fovV * 2)

		if brightOn then
			Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows = 2, 14, 1000000, false
		end

		if LP.Character then
			local hum = LP.Character:FindFirstChildOfClass("Humanoid")
			local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
			if noclipOn then
				for _, x in ipairs(LP.Character:GetDescendants()) do
					if x:IsA("BasePart") and x.CanCollide then x.CanCollide = false end
				end
			end
			if flyOn and hrp and hum then
				local mv = hum.MoveDirection
				for _, x in ipairs(LP.Character:GetDescendants()) do if x:IsA("BasePart") then x.CanCollide = false end end
				local vy = (mv.Magnitude > 0) and (Cam.CFrame.LookVector.Y * flyV) or 0
				if UIS:IsKeyDown(Enum.KeyCode.Space) then vy = flyV elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vy = -flyV end
				hrp.AssemblyLinearVelocity = Vector3.new(mv.X * flyV, vy, mv.Z * flyV)
			end
		end

		local ctr = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
		local bestCand = nil
		local bestScore = math.huge
		local cp = Cam.CFrame.Position
		local doInfo = (healthEspOn or distEspOn or wallEspOn) and not stealthOn and infoTick >= 0.06
		if doInfo then infoTick = 0 end

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local inSafe = char and isInSafeOrSpawnZone(char)
			local okPlr = valid(p) and not inSafe

			if hlOn and not stealthOn then
				if okPlr then
					local h = char:FindFirstChild("Highlight") or Instance.new("Highlight", char)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.FillColor = (p == lock) and Color3.fromRGB(0, 220, 255) or Accent
					h.FillTransparency = 0.35
					h.OutlineColor = (p == lock) and Color3.fromRGB(0, 255, 255) or Color3.new(1, 1, 1)
				elseif char and char:FindFirstChild("Highlight") then
					char.Highlight:Destroy()
				end
			end

			if p ~= LP and (healthEspOn or distEspOn or wallEspOn) and not stealthOn then
				local info = infoEspMap[p]
				if doInfo then
					if okPlr then
						local anc = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
						local hum = char:FindFirstChildOfClass("Humanoid")
						local dist = anc and (anc.Position - cp).Magnitude or math.huge
						local behindWall = (anc and not rayClearToPoint(char, anc.Position)) or false
						if anc and hum and dist <= MAX_D then
							local sp, on = Cam:WorldToViewportPoint(anc.Position + Vector3.new(0, 2.2, 0))
							if on and sp.Z > 0 then
								info = getInfoEsp(p)
								local lines = {}
								if wallEspOn then
									lines[#lines + 1] = behindWall and ((lang == "ar") and ("وراء جدار: " .. p.DisplayName) or ("WALL: " .. p.DisplayName)) or p.DisplayName
								end
								if healthEspOn then
									local curHp = math.clamp(math.floor(hum.Health), 0, math.floor(math.max(1, hum.MaxHealth)))
									lines[#lines + 1] = (lang == "ar") and ("الصحة: " .. tostring(curHp)) or ("HP: " .. tostring(curHp))
								end
								if distEspOn then
									lines[#lines + 1] = (lang == "ar") and (tostring(math.floor(dist)) .. " م") or (tostring(math.floor(dist)) .. "m")
								end
								info.lbl.Visible = #lines > 0
								if #lines > 0 then
									info.lbl.Position = UDim2.new(0, sp.X, 0, sp.Y)
									info.lbl.Size = UDim2.fromOffset(165, (#lines > 1) and (#lines * 16 + 4) or 20)
									info.lbl.Text = table.concat(lines, "\n")
									info.lbl.TextColor3 = (wallEspOn and behindWall) and SoftAccent or (healthEspOn and Color3.fromRGB(115, 255, 150) or SoftAccent)
								end
							elseif info and info.lbl then info.lbl.Visible = false end
						elseif info and info.lbl then info.lbl.Visible = false end
					elseif info and info.lbl then info.lbl.Visible = false end
				end
			end

			if espOn and not stealthOn then
				local e = espMap[p]
				if okPlr then
					local head, hrp = char:FindFirstChild("Head"), char:FindFirstChild("HumanoidRootPart")
					local anc, hum = head or hrp, char:FindFirstChildOfClass("Humanoid")
					local dist = anc and (anc.Position - cp).Magnitude or math.huge
					local ws = (anc and dist <= MAX_D and (not hum or hum.Health > 1)) and plrGuns(p) or {}
					if #ws > 0 and anc then
						local sp, on = Cam:WorldToViewportPoint(head and (head.Position + Vector3.new(0, 1.35, 0)) or (hrp.Position + Vector3.new(0, 3, 0)))
						e = getEsp(p)
						e.h.Size = UDim2.new(0, math.max(74, #ws * 76), 0, 34)
						if on and sp.Z > 0 and sp.Z <= MAX_D then
							e.h.Visible, e.h.Position = true, UDim2.new(0, sp.X, 0, sp.Y)
							for i = 1, MAX_I do
								local sl, wd = e.slots[i], ws[i]
								if wd then
									sl.box.Visible, sl.st.Color = true, (p == lock) and Color3.fromRGB(0, 220, 255) or rarCol(wd.o, i)
									if wd.img then
										sl.box.Size, sl.img.Visible, sl.img.Image, sl.lbl.Visible = UDim2.new(0, 34, 0, 34), true, wd.img, false
									else
										sl.box.Size, sl.img.Visible, sl.lbl.Visible, sl.lbl.Text = UDim2.new(0, 74, 0, 24), false, true, wd.n
									end
								else
									sl.box.Visible = false
								end
							end
						elseif e and e.h then e.h.Visible = false end
					elseif e and e.h then e.h.Visible = false end
				elseif e and e.h then e.h.Visible = false end
			end

			if aimOn and okPlr then
				local cand = evaluateAimCandidate(p, ctr, cp)
				if cand and cand.priorityScore < bestScore then
					bestScore = cand.priorityScore
					bestCand = cand
				end
			end
		end

		if not espOn or stealthOn then hideAllWeaponsEsp() end

		if aimOn then
			local lockedCand = nil
			if lock then
				lockedCand = evaluateAimCandidate(lock, ctr, cp)
				if not lockedCand then
					lock = nil
				end
			end

			local chosenCand = lockedCand or bestCand
			if chosenCand then
				lock = chosenCand.plr
				local dir = chosenCand.aimPos - Cam.CFrame.Position
				if dir.Magnitude > 0.001 then
					Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, Cam.CFrame.Position + dir.Unit)
				end
			else
				lock = nil
			end
		else
			lock = nil
		end
	end)
end)
