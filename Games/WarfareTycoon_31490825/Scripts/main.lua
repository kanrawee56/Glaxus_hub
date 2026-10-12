-- =====================================================================
-- WARFARE TYCOON [NEW JET] (PlaceId: 31490825) - MAIN SCRIPT
-- Universal Cursor Silent Aim, Wallbang, Weapon Mods, Visuals & WindUI
-- Architecture: Single-file, ready-to-run
-- =====================================================================

-- [REVISION & KILLSWITCH]
local REV = (getgenv().EsaWT_Rev or 0) + 1
getgenv().EsaWT_Rev = REV

if getgenv().EsaWT_Cleanup then
    pcall(getgenv().EsaWT_Cleanup)
end

-- [CONFIG & DEFAULTS]
local Cfg = {
    SilentAim = true,
    SilentFOV = 350,
    Wallbang = true,
    TargetPart = "Head", -- "Head" or "HumanoidRootPart"
    TargetBots = true,
    CheckTeam = true,
    NoRecoil = true,
    NoSpread = true,
    FastADS = true,
    ESP_Enabled = true,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Snaplines = false,
    FOV_Circle = true,
}

-- [SERVICES]
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- [CLEANUP STORAGE]
local connections = {}
local drawingObjects = {}
local activeWindow = nil
local floatingToggleGui = nil

local function addConn(conn)
    table.insert(connections, conn)
    return conn
end

local function createDrawing(typ, props)
    if Drawing == nil then return { Visible = false, Remove = function() end } end
    local obj = Drawing.new(typ)
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    table.insert(drawingObjects, obj)
    return obj
end

getgenv().EsaWT_Cleanup = function()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, d in ipairs(drawingObjects) do
        pcall(function() d:Remove() end)
    end
    if activeWindow then
        pcall(function() activeWindow:Destroy() end)
        activeWindow = nil
    end
    if floatingToggleGui then
        pcall(function() floatingToggleGui:Destroy() end)
        floatingToggleGui = nil
    end
    table.clear(connections)
    table.clear(drawingObjects)
    warn("[WarfareTycoon] Previous revision cleaned up.")
end

-- =====================================================================
-- [TARGETING] Universal Screen Cursor Distance
-- =====================================================================
local function isTeammate(plr)
    if not Cfg.CheckTeam then return false end
    if not plr or plr == LP then return true end

    -- Check Roblox Team
    if LP.Team and plr.Team and LP.Team == plr.Team then
        return true
    end

    -- Check Warfare Tycoon SquadIndex
    local mySquad = LP:GetAttribute("SquadIndex")
    local theirSquad = plr:GetAttribute("SquadIndex")
    if mySquad and theirSquad and mySquad == theirSquad and mySquad ~= 0 then
        return true
    end

    return false
end

local function getEnemyCharacters()
    local enemies = {}

    -- Players in Workspace
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and not isTeammate(p) then
            local char = p.Character
            if char and char.Parent then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if hum and hum.Health > 0 and hrp then
                    table.insert(enemies, {
                        Model = char,
                        Player = p,
                        Name = p.DisplayName or p.Name,
                        Root = hrp,
                        Head = char:FindFirstChild("Head") or hrp,
                        Humanoid = hum,
                        IsBot = false
                    })
                end
            end
        end
    end

    -- Bots / NPCs (if enabled)
    if Cfg.TargetBots then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("Head")
                if hum and hum.Health > 0 and hrp and obj ~= LP.Character then
                    table.insert(enemies, {
                        Model = obj,
                        Player = nil,
                        Name = obj.Name,
                        Root = hrp,
                        Head = obj:FindFirstChild("Head") or hrp,
                        Humanoid = hum,
                        IsBot = true
                    })
                end
            end
        end
    end

    return enemies
end

