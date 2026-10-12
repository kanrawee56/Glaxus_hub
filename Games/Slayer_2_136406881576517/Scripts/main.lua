-- ============================================================================
-- Map: Slayer_2 (Ouwland, PlaceId 136406881576517)
-- File: Games/Slayer_2_136406881576517/Scripts/main.lua
-- Type: Single-file | Status: Ready to run (Real executor)
-- Tabs: [Parry] [Farm] [Bring] [Weapon] [Quest] [Travel] [Events]
-- อิงของจริง:
--   Blocking = สกิลปุ่ม F / Attempt_Hold("Blocking") (ClanSkills, Skill_Controller)
--   Perfect / PerfectNpc = child ใน Blocking (Checker docId 542)
--   Combat: SignalEvent.ToServer("Combat_Service", style, combo, isRun, delay, jump, swing)
--   Warp: SequenceTeleport.Start({Destination}) (OuwigaharaMapTeleport docId 57)
--   Foxfire: prompt "Take it/Lantern" -> ToServer("FoxfireTake") (docId 97)
--   Quest: ToServer("AddQuest", questName) (Dialogue/AddQuest), 92 quests ใน Quests.Holder
--   Mobs: Workspace.Humanoids.Regions.<Region>/ActiveNpcs (shallow scan only)
-- กันแลค: สแกนตื้นเป็นรอบ, tween ตัวเดียว, Bring จำกัดจำนวน, Foxfire แบบ event
-- ============================================================================

-- ============================== CONFIG =====================================
local CONFIG = {
    PLACE_ID = 136406881576517,
    -- Parry
    MinHoldTime = 0.35,
    ReleaseGap = 0.05,
    EnemyRange = 30,
    ScanInterval = 0.3,
    -- Farm
    FarmRange = 80,
    FarmHeight = 7,
    TweenSpeed = 120,
    MoveMode = "Tween",
    Noclip = true,
    AttackDelay = 0.1,
    HitRange = 12,
    TargetMob = "Nearest",
    AutoProgress = false,
    -- Bring
    BringRadius = 40,
    BringMax = 8,
    BringInterval = 0.5,
    StyleFallback = "Combat",
}

local REGIONS = {
    "Windy Peak", "Iceveil Valley", "Hidden Mist Village", "Butterfly Estate",
    "Bamboo Grove", "Misc", "Final Selection Plains", "Stone Sanctuary",
    "Forgotten Ruins", "Mistfall Harbor", "Verdant Cliffs", "Temporary",
}

-- เส้นทางฟาร์มตามเลเวล: อ่อน -> เก่ง (ใช้กับ Auto Progress)
local ROUTE = { "Windy Peak", "Bamboo Grove", "Butterfly Estate", "Mistfall Harbor", "Iceveil Valley", "Temporary" }

local KNOWN_MOBS = {
    "Nearest",
    "Bandit", "Civilian", "Zuko",
    "Kaiden", "Kaiden Subordinate", "Hoyuzo", "Hoyuzo Subordinate", "Bear Cub", "Mother Bear",
    "Lesser Demon", "Greater Demon",
    "Mizunoto", "Beast Born Demon", "Blood Hounded Demon",
    "Ice Profound Demon", "Fire Profound Demon", "High Demon", "Kanoe Demon Slayer",
    "Mizunoe Demon Slayer", "Fujiko",
    "Cache Lancer", "Lancer Captain", "Yeti Demon", "Raid Captain", "Grove Raider", "Prowler Captain", "Cache Prowler",
    "Wind Trainee", "Insect Trainee", "Water Trainee Sabito", "Sound Trainee", "Stone Trainee",
    "Thunder Trainee", "Flame Trainee", "Serpent Trainee", "Tai Chi Trainee Suzume",
    "Enru", "Shinora", "Reaper", "Sumari", "Akazo", "Domae", "Nezura", "Yahari",
    "Datai", "Giyen", "Gyorei", "Rengu", "Reaper Trainee Kuzan", "Gyutai", "Tengai",
    "Zentaro", "Soryu Trainee Goki", "Saneri", "Obari", "PhaiYaRaCH",
}

