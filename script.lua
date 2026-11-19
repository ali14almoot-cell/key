local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Cam = workspace.CurrentCamera
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui", 10)
if not pg then return end

if pg:FindFirstChild("DarkfulBQMStreetUI") then
	pg.DarkfulBQMStreetUI:Destroy()
end

local KEYS_URL = "https://raw.githubusercontent.com/ali14almoot-cell/key/refs/heads/main/key"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1573011451206176879/3CIjKfCC-tu197kkXX5DQAd10zYqqQix8r9gdK6GcjEA6JY-MSgovt-ysa4dF3q6Z_Iw"
local SAVE_FILE = "DarkDestroyer_KeyState_" .. tostring(LP.UserId) .. ".json"

local keysDb = {
	["10"] = {key = "10", duration = "1d", status = "active", lockedUser = nil}
}

local function trim(s)
	return string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1")
end

local function parseDuration(durText)
	local t = string.lower(trim(durText))
	if t == "" then
		return 86400, false
	end
	if t == "inf" or t == "infinite" or t == "lifetime" or t == "perm" then
		return nil, true
	end
	local num = tonumber(string.match(t, "^(%d+)"))
	local unit = string.match(t, "[a-z]+$") or "d"
	if not num or num <= 0 then
		return 86400, false
	end
	if unit == "s" or unit == "sec" or unit == "secs" then
		return num, false
	elseif unit == "m" or unit == "min" or unit == "mins" then
		return num * 60, false
	elseif unit == "h" or unit == "hr" or unit == "hrs" then
		return num * 3600, false
	elseif unit == "w" or unit == "week" or unit == "weeks" then
		return num * 7 * 86400, false
	elseif unit == "mo" or unit == "month" or unit == "months" then
		return num * 30 * 86400, false
	elseif unit == "y" or unit == "year" or unit == "years" then
		return num * 365 * 86400, false
	else
		return num * 86400, false
	end
end

local function loadRemoteKeys()
	if type(game.HttpGet) ~= "function" then return end
	local ok, raw = pcall(function()
		return game:HttpGet(KEYS_URL, true)
	end)
	if ok and type(raw) == "string" and trim(raw) ~= "" then
		for line in string.gmatch(raw, "[^\r\n]+") do
			local clean = trim(line)
			if clean ~= "" and string.sub(clean, 1, 1) ~= "#" then
				local row = {}
				local idx = 0
				for p in string.gmatch(clean, "[^|]+") do
					idx = idx + 1
					row[idx] = trim(p)
				end
				if row[1] and row[1] ~= "" then
					keysDb[string.lower(row[1])] = {
						key = row[1],
						duration = (row[2] and row[2] ~= "") and row[2] or "1d",
						status = (row[3] and row[3] ~= "") and string.lower(row[3]) or "active",
						lockedUser = (row[4] and row[4] ~= "") and row[4] or nil
					}
				end
			end
		end
	end
end

task.spawn(loadRemoteKeys)

local function isKeyAllowedForPlayer(entry)
	if not entry.lockedUser or entry.lockedUser == "" then
		return true
	end
	local target = string.lower(trim(entry.lockedUser))
	local myName = string.lower(tostring(LP.Name or ""))
	local myId = tostring(LP.UserId or "")
	return (myName == target) or (myId == target)
end

local function getHttpFunc()
	if type(syn) == "table" and type(syn.request) == "function" then
		return syn.request
	elseif type(http_request) == "function" then
		return http_request
	elseif type(request) == "function" then
		return request
	end
	return nil
end

local lang = "en"

local function getRemainingText(activeKey, keyExpireAt)
	if not activeKey then
		return (lang == "ar") and "الرمز: لا يوجد" or "KEY: NONE"
	end
	if activeKey.infinite or not keyExpireAt then
		return activeKey.key .. ((lang == "ar") and " | دائم" or " | LIFETIME")
	end
	local rem = math.max(0, math.floor(keyExpireAt - os.time()))
	local d = math.floor(rem / 86400)
	local h = math.floor((rem % 86400) / 3600)
	local m = math.floor((rem % 3600) / 60)
	local s = rem % 60
	if d > 0 then
		return string.format("%s | %dd %02dh %02dm", activeKey.key, d, h, m)
	end
	return string.format("%s | %02d:%02d:%02d", activeKey.key, h, m, s)
end

local activeKey = nil
local keyExpireAt = nil

local function sendKeyWebhook(keyUsed, remText)
	local reqFunc = getHttpFunc()
	if not reqFunc or WEBHOOK_URL == "" then
		return
	end
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
			reqFunc({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = HttpService:JSONEncode(payload)
			})
		end)
	end)
end

local function readSavedState()
	if type(isfile) == "function" and type(readfile) == "function" then
		local ok, exists = pcall(isfile, SAVE_FILE)
		if ok and exists then
			local rOk, content = pcall(readfile, SAVE_FILE)
			if rOk and type(content) == "string" and content ~= "" then
				local dOk, decoded = pcall(function()
					return HttpService:JSONDecode(content)
				end)
				if dOk and type(decoded) == "table" then
					return decoded
				end
			end
		end
	end
	return {}
end

local function writeSavedState(tbl)
	if type(writefile) == "function" then
		pcall(function()
			writefile(SAVE_FILE, HttpService:JSONEncode(tbl))
		end)
	end
end

local function activateKeyEntry(entry)
	local secs, isInf = parseDuration(entry.duration)
	local state = readSavedState()
	local kLower = string.lower(entry.key)
	local now = os.time()

	if isInf then
		activeKey = {key = entry.key, infinite = true}
		keyExpireAt = nil
		state[kLower] = {key = entry.key, infinite = true, expireAt = nil}
		writeSavedState(state)
		return true
	end

	local saved = state[kLower]
	if saved and type(saved.expireAt) == "number" and saved.expireAt > now then
		activeKey = {key = entry.key, infinite = false}
		keyExpireAt = saved.expireAt
		return true
	elseif saved and type(saved.expireAt) == "number" and saved.expireAt <= now then
		return false, "EXPIRED"
	end

	local exp = now + secs
	activeKey = {key = entry.key, infinite = false}
	keyExpireAt = exp
	state[kLower] = {key = entry.key, infinite = false, expireAt = exp}
	writeSavedState(state)
	return true
end

local SG = Instance.new("ScreenGui")
SG.Name = "DarkfulBQMStreetUI"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.DisplayOrder = 999999
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = pg

local origLight = {
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows
}
local origFov = Cam.FieldOfView

