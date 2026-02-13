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

-- Update score label from server
ScoreUpdate.OnClientEvent:Connect(function(newScore)
	scoreLabel.Text = "Score: " .. tostring(newScore)
end)
