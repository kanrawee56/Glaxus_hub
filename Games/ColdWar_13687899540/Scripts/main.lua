-- ==============================================================================
-- Cold War [VIETNAM] (PlaceId: 13687899540)
-- System: Networked Stepped Ballistics Raycasting
-- Modules: PlayerScripts.BallisticsClient.ClientFire, ReplicatedStorage.Shared.Ballistics
-- Single-file All-in-One: Networked Silent Aim, Exact Ballistic Lead, No Recoil, Full ESP Suite, Triggerbot & WindUI
-- ==============================================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")

-- ==============================================================================
-- [ CLEANUP PREVIOUS INSTANCES ]
-- ==============================================================================
local G = getgenv()
if G.__CW_Cleanup then
    pcall(G.__CW_Cleanup)
end

local connections   = {}
local drawingPool   = {}
local highlightPool = {}
local billboardPool = {}

G.__CW_Cleanup = function()
    -- Disconnect all events
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    -- Remove drawing objects
    for _, obj in ipairs(drawingPool) do
        pcall(function() obj:Remove() end)
    end
    table.clear(drawingPool)

    -- Destroy highlights
    for _, hl in pairs(highlightPool) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(highlightPool)

    -- Destroy billboards
    for _, bb in pairs(billboardPool) do
        pcall(function() bb:Destroy() end)
    end
    table.clear(billboardPool)

    -- Restore hooked functions
    if G.__CW_origSLnpi and G.__CW_ClientFire then
        pcall(function()
            G.__CW_ClientFire.sLnpiWe6Dt = G.__CW_origSLnpi
        end)
    end
    if G.__CW_origFire and G.__CW_ProjectileCaster then
        pcall(function()
            G.__CW_ProjectileCaster.Fire = G.__CW_origFire
        end)
    end
    if G.__CW_origRecoil and G.__CW_RecoilController then
        pcall(function()
            G.__CW_RecoilController.rNDvKCHx7N = G.__CW_origRecoil
        end)
    end

    -- Close WindUI window
    if G.__CW_Window then
        pcall(function() G.__CW_Window:Destroy() end)
    end

    G.__CW_ClientFire       = nil
    G.__CW_origSLnpi        = nil
    G.__CW_ProjectileCaster = nil
    G.__CW_origFire         = nil
    G.__CW_RecoilController = nil
    G.__CW_origRecoil       = nil
    G.__CW_Window           = nil
    G.__CW_Cleanup          = nil
end

-- ==============================================================================
-- [ CONFIGURATION ]
-- ==============================================================================
local Cfg = {
    -- Aim / Silent Aim
    SilentEnabled       = true,
    FOV                 = 250,
    ShowFOV             = true,
    TargetPart          = "Head",    -- "Head" | "HumanoidRootPart" | "Torso"
    HitChance           = 100,       -- 1 - 100%
    TeamCheck           = true,      -- Aimbot targets only enemies
    BallisticPrediction = true,       -- Compensate bullet drag, gravity drop & target velocity lead
    MaxDistance         = 1500,

    -- Weapon Modifiers
    NoRecoil            = true,      -- Suppress camera kick & spring recoil

    -- Triggerbot
    Triggerbot          = false,
    TriggerbotDelay     = 30,        -- ms

    -- Visuals / ESP
    ESPEnabled          = true,
    ShowTeammates       = true,      -- Show teammates as well (Teammates: Green, Enemies: Red)
    ESPBox              = true,
    ESPName             = true,
    NameMode            = "DisplayName", -- "DisplayName" | "Both" | "Username"
    ESPHealth           = true,
    ESPDistance         = true,
    ESPWeapon           = true,
    ESPTracers          = false,
    ChamsEnabled        = true,      -- Highlight characters through walls
    BillboardOverhead   = true,      -- Fail-safe 3D BillboardGui name overhead
    ESPMaxDist          = 1500,
    EnemyColor          = Color3.fromRGB(255, 65, 65),
    TeamColor           = Color3.fromRGB(65, 220, 65),
}

-- Stats tracking
local Stats = {
    shotsFired      = 0,
    shotsRedirected = 0,
    triggerPulls    = 0,
}

-- ==============================================================================
-- [ TARGET & ENVIRONMENT RECON ]
-- ==============================================================================
local function getCharactersFolder()
    return Workspace:FindFirstChild("Characters")
end

local function isPlayerAlive(model)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

local function getPlayerFromModel(model)
    if not model then return nil end
    local plr = Players:FindFirstChild(model.Name)
    if plr then return plr end
    return Players:GetPlayerFromCharacter(model)
