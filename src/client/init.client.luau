local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("VacuumRemotes")
local VacuumControl = remotes:WaitForChild("VacuumControl")
local ScoreUpdate = remotes:WaitForChild("ScoreUpdate")
local PowerupEvent = remotes:WaitForChild("PowerupEvent")
local AchievementEvent = remotes:WaitForChild("AchievementEvent")

-- Simple UI: Score display
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VacuumUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(0, 220, 0, 40)
scoreLabel.Position = UDim2.new(0, 10, 0, 10)
scoreLabel.BackgroundTransparency = 0.4
scoreLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.Text = "Score: 0"
scoreLabel.Parent = screenGui

local batteryLabel = Instance.new("TextLabel")
batteryLabel.Size = UDim2.new(0, 220, 0, 30)
batteryLabel.Position = UDim2.new(0, 10, 0, 55)
batteryLabel.BackgroundTransparency = 0.4
batteryLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
batteryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
batteryLabel.Text = "Battery: 100%"
batteryLabel.Parent = screenGui

local respawnLabel = Instance.new("TextLabel")
respawnLabel.Size = UDim2.new(0, 220, 0, 30)
respawnLabel.Position = UDim2.new(0, 10, 0, 95)
respawnLabel.BackgroundTransparency = 0.6
respawnLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
respawnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
respawnLabel.Text = ""
respawnLabel.Visible = false
respawnLabel.Parent = screenGui

local inputVector = Vector3.new(0, 0, 0)

-- Map WASD/Arrows to a movement vector
local function updateInput()
	local forward = (UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)) and -1 or 0
	local backward = (UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)) and 1 or 0
	local left = (UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)) and -1 or 0
	local right = (UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)) and 1 or 0

	local z = forward + backward
	local x = left + right
	local cam = workspace.CurrentCamera
	local look = cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude > 0 then look = look.Unit end
	if look ~= look then look = Vector3.new(0, 0, -1) end
	local rightVec = Vector3.new(look.Z, 0, -look.X)

	local v = (look * z) + (rightVec * x)
	if v.Magnitude > 0 then
		inputVector = v.Unit
	else
		inputVector = Vector3.new(0, 0, 0)
	end
end

-- Throttle sending input to server
RunService.RenderStepped:Connect(function()
	updateInput()
	VacuumControl:FireServer(inputVector)
end)

-- ===== Minimap UI =====
local mapSize = 180
local mapFrame = Instance.new("Frame")
mapFrame.Name = "Minimap"
mapFrame.Size = UDim2.new(0, mapSize, 0, mapSize)
mapFrame.Position = UDim2.new(1, -mapSize - 10, 1, -mapSize - 10)
mapFrame.BackgroundTransparency = 0.45
mapFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
mapFrame.BorderSizePixel = 0
mapFrame.Parent = screenGui

local icons = {}
local dustIcons = {}
local powerIcons = {}

-- Configurable sprite and sound asset ids (replace with your assets)
local SPRITES = {
	dust = "rbxassetid://6023426911", -- example dust icon
	power = "rbxassetid://6023426912", -- example power-up icon
}
local SOUNDS = {
    respawn = "rbxassetid://142070127", -- example respawn sound
    powerup = "rbxassetid://138087536", -- example power-up ding
}

local function getArenaHalf()
	local floor = workspace:FindFirstChild("GameFloor")
	if floor and floor:IsA("BasePart") then
		return floor.Size.X / 2
	end
	return 60
end

