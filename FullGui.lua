-- Unified Admin GUI (Client-side)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Defaults (set before character setup)
local walkSpeed = 16
local jumpPower = 50 -- default Roblox value
local baseWalkSpeed
local baseJumpPower
local baseUseJumpPower
local baseJumpHeight
local moveOverrides = false

-- ===== CHARACTER HANDLING =====
local character, humanoid, hrp
local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")

	baseWalkSpeed = humanoid.WalkSpeed
	baseUseJumpPower = humanoid.UseJumpPower
	baseJumpPower = humanoid.JumpPower
	baseJumpHeight = humanoid.JumpHeight

	if moveOverrides then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpPower
		humanoid.WalkSpeed = walkSpeed
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Running)

	task.defer(function()
		if humanoid then
			if moveOverrides then
				humanoid.UseJumpPower = true
				humanoid.JumpPower = jumpPower
				humanoid.WalkSpeed = walkSpeed
			else
				humanoid.UseJumpPower = baseUseJumpPower
				humanoid.JumpPower = baseJumpPower
				humanoid.JumpHeight = baseJumpHeight
				humanoid.WalkSpeed = baseWalkSpeed
			end
		end
	end)

	if typeof(updateMoveInputs) == "function" then
		updateMoveInputs()
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- ===== CLEAN UP OLD GUIS =====
for _, name in ipairs({"AdminGui"}) do
	if player.PlayerGui:FindFirstChild(name) then
		player.PlayerGui[name]:Destroy()
	end
end

-- ===== STATE =====
-- ESP
local espEnabled = false

-- Fly / Noclip
local flying = false
local noclip = false
local flySpeed = 60
local moveConn, noclipConn
local lv, ao


-- WalkSpeed / Platform
local platformEnabled = false
local platformPart
local platformConn

-- Jump Modifier

-- Tween
local tweenNoclipConn

-- Infinite Jump
local infJumpEnabled = false
local infJumpHolding = false
local infJumpInputBeganConn
local infJumpInputEndedConn
local infJumpConn

-- FOLLOW (BACKPACK)
local followTarget = nil
local followAttachment
local followPos
local followOri
local followConn
local selectedTweenTarget

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "AdminGui"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local guiVisible = true
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Delete then
		guiVisible = not guiVisible
		gui.Enabled = guiVisible
	end
end)

local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.fromScale(0.3, 0.55)
mainFrame.Position = UDim2.fromScale(0.03,0.2)
mainFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,8)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(70,200,70)
mainStroke.Thickness = 1

local mainGradient = Instance.new("UIGradient", mainFrame)
mainGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8,8,8))
})

local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.fromScale(1,0.09)
titleBar.Position = UDim2.fromScale(0,0)
titleBar.BackgroundColor3 = Color3.fromRGB(10,10,10)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,8)

local titleGradient = Instance.new("UIGradient", titleBar)
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(25,25,25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(5,5,5))
})

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.fromScale(1,1)
title.Position = UDim2.fromScale(0,0)
title.BackgroundTransparency = 1
title.Text = "GOOBER MENU"
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(220,220,220)

local minimizeBtn = Instance.new("TextButton", titleBar)
minimizeBtn.Size = UDim2.fromScale(0.1, 0.8)
minimizeBtn.Position = UDim2.fromScale(0.9, 0.1)
minimizeBtn.Text = "-"
minimizeBtn.Font = Enum.Font.GothamBlack
minimizeBtn.TextScaled = true
minimizeBtn.TextColor3 = Color3.fromRGB(70,200,70)
minimizeBtn.BackgroundTransparency = 1

local minimized = false
local fullSize = mainFrame.Size
local minimizedSize = UDim2.fromScale(0.38, 0.09) -- only title bar

-- ===== TAB BUTTONS =====
local tabsFrame = Instance.new("Frame", mainFrame)
tabsFrame.Size = UDim2.fromScale(0.24,0.91)
tabsFrame.Position = UDim2.fromScale(0,0.09)
tabsFrame.BackgroundColor3 = Color3.fromRGB(12,12,12)
tabsFrame.BorderSizePixel = 0

local tabsStroke = Instance.new("UIStroke", tabsFrame)
tabsStroke.Color = Color3.fromRGB(40,120,40)
tabsStroke.Thickness = 1

local tabsList = Instance.new("UIListLayout", tabsFrame)
tabsList.SortOrder = Enum.SortOrder.LayoutOrder
tabsList.Padding = UDim.new(0,6)
tabsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabsList.VerticalAlignment = Enum.VerticalAlignment.Top

local tabsPadding = Instance.new("UIPadding", tabsFrame)
tabsPadding.PaddingTop = UDim.new(0,8)

local function makeTabButton(text)
	local b = Instance.new("TextButton", tabsFrame)
	b.Size = UDim2.fromScale(0.9,0.1)
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(200,200,200)
	b.BackgroundColor3 = Color3.fromRGB(30,30,30)
	b.BorderSizePixel = 0
	Instance.new("UICorner", b)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(40,120,40)
	s.Thickness = 1
	return b
end

local espTabBtn = makeTabButton("ESP")
local flyTabBtn = makeTabButton("FLY")
local moveTabBtn = makeTabButton("PLAYER")
local tweenTabBtn = makeTabButton("TWEEN")
local flingTabBtn = makeTabButton("FLING")
local xrayTabBtn = makeTabButton("XRAY")
local infoTabBtn = makeTabButton("INFO")

-- ===== CONTENT FRAMES =====
local function makeContentFrame()
	local f = Instance.new("Frame", mainFrame)
	f.Size = UDim2.fromScale(0.76,0.91)
	f.Position = UDim2.fromScale(0.24,0.09)
	f.BackgroundTransparency = 1
	f.Visible = false
	return f
end

local espFrame = makeContentFrame()
local flyFrame = makeContentFrame()
local moveFrame = makeContentFrame()
local tweenFrame = makeContentFrame()
local flingFrame = makeContentFrame()
local xrayFrame = makeContentFrame()
local infoFrame = makeContentFrame()

local contentFrames = {espFrame, flyFrame, moveFrame, tweenFrame, flingFrame, xrayFrame, infoFrame}
local tabButtons = {espTabBtn, flyTabBtn, moveTabBtn, tweenTabBtn, flingTabBtn, xrayTabBtn, infoTabBtn}
local function setTabActive(activeBtn)
	for _, b in ipairs(tabButtons) do
		local isActive = (b == activeBtn)
		b.BackgroundColor3 = isActive and Color3.fromRGB(40,80,40) or Color3.fromRGB(30,30,30)
		b.TextColor3 = isActive and Color3.fromRGB(170,255,170) or Color3.fromRGB(200,200,200)
	end
