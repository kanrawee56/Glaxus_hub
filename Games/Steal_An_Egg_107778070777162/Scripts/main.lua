-- ============================================================================
-- Map: Steal An Egg (PlaceId 107778070777162, Universe 10563114921)
-- File: Games/Steal_An_Egg_107778070777162/Scripts/main.lua
-- Type: Single-file | Status: Ready to run (Real executor)
-- Tabs: [Egg] [Pets] [Train] [TP] [Events] [Player]
-- อิงของจริงในเกม:
--   Remotes ศูนย์กลาง = ReplicatedStorage.Packages.Networking (RE/ + RF/)
--   นิยามชื่อ = ReplicatedStorage.Shared.Remotes (EggWorld.AskHatch etc.)
--   วิธีเรียกจริง = EggState.BeginHatch(uid) -> EggWorld.AskHatch:InvokeServer(uid)
--     FinishHatch(uid) -> AskFinishHatch:InvokeServer(uid)
--     SkipGrowth(uid) -> AskSkipGrowth:InvokeServer(uid)
--   BeanstalkEvent.AskStealEgg:FireServer() (ไม่มี args)
--   Plots = Workspace.Plots.1..7 (PlotUpgrade, TreadmillUpgrade, SpawnPoint,
--     CenterPoint, TreadmillBottom, PlotSign, ToUpdate)
--   HUD = PlayerGui.HUD.GameHUD.BottomLeft (Money.Value, Speed.Value)
-- กันพัง: execute-guard ฆ่าลูปเก่าก่อน (กัน remote spam x2 -> 267),
--   parse uid ตาม shape จริง (Owned=[{OwnerUserId,Records}], Field={Records,ServerTime}),
--   Carry ส่ง {Uid=uid} (ห้าม raw string), Hatch เฉพาะใบพร้อม (IsReadyToHatch),
--   ไม่ตั้ง WalkSpeed ตอนโหลด, WindUI validate content + cache, ทุกลูปมีสวิตช์หยุดได้,
--   ไม่ยิง remote ดิบถี่เกิน (0.5s/ใบ + delay slider), PlaceId ผิดเตือนแล้วหยุด
-- ============================================================================

-- ============================== CONFIG =====================================
local CONFIG = {
    PLACE_ID = 107778070777162,
    Theme = "White",
    ToggleKey = Enum.KeyCode.RightShift,
    HatchDelay = 2.0,
    CollectDelay = 3.0,
    TrainDelay = 5.0,
    EventDelay = 2.5,
    TeleportHeight = 5,
    WalkSpeed = 16,
    JumpPower = 50,
}

-- ============================== STATE ======================================
-- Execute-guard: re-execute ต้องไม่ซ้อนลูปเก่า (สาเหตุ kick 267 จาก remote spam x2)
local GEN = (getgenv().__SAE_GEN or 0) + 1
getgenv().__SAE_GEN = GEN
do
    local old = getgenv().SAE
    if old then
        pcall(function()
            old.running = false
            for _, k in ipairs({
                "autoHatch", "autoFinish", "autoPlace", "autoField",
                "autoEquipBest", "autoSell", "autoTier",
                "autoBeanstalk", "autoPickups",
            }) do
                old[k] = false
            end
        end)
        pcall(function()
            if old._stepConn then old._stepConn:Disconnect() end
        end)
        pcall(function()
            if old._afkConn then old._afkConn:Disconnect() end
        end)
    end
end
task.wait(0.3) -- ปล่อยให้ลูปเก่าหลุดก่อน
getgenv().SAE = {
    running = true,
    gen = GEN,
    autoHatch = false,
    autoFinish = false,
    autoPlace = false,
    autoField = false,
    autoEquipBest = false,
    autoSell = false,
    autoTier = false,
    autoBeanstalk = false,
    autoPickups = false,
    noclip = false,
    antiAfk = true,
    _stepConn = nil,
    _afkConn = nil,
}
local S = getgenv().SAE
local MY_GEN = GEN

-- ============================== SERVICES ===================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunSvc = game:GetService("RunService")
local LP = Players.LocalPlayer

local function getChar()
    return LP and LP.Character or nil
end

local function getHRP()
    local c = getChar()
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    if not c then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end

local function notify(WindUI, title, msg)
    pcall(function()
        WindUI:Notify({ Title = title, Content = msg, Duration = 2 })
    end)
end