end

local function isEnemy(model)
    local targetPlr = getPlayerFromModel(model)
    if not targetPlr then
        return true
    end
    if targetPlr == LocalPlayer then return false end

    if LocalPlayer.Team and targetPlr.Team then
        return targetPlr.Team ~= LocalPlayer.Team
    end
    return true
end

local function getTargetPart(model)
    if not model then return nil end
    local preferred = Cfg.TargetPart
    local part = model:FindFirstChild(preferred)
    if part and part:IsA("BasePart") then
        return part
    end
    -- Fallback order
    local fallbacks = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" }
    for _, name in ipairs(fallbacks) do
        local fallbackPart = model:FindFirstChild(name)
        if fallbackPart and fallbackPart:IsA("BasePart") then
            return fallbackPart
        end
    end
    return nil
end

local function getEquippedWeaponName(model)
    if not model then return "None" end
    local tool = model:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("Model") and string.find(c.Name, "Model") then
            return string.gsub(c.Name, "Model", "")
        end
    end
    return "None"
end

local function formatPlayerName(model)
    local plr = getPlayerFromModel(model)
    local disp = (plr and plr.DisplayName) or model.Name
    local user = (plr and plr.Name) or model.Name

    if Cfg.NameMode == "Both" and disp ~= user then
        return string.format("%s (@%s)", disp, user)
    elseif Cfg.NameMode == "Username" then
        return user
    else
        return disp
    end
end

-- ==============================================================================
-- [ WEAPON CONFIG & BALLISTICS RESOLUTION ]
-- ==============================================================================
local WeaponConfigManager = nil
local WeaponSource = nil
local ProjectileTypes = nil

pcall(function()
    WeaponConfigManager = require(ReplicatedStorage.Shared:WaitForChild("WeaponConfigManager", 5))
end)
pcall(function()
    local Ballistics = ReplicatedStorage.Shared:WaitForChild("Ballistics", 5)
    WeaponSource = require(Ballistics.Sources:WaitForChild("WeaponSource", 5))
    ProjectileTypes = require(Ballistics:WaitForChild("ProjectileTypes", 5))
end)

local function getWeaponBallistics(tool, muzzleIndex, bulletIndex)
    local speed = 2500
    local dragK = 0.9
    local gravityVal = Workspace.Gravity

    pcall(function()
        if WeaponSource and WeaponSource.toFireParams then
            local fp = WeaponSource.toFireParams({
                Tool = tool,
                WeaponName = tool and tool.Name,
                MuzzleIndex = muzzleIndex or 1,
                BulletIndex = bulletIndex or 1,
            })
            if fp and fp.Weapon then
                if type(fp.Weapon.MuzzleSpeed) == "number" and fp.Weapon.MuzzleSpeed > 0 then
                    speed = fp.Weapon.MuzzleSpeed
                end
                if type(fp.Weapon.K) == "number" then
                    dragK = fp.Weapon.K
                end
                if type(fp.Weapon.Gravity) == "number" then
                    gravityVal = fp.Weapon.Gravity
                end
                return
            end
        end

        if WeaponConfigManager and tool then
            local configs = WeaponConfigManager:MuzzleConfigsOf(tool.Name)
            if configs and configs[muzzleIndex or 1] then
                local mConf = configs[muzzleIndex or 1]
                local bSettings = mConf.BulletSettings and mConf.BulletSettings[bulletIndex or 1]
                if bSettings then
                    if type(bSettings.MuzzleVelocity) == "number" and bSettings.MuzzleVelocity > 0 then
                        speed = bSettings.MuzzleVelocity
                    end
                    if type(bSettings.Drag) == "number" then
                        dragK = bSettings.Drag
                    end
                end
            end
        end
    end)

    return speed, dragK, gravityVal
end