-- ============================== STATE ======================================
getgenv().SL2_AP = getgenv().SL2_AP or { running = false, farming = false, foxfire = false, bringing = false }
local S = getgenv().SL2_AP

-- ============================== HELPERS ====================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunSvc = game:GetService("RunService")
local TweenSvc = game:GetService("TweenService")
local LP = Players.LocalPlayer

local SkillController = nil
pcall(function()
    SkillController = require(RS.CAM.Client.Controllers.Skill_Controller)
end)

local CombatSignal = nil
pcall(function()
    CombatSignal = require(RS.Communication.ServerAndClient.Signals.SignalEvent)
end)

local SeqTeleport = nil
pcall(function()
    SeqTeleport = require(RS.CAM.Client.Modules.SequenceTeleport)
end)

local QuestsMod = nil
pcall(function()
    QuestsMod = require(RS.CAM.Global.Subsets.Gameplay.Quests)
end)

local function getChar()
    return LP.Character
end

local function getHRP()
    local c = LP.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

-- มอนในแมพนี้เป็น Folder หุ้ม Model ตัวจริง (เช่น Folder/Bandit -> Model/Bandit)
local function mobRig(m)
    if not m then return nil end
    if m:IsA("Model") then return m end
    if m:IsA("Folder") then
        local rig = m:FindFirstChildOfClass("Model")
        if rig then return rig end
        for _, c in ipairs(m:GetChildren()) do
            if c:IsA("Model") then return c end
        end
    end
    return nil
end

local function mobCF(m)
    local rig = mobRig(m)
    if not rig then return nil end
    local ok, cf = pcall(function() return rig:GetPivot() end)
    return ok and cf or nil
end

local function isMob(m)
    if not (m:IsA("Model") or m:IsA("Folder")) then return false end
    if Players:GetPlayerFromCharacter(m) ~= nil then return false end
    return mobRig(m) ~= nil
end

local function getData()
    local ok, util = pcall(function()
        return require(RS.CAM.Global.Utility)
    end)
    if not ok or not util.GetData then return nil end
    local ok2, d = pcall(util.GetData, LP)
    return ok2 and d or nil
end

-- ---------- Parry helpers ----------
local function blockingFolder(char)
    if not char then return nil end
    return char:FindFirstChild("Blocking")
end

local function hasPerfect(char)
    local b = blockingFolder(char)
    if not b then return false, false end
    return b:FindFirstChild("Perfect") ~= nil, b:FindFirstChild("PerfectNpc") ~= nil
end

local function isBlocking(char)
    return blockingFolder(char) ~= nil
end

local function holdBlock()
    if not SkillController or not SkillController.Attempt_Hold then return false end
    local ok = pcall(function()
        SkillController.Attempt_Hold("Blocking")
    end)
    return ok
end

local function releaseBlock()
    if not SkillController or not SkillController.StopHold then return false end
    pcall(function()
        SkillController.StopHold("Blocking")
    end)
    return true
end

local function enemyNear(hrpPos)
    local regions = workspace:FindFirstChild("Humanoids")
    if regions then regions = regions:FindFirstChild("Regions") end
    if regions then
        for _, region in ipairs(regions:GetChildren()) do
            local active = region:FindFirstChild("ActiveNpcs")
            if active then
                for _, m in ipairs(active:GetChildren()) do
                    if isMob(m) then
                        local cf = mobCF(m)
                        if cf and (cf.Position - hrpPos).Magnitude <= CONFIG.EnemyRange then
                            return true
                        end
                    end
                end
            end
            task.wait()
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - hrpPos).Magnitude <= CONFIG.EnemyRange then
                return true
            end
        end
    end
    return false
end

-- ---------- Farm helpers ----------
local function getStyle()
    local ok, style = pcall(function()
        local data = LP:FindFirstChild("Data") or LP:FindFirstChild("Powers")
        if data then
            local fs = data:FindFirstChild("FightingStyle", true)
            if fs and fs.Value and fs.Value ~= "" then return fs.Value end
        end
        local util = require(RS.CAM.Global.Utility)
        local d = util.GetData and util.GetData(LP)
        if d and d.Powers and d.Powers.FightingStyle then
            return d.Powers.FightingStyle.Value
        end
        return nil
    end)
    if ok and style and style ~= "" then return style end
    return CONFIG.StyleFallback