-- ============================== REMOTES ====================================
-- ชื่อ instance มี "/" ในชื่อเลย ต้องหาด้วย FindFirstChild แบบชื่อเต็ม
local NetRoot = nil
pcall(function()
    NetRoot = RS:WaitForChild("Packages", 5):WaitForChild("Networking", 5)
end)

local function findRemote(kind, suffix)
    -- kind: "RF" หรือ "RE", suffix เช่น "EggWorld/AskHatch"
    if not NetRoot then return nil end
    local full = kind .. "/" .. suffix
    local ok, inst = pcall(function()
        -- โครงสร้าง: Networking -> "RF/EggWorld/AskHatch" ตรงๆ (Name มี slash)
        local direct = NetRoot:FindFirstChild(full, true)
        if direct then return direct end
        -- fallback: ไล่ path ทีละชั้น (เผื่อบาง executor มอง slash เป็น path)
        local node = NetRoot
        for part in string.gmatch(full, "[^/]+") do
            if not node then break end
            node = node:FindFirstChild(part)
        end
        return node
    end)
    if ok then return inst end
    return nil
end

local function rf(suffix) return findRemote("RF", suffix) end
local function re(suffix) return findRemote("RE", suffix) end

local function invokeRF(suffix, ...)
    local inst = rf(suffix)
    if not inst then return false, "RF not found: " .. suffix end
    local args = { ... }
    local ok, a, b, c = pcall(function()
        return inst:InvokeServer(table.unpack(args))
    end)
    if not ok then return false, tostring(a) end
    return true, a, b, c
end

local function fireRE(suffix, ...)
    local inst = re(suffix)
    if not inst then return false, "RE not found: " .. suffix end
    local args = { ... }
    local ok, err = pcall(function()
        inst:FireServer(table.unpack(args))
    end)
    if not ok then return false, tostring(err) end
    return true
end

-- EggState module (วิธียิงที่เกมใช้จริง) — ถ้า require ได้จะใช้แทนยิงดิบ
local EggStateMod = nil
pcall(function()
    EggStateMod = require(RS.Client.EggState)
end)

local function readOwnedEggs()
    if EggStateMod and EggStateMod.ReadOwnedEggs then
        local ok, rows = pcall(EggStateMod.ReadOwnedEggs)
        if ok and rows then return rows end
    end
    return nil
end

local function readFieldEggs()
    if EggStateMod and EggStateMod.ReadFieldEggs then
        local ok, rows = pcall(EggStateMod.ReadFieldEggs)
        if ok and rows then return rows end
    end
    return nil
end

-- ดึง uid ออกจาก row (รองรับหลาย shape: string / {Uid,uid,Id,id} / {EggUid})
local function rowUid(row)
    if type(row) == "string" then return row end
    if type(row) ~= "table" then return nil end
    for _, k in ipairs({ "Uid", "uid", "UID", "Id", "id", "EggUid", "eggUid", "EggId" }) do
        local v = row[k]
        if type(v) == "string" and #v > 0 then return v end
    end
    return nil
end

-- ataจริงจาก EggState:
--   ReadOwnedEggs() -> [{OwnerUserId=number, Records={uid=data}}] (array)
--   ReadOwnerEggs(userId) -> {uid=data} (dict ของตัวเอง ใช้ตัวนี้ก่อน)
--   ReadFieldEggs() -> {Records=[{Uid=...}...], ServerTime=...} (dict)
local function eachOwnedUid(fn)
    -- ทางที่ถูกที่สุด: dict ของตัวเองโดยตรง
    if EggStateMod and EggStateMod.ReadOwnerEggs and LP then
        local ok, dict = pcall(EggStateMod.ReadOwnerEggs, LP.UserId)
        if ok and type(dict) == "table" then
            local n = 0
            for uid, _ in pairs(dict) do
                if type(uid) == "string" and #uid > 0 then
                    n = n + 1
                    pcall(fn, uid)
                end
            end
            if n > 0 then return n end
        end
    end
    local rows = readOwnedEggs()
    if type(rows) ~= "table" then return 0 end
    local n = 0
    local myId = LP and LP.UserId or nil
    for _, entry in ipairs(rows) do
        if type(entry) == "table" and type(entry.Records) == "table" then
            if myId == nil or entry.OwnerUserId == myId then
                for uid, _ in pairs(entry.Records) do
                    if type(uid) == "string" and #uid > 0 then
                        n = n + 1
                        pcall(fn, uid)
                    end
                end
            end
        else
            -- fallback shape เก่า (array ของ row ตรงๆ)
            local u = rowUid(entry)
            if u then
                n = n + 1
                pcall(fn, u, entry)
            end
        end
    end
    return n