-- ==============================================================================
-- [ TARGET SELECTION & BALLISTIC CALCULATION ]
-- ==============================================================================
local function getBestTarget(muzzleOrigin, muzzleSpeed, dragK, gravityVal)
    if not Camera then
        Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
        if not Camera then return nil, nil, nil end
    end

    local vpSize = Camera.ViewportSize
    local center = Vector2.new(vpSize.X * 0.5, vpSize.Y * 0.5)

    local bestTargetModel = nil
    local bestPart = nil
    local bestScreenDist = Cfg.FOV
    local bestLeadPosition = nil

    local charsFolder = getCharactersFolder()
    if not charsFolder then return nil, nil, nil end

    local speed = muzzleSpeed or 2500
    local kDecay = dragK or 0.9
    local grav = gravityVal or Workspace.Gravity

    for _, model in ipairs(charsFolder:GetChildren()) do
        if not model:IsA("Model") or model.Name == LocalPlayer.Name then
            continue
        end

        if not isPlayerAlive(model) then
            continue
        end

        if Cfg.TeamCheck and not isEnemy(model) then
            continue
        end

        local part = getTargetPart(model)
        if not part then
            continue
        end

        local dist3D = (part.Position - (muzzleOrigin or Camera.CFrame.Position)).Magnitude
        if dist3D > Cfg.MaxDistance then
            continue
        end

        -- Screen projection & FOV validation
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen or screenPos.Z <= 0 then
            continue
        end

        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if screenDist <= bestScreenDist then
            bestScreenDist = screenDist
            bestTargetModel = model
            bestPart = part

            -- Ballistic Prediction & Lead Calculation
            if Cfg.BallisticPrediction and muzzleOrigin then
                local tof
                if kDecay > 1e-5 and dist3D * kDecay < speed then
                    tof = -(1 / kDecay) * math.log(1 - (dist3D * kDecay / speed))
                else
                    tof = dist3D / speed
                end

                local dropComp = Vector3.new(0, 0.5 * grav * (tof ^ 2), 0)

                local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
                local targetVelocity = Vector3.zero
                if hrp and hrp:IsA("BasePart") then
                    targetVelocity = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.zero
                end

                bestLeadPosition = part.Position + dropComp + (targetVelocity * tof)
            else
                bestLeadPosition = part.Position
            end
        end
    end

    return bestTargetModel, bestPart, bestLeadPosition
end

-- ==============================================================================
-- [ HOOK 1: BallisticsClient.ClientFire.sLnpiWe6Dt (NETWORKED SILENT AIM) ]
-- ==============================================================================
local ClientFire = nil
pcall(function()
    local ps = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local bc = ps and ps:WaitForChild("BallisticsClient", 5)
    if bc and bc:FindFirstChild("ClientFire") then
        ClientFire = require(bc.ClientFire)
    end
end)

if ClientFire and type(ClientFire.sLnpiWe6Dt) == "function" then
    G.__CW_ClientFire = ClientFire
    G.__CW_origSLnpi = ClientFire.sLnpiWe6Dt

    ClientFire.sLnpiWe6Dt = function(tool, muzzleIndex, bulletIndex, origin, directions, options)
        Stats.shotsFired = Stats.shotsFired + 1

        if Cfg.SilentEnabled and type(directions) == "table" and #directions > 0 then
            local roll = math.random(1, 100)
            if roll <= Cfg.HitChance then
                local speed, dragK, grav = getWeaponBallistics(tool, muzzleIndex, bulletIndex)
                local targetModel, targetPart, leadPos = getBestTarget(origin, speed, dragK, grav)

                if targetModel and targetPart and leadPos then
                    local newDir = (leadPos - origin).Unit
                    for i = 1, #directions do
                        directions[i] = newDir
                    end
                    Stats.shotsRedirected = Stats.shotsRedirected + 1
                end
            end
        end

        return G.__CW_origSLnpi(tool, muzzleIndex, bulletIndex, origin, directions, options)
    end
    print("[Cold War] Successfully hooked BallisticsClient.ClientFire.sLnpiWe6Dt")
end

-- ==============================================================================
-- [ HOOK 2: ReplicatedStorage.Shared.Ballistics.ProjectileCaster (FALLBACK) ]
-- ==============================================================================
local ProjectileCaster = nil
pcall(function()
    ProjectileCaster = require(ReplicatedStorage.Shared.Ballistics.ProjectileCaster)
end)

if ProjectileCaster and type(ProjectileCaster.Fire) == "function" then
    G.__CW_ProjectileCaster = ProjectileCaster
    G.__CW_origFire = ProjectileCaster.Fire

    ProjectileCaster.Fire = function(fireParams)
        if Cfg.SilentEnabled and fireParams and fireParams.Owner == LocalPlayer then
            local roll = math.random(1, 100)
            if roll <= Cfg.HitChance then
                local origin = fireParams.Origin or (Camera and Camera.CFrame.Position)
                local weapon = fireParams.Weapon
                local speed = weapon and weapon.MuzzleSpeed
                local dragK = weapon and weapon.K
                local grav  = weapon and weapon.Gravity

                local targetModel, targetPart, leadPos = getBestTarget(origin, speed, dragK, grav)
                if targetModel and targetPart and leadPos then
                    fireParams.Direction = (leadPos - origin).Unit
                end
            end
        end

        return G.__CW_origFire(fireParams)
    end
    print("[Cold War] Successfully hooked ProjectileCaster.Fire")