end

local function mobMatch(m)
    if CONFIG.TargetMob == "Nearest" or not CONFIG.TargetMob then return true end
    return m.Name == CONFIG.TargetMob
end

local function findNearestMob(hrpPos, maxRange)
    local regions = workspace:FindFirstChild("Humanoids")
    if regions then regions = regions:FindFirstChild("Regions") end
    if not regions then return nil end
    local best, bestD = nil, maxRange or math.huge
    for _, region in ipairs(regions:GetChildren()) do
        local active = region:FindFirstChild("ActiveNpcs")
        if active then
            for _, m in ipairs(active:GetChildren()) do
                if isMob(m) and mobMatch(m) then
                    local cf = mobCF(m)
                    if cf then
                        local d = (cf.Position - hrpPos).Magnitude
                        if d < bestD then bestD, best = d, m end
                    end
                end
            end
        end
        task.wait()
    end
    return best, bestD
end

local function eachMobInRadius(hrpPos, radius, limit, fn)
    local regions = workspace:FindFirstChild("Humanoids")
    if regions then regions = regions:FindFirstChild("Regions") end
    if not regions then return 0 end
    local count = 0
    for _, region in ipairs(regions:GetChildren()) do
        local active = region:FindFirstChild("ActiveNpcs")
        if active then
            for _, m in ipairs(active:GetChildren()) do
                if count >= (limit or 8) then return count end
                if isMob(m) then
                    local cf = mobCF(m)
                    if cf and (cf.Position - hrpPos).Magnitude <= radius then
                        count = count + 1
                        pcall(fn, m, cf)
                    end
                end
            end
        end
        task.wait()
    end
    return count
end

local activeTween = nil
local function cancelTween()
    if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
end

local function moveAbove(char, hrp, targetCF)
    -- หันหน้าเข้าหามอนเสมอ (hitbox เกมเช็คทิศทางตัวละคร)
    local destPos = targetCF.Position + Vector3.new(2, CONFIG.FarmHeight, 2)
    local dest = CFrame.lookAt(destPos, targetCF.Position)
    if CONFIG.MoveMode == "Snap" then
        cancelTween()
        pcall(function() char:PivotTo(dest) end)
        return
    end
    local dist = (destPos - hrp.Position).Magnitude
    if dist < 2 then
        cancelTween()
        -- ถึงแล้วแต่ยังไม่หันหน้า: หมุนอยู่กับที่
        pcall(function()
            char:PivotTo(CFrame.lookAt(hrp.Position, targetCF.Position))
        end)
        return
    end
    cancelTween()
    local ok, tw = pcall(function()
        return TweenSvc:Create(hrp, TweenInfo.new(dist / CONFIG.TweenSpeed, Enum.EasingStyle.Linear), { CFrame = dest })
    end)
    if ok and tw then
        activeTween = tw
        pcall(function() tw:Play() end)
    else
        pcall(function() char:PivotTo(dest) end)
    end
end

-- ---------- Weapon helpers ----------
local function listTools()
    local out, seen = {}, {}
    local function add(t)
        if t:IsA("Tool") and not seen[t.Name] then
            seen[t.Name] = true
            table.insert(out, t.Name)
        end
    end
    pcall(function()
        for _, t in ipairs(LP.Backpack:GetChildren()) do add(t) end
    end)
    local char = getChar()
    if char then
        pcall(function()
            for _, t in ipairs(char:GetChildren()) do add(t) end
        end)
    end
    return out
end

local function equipTool(name)
    if not name then return false end
    local char = getChar()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local tool = LP.Backpack:FindFirstChild(name) or (char and char:FindFirstChild(name))
    if tool and tool:IsA("Tool") then
        pcall(function() hum:EquipTool(tool) end)
        return true
    end
    return false
end

local function unequipAll()
    local char = getChar()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