end

local function showFrame(frame, activeBtn)
	for _, f in ipairs(contentFrames) do
		f.Visible = (f == frame)
	end
	if activeBtn then setTabActive(activeBtn) end
end

-- Default: show ESP tab
showFrame(espFrame, espTabBtn)

espTabBtn.MouseButton1Click:Connect(function() showFrame(espFrame, espTabBtn) end)
flyTabBtn.MouseButton1Click:Connect(function() showFrame(flyFrame, flyTabBtn) end)
moveTabBtn.MouseButton1Click:Connect(function() showFrame(moveFrame, moveTabBtn) end)
tweenTabBtn.MouseButton1Click:Connect(function() showFrame(tweenFrame, tweenTabBtn) end)
flingTabBtn.MouseButton1Click:Connect(function() showFrame(flingFrame, flingTabBtn) end)
xrayTabBtn.MouseButton1Click:Connect(function() showFrame(xrayFrame, xrayTabBtn) end)
infoTabBtn.MouseButton1Click:Connect(function() showFrame(infoFrame, infoTabBtn) end)

-- ===== BUTTON CREATOR =====
local function makeButton(parent,text,posY)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.fromScale(0.9,0.11)
	b.Position = UDim2.fromScale(0.05,posY)
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(210,210,210)
	b.BackgroundColor3 = Color3.fromRGB(24,24,24)
	b.BorderSizePixel = 0
	Instance.new("UICorner", b)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(40,120,40)
	s.Thickness = 1
	return b
end
-- ===Minimize===
local function setMinimized(state)
	minimized = state

	local goalSize = minimized and minimizedSize or fullSize

	TweenService:Create(
		mainFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = goalSize }
	):Play()

	-- Hide/show tabs & content
	tabsFrame.Visible = not minimized
	for _, frame in ipairs(contentFrames) do
		frame.Visible = not minimized and frame.Visible
	end
end
minimizeBtn.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
	minimizeBtn.Text = minimized and "+" or "-"
end)

-- ================== ESP ==================
-- Outline + tracer + name (team-aware)
local espObjects = {}
local espRenderConn
local espAddConn
local espRemoveConn

local function isOpponent(plr)
	if not player.Team or not plr.Team then
		return true
	end
	return plr.Team ~= player.Team
end

local function createESP(plr)
	if plr == player then return end
	if espObjects[plr] then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "OutlineESP"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	local tracer = Drawing.new("Line")
	tracer.Thickness = 1.5
	tracer.Color = Color3.fromRGB(255, 255, 255)
	tracer.Visible = false

	local nameText = Drawing.new("Text")
	nameText.Size = 14
	nameText.Center = true
	nameText.Outline = true
	nameText.Color = Color3.fromRGB(255, 255, 255)
	nameText.Visible = false

	espObjects[plr] = {
		highlight = highlight,
		tracer = tracer,
		name = nameText
	}

	local function onCharacter(char)
		if not isOpponent(plr) then return end
		highlight.Parent = char
	end

	if plr.Character then
		onCharacter(plr.Character)
	end
	plr.CharacterAdded:Connect(onCharacter)
end

local function removeESP(plr)
	if espObjects[plr] then
		espObjects[plr].highlight:Destroy()
		espObjects[plr].tracer:Remove()
		espObjects[plr].name:Remove()
		espObjects[plr] = nil
	end
end

local function updateESP()
	for plr, objects in pairs(espObjects) do
		if not isOpponent(plr) then
			objects.tracer.Visible = false
			objects.name.Visible = false
			if objects.highlight then objects.highlight.Enabled = false end
			continue
		end

		local char = plr.Character
		local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if not char or not hrp2 or not hum or hum.Health <= 0 then
			objects.tracer.Visible = false
			objects.name.Visible = false
			if objects.highlight then objects.highlight.Enabled = false end
			continue
		end

		objects.highlight.Enabled = true

		local screenPos, onScreen = camera:WorldToViewportPoint(hrp2.Position)
		if not onScreen then
			objects.tracer.Visible = false
			objects.name.Visible = false
			continue
		end

		objects.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		objects.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
		objects.tracer.Visible = true

		objects.name.Text = plr.Name
		objects.name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
		objects.name.Visible = true
	end
end

local function enableESP()
	if espEnabled then return end
	espEnabled = true
	for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
	espRenderConn = RunService.RenderStepped:Connect(updateESP)
	espAddConn = Players.PlayerAdded:Connect(createESP)
	espRemoveConn = Players.PlayerRemoving:Connect(removeESP)
end

local function disableESP()
	if not espEnabled then return end
	espEnabled = false
	if espRenderConn then espRenderConn:Disconnect(); espRenderConn = nil end
	if espAddConn then espAddConn:Disconnect(); espAddConn = nil end
	if espRemoveConn then espRemoveConn:Disconnect(); espRemoveConn = nil end
	for plr, _ in pairs(espObjects) do
		removeESP(plr)
	end
	espObjects = {}
end

makeButton(espFrame,"ESP ON",0.05).MouseButton1Click:Connect(enableESP)
makeButton(espFrame,"ESP OFF",0.2).MouseButton1Click:Connect(disableESP)

-- ================== XRAY ==================
local xrayEnabled = false
local xrayAddedConn
local xrayCharAdded = {}
local xrayCharRemoving = {}
local xrayParts = {}
local characterModels = {}
local xrayAlpha = 0.9

local function isPlayerPart(inst)
	for model, _ in pairs(characterModels) do
		if inst:IsDescendantOf(model) then
			return true
		end
	end
	return false
end

local function applyXrayTo(inst)
	if not xrayEnabled then return end
	if inst:IsDescendantOf(player.PlayerGui) then return end
	if inst:IsDescendantOf(gui) then return end
	if isPlayerPart(inst) then return end

	if inst:IsA("BasePart") then
		if not xrayParts[inst] then
			xrayParts[inst] = inst.LocalTransparencyModifier
		end
		inst.LocalTransparencyModifier = xrayAlpha
	end
end

local function clearXray()
	for inst, data in pairs(xrayParts) do
		if inst and inst.Parent then
			if inst:IsA("BasePart") and data ~= nil then
				inst.LocalTransparencyModifier = data
			end
		end
	end
	xrayParts = {}
end

