local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Cam = workspace.CurrentCamera
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui", 10)
if not pg then return end

if pg:FindFirstChild("DarkDestroyerHub") then
	pg.DarkDestroyerHub:Destroy()
end

local KEYS_URL = "https://raw.githubusercontent.com/ali14almoot-cell/key/refs/heads/main/key"

local keysDb = {
	["123"] = {key = "123", duration = "inf", status = "active"},
	key1 = {key = "KEY1", duration = "1d", status = "active"},
	key2 = {key = "KEY2", duration = "7d", status = "active"},
	key3 = {key = "KEY3", duration = "30d", status = "active"},
	key4 = {key = "KEY4", duration = "365d", status = "active"},
	key5 = {key = "KEY5", duration = "inf", status = "active"}
}

local function trim(s)
	return string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1")
end

local function parseDuration(durText)
	local t = string.lower(trim(durText))
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
				local parts = {}
				for p in string.gmatch(clean, "[^|]+") do
					table.insert(parts, trim(p))
				end
				if parts[1] and parts[1] ~= "" then
					keysDb[string.lower(parts[1])] = {
						key = parts[1],
						duration = parts[2] or "1d",
						status = string.lower(parts[3] or "active")
					}
				end
			end
		end
	end
end

task.spawn(loadRemoteKeys)

local activeKey = nil
local keyExpireAt = nil

local function getRemainingText()
	if not activeKey then
		return "KEY: NONE"
	end
	if activeKey.infinite or not keyExpireAt then
		return activeKey.key .. " | LIFETIME"
	end
	local rem = math.max(0, math.floor(keyExpireAt - os.clock()))
	local d = math.floor(rem / 86400)
	local h = math.floor((rem % 86400) / 3600)
	local m = math.floor((rem % 3600) / 60)
	local s = rem % 60
	if d > 0 then
		return string.format("%s | %dd %02dh %02dm", activeKey.key, d, h, m)
	end
	return string.format("%s | %02d:%02d:%02d", activeKey.key, h, m, s)
end

local SG = Instance.new("ScreenGui")
SG.Name = "DarkDestroyerHub"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.DisplayOrder = 999999
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = pg

local Red = Color3.fromRGB(235, 22, 40)
local Dark = Color3.fromRGB(10, 10, 16)
local Card = Color3.fromRGB(18, 18, 28)

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
	TextColor3 = Color3.fromRGB(255, 70, 88),
	TextSize = 12,
	Font = Enum.Font.GothamBlack
})
drag(TopTimerBar, TopTimerBar)

local Auth = ui("Frame", {
	Parent = SG,
	Size = UDim2.new(0, 344, 0, 212),
	Position = UDim2.new(0.5, -172, 0.5, -106),
	BackgroundColor3 = Color3.fromRGB(12, 12, 19),
	BorderSizePixel = 0,
	Active = true
}, 18, Red, 2.2)

ui("TextLabel", {
	Parent = Auth,
	Size = UDim2.new(1, -24, 0, 42),
	Position = UDim2.new(0, 12, 0, 14),
	BackgroundTransparency = 1,
	Text = "DARK DESTROYER | KEY",
	TextColor3 = Color3.fromRGB(255, 60, 78),
	TextSize = 16,
	Font = Enum.Font.GothamBlack
})

local Pass = ui("TextBox", {
	Parent = Auth,
	Size = UDim2.new(1, -44, 0, 44),
	Position = UDim2.new(0, 22, 0, 68),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	PlaceholderText = "ENTER KEY (e.g. KEY1)",
	PlaceholderColor3 = Color3.fromRGB(135, 135, 155),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	ClearTextOnFocus = false
}, 12, Color3.fromRGB(115, 16, 26), 1.4)

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

local Main = ui("Frame", {
	Parent = SG,
	Size = UDim2.new(0, 386, 0, 470),
	Position = UDim2.new(0.5, -193, 0.5, -235),
	BackgroundColor3 = Dark,
	BorderSizePixel = 0,
	Visible = false,
	Active = true
}, 18, Red, 2.4)

local Top = ui("Frame", {
	Parent = Main,
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = Color3.fromRGB(20, 13, 22),
	Active = true
}, 18)

ui("TextLabel", {
	Parent = Top,
	Size = UDim2.new(0.45, 0, 1, 0),
	Position = UDim2.new(0, 16, 0, 0),
	BackgroundTransparency = 1,
	Text = "DARK DESTROYER",
	TextColor3 = Color3.fromRGB(255, 60, 78),
	TextSize = 15,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left
})

