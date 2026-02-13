local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("VacuumRemotes")
local VacuumControl = remotes:WaitForChild("VacuumControl")
local ScoreUpdate = remotes:WaitForChild("ScoreUpdate")

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

	-- remove icons for deleted models
	for m, icon in pairs(icons) do
		if not m.Parent then
			icon:Destroy()
			icons[m] = nil
		end
	end
end

-- Update minimap at RenderStepped for smooth motion
RunService:BindToRenderStep("MinimapUpdate", Enum.RenderPriority.Camera.Value - 1, function()
	updateMinimap()
end)

-- Update score label from server
ScoreUpdate.OnClientEvent:Connect(function(newScore)
	scoreLabel.Text = "Score: " .. tostring(newScore)
end)

-- Respawn event: show countdown
local RespawnEvent = remotes:WaitForChild("RespawnEvent")
RespawnEvent.OnClientEvent:Connect(function(seconds)
	respawnLabel.Visible = true
	for i = seconds, 1, -1 do
		respawnLabel.Text = "Respawning in " .. tostring(i) .. "s"
		task.wait(1)
	end
	respawnLabel.Visible = false
	respawnLabel.Text = ""
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