local function getUniversalCursorTarget(maxFov)
    maxFov = maxFov or Cfg.SilentFOV or 350
    local mousePos = UIS:GetMouseLocation()
    local bestTarget = nil
    local shortestDist = maxFov

    local enemies = getEnemyCharacters()
    for _, e in ipairs(enemies) do
        local aimPart = if Cfg.TargetPart == "Head" then e.Head else e.Root
        if aimPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
            if onScreen and screenPos.Z > 0 then
                local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if screenDist < shortestDist then
                    shortestDist = screenDist
                    bestTarget = {
                        Enemy = e,
                        Part = aimPart,
                        ScreenPos = Vector2.new(screenPos.X, screenPos.Y),
                        Distance = (aimPart.Position - Camera.CFrame.Position).Magnitude
                    }
                end
            end
        end
    end

    return bestTarget
end

-- =====================================================================
-- [WEAPON MODS] ACS_Settings Injector (No Recoil, No Spread, Fast ADS)
-- =====================================================================
local function patchWeaponSettings(tool)
    if not (tool and tool:IsA("Tool")) then return end
    local settingsMod = tool:FindFirstChild("ACS_Settings")
    if not settingsMod then return end

    local ok, settingsTable = pcall(require, settingsMod)
    if not (ok and type(settingsTable) == "table") then return end

    if Cfg.NoRecoil then
        settingsTable.MinRecoilPower = 0
        settingsTable.MaxRecoilPower = 0
        settingsTable.RecoilPowerStepAmount = 0
        if type(settingsTable.camRecoil) == "table" then
            settingsTable.camRecoil.CamRecoilUp = {0, 0}
            settingsTable.camRecoil.CamRecoilLeft = {0, 0}
            settingsTable.camRecoil.CamRecoilRight = {0, 0}
            settingsTable.camRecoil.CamRecoilTilt = {0, 0}
        end
        if type(settingsTable.gunRecoil) == "table" then
            settingsTable.gunRecoil.GunRecoilUp = {0, 0}
            settingsTable.gunRecoil.GunRecoilLeft = {0, 0}
            settingsTable.gunRecoil.GunRecoilRight = {0, 0}
            settingsTable.gunRecoil.GunRecoilTilt = {0, 0}
        end
    end

    if Cfg.NoSpread then
        settingsTable.MinSpread = 0
        settingsTable.MaxSpread = 0
        settingsTable.AimSpreadReduction = 100
    end

    if Cfg.FastADS then
        settingsTable.adsTime = 0.01
    end
end

local function scanAndPatchInventory()
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            patchWeaponSettings(t)
        end
    end
    if LP.Character then
        for _, t in ipairs(LP.Character:GetChildren()) do
            patchWeaponSettings(t)
        end
    end
end

scanAndPatchInventory()
if LP:FindFirstChild("Backpack") then
    addConn(LP.Backpack.ChildAdded:Connect(function(child)
        task.wait(0.1)
        patchWeaponSettings(child)
    end))
end