local KeyBadge = ui("TextLabel", {
	Parent = Top,
	Size = UDim2.new(0.42, -10, 1, 0),
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

local Tog = ui("TextButton", {
	Parent = SG,
	Size = UDim2.new(0, 52, 0, 52),
	Position = UDim2.new(0, 20, 0.42, 0),
	BackgroundColor3 = Color3.fromRGB(16, 10, 19),
	Text = "DD",
	TextColor3 = Color3.fromRGB(255, 60, 78),
	TextSize = 14,
	Font = Enum.Font.GothamBlack,
	Visible = false
}, 999, Red, 2.2)

local List = ui("ScrollingFrame", {
	Parent = Main,
	Size = UDim2.new(1, -24, 1, -72),
	Position = UDim2.new(0, 12, 0, 64),
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(0, 0, 0, 520),
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Red
})

ui("UIListLayout", {
	Parent = List,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 9)
})

local aimOn, noclipOn, flyOn, jumpOn, brightOn, hlOn = false, false, false, false, false, false
local flySpeed = 55
local origLight = {
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows
}

local function makeBtn(txt, cb)
	local b = ui("TextButton", {
		Parent = List,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Card,
		Text = txt,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 12,
		Font = Enum.Font.GothamBlack
	}, 10, Color3.fromRGB(190, 22, 40), 1.3)
	b.MouseButton1Click:Connect(function()
		cb(b)
	end)
	return b
end

makeBtn("AIMBOT: OFF", function(b)
	aimOn = not aimOn
	b.Text = aimOn and "AIMBOT: ON" or "AIMBOT: OFF"
	b.BackgroundColor3 = aimOn and Red or Card
end)

makeBtn("NOCLIP: OFF", function(b)
	noclipOn = not noclipOn
	b.Text = noclipOn and "NOCLIP: ON" or "NOCLIP: OFF"
	b.BackgroundColor3 = noclipOn and Red or Card
end)

makeBtn("FLY: OFF", function(b)
	flyOn = not flyOn
	b.Text = flyOn and "FLY: ON" or "FLY: OFF"
	b.BackgroundColor3 = flyOn and Red or Card
	if not flyOn and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
		LP.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	end
end)

makeBtn("INFINITE JUMP: OFF", function(b)
	jumpOn = not jumpOn
	b.Text = jumpOn and "INFINITE JUMP: ON" or "INFINITE JUMP: OFF"
	b.BackgroundColor3 = jumpOn and Red or Card
end)

makeBtn("FULLBRIGHT: OFF", function(b)
	brightOn = not brightOn
	b.Text = brightOn and "FULLBRIGHT: ON" or "FULLBRIGHT: OFF"
	b.BackgroundColor3 = brightOn and Red or Card
	if not brightOn then
		Lighting.Brightness = origLight.Brightness
		Lighting.ClockTime = origLight.ClockTime
		Lighting.FogEnd = origLight.FogEnd
		Lighting.GlobalShadows = origLight.GlobalShadows
	end
end)

makeBtn("HIGHLIGHT ESP: OFF", function(b)
	hlOn = not hlOn
	b.Text = hlOn and "HIGHLIGHT ESP: ON" or "HIGHLIGHT ESP: OFF"
	b.BackgroundColor3 = hlOn and Red or Card
	if not hlOn then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and p.Character:FindFirstChild("Highlight") then
				p.Character.Highlight:Destroy()
			end
		end
	end
end)

UIS.JumpRequest:Connect(function()
	if jumpOn and LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
		LP.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

local function submitKey()
	loadRemoteKeys()
	local raw = trim(Pass.Text)
	local firstPart = trim(string.match(raw, "^([^|]+)") or raw)
	local lower = string.lower(firstPart)
	if lower == "" then
		Pass.Text = ""
		Pass.PlaceholderText = "ENTER KEY FIRST"
		return
	end
	local entry = keysDb[lower]
	if not entry then
		Pass.Text = ""
		Pass.PlaceholderText = "WRONG KEY"
		return
	end
	if entry.status == "paused" then
		Pass.Text = ""
		Pass.PlaceholderText = "KEY PAUSED"
		return
	end
	if entry.status ~= "active" then
		Pass.Text = ""
		Pass.PlaceholderText = "KEY BANNED"
		return
	end
	local secs, isInf = parseDuration(entry.duration)
	activeKey = {key = entry.key, infinite = isInf}
	keyExpireAt = isInf and nil or (os.clock() + secs)
	local tStr = getRemainingText()
	KeyBadge.Text = tStr
	TopTimerLbl.Text = tStr
	TopTimerBar.Visible = true
	Pass.Text = ""
	Auth.Visible = false
	Main.Visible = true
	Tog.Visible = true
end

Enter.MouseButton1Click:Connect(submitKey)
Pass.FocusLost:Connect(function(enter)
	if enter then
		submitKey()
	end
end)

Close.MouseButton1Click:Connect(function()
	Main.Visible = false
end)

Tog.MouseButton1Click:Connect(function()
	Main.Visible = not Main.Visible
end)

drag(Top, Main)
drag(Auth, Auth)
drag(Tog, Tog)

local function getClosestEnemy()
	local center = Vector2.new(Cam.ViewportSize.X * 0.5, Cam.ViewportSize.Y * 0.5)
	local best, bestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and head then
				local sp, onScreen = Cam:WorldToViewportPoint(head.Position)
				if onScreen and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					if d < bestD then
						bestD = d
						best = head
					end
				end
			end
		end
	end
	return best
end

local tickTimer = 0
RunService.RenderStepped:Connect(function(dt)
	tickTimer += dt
	if tickTimer >= 0.5 then
		tickTimer = 0
		if activeKey then
			local tStr = getRemainingText()
			KeyBadge.Text = tStr
			TopTimerLbl.Text = tStr
		end
	end

	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if (noclipOn or flyOn) and char then
		for _, v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end
	end

	if flyOn and root and hum then
		local md = hum.MoveDirection
		local up = 0
		if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then up += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then up -= 1 end
		root.AssemblyLinearVelocity = Vector3.new(md.X * flySpeed, up * flySpeed, md.Z * flySpeed)
	end

	if aimOn then
		local target = getClosestEnemy()
		if target then
			local cf = CFrame.new(Cam.CFrame.Position, target.Position)
			Cam.CFrame = Cam.CFrame:Lerp(cf, math.clamp(dt * 18, 0, 1))
		end
	end

	if brightOn then
		Lighting.Brightness = 2.2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
	end

	if hlOn then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character and not p.Character:FindFirstChild("Highlight") then
				local h = Instance.new("Highlight")
				h.FillColor = Red
				h.OutlineColor = Color3.new(1, 1, 1)
				h.FillTransparency = 0.55
				h.Parent = p.Character
			end
		end
	end
end)