local SFX = {
	click = 6895079853,
	on = 6042053626,
	off = 6042053309,
	tab = 6895079853,
	open = 6042053626,
	close = 6042053309,
	ok = 6026984224,
	err = 6042053309,
	save = 6026984224,
	reset = 6042053309
}

local function snd(id, pitch, vol)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume = vol or 2.2
		s.PlaybackSpeed = pitch or 1
		s.Parent = SG
		s:Play()
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end)
end

local function drag(top, gui)
	local d, inp, s0, p0
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			d, s0, p0 = true, i.Position, gui.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					d = false
				end
			end)
		end
	end)
	top.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			inp = i
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if i == inp and d then
			local delta = i.Position - s0
			gui.Position = UDim2.new(p0.X.Scale, p0.X.Offset + delta.X, p0.Y.Scale, p0.Y.Offset + delta.Y)
		end
	end)
end

local function ui(cls, props, rad, col, thick)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	if props.Parent then
		o.Parent = props.Parent
	end
	if rad then
		Instance.new("UICorner", o).CornerRadius = UDim.new(0, rad)
	end
	if col then
		local st = Instance.new("UIStroke", o)
		st.Color = col
		if thick then
			st.Thickness = thick
		end
	end
	return o
end

local Red = Color3.fromRGB(235, 22, 40)
local Dark = Color3.fromRGB(9, 9, 14)
local Card = Color3.fromRGB(16, 16, 25)

local TopTimerBar = ui("Frame", {
	Parent = SG,
	Size = UDim2.new(0, 270, 0, 34),
	Position = UDim2.new(0.5, -135, 0, 10),
	BackgroundColor3 = Dark,
	BorderSizePixel = 0,
	Visible = false,
	Active = true
}, 10, Red, 1.8)

local TopTimerLbl = ui("TextLabel", {
	Parent = TopTimerBar,
	Size = UDim2.new(1, -12, 1, 0),
	Position = UDim2.new(0, 6, 0, 0),
	BackgroundTransparency = 1,
	Text = "KEY TIME",
	TextColor3 = Color3.fromRGB(255, 65, 85),
	TextSize = 12,
	Font = Enum.Font.GothamBlack
})
drag(TopTimerBar, TopTimerBar)

local Auth = ui("Frame", {
	Parent = SG,
	Size = UDim2.new(0, 344, 0, 212),
	Position = UDim2.new(0.5, -172, 0.5, -106),
	BackgroundColor3 = Color3.fromRGB(11, 11, 17),
	BorderSizePixel = 0,
	Active = true
}, 18, Red, 2.2)

local AuthGrad = Instance.new("UIGradient", Auth)
AuthGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 11, 18)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 9, 14))
})
AuthGrad.Rotation = 135

local AuthTitle = ui("TextLabel", {
	Parent = Auth,
	Size = UDim2.new(1, -24, 0, 42),
	Position = UDim2.new(0, 12, 0, 14),
	BackgroundTransparency = 1,
	Text = "DARK DESTROYER | KEY",
	TextColor3 = Color3.fromRGB(255, 55, 70),
	TextSize = 16,
	Font = Enum.Font.GothamBlack
})

local Pass = ui("TextBox", {
	Parent = Auth,
	Size = UDim2.new(1, -44, 0, 44),
	Position = UDim2.new(0, 22, 0, 68),
	BackgroundColor3 = Color3.fromRGB(19, 19, 29),
	PlaceholderText = "ENTER KEY (10)",
	PlaceholderColor3 = Color3.fromRGB(135, 135, 150),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	ClearTextOnFocus = false
}, 12, Color3.fromRGB(115, 16, 26), 1.4)

local realPass = ""
Pass:GetPropertyChangedSignal("Text"):Connect(function()
	local t = Pass.Text
	if #t < #realPass then
		realPass = string.sub(realPass, 1, #t)
	elseif #t > #realPass then
		local cleanAdded = string.gsub(string.sub(t, #realPass + 1), "%*", "")
		if cleanAdded ~= "" then
			realPass = realPass .. cleanAdded
		end
	end
	local masked = string.rep("*", #realPass)
	if Pass.Text ~= masked then
		Pass.Text = masked
	end
end)

local Enter = ui("TextButton", {
	Parent = Auth,
	Size = UDim2.new(1, -44, 0, 44),
	Position = UDim2.new(0, 22, 0, 128),
	BackgroundColor3 = Color3.fromRGB(215, 18, 36),
	Text = "ENTER",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 14,
	Font = Enum.Font.GothamBlack
}, 12)

local LangBox = ui("Frame", {
	Parent = SG,
	Size = UDim2.new(0, 360, 0, 176),
	Position = UDim2.new(0.5, -180, 0.5, -88),
	BackgroundColor3 = Color3.fromRGB(11, 11, 17),
	BorderSizePixel = 0,
	Active = true,
	Visible = false
}, 18, Red, 2.4)

local LangGrad = Instance.new("UIGradient", LangBox)
LangGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 11, 18)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 9, 14))
})
LangGrad.Rotation = 135

ui("TextLabel", {
	Parent = LangBox,
	Size = UDim2.new(1, -24, 0, 34),
	Position = UDim2.new(0, 12, 0, 10),
	BackgroundTransparency = 1,
	Text = "CHOOSE LANGUAGE / AR",
	TextColor3 = Color3.fromRGB(255, 55, 70),
	TextSize = 14,
	Font = Enum.Font.GothamBlack
})

local EnFlag = ui("Frame", {
	Parent = LangBox,
	Size = UDim2.new(0, 154, 0, 104),
	Position = UDim2.new(0, 18, 0, 52),
	BackgroundColor3 = Color3.fromRGB(18, 18, 28),
	ClipsDescendants = true
}, 12, Color3.fromRGB(205, 20, 38), 1.5)

for r = 0, 6 do
	ui("Frame", {
		Parent = EnFlag,
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 0, r * 14),
		BackgroundColor3 = (r % 2 == 0) and Color3.fromRGB(190, 25, 38) or Color3.fromRGB(240, 240, 245),
		BorderSizePixel = 0
	})
end
ui("Frame", {
	Parent = EnFlag,
	Size = UDim2.new(0.45, 0, 0.54, 0),
	BackgroundColor3 = Color3.fromRGB(22, 42, 110),
	BorderSizePixel = 0
})
local EnBtn = ui("TextButton", {
	Parent = EnFlag,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Text = "ENGLISH",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 14,
	Font = Enum.Font.GothamBlack
}, 12)