-- ---------- Quest helpers ----------
local function listQuests()
    if not QuestsMod or not QuestsMod.Holder then return {} end
    local out = {}
    pcall(function()
        for k, _ in pairs(QuestsMod.Holder) do
            table.insert(out, k)
        end
    end)
    table.sort(out)
    return out
end

local function activeQuestInfo()
    local d = getData()
    if not d then return nil end
    local holder = d:FindFirstChild("Quests") and d.Quests:FindFirstChild("Holder")
    if not holder then return nil end
    for _, q in ipairs(holder:GetChildren()) do
        local parts = { q.Name }
        for _, task in ipairs(q:GetChildren()) do
            local v = task:FindFirstChild("Value")
            local mx = task:FindFirstChild("Max")
            if v and mx then
                table.insert(parts, task.Name .. " " .. tostring(v.Value) .. "/" .. tostring(mx.Value))
            end
        end
        return table.concat(parts, " | ")
    end
    return nil
end

local function acceptQuest(name)
    if not CombatSignal or not CombatSignal.ToServer or not name then return false end
    local ok = pcall(function()
        CombatSignal.ToServer("AddQuest", name)
    end)
    return ok
end

-- ---------- Travel helpers ----------
local function regionSpawn(regionName)
    local regions = workspace:FindFirstChild("Humanoids")
    local reg = regions and regions:FindFirstChild("Regions") and regions.Regions:FindFirstChild(regionName)
    if reg then
        local active = reg:FindFirstChild("ActiveNpcs")
        if active then
            for _, m in ipairs(active:GetChildren()) do
                if isMob(m) then
                    local cf = mobCF(m)
                    if cf then return cf + Vector3.new(0, 3, 0) end
                end
            end
        end
    end
    local mapReg = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Regions")
    local mr = mapReg and mapReg:FindFirstChild(regionName)
    if mr then
        local ok, cf = pcall(function() return mr:GetPivot() end)
        if ok and cf then return cf + Vector3.new(0, 5, 0) end
    end
    return nil
end

local function warpTo(cf)
    if not SeqTeleport or not SeqTeleport.Start then return false end
    local ok = pcall(function()
        SeqTeleport.Start({ FallLength = 1, TeleportAtFall = 0.5, RiseLength = 1, Destination = cf })
    end)
    return ok
end