local function updateMinimap()
	local half = getArenaHalf()
	local center = mapSize / 2

	-- Create/update icons for vacuum models
	for _, model in pairs(workspace:GetChildren()) do
		if model:IsA("Model") and (model.Name:match("^Vacuum_") or model.Name:match("^PlayerVacuum_")) then
			local body = model:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				local pos = body.Position
				local x = (pos.X / half) * (mapSize / 2) + center
				local z = (-pos.Z / half) * (mapSize / 2) + center
				x = math.clamp(x, 6, mapSize - 6)
				z = math.clamp(z, 6, mapSize - 6)

				local icon = icons[model]
				if not icon then
					icon = Instance.new("Frame")
					icon.Size = UDim2.new(0, 10, 0, 10)
					icon.AnchorPoint = Vector2.new(0.5, 0.5)
					icon.Parent = mapFrame
					icon.BorderSizePixel = 0
					icons[model] = icon
				end

				-- color icon from vacuum body
				if body.BrickColor then
					icon.BackgroundColor3 = body.BrickColor.Color
				end

				icon.Position = UDim2.new(0, x, 0, z)

				-- highlight player's vacuum icon
				if model.Name:match(tostring(player.UserId)) then
					icon.BorderSizePixel = 2
					icon.BorderColor3 = Color3.fromRGB(255, 255, 255)
				else
					icon.BorderSizePixel = 0
				end
			end
		end
	end

	-- Dust blips
	for _, dust in pairs(workspace:GetChildren()) do
		if dust.Name == "Dust" and dust:IsA("BasePart") then
			local pos = dust.Position
			local x = (pos.X / half) * (mapSize / 2) + center
			local z = (-pos.Z / half) * (mapSize / 2) + center
			x = math.clamp(x, 4, mapSize - 4)
			z = math.clamp(z, 4, mapSize - 4)

			local icon = dustIcons[dust]
			if not icon then
				if SPRITES.dust ~= "" then
					icon = Instance.new("ImageLabel")
					icon.Image = SPRITES.dust
					icon.BackgroundTransparency = 1
				else
					icon = Instance.new("Frame")
					icon.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
					icon.BorderSizePixel = 0
				end
				icon.Size = UDim2.new(0, 8, 0, 8)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = mapFrame
				dustIcons[dust] = icon
			end
			icon.Position = UDim2.new(0, x, 0, z)
		end
	end

	-- Power-up blips
	for _, p in pairs(workspace:GetChildren()) do
		if p.Name == "Powerup" and p:IsA("BasePart") then
			local pos = p.Position
			local x = (pos.X / half) * (mapSize / 2) + center
			local z = (-pos.Z / half) * (mapSize / 2) + center
			x = math.clamp(x, 4, mapSize - 4)
			z = math.clamp(z, 4, mapSize - 4)

			local icon = powerIcons[p]
			if not icon then
				if SPRITES.power ~= "" then
					icon = Instance.new("ImageLabel")
					icon.Image = SPRITES.power
					icon.BackgroundTransparency = 1
				else
					icon = Instance.new("Frame")
					icon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
					icon.BorderSizePixel = 1
					icon.BorderColor3 = Color3.fromRGB(0, 0, 0)
				end
				icon.Size = UDim2.new(0, 10, 0, 10)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = mapFrame
				powerIcons[p] = icon
			end
			icon.Position = UDim2.new(0, x, 0, z)
		end
	end

	-- remove icons for deleted models
	for m, icon in pairs(icons) do
		if not m.Parent then
			icon:Destroy()
			icons[m] = nil
		end
	end
	for m, icon in pairs(dustIcons) do
		if not m.Parent then
			icon:Destroy()
			dustIcons[m] = nil
		end
	end
	for m, icon in pairs(powerIcons) do
		if not m.Parent then
			icon:Destroy()
			powerIcons[m] = nil
		end
	end
end

-- Update minimap at RenderStepped for smooth motion
RunService:BindToRenderStep("MinimapUpdate", Enum.RenderPriority.Camera.Value - 1, function()
	updateMinimap()
end)

-- Play powerup sounds and show achievement popups
PowerupEvent.OnClientEvent:Connect(function(ptype)
	local soundId = SOUNDS.powerup
	if ptype == "Battery" then
		-- optional different sound
	end
	if soundId and soundId ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = soundId
		s.Volume = 1
		s.Parent = player:WaitForChild("PlayerGui")
		pcall(function() s:Play() end)
		game:GetService("Debris"):AddItem(s, 3)
	end
end)

AchievementEvent.OnClientEvent:Connect(function(id, title, desc)
	-- simple popup
	local popup = Instance.new("Frame")
	popup.Size = UDim2.new(0, 260, 0, 60)
	popup.Position = UDim2.new(0.5, -130, 0, 60)
	popup.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	popup.BackgroundTransparency = 0
	popup.BorderSizePixel = 0
	popup.Parent = screenGui

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -12, 0.5, -6)
	t.Position = UDim2.new(0, 6, 0, 6)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.fromRGB(255, 215, 0)
	t.Text = "Achievement Unlocked: " .. tostring(title)
	t.Font = Enum.Font.SourceSansBold
	t.TextSize = 18
	t.Parent = popup

	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(1, -12, 0.5, -6)
	d.Position = UDim2.new(0, 6, 0.5, 0)
	d.BackgroundTransparency = 1
	d.TextColor3 = Color3.fromRGB(220, 220, 220)
	d.Text = tostring(desc)
	d.Font = Enum.Font.SourceSans
	d.TextSize = 14
	d.Parent = popup

	task.delay(3, function()
		popup:Destroy()
	end)
end)