local ArFlag = ui("Frame", {
	Parent = LangBox,
	Size = UDim2.new(0, 154, 0, 104),
	Position = UDim2.new(1, -172, 0, 52),
	BackgroundColor3 = Color3.fromRGB(12, 118, 52),
	ClipsDescendants = true
}, 12, Color3.fromRGB(205, 20, 38), 1.5)

ui("Frame", {
	Parent = ArFlag,
	Size = UDim2.new(1, -24, 0, 3),
	Position = UDim2.new(0, 12, 0, 52),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0
})
local ArBtn = ui("TextButton", {
	Parent = ArFlag,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.25,
	Text = "ARABIC",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 14,
	Font = Enum.Font.GothamBlack
}, 12)

local Welc = ui("TextLabel", {
	Parent = SG,
	Size = UDim2.new(0, 430, 0, 86),
	Position = UDim2.new(0.5, -215, 0.22, 0),
	BackgroundColor3 = Color3.fromRGB(13, 10, 18),
	TextColor3 = Color3.fromRGB(255, 55, 70),
	TextSize = 18,
	Font = Enum.Font.GothamBlack,
	Text = "DARK DESTROYER",
	Visible = false
}, 16, Red, 2.5)

local Main = ui("Frame", {
	Parent = SG,
	Size = UDim2.new(0, 404, 0, 560),
	Position = UDim2.new(0.5, -202, 0.5, -280),
	BackgroundColor3 = Dark,
	BorderSizePixel = 0,
	Visible = false,
	Active = true
}, 18, Red, 2.5)

local MainGrad = Instance.new("UIGradient", Main)
MainGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 12, 20)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(9, 9, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 16))
})
MainGrad.Rotation = 140

local Top = ui("Frame", {
	Parent = Main,
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = Color3.fromRGB(20, 13, 22),
	BackgroundTransparency = 0.15,
	Active = true
}, 18)

ui("Frame", {
	Parent = Top,
	Size = UDim2.new(1, -36, 0, 2),
	Position = UDim2.new(0, 18, 1, -2),
	BackgroundColor3 = Red,
	BorderSizePixel = 0
})

local TopTitle = ui("TextLabel", {
	Parent = Top,
	Size = UDim2.new(0.45, 0, 1, 0),
	Position = UDim2.new(0, 18, 0, 0),
	BackgroundTransparency = 1,
	Text = "DARK DESTROYER",
	TextColor3 = Color3.fromRGB(255, 55, 70),
	TextSize = 15,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left
})

local KeyBadge = ui("TextLabel", {
	Parent = Top,
	Size = UDim2.new(0.42, -8, 1, 0),
	Position = UDim2.new(0.45, 0, 0, 0),
	BackgroundTransparency = 1,
	Text = "KEY TIME",
	TextColor3 = Color3.fromRGB(220, 220, 235),
	TextSize = 10,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Right
})

local Close = ui("TextButton", {
	Parent = Top,
	Size = UDim2.new(0, 30, 0, 30),
	Position = UDim2.new(1, -40, 0.5, -15),
	BackgroundColor3 = Color3.fromRGB(210, 18, 36),
	Text = "X",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 13,
	Font = Enum.Font.GothamBlack
}, 9)

local DeepBanner = ui("Frame", {
	Parent = Main,
	Size = UDim2.new(1, -24, 0, 62),
	Position = UDim2.new(0, 12, 0, 62),
	BackgroundColor3 = Color3.fromRGB(16, 12, 22),
	BackgroundTransparency = 0.35,
	ClipsDescendants = true
}, 12, Color3.fromRGB(140, 20, 36), 1.3)

ui("ImageLabel", {
	Parent = DeepBanner,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Image = "rbxassetid://16071535782",
	ImageTransparency = 0.45,
	ScaleType = Enum.ScaleType.Crop
})

local DeepGrad = Instance.new("UIGradient", DeepBanner)
DeepGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 10, 18)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 16, 28)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 10, 20))
})
DeepGrad.Rotation = 90

local BannerLbl = ui("TextLabel", {
	Parent = DeepBanner,
	Size = UDim2.new(1, -20, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "DEEP | DARK DESTROYER",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 13,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left
})

local TabBar = ui("Frame", {
	Parent = Main,
	Size = UDim2.new(1, -24, 0, 42),
	Position = UDim2.new(0, 12, 0, 130),
	BackgroundColor3 = Color3.fromRGB(15, 15, 24)
}, 11, Color3.fromRGB(70, 15, 24), 1.2)

ui("UIListLayout", {
	Parent = TabBar,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 5)
})

local Pages = ui("Frame", {
	Parent = Main,
	Size = UDim2.new(1, -24, 1, -184),
	Position = UDim2.new(0, 12, 0, 178),
	BackgroundTransparency = 1
})

local function page()
	local sf = ui("ScrollingFrame", {
		Parent = Pages,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 780),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Red,
		Visible = false
	})
	ui("UIListLayout", {
		Parent = sf,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 9)
	})
	return sf
end

local AimP, GenP, EspP, SetP = page(), page(), page(), page()
AimP.Visible = true