local function enableXray()
	if xrayEnabled then return end
	xrayEnabled = true
	characterModels = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			characterModels[plr.Character] = true
		end
	end
	for _, inst in ipairs(workspace:GetDescendants()) do
		applyXrayTo(inst)
	end
	xrayAddedConn = workspace.DescendantAdded:Connect(applyXrayTo)

	for _, plr in ipairs(Players:GetPlayers()) do
		xrayCharAdded[plr] = plr.CharacterAdded:Connect(function(char)
			characterModels[char] = true
			for _, inst in ipairs(char:GetDescendants()) do
				if xrayParts[inst] then
					if inst:IsA("BasePart") then
						inst.LocalTransparencyModifier = 0
					end
					xrayParts[inst] = nil
				end
			end
		end)
		xrayCharRemoving[plr] = plr.CharacterRemoving:Connect(function(char)
			characterModels[char] = nil
		end)
	end
end

local function disableXray()
	if not xrayEnabled then return end
	xrayEnabled = false
	if xrayAddedConn then xrayAddedConn:Disconnect(); xrayAddedConn = nil end
	for _, conn in pairs(xrayCharAdded) do
		if conn then conn:Disconnect() end
	end
	for _, conn in pairs(xrayCharRemoving) do
		if conn then conn:Disconnect() end
	end
	xrayCharAdded = {}
	xrayCharRemoving = {}
	characterModels = {}
	clearXray()
end

makeButton(xrayFrame,"XRAY ON",0.05).MouseButton1Click:Connect(enableXray)
makeButton(xrayFrame,"XRAY OFF",0.2).MouseButton1Click:Connect(disableXray)

local xrayControlFrame = Instance.new("Frame", xrayFrame)
xrayControlFrame.Size = UDim2.fromScale(0.9, 0.2)
xrayControlFrame.Position = UDim2.fromScale(0.05, 0.35)
xrayControlFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
xrayControlFrame.BorderSizePixel = 0
Instance.new("UICorner", xrayControlFrame)
local xrayControlStroke = Instance.new("UIStroke", xrayControlFrame)
xrayControlStroke.Color = Color3.fromRGB(40,120,40)
xrayControlStroke.Thickness = 1

local xrayLabel = Instance.new("TextLabel", xrayControlFrame)
xrayLabel.Size = UDim2.fromScale(1, 0.35)
xrayLabel.Position = UDim2.fromScale(0, 0.05)
xrayLabel.BackgroundTransparency = 1
xrayLabel.Text = "XRAY TRANSPARENCY (%)"
xrayLabel.Font = Enum.Font.GothamBlack
xrayLabel.TextScaled = true
xrayLabel.TextColor3 = Color3.fromRGB(210,210,210)

local xrayBox = Instance.new("TextBox", xrayControlFrame)
xrayBox.Size = UDim2.fromScale(0.25, 0.35)
xrayBox.Position = UDim2.fromScale(0.72, 0.55)
xrayBox.BackgroundColor3 = Color3.fromRGB(14,14,14)
xrayBox.BorderSizePixel = 0
xrayBox.Text = tostring(math.floor(xrayAlpha * 100))
xrayBox.Font = Enum.Font.GothamBlack
xrayBox.TextScaled = true
xrayBox.TextColor3 = Color3.fromRGB(220,220,220)
xrayBox.ClearTextOnFocus = false
Instance.new("UICorner", xrayBox)
local xrayBoxStroke = Instance.new("UIStroke", xrayBox)
xrayBoxStroke.Color = Color3.fromRGB(40,120,40)
xrayBoxStroke.Thickness = 1

local sliderTrack = Instance.new("Frame", xrayControlFrame)
sliderTrack.Size = UDim2.fromScale(0.65, 0.18)
sliderTrack.Position = UDim2.fromScale(0.05, 0.63)
sliderTrack.BackgroundColor3 = Color3.fromRGB(12,12,12)
sliderTrack.BorderSizePixel = 0
sliderTrack.Active = true
sliderTrack.ClipsDescendants = true
Instance.new("UICorner", sliderTrack)
local sliderStroke = Instance.new("UIStroke", sliderTrack)
sliderStroke.Color = Color3.fromRGB(40,120,40)
sliderStroke.Thickness = 1

local sliderFill = Instance.new("Frame", sliderTrack)
sliderFill.Size = UDim2.fromScale(xrayAlpha, 1)
sliderFill.BackgroundColor3 = Color3.fromRGB(40,80,40)
sliderFill.BorderSizePixel = 0
Instance.new("UICorner", sliderFill)

local sliderKnob = Instance.new("Frame", sliderTrack)
sliderKnob.Size = UDim2.new(0, 10, 1, 4)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.Position = UDim2.new(xrayAlpha, 0, 0.5, 0)
sliderKnob.BackgroundColor3 = Color3.fromRGB(70,200,70)
sliderKnob.BorderSizePixel = 0
Instance.new("UICorner", sliderKnob)

local sliderHit = Instance.new("TextButton", sliderTrack)
sliderHit.Size = UDim2.fromScale(1,1)
sliderHit.BackgroundTransparency = 1
sliderHit.Text = ""

local draggingXray = false
local function applyXrayAlphaFromPercent(pct)
	local v = tonumber(pct)
	if not v then return end
	v = math.clamp(v, 0, 100)
	xrayAlpha = v / 100
	sliderFill.Size = UDim2.fromScale(xrayAlpha, 1)
	sliderKnob.Position = UDim2.new(xrayAlpha, 0, 0.5, 0)
	xrayBox.Text = tostring(math.floor(v))
	if xrayEnabled then
		for inst, _ in pairs(xrayParts) do
			if inst and inst.Parent and inst:IsA("BasePart") then
				inst.LocalTransparencyModifier = xrayAlpha
			end
		end
	end
end

sliderHit.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingXray = true
		local pos = (input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X
		applyXrayAlphaFromPercent(math.floor(math.clamp(pos, 0, 1) * 100))
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingXray = false
	end
end)

UIS.InputChanged:Connect(function(input)
	if not draggingXray then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local pos = (input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X
		applyXrayAlphaFromPercent(math.floor(math.clamp(pos, 0, 1) * 100))
	end
end)

xrayBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applyXrayAlphaFromPercent(xrayBox.Text)
	end
end)

-- ================== INFO ==================
local infoContainer = Instance.new("Frame", infoFrame)
infoContainer.Size = UDim2.fromScale(0.92, 0.9)
infoContainer.Position = UDim2.fromScale(0.04, 0.05)
infoContainer.BackgroundColor3 = Color3.fromRGB(18,18,18)
infoContainer.BorderSizePixel = 0
Instance.new("UICorner", infoContainer)
local infoStroke = Instance.new("UIStroke", infoContainer)
infoStroke.Color = Color3.fromRGB(40,120,40)
infoStroke.Thickness = 1