end

-- ==============================================================================
-- [ HOOK 3: RecoilController.rNDvKCHx7N (NO RECOIL) ]
-- ==============================================================================
local RecoilController = nil
pcall(function()
    local rcMod = ReplicatedStorage:FindFirstChild("Client")
        and ReplicatedStorage.Client:FindFirstChild("Tools")
        and ReplicatedStorage.Client.Tools:FindFirstChild("Weapon")
        and ReplicatedStorage.Client.Tools.Weapon:FindFirstChild("controllers")
        and ReplicatedStorage.Client.Tools.Weapon.controllers:FindFirstChild("RecoilController")
    if rcMod then
        RecoilController = require(rcMod)
    end
end)

if RecoilController and type(RecoilController.rNDvKCHx7N) == "function" then
    G.__CW_RecoilController = RecoilController
    G.__CW_origRecoil = RecoilController.rNDvKCHx7N

    RecoilController.rNDvKCHx7N = function(...)
        if Cfg.NoRecoil then
            return
        end
        return G.__CW_origRecoil(...)
    end
    print("[Cold War] Successfully hooked RecoilController.rNDvKCHx7N")
end

-- ==============================================================================
-- [ FOV DRAWING ]
-- ==============================================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.Filled = false
fovCircle.Transparency = 0.85
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Visible = false
table.insert(drawingPool, fovCircle)

-- ==============================================================================
-- [ ESP SYSTEM: DRAWING API ]
-- ==============================================================================
local espEntries = {}

local function createEspEntry()
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 1
    box.Visible = false
    box.ZIndex = 2
    table.insert(drawingPool, box)

    local boxOutline = Drawing.new("Square")
    boxOutline.Thickness = 3
    boxOutline.Filled = false
    boxOutline.Color = Color3.fromRGB(0, 0, 0)
    boxOutline.Transparency = 0.6
    boxOutline.Visible = false
    boxOutline.ZIndex = 1
    table.insert(drawingPool, boxOutline)

    local nameText = Drawing.new("Text")
    nameText.Size = 14
    nameText.Center = true
    nameText.Outline = true
    nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameText.Color = Color3.fromRGB(255, 255, 255)
    nameText.Visible = false
    nameText.ZIndex = 3
    table.insert(drawingPool, nameText)

    local weaponText = Drawing.new("Text")
    weaponText.Size = 12
    weaponText.Center = true
    weaponText.Outline = true
    weaponText.OutlineColor = Color3.fromRGB(0, 0, 0)
    weaponText.Color = Color3.fromRGB(240, 240, 240)
    weaponText.Visible = false
    weaponText.ZIndex = 3
    table.insert(drawingPool, weaponText)

    local hpBar = Drawing.new("Line")
    hpBar.Thickness = 2.5
    hpBar.Visible = false
    hpBar.ZIndex = 2
    table.insert(drawingPool, hpBar)

    local hpOutline = Drawing.new("Line")
    hpOutline.Thickness = 4.5
    hpOutline.Color = Color3.fromRGB(0, 0, 0)
    hpOutline.Visible = false
    hpOutline.ZIndex = 1
    table.insert(drawingPool, hpOutline)

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Transparency = 0.8
    tracer.Visible = false
    tracer.ZIndex = 1
    table.insert(drawingPool, tracer)

    return {
        Box        = box,
        BoxOutline = boxOutline,
        Name       = nameText,
        Weapon     = weaponText,
        HpBar      = hpBar,
        HpOutline  = hpOutline,
        Tracer     = tracer,
    }
end

local function hideEspEntry(entry)
    entry.Box.Visible = false
    entry.BoxOutline.Visible = false
    entry.Name.Visible = false
    entry.Weapon.Visible = false
    entry.HpBar.Visible = false
    entry.HpOutline.Visible = false
    entry.Tracer.Visible = false
end

local function getEspEntry(model)
    if not espEntries[model] then
        espEntries[model] = createEspEntry()
    end
    return espEntries[model]
end