end

local function eachFieldUid(fn)
    local rows = readFieldEggs()
    if type(rows) ~= "table" then return 0 end
    local recs = rows.Records
    if type(recs) ~= "table" then return 0 end
    local n = 0
    for _, rec in ipairs(recs) do
        local u = rowUid(rec)
        if u then
            n = n + 1
            pcall(fn, u, rec)
        end
    end
    return n
end

-- ============================== TELEPORT ===================================
local function tpTo(cf)
    local hrp = getHRP()
    if not hrp or not cf then return false end
    pcall(function()
        hrp.CFrame = cf + Vector3.new(0, CONFIG.TeleportHeight, 0)
    end)
    return true
end

local function plotNames()
    local out = {}
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, m in ipairs(plots:GetChildren()) do
            table.insert(out, m.Name)
        end
        table.sort(out)
    end
    if #out == 0 then
        out = { "1", "2", "3", "4", "5", "6", "7" }
    end
    return out
end

local function tpToPlot(name, spot)
    spot = spot or "CenterPoint"
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(tostring(name))
    if not plot then return false end
    local part = plot:FindFirstChild(spot) or plot:FindFirstChild("CenterPoint")
        or plot:FindFirstChild("SpawnPoint")
    if not part then return false end
    local cf = part:IsA("BasePart") and part.CFrame or part:GetPivot()
    return tpTo(cf)
end

-- ============================== FEATURE LOOPS ==============================
local function loopFlag(flag, delayFn, fn)
    task.spawn(function()
        while S.running and S[flag] and S.gen == MY_GEN do
            local ok, err = pcall(fn)
            if not ok then
                warn("[SAE] loop " .. flag .. " error: " .. tostring(err))
            end
            task.wait(delayFn())
        end
    end)
end

local function isReady(uid)
    if EggStateMod and EggStateMod.IsReadyToHatch then
        local ok, r = pcall(EggStateMod.IsReadyToHatch, uid)
        if ok then return r end
    end
    return true -- ไม่มี checker: ปล่อยผ่าน (กัน false negative)
end

local function startAutoHatch()
    loopFlag("autoHatch", function() return CONFIG.HatchDelay end, function()
        -- ใช้ EggState โดยตรง (contract จริง: BeginHatch(uid:string))
        local n = eachOwnedUid(function(uid)
            if not (S.autoHatch and S.gen == MY_GEN) then return end
            if not isReady(uid) then return end -- ฟักเฉพาะใบพร้อม กันยิง invalid -> 267
            if EggStateMod and EggStateMod.BeginHatch then
                pcall(EggStateMod.BeginHatch, uid)
            else
                invokeRF("EggWorld/AskHatch", uid) -- hatch รับ raw string (ถูก)
            end
            task.wait(0.5)
        end)
        if n == 0 then
            -- ไม่มี uid ที่ parse ได้: sync แทนการยิงมั่ว (กัน uid="Records")
            pcall(function()
                if EggStateMod and EggStateMod.SyncOwnedEggs then
                    EggStateMod.SyncOwnedEggs()
                else
                    invokeRF("EggWorld/AskLiveSnapshot")
                end
            end)
        end
    end)
end

local function startAutoFinish()
    loopFlag("autoFinish", function() return CONFIG.HatchDelay end, function()
        eachOwnedUid(function(uid)
            if not (S.autoFinish and S.gen == MY_GEN) then return end
            if EggStateMod and EggStateMod.FinishHatch then
                pcall(EggStateMod.FinishHatch, uid)
            else
                invokeRF("EggWorld/AskFinishHatch", uid) -- finish รับ raw string (ถูก)
            end
            task.wait(0.5)
        end)
    end)
end

local function startAutoField()
    loopFlag("autoField", function() return CONFIG.CollectDelay end, function()
        -- contract จริง: CarryFieldEgg(uid) -> AskFieldEggCarry({Uid=uid})
        -- ห้ามยิง raw string ตรงๆ (server 267)
        local n = eachFieldUid(function(uid)
            if not (S.autoField and S.gen == MY_GEN) then return end
            if EggStateMod and EggStateMod.CarryFieldEgg then
                pcall(EggStateMod.CarryFieldEgg, uid, nil)
            else
                invokeRF("EggWorld/AskFieldEggCarry", { Uid = uid })
            end
            task.wait(0.5)
        end)
        if n == 0 then
            pcall(function()
                if EggStateMod and EggStateMod.SyncFieldEggs then
                    EggStateMod.SyncFieldEggs()
                else
                    invokeRF("EggWorld/AskFieldEggSnapshot")
                end
            end)
        end
    end)