-- =====================================================================
-- [SILENT AIM HOOKS]
-- 1. ShootModule.fire Hook (Infantry & Vehicles client ballistics)
-- 2. ServerBullet Remote Hook (Server hit registration)
-- 3. canRayPierce Hook (Wallbang penetration)
-- =====================================================================
task.spawn(function()
    -- 1. Hook ShootModule.fire
    local okShoot, ShootModule = pcall(function()
        return require(RepStorage:WaitForChild("Modules", 5):WaitForChild("Projectile", 5):WaitForChild("ShootModule", 5))
    end)

    if okShoot and ShootModule and type(ShootModule.fire) == "function" then
        local rawFire = ShootModule.fire
        ShootModule.fire = function(shooter, origin, lookVector, bulletData, ...)
            if REV ~= getgenv().EsaWT_Rev then return rawFire(shooter, origin, lookVector, bulletData, ...) end

            if Cfg.SilentAim and (shooter == LP or shooter == nil) then
                local target = getUniversalCursorTarget()
                if target and target.Part then
                    local redirectedDir = (target.Part.Position - origin).Unit
                    return rawFire(shooter, origin, redirectedDir, bulletData, ...)
                end
            end
            return rawFire(shooter, origin, lookVector, bulletData, ...)
        end
        warn("[WarfareTycoon] Hooked ShootModule.fire successfully.")
    else
        warn("[WarfareTycoon] ShootModule.fire could not be hooked.")
    end

    -- 2. Hook BulletHitDetector.canRayPierce (Wallbang)
    local okHit, BulletHitDetector = pcall(function()
        return require(RepStorage:WaitForChild("Modules", 5):WaitForChild("Projectile", 5):WaitForChild("BulletHitDetector", 5))
    end)

    if okHit and BulletHitDetector and type(BulletHitDetector.canRayPierce) == "function" then
        local rawPierce = BulletHitDetector.canRayPierce
        BulletHitDetector.canRayPierce = function(shooter, hitPart, bulletData)
            if REV ~= getgenv().EsaWT_Rev then return rawPierce(shooter, hitPart, bulletData) end

            if Cfg.Wallbang and (shooter == LP or shooter == nil) then
                if hitPart and hitPart.Parent then
                    local hum = hitPart.Parent:FindFirstChildOfClass("Humanoid")
                    if not hum and hitPart.Parent.Parent then
                        hum = hitPart.Parent.Parent:FindFirstChildOfClass("Humanoid")
                    end
                    -- If the hit part is a wall, vehicle armor, prop or terrain, pierce straight through!
                    if not hum then
                        return true
                    end
                end
            end
            return rawPierce(shooter, hitPart, bulletData)
        end
        warn("[WarfareTycoon] Hooked BulletHitDetector.canRayPierce (Wallbang) successfully.")
    else
        warn("[WarfareTycoon] BulletHitDetector.canRayPierce could not be hooked.")
    end

    -- 3. Hook ServerBullet via __namecall
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if REV ~= getgenv().EsaWT_Rev then return oldNamecall(self, ...) end

            local method = getnamecallmethod()
            local args = {...}

            if not checkcaller() and (method == "FireServer" or method == "fireServer") and self and self.Name == "ServerBullet" then
                if Cfg.SilentAim and #args >= 2 and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                    local origin = args[1]
                    local target = getUniversalCursorTarget()
                    if target and target.Part then
                        args[2] = (target.Part.Position - origin).Unit
                    end
                end
            end

            return oldNamecall(self, table.unpack(args))
        end))
        warn("[WarfareTycoon] Hooked ServerBullet __namecall successfully.")
    end
end)

-- =====================================================================
-- [VISUALS] FOV Circle & ESP
-- =====================================================================
local fovCircle = createDrawing("Circle", {
    Visible = false,
    Radius = Cfg.SilentFOV or 350,
    Color = Color3.fromRGB(0, 255, 170),
    Thickness = 1.5,
    Filled = false,
    Transparency = 0.85
})

local snapLine = createDrawing("Line", {
    Visible = false,
    Color = Color3.fromRGB(255, 60, 60),
    Thickness = 1.5,
    Transparency = 0.9
})

local espCache = {}

local function getOrCreateESP(model)
    if espCache[model] then return espCache[model] end
    local esp = {
        Box = createDrawing("Square", { Thickness = 1.5, Filled = false }),
        Name = createDrawing("Text", { Size = 13, Center = true, Outline = true }),
        Health = createDrawing("Line", { Thickness = 2.5 }),
        Dist = createDrawing("Text", { Size = 11, Center = true, Outline = true })
    }
    espCache[model] = esp
    return esp
end