local infoList = Instance.new("UIListLayout", infoContainer)
infoList.SortOrder = Enum.SortOrder.LayoutOrder
infoList.Padding = UDim.new(0,6)

local infoPad = Instance.new("UIPadding", infoContainer)
infoPad.PaddingTop = UDim.new(0,8)
infoPad.PaddingLeft = UDim.new(0,10)
infoPad.PaddingRight = UDim.new(0,10)

local function makeInfoRow(labelText)
	local row = Instance.new("TextLabel", infoContainer)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundTransparency = 1
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Font = Enum.Font.GothamBlack
	row.TextScaled = true
	row.TextColor3 = Color3.fromRGB(210,210,210)
	row.Text = labelText
	return row
end

local infoName = makeInfoRow("Name: ")
local infoDisplay = makeInfoRow("Display: ")
local infoUserId = makeInfoRow("UserId: ")
local infoAge = makeInfoRow("Account Age: ")
local infoTeam = makeInfoRow("Team: ")
local infoHealth = makeInfoRow("Health: ")
local infoPos = makeInfoRow("Position: ")
local infoSpeed = makeInfoRow("WalkSpeed: ")
local infoJump = makeInfoRow("JumpPower: ")
local infoPing = makeInfoRow("(Your) Ping: ")

local infoDivider = Instance.new("Frame", infoContainer)
infoDivider.Size = UDim2.new(1, 0, 0, 1)
infoDivider.BackgroundColor3 = Color3.fromRGB(40,120,40)
infoDivider.BorderSizePixel = 0

local infoTargetLabel = makeInfoRow("Target: (You)")

local infoListFrame = Instance.new("Frame", infoContainer)
infoListFrame.Size = UDim2.new(1, 0, 0, 200)
infoListFrame.BackgroundColor3 = Color3.fromRGB(16,16,16)
infoListFrame.BorderSizePixel = 0
Instance.new("UICorner", infoListFrame)
local infoListStroke = Instance.new("UIStroke", infoListFrame)
infoListStroke.Color = Color3.fromRGB(40,120,40)
infoListStroke.Thickness = 1

local infoScroll = Instance.new("ScrollingFrame", infoListFrame)
infoScroll.Size = UDim2.fromScale(1,1)
infoScroll.BackgroundTransparency = 1
infoScroll.BorderSizePixel = 0
infoScroll.ScrollBarThickness = 6
infoScroll.ScrollBarImageColor3 = Color3.fromRGB(70,200,70)
infoScroll.CanvasSize = UDim2.new(0,0,0,0)

local infoListLayout = Instance.new("UIListLayout", infoScroll)
infoListLayout.SortOrder = Enum.SortOrder.LayoutOrder
infoListLayout.Padding = UDim.new(0,4)

local infoListPad = Instance.new("UIPadding", infoScroll)
infoListPad.PaddingTop = UDim.new(0,6)
infoListPad.PaddingLeft = UDim.new(0,6)
infoListPad.PaddingRight = UDim.new(0,6)

infoListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	infoScroll.CanvasSize = UDim2.new(0, 0, 0, infoListLayout.AbsoluteContentSize.Y + 12)
end)

infoScroll.Parent = infoListFrame

local selectedInfoPlayer = player
local infoButtons = {}

local function setInfoTarget(plr)
	selectedInfoPlayer = plr or player
	infoTargetLabel.Text = "Target: " .. (selectedInfoPlayer == player and "(You)" or selectedInfoPlayer.Name)
	for _, data in pairs(infoButtons) do
		local active = data.player == selectedInfoPlayer
		data.button.BackgroundColor3 = active and Color3.fromRGB(40,80,40) or Color3.fromRGB(22,22,22)
	end
end

local function refreshInfoPlayerList()
	for _, child in ipairs(infoScroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	infoButtons = {}

	local list = Players:GetPlayers()
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)

	for _, plr in ipairs(list) do
		local b = Instance.new("TextButton", infoScroll)
		b.Size = UDim2.new(1, -12, 0, 26)
		b.BackgroundColor3 = Color3.fromRGB(22,22,22)
		b.BorderSizePixel = 0
		b.Text = plr.Name
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = Color3.fromRGB(210,210,210)
		Instance.new("UICorner", b)
		local s = Instance.new("UIStroke", b)
		s.Color = Color3.fromRGB(40,120,40)
		s.Thickness = 1

		infoButtons[plr.Name] = { button = b, player = plr }
		b.MouseButton1Click:Connect(function()
			setInfoTarget(plr)
		end)
	end

	if selectedInfoPlayer and not infoButtons[selectedInfoPlayer.Name] then
		selectedInfoPlayer = player
	end
	setInfoTarget(selectedInfoPlayer)
end

local function getStatValue(path)
	local ok, stats = pcall(function() return game:GetService("Stats") end)
	if not ok or not stats then return "N/A" end
	local node = stats
	for _, name in ipairs(path) do
		node = node:FindFirstChild(name)
		if not node then return "N/A" end
	end
	local ok2, val = pcall(function() return node:GetValueString() end)
	if ok2 and val then return val end
	return "N/A"
end