end

local function startAutoEquipBest()
    loopFlag("autoEquipBest", function() return CONFIG.TrainDelay end, function()
        invokeRF("Haul/WearBest")
    end)
end

local function startAutoSell()
    loopFlag("autoSell", function() return CONFIG.TrainDelay end, function()
        local ok = fireRE("PetSatchel/SellEveryPet")
        if not ok then
            invokeRF("Haul/OfferFullSatchelSale")
        end
    end)
end

local function startAutoTier()
    loopFlag("autoTier", function() return CONFIG.TrainDelay end, function()
        invokeRF("Treadmill/AskTierRaise")
    end)
end

local function startAutoBeanstalk()
    loopFlag("autoBeanstalk", function() return CONFIG.EventDelay end, function()
        fireRE("BeanstalkEvent/AskStealEgg")
    end)
end

local function startAutoPickups()
    loopFlag("autoPickups", function() return CONFIG.EventDelay end, function()
        fireRE("SammyEvent/AskCollectPickup")
        fireRE("LightVsDarkness/AskCollectRing")
        fireRE("LightVsDarkness/AskCollectPowerUp")
    end)
end

-- Noclip + AntiAFK (guard re-execute: ตัวเก่าถูก disconnect ไปแล้วข้างบน)
task.spawn(function()
    local conn
    conn = RunSvc.Stepped:Connect(function()
        if not S.running or S.gen ~= MY_GEN then
            pcall(function() conn:Disconnect() end)
            return
        end
        if S.noclip then
            local c = getChar()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.CanCollide = false
                    end
                end
            end
        end
    end)
    S._stepConn = conn
end)

if not S._afkConn then
    pcall(function()
        local VU = game:GetService("VirtualUser")
        S._afkConn = LP.Idled:Connect(function()
            if S.antiAfk and S.gen == MY_GEN then
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
            end
        end)
    end)
end

local function applySpeed()
    local h = getHum()
    if h then
        pcall(function()
            h.WalkSpeed = CONFIG.WalkSpeed
            h.JumpPower = CONFIG.JumpPower
        end)
    end
end