-- ==============================================================================
-- [ ESP SYSTEM: OVERHEAD BILLBOARD GUI (100% RELIABLE IN-WORLD NAME) ]
-- ==============================================================================
local function updateBillboardOverhead(model, isEnemyTarget, shouldShow, dist)
    local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    if not head or not shouldShow or not Cfg.BillboardOverhead then
        local bb = billboardPool[model]
        if bb then bb.Enabled = false end
        return
    end

    local bb = billboardPool[model]
    if not bb or not bb.Parent then
        local gui = Instance.new("BillboardGui")
        gui.Name = "CW_Overhead"
        gui.Adornee = head
        gui.Size = UDim2.new(0, 200, 0, 40)
        gui.StudsOffset = Vector3.new(0, 2.5, 0)
        gui.AlwaysOnTop = true
        gui.MaxDistance = Cfg.ESPMaxDist
        gui.Parent = head

        local lbl = Instance.new("TextLabel")
        lbl.Name = "NameLabel"
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextStrokeTransparency = 0.2
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Parent = gui

        billboardPool[model] = gui
        bb = gui
    end

    local col = isEnemyTarget and Cfg.EnemyColor or Cfg.TeamColor
    local label = bb:FindFirstChild("NameLabel")
    if label and label:IsA("TextLabel") then
        local pName = formatPlayerName(model)
        local teamTag = isEnemyTarget and "[ENEMY]" or "[TEAM]"
        label.TextColor3 = col
        if Cfg.ESPDistance then
            label.Text = string.format("%s %s [%dm]", teamTag, pName, math.floor(dist))
        else
            label.Text = string.format("%s %s", teamTag, pName)
        end
    end
    bb.MaxDistance = Cfg.ESPMaxDist
    bb.Enabled = true
end

-- ==============================================================================
-- [ ESP SYSTEM: CHAMS (HIGHLIGHT) ]
-- ==============================================================================
local function updateHighlight(model, isEnemyTarget, shouldShow)
    local hl = highlightPool[model]
    if not shouldShow or not Cfg.ChamsEnabled then
        if hl then hl.Enabled = false end
        return
    end

    if not hl or not hl.Parent then
        hl = Instance.new("Highlight")
        hl.Name = "CW_Cham"
        hl.Adornee = model
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0.1
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = model
        highlightPool[model] = hl
    end

    local col = isEnemyTarget and Cfg.EnemyColor or Cfg.TeamColor
    hl.FillColor = col
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.Enabled = true
end

-- ==============================================================================
-- [ TRIGGERBOT ]
-- ==============================================================================
local lastTriggerTick = 0

local function pullTrigger()
    if typeof(mouse1click) == "function" then
        mouse1click()
        Stats.triggerPulls = Stats.triggerPulls + 1
    elseif typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
        mouse1press()
        task.wait(0.02)
        mouse1release()
        Stats.triggerPulls = Stats.triggerPulls + 1
    end
end

local function updateTriggerbot()
    if not Cfg.Triggerbot then return end
    local now = os.clock()
    if (now - lastTriggerTick) * 1000 < Cfg.TriggerbotDelay then
        return
    end

    local targetModel, targetPart = getBestTarget(Camera.CFrame.Position, 2500, 0.9, Workspace.Gravity)
    if targetModel and targetPart then
        lastTriggerTick = now
        pullTrigger()
    end
end