addConn(RS.RenderStepped:Connect(function()
    if REV ~= getgenv().EsaWT_Rev then return end

    local mousePos = UIS:GetMouseLocation()

    -- 1. FOV Circle
    if Cfg.FOV_Circle and Cfg.SilentAim then
        fovCircle.Position = mousePos
        fovCircle.Radius = Cfg.SilentFOV or 350
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end

    -- 2. Current Silent Aim Target & SnapLine
    local currentTarget = getUniversalCursorTarget()
    if Cfg.ESP_Snaplines and currentTarget and currentTarget.ScreenPos then
        snapLine.From = mousePos
        snapLine.To = currentTarget.ScreenPos
        snapLine.Visible = true
    else
        snapLine.Visible = false
    end

    -- 3. ESP Rendering
    local enemies = getEnemyCharacters()
    local activeModels = {}

    for _, e in ipairs(enemies) do
        activeModels[e.Model] = true
        local esp = getOrCreateESP(e.Model)

        if not Cfg.ESP_Enabled then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            esp.Dist.Visible = false
        else
            local rootPart = e.Root
            local headPart = e.Head
            local hum = e.Humanoid

            local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            local headPos = Camera:WorldToViewportPoint(headPart.Position + Vector3.new(0, 0.6, 0))
            local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

            if onScreen and rootPos.Z > 0 then
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height * 0.65
                local boxPos = Vector2.new(rootPos.X - width / 2, headPos.Y)

                local dist = math.floor((rootPart.Position - Camera.CFrame.Position).Magnitude)
                local color = if e == (currentTarget and currentTarget.Enemy) then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(0, 255, 170)

                -- Box
                if Cfg.ESP_Boxes then
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = boxPos
                    esp.Box.Color = color
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end

                -- Name
                if Cfg.ESP_Names then
                    esp.Name.Text = (if e.IsBot then "[BOT] " else "") .. e.Name
                    esp.Name.Position = Vector2.new(rootPos.X, boxPos.Y - 16)
                    esp.Name.Color = color
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end

                -- Health Bar
                if Cfg.ESP_Health and hum.MaxHealth > 0 then
                    local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barHeight = height * hpPct
                    esp.Health.From = Vector2.new(boxPos.X - 5, boxPos.Y + height)
                    esp.Health.To = Vector2.new(boxPos.X - 5, boxPos.Y + height - barHeight)
                    esp.Health.Color = Color3.fromHSV(hpPct * 0.33, 1, 1)
                    esp.Health.Visible = true
                else
                    esp.Health.Visible = false
                end

                -- Distance
                if Cfg.ESP_Distance then
                    esp.Dist.Text = tostring(dist) .. "m"
                    esp.Dist.Position = Vector2.new(rootPos.X, boxPos.Y + height + 2)
                    esp.Dist.Color = Color3.fromRGB(220, 220, 220)
                    esp.Dist.Visible = true
                else
                    esp.Dist.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Health.Visible = false
                esp.Dist.Visible = false
            end
        end
    end

    -- Clean up stale ESP drawings
    for model, esp in pairs(espCache) do
        if not activeModels[model] then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            esp.Dist.Visible = false
        end
    end
end))

