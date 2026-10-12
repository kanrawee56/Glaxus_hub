-- ============================================================================
-- Map: Ride A Pet (PlaceId 124216119978534, Universe 10035204815)
-- File: Games/Ride_A_Pet_124216119978534/Scripts/main.lua
-- Type: Single-file | Status: Ready to run (Real executor)
-- Desc: Auto all (prompt-based, no egg warp) + WindUI (RightShift ซ่อน/โชว์)
-- GUI: WindUI loadstring ทางการ + CreateWindow ToggleKey = RightShift (built-in)
--   Tab Auto: Toggle Pickup/Place/Hatch + Slider Scan/TweenSpeed + Button TP Plot
--
-- ของจริงที่อิง (ห้ามเดา):
--   Pickup template = ReplicatedStorage.Assets.Prompts.Pickup
--     (ActionText "Pick Up", Hold 0.2s, MaxDistance 15, LOS false, Key E)
--   RenderEgg โคลน Pickup ลงบนตัวไข่ป่า + เกต Enabled ด้วย DropEndsAt/
--     ComputeReach/ApplyReach/CanSeeMazeEgg (PlayerScripts.Game.EggSpawning.Client)
--   Triggered ของ Pickup เป็น native server-validate (ไม่เจอ FireServer ฝั่ง
--     client) -> ต้องยืนในระยะ + hold ครบ ห้ามวาร์ปไข่, ห้ามวาร์ปแล้วหนีทันที
--   Basket = LocalPlayer.Basket (DropEgg.DropNormally ยิง BasketDrop แบบไม่ส่ง arg)
--   Plot เรา = Workspace.Plots ลูกที่มี Attribute NestsOwnerLoaded == UserId
--   Place = prompt "Place" ใต้ Nest (EggPlaced {NestId} ยิงจาก server ของ prompt)
--   Hatch = prompt "Hatch" บนไข่ใน Plot (fallback: Hatch:FireServer {EggKey})
--   Skip ทั้งหมดเป็น Robux product -> สคริปต์นี้ไม่มีปุ่ม Skip
-- ============================================================================

-- ============================== CONFIG =====================================
local CONFIG = {
    PLACE_ID = 124216119978534,
    ToggleKey = Enum.KeyCode.RightShift,
    AutoPickup = true,   -- เดินไปกด E เก็บไข่ป่า
    AutoPlace = true,    -- เอาไข่ในตะกร้าไปวางที่ Plot
    AutoHatch = true,    -- ฟักไข่ที่พร้อม
    ScanInterval = 3,    -- วินาทีต่อรอบสแกนไข่ป่า
    HatchInterval = 5,   -- วินาทีต่อรอบเช็คฟัก
    ArriveDist = 9,      -- ยืนห่างไข่ไม่เกินนี้ (Template 15, เผื่อเหลือ)
    HoldWait = 0.9,      -- รอหลัง fireproximityprompt (Hold 0.2 + เผื่อ)
    TweenSpeed = 60,     -- studs/sec
    MaxTargetsPerRound = 3,
}

-- ============================== SERVICES ===================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local RemotesGame = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Game")
local HatchRE = RemotesGame:WaitForChild("Hatch")
local BasketDropRE = RemotesGame:WaitForChild("BasketDrop")

-- ============================== STATE ======================================
local GEN = (getgenv().__RAP_GEN or 0) + 1
getgenv().__RAP_GEN = GEN

local S = {
    running = true,
    gen = GEN,
    busy = false,
    lastHatchFire = {},
}
getgenv().RAP = S

local function IsAlive()
    return S.running and getgenv().__RAP_GEN == S.gen
end

local function Notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5,
        })
    end)
end

-- ============================== HELPERS ====================================
local function GetHRP()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function BasketCount()
    local ok, n = pcall(function()
        local b = LocalPlayer:FindFirstChild("Basket")
        if not b then
            return 0
        end
        return #b:GetChildren()
    end)
    if ok and type(n) == "number" then
        return n
    end
    return 0
end