local function updateInfo()
	local plr = selectedInfoPlayer or player
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	infoName.Text = "Name: " .. plr.Name
	infoDisplay.Text = "Display: " .. plr.DisplayName
	infoUserId.Text = "UserId: " .. tostring(plr.UserId)
	infoAge.Text = "Account Age: " .. tostring(plr.AccountAge) .. " days"
	infoTeam.Text = "Team: " .. (plr.Team and plr.Team.Name or "None")
	infoHealth.Text = "Health: " .. (hum and math.floor(hum.Health) or 0)
	if root then
		local p = root.Position
		infoPos.Text = string.format("Position: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)
	else
		infoPos.Text = "Position: N/A"
	end
	if hum then
		infoSpeed.Text = "WalkSpeed: " .. tostring(hum.WalkSpeed)
		infoJump.Text = "JumpPower: " .. tostring(hum.JumpPower)
	else
		infoSpeed.Text = "WalkSpeed: N/A"
		infoJump.Text = "JumpPower: N/A"
	end
	infoPing.Text = "(Your) Ping: " .. getStatValue({"Network", "ServerStatsItem", "Data Ping"})
end

local infoTick = 0
RunService.Heartbeat:Connect(function(dt)
	infoTick += dt
	if infoTick >= 0.3 then
		infoTick = 0
		updateInfo()
	end
end)

Players.PlayerAdded:Connect(refreshInfoPlayerList)
Players.PlayerRemoving:Connect(function(plr)
	if selectedInfoPlayer == plr then
		selectedInfoPlayer = player
	end
	refreshInfoPlayerList()
end)

refreshInfoPlayerList()
setInfoTarget(player)

-- ================== FLING ==================
local flingStatus = Instance.new("TextLabel", flingFrame)
flingStatus.Size = UDim2.fromScale(0.9,0.08)
flingStatus.Position = UDim2.fromScale(0.05,0.02)
flingStatus.BackgroundTransparency = 1
flingStatus.Text = "Select targets to fling"
flingStatus.TextColor3 = Color3.fromRGB(220,220,220)
flingStatus.Font = Enum.Font.GothamBlack
flingStatus.TextScaled = true
flingStatus.TextXAlignment = Enum.TextXAlignment.Left

local flingListFrame = Instance.new("Frame", flingFrame)
flingListFrame.Size = UDim2.fromScale(0.9,0.6)
flingListFrame.Position = UDim2.fromScale(0.05,0.12)
flingListFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
flingListFrame.BorderSizePixel = 0
Instance.new("UICorner", flingListFrame)
local flingListStroke = Instance.new("UIStroke", flingListFrame)
flingListStroke.Color = Color3.fromRGB(40,120,40)
flingListStroke.Thickness = 1

local flingScroll = Instance.new("ScrollingFrame", flingListFrame)
flingScroll.Size = UDim2.fromScale(1,1)
flingScroll.BackgroundTransparency = 1
flingScroll.BorderSizePixel = 0
flingScroll.ScrollBarThickness = 6
flingScroll.ScrollBarImageColor3 = Color3.fromRGB(70,200,70)
flingScroll.CanvasSize = UDim2.new(0,0,0,0)
flingScroll.Parent = flingListFrame

local flingListLayout = Instance.new("UIListLayout", flingScroll)
flingListLayout.SortOrder = Enum.SortOrder.LayoutOrder
flingListLayout.Padding = UDim.new(0,4)

flingListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	flingScroll.CanvasSize = UDim2.new(0, 0, 0, flingListLayout.AbsoluteContentSize.Y + 12)
end)

local flingPadding = Instance.new("UIPadding", flingScroll)
flingPadding.PaddingTop = UDim.new(0,6)
flingPadding.PaddingLeft = UDim.new(0,6)
flingPadding.PaddingRight = UDim.new(0,6)

local function makeFlingButton(text, x, y, w, h, color)
	local b = Instance.new("TextButton", flingFrame)
	b.Size = UDim2.fromScale(w,h)
	b.Position = UDim2.fromScale(x,y)
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(220,220,220)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	Instance.new("UICorner", b)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(40,120,40)
	s.Thickness = 1
	return b
end

local startFlingBtn = makeFlingButton("START FLING", 0.05, 0.75, 0.44, 0.11, Color3.fromRGB(30,70,30))
local stopFlingBtn = makeFlingButton("STOP FLING", 0.51, 0.75, 0.44, 0.11, Color3.fromRGB(70,30,30))
local selectAllBtn = makeFlingButton("SELECT ALL", 0.05, 0.88, 0.44, 0.09, Color3.fromRGB(26,26,26))
local deselectAllBtn = makeFlingButton("DESELECT ALL", 0.51, 0.88, 0.44, 0.09, Color3.fromRGB(26,26,26))

local flingCredit = Instance.new("TextLabel", flingFrame)
flingCredit.Size = UDim2.fromScale(0.9,0.05)
flingCredit.Position = UDim2.fromScale(0.05,0.955)
flingCredit.BackgroundTransparency = 1
flingCredit.Text = "Fling by KILASIK (based on zqyDSUWX)"
flingCredit.TextColor3 = Color3.fromRGB(160,160,160)
flingCredit.Font = Enum.Font.GothamBlack
flingCredit.TextScaled = true
flingCredit.TextXAlignment = Enum.TextXAlignment.Left

local SelectedTargets = {}
local PlayerCheckboxes = {}
local FlingActive = false
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local function CountSelectedTargets()
	local count = 0
	for _ in pairs(SelectedTargets) do
		count += 1
	end
	return count
end

local function UpdateFlingStatus()
	local count = CountSelectedTargets()
	if FlingActive then
		flingStatus.Text = "Flinging " .. count .. " target(s)"
		flingStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
	else
		flingStatus.Text = count .. " target(s) selected"
		flingStatus.TextColor3 = Color3.fromRGB(220,220,220)
	end
end

local function RefreshFlingPlayerList()
	for _, child in ipairs(flingScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	PlayerCheckboxes = {}

	local list = Players:GetPlayers()
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)

	for i, plr in ipairs(list) do
		if plr ~= player then
			local entry = Instance.new("Frame")
			entry.Size = UDim2.new(1, -12, 0, 28)
			entry.BackgroundColor3 = Color3.fromRGB(24,24,24)
			entry.BorderSizePixel = 0
			entry.LayoutOrder = i
			entry.Parent = flingScroll
			Instance.new("UICorner", entry)
			local entryStroke = Instance.new("UIStroke", entry)
			entryStroke.Color = Color3.fromRGB(40,120,40)
			entryStroke.Thickness = 1

			local checkbox = Instance.new("TextButton")
			checkbox.Size = UDim2.new(0, 22, 0, 22)
			checkbox.Position = UDim2.new(0, 3, 0.5, -11)
			checkbox.BackgroundColor3 = Color3.fromRGB(18,18,18)
			checkbox.BorderSizePixel = 0
			checkbox.Text = ""
			checkbox.Parent = entry
			Instance.new("UICorner", checkbox)

			local checkmark = Instance.new("TextLabel")
			checkmark.Size = UDim2.new(1, 0, 1, 0)
			checkmark.BackgroundTransparency = 1
			checkmark.Text = "X"
			checkmark.TextColor3 = Color3.fromRGB(0, 255, 0)
			checkmark.TextScaled = true
			checkmark.Font = Enum.Font.GothamBlack
			checkmark.Visible = SelectedTargets[plr.Name] ~= nil
			checkmark.Parent = checkbox

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -32, 1, 0)
			nameLabel.Position = UDim2.new(0, 30, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = plr.Name
			nameLabel.TextColor3 = Color3.fromRGB(220,220,220)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBlack
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = entry

			local clickArea = Instance.new("TextButton")
			clickArea.Size = UDim2.new(1, 0, 1, 0)
			clickArea.BackgroundTransparency = 1
			clickArea.Text = ""
			clickArea.ZIndex = 2
			clickArea.Parent = entry

			clickArea.MouseButton1Click:Connect(function()
				if SelectedTargets[plr.Name] then
					SelectedTargets[plr.Name] = nil
					checkmark.Visible = false
				else
					SelectedTargets[plr.Name] = plr
					checkmark.Visible = true
				end
				UpdateFlingStatus()
			end)

			PlayerCheckboxes[plr.Name] = {
				Entry = entry,
				Checkmark = checkmark
			}
		end
	end

	flingScroll.CanvasSize = UDim2.new(0, 0, 0, flingListLayout.AbsoluteContentSize.Y + 12)
end

local function ToggleAllPlayers(select)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local checkboxData = PlayerCheckboxes[plr.Name]
			if checkboxData then
				if select then
					SelectedTargets[plr.Name] = plr
					checkboxData.Checkmark.Visible = true
				else
					SelectedTargets[plr.Name] = nil
					checkboxData.Checkmark.Visible = false
				end
			end
		end
	end
	UpdateFlingStatus()
end

local function FlingMessage(titleText, bodyText, timeSeconds)
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = titleText,
		Text = bodyText,
		Duration = timeSeconds or 5
	})