-- ============================== GUI (WindUI) ===============================
task.spawn(function()
    if game.PlaceId ~= CONFIG.PLACE_ID then
        warn("[SAE] PlaceId mismatch: " .. tostring(game.PlaceId))
        return
    end

    -- กัน HttpGet ค้าง (เคย hang 20s+ จนต้อง re-execute ซ้อนลูป -> 267):
    -- อยู่ใน task.spawn อยู่แล้ว + validate content ก่อน loadstring
    local ok, WindUI = false, nil
    if getgenv().__SAE_WindUI and type(getgenv().__SAE_WindUI) == "table" then
        WindUI = getgenv().__SAE_WindUI
        ok = true
    else
        local src = nil
        ok, src = pcall(function()
            return game:HttpGet(
                "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
            )
        end)
        if ok and type(src) == "string" and #src > 5000
            and src:sub(1, 9) ~= "<!DOCTYPE" and src:sub(1, 5) ~= "<html" then
            local f
            ok, f = pcall(loadstring, src)
            if ok and type(f) == "function" then
                local w
                ok, w = pcall(f)
                if ok and type(w) == "table" then
                    WindUI = w
                    getgenv().__SAE_WindUI = w
                else
                    ok = false
                end
            else
                ok = false
            end
        else
            ok = false
        end
    end
    if not ok or not WindUI then
        warn("[SAE] โหลด WindUI ไม่ได้ รันแบบ headless")
        return
    end

    local okWin, Window = pcall(function()
        return WindUI:CreateWindow({
            Title = "Steal An Egg",
            Author = "Egg + Pets + Train",
            Folder = "StealAnEgg",
            Size = UDim2.fromOffset(520, 440),
            ToggleKey = CONFIG.ToggleKey,
            HideSearchBar = true,
        })
    end)
    if not okWin or not Window then
        warn("[SAE] สร้าง window ไม่ได้")
        return
    end

    pcall(function()
        WindUI:AddTheme({
            Name = "White",
            Accent = Color3.fromHex("#FFFFFF"),
            Background = Color3.fromHex("#F2F2F2"),
            Outline = Color3.fromHex("#D9D9D9"),
            Text = Color3.fromHex("#18181b"),
            Placeholder = Color3.fromHex("#7a7a7a"),
            Button = Color3.fromHex("#FFFFFF"),
            Icon = Color3.fromHex("#52525b"),
        })
        WindUI:SetTheme("White")
    end)

    -- Tab: Egg
    local EggTab = Window:Tab({ Title = "Egg", Icon = "egg" })
    EggTab:Toggle({
        Title = "Auto Hatch (ไข่ในตัว)",
        Desc = "วน BeginHatch ทุกใบ",
        Value = false,
        Callback = function(v)
            S.autoHatch = v
            if v then startAutoHatch() end
            notify(WindUI, "StealAnEgg", v and "AutoHatch ON" or "AutoHatch OFF")
        end,
    })
    EggTab:Toggle({
        Title = "Auto Finish Hatch",
        Desc = "กดรับ pet หลังฟักเสร็จ",
        Value = false,
        Callback = function(v)
            S.autoFinish = v
            if v then startAutoFinish() end
            notify(WindUI, "StealAnEgg", v and "AutoFinish ON" or "AutoFinish OFF")
        end,
    })
    EggTab:Toggle({
        Title = "Auto Field Eggs",
        Desc = "เก็บไข่ในแมพ (AskFieldEggCarry)",
        Value = false,
        Callback = function(v)
            S.autoField = v
            if v then startAutoField() end
            notify(WindUI, "StealAnEgg", v and "Field ON" or "Field OFF")
        end,
    })
    EggTab:Slider({
        Title = "Hatch Delay (วิ)",
        Value = { Min = 5, Max = 100, Default = math.floor(CONFIG.HatchDelay * 10) },
        Step = 5,
        Callback = function(v) CONFIG.HatchDelay = v / 10 end,
    })
    EggTab:Button({
        Title = "Hatch ทีเดียว (ทุกใบ)",
        Callback = function()
            local n = eachOwnedUid(function(uid)
                if not isReady(uid) then return end
                if EggStateMod and EggStateMod.BeginHatch then
                    pcall(EggStateMod.BeginHatch, uid)
                else
                    invokeRF("EggWorld/AskHatch", uid)
                end
                task.wait(0.5)
            end)
            notify(WindUI, "StealAnEgg", "Hatch once: " .. n .. " ใบ")
        end,
    })
    EggTab:Button({
        Title = "Snapshot ไข่ (เช็ก uid)",
        Callback = function()
            local o = readOwnedEggs()
            local f = readFieldEggs()
            local function count(t)
                if type(t) ~= "table" then return 0 end
                if #t > 0 then return #t end
                local n = 0
                for _ in pairs(t) do n = n + 1 end
                return n
            end
            notify(WindUI, "StealAnEgg", "Owned:" .. count(o) .. " Field:" .. count(f))
        end,
    })

    -- Tab: Pets
    local PetTab = Window:Tab({ Title = "Pets", Icon = "paw-print" })
    PetTab:Toggle({
        Title = "Auto Equip Best",
        Desc = "RF/Haul/WearBest",
        Value = false,
        Callback = function(v)
            S.autoEquipBest = v
            if v then startAutoEquipBest() end
        end,
    })
    PetTab:Toggle({
        Title = "Auto Sell All",
        Desc = "RE/PetSatchel/SellEveryPet",
        Value = false,
        Callback = function(v)
            S.autoSell = v
            if v then startAutoSell() end
        end,
    })
    PetTab:Button({
        Title = "Equip Best ทีเดียว",
        Callback = function()
            invokeRF("Haul/WearBest")
            notify(WindUI, "StealAnEgg", "WearBest sent")
        end,
    })
    PetTab:Button({
        Title = "Sell All ทีเดียว",
        Callback = function()
            fireRE("PetSatchel/SellEveryPet")
            notify(WindUI, "StealAnEgg", "Sell sent")
        end,
    })

    -- Tab: Train
    local TrainTab = Window:Tab({ Title = "Train", Icon = "zap" })
    TrainTab:Toggle({
        Title = "Auto Upgrade Treadmill",
        Desc = "RF/Treadmill/AskTierRaise",
        Value = false,
        Callback = function(v)
            S.autoTier = v
            if v then startAutoTier() end
        end,
    })
    TrainTab:Button({
        Title = "วาร์ปไป Treadmill ตัวเอง (Plot 1)",
        Callback = function()
            -- ลอง plot ของตัวเองก่อน: หา plot ที่มี owner เป็นเรา (fallback plot 1)
            tpToPlot("1", "TreadmillBottom")
            notify(WindUI, "StealAnEgg", "TP Treadmill")
        end,
    })
    TrainTab:Slider({
        Title = "Train Delay (วิ)",
        Value = { Min = 20, Max = 300, Default = math.floor(CONFIG.TrainDelay * 10) },
        Step = 10,
        Callback = function(v) CONFIG.TrainDelay = v / 10 end,
    })

    -- Tab: TP
    local TPTab = Window:Tab({ Title = "TP", Icon = "map-pin" })
    local plots = plotNames()
    TPTab:Dropdown({
        Title = "Plot",
        Values = plots,
        Value = plots[1],
        Callback = function(v)
            _G.__SAE_Plot = v
        end,
    })
    TPTab:Button({
        Title = "TP Plot Center",
        Callback = function()
            tpToPlot(_G.__SAE_Plot or plots[1], "CenterPoint")
        end,
    })
    TPTab:Button({
        Title = "TP Plot Spawn",
        Callback = function()
            tpToPlot(_G.__SAE_Plot or plots[1], "SpawnPoint")
        end,
    })
    TPTab:Button({
        Title = "TP SpawnLocation กลางแมพ",
        Callback = function()
            local sp = workspace:FindFirstChild("SpawnLocation")
            if sp and sp:IsA("BasePart") then tpTo(sp.CFrame) end
        end,
    })

    -- Tab: Events
    local EvTab = Window:Tab({ Title = "Events", Icon = "gift" })
    EvTab:Toggle({
        Title = "Auto Beanstalk StealEgg",
        Desc = "RE/BeanstalkEvent/AskStealEgg",
        Value = false,
        Callback = function(v)
            S.autoBeanstalk = v
            if v then startAutoBeanstalk() end
        end,
    })
    EvTab:Toggle({
        Title = "Auto Pickups (Sammy/Rings)",
        Value = false,
        Callback = function(v)
            S.autoPickups = v
            if v then startAutoPickups() end
        end,
    })
    EvTab:Slider({
        Title = "Event Delay (วิ)",
        Value = { Min = 10, Max = 100, Default = math.floor(CONFIG.EventDelay * 10) },
        Step = 5,
        Callback = function(v) CONFIG.EventDelay = v / 10 end,
    })

    -- Tab: Player
    local PlTab = Window:Tab({ Title = "Player", Icon = "user" })
    PlTab:Slider({
        Title = "WalkSpeed",
        Value = { Min = 16, Max = 200, Default = CONFIG.WalkSpeed },
        Step = 1,
        Callback = function(v)
            CONFIG.WalkSpeed = v
            applySpeed()
        end,
    })
    PlTab:Slider({
        Title = "JumpPower",
        Value = { Min = 50, Max = 300, Default = CONFIG.JumpPower },
        Step = 5,
        Callback = function(v)
            CONFIG.JumpPower = v
            applySpeed()
        end,
    })
    PlTab:Toggle({
        Title = "Noclip",
        Value = false,
        Callback = function(v) S.noclip = v end,
    })
    PlTab:Toggle({
        Title = "Anti-AFK",
        Value = true,
        Callback = function(v) S.antiAfk = v end,
    })

    pcall(function() Window:Open() end)
    warn("[SAE] WindUI พร้อมแล้ว (RightShift เปิด/ปิด)")
end)

-- ============================== INIT =======================================
-- ห้าม applySpeed() ตอนโหลด (server ตรวจ WalkSpeed/movement -> 267)
-- ให้ user กด slider เองเท่านั้น
do
    local ok, err = pcall(function()
        if game.PlaceId ~= CONFIG.PLACE_ID then
            warn("[SAE] PlaceId mismatch: " .. tostring(game.PlaceId))
            return
        end
        warn("[SAE] ready | EggState:" .. tostring(EggStateMod ~= nil)
            .. " Net:" .. tostring(NetRoot ~= nil)
            .. " gen:" .. tostring(MY_GEN))
    end)
    if not ok then
        warn("[SAE init error] " .. tostring(err))
    end
end

_G.SAE_Stop = function()
    S.running = false
    for _, k in ipairs({
        "autoHatch", "autoFinish", "autoPlace", "autoField",
        "autoEquipBest", "autoSell", "autoTier",
        "autoBeanstalk", "autoPickups",
    }) do
        S[k] = false
    end
    pcall(function()
        if S._stepConn then S._stepConn:Disconnect() end
        if S._afkConn then S._afkConn:Disconnect() end
    end)
    warn("[SAE] stopped")
end