-- Plot เรา: Attribute NestsOwnerLoaded == UserId (ยืนยันจากเกมจริง)
local function GetMyPlot()
    local ok, plot = pcall(function()
        local plots = workspace:FindFirstChild("Plots")
        if not plots then
            return nil
        end
        for _, pl in ipairs(plots:GetChildren()) do
            if pl:GetAttribute("NestsOwnerLoaded") == LocalPlayer.UserId then
                return pl
            end
        end
        return nil
    end)
    if ok then
        return plot
    end
    return nil
end

local function PlotAnchor(plot)
    if not plot then
        return nil
    end
    local ok, cf = pcall(function()
        local eggs = plot:FindFirstChild("Eggs")
        if eggs and #eggs:GetChildren() > 0 then
            local m = eggs:GetChildren()[1]
            local bp = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart", true)
            if bp then
                return bp.CFrame
            end
        end
        local nests = plot:FindFirstChild("Nests")
        if nests and #nests:GetChildren() > 0 then
            local n = nests:GetChildren()[1]
            local bp = n:IsA("BasePart") and n or n:FindFirstChildWhichIsA("BasePart", true)
            if bp then
                return bp.CFrame
            end
        end
        if plot.GetBoundingBox then
            local cf0 = plot:GetBoundingBox()
            return cf0
        end
        return nil
    end)
    if ok then
        return cf
    end
    return nil
end

-- ขยับตัวแบบ Tween (ห้ามวาร์ปไข่, ขยับแต่ตัวเรา)
local function TweenTo(targetCF, timeout)
    local hrp = GetHRP()
    if not hrp or not targetCF then
        return false
    end
    local dist = (hrp.Position - targetCF.Position).Magnitude
    local t = math.clamp(dist / CONFIG.TweenSpeed, 0.3, 12)
    local ok = pcall(function()
        local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = targetCF })
        tw:Play()
        local done = false
        tw.Completed:Connect(function()
            done = true
        end)
        local waitT = (timeout or (t + 3))
        local start = os.clock()
        while not done and IsAlive() and (os.clock() - start) < waitT do
            task.wait(0.1)
        end
        pcall(function()
            tw:Cancel()
        end)
    end)
    return ok
end

local function FirePrompt(prompt)
    if not prompt then
        return false
    end
    local ok = pcall(function()
        fireproximityprompt(prompt) -- ยืนยันว่ามีใน Real API
    end)
    return ok
end