end

local function SkidFling(TargetPlayer)
	local Character = player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Humanoid and Humanoid.RootPart
	local TCharacter = TargetPlayer.Character
	if not TCharacter then return end

	local THumanoid
	local TRootPart
	local THead
	local Accessory
	local Handle
	if TCharacter:FindFirstChildOfClass("Humanoid") then
		THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
	end
	if THumanoid and THumanoid.RootPart then
		TRootPart = THumanoid.RootPart
	end
	if TCharacter:FindFirstChild("Head") then
		THead = TCharacter.Head
	end
	if TCharacter:FindFirstChildOfClass("Accessory") then
		Accessory = TCharacter:FindFirstChildOfClass("Accessory")
	end
	if Accessory and Accessory:FindFirstChild("Handle") then
		Handle = Accessory.Handle
	end
	if Character and Humanoid and RootPart then
		if RootPart.Velocity.Magnitude < 50 then
			getgenv().OldPos = RootPart.CFrame
		end

		if THumanoid and THumanoid.Sit then
			return FlingMessage("Error", TargetPlayer.Name .. " is sitting", 2)
		end

		if THead then
			workspace.CurrentCamera.CameraSubject = THead
		elseif Handle then
			workspace.CurrentCamera.CameraSubject = Handle
		elseif THumanoid and TRootPart then
			workspace.CurrentCamera.CameraSubject = THumanoid
		end

		if not TCharacter:FindFirstChildWhichIsA("BasePart") then
			return
		end

		local FPos = function(BasePart, Pos, Ang)
			RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
			Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
			RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
			RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
		end

		local SFBasePart = function(BasePart)
			local TimeToWait = 2
			local Time = tick()
			local Angle = 0
			repeat
				if RootPart and THumanoid then
					if BasePart.Velocity.Magnitude < 50 then
						Angle = Angle + 100
						FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
						task.wait()
					else
						FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
						task.wait()

						FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
						task.wait()
						FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
						task.wait()
					end
				end
			until Time + TimeToWait < tick() or not FlingActive
		end

		workspace.FallenPartsDestroyHeight = 0/0

		local BV = Instance.new("BodyVelocity")
		BV.Parent = RootPart
		BV.Velocity = Vector3.new(0, 0, 0)
		BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

		if TRootPart then
			SFBasePart(TRootPart)
		elseif THead then
			SFBasePart(THead)
		elseif Handle then
			SFBasePart(Handle)
		else
			return FlingMessage("Error", TargetPlayer.Name .. " has no valid parts", 2)
		end

		BV:Destroy()
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
		workspace.CurrentCamera.CameraSubject = Humanoid

		if getgenv().OldPos then
			repeat
				RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
				Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
				Humanoid:ChangeState("GettingUp")
				for _, part in pairs(Character:GetChildren()) do
					if part:IsA("BasePart") then
						part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()
					end
				end
				task.wait()
			until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
			workspace.FallenPartsDestroyHeight = getgenv().FPDH
		end
	else
		return FlingMessage("Error", "Your character is not ready", 2)
	end
end

local function StartFling()
	if FlingActive then return end
	local count = CountSelectedTargets()
	if count == 0 then
		flingStatus.Text = "No targets selected!"
		task.wait(1)
		flingStatus.Text = "Select targets to fling"
		return
	end

	FlingActive = true
	UpdateFlingStatus()
	FlingMessage("Started", "Flinging " .. count .. " targets", 2)

	task.spawn(function()
		while FlingActive do
			local validTargets = {}
			for name, plr in pairs(SelectedTargets) do
				if plr and plr.Parent then
					validTargets[name] = plr
				else
					SelectedTargets[name] = nil
					local checkbox = PlayerCheckboxes[name]
					if checkbox then
						checkbox.Checkmark.Visible = false
					end
				end
			end

			for _, plr in pairs(validTargets) do
				if FlingActive then
					SkidFling(plr)
					task.wait(0.1)
				else
					break
				end
			end

			UpdateFlingStatus()
			task.wait(0.5)
		end
	end)
end

local function StopFling()
	if not FlingActive then return end
	FlingActive = false
	UpdateFlingStatus()
	FlingMessage("Stopped", "Fling has been stopped", 2)
end

startFlingBtn.MouseButton1Click:Connect(StartFling)
stopFlingBtn.MouseButton1Click:Connect(StopFling)
selectAllBtn.MouseButton1Click:Connect(function() ToggleAllPlayers(true) end)
deselectAllBtn.MouseButton1Click:Connect(function() ToggleAllPlayers(false) end)

Players.PlayerAdded:Connect(function()
	RefreshFlingPlayerList()
	UpdateFlingStatus()
end)
Players.PlayerRemoving:Connect(function(plr)
	if SelectedTargets[plr.Name] then
		SelectedTargets[plr.Name] = nil
	end
	RefreshFlingPlayerList()
	UpdateFlingStatus()
end)

RefreshFlingPlayerList()
UpdateFlingStatus()

-- ================== FLY / NOCLIP ==================
local flyBV
local flyBG