-- ---------- Foxfire helpers ----------
local function takeLantern(prompt)
    local char = getChar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local adornee = prompt and (prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.Parent or nil)
    if not hrp or not adornee then return end
    pcall(function()
        char:PivotTo(CFrame.new(adornee.Position + Vector3.new(0, 3, 3)))
    end)
    task.wait(0.3)
    if typeof(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    end
end

-- ============================== MAIN LOGIC =================================
local function setRunning(on)
    if on and S.running then return end
    S.running = on
    if on then task.spawn(function()
        local lastScan, danger, holdSince = 0, false, 0
        while S.running do
            local char = getChar()
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then
                task.wait(0.5)
                continue
            end
            if os.clock() - lastScan > CONFIG.ScanInterval then
                danger = enemyNear(hrp.Position)
                lastScan = os.clock()
            end
            if not danger then
                if isBlocking(char) then releaseBlock() end
                task.wait(CONFIG.ScanInterval)
                continue
            end
            if not isBlocking(char) then
                holdBlock()
                holdSince = os.clock()
            end
            local hasP, hasPN = hasPerfect(char)
            if not hasP and not hasPN and (os.clock() - holdSince) >= CONFIG.MinHoldTime then
                releaseBlock()
                task.wait(CONFIG.ReleaseGap)
                holdBlock()
                holdSince = os.clock()
            else
                task.wait(0.05)
            end
        end
        pcall(function()
            local c = getChar()
            if c and c:FindFirstChild("Blocking") then releaseBlock() end
        end)
    end) end
end

local farmCombo = 0
local farmStyle = nil
local farmTarget = nil
local routeIdx = 1

local function setFarming(on)
    if on and S.farming then return end
    S.farming = on
    if on then
        farmStyle = getStyle()
        task.spawn(function()
            local lastRetarget, missCount = 0, 0
            while S.farming do
                local hrp = getHRP()
                local char = getChar()
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then
                    task.wait(0.5)
                    continue
                end
                if (not farmTarget or not farmTarget.Parent) or (os.clock() - lastRetarget > 1.5) then
                    farmTarget = findNearestMob(hrp.Position, CONFIG.FarmRange)
                    lastRetarget = os.clock()
                    if not farmTarget then
                        missCount = missCount + 1
                        -- Auto Progress: หาไม่เจอหลายรอบ -> วาร์ป region ถัดไปตามเลเวล
                        if CONFIG.AutoProgress and missCount >= 4 then
                            missCount = 0
                            routeIdx = (routeIdx % #ROUTE) + 1
                            local cf = regionSpawn(ROUTE[routeIdx])
                            if cf then warpTo(cf) end
                            task.wait(2)
                        else
                            task.wait(0.5)
                        end
                        continue
                    end
                    missCount = 0
                end
                local cf = mobCF(farmTarget)
                if not cf then
                    farmTarget = nil
                    continue
                end
                moveAbove(char, hrp, cf)
                -- ยิงเฉพาะตอนอยู่ในระยะจริง (ไกลไปเซิร์ฟเมิน = ดาเมจหาย)
                if (cf.Position - hrp.Position).Magnitude > CONFIG.HitRange then
                    RunSvc.Heartbeat:Wait()
                    continue
                end
                -- ย้ำทิศทางก่อนยิงทุกฮิต
                pcall(function()
                    char:PivotTo(CFrame.lookAt(hrp.Position, cf.Position))
                end)
                farmCombo = (farmCombo % 5) + 1
                if CombatSignal and CombatSignal.ToServer then
                    pcall(function()
                        CombatSignal.ToServer("Combat_Service", farmStyle, farmCombo, false, 0, false, nil)
                    end)
                end
                if CONFIG.AttackDelay > 0 then
                    task.wait(CONFIG.AttackDelay)
                else
                    RunSvc.Heartbeat:Wait()
                end
            end
            cancelTween()
            farmTarget = nil
        end)
    else
        farmTarget = nil
        cancelTween()
    end
end

local function setBringing(on)
    if on and S.bringing then return end
    S.bringing = on
    if on then task.spawn(function()
        while S.bringing do
            local hrp = getHRP()
            local char = getChar()
            if hrp and char then
                local feetCF = hrp.CFrame * CFrame.new(0, -2, 0)
                eachMobInRadius(hrp.Position, CONFIG.BringRadius, CONFIG.BringMax, function(m)
                    if m ~= farmTarget then
                        local rig = mobRig(m)
                        if rig then
                            pcall(function()
                                rig:PivotTo(feetCF * CFrame.new(math.random(-4, 4), 0, math.random(-4, 4)))
                            end)
                        end
                    end
                end)
            end
            task.wait(CONFIG.BringInterval)
        end
    end) end
end

RunSvc.Stepped:Connect(function()
    if S.farming and CONFIG.Noclip then
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

if not getgenv().SL2_FFHOOK then
    getgenv().SL2_FFHOOK = true
    pcall(function()
        workspace.DescendantAdded:Connect(function(v)
            if not S.foxfire then return end
            if v:IsA("ProximityPrompt") and v.ObjectText == "Lantern" then
                task.spawn(function()
                    takeLantern(v)
                end)
            end
        end)
    end)
end

-- ============================== GUI (WindUI) ================================
local ok, err = pcall(function()
    if game.PlaceId ~= CONFIG.PLACE_ID then
        warn("[Slayer_2] PlaceId mismatch:", game.PlaceId)
        return
    end
    if not SkillController or not SkillController.Attempt_Hold then
        warn("[Slayer_2] Skill_Controller require ไม่ได้")
        return
    end

    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

    local Window = WindUI:CreateWindow({
        Title = "Slayer_2",
        Author = "Parry + Farm + Quest",
        Folder = "Slayer2",
        Size = UDim2.fromOffset(480, 400),
        Theme = "Dark",
        ToggleKey = Enum.KeyCode.RightShift,
    })

    -- Tab 1: Parry
    local ParryTab = Window:Tab({ Title = "Parry", Icon = "shield" })

    ParryTab:Toggle({
        Title = "Auto Parry",
        Desc = "รีเฟรช Perfect window อัตโนมัติเมื่อมีศัตรูใกล้",
        Value = false,
        Callback = function(state)
            setRunning(state)
            WindUI:Notify({
                Title = "Slayer_2",
                Content = state and "AutoParry ON" or "AutoParry OFF",
                Duration = 2,
            })
        end,
    })

    ParryTab:Slider({
        Title = "Enemy Range",
        Value = { Min = 10, Max = 60, Default = CONFIG.EnemyRange },
        Step = 1,
        Callback = function(v) CONFIG.EnemyRange = v end,
    })

    ParryTab:Slider({
        Title = "Min Hold Time",
        Value = { Min = 10, Max = 100, Default = math.floor(CONFIG.MinHoldTime * 100) },
        Step = 1,
        Callback = function(v) CONFIG.MinHoldTime = v / 100 end,
    })

    -- Tab 2: Farm
    local FarmTab = Window:Tab({ Title = "Farm", Icon = "swords" })

    local farmToggle = FarmTab:Toggle({
        Title = "Auto Farm",
        Desc = "tween ไปบนหัวมอน + หันหน้า + ตีลงใต้ตีน",
        Value = false,
        Callback = function(state)
            setFarming(state)
            WindUI:Notify({
                Title = "Slayer_2",
                Content = state and ("AutoFarm ON | " .. tostring(CONFIG.TargetMob) .. " | " .. tostring(farmStyle or getStyle())) or "AutoFarm OFF",
                Duration = 2,
            })
        end,
    })

    FarmTab:Dropdown({
        Title = "Target Mob",
        Desc = "เลือกมอนที่จะฟาร์ม (Nearest = ตัวใกล้สุด)",
        Values = KNOWN_MOBS,
        Value = CONFIG.TargetMob,
        SearchBarEnabled = true,
        Callback = function(v)
            CONFIG.TargetMob = v
            farmTarget = nil
        end,
    })

    FarmTab:Toggle({
        Title = "Auto Progress",
        Desc = "ฟาร์มเลเวล: หมดแมพแล้ววาร์ป region ถัดไปเอง (อ่อน->เก่ง)",
        Value = false,
        Callback = function(state)
            CONFIG.AutoProgress = state
            WindUI:Notify({
                Title = "Slayer_2",
                Content = state and "AutoProgress ON" or "AutoProgress OFF",
                Duration = 2,
            })
        end,
    })

    FarmTab:Dropdown({
        Title = "Move Mode",
        Values = { "Tween", "Snap" },
        Value = CONFIG.MoveMode,
        Callback = function(v) CONFIG.MoveMode = v end,
    })

    FarmTab:Toggle({
        Title = "Noclip",
        Desc = "ทะลุกำแพงตอนฟาร์ม",
        Value = CONFIG.Noclip,
        Callback = function(state) CONFIG.Noclip = state end,
    })

    FarmTab:Slider({
        Title = "Farm Range",
        Desc = "ระยะหามอน (เมตร)",
        Value = { Min = 20, Max = 200, Default = CONFIG.FarmRange },
        Step = 5,
        Callback = function(v) CONFIG.FarmRange = v end,
    })

    FarmTab:Slider({
        Title = "Hover Height",
        Desc = "ลอยเหนือหัวมอนกี่เมตร",
        Value = { Min = 3, Max = 12, Default = CONFIG.FarmHeight },
        Step = 1,
        Callback = function(v) CONFIG.FarmHeight = v end,
    })

    FarmTab:Slider({
        Title = "Tween Speed",
        Desc = "ความเร็วบิน (studs/sec)",
        Value = { Min = 40, Max = 300, Default = CONFIG.TweenSpeed },
        Step = 10,
        Callback = function(v) CONFIG.TweenSpeed = v end,
    })

    FarmTab:Slider({
        Title = "Hit Range",
        Desc = "ใกล้แค่ไหนถึงยิง (ไกลไปเซิร์ฟเมิน)",
        Value = { Min = 6, Max = 25, Default = CONFIG.HitRange },
        Step = 1,
        Callback = function(v) CONFIG.HitRange = v end,
    })

    FarmTab:Slider({
        Title = "Attack Delay",
        Desc = "ดีเลย์ระหว่างฮิต (ยิงถี่ไปเซิร์ฟเมิน)",
        Value = { Min = 0, Max = 50, Default = math.floor(CONFIG.AttackDelay * 100) },
        Step = 5,
        Callback = function(v) CONFIG.AttackDelay = v / 100 end,
    })

    -- Tab 3: Bring
    local BringTab = Window:Tab({ Title = "Bring", Icon = "magnet" })

    BringTab:Toggle({
        Title = "Bring Mobs",
        Desc = "ดึงมอนรอบตัวมาใต้ตีนแล้วรุมตี",
        Value = false,
        Callback = function(state)
            setBringing(state)
            WindUI:Notify({
                Title = "Slayer_2",
                Content = state and "Bring ON" or "Bring OFF",
                Duration = 2,
            })
        end,
    })

    BringTab:Slider({
        Title = "Bring Radius",
        Desc = "ระยะดึง (เมตร)",
        Value = { Min = 10, Max = 100, Default = CONFIG.BringRadius },
        Step = 5,
        Callback = function(v) CONFIG.BringRadius = v end,
    })

    BringTab:Slider({
        Title = "Bring Max",
        Desc = "ดึงทีละไม่เกินกี่ตัว (กันแลค)",
        Value = { Min = 2, Max = 20, Default = CONFIG.BringMax },
        Step = 1,
        Callback = function(v) CONFIG.BringMax = v end,
    })

    -- Tab 4: Weapon
    local WeaponTab = Window:Tab({ Title = "Weapon", Icon = "axe" })
    local pickedTool = nil
    local toolDropdown = nil

    WeaponTab:Dropdown({
        Title = "Weapon",
        Desc = "เลือกอาวุธจากกระเป๋า (ไม่มี = ใช้สไตล์หมัด)",
        Values = { "(empty)" },
        Value = "(empty)",
        Callback = function(v) pickedTool = (v ~= "(empty)") and v or nil end,
    })

    WeaponTab:Button({
        Title = "Refresh Weapons",
        Desc = "สแกนอาวุธในกระเป๋าใหม่",
        Callback = function()
            local tools = listTools()
            pickedTool = nil
            local msg = #tools > 0 and ("Found: " .. table.concat(tools, ", ")) or "ไม่มีอาวุธ (ใช้สไตล์หมัด)"
            WindUI:Notify({ Title = "Slayer_2", Content = msg, Duration = 3 })
        end,
    })

    WeaponTab:Button({
        Title = "Equip Selected",
        Desc = "ถืออาวุธที่เลือก",
        Callback = function()
            if pickedTool and equipTool(pickedTool) then
                farmStyle = getStyle()
                WindUI:Notify({ Title = "Slayer_2", Content = "Equipped: " .. tostring(pickedTool), Duration = 2 })
            else
                WindUI:Notify({ Title = "Slayer_2", Content = "ถือไม่ได้ / ยังไม่เลือก", Duration = 2 })
            end
        end,
    })

    WeaponTab:Button({
        Title = "Unequip (Fists)",
        Desc = "เก็บอาวุธ กลับไปใช้สไตล์หมัด",
        Callback = function()
            unequipAll()
            farmStyle = getStyle()
            WindUI:Notify({ Title = "Slayer_2", Content = "Unequipped", Duration = 2 })
        end,
    })

    -- Tab 5: Quest
    local QuestTab = Window:Tab({ Title = "Quest", Icon = "scroll" })
    local pickedQuest = nil
    local questList = listQuests()

    QuestTab:Dropdown({
        Title = "Quest",
        Desc = "เลือกเควส (มี " .. tostring(#questList) .. " เควส, พิมพ์ค้นได้)",
        Values = (#questList > 0) and questList or { "(none)" },
        SearchBarEnabled = true,
        Callback = function(v) pickedQuest = v end,
    })

    QuestTab:Button({
        Title = "Accept Quest",
        Desc = "รับเควสที่เลือก (ทีละ 1 เควส)",
        Callback = function()
            if pickedQuest and pickedQuest ~= "(none)" and acceptQuest(pickedQuest) then
                WindUI:Notify({ Title = "Slayer_2", Content = "Accepted: " .. tostring(pickedQuest), Duration = 2 })
            else
                WindUI:Notify({ Title = "Slayer_2", Content = "รับไม่ได้ / ยังไม่เลือก", Duration = 2 })
            end
        end,
    })

    QuestTab:Button({
        Title = "Check Progress",
        Desc = "ดูเควสที่รับอยู่ + ความคืบหน้า",
        Callback = function()
            local info = activeQuestInfo()
            WindUI:Notify({
                Title = "Slayer_2",
                Content = info or "ไม่มีเควสที่รับอยู่",
                Duration = 4,
            })
        end,
    })

    QuestTab:Button({
        Title = "Farm This Quest",
        Desc = "ตั้งเป้า + วาร์ปไปหามอน + เปิดฟาร์มให้เลย",
        Callback = function()
            if not (pickedQuest and string.find(pickedQuest, "^Eliminate ")) then
                WindUI:Notify({ Title = "Slayer_2", Content = "เลือกเควส Eliminate ก่อน", Duration = 2 })
                return
            end
            local mob = string.gsub(pickedQuest, "^Eliminate ", "")
            CONFIG.TargetMob = mob
            farmTarget = nil
            -- วาร์ปไปหามอนตัวแรกที่ชื่อตรง (ค้นทั้งแมพ ไม่จำกัดระยะ)
            local hrp = getHRP()
            if hrp then
                local found = findNearestMob(hrp.Position, 5000)
                -- findNearestMob กรองตาม TargetMob อยู่แล้ว
                if found then
                    local cf = mobCF(found)
                    if cf and warpTo(cf + Vector3.new(0, 3, 0)) then
                        WindUI:Notify({ Title = "Slayer_2", Content = "Warp->" .. mob .. " + Farm ON", Duration = 2 })
                    end
                else
                    WindUI:Notify({ Title = "Slayer_2", Content = mob .. " ยังไม่เกิด รอแล้วฟาร์มให้", Duration = 3 })
                end
            end
            -- เปิดฟาร์มให้เอง + ซิงก์ปุ่ม (ปิดเองได้ถ้าจะฟาร์มมือ)
            if farmToggle and farmToggle.Set then
                pcall(function() farmToggle:Set(true) end)
            end
            setFarming(true)
        end,
    })

    -- Tab 6: Travel
    local TravelTab = Window:Tab({ Title = "Travel", Icon = "map" })
    local pickedRegion = REGIONS[1]

    TravelTab:Dropdown({
        Title = "Region",
        Values = REGIONS,
        Value = pickedRegion,
        Callback = function(v) pickedRegion = v end,
    })

    TravelTab:Button({
        Title = "Teleport",
        Desc = "วาร์ปไป region ที่เลือก (ผ่าน SequenceTeleport ของเกม)",
        Callback = function()
            local cf = regionSpawn(pickedRegion)
            if cf and warpTo(cf) then
                WindUI:Notify({ Title = "Slayer_2", Content = "Warp: " .. tostring(pickedRegion), Duration = 2 })
            else
                WindUI:Notify({ Title = "Slayer_2", Content = tostring(pickedRegion) .. " ว่าง/วาร์ปไม่ได้", Duration = 2 })
            end
        end,
    })

    -- Tab 7: Events
    local EventTab = Window:Tab({ Title = "Events", Icon = "sparkles" })

    EventTab:Toggle({
        Title = "Auto Foxfire",
        Desc = "เจอตะเกียง Foxfire วาร์ปไปเก็บให้เอง",
        Value = false,
        Callback = function(state)
            S.foxfire = state
            WindUI:Notify({
                Title = "Slayer_2",
                Content = state and "AutoFoxfire ON" or "AutoFoxfire OFF",
                Duration = 2,
            })
        end,
    })

    print("[Slayer_2] GUI loaded (Parry + Farm + Bring + Weapon + Quest + Travel + Events)")
end)

if not ok then
    warn("[Slayer_2 Error]", err)
end