-- หา prompt "Pick Up" ที่ Enabled ใน Workspace (ไข่ป่า render แล้วเท่านั้น)
local function FindPickupPrompts(maxN)
    local out = {}
    local hrp = GetHRP()
    if not hrp then
        return out
    end
    local ok = pcall(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if not IsAlive() then
                break
            end
            if d:IsA("ProximityPrompt") and d.ActionText == "Pick Up" and d.Enabled then
                local pp = d.Parent
                if pp and pp:IsA("BasePart") then
                    local dist = (hrp.Position - pp.Position).Magnitude
                    table.insert(out, { prompt = d, part = pp, dist = dist })
                end
            end
            if #out >= 400 then
                break
            end
        end
    end)
    if not ok then
        return {}
    end
    table.sort(out, function(a, b)
        return a.dist < b.dist
    end)
    local trimmed = {}
    for i = 1, math.min(#out, maxN or 24) do
        trimmed[i] = out[i]
    end
    return trimmed
end

-- จุด spawn สำรอง (Workspace.EggSpawns มี 29 จุดจริง) เอาไว้เดินไปกระตุ้น render
local function NearestEggSpawn()
    local hrp = GetHRP()
    local folder = workspace:FindFirstChild("EggSpawns")
    if not hrp or not folder then
        return nil
    end
    local best, bestD = nil, math.huge
    pcall(function()
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("BasePart") then
                local d = (hrp.Position - c.Position).Magnitude
                if d < bestD then
                    best, bestD = c, d
                end
            end
        end
    end)
    return best
end

-- หา prompt ชื่อตรง (Hatch/Place) ใต้ model ที่กำหนด
local function FindPromptIn(model, name)
    if not model then
        return nil
    end
    local found = nil
    pcall(function()
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Name == name and d.Enabled then
                found = d
                break
            end
        end
    end)
    return found
end

-- ============================== MAIN LOGIC =================================
-- เก็บไข่ป่า: เดินไปยืนใกล้ -> รอ Enabled นิ่ง -> fireproximityprompt -> เช็ค Basket
local function CollectOne(entry)
    local hrp = GetHRP()
    if not hrp or not entry or not entry.prompt or not entry.part then
        return false
    end
    if not entry.prompt.Enabled then
        return false
    end
    local before = BasketCount()
    local standCF = entry.part.CFrame + Vector3.new(0, 3, 0)
    -- ยืนห่างไม่เกิน ArriveDist: ถ้าไกลให้ Tween ไปก่อน
    if entry.dist > CONFIG.ArriveDist then
        TweenTo(standCF)
        task.wait(0.4) -- รอเกมคำนวณ ComputeReach/ApplyReach รายเฟรม
    else
        -- ใกล้อยู่แล้วก็ยังต้องขยับนิดให้ prompt อัปเดต
        pcall(function()
            hrp.CFrame = standCF
        end)
        task.wait(0.4)
    end
    if not IsAlive() then
        return false
    end
    -- prompt อาจดับระหว่างเดิน (DropEndsAt/มีคนเก็บไปก่อน) -> ยกเลิก ไม่ฝืน
    if not entry.prompt.Enabled then
        return false
    end
    if not FirePrompt(entry.prompt) then
        return false
    end
    task.wait(CONFIG.HoldWait)
    local after = BasketCount()
    return after > before
end

local function AutoPickupLoop()
    while IsAlive() do
        if CONFIG.AutoPickup and not S.busy then
            local ok = pcall(function()
                local targets = FindPickupPrompts(24)
                local done = 0
                for _, entry in ipairs(targets) do
                    if not IsAlive() or not CONFIG.AutoPickup then
                        break
                    end
                    if done >= CONFIG.MaxTargetsPerRound then
                        break
                    end
                    local okOne, got = pcall(CollectOne, entry)
                    if okOne and got then
                        done = done + 1
                    end
                    task.wait(0.5)
                end
                -- ไม่เจอไข่ render เลย -> เดินไปจุด spawn ใกล้สุดเพื่อกระตุ้น
                if #targets == 0 then
                    local sp = NearestEggSpawn()
                    if sp then
                        local hrp = GetHRP()
                        if hrp and (hrp.Position - sp.Position).Magnitude > 12 then
                            TweenTo(sp.CFrame + Vector3.new(0, 4, 0))
                            task.wait(0.6)
                        else
                            task.wait(1)
                        end
                    end
                end
            end)
            if not ok then
                task.wait(1)
            end
        end
        local t = 0
        while IsAlive() and t < CONFIG.ScanInterval do
            task.wait(0.25)
            t = t + 0.25
        end
    end
end

-- วางไข่: ไป Plot เรา -> BasketDrop (no-arg ตาม DropNormally) -> กด Place ทีละ Nest
local function AutoPlaceLoop()
    while IsAlive() do
        if CONFIG.AutoPlace and BasketCount() > 0 and not S.busy then
            pcall(function()
                local plot = GetMyPlot()
                if not plot then
                    return
                end
                local anchor = PlotAnchor(plot)
                if anchor then
                    local hrp = GetHRP()
                    if hrp and (hrp.Position - anchor.Position).Magnitude > 14 then
                        TweenTo(anchor + Vector3.new(0, 4, 0))
                        task.wait(0.5)
                    end
                end
                if not IsAlive() then
                    return
                end
                -- เทตะกร้าลง Plot (DropEgg.DropNormally: BasketDrop แบบไม่ส่ง arg)
                pcall(function()
                    BasketDropRE:FireServer()
                end)
                task.wait(1)
                -- กด Place ตาม Nest ที่มี prompt เปิดอยู่ (native, ไม่ forge NestId)
                local nests = plot:FindFirstChild("Nests")
                if nests then
                    for _, nest in ipairs(nests:GetChildren()) do
                        if not IsAlive() or BasketCount() <= 0 then
                            break
                        end
                        local pr = FindPromptIn(nest, "Place")
                        if pr then
                            FirePrompt(pr)
                            task.wait(1)
                        end
                    end
                end
            end)
        end
        local t = 0
        while IsAlive() and t < CONFIG.ScanInterval do
            task.wait(0.25)
            t = t + 0.25
        end
    end
end

-- ฟักไข่: กด prompt Hatch ที่เปิดอยู่ก่อน, fallback ยิง {EggKey} แบบมี debounce
local function AutoHatchLoop()
    while IsAlive() do
        if CONFIG.AutoHatch then
            pcall(function()
                local plot = GetMyPlot()
                if not plot then
                    return
                end
                local eggs = plot:FindFirstChild("Eggs")
                if not eggs then
                    return
                end
                for _, egg in ipairs(eggs:GetChildren()) do
                    if not IsAlive() or not CONFIG.AutoHatch then
                        break
                    end
                    local pr = FindPromptIn(egg, "Hatch")
                    if pr then
                        -- ยืนใกล้ไข่ใบนั้นก่อนกด (prompt ระยะสั้น)
                        local bp = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart", true)
                        local hrp = GetHRP()
                        if bp and hrp and (hrp.Position - bp.Position).Magnitude > 12 then
                            TweenTo(bp.CFrame + Vector3.new(0, 4, 0))
                            task.wait(0.4)
                        end
                        FirePrompt(pr)
                        task.wait(1.2) -- กันสแปมตาม cooldown 1s ของเกม
                    else
                        -- fallback: ยิงตรงด้วย EggKey (เกมเช็ค Ready เอง, ยิงก่อนพร้อม = no-op)
                        local key = egg:GetAttribute("EggKey")
                        if key then
                            local last = S.lastHatchFire[key] or 0
                            if os.clock() - last > 3 then
                                S.lastHatchFire[key] = os.clock()
                                pcall(function()
                                    HatchRE:FireServer({ EggKey = key })
                                end)
                                task.wait(1.2)
                            end
                        end
                    end
                end
            end)
        end
        local t = 0
        while IsAlive() and t < CONFIG.HatchInterval do
            task.wait(0.25)
            t = t + 0.25
        end
    end
end

local function GuiNotify(ui, title, msg)
    if ui then
        pcall(function()
            ui:Notify({ Title = title, Content = msg, Duration = 2 })
        end)
    else
        Notify(title, msg)
    end
end

-- ============================== GUI (WindUI) =================================
-- pattern เดียวกับที่รันได้จริงใน executor นี้ (อ้างอิง StealAnEgg):
-- loadstring ทางการ + validate + cache + CreateWindow ToggleKey = RightShift
task.spawn(function()
    if game.PlaceId ~= CONFIG.PLACE_ID then
        return
    end
    local ok, WindUI = false, nil
    if getgenv().__RAP_WindUI and type(getgenv().__RAP_WindUI) == "table" then
        WindUI = getgenv().__RAP_WindUI
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
                    getgenv().__RAP_WindUI = w
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
        warn("[RAP] โหลด WindUI ไม่ได้ รันแบบ headless (auto ยังทำงาน)")
        return
    end

    local okWin, Window = pcall(function()
        return WindUI:CreateWindow({
            Title = "Ride A Pet",
            Author = "Pickup + Place + Hatch",
            Folder = "RideAPet",
            Size = UDim2.fromOffset(520, 440),
            ToggleKey = CONFIG.ToggleKey, -- RightShift ซ่อน/โชว์ (built-in)
            HideSearchBar = true,
        })
    end)
    if not okWin or not Window then
        warn("[RAP] สร้าง window ไม่ได้")
        return
    end

    local AutoTab = Window:Tab({ Title = "Auto", Icon = "egg" })
    AutoTab:Toggle({
        Title = "Auto Pickup (เก็บไข่ป่า)",
        Desc = "Tween ไปยืนใกล้ + fireproximityprompt",
        Value = CONFIG.AutoPickup,
        Callback = function(v)
            CONFIG.AutoPickup = v
            GuiNotify(WindUI, "Ride A Pet", v and "AutoPickup ON" or "AutoPickup OFF")
        end,
    })
    AutoTab:Toggle({
        Title = "Auto Place (วางไข่ที่ Plot)",
        Desc = "BasketDrop + กด Place ทีละ Nest",
        Value = CONFIG.AutoPlace,
        Callback = function(v)
            CONFIG.AutoPlace = v
            GuiNotify(WindUI, "Ride A Pet", v and "AutoPlace ON" or "AutoPlace OFF")
        end,
    })
    AutoTab:Toggle({
        Title = "Auto Hatch (ฟักไข่พร้อม)",
        Desc = "กด prompt Hatch / fallback {EggKey}",
        Value = CONFIG.AutoHatch,
        Callback = function(v)
            CONFIG.AutoHatch = v
            GuiNotify(WindUI, "Ride A Pet", v and "AutoHatch ON" or "AutoHatch OFF")
        end,
    })
    AutoTab:Slider({
        Title = "Scan Interval (วิ)",
        Value = { Min = 1, Max = 10, Default = CONFIG.ScanInterval },
        Step = 1,
        Callback = function(v) CONFIG.ScanInterval = v end,
    })
    AutoTab:Slider({
        Title = "Tween Speed",
        Value = { Min = 20, Max = 120, Default = CONFIG.TweenSpeed },
        Step = 5,
        Callback = function(v) CONFIG.TweenSpeed = v end,
    })
    AutoTab:Button({
        Title = "TP กลับ Plot ตัวเอง",
        Callback = function()
            local plot = GetMyPlot()
            local anchor = plot and PlotAnchor(plot)
            if anchor then
                TweenTo(anchor + Vector3.new(0, 4, 0))
                GuiNotify(WindUI, "Ride A Pet", "TP Plot แล้ว")
            else
                GuiNotify(WindUI, "Ride A Pet", "หา Plot ตัวเองไม่เจอ")
            end
        end,
    })

    local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })
    InfoTab:Button({
        Title = "เช็ค Basket / Plot ตอนนี้",
        Callback = function()
            local plot = GetMyPlot()
            local eggs = 0
            if plot then
                local e = plot:FindFirstChild("Eggs")
                if e then eggs = #e:GetChildren() end
            end
            GuiNotify(WindUI, "Ride A Pet",
                "Basket:" .. BasketCount() .. " ไข่ใน Plot:" .. eggs)
        end,
    })

    pcall(function() Window:Open() end)
    warn("[RAP] WindUI พร้อมแล้ว (RightShift ซ่อน/โชว์)")
end)

local function Main()
    if game.PlaceId ~= CONFIG.PLACE_ID then
        warn("[RAP] Wrong PlaceId:", game.PlaceId, "expected:", CONFIG.PLACE_ID)
        Notify("Ride A Pet", "PlaceId ไม่ตรง หยุดทำงาน")
        S.running = false
        return
    end
    if not fireproximityprompt then
        warn("[RAP] executor ไม่มี fireproximityprompt ใช้วิธีนี้ไม่ได้")
        Notify("Ride A Pet", "executor ไม่รองรับ fireproximityprompt")
        S.running = false
        return
    end

    -- RightShift ถูกใช้เป็น WindUI ToggleKey (ซ่อน/โชว์) แทนแล้ว

    Notify("Ride A Pet", "Auto loaded (no egg warp). RightShift = ซ่อน/โชว์")
    print("[RAP] Ready. AutoPickup/Place/Hatch ON. GEN=" .. tostring(S.gen))

    task.spawn(AutoPickupLoop)
    task.spawn(AutoPlaceLoop)
    task.spawn(AutoHatchLoop)
end

-- ============================== INITIALIZATION =============================
local ok, err = pcall(Main)
if not ok then
    warn("[RAP Error]", err)
end