local tabs = {}
local function tab(name, p)
	local b = ui("TextButton", {
		Parent = TabBar,
		Size = UDim2.new(1 / 4, -5, 1, -8),
		Position = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(23, 23, 35),
		Text = name,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		TextSize = 11,
		Font = Enum.Font.GothamBlack
	}, 8)
	tabs[#tabs + 1] = {b = b, p = p}
	b.MouseButton1Click:Connect(function()
		snd(SFX.tab, 1.25, 1.3)
		for _, t in ipairs(tabs) do
			local act = t.p == p
			t.p.Visible = act
			t.b.BackgroundColor3 = act and Color3.fromRGB(210, 18, 36) or Color3.fromRGB(23, 23, 35)
			t.b.TextColor3 = act and Color3.new(1, 1, 1) or Color3.fromRGB(185, 185, 200)
		end
	end)
	return b
end

local t0 = tab("AIMBOT", AimP)
t0.BackgroundColor3 = Color3.fromRGB(210, 18, 36)
t0.TextColor3 = Color3.new(1, 1, 1)
local t1 = tab("GENERAL", GenP)
local t2 = tab("ESP", EspP)
local t3 = tab("SETTINGS", SetP)

local Tog = ui("TextButton", {
	Parent = SG,
	Size = UDim2.new(0, 54, 0, 54),
	Position = UDim2.new(0, 22, 0.4, 0),
	BackgroundColor3 = Color3.fromRGB(16, 10, 19),
	Text = "DD",
	TextColor3 = Color3.fromRGB(255, 55, 70),
	TextSize = 14,
	Font = Enum.Font.GothamBlack,
	Visible = false
}, 999, Red, 2.4)

local function paintBtn(b, active)
	b.BackgroundColor3 = active and Color3.fromRGB(220, 22, 42) or Color3.fromRGB(25, 14, 22)
end

local function btn(p, txt)
	return ui("TextButton", {
		Parent = p,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(25, 14, 22),
		Text = txt,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 12,
		Font = Enum.Font.GothamBlack
	}, 10, Color3.fromRGB(205, 20, 38), 1.4)
end

local sliders = {}
local function sld(p, getLabelFn, mn, mx, def, cb)
	local f = ui("Frame", {
		Parent = p,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Card
	}, 10, Color3.fromRGB(85, 15, 24), 1.3)
	local lbl = ui("TextLabel", {
		Parent = f,
		Size = UDim2.new(1, -18, 0, 20),
		Position = UDim2.new(0, 10, 0, 6),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(245, 245, 250),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local bar = ui("TextButton", {
		Parent = f,
		Size = UDim2.new(1, -22, 0, 10),
		Position = UDim2.new(0, 11, 0, 37),
		BackgroundColor3 = Color3.fromRGB(32, 32, 46),
		Text = "",
		AutoButtonColor = false
	}, 999)
	local fill = ui("Frame", {
		Parent = bar,
		Size = UDim2.new((def - mn) / (mx - mn), 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(230, 20, 38),
		BorderSizePixel = 0
	}, 999)
	local curVal = def
	local function updLbl()
		lbl.Text = getLabelFn(curVal)
	end
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
	local function upd(i)
		local r = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		setVal(mn + (mx - mn) * r)
	end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			act = true
			upd(i)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			act = false
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if act and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			upd(i)
		end
	end)
end

local fovV = 190
local predV = 50
local flyV = 55
local zoomOutV = 850

local AimB = btn(AimP, "Aimbot: OFF")
local PartB = btn(AimP, "Target: Head")
local FovB = btn(AimP, "FOV Circle: OFF")

sld(AimP, function(v)
	return ((lang == "ar") and "حجم المجال" or "FOV Size") .. ": " .. string.format("%.0f", v)
end, 50, 420, fovV, function(v)
	fovV = v
end)

sld(AimP, function(v)
	return ((lang == "ar") and "التسبيق" or "Prediction") .. ": " .. string.format("%.0f", v)
end, 0, 850, predV, function(v)
	predV = v
end)

local NoclipB = btn(GenP, "Noclip: OFF")
local FlyB = btn(GenP, "Fly + Noclip: OFF")
local JumpB = btn(GenP, "Infinite Jump: OFF")
local BrightB = btn(GenP, "Fullbright: OFF")
local ZoomOutB = btn(GenP, "Zoom Out: OFF")

sld(GenP, function(v)
	return ((lang == "ar") and "سرعة الطيران" or "Fly Speed") .. ": " .. string.format("%.0f", v)
end, 20, 200, flyV, function(v)
	flyV = v
end)

sld(GenP, function(v)
	return ((lang == "ar") and "درجة الزوم اوت" or "Zoom Out") .. ": " .. string.format("%.0f", v)
end, 70, 850, zoomOutV, function(v)
	zoomOutV = v
end)

local HlB = btn(EspP, "Highlight ESP: OFF")
local EspB = btn(EspP, "Weapons ESP: OFF")

local SaveB = btn(SetP, "Save Config")
local ResetB = btn(SetP, "Reset Config")
local ScanAcB = btn(SetP, "Scan Anti-Cheat")
local BypassAcB = btn(SetP, "Bypass Anti-Cheat: OFF")

local AcInfoLbl = ui("TextLabel", {
	Parent = SetP,
	Size = UDim2.new(1, 0, 0, 84),
	BackgroundColor3 = Card,
	Text = "Bypass Status: OFF\nDetected: None",
	TextColor3 = Color3.fromRGB(235, 235, 245),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextWrapped = true
}, 10, Color3.fromRGB(95, 16, 26), 1.3)

local aimOn = false
local fovOn = false
local noclipOn = false
local flyOn = false
local jumpOn = false
local brightOn = false
local zoomOutOn = false
local hlOn = false
local espOn = false
local bypassOn = false

local parts = {"Head", "Body", "Feet"}
local pIdx = 1

local FovGui = ui("Frame", {
	Parent = SG,
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false
}, 999, Red, 2)

local MAX_I = 6
local MAX_D = 750
local espMap = {}
local savedCfg = nil
local lock = nil
local lastV = {}
local detectedAC = {}
local lastBypassCount = 0

local function updateAcText()
	local det = (#detectedAC > 0 and detectedAC[1] or ((lang == "ar") and "فحوصات عامة" or "Generic / Client Checks"))
	if lang == "ar" then
		AcInfoLbl.Text = (bypassOn and ("حالة التخطي: مفعل (" .. tostring(lastBypassCount) .. " سكربت)\n") or "حالة التخطي: مغلق\n") .. "المكتشف: " .. det
	else
		AcInfoLbl.Text = (bypassOn and ("Bypass Status: BYPASSED (" .. tostring(lastBypassCount) .. " scripts)\n") or "Bypass Status: OFF\n") .. "Detected: " .. det
	end
end

local function applyLang()
	if lang == "ar" then
		AuthTitle.Text = "دارك المدمر | الرمز"
		Pass.PlaceholderText = "اكتب الرمز (10)"
		Enter.Text = "دخول"
		Welc.Text = "مرحبا بك في دارك المدمر"
		TopTitle.Text = "دارك المدمر"
		BannerLbl.Text = "عميق | دارك المدمر"
		Tog.Text = "د م"
		t0.Text = "ايم بوت"
		t1.Text = "عام"
		t2.Text = "اكس راي"
		t3.Text = "اعدادات"
		SaveB.Text = "حفظ الاعدادات"
		ResetB.Text = "تصفير الاعدادات"
		ScanAcB.Text = "فحص الحماية"
	else
		AuthTitle.Text = "DARK DESTROYER | KEY"
		Pass.PlaceholderText = "ENTER KEY (10)"
		Enter.Text = "ENTER"
		Welc.Text = "WELCOME TO DARK DESTROYER"
		TopTitle.Text = "DARK DESTROYER"
		BannerLbl.Text = "DEEP | DARK DESTROYER"
		Tog.Text = "DD"
		t0.Text = "AIMBOT"
		t1.Text = "GENERAL"
		t2.Text = "ESP"
		t3.Text = "SETTINGS"
		SaveB.Text = "Save Config"
		ResetB.Text = "Reset Config"
		ScanAcB.Text = "Scan Anti-Cheat"
	end
	for _, s in ipairs(sliders) do
		s.updLbl()
	end
end

local function syncUI()
	local t = parts[pIdx]
	if lang == "ar" then
		AimB.Text = aimOn and "ايم بوت: مفعل" or "ايم بوت: مغلق"
		if t == "Head" then
			PartB.Text = "الهدف: الرأس"
		elseif t == "Body" then
			PartB.Text = "الهدف: الجسم"
		else
			PartB.Text = "الهدف: القدم"
		end
		FovB.Text = fovOn and "دائرة المجال: مفعل" or "دائرة المجال: مغلق"
		NoclipB.Text = noclipOn and "اختراق الجدران: مفعل" or "اختراق الجدران: مغلق"
		FlyB.Text = flyOn and "طيران + اختراق: مفعل" or "طيران + اختراق: مغلق"
		JumpB.Text = jumpOn and "قفز لا نهائي: مفعل" or "قفز لا نهائي: مغلق"
		BrightB.Text = brightOn and "اضاءة كاملة: مفعل" or "اضاءة كاملة: مغلق"
		ZoomOutB.Text = zoomOutOn and "زوم اوت: مفعل" or "زوم اوت: مغلق"
		HlB.Text = hlOn and "تحديد اللاعبين: مفعل" or "تحديد اللاعبين: مغلق"
		EspB.Text = espOn and "كشف الاسلحة: مفعل" or "كشف الاسلحة: مغلق"
		BypassAcB.Text = bypassOn and "تخطي الحماية: مفعل" or "تخطي الحماية: مغلق"
	else
		AimB.Text = aimOn and "Aimbot: ON" or "Aimbot: OFF"
		PartB.Text = "Target: " .. t
		FovB.Text = fovOn and "FOV Circle: ON" or "FOV Circle: OFF"
		NoclipB.Text = noclipOn and "Noclip: ON" or "Noclip: OFF"
		FlyB.Text = flyOn and "Fly + Noclip: ON" or "Fly + Noclip: OFF"
		JumpB.Text = jumpOn and "Infinite Jump: ON" or "Infinite Jump: OFF"
		BrightB.Text = brightOn and "Fullbright: ON" or "Fullbright: OFF"
		ZoomOutB.Text = zoomOutOn and "Zoom Out: ON" or "Zoom Out: OFF"
		HlB.Text = hlOn and "Highlight ESP: ON" or "Highlight ESP: OFF"
		EspB.Text = espOn and "Weapons ESP: ON" or "Weapons ESP: OFF"
		BypassAcB.Text = bypassOn and "Bypass Anti-Cheat: ON" or "Bypass Anti-Cheat: OFF"
	end

	paintBtn(AimB, aimOn)
	paintBtn(FovB, fovOn)
	FovGui.Visible = fovOn
	paintBtn(NoclipB, noclipOn)
	paintBtn(FlyB, flyOn)
	paintBtn(JumpB, jumpOn)
	paintBtn(BrightB, brightOn)
	paintBtn(ZoomOutB, zoomOutOn)
	paintBtn(HlB, hlOn)
	paintBtn(EspB, espOn)
	paintBtn(BypassAcB, bypassOn)
	updateAcText()

	if not zoomOutOn then
		Cam.FieldOfView = origFov
		LP.CameraMaxZoomDistance = 128
	end
	if not brightOn then
		Lighting.Brightness = origLight.Brightness
		Lighting.ClockTime = origLight.ClockTime
		Lighting.FogEnd = origLight.FogEnd
		Lighting.GlobalShadows = origLight.GlobalShadows
	end
	if not hlOn then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and p.Character:FindFirstChild("Highlight") then
				p.Character.Highlight:Destroy()
			end
		end
	end
	if not espOn then
		for _, e in pairs(espMap) do
			if e and e.h then
				e.h.Visible = false
				pcall(function() e.h:Destroy() end)
			end
		end
		table.clear(espMap)
	end
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
bindToggle(FovB, function() return fovOn end, function(v) fovOn = v end)
bindToggle(NoclipB, function() return noclipOn end, function(v) noclipOn = v end)
bindToggle(FlyB, function() return flyOn end, function(v)
	flyOn = v
	if not v and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
		LP.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	end
end)
bindToggle(JumpB, function() return jumpOn end, function(v) jumpOn = v end)
bindToggle(BrightB, function() return brightOn end, function(v) brightOn = v end)
bindToggle(ZoomOutB, function() return zoomOutOn end, function(v) zoomOutOn = v end)
bindToggle(HlB, function() return hlOn end, function(v) hlOn = v end)
bindToggle(EspB, function() return espOn end, function(v) espOn = v end)

local function finishEntry(chosenLang)
	lang = chosenLang
	applyLang()
	syncUI()
	snd(SFX.ok, 1.05, 2.2)
	LangBox.Visible = false
	Welc.Visible = true
	task.wait(1.2)
	Welc.Visible = false
	Main.Visible = true
	Tog.Visible = true
	snd(SFX.open, 1.1, 1.8)
end

EnBtn.MouseButton1Click:Connect(function()
	snd(SFX.click, 1.2, 1.5)
	finishEntry("en")
end)

ArBtn.MouseButton1Click:Connect(function()
	snd(SFX.click, 1.2, 1.5)
	finishEntry("ar")
end)

local function checkKeyEntry()
	snd(SFX.click, 1.1, 1.5)
	loadRemoteKeys()
	local raw = trim(realPass)
	if raw == "" then
		raw = trim(Pass.Text)
	end
	local firstPart = trim(string.match(raw, "^([^|]+)") or raw)
	local lower = string.lower(firstPart)
	local entry = keysDb[lower]
	if entry and entry.status == "active" then
		if not isKeyAllowedForPlayer(entry) then
			snd(SFX.err, 0.9, 1.8)
			realPass = ""
			Pass.Text = ""
			Pass.PlaceholderText = (lang == "ar") and "حساب غير مسموح" or "WRONG ACCOUNT"
			return
		end
		local okAct, reason = activateKeyEntry(entry)
		if okAct then
			local tStr = getRemainingText(activeKey, keyExpireAt)
			KeyBadge.Text = tStr
			TopTimerLbl.Text = tStr
			TopTimerBar.Visible = true
			sendKeyWebhook(entry.key, tStr)
			realPass = ""
			Pass.Text = ""
			Auth.Visible = false
			LangBox.Visible = true
			snd(SFX.ok, 1.1, 1.6)
		else
			snd(SFX.err, 0.9, 1.8)
			realPass = ""
			Pass.Text = ""
			Pass.PlaceholderText = reason or "EXPIRED"
		end
	else
		snd(SFX.err, 0.9, 1.8)
		realPass = ""
		Pass.Text = ""
		Pass.PlaceholderText = "INVALID KEY"
	end
end

Enter.MouseButton1Click:Connect(checkKeyEntry)
Pass.FocusLost:Connect(function(enter)
	if enter then
		checkKeyEntry()
	end
end)

Tog.MouseButton1Click:Connect(function()
	Main.Visible = not Main.Visible
	snd(Main.Visible and SFX.open or SFX.close, Main.Visible and 1.1 or 0.95, 1.8)
end)

Close.MouseButton1Click:Connect(function()
	snd(SFX.close, 0.95, 1.8)
	Main.Visible = false
end)

drag(Top, Main)
drag(Auth, Auth)
drag(LangBox, LangBox)
drag(Tog, Tog)

local function scanAntiCheat()
	table.clear(detectedAC)
	local suspects = {"anticheat","anti-cheat","ac","adonis","byfron","hyperion","kick","ban","detect","exploit","speed","noclip","fly","hit","hitbox","guard","shield","watch","monitor"}
	local roots = {game:GetService("ReplicatedStorage"), LP:FindFirstChild("PlayerScripts"), LP.Character}
	for _, r in ipairs(roots) do
		if r then
			for _, d in ipairs(r:GetDescendants()) do
				if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("LocalScript") then
					local n = string.lower(d.Name)
					for _, k in ipairs(suspects) do
						if string.find(n, k, 1, true) then
							detectedAC[#detectedAC + 1] = d.Name .. " (" .. d.ClassName .. ")"
							break
						end
					end
				end
			end
		end
	end
	updateAcText()
end

local function applyBypassOnce()
	if not bypassOn then return end
	local disabledCount = 0
	pcall(function()
		if LP.Character and LP.Character:FindFirstChild("Humanoid") then
			local h = LP.Character.Humanoid
			h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end
	end)
	pcall(function()
		local roots = {LP:FindFirstChild("PlayerScripts"), LP.Character}
		for _, r in ipairs(roots) do
			if r then
				for _, d in ipairs(r:GetDescendants()) do
					if d:IsA("LocalScript") and not d.Disabled then
						local n = string.lower(d.Name)
						if string.find(n, "anti", 1, true) or string.find(n, "ac", 1, true) or string.find(n, "cheat", 1, true) or string.find(n, "guard", 1, true) then
							pcall(function()
								d.Disabled = true
								disabledCount += 1
							end)
						end
					end
				end
			end
		end
	end)
	lastBypassCount = disabledCount
	updateAcText()
end

bindToggle(BypassAcB, function() return bypassOn end, function(v)
	bypassOn = v
	if v then
		applyBypassOnce()
	end
end)

LP.CharacterAdded:Connect(function()
	if bypassOn then
		task.wait(0.3)
		applyBypassOnce()
	end
end)

ScanAcB.MouseButton1Click:Connect(function()
	snd(SFX.ok, 1.2, 1.7)
	scanAntiCheat()
	ScanAcB.BackgroundColor3 = Color3.fromRGB(220, 22, 42)
	task.delay(0.18, function()
		if ScanAcB then
			ScanAcB.BackgroundColor3 = Color3.fromRGB(25, 14, 22)
		end
	end)
end)

PartB.MouseButton1Click:Connect(function()
	pIdx = pIdx % #parts + 1
	syncUI()
	snd(SFX.on, 1.1, 1.5)
	PartB.BackgroundColor3 = Color3.fromRGB(220, 22, 42)
	task.delay(0.18, function()
		if PartB then
			PartB.BackgroundColor3 = Color3.fromRGB(25, 14, 22)
		end
	end)
end)

SaveB.MouseButton1Click:Connect(function()
	savedCfg = {
		aimOn = aimOn, fovOn = fovOn, noclipOn = noclipOn, flyOn = flyOn,
		jumpOn = jumpOn, brightOn = brightOn, zoomOutOn = zoomOutOn,
		hlOn = hlOn, espOn = espOn, bypassOn = bypassOn, pIdx = pIdx,
		fovV = fovV, predV = predV, flyV = flyV, zoomOutV = zoomOutV
	}
	snd(SFX.save, 1.2, 1.8)
	SaveB.BackgroundColor3 = Color3.fromRGB(35, 175, 90)
	task.delay(0.25, function()
		if SaveB then
			SaveB.BackgroundColor3 = Color3.fromRGB(25, 14, 22)
		end
	end)
end)

ResetB.MouseButton1Click:Connect(function()
	if savedCfg then
		aimOn = savedCfg.aimOn
		fovOn = savedCfg.fovOn
		noclipOn = savedCfg.noclipOn
		flyOn = savedCfg.flyOn
		jumpOn = savedCfg.jumpOn
		brightOn = savedCfg.brightOn
		zoomOutOn = savedCfg.zoomOutOn
		hlOn = savedCfg.hlOn
		espOn = savedCfg.espOn
		bypassOn = savedCfg.bypassOn
		pIdx = savedCfg.pIdx
		sliders[1].setVal(savedCfg.fovV)
		sliders[2].setVal(savedCfg.predV)
		sliders[3].setVal(savedCfg.flyV)
		sliders[4].setVal(savedCfg.zoomOutV)
	else
		aimOn = false
		fovOn = false
		noclipOn = false
		flyOn = false
		jumpOn = false
		brightOn = false
		zoomOutOn = false
		hlOn = false
		espOn = false
		bypassOn = false
		pIdx = 1
		for _, s in ipairs(sliders) do
			s.setVal(s.def)
		end
		if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
			LP.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		end
	end
	syncUI()
	snd(SFX.reset, 0.9, 1.8)
	ResetB.BackgroundColor3 = Color3.fromRGB(220, 22, 42)
	task.delay(0.25, function()
		if ResetB then
			ResetB.BackgroundColor3 = Color3.fromRGB(25, 14, 22)
		end
	end)
end)

UIS.JumpRequest:Connect(function()
	if jumpOn and LP.Character and LP.Character:FindFirstChild("Humanoid") then
		LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

local Overlay = ui("Frame", {
	Parent = SG,
	Name = "Darkful2DWeaponsOverlay",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 50
})

local tiers = {
	omega = Color3.fromRGB(255, 50, 95),
	legendary = Color3.fromRGB(255, 195, 35),
	epic = Color3.fromRGB(185, 85, 255),
	rare = Color3.fromRGB(70, 180, 255),
	uncommon = Color3.fromRGB(85, 235, 125),
	common = Color3.fromRGB(220, 220, 230)
}

local guns = {"ak47","ak-47","crossbow","rpg","pumpkin launcher","draco","mp5","m16","anaconda","skorpion","scorpion","aug","awp","awm","m249","m24","double barrel","remington","uzi","glock","m4","m4a1","m4a4","ak74","ak-74","scar","famas","galil","hk416","ar15","ar-15","fal","mp7","mp9","mp40","mac","mac10","mac-10","p90","vector","thompson","deagle","desert eagle","revolver","colt","1911","m1911","beretta","m9","usp","tec9","tec-9","shotgun","pump","mossberg","spas","m870","m1014","aa12","saiga","sniper","barrett","m82","m107","m40","m200","intervention","dragunov","svd","kar98","kar98k","rocket","launcher","bazooka","grenade launcher","gun","rifle","pistol","smg","carbine","firearm","minigun"}
local bad = {"ammo","bullet","bullets","shell","shells","arrow","arrows","rocketarrow","mag","magazine","clip","casing","round","rounds","fish","fishing","rod","bait","lure","bucket","bass","coelacanth","dolphinfish","perch","prawn","worm","seed","seeds","soil","fertilizer","water","watering","can","pot","pots","farm","farming","hack","food","drink","heal","med","bandage","potion","sword","katana","blade","dagger","karambit","butterfly","balisong","machete","axe","hatchet","tomahawk","cleaver","scythe","spear","halberd","rapier","sabre","saber","bat","crowbar","pipe","wrench","hammer","mallet","club","pan","shank","shiv","bayonet"}

local function isGun(o)
	if not o or not (o:IsA("Tool") or o:IsA("Model")) then return false end
	local n = string.lower(tostring(o.Name or ""))
	if n == "" or n == "fists" then return false end
	for _, k in ipairs(bad) do
		if string.find(n, k, 1, true) then return false end
	end
	for _, w in ipairs(guns) do
		if string.find(n, w, 1, true) then return true end
	end
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
		for k, v in pairs(o:GetAttributes()) do
			local lk, lv = string.lower(tostring(k)), string.lower(tostring(v))
			if string.find(lk, "rar") or string.find(lk, "tier") then
				if string.find(lv, "omega") or string.find(lv, "myth") or string.find(lv, "red") then
					return tiers.omega
				elseif string.find(lv, "legend") then
					return tiers.legendary
				elseif string.find(lv, "epic") or string.find(lv, "purp") then
					return tiers.epic
				elseif string.find(lv, "rare") then
					return tiers.rare
				elseif string.find(lv, "uncommon") then
					return tiers.uncommon
				end
			end
		end
		local nm = string.lower(tostring(o.Name or ""))
		if string.find(nm, "anaconda", 1, true) or string.find(nm, "m249", 1, true) or string.find(nm, "pumpkin", 1, true) or string.find(nm, "minigun", 1, true) then
			return tiers.omega
		elseif string.find(nm, "ak47", 1, true) or string.find(nm, "ak-47", 1, true) or string.find(nm, "crossbow", 1, true) or string.find(nm, "rpg", 1, true) or string.find(nm, "mp5", 1, true) or string.find(nm, "m16", 1, true) or string.find(nm, "awp", 1, true) or string.find(nm, "remington", 1, true) or string.find(nm, "barrett", 1, true) then
			return tiers.legendary
		elseif string.find(nm, "skorpion", 1, true) or string.find(nm, "scorpion", 1, true) or string.find(nm, "aug", 1, true) or string.find(nm, "draco", 1, true) or string.find(nm, "double barrel", 1, true) or string.find(nm, "m24", 1, true) or string.find(nm, "spas", 1, true) then
			return tiers.epic
		elseif string.find(nm, "uzi", 1, true) or string.find(nm, "glock", 1, true) or string.find(nm, "deagle", 1, true) then
			return tiers.rare
		end
	end
	local fb = {tiers.legendary, tiers.epic, tiers.omega, tiers.rare, tiers.uncommon, tiers.common}
	return fb[((idx - 1) % #fb) + 1]
end

local function getEsp(plr)
	if espMap[plr] and espMap[plr].h and espMap[plr].h.Parent then
		return espMap[plr]
	end
	local h = ui("Frame", {
		Parent = Overlay,
		Size = UDim2.new(0, MAX_I * 88, 0, 46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false
	})
	ui("UIListLayout", {
		Parent = h,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6)
	})
	local slots = {}
	for i = 1, MAX_I do
		local box = ui("Frame", {
			Parent = h,
			Size = UDim2.new(0, 42, 0, 42),
			BackgroundColor3 = Color3.fromRGB(13, 13, 20),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Visible = false
		}, 8)
		local st = Instance.new("UIStroke", box)
		st.Thickness = 2.3
		st.Color = tiers.legendary
		local img = ui("ImageLabel", {
			Parent = box,
			Size = UDim2.new(1, -6, 1, -6),
			Position = UDim2.new(0, 3, 0, 3),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = Color3.new(1, 1, 1),
			Visible = false
		})
		local lbl = ui("TextLabel", {
			Parent = box,
			Size = UDim2.new(1, -6, 1, 0),
			Position = UDim2.new(0, 3, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 10,
			Font = Enum.Font.GothamBlack,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Visible = false
		})
		slots[i] = {box = box, st = st, img = img, lbl = lbl}
	end
	espMap[plr] = {h = h, slots = slots}
	return espMap[plr]
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
	if plr.Character then
		for _, c in ipairs(plr.Character:GetChildren()) do
			add(c)
		end
	end
	if plr:FindFirstChild("Backpack") then
		for _, c in ipairs(plr.Backpack:GetChildren()) do
			add(c)
		end
	end
	return out
end

Players.PlayerRemoving:Connect(function(p)
	if espMap[p] then
		pcall(function()
			if espMap[p].h then
				espMap[p].h:Destroy()
			end
		end)
		espMap[p] = nil
	end
end)

local function valid(p)
	return p ~= LP and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0
end

local function tPos(char)
	local t = parts[pIdx]
	if t == "Head" then
		local h = char:FindFirstChild("Head")
		if h then
			return h.Position, h.AssemblyLinearVelocity
		end
	elseif t == "Body" then
		local b = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
		if b then
			return b.Position, b.AssemblyLinearVelocity
		end
	elseif t == "Feet" then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = {char, LP.Character}
			local r = workspace:Raycast(hrp.Position + Vector3.new(0, 1, 0), Vector3.new(0, -150, 0), rp)
			return Vector3.new(hrp.Position.X, r and r.Position.Y or (hrp.Position.Y - 3.2), hrp.Position.Z), Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or Vector3.zero, Vector3.zero
end

local timerTick = 0
RunService.RenderStepped:Connect(function(dt)
	timerTick += dt
	if timerTick >= 0.5 then
		timerTick = 0
		if activeKey then
			if not activeKey.infinite and keyExpireAt and os.time() >= keyExpireAt then
				activeKey = nil
				TopTimerBar.Visible = false
				Main.Visible = false
				Tog.Visible = false
				Auth.Visible = true
				Pass.PlaceholderText = "EXPIRED"
			else
				local tStr = getRemainingText(activeKey, keyExpireAt)
				KeyBadge.Text = tStr
				TopTimerLbl.Text = tStr
			end
		end
	end

	pcall(function()
		FovGui.Position = UDim2.new(0, Cam.ViewportSize.X / 2, 0, Cam.ViewportSize.Y / 2)
		FovGui.Size = UDim2.new(0, fovV * 2, 0, fovV * 2)

		if zoomOutOn then
			local maxZ = math.clamp(zoomOutV, 70, 850)
			LP.CameraMaxZoomDistance = maxZ
			Cam.FieldOfView = math.clamp(70 + ((maxZ - 70) / (850 - 70)) * 55, 70, 125)
		else
			LP.CameraMaxZoomDistance = 128
			if Cam.FieldOfView ~= origFov then
				Cam.FieldOfView = origFov
			end
		end

		if brightOn then
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 1000000
			Lighting.GlobalShadows = false
		end

		if noclipOn and LP.Character then
			for _, x in ipairs(LP.Character:GetDescendants()) do
				if x:IsA("BasePart") and x.CanCollide then
					x.CanCollide = false
				end
			end
		end

		if flyOn and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character:FindFirstChild("Humanoid") then
			local hrp = LP.Character.HumanoidRootPart
			local hum = LP.Character.Humanoid
			local mv = hum.MoveDirection
			for _, x in ipairs(LP.Character:GetDescendants()) do
				if x:IsA("BasePart") then
					x.CanCollide = false
				end
			end
			local vy = 0
			if mv.Magnitude > 0 then
				vy = Cam.CFrame.LookVector.Y * flyV
			end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then
				vy = flyV
			elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
				vy = -flyV
			end
			hrp.AssemblyLinearVelocity = Vector3.new(mv.X * flyV, vy, mv.Z * flyV)
		end

		if hlOn then
			for _, p in ipairs(Players:GetPlayers()) do
				if valid(p) then
					local h = p.Character:FindFirstChild("Highlight") or Instance.new("Highlight", p.Character)
					local isLocked = (p == lock)
					h.FillColor = isLocked and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(200, 10, 20)
					h.FillTransparency = 0.4
					h.OutlineColor = isLocked and Color3.fromRGB(0, 255, 255) or Color3.new(1, 1, 1)
				elseif p.Character and p.Character:FindFirstChild("Highlight") then
					p.Character.Highlight:Destroy()
				end
			end
		end

		if espOn then
			local cp = Cam.CFrame.Position
			for _, p in ipairs(Players:GetPlayers()) do
				local e = espMap[p]
				if valid(p) then
					local head, hrp = p.Character:FindFirstChild("Head"), p.Character:FindFirstChild("HumanoidRootPart")
					local anc, hum = head or hrp, p.Character:FindFirstChildOfClass("Humanoid")
					local dist = anc and (anc.Position - cp).Magnitude or math.huge
					local ws = (anc and dist <= MAX_D and (not hum or hum.Health > 0)) and plrGuns(p) or {}
					if #ws > 0 and anc then
						local sp, on = Cam:WorldToViewportPoint(head and (head.Position + Vector3.new(0, 1.35, 0)) or (hrp.Position + Vector3.new(0, 3, 0)))
						e = getEsp(p)
						e.h.Size = UDim2.new(0, math.max(88, #ws * 90), 0, 44)
						e.h.ZIndex = math.clamp(math.floor(120 - math.min(dist, 100)), 20, 120)
						if on and sp.Z > 0 and sp.Z <= MAX_D then
							e.h.Visible = true
							e.h.Position = UDim2.new(0, sp.X, 0, sp.Y)
							for i = 1, MAX_I do
								local sl, wd = e.slots[i], ws[i]
								if wd then
									sl.box.Visible = true
									sl.st.Color = (p == lock) and Color3.fromRGB(0, 220, 255) or rarCol(wd.o, i)
									if wd.img then
										sl.box.Size = UDim2.new(0, 42, 0, 42)
										sl.img.Visible = true
										sl.img.Image = wd.img
										sl.lbl.Visible = false
									else
										sl.box.Size = UDim2.new(0, 84, 0, 28)
										sl.img.Visible = false
										sl.lbl.Visible = true
										sl.lbl.Text = wd.n
									end
								else
									sl.box.Visible = false
								end
							end
						elseif e and e.h then
							e.h.Visible = false
						end
					elseif e and e.h then
						e.h.Visible = false
					end
				elseif e and e.h then
					e.h.Visible = false
				end
			end
		end

		if aimOn and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
			local ctr = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
			if lock and valid(lock) then
				local pv = tPos(lock.Character)
				local sp, on = Cam:WorldToViewportPoint(pv)
				if not on or (Vector2.new(sp.X, sp.Y) - ctr).Magnitude > (fovV * 1.65) then
					lock = nil
				end
			else
				lock = nil
			end
			if not lock then
				local md = fovV
				for _, p in ipairs(Players:GetPlayers()) do
					if valid(p) then
						local pv = tPos(p.Character)
						local sp, on = Cam:WorldToViewportPoint(pv)
						if on then
							local d = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
							if d < md then
								md, lock = d, p
							end
						end
					end
				end
			end
			if lock and lock.Character then
				local pos, vel = tPos(lock.Character)
				local acc = (vel - (lastV[lock] or vel)) / math.max(dt, 0.001)
				lastV[lock] = vel
				local predScale = predV / 100
				local ld = (0.34 * predScale) + (vel.Magnitude * 0.003 * predScale)
				local aimPoint = pos + (vel * ld) + (0.5 * acc * (ld * 0.25) ^ 2)
				Cam.CFrame = CFrame.new(Cam.CFrame.Position, aimPoint)
			end
		else
			lock = nil
		end
	end)
end)