-- =====================================================================
-- [USER INTERFACE: WindUI + FLOATING TOGGLE BUTTON]
-- =====================================================================
task.spawn(function()
    local okUI, WindUI = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)

    if okUI and WindUI then
        local Window = WindUI:CreateWindow({
            Title     = "Warfare Tycoon [NEW JET]",
            Icon      = "crosshair",
            Author    = "Antigravity",
            Folder    = "WarfareTycoonConfig",
            Size      = UDim2.fromOffset(540, 480),
            Theme     = "Dark",
            ToggleKey = Enum.KeyCode.RightShift,
        })
        activeWindow = Window

        -- Configure WindUI's built-in OpenButton
        pcall(function()
            Window:EditOpenButton({
                Title = "Open Menu",
                Icon = "crosshair",
                CornerRadius = UDim.new(0, 8),
                StrokeThickness = 2,
                Color = ColorSequence.new(Color3.fromRGB(0, 255, 170), Color3.fromRGB(0, 170, 255)),
                Enabled = true,
            })
        end)

        -- Create sleek floating draggable screen toggle button so menu NEVER gets lost
        pcall(function()
            local hui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
            floatingToggleGui = Instance.new("ScreenGui")
            floatingToggleGui.Name = "EsaWT_FloatingToggle"
            floatingToggleGui.ResetOnSpawn = false
            floatingToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            floatingToggleGui.Parent = hui

            local floatBtn = Instance.new("TextButton")
            floatBtn.Name = "ToggleBtn"
            floatBtn.Size = UDim2.new(0, 136, 0, 36)
            floatBtn.Position = UDim2.new(0, 20, 0.45, 0)
            floatBtn.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
            floatBtn.Text = "⚔️ MENU [R-Shift]"
            floatBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
            floatBtn.TextSize = 13
            floatBtn.Font = Enum.Font.GothamBold
            floatBtn.AutoButtonColor = true
            floatBtn.Active = true
            floatBtn.Draggable = true
            floatBtn.Parent = floatingToggleGui

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = floatBtn

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(0, 255, 170)
            stroke.Thickness = 1.5
            stroke.Transparency = 0.25
            stroke.Parent = floatBtn

            floatBtn.MouseButton1Click:Connect(function()
                if Window then
                    pcall(function() Window:Toggle() end)
                end
            end)
        end)

        -- Tab 1: Silent Aim
        local AimTab = Window:Tab({ Title = "Aim / Silent", Icon = "crosshair" })

        AimTab:Toggle({
            Title    = "Silent Aim",
            Desc     = "Redirects bullets to enemy closest to cursor",
            Value    = Cfg.SilentAim,
            Callback = function(v) Cfg.SilentAim = v end,
        })

        AimTab:Slider({
            Title    = "FOV Radius",
            Desc     = "Screen cursor distance limit in pixels",
            Value    = { Min = 50, Max = 800, Default = Cfg.SilentFOV },
            Step     = 10,
            Callback = function(v) Cfg.SilentFOV = v end,
        })

        AimTab:Toggle({
            Title    = "Show FOV Circle",
            Desc     = "Draws circle around mouse cursor",
            Value    = Cfg.FOV_Circle,
            Callback = function(v) Cfg.FOV_Circle = v end,
        })

        AimTab:Dropdown({
            Title    = "Target Bone",
            Desc     = "Priority body part to hit",
            Values   = { "Head", "HumanoidRootPart" },
            Value    = Cfg.TargetPart,
            Callback = function(v) Cfg.TargetPart = v end,
        })

        AimTab:Toggle({
            Title    = "Team & Squad Check",
            Desc     = "Ignore friendly players & squad mates",
            Value    = Cfg.CheckTeam,
            Callback = function(v) Cfg.CheckTeam = v end,
        })

        AimTab:Toggle({
            Title    = "Target Bots & NPCs",
            Desc     = "Also target AI / hostile non-player models",
            Value    = Cfg.TargetBots,
            Callback = function(v) Cfg.TargetBots = v end,
        })

        AimTab:Toggle({
            Title    = "Snapline to Target",
            Desc     = "Draw line from cursor to current locked target",
            Value    = Cfg.ESP_Snaplines,
            Callback = function(v) Cfg.ESP_Snaplines = v end,
        })

        -- Tab 2: Weapon Mods & Wallbang
        local ModTab = Window:Tab({ Title = "Weapon Mods", Icon = "zap" })

        ModTab:Toggle({
            Title    = "Wallbang (CanRayPierce)",
            Desc     = "Bullets pierce walls, props & vehicle armor",
            Value    = Cfg.Wallbang,
            Callback = function(v) Cfg.Wallbang = v end,
        })

        ModTab:Toggle({
            Title    = "No Recoil",
            Desc     = "Removes camera and gun kickback",
            Value    = Cfg.NoRecoil,
            Callback = function(v)
                Cfg.NoRecoil = v
                scanAndPatchInventory()
            end,
        })

        ModTab:Toggle({
            Title    = "No Spread",
            Desc     = "100% pinpoint accuracy without bullet dispersion",
            Value    = Cfg.NoSpread,
            Callback = function(v)
                Cfg.NoSpread = v
                scanAndPatchInventory()
            end,
        })

        ModTab:Toggle({
            Title    = "Instant ADS",
            Desc     = "Instantaneous aim-down-sights zoom transition",
            Value    = Cfg.FastADS,
            Callback = function(v)
                Cfg.FastADS = v
                scanAndPatchInventory()
            end,
        })

        ModTab:Button({
            Title    = "Re-apply Weapon Mods",
            Desc     = "Re-patches current equipped gun & backpack",
            Callback = function()
                scanAndPatchInventory()
                WindUI:Notify({ Title = "Weapon Mods", Content = "Weapons successfully patched!", Duration = 2 })
            end,
        })

        -- Tab 3: Visuals / ESP
        local EspTab = Window:Tab({ Title = "Visuals / ESP", Icon = "eye" })

        EspTab:Toggle({
            Title    = "Master ESP",
            Desc     = "Enable / disable entire ESP overlay",
            Value    = Cfg.ESP_Enabled,
            Callback = function(v) Cfg.ESP_Enabled = v end,
        })

        EspTab:Toggle({
            Title    = "Box ESP",
            Desc     = "Bounding 2D box around enemies",
            Value    = Cfg.ESP_Boxes,
            Callback = function(v) Cfg.ESP_Boxes = v end,
        })

        EspTab:Toggle({
            Title    = "Name ESP",
            Desc     = "Display player/bot name",
            Value    = Cfg.ESP_Names,
            Callback = function(v) Cfg.ESP_Names = v end,
        })

        EspTab:Toggle({
            Title    = "Health Bar",
            Desc     = "Vertical color-coded health indicator",
            Value    = Cfg.ESP_Health,
            Callback = function(v) Cfg.ESP_Health = v end,
        })

        EspTab:Toggle({
            Title    = "Distance ESP",
            Desc     = "Display distance in meters",
            Value    = Cfg.ESP_Distance,
            Callback = function(v) Cfg.ESP_Distance = v end,
        })

        -- Tab 4: Settings
        local SettingTab = Window:Tab({ Title = "Settings", Icon = "settings" })

        SettingTab:Keybind({
            Title    = "Toggle Menu Key",
            Desc     = "Key to show/hide this interface (default: RightShift)",
            Value    = Enum.KeyCode.RightShift,
            Callback = function(k)
                if Window and Window.SetToggleKey then
                    Window:SetToggleKey(k)
                end
            end,
        })

        SettingTab:Button({
            Title    = "Unload Script",
            Desc     = "Cleanly destroys all hooks, drawings and GUI",
            Callback = function()
                if getgenv().EsaWT_Cleanup then
                    getgenv().EsaWT_Cleanup()
                end
            end,
        })

        WindUI:Notify({
            Title   = "Warfare Tycoon Loaded",
            Content = "Press [RightShift] or click [⚔️ MENU] to toggle.",
            Duration = 4
        })
    end
end)

-- [GLOBAL SHORTCUT KEYBINDS & MENU TOGGLE]
addConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightControl then
        if activeWindow then
            pcall(function() activeWindow:Toggle() end)
        end
    elseif input.KeyCode == Enum.KeyCode.P then
        Cfg.SilentAim = not Cfg.SilentAim
        warn("[WarfareTycoon] Silent Aim: " .. tostring(Cfg.SilentAim))
    elseif input.KeyCode == Enum.KeyCode.L then
        Cfg.Wallbang = not Cfg.Wallbang
        warn("[WarfareTycoon] Wallbang: " .. tostring(Cfg.Wallbang))
    elseif input.KeyCode == Enum.KeyCode.O then
        Cfg.ESP_Enabled = not Cfg.ESP_Enabled
        warn("[WarfareTycoon] ESP Enabled: " .. tostring(Cfg.ESP_Enabled))
    end
end))

-- [CHARACTER RESPAWN HOOK]
addConn(LP.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    scanAndPatchInventory()
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        addConn(bp.ChildAdded:Connect(function(child)
            task.wait(0.1)
            patchWeaponSettings(child)
        end))
    end
end))

warn(string.format("[WarfareTycoon] Revision %d loaded successfully with Floating Toggle!", REV))