-- ==============================================================================
-- [ MAIN RENDER LOOP ]
-- ==============================================================================
local renderConn = RunService.RenderStepped:Connect(function()
    if not Camera then
        Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
        return
    end

    local vpSize = Camera.ViewportSize
    local center = Vector2.new(vpSize.X * 0.5, vpSize.Y * 0.5)

    -- Update FOV circle
    fovCircle.Position = center
    fovCircle.Radius = Cfg.FOV
    fovCircle.Visible = Cfg.SilentEnabled and Cfg.ShowFOV

    -- Triggerbot
    if Cfg.Triggerbot then
        pcall(updateTriggerbot)
    end

    local charsFolder = getCharactersFolder()
    local activeModels = {}

    if charsFolder then
        for _, model in ipairs(charsFolder:GetChildren()) do
            if not model:IsA("Model") or model.Name == LocalPlayer.Name then
                continue
            end

            if not isPlayerAlive(model) then
                continue
            end

            local isEnemyTarget = isEnemy(model)

            -- Check if teammates should be displayed
            if not isEnemyTarget and not Cfg.ShowTeammates then
                continue
            end

            local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
            local head = model:FindFirstChild("Head") or hrp
            if not hrp then continue end

            local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if dist > Cfg.ESPMaxDist then
                continue
            end

            activeModels[model] = true

            -- 1. Update In-World Billboard Overhead (100% visible guaranteed)
            updateBillboardOverhead(model, isEnemyTarget, true, dist)

            -- 2. Update Highlight Chams
            updateHighlight(model, isEnemyTarget, true)

            -- 3. Update 2D Drawing ESP
            local rootScreen, onScreen = Camera:WorldToViewportPoint(hrp.Position)

            if Cfg.ESPEnabled and onScreen and rootScreen.Z > 0 then
                local entry = getEspEntry(model)
                local col = isEnemyTarget and Cfg.EnemyColor or Cfg.TeamColor

                local headPos = (head and head.Position or hrp.Position) + Vector3.new(0, 0.8, 0)
                local footPos = hrp.Position - Vector3.new(0, 3.0, 0)

                local headScreen = Camera:WorldToViewportPoint(headPos)
                local footScreen = Camera:WorldToViewportPoint(footPos)

                local height = math.clamp(math.abs(footScreen.Y - headScreen.Y), 15, 1200)
                local width  = height * 0.65
                local left   = rootScreen.X - (width * 0.5)
                local top    = headScreen.Y

                -- 2D Box
                if Cfg.ESPBox then
                    entry.BoxOutline.Size = Vector2.new(width, height)
                    entry.BoxOutline.Position = Vector2.new(left, top)
                    entry.BoxOutline.Visible = true

                    entry.Box.Size = Vector2.new(width, height)
                    entry.Box.Position = Vector2.new(left, top)
                    entry.Box.Color = col
                    entry.Box.Visible = true
                else
                    entry.Box.Visible = false
                    entry.BoxOutline.Visible = false
                end

                -- Player Name
                if Cfg.ESPName then
                    local nameStr = formatPlayerName(model)
                    if Cfg.ESPDistance then
                        nameStr = string.format("%s [%dm]", nameStr, math.floor(dist))
                    end
                    entry.Name.Text = nameStr
                    entry.Name.Position = Vector2.new(rootScreen.X, math.max(top - 17, 4))
                    entry.Name.Color = col
                    entry.Name.Visible = true
                else
                    entry.Name.Visible = false
                end

                -- Weapon Name
                if Cfg.ESPWeapon then
                    entry.Weapon.Text = getEquippedWeaponName(model)
                    entry.Weapon.Position = Vector2.new(rootScreen.X, top + height + 2)
                    entry.Weapon.Color = Color3.fromRGB(240, 240, 240)
                    entry.Weapon.Visible = true
                else
                    entry.Weapon.Visible = false
                end

                -- Health Bar
                if Cfg.ESPHealth then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    local hpFrac = 1
                    if hum and hum.MaxHealth > 0 then
                        hpFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    end

                    local barX = left - 6
                    local barTop = top + height * (1 - hpFrac)
                    local barBottom = top + height

                    entry.HpOutline.From = Vector2.new(barX, top)
                    entry.HpOutline.To = Vector2.new(barX, barBottom)
                    entry.HpOutline.Visible = true

                    entry.HpBar.From = Vector2.new(barX, barTop)
                    entry.HpBar.To = Vector2.new(barX, barBottom)
                    entry.HpBar.Color = Color3.fromHSV(hpFrac * 0.33, 1, 1)
                    entry.HpBar.Visible = true
                else
                    entry.HpBar.Visible = false
                    entry.HpOutline.Visible = false
                end

                -- Tracer
                if Cfg.ESPTracers then
                    entry.Tracer.From = Vector2.new(vpSize.X * 0.5, vpSize.Y)
                    entry.Tracer.To = Vector2.new(rootScreen.X, top + height)
                    entry.Tracer.Color = col
                    entry.Tracer.Visible = true
                else
                    entry.Tracer.Visible = false
                end
            elseif espEntries[model] then
                hideEspEntry(espEntries[model])
            end
        end
    end

    -- Cleanup non-visible or removed models
    for model, entry in pairs(espEntries) do
        if not activeModels[model] then
            hideEspEntry(entry)
            if not model.Parent then
                pcall(function()
                    entry.Box:Remove()
                    entry.BoxOutline:Remove()
                    entry.Name:Remove()
                    entry.Weapon:Remove()
                    entry.HpBar:Remove()
                    entry.HpOutline:Remove()
                    entry.Tracer:Remove()
                end)
                espEntries[model] = nil
            end
        end
    end

    for model, hl in pairs(highlightPool) do
        if not activeModels[model] then
            hl.Enabled = false
            if not model.Parent then
                pcall(function() hl:Destroy() end)
                highlightPool[model] = nil
            end
        end
    end

    for model, bb in pairs(billboardPool) do
        if not activeModels[model] then
            bb.Enabled = false
            if not model.Parent then
                pcall(function() bb:Destroy() end)
                billboardPool[model] = nil
            end
        end
    end
end)
table.insert(connections, renderConn)