local function startFly()
	if flying or not hrp or not humanoid then return end
	flying = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	humanoid.AutoRotate = false

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	flyBG.P = 8e4
	flyBG.D = 1e3
	flyBG.CFrame = hrp.CFrame
	flyBG.Parent = hrp

	moveConn = RunService.RenderStepped:Connect(function()
		local camCF = camera.CFrame
		local dir = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then dir += camCF.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= camCF.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= camCF.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then dir += camCF.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end

		if dir.Magnitude < 0.1 then
			flyBV.Velocity = Vector3.zero
		else
			flyBV.Velocity = dir.Unit * flySpeed
		end

		local look = camCF.LookVector
		flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(look.X, 0, look.Z))
	end)
end

local function stopFly()
	flying = false
	if moveConn then moveConn:Disconnect() end
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
	if humanoid then
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

local function startNoclip()
	if noclip then return end
	noclip = true
	noclipConn = RunService.Stepped:Connect(function()
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
	end)
end

local function stopNoclip()
	noclip = false
	if noclipConn then noclipConn:Disconnect() end
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end

makeButton(flyFrame,"FLY ON",0.02).MouseButton1Click:Connect(startFly)
makeButton(flyFrame,"FLY OFF",0.18).MouseButton1Click:Connect(stopFly)
makeButton(flyFrame,"NOCLIP ON",0.34).MouseButton1Click:Connect(startNoclip)
makeButton(flyFrame,"NOCLIP OFF",0.5).MouseButton1Click:Connect(stopNoclip)
makeButton(flyFrame,"SPEED +",0.66).MouseButton1Click:Connect(function() flySpeed += 10 end)
makeButton(flyFrame,"SPEED -",0.82).MouseButton1Click:Connect(function() flySpeed = math.max(10,flySpeed-10) end)

-- ================== WALK SPEED / JUMP / PLATFORM ==================
local function applyWalkSpeed(value)
	local v = tonumber(value)
	if not v then return end
	v = math.clamp(v, 0, 200)
	walkSpeed = v
	moveOverrides = true
	if humanoid then humanoid.WalkSpeed = walkSpeed end
end

local function applyJumpPower(value)
	local v = tonumber(value)
	if not v then return end
	v = math.clamp(v, 0, 200)
	jumpPower = v
	moveOverrides = true
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpPower
	end
end

if humanoid and moveOverrides then
	humanoid.WalkSpeed = walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = jumpPower
end

local function enablePlatform()
	if platformEnabled or not hrp then return end
	platformEnabled = true
	platformPart = Instance.new("Part")
	platformPart.Size = Vector3.new(6,1,6)
	platformPart.Transparency = 1
	platformPart.Anchored = true
	platformPart.CanCollide = true
	platformPart.Name = "AirPlatform"
	platformPart.Parent = workspace
	platformConn = RunService.RenderStepped:Connect(function()
		if hrp and platformPart then platformPart.CFrame = hrp.CFrame * CFrame.new(0,-3.5,0) end
	end)
end

local function disablePlatform()
	platformEnabled = false
	if platformConn then platformConn:Disconnect() end
	if platformPart then platformPart:Destroy() end
end

-- ================== INFINITE JUMP ==================
local function enableInfJump()
	if infJumpEnabled then return end
	infJumpEnabled = true
	infJumpHolding = false

	infJumpInputBeganConn = UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Space then
			infJumpHolding = true
		end
	end)

	infJumpInputEndedConn = UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			infJumpHolding = false
		end
	end)

	infJumpConn = RunService.RenderStepped:Connect(function()
		if infJumpHolding and humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end

local function disableInfJump()
	if not infJumpEnabled then return end
	infJumpEnabled = false
	infJumpHolding = false
	if infJumpInputBeganConn then infJumpInputBeganConn:Disconnect(); infJumpInputBeganConn = nil end
	if infJumpInputEndedConn then infJumpInputEndedConn:Disconnect(); infJumpInputEndedConn = nil end
	if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
end

local moveTop = Instance.new("Frame", moveFrame)
moveTop.Size = UDim2.fromScale(0.9,0.2)
moveTop.Position = UDim2.fromScale(0.05,0.05)
moveTop.BackgroundTransparency = 1

local function makeInputBlock(parent, x, labelText, defaultValue)
	local block = Instance.new("Frame", parent)
	block.Size = UDim2.fromScale(0.48,1)
	block.Position = UDim2.fromScale(x,0)
	block.BackgroundColor3 = Color3.fromRGB(20,20,20)
	block.BorderSizePixel = 0
	Instance.new("UICorner", block)
	local s = Instance.new("UIStroke", block)
	s.Color = Color3.fromRGB(40,120,40)
	s.Thickness = 1

	local label = Instance.new("TextLabel", block)
	label.Size = UDim2.fromScale(1,0.4)
	label.Position = UDim2.fromScale(0,0.05)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200,200,200)

	local box = Instance.new("TextBox", block)
	box.Size = UDim2.fromScale(0.9,0.45)
	box.Position = UDim2.fromScale(0.05,0.5)
	box.BackgroundColor3 = Color3.fromRGB(14,14,14)
	box.BorderSizePixel = 0
	box.Text = tostring(defaultValue)
	box.Font = Enum.Font.GothamBlack
	box.TextScaled = true
	box.TextColor3 = Color3.fromRGB(220,220,220)
	box.ClearTextOnFocus = false
	Instance.new("UICorner", box)
	local bs = Instance.new("UIStroke", box)
	bs.Color = Color3.fromRGB(40,120,40)
	bs.Thickness = 1

	return box
end

local speedBox = makeInputBlock(moveTop, 0, "WALK SPEED", walkSpeed)
local jumpBox = makeInputBlock(moveTop, 0.52, "JUMP POWER", jumpPower)

local function updateMoveInputs()
	if humanoid and not moveOverrides then
		if speedBox then speedBox.Text = tostring(humanoid.WalkSpeed) end
		if jumpBox then
			if humanoid.UseJumpPower then
				jumpBox.Text = tostring(humanoid.JumpPower)
			else
				jumpBox.Text = tostring(humanoid.JumpHeight)
			end
		end
	else
		if speedBox then speedBox.Text = tostring(walkSpeed) end
		if jumpBox then jumpBox.Text = tostring(jumpPower) end
	end
end

speedBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applyWalkSpeed(speedBox.Text)
		speedBox.Text = tostring(walkSpeed)
	end
end)

jumpBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applyJumpPower(jumpBox.Text)
		jumpBox.Text = tostring(jumpPower)
	end
end)

local applyBtn = makeButton(moveFrame, "APPLY VALUES", 0.3)
applyBtn.MouseButton1Click:Connect(function()
	applyWalkSpeed(speedBox.Text)
	applyJumpPower(jumpBox.Text)
	updateMoveInputs()
end)

