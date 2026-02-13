-- ========================================
-- ROBOT VACUUM CLEANER GAME
-- A fun competitive cleaning game
-- ========================================

-- ========================================
-- GAME CONFIGURATION
-- ========================================
local CONFIG = {
    ARENA_SIZE = 120,
    FLOOR_HEIGHT = 1,
    WALL_HEIGHT = 10,
    INITIAL_DUST = 100,
    INITIAL_DUST_VISIBLE = 140,
    DUST_RESPAWN_RATE = 0.5, -- Dust per second
    VACUUM_COUNT = 3,
    GAME_DURATION = 300, -- 5 minutes
    VACUUM_SPEED = 25,
    VACUUM_SIZE = 3,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFolder = ReplicatedStorage:FindFirstChild("VacuumRemotes") or Instance.new("Folder")
RemoteFolder.Name = "VacuumRemotes"
RemoteFolder.Parent = ReplicatedStorage

local VacuumControl = RemoteFolder:FindFirstChild("VacuumControl") or Instance.new("RemoteEvent")
VacuumControl.Name = "VacuumControl"
VacuumControl.Parent = RemoteFolder

local SpawnRequest = RemoteFolder:FindFirstChild("SpawnRequest") or Instance.new("RemoteEvent")
SpawnRequest.Name = "SpawnRequest"
SpawnRequest.Parent = RemoteFolder

local ScoreUpdate = RemoteFolder:FindFirstChild("ScoreUpdate") or Instance.new("RemoteEvent")
ScoreUpdate.Name = "ScoreUpdate"
ScoreUpdate.Parent = RemoteFolder

local RespawnEvent = RemoteFolder:FindFirstChild("RespawnEvent") or Instance.new("RemoteEvent")
RespawnEvent.Name = "RespawnEvent"
RespawnEvent.Parent = RemoteFolder

local PowerupEvent = RemoteFolder:FindFirstChild("PowerupEvent") or Instance.new("RemoteEvent")
PowerupEvent.Name = "PowerupEvent"
PowerupEvent.Parent = RemoteFolder

local AchievementEvent = RemoteFolder:FindFirstChild("AchievementEvent") or Instance.new("RemoteEvent")
AchievementEvent.Name = "AchievementEvent"
AchievementEvent.Parent = RemoteFolder

-- High-score persistence (DataStore)
local GetHighScores = RemoteFolder:FindFirstChild("GetHighScores") or Instance.new("RemoteFunction")
GetHighScores.Name = "GetHighScores"
GetHighScores.Parent = RemoteFolder

local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local highStore = DataStoreService:GetDataStore("VacuumHighScores")
local HighScores = {}

local AchieveStore = DataStoreService:GetDataStore("VacuumAchievements")
local PlayerAchievements = {}

local function loadPlayerAchievements(player)
    local uid = tostring(player.UserId)
    local ok, data = pcall(function()
        return AchieveStore:GetAsync(uid)
    end)
    if ok and type(data) == "table" then
        PlayerAchievements[player.UserId] = data
    else
        PlayerAchievements[player.UserId] = {}
    end
end

local function savePlayerAchievements(player)
    local uid = tostring(player.UserId)
    local data = PlayerAchievements[player.UserId] or {}
    pcall(function()
        AchieveStore:SetAsync(uid, data)
    end)
end

local function grantAchievementToPlayer(player, achievementId, title, desc)
    if not player then return end
    local ach = PlayerAchievements[player.UserId]
    if not ach then
        loadPlayerAchievements(player)
        ach = PlayerAchievements[player.UserId]
    end
    if ach[achievementId] then return end -- already granted
    ach[achievementId] = {title = title, desc = desc, time = os.time()}
    savePlayerAchievements(player)
    AchievementEvent:FireClient(player, achievementId, title, desc)
end

do
    local ok, data = pcall(function()
        return highStore:GetAsync("HighScores")
    end)
    if ok and type(data) == "table" then
        HighScores = data
    else
        HighScores = {}
    end
end

local function saveHighScores()
    pcall(function()
        highStore:SetAsync("HighScores", HighScores)
    end)
end

local function updatePlayerHighScore(player, score)
    if not player then return end
    local uid = player.UserId
    local name = player.Name
    local found = false
    for _, entry in ipairs(HighScores) do
        if entry.userId == uid then
            found = true
            if score > entry.score then
                entry.score = score
                entry.name = name
            end
            break
        end
    end
    if not found then
        table.insert(HighScores, { userId = uid, name = name, score = score })
    end
    table.sort(HighScores, function(a, b) return a.score > b.score end)
    while #HighScores > 10 do
        table.remove(HighScores)
    end
    saveHighScores()
end

GetHighScores.OnServerInvoke = function(player)
    return HighScores
end

-- ========================================
-- MODEL VARIANT SPAWNER
-- Place a model named "RobotVacuumTemplate" into ReplicatedStorage (or Workspace)
-- and this function will clone 4 color variants and place them in the arena.
-- ========================================
local function spawnTemplateVariants()
    local template = ReplicatedStorage:FindFirstChild("RobotVacuumTemplate") or workspace:FindFirstChild("RobotVacuumTemplate")
    if not template then
        warn("RobotVacuumTemplate model not found. Import the model into ReplicatedStorage and name it 'RobotVacuumTemplate'.")
        return
    end

    local colors = {"Bright red", "Bright blue", "Bright green", "Deep orange"}
    local startPositions = {
        Vector3.new(-25, 1, -25),
        Vector3.new(25, 1, -25),
        Vector3.new(-25, 1, 25),
        Vector3.new(25, 1, 25),
    }

    local variantsFolder = workspace:FindFirstChild("VacuumVariants") or Instance.new("Folder")
    variantsFolder.Name = "VacuumVariants"
    variantsFolder.Parent = workspace

    for i, colorName in ipairs(colors) do
        local clone = template:Clone()
        clone.Name = "Vacuum_Model_Variant_" .. i
        -- recolor parts and meshparts
        for _, obj in pairs(clone:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                pcall(function()
                    obj.BrickColor = BrickColor.new(colorName)
                end)
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                -- optional: tint decals by adjusting Transparency or leave as-is
            end
        end

        clone.Parent = variantsFolder
        -- try to move model to position
        local pos = startPositions[i] or Vector3.new(0, 1, 0)
        pcall(function()
            if clone.PrimaryPart then
                clone:SetPrimaryPartCFrame(CFrame.new(pos + Vector3.new(0, 1, 0)))
            else
                clone:MoveTo(pos + Vector3.new(0, 1, 0))
            end
        end)
    end
    print("Spawned " .. #colors .. " color variants from RobotVacuumTemplate into Workspace.VacuumVariants.")
end

-- Attempt automatic spawn on server start (only if template present)
-- Note: spawnTemplateVariants will be called after arena setup to avoid being cleared


-- ========================================
-- SETUP: Clear and Create Arena
-- ========================================
for _, child in game.Workspace:GetChildren() do
    if child.Name ~= "Terrain" then
        child:Destroy()
    end
end

local floor = Instance.new("Part")
floor.Name = "GameFloor"
floor.Size = Vector3.new(CONFIG.ARENA_SIZE, CONFIG.FLOOR_HEIGHT, CONFIG.ARENA_SIZE)
floor.Position = Vector3.new(0, 0, 0)
floor.Anchored = true
floor.BrickColor = BrickColor.new("Light gray")
floor.Material = Enum.Material.Concrete
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.Parent = game.Workspace

-- Create walls
local function createWall(position, size)
    local wall = Instance.new("Part")
    wall.Name = "Wall"
    wall.Size = size
    wall.Position = position
    wall.Anchored = true
    wall.BrickColor = BrickColor.new("Medium stone grey")
    wall.Material = Enum.Material.Concrete
    wall.CanCollide = true
    wall.Parent = game.Workspace
    return wall
end

local halfArena = CONFIG.ARENA_SIZE / 2 + 1
createWall(Vector3.new(0, CONFIG.WALL_HEIGHT / 2, halfArena), Vector3.new(CONFIG.ARENA_SIZE, CONFIG.WALL_HEIGHT, 2))
createWall(Vector3.new(0, CONFIG.WALL_HEIGHT / 2, -halfArena), Vector3.new(CONFIG.ARENA_SIZE, CONFIG.WALL_HEIGHT, 2))
createWall(Vector3.new(halfArena, CONFIG.WALL_HEIGHT / 2, 0), Vector3.new(2, CONFIG.WALL_HEIGHT, CONFIG.ARENA_SIZE))
createWall(Vector3.new(-halfArena, CONFIG.WALL_HEIGHT / 2, 0), Vector3.new(2, CONFIG.WALL_HEIGHT, CONFIG.ARENA_SIZE))

-- Create obstacles (furniture)
local function createObstacle(position, size, color)
    local obs = Instance.new("Part")
    obs.Name = "Obstacle"
    obs.Size = size
    obs.Position = position
    obs.Anchored = true
    obs.BrickColor = BrickColor.new(color)
    obs.Material = Enum.Material.Wood
    obs.CanCollide = true
    obs.Parent = game.Workspace
    return obs
end

-- Add some obstacles to make it more interesting
createObstacle(Vector3.new(0, 1, 0), Vector3.new(10, 2, 10), "Reddish brown")
createObstacle(Vector3.new(30, 1, 30), Vector3.new(8, 2, 8), "Dark stone grey")
createObstacle(Vector3.new(-30, 1, -30), Vector3.new(12, 2, 6), "Dark red")

-- Spawn template variants after arena is set up so they aren't destroyed by the clear
spawnTemplateVariants()

-- ===== Room Decorations =====
-- Rug
local rug = Instance.new("Part")
rug.Name = "Rug"
rug.Size = Vector3.new(30, 0.2, 20)
rug.Position = Vector3.new(0, 0.6, 0)
rug.Anchored = true
rug.BrickColor = BrickColor.new("Pastel brown")
rug.Material = Enum.Material.Fabric
rug.Parent = game.Workspace

-- Coffee table
local tableTop = Instance.new("Part")
tableTop.Name = "CoffeeTable"
tableTop.Size = Vector3.new(6, 0.6, 3)
tableTop.Position = Vector3.new(0, 1.2, 0)
tableTop.Anchored = true
tableTop.BrickColor = BrickColor.new("Reddish brown")
tableTop.Parent = game.Workspace

local tableLeg = Instance.new("Part")
tableLeg.Size = Vector3.new(0.6, 1.2, 0.6)
tableLeg.Position = Vector3.new(0, 0.6, 0)
tableLeg.Anchored = true
tableLeg.BrickColor = BrickColor.new("Reddish brown")
tableLeg.Parent = game.Workspace

-- Couch (simple block)
local couch = Instance.new("Part")
couch.Name = "Couch"
couch.Size = Vector3.new(12, 2, 4)
couch.Position = Vector3.new(-20, 1, 0)
couch.Anchored = true
couch.BrickColor = BrickColor.new("Bright red")
couch.Material = Enum.Material.SmoothPlastic
couch.Parent = game.Workspace

-- Floor lamp
local lampBase = Instance.new("Part")
lampBase.Name = "LampBase"
lampBase.Size = Vector3.new(0.6, 6, 0.6)
lampBase.Position = Vector3.new(18, 3, -10)
lampBase.Anchored = true
lampBase.BrickColor = BrickColor.new("Dark stone grey")
lampBase.Parent = game.Workspace

local lampLight = Instance.new("PointLight")
lampLight.Parent = lampBase
lampLight.Brightness = 2
lampLight.Range = 20

-- ========================================
-- DUST SYSTEM
-- ========================================
local DustManager = {}
local dustCount = 0

function DustManager:spawnDust(count)
    for i = 1, count do
        local dust = Instance.new("Part")
        dust.Name = "Dust"
        dust.Shape = Enum.PartType.Ball
        dust.Size = Vector3.new(0.6, 0.6, 0.6)
        dust.BrickColor = BrickColor.new("Dark stone grey")
        dust.Material = Enum.Material.SmoothPlastic
        dust.CanCollide = false
        dust.Anchored = true

        -- Random position within the arena, sitting just above the floor
        local rx = math.random(-halfArena + 5, halfArena - 5)
        local rz = math.random(-halfArena + 5, halfArena - 5)
        local ry = CONFIG.FLOOR_HEIGHT + 0.6
        dust.Position = Vector3.new(rx, ry, rz)

        -- Add a faint particle emitter so dust looks fuzzy and visible
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = "rbxassetid://6023426913" -- small dust particle texture (example)
        pe.Rate = 5
        pe.Lifetime = NumberRange.new(0.4)
        pe.Speed = NumberRange.new(0)
        pe.Size = NumberSequence.new(0.3)
        pe.LightInfluence = 0
        pe.Parent = dust

        dust.Parent = game.Workspace
        dustCount = dustCount + 1
    end
end

function DustManager:removeDust(dustPart)
    if dustPart and dustPart.Parent then
        dustPart:Destroy()
        dustCount = dustCount - 1
    end
end

-- Initial dust spawn
-- Initial dust spawn (use visible count)
DustManager:spawnDust(CONFIG.INITIAL_DUST_VISIBLE)

-- Continuous dust respawning
game:GetService("RunService").Heartbeat:Connect(function()
    if dustCount < CONFIG.INITIAL_DUST_VISIBLE then
        local toSpawn = math.ceil((CONFIG.INITIAL_DUST_VISIBLE - dustCount) * CONFIG.DUST_RESPAWN_RATE / 60)
        DustManager:spawnDust(toSpawn)
    end
end)

-- ========================================
-- VACUUM ROBOT CLASS
-- ========================================
local VacuumRobot = {}
VacuumRobot.__index = VacuumRobot

function VacuumRobot.new(name, color, startPos)
    local self = setmetatable({}, VacuumRobot)
    
    self.name = name
    self.color = color
    self.startPos = startPos
    self.score = 0
    self.dustCleaned = 0
    self.isActive = true
    self.direction = CFrame.new()
    self.lastTurnTime = tick()
    self.battery = 100
    self.maxBattery = 100
    self.owner = nil -- will be set for player-controlled vacuums
    
    self:createModel()
    self:initializePhysics()
    self:startAI()
    
    return self
end

function VacuumRobot:createModel()
    self.model = Instance.new("Model", game.Workspace)
    self.model.Name = self.name
    
    -- Main body (disc shape)
    self.body = Instance.new("Part")
    self.body.Name = "Body"
    self.body.Shape = Enum.PartType.Cylinder
    self.body.Size = Vector3.new(1, CONFIG.VACUUM_SIZE, CONFIG.VACUUM_SIZE)
    self.body.Position = self.startPos + Vector3.new(0, 1, 0)
    self.body.Orientation = Vector3.new(0, 0, 90)
    self.body.BrickColor = BrickColor.new(self.color)
    self.body.Material = Enum.Material.Plastic
    self.body.CanCollide = true
    self.body.Parent = self.model
    
    -- LED Light indicator
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 15
    light.Parent = self.body
    
    -- Top decorative ring
    local ring = Instance.new("Part")
    ring.Name = "Ring"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, CONFIG.VACUUM_SIZE + 0.5, CONFIG.VACUUM_SIZE + 0.5)
    ring.Position = self.body.Position + Vector3.new(0.3, 0, 0)
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.BrickColor = BrickColor.new("Black")
    ring.CanCollide = false
    ring.Parent = self.model
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = ring
    weld.Part1 = self.body
    weld.Parent = ring
    -- store battery as attribute on model for client polling
    self.model:SetAttribute("Battery", self.battery)
end

function VacuumRobot:initializePhysics()
    -- BodyVelocity for movement
    self.bodyVelocity = Instance.new("BodyVelocity")
    self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
    self.bodyVelocity.Parent = self.body
    
    -- BodyGyro for rotation
    self.bodyGyro = Instance.new("BodyGyro")
    self.bodyGyro.MaxTorque = Vector3.new(0, 400000, 0)
    self.bodyGyro.D = 500
    self.bodyGyro.P = 10000
    self.bodyGyro.Parent = self.body
    
    -- Collision detection
    self.body.Touched:Connect(function(hit)
        self:onTouched(hit)
    end)
    -- update model attribute periodically
    task.spawn(function()
        while self.model and self.model.Parent do
            self.model:SetAttribute("Battery", math.floor(self.battery))
            task.wait(0.5)
        end
    end)

    -- If this vacuum is player-controlled, listen for control updates
    if self.owner then
        self.controlConn = VacuumControl.OnServerEvent:Connect(function(player, dirVector)
            if player == self.owner and typeof(dirVector) == "Vector3" then
                if dirVector.Magnitude > 0 then
                    self.direction = CFrame.new(self.body.Position, self.body.Position + dirVector.Unit)
                end
            end
        end)
    end
end

function VacuumRobot:onTouched(hit)
    if hit.Name == "Dust" then
        self:collectDust(hit)
    elseif hit.Name == "Wall" or hit.Name == "Obstacle" then
        self:avoidObstacle()
    end
end

function VacuumRobot:collectDust(dustPart)
    if dustPart and dustPart.Parent then
        DustManager:removeDust(dustPart)
        self.dustCleaned = self.dustCleaned + 1
        self.score = self.score + 10
        
        -- Visual feedback
        local sparkles = Instance.new("Part")
        sparkles.Name = "Sparkle"
        sparkles.Shape = Enum.PartType.Ball
        sparkles.Size = Vector3.new(0.5, 0.5, 0.5)
        sparkles.Position = dustPart.Position
        sparkles.BrickColor = BrickColor.new("Bright yellow")
        sparkles.CanCollide = false
        sparkles.Parent = game.Workspace
        game:GetService("Debris"):AddItem(sparkles, 0.3)
        -- If owned by a player, update leaderstats and notify client
        if self.owner and self.owner.Parent then
            local stats = self.owner:FindFirstChild("leaderstats")
            if stats and stats:FindFirstChild("Score") then
                stats.Score.Value = stats.Score.Value + 10
                -- Update persistent high score
                updatePlayerHighScore(self.owner, stats.Score.Value)
            end
            ScoreUpdate:FireClient(self.owner, self.score)
            -- achievements: first clean and dust collector
            if self.dustCleaned >= 1 then
                grantAchievementToPlayer(self.owner, "first_clean", "First Clean", "Cleaned your first dust")
            end
            if self.dustCleaned >= 50 then
                grantAchievementToPlayer(self.owner, "dust_collector", "Dust Collector", "Cleaned 50 dust pieces")
            end
        end
    end
end

function VacuumRobot:avoidObstacle()
    -- Turn away and reverse
    local randomAngle = math.rad(math.random(60, 150))
    self.direction = self.direction * CFrame.Angles(0, randomAngle, 0)
    self.lastTurnTime = tick()
end

function VacuumRobot:startAI()
    while self.isActive do
        task.wait(0.1)
        
        -- Battery drain
        self.battery = math.max(0, self.battery - 0.02)
        
        -- If battery dead, stop and schedule respawn
        if self.battery <= 0 then
            self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            self.isActive = false
            -- notify owner to show respawn countdown
            if self.owner then
                RespawnEvent:FireClient(self.owner, 5) -- 5 second respawn
            end
            -- respawn after delay
            task.spawn(function()
                task.wait(5)
                self:respawn()
            end)
            return
        end
        
        -- Random turning behavior
        local timeSinceTurn = tick() - self.lastTurnTime
        if timeSinceTurn > math.random(3, 8) then
            local randomAngle = math.rad(math.random(-45, 45))
            self.direction = self.direction * CFrame.Angles(0, randomAngle, 0)
            self.lastTurnTime = tick()
        end
        
        -- Find nearest dust and move towards it
        local nearestDust = self:findNearestDust()
        if nearestDust then
            local direction = (nearestDust.Position - self.body.Position).Unit
            self.direction = CFrame.new(self.body.Position, self.body.Position + direction)
        end
        
        -- Move in current direction
        local moveDirection = self.direction.LookVector
        self.bodyVelocity.Velocity = moveDirection * CONFIG.VACUUM_SPEED
        self.bodyGyro.CFrame = self.direction
    end
end

function VacuumRobot:findNearestDust()
    local nearestDust = nil
    local nearestDistance = 30 -- Detection range
    
    for _, dust in pairs(game.Workspace:GetChildren()) do
        if dust.Name == "Dust" then
            local distance = (dust.Position - self.body.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestDust = dust
            end
        end
    end
    
    return nearestDust
end

function VacuumRobot:respawn()
    -- Reset state and place at random spawn
    local spawnPos = Vector3.new(math.random(-halfArena + 5, halfArena - 5), 1, math.random(-halfArena + 5, halfArena - 5))

    -- Create a quick visual effect at spawn position (server-side fallback)
    local effect = Instance.new("Part")
    effect.Name = "RespawnEffect"
    effect.Anchored = true
    effect.CanCollide = false
    effect.Size = Vector3.new(1, 0.2, 1)
    effect.Position = spawnPos + Vector3.new(0, 0.2, 0)
    effect.BrickColor = BrickColor.new("Institutional white")
    effect.Transparency = 0.6
    effect.Parent = game.Workspace

    local tweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local goal = {Size = Vector3.new(6, 0.2, 6), Transparency = 1}
    pcall(function()
        TweenService:Create(effect, tweenInfo, goal):Play()
    end)
    game:GetService("Debris"):AddItem(effect, 1)

    if self.body and self.body.Parent then
        self.body.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1, 0))
    end
    self.battery = self.maxBattery
    self.isActive = true
    self.direction = CFrame.new()
    self.lastTurnTime = tick()
    -- Restart AI loop
    task.spawn(function()
        self:startAI()
    end)

    -- notify owner client to play respawn effect/sound
    if self.owner then
        RespawnEvent:FireClient(self.owner, 0, spawnPos)
    end
end

-- Create a VacuumRobot instance from an existing model in the workspace
function VacuumRobot.fromModel(model, owner)
    if not model or not model.Parent then return nil end
    local body = model:FindFirstChild("Body") or model.PrimaryPart
    if not body then
        -- try to find any BasePart
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                body = d
                break
            end
        end
    end
    if not body then
        warn("Cannot create VacuumRobot: model has no body part")
        return nil
    end

    local self = setmetatable({}, VacuumRobot)
    self.model = model
    self.body = body
    self.name = model.Name
    self.color = (body.BrickColor and body.BrickColor.Name) or "Bright blue"
    self.startPos = body.Position
    self.score = 0
    self.dustCleaned = 0
    self.isActive = true
    self.direction = CFrame.new()
    self.lastTurnTime = tick()
    self.battery = 100
    self.maxBattery = 100
    self.owner = owner

    -- ensure physics-ready
    body.Anchored = false
    body.CanCollide = true

    -- expose battery attribute for clients
    self.model:SetAttribute("Battery", self.battery)

    -- initialize physics and AI
    self:initializePhysics()
    task.spawn(function()
        self:startAI()
    end)

    return self
end

-- ========================================
-- GAME MANAGER
-- ========================================
local GameManager = {}
GameManager.vacuums = {}
GameManager.gameActive = true
GameManager.gameTime = CONFIG.GAME_DURATION

function GameManager:initialize()
    -- Create multiple vacuums with different colors
    local colors = {"Deep orange", "Bright blue", "Bright green"}
    local positions = {
        Vector3.new(-30, 1, -30),
        Vector3.new(30, 1, 30),
        Vector3.new(0, 1, -40)
    }
    
    for i = 1, CONFIG.VACUUM_COUNT do
        local vacuum = VacuumRobot.new(
            "Vacuum_" .. i,
            colors[i],
            positions[i]
        )
        table.insert(self.vacuums, vacuum)
    end
    
    print("✓ Game Initialized with " .. CONFIG.VACUUM_COUNT .. " robot vacuums!")
end

-- Player support: leaderstats and spawning personal vacuum
local Players = game:GetService("Players")

local function makeLeaderstats(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local score = Instance.new("IntValue")
    score.Name = "Score"
    score.Value = 0
    score.Parent = leaderstats
end

Players.PlayerAdded:Connect(function(player)
    makeLeaderstats(player)
    loadPlayerAchievements(player)

    -- Spawn a player-controlled vacuum for them
    local spawnPos = Vector3.new(math.random(-40, 40), 1, math.random(-40, 40))
    local vacuum = VacuumRobot.new("PlayerVacuum_" .. player.UserId, "Bright blue", spawnPos)
    vacuum.owner = player
    table.insert(GameManager.vacuums, vacuum)

    -- Notify client to start its local UI
    ScoreUpdate:FireClient(player, vacuum.score)
end)

Players.PlayerRemoving:Connect(function(player)
    local stats = player:FindFirstChild("leaderstats")
    if stats and stats:FindFirstChild("Score") then
        updatePlayerHighScore(player, stats.Score.Value)
    end
    -- save achievements
    savePlayerAchievements(player)
end)

-- Handle client control requests centrally (fallback)
VacuumControl.OnServerEvent:Connect(function(player, moveVector)
    -- find player's vacuum and set direction
    for _, v in ipairs(GameManager.vacuums) do
        if v.owner == player then
            if typeof(moveVector) == "Vector3" and moveVector.Magnitude > 0 then
                v.direction = CFrame.new(v.body.Position, v.body.Position + moveVector.Unit)
            end
            break
        end
    end
end)

-- POWER-UPS: Spawn occasional power-ups that give speed or battery
local function spawnPowerup(position, ptype)
    local p = Instance.new("Part")
    p.Name = "Powerup"
    p.Size = Vector3.new(2, 0.6, 2)
    p.Position = position
    p.Anchored = true
    p.BrickColor = BrickColor.new(ptype == "Speed" and "Bright yellow" or "Lime green")
    p.Parent = game.Workspace
    p:SetAttribute("Type", ptype)

    p.Touched:Connect(function(hit)
        local model = hit:FindFirstAncestorOfClass("Model")
        if not model then return end
        local ownerVacuum
        for _, v in ipairs(GameManager.vacuums) do
            if v.model == model then
                ownerVacuum = v
                break
            end
        end
        if ownerVacuum then
            if p:GetAttribute("Type") == "Speed" then
                spawn(function()
                    local prevSpeed = CONFIG.VACUUM_SPEED
                    CONFIG.VACUUM_SPEED = CONFIG.VACUUM_SPEED * 1.8
                    task.wait(8)
                    CONFIG.VACUUM_SPEED = prevSpeed
                end)
                -- notify client to play power-up sound/FX
                if ownerVacuum.owner then
                    PowerupEvent:FireClient(ownerVacuum.owner, "Speed")
                end
            else
                ownerVacuum.battery = math.min(ownerVacuum.maxBattery, ownerVacuum.battery + 40)
                if ownerVacuum.owner then
                    PowerupEvent:FireClient(ownerVacuum.owner, "Battery")
                end
            end
            p:Destroy()
        end
    end)
end

-- periodic power-up spawner
task.spawn(function()
    while GameManager.gameActive do
        task.wait(20)
        local pos = Vector3.new(math.random(-halfArena + 5, halfArena - 5), 1.5, math.random(-halfArena + 5, halfArena - 5))
        spawnPowerup(pos, (math.random() > 0.5) and "Speed" or "Battery")
    end
end)

function GameManager:updateGameTime()
    while self.gameActive and self.gameTime > 0 do
        task.wait(1)
        self.gameTime = self.gameTime - 1
        
        if self.gameTime % 30 == 0 then
            self:broadcastStats()
        end
    end
    
    self:endGame()
end

function GameManager:broadcastStats()
    print("\n" .. string.rep("=", 50))
    print("TIME REMAINING: " .. self.gameTime .. "s")
    for _, vacuum in ipairs(self.vacuums) do
        print(vacuum.name .. " | Score: " .. vacuum.score .. 
              " | Dust: " .. vacuum.dustCleaned .. 
              " | Battery: " .. string.format("%.1f", vacuum.battery) .. "%")
    end
    print(string.rep("=", 50) .. "\n")
end

function GameManager:endGame()
    self.gameActive = false
    
    for _, vacuum in ipairs(self.vacuums) do
        vacuum.isActive = false
    end
    
    print("\n" .. string.rep("=", 60))
    print("GAME OVER! - FINAL RESULTS")
    print(string.rep("=", 60))
    
    table.sort(self.vacuums, function(a, b)
        return a.score > b.score
    end)
    
    for i, vacuum in ipairs(self.vacuums) do
        print(i .. ". " .. vacuum.name .. 
              " - Score: " .. vacuum.score .. 
              " - Dust Cleaned: " .. vacuum.dustCleaned)
    end
    
    print(string.rep("=", 60) .. "\n")
end

-- ========================================
-- START GAME
-- ========================================
GameManager:initialize()
-- If any template variants were spawned, convert them into active VacuumRobot instances
local variantsFolder = workspace:FindFirstChild("VacuumVariants")
if variantsFolder then
    for _, model in ipairs(variantsFolder:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("_processed") then
            local vr = VacuumRobot.fromModel(model)
            if vr then
                table.insert(GameManager.vacuums, vr)
                model:SetAttribute("_processed", true)
                print("Converted variant " .. model.Name .. " into VacuumRobot instance.")
            end
        end
    end
end
task.spawn(function()
    GameManager:updateGameTime()
end)

print("🤖 ROBOT VACUUM CLEANER GAME STARTED! 🤖")