-- ==============================================================================
-- [ USER INTERFACE: WindUI ]
-- Theme = "White", ToggleKey = Enum.KeyCode.RightShift
-- ==============================================================================
local okUI, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if okUI and WindUI ~= nil then
    pcall(function()
        local Window = nil
        local okWindow = pcall(function()
            Window = WindUI:CreateWindow({
                Title     = "Cold War - Ballistics Suite",
                Icon      = "target",
                Author    = "Antigravity",
                Folder    = "ColdWarConfig",
                Size      = UDim2.fromOffset(480, 560),
                Theme     = "White",
                ToggleKey = Enum.KeyCode.RightShift,
            })
        end)

        if not Window then
            Window = WindUI:CreateWindow({
                Title     = "Cold War - Ballistics Suite",
                Icon      = "target",
                Author    = "Antigravity",
                Folder    = "ColdWarConfig",
                Size      = UDim2.fromOffset(480, 560),
                Theme     = "Dark",
                ToggleKey = Enum.KeyCode.RightShift,
            })
        end
        G.__CW_Window = Window

        -- Tab 1: Ballistics & Silent Aim
        local AimTab = Window:Tab({ Title = "Ballistics / Aim", Icon = "crosshair" })

        AimTab:Toggle({
            Title    = "Networked Silent Aim",
            Desc     = "Redirects pellets before Net.Fire serialization & local raycast simulation",
            Value    = Cfg.SilentEnabled,
            Callback = function(v) Cfg.SilentEnabled = v end,
        })

        AimTab:Toggle({
            Title    = "Ballistic Prediction & Drag Compensation",
            Desc     = "Compensates for aerodynamic drag decay (K), gravity drop & target velocity lead",
            Value    = Cfg.BallisticPrediction,
            Callback = function(v) Cfg.BallisticPrediction = v end,
        })

        AimTab:Slider({
            Title    = "FOV Radius",
            Desc     = "Silent aim target selection radius in screen pixels",
            Value    = { Min = 40, Max = 600, Default = Cfg.FOV },
            Step     = 5,
            Callback = function(v) Cfg.FOV = v end,
        })

        AimTab:Dropdown({
            Title    = "Target Bone / Part",
            Desc     = "Priority body part to redirect bullets toward",
            Values   = { "Head", "HumanoidRootPart", "Torso" },
            Value    = Cfg.TargetPart,
            Callback = function(v) Cfg.TargetPart = v end,
        })

        AimTab:Slider({
            Title    = "Hit Chance %",
            Desc     = "Percentage rate of bullet redirection",
            Value    = { Min = 1, Max = 100, Default = Cfg.HitChance },
            Step     = 1,
            Callback = function(v) Cfg.HitChance = v end,
        })

        AimTab:Toggle({
            Title    = "Aimbot Team Check",
            Desc     = "Ignore friendly players (NATO / PACT teams)",
            Value    = Cfg.TeamCheck,
            Callback = function(v) Cfg.TeamCheck = v end,
        })

        AimTab:Toggle({
            Title    = "Show FOV Circle",
            Desc     = "Render visible circle around crosshair",
            Value    = Cfg.ShowFOV,
            Callback = function(v) Cfg.ShowFOV = v end,
        })

        -- Tab 2: Weapon Modifiers & Triggerbot
        local WeaponTab = Window:Tab({ Title = "Gun Mods & Trigger", Icon = "zap" })

        WeaponTab:Toggle({
            Title    = "No Recoil",
            Desc     = "Eliminates camera kick & gun spring displacement via RecoilController hook",
            Value    = Cfg.NoRecoil,
            Callback = function(v) Cfg.NoRecoil = v end,
        })

        WeaponTab:Toggle({
            Title    = "Triggerbot Enabled",
            Desc     = "Automatically fire whenever an enemy enters aim FOV",
            Value    = Cfg.Triggerbot,
            Callback = function(v) Cfg.Triggerbot = v end,
        })

        WeaponTab:Slider({
            Title    = "Triggerbot Delay (ms)",
            Desc     = "Reaction delay before pulling trigger",
            Value    = { Min = 0, Max = 300, Default = Cfg.TriggerbotDelay },
            Step     = 10,
            Callback = function(v) Cfg.TriggerbotDelay = v end,
        })

        -- Tab 3: Visuals & ESP
        local VisualsTab = Window:Tab({ Title = "Visuals / ESP", Icon = "eye" })

        VisualsTab:Toggle({
            Title    = "ESP Master Switch",
            Desc     = "Render 2D Drawing overlays on characters",
            Value    = Cfg.ESPEnabled,
            Callback = function(v) Cfg.ESPEnabled = v end,
        })

        VisualsTab:Toggle({
            Title    = "Show Teammates (Team ESP)",
            Desc     = "Display teammates in Green and enemies in Red",
            Value    = Cfg.ShowTeammates,
            Callback = function(v) Cfg.ShowTeammates = v end,
        })

        VisualsTab:Toggle({
            Title    = "Overhead 3D Billboard Name",
            Desc     = "In-world guaranteed billboard label above head (Never clips)",
            Value    = Cfg.BillboardOverhead,
            Callback = function(v) Cfg.BillboardOverhead = v end,
        })

        VisualsTab:Toggle({
            Title    = "Player Name ESP",
            Desc     = "Display player name above box",
            Value    = Cfg.ESPName,
            Callback = function(v) Cfg.ESPName = v end,
        })

        VisualsTab:Dropdown({
            Title    = "Name Display Mode",
            Desc     = "Choose DisplayName, Username or Both",
            Values   = { "DisplayName", "Both", "Username" },
            Value    = Cfg.NameMode,
            Callback = function(v) Cfg.NameMode = v end,
        })

        VisualsTab:Toggle({
            Title    = "Highlight Chams",
            Desc     = "Glow enemy character models through walls",
            Value    = Cfg.ChamsEnabled,
            Callback = function(v) Cfg.ChamsEnabled = v end,
        })

        VisualsTab:Toggle({
            Title    = "2D Box ESP",
            Desc     = "2D bounding box",
            Value    = Cfg.ESPBox,
            Callback = function(v) Cfg.ESPBox = v end,
        })

        VisualsTab:Toggle({
            Title    = "Equipped Weapon ESP",
            Desc     = "Display name of gun held by player",
            Value    = Cfg.ESPWeapon,
            Callback = function(v) Cfg.ESPWeapon = v end,
        })

        VisualsTab:Toggle({
            Title    = "Health Bar",
            Desc     = "Dynamic colored health bar on the left",
            Value    = Cfg.ESPHealth,
            Callback = function(v) Cfg.ESPHealth = v end,
        })

        VisualsTab:Toggle({
            Title    = "Distance Text",
            Desc     = "Display distance in studs/meters",
            Value    = Cfg.ESPDistance,
            Callback = function(v) Cfg.ESPDistance = v end,
        })

        VisualsTab:Toggle({
            Title    = "Tracers (Snaplines)",
            Desc     = "Draw lines from bottom screen to targets",
            Value    = Cfg.ESPTracers,
            Callback = function(v) Cfg.ESPTracers = v end,
        })

        VisualsTab:Slider({
            Title    = "Max Visual Distance",
            Desc     = "Cull entities beyond this distance",
            Value    = { Min = 100, Max = 2500, Default = Cfg.ESPMaxDist },
            Step     = 50,
            Callback = function(v) Cfg.ESPMaxDist = v end,
        })

        -- Tab 4: Utilities & Stats
        local UtilsTab = Window:Tab({ Title = "Utilities", Icon = "settings" })

        UtilsTab:Button({
            Title    = "Show Statistics Notification",
            Callback = function()
                WindUI:Notify({
                    Title    = "Ballistics Stats",
                    Content  = string.format("Shots: %d | Redirected: %d | Trigger: %d",
                        Stats.shotsFired, Stats.shotsRedirected, Stats.triggerPulls),
                    Duration = 4,
                })
            end,
        })

        UtilsTab:Button({
            Title    = "Unload & Cleanup Script",
            Callback = function()
                if G.__CW_Cleanup then
                    G.__CW_Cleanup()
                end
            end,
        })

        WindUI:Notify({
            Title    = "Cold War Ballistics",
            Content  = "Loaded successfully! Press RightShift to toggle menu.",
            Duration = 5,
        })
    end)
else
    warn("[Cold War] WindUI failed to load from remote repository.")
end

print("[Cold War] Ballistics Suite v2.1 (Name Fix + Team ESP + Billboard) initialized.")