local resetBtn = makeButton(moveFrame, "RESET TO DEFAULT", 0.42)
resetBtn.MouseButton1Click:Connect(function()
	moveOverrides = false
	if humanoid then
		humanoid.WalkSpeed = baseWalkSpeed or humanoid.WalkSpeed
		humanoid.UseJumpPower = baseUseJumpPower
		humanoid.JumpPower = baseJumpPower or humanoid.JumpPower
		humanoid.JumpHeight = baseJumpHeight or humanoid.JumpHeight
	end
	walkSpeed = baseWalkSpeed or 16
	jumpPower = baseJumpPower or 50
	updateMoveInputs()
end)

local platformBtn = makeButton(moveFrame,"PLATFORM: OFF",0.6)
local function updatePlatformBtn()
	platformBtn.Text = platformEnabled and "PLATFORM: ON" or "PLATFORM: OFF"
end
platformBtn.MouseButton1Click:Connect(function()
	if platformEnabled then
		disablePlatform()
	else
		enablePlatform()
	end
	updatePlatformBtn()
end)
updatePlatformBtn()

local infJumpBtn = makeButton(moveFrame,"INF JUMP: OFF",0.75)
infJumpBtn.Size = UDim2.fromScale(0.9,0.09)
local function updateInfJumpBtn()
	infJumpBtn.Text = infJumpEnabled and "INF JUMP: ON" or "INF JUMP: OFF"
end
infJumpBtn.MouseButton1Click:Connect(function()
	if infJumpEnabled then
		disableInfJump()
	else
		enableInfJump()
	end
	updateInfJumpBtn()
end)
updateInfJumpBtn()

-- ================== TWEEN TO PLAYER ==================
local function getChar()
	local char = player.Character or player.CharacterAdded:Wait()
	return char, char:WaitForChild("Humanoid"), char:WaitForChild("HumanoidRootPart")
end

local function enableTweenNoclip()
	tweenNoclipConn = RunService.Stepped:Connect(function()
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
	end)
end

local function disableTweenNoclip()
	if tweenNoclipConn then tweenNoclipConn:Disconnect() end
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
end

local tweenInProgress = false
local function TweenToPlayer(target)
	if tweenInProgress then return end
	if not target or not target.Character or not hrp or not humanoid then return end
	local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	tweenInProgress = true

	local finalOffset = Vector3.new(0, 2.5, -3)
	local targetPos = targetHRP.Position + finalOffset
	local distance = (hrp.Position - targetPos).Magnitude
	local time = math.clamp(distance / 45, 0.6, 4)

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	enableTweenNoclip()
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(targetPos) }
	)
	tween:Play()
	tween.Completed:Wait()

	disableTweenNoclip()
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	tweenInProgress = false
end
local function enableFollowNoclip()
	followConn = RunService.Stepped:Connect(function()
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
				end
			end
		end
	end)
end

local function disableFollowNoclip()
	if followConn then followConn:Disconnect() end
	if character then
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = true
			end
		end
	end
end

local function AttachToPlayer(target)
	if not target or not target.Character or not hrp then return end
	local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end

	-- Cleanup old
	DetachFromPlayer()

	followTarget = target
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	enableFollowNoclip()

	followAttachment = Instance.new("Attachment", hrp)

	local targetAttachment = Instance.new("Attachment", targetHRP)
targetAttachment.Name = "FollowTargetAttachment"

-- Stay behind the player
targetAttachment.Position = Vector3.new(0, 0, 2.5)
targetAttachment.Orientation = Vector3.new(0, 0, 0)

	followPos = Instance.new("AlignPosition")
	followPos.Attachment0 = followAttachment
	followPos.Attachment1 = targetAttachment
	followPos.MaxForce = math.huge
	followPos.Responsiveness = 200
	followPos.Parent = hrp

	followOri = Instance.new("AlignOrientation")
	followOri.Attachment0 = followAttachment
	followOri.Attachment1 = targetAttachment
	followOri.MaxTorque = math.huge
	followOri.Responsiveness = 200
	followOri.Parent = hrp
end

function DetachFromPlayer()
	followTarget = nil

	if followPos then followPos:Destroy() end
	if followOri then followOri:Destroy() end
	if followAttachment then followAttachment:Destroy() end

	-- Remove target attachment safely
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			local att = plr.Character:FindFirstChild("HumanoidRootPart")
			if att and att:FindFirstChild("FollowTargetAttachment") then
				att.FollowTargetAttachment:Destroy()
			end
		end
	end

	disableFollowNoclip()
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
end

-- GUI ScrollFrame for players
local attachBtn = makeButton(tweenFrame, "ATTACH (BACKPACK)", 0.02)
local detachBtn = makeButton(tweenFrame, "LET GO", 0.16)

attachBtn.Size = UDim2.fromScale(0.9, 0.12)
detachBtn.Size = UDim2.fromScale(0.9, 0.12)

attachBtn.MouseButton1Click:Connect(function()
	if selectedTweenTarget then
		AttachToPlayer(selectedTweenTarget)
	end
end)

detachBtn.MouseButton1Click:Connect(DetachFromPlayer)

local scrollFrame = Instance.new("ScrollingFrame", tweenFrame)
scrollFrame.Size = UDim2.fromScale(0.95, 0.65)
scrollFrame.Position = UDim2.fromScale(0.025, 0.32)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0,0,0,0)
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70,200,70)

local uiList = Instance.new("UIListLayout",scrollFrame)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0,4)

local function makeTweenButton(plr)
	if plr == player then return end
	local b = Instance.new("TextButton", scrollFrame)
	b.Size = UDim2.new(1,0,0,35)
	b.Text = plr.Name
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(210,210,210)
	b.BackgroundColor3 = Color3.fromRGB(24,24,24)
	b.BorderSizePixel = 0
	Instance.new("UICorner", b)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(40,120,40)
	s.Thickness = 1
b.MouseButton1Click:Connect(function()
	selectedTweenTarget = plr
	TweenToPlayer(plr)
end)

	scrollFrame.CanvasSize = UDim2.new(0,0,0,uiList.AbsoluteContentSize.Y)
end

for _, plr in ipairs(Players:GetPlayers()) do makeTweenButton(plr) end
Players.PlayerAdded:Connect(makeTweenButton)
Players.PlayerRemoving:Connect(function(plr)
	for _, b in ipairs(scrollFrame:GetChildren()) do
		if b:IsA("TextButton") and b.Text == plr.Name then b:Destroy() end
	end
	scrollFrame.CanvasSize = UDim2.new(0,0,0,uiList.AbsoluteContentSize.Y)
end)