-- ===== Leaderboard UI =====
local lbFrame = Instance.new("Frame")
lbFrame.Name = "Leaderboard"
lbFrame.Size = UDim2.new(0, 220, 0, 160)
lbFrame.Position = UDim2.new(1, -mapSize - 10, 0, 10)
lbFrame.BackgroundTransparency = 0.45
lbFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
lbFrame.BorderSizePixel = 0
lbFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "Top Scores"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = lbFrame

local entries = {}
for i = 1, 5 do
	local e = Instance.new("TextLabel")
	e.Size = UDim2.new(1, -8, 0, 24)
	e.Position = UDim2.new(0, 4, 0, 28 + (i - 1) * 26)
	e.BackgroundTransparency = 1
	e.TextXAlignment = Enum.TextXAlignment.Left
	e.TextColor3 = Color3.fromRGB(230, 230, 230)
	e.Text = tostring(i) .. ". ---"
	e.Font = Enum.Font.SourceSans
	e.TextSize = 14
	e.Parent = lbFrame
	entries[i] = e
end

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(1, -8, 0, 26)
refreshBtn.Position = UDim2.new(0, 4, 1, -34)
refreshBtn.Text = "Refresh"
refreshBtn.Font = Enum.Font.SourceSans
refreshBtn.TextSize = 14
refreshBtn.Parent = lbFrame

local function refreshLeaderboard()
	local ok, data = pcall(function()
		return remotes:WaitForChild("GetHighScores"):InvokeServer()
	end)
	if ok and type(data) == "table" then
		for i = 1, 5 do
			local entry = data[i]
			if entry then
				entries[i].Text = tostring(i) .. ". " .. tostring(entry.name) .. " — " .. tostring(entry.score)
			else
				entries[i].Text = tostring(i) .. ". ---"
			end
		end
	end
end

refreshBtn.MouseButton1Click:Connect(refreshLeaderboard)
-- initial load
task.spawn(refreshLeaderboard)

-- Update score label from server
ScoreUpdate.OnClientEvent:Connect(function(newScore)
	scoreLabel.Text = "Score: " .. tostring(newScore)
end)

-- Respawn event: show countdown
local RespawnEvent = remotes:WaitForChild("RespawnEvent")
RespawnEvent.OnClientEvent:Connect(function(seconds)
	if seconds and seconds > 0 then
		respawnLabel.Visible = true
		for i = seconds, 1, -1 do
			respawnLabel.Text = "Respawning in " .. tostring(i) .. "s"
			task.wait(1)
		end
		respawnLabel.Visible = false
		respawnLabel.Text = ""
	else
		-- seconds == 0 -> immediate respawn effect at provided position
		respawnLabel.Visible = false
		local spawnPos = select(2, ...) or nil
		if spawnPos and typeof(spawnPos) == "Vector3" then
			-- create visual ping on client's minimap and world
			local ping = Instance.new("Part")
			ping.Size = Vector3.new(1, 0.2, 1)
			ping.Anchored = true
			ping.CanCollide = false
			ping.Position = spawnPos + Vector3.new(0, 0.2, 0)
			ping.BrickColor = BrickColor.new("Institutional white")
			ping.Transparency = 0.6
			ping.Parent = workspace

			local ts = game:GetService("TweenService")
			local tw = ts:Create(ping, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(6, 0.2, 6), Transparency = 1})
			tw:Play()
			game:GetService("Debris"):AddItem(ping, 1)

			-- play a local respawn sound (replace SoundId with a valid asset if desired)
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://1843520" -- placeholder; replace with a valid id
			sound.Volume = 1
			sound.Parent = player:WaitForChild("PlayerGui")
			pcall(function() sound:Play() end)
			game:GetService("Debris"):AddItem(sound, 2)
		end
	end
end)

-- Update battery locally if available via ScoreUpdate notifications (server also updates leaderstats)
-- We'll poll player's vacuum model for battery display
RunService.RenderStepped:Connect(function()
	local foundBattery = nil
	for _, v in pairs(workspace:GetChildren()) do
		if v:IsA("Model") and v.Name:match("PlayerVacuum_") then
			local hum = v:FindFirstChild("Body")
			if hum then
				local ownerIdStr = v.Name:match("PlayerVacuum_(%d+)")
				if ownerIdStr and tonumber(ownerIdStr) == player.UserId then
					-- read battery attribute if set on model
					local battery = v:GetAttribute("Battery")
					if battery then
						foundBattery = battery
					end
				end
			end
		end
	end
	if foundBattery then
		batteryLabel.Text = "Battery: " .. tostring(foundBattery) .. "%"
	end
end)
