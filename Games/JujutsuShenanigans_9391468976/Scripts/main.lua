-- ============================================================================
-- Map: JujutsuShenanigans (PlaceID 9391468976)
-- File: Games/JujutsuShenanigans_9391468976/Scripts/main.lua
-- Type: Single-file | Status: Ready to run (Real executor)
-- Goal: กด 3 ครั้งเดียว -> สคริปต์กดรอบ 2 ให้เอง + ฟาร์มลุ้น Black Flash
-- ความจริงที่ต้องรู้ก่อน:
--   DivergentFistService.RE.Activated ส่งแค่ (target) ไม่มี flag บังคับติด
--   เซิร์ฟเวอร์เป็นคนสุ่ม Black Flash (FX: Effects "DivergentSwing", char, true)
--   สคริปต์นี้เลยทำได้แค่ "กด 2 จังหวะให้เป๊ะ + สแปมให้ถี่ + กันโดนเตะ"
--   ไม่ใช่ "กดทีเดียวติด 100%" (ใครอ้างแบบนั้นคือหลอก)
-- Slot: 1=Cursed Strikes, 2=Crushing Blow, 3=Divergent Fist, 4=Manji Kick
-- ============================================================================

-- ============================== CONFIG =====================================
local CONFIG = {
    TargetMode = "Nearest",   -- "Dummy" | "Nearest" | "Any"
    TargetName = "Dummy",
    AttackPlayers = false,
    StandDist = 7,
    WalkTimeout = 5,
    TeleportIfFar = 60,

    DivergentCooldown = 8,    -- กันโดน 267 kick (อย่าต่ำกว่า 7)
    CursedCooldown = 10,
    M1Delay = 0.4,

    -- หัวใจของสคริปต์นี้: กด 3 ครั้งที่ 2 ห่างจากครั้งที่ 1 กี่วิ
    -- ค่า exact ของเซิร์ฟเวอร์ไม่มีใน client (server-side)
    -- จาก FX timing (Crack 0.142s / Divergent delay 0.3s) เริ่มที่ 0.65 แล้วจูนเอา
    -- วัดจากนิ้วผู้ใช้จริง: 0.356 / 0.430 / 0.479 -> ล็อก 0.44
    SecondPressDelay = 0.44,  -- slider 0.10 - 2.00
    AutoDouble3 = true,       -- กด 3 ครั้งเดียว -> ยิงรอบ 2 ให้เอง
    AutoFarmDouble3 = false,  -- อย่าวนเอง (ผู้ใช้กดเอง)
    AutoCursed = false,
    AutoM1 = false,
    AutoWalk = false,         -- อย่าเดินเอง (ผู้ใช้เดินเอง)
    SpamMode = false,         -- โหมดทดลอง: ยิง 3->3 ทันทีที่คูลดาวน์หมดทุกครั้ง + นับเรท
}

-- ============================== STATE ======================================
getgenv().JJS_BF = getgenv().JJS_BF or { running = false, procs = 0, tries = 0, doubles = 0 }
local S = getgenv().JJS_BF
S.running = S.running or false

-- ============================== SERVICES ===================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ============================== TARGET =====================================
local function isPlayerChar(m)
    if m.Name == "Dummy" then return false end
    if Players:GetPlayerFromCharacter(m) then return true end
    local owner = m:GetAttribute("Owner")
    if owner then return true end
    return m:FindFirstChild("Info") ~= nil
end

local function getTarget()
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return nil end
    if CONFIG.TargetMode == "Dummy" then
        local d = chars:FindFirstChild(CONFIG.TargetName)
        if d and d:FindFirstChild("HumanoidRootPart") then return d end
        return nil
    end
    local myHRP = getHRP()
    if not myHRP then return nil end
    local best, bestDist = nil, 80
    for _, m in pairs(chars:GetChildren()) do
        if m ~= getChar() and m:FindFirstChild("HumanoidRootPart") then
            local h = m:FindFirstChildOfClass("Humanoid")
            if not h or h.Health > 0 then
                local isDummy = (m.Name == CONFIG.TargetName)
                local want = false
                if CONFIG.TargetMode == "Nearest" then
                    want = isDummy or (CONFIG.AttackPlayers and isPlayerChar(m))
                elseif CONFIG.TargetMode == "Any" then
                    want = true
                end
                if want then
                    local dist = (m.HumanoidRootPart.Position - myHRP.Position).Magnitude
                    if dist < bestDist then best, bestDist = m, dist end
                end
            end
        end
    end
    return best
end

-- ============================== REMOTES ====================================
local function getRemote(service, name)
    local ok, rem = pcall(function()
        return ReplicatedStorage.Knit.Knit.Services[service].RE[name]
    end)
    if ok and rem then return rem end
    return nil
end

local DivergentActivated = getRemote("DivergentFistService", "Activated")
local CursedActivated = getRemote("CursedStrikesService", "Activated")
local ItadoriActivated = getRemote("ItadoriService", "Activated")
local DivergentFX = getRemote("DivergentFistService", "Effects")

-- ============ BYPASS: เดินสายเกม (ToolController.UseKey) แทนยิง remote ดิบ ==
-- ยิง Activated ดิบข้ามคิวเกม (tool object / state InDash-InRoll / ReadyAt)
-- เซิร์ฟเวอร์มองเป็น spam/malformed -> เตะ 267 วิธีเลี่ยงคือให้เกมกดให้
-- หมายเหตุ: หา ToolController ตอนกดจริงทุกครั้ง (ไม่จำไว้ตั้งแต่ตอนโหลด เพราะ Knit อาจยังไม่พร้อม)
local function getToolController()
    local ok, Knit = pcall(function() return require(ReplicatedStorage.Knit.Knit) end)
    if not ok or not Knit then return nil end
    local ok2, tc = pcall(function() return Knit.GetController("ToolController") end)
    if ok2 then return tc end
    return nil
end

local function getSkillTool(key)
    local c = getChar()
    local ms = c and c:FindFirstChild("Moveset")
    if not ms then return nil end
    for _, j in pairs(ms:GetChildren()) do
        if j:GetAttribute("Key") == key and j:GetAttribute("Service") then
            return j
        end
    end
    return nil
end

-- อ่านคูลดาวน์จริงจาก attribute (ReadyAt vs ServerTimeNow) กันยิงตอนติดคูลดาวน์
local function skillReady(key)
    local tool = getSkillTool(key)
    if not tool then return true end -- ไม่มีข้อมูล ให้เกมตัดสินเอง
    local ok, readyAt = pcall(function() return tool:GetAttribute("ReadyAt") end)
    if not ok or readyAt == nil then return true end
    local now = 0
    pcall(function() now = workspace:GetServerTimeNow() end)
    return (readyAt - now) <= 0.25 -- เผื่อแล็ก 0.25วิ
end

-- กดสกิลผ่านสายเกมเท่านั้น (ไม่ยิงดิบ กันเตะ 267)
-- force=true = กดรอบ 2 ของคอมโบ ข้ามเช็ค ReadyAt (เซิร์ฟเวอร์รับรอบ 2 ในหน้าต่างของมันเอง)
local function pressSkill(key, force)
    if not force and not skillReady(key) then return false end
    local ToolController = getToolController()
    if ToolController and ToolController.UseKey then
        local ok, err = pcall(function() ToolController:UseKey(key, "Activated") end)
        if ok then
            S.tries = S.tries + 1
            return true
        else
            warn("[JJS] UseKey failed: " .. tostring(err))
            return false
        end
    else
        warn("[JJS] no ToolController")
        return false
    end
end

-- ยิงรอบ 2 แบบไม่เช็คคูลดาวน์ (ใช้เฉพาะคู่กับรอบ 1 ที่เพิ่งกด)
local function fireSecond(target)
    if not target then target = getTarget() end
    if not target then return false end
    faceTarget(target)
    return pressSkill(3, true)
end

-- ============================== MOVE =======================================
local function faceTarget(target)
    pcall(function()
        local hrp = getHRP()
        local thrp = target and target:FindFirstChild("HumanoidRootPart")
        if not hrp or not thrp then return end
        local p, tp = hrp.Position, thrp.Position
        hrp.CFrame = CFrame.new(p, Vector3.new(tp.X, p.Y, tp.Z))
    end)
end

local function gotoTarget(target)
    local hrp, hum = getHRP(), getHum()
    local thrp = target and target:FindFirstChild("HumanoidRootPart")
    if not hrp or not hum or not thrp then return false end
    if hum.Health <= 0 then return false end
    local dist = (hrp.Position - thrp.Position).Magnitude
    if dist <= CONFIG.StandDist then faceTarget(target) return true end
    if dist >= CONFIG.TeleportIfFar then
        pcall(function()
            hrp.CFrame = thrp.CFrame * CFrame.new(0, 0, CONFIG.StandDist)
        end)
        task.wait(0.5)
        return true
    end
    pcall(function()
        hum:MoveTo((thrp.CFrame * CFrame.new(0, 0, CONFIG.StandDist)).Position)
    end)
    local t0 = tick()
    while tick() - t0 < CONFIG.WalkTimeout do
        if not S.running then break end
        local h2 = getHRP()
        local th2 = target.Parent and target:FindFirstChild("HumanoidRootPart")
        if not h2 or not th2 then break end
        if (h2.Position - th2.Position).Magnitude <= CONFIG.StandDist + 1 then break end
        task.wait(0.2)
    end
    faceTarget(target)
    return true
end

-- ============================== DETECTOR (ของจริงเท่านั้น) ==================
do
    if DivergentFX and not S._hooked then
        S._hooked = true
        DivergentFX.OnClientEvent:Connect(function(action, char, isBF, ...)
            if action == "DivergentSwing" and isBF == true then
                S.procs = S.procs + 1
            elseif action == "BlackFlashHit" then
                S.procs = S.procs + 1
            end
        end)
        print("[JJS] detector hooked (DivergentSwing true = ของจริง)")
    end
end

-- ============================== DOUBLE-3 CORE ==============================
-- สายใหม่: กดผ่าน UseKey(3) ให้เกมยิง Activated เอง (ไม่ยิงดิบ กันเตะ 267)
local function fireOnce(target)
    faceTarget(target)
    return pressSkill(3)
end

-- กด 3 ครั้งเดียวจบ: ยิงครั้งที่ 1 ทันที + ตั้งเวลายิงครั้งที่ 2 ให้เอง
local function doublePress3(target, delayOverride)
    if not target then target = getTarget() end
    if not target then return false end
    local d = delayOverride or CONFIG.SecondPressDelay
    faceTarget(target)
    fireOnce(target)
    S.doubles = S.doubles + 1
    task.delay(d, function()
        if not S.running then return end
        -- ล็อกเป้าใหม่กันหุ่นตาย/เปลี่ยนตัวระหว่างรอ
        local t2 = target.Parent and target:FindFirstChild("HumanoidRootPart") and target or getTarget()
        if not t2 then return end
        fireSecond(t2)
    end)
    return true
end

local function fireCursed(target)
    faceTarget(target)
    pressSkill(1)
end
local function fireM1(target)
    -- M1 เดินสายเกมเหมือนกัน (กันเตะ): ใช้ Melee ผ่าน ToolController ถ้ามี
    faceTarget(target)
    local TC = getToolController()
    if TC and TC.Melee then
        pcall(function() TC:Melee() end)
        return
    end
    if not ItadoriActivated or not target then return end
    pcall(function() ItadoriActivated:FireServer("Down", target) end)
end

-- ============================== INPUT HOOK =================================
-- ผู้ใช้กด 3 เองครั้งเดียว -> สคริปต์เสริมครั้งที่ 2 ให้อัตโนมัติ
-- ดักเฉพาะตอนพิมพ์ไม่ติดแชท (gameProcessedEvent == false)
do
    if not S._inputHooked then
        S._inputHooked = true
        UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if not S.running then return end
            if not CONFIG.AutoDouble3 then return end
            if input.KeyCode == Enum.KeyCode.Three then
                local c = getChar()
                if not c or c:GetAttribute("Moveset") ~= "Itadori" then return end
                local t = getTarget()
                if not t then return end
                -- จดจังหวะนิ้ว: กด 3 ห่างกันกี่วิ (ดูว่าปกติเว้นเท่าไหร่)
                local now = tick()
                S._pressT = S._pressT or {}
                table.insert(S._pressT, now)
                if #S._pressT > 20 then table.remove(S._pressT, 1) end
                if #S._pressT >= 2 then
                    local gap = now - S._pressT[#S._pressT - 1]
                    warn(string.format("[GAP] %.3f sec", gap))
                end
                -- กันยิงซ้ำซ้อน: หน้านี้จดจังหวะอย่างเดียว รอบ 2 ปล่อยให้ watcher loop จัดการ
                if S._lastManual and (now - S._lastManual) < 0.5 then return end
                S._lastManual = now
            end
        end)
        print("[JJS] input hook: กด 3 ครั้งเดียว -> เสริมครั้งที่ 2 อัตโนมัติ")
    end
end

-- ============================== LOOPS ======================================
local function stopAll()
    S.running = false
    pcall(function()
        local h = getHum()
        if h and getHRP() then h:MoveTo(getHRP().Position) end
    end)
    print("[JJS] stopped. tries=" .. tostring(S.tries) .. " doubles=" .. tostring(S.doubles) .. " realBF=" .. tostring(S.procs))
end

local function startAll()
    if S.running then print("[JJS] already running") return end
    local c = getChar()
    if not c or c:GetAttribute("Moveset") ~= "Itadori" then
        warn("[JJS] ต้องเลือกตัว Itadori ก่อน (ตอนนี้=" .. tostring(c and c:GetAttribute("Moveset")) .. ")")
        return
    end
    if not getToolController() and not DivergentActivated then
        warn("[JJS] หา ToolController และ DivergentFistService.Activated ไม่เจอ")
        return
    end
    S.running = true
    print("[JJS] AUTO DOUBLE-3 started. delay=" .. tostring(CONFIG.SecondPressDelay))

    task.spawn(function() -- mover (ปิดไว้ตามคำขอ: ผู้ใช้เดินเอง)
        while S.running do
            if CONFIG.AutoWalk then
                local t = getTarget()
                if t then gotoTarget(t) else task.wait(1) end
            end
            task.wait(0.5)
        end
    end)

    task.spawn(function() -- auto double-3 loop (ไม่ต้องกดเองเลย)
        while S.running do
            if CONFIG.AutoFarmDouble3 then
                local t = getTarget()
                if t then
                    local hrp = getHRP()
                    local th = t:FindFirstChild("HumanoidRootPart")
                    if hrp and th and (hrp.Position - th.Position).Magnitude <= 20 then
                        doublePress3(t)
                    end
                end
            end
            task.wait(CONFIG.DivergentCooldown)
        end
    end)

    task.spawn(function() -- Cursed
        while S.running do
            if CONFIG.AutoCursed then
                local t = getTarget()
                if t then faceTarget(t) fireCursed(t) end
            end
            task.wait(CONFIG.CursedCooldown)
        end
    end)

    task.spawn(function() -- M1 เบาๆ
        while S.running do
            if CONFIG.AutoM1 then
                local t = getTarget()
                local hrp = getHRP()
                local th = t and t:FindFirstChild("HumanoidRootPart")
                if t and hrp and th and (hrp.Position - th.Position).Magnitude <= 12 then
                    faceTarget(t) fireM1(t)
                end
            end
            task.wait(CONFIG.M1Delay)
        end
    end)

    task.spawn(function() -- status
        while S.running do
            task.wait(10)
            local rate = S.tries > 0 and (S.procs / S.tries * 100) or 0
            print(string.format("[JJS] tries=%d doubles=%d realBF=%d rate=%.1f%%",
                S.tries, S.doubles, S.procs, rate))
        end
    end)

    task.spawn(function() -- watcher: เห็นนายกด 3 (LastUse ขยับ) -> เสริมรอบ 2 ให้หลัง delay
        -- แบบ event-driven (ไม่ poll ถี่ ไม่กินแรง client)
        local lastTool, conn = nil, nil
        while S.running do
            local tool = getSkillTool(3)
            if tool ~= lastTool then
                if conn then pcall(function() conn:Disconnect() end) conn = nil end
                lastTool = tool
                if tool then
                    conn = tool:GetAttributeChangedSignal("LastUse"):Connect(function()
                        if not S.running then return end
                        S.doubles = S.doubles + 1
                        task.delay(CONFIG.SecondPressDelay, function()
                            if not S.running then return end
                            fireSecond(getTarget())
                        end)
                    end)
                end
            end
            task.wait(2)
        end
        if conn then pcall(function() conn:Disconnect() end) end
    end)

    task.spawn(function() -- spam mode: ยิงทันทีที่ ReadyAt หมด (ถี่สุดแบบไม่โดนเตะ)
        while S.running do
            if CONFIG.SpamMode then
                if skillReady(3) then
                    local t = getTarget()
                    if t then
                        local hrp = getHRP()
                        local th = t:FindFirstChild("HumanoidRootPart")
                        if hrp and th and (hrp.Position - th.Position).Magnitude <= 20 then
                            doublePress3(t)
                        end
                    end
                end
                task.wait(0.5)
            else
                task.wait(1)
            end
        end
    end)
end

-- ============================== WINDUI =====================================
local function buildUI()
    local ok, WindUI = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if not ok or not WindUI then
        warn("[JJS] โหลด WindUI ไม่ได้ ใช้คำสั่ง JJS_Start()/JJS_Stop() แทน")
        return nil
    end
    local Window = WindUI:CreateWindow({
        Title = "JJS BlackFlash",
        Author = "Itadori Double-3 | กด 3 ทีเดียว",
        Folder = "JJS_BF",
        Size = UDim2.fromOffset(520, 420),
        Theme = "Light",
        ToggleKey = Enum.KeyCode.RightShift,
    })
    S._notify = function(msg)
        pcall(function()
            WindUI:Notify({ Title = "JJS", Content = msg, Duration = 3 })
        end)
    end

    local TabMain = Window:Tab({ Title = "ฟาร์ม", Icon = "zap" })
    TabMain:Toggle({
        Title = "เปิดออโต้ (เริ่ม/หยุด)",
        Value = S.running,
        Callback = function(v)
            if v then startAll() else stopAll() end
        end,
    })
    TabMain:Toggle({
        Title = "กด 3 ทีเดียว -> ยิงรอบ 2 ให้เอง",
        Desc = "กด 3 เองครั้งเดียวพอ ที่เหลือสคริปต์เสริมให้",
        Value = CONFIG.AutoDouble3,
        Callback = function(v) CONFIG.AutoDouble3 = v end,
    })
    TabMain:Toggle({
        Title = "วนลูป 3 -> 3 อัตโนมัติ (ไม่ต้องกดเลย)",
        Value = CONFIG.AutoFarmDouble3,
        Callback = function(v) CONFIG.AutoFarmDouble3 = v end,
    })
    TabMain:Toggle({
        Title = "เดินหาหุ่นเอง",
        Desc = "ปิดไว้ = ผู้ใช้เดินเอง",
        Value = CONFIG.AutoWalk,
        Callback = function(v) CONFIG.AutoWalk = v end,
    })
    TabMain:Toggle({
        Title = "โหมดสแปมถี่สุด (ทดลองเรทติด)",
        Desc = "ยิง 3->3 ทันทีที่คูลดาวน์หมดทุกครั้ง ยืนใกล้หุ่นไว้",
        Value = CONFIG.SpamMode,
        Callback = function(v) CONFIG.SpamMode = v end,
    })
    TabMain:Slider({
        Title = "ดีเลย์กดครั้งที่ 2 (วินาที)",
        Desc = "ถ้ากดแล้วออกแค่ฮิตเดียว ให้ลอง 0.45 / 0.65 / 0.90",
        Value = { Min = 10, Max = 200, Default = math.floor(CONFIG.SecondPressDelay * 100) },
        Step = 5,
        Callback = function(v)
            CONFIG.SecondPressDelay = v / 100
        end,
    })
    TabMain:Slider({
        Title = "คูลดาวน์ Divergent (วิ กันเตะ 267)",
        Value = { Min = 7, Max = 15, Default = CONFIG.DivergentCooldown },
        Step = 1,
        Callback = function(v) CONFIG.DivergentCooldown = v end,
    })
    TabMain:Toggle({
        Title = "ตี Cursed (สกิล 1) ด้วย",
        Value = CONFIG.AutoCursed,
        Callback = function(v) CONFIG.AutoCursed = v end,
    })
    TabMain:Toggle({
        Title = "ตี M1 เบาๆ ด้วย",
        Value = CONFIG.AutoM1,
        Callback = function(v) CONFIG.AutoM1 = v end,
    })
    TabMain:Button({
        Title = "ยิง Double-3 เดี๋ยวนี้ 1 ชุด",
        Callback = function() doublePress3(getTarget()) end,
    })

    local TabHelp = Window:Tab({ Title = "วิธีจูน", Icon = "info" })
    TabHelp:Button({
        Title = "ทำไมต้องจูนดีเลย์?",
        Desc = "จังหวะรอบ 2 อยู่ฝั่งเซิร์ฟเวอร์ เริ่ม 0.65 วิ ถ้าออกฮิตเดียวให้ขยับทีละ 0.10 (0.45/0.65/0.90)",
        Callback = function() end,
    })
    TabHelp:Button({
        Title = "Black Flash ลุ้นยังไง?",
        Desc = "เซิร์ฟเวอร์สุ่มติดเอง เราเพิ่มจำนวนครั้งให้ถี่โดยไม่โดนเตะ นับเฉพาะ DivergentSwing=true",
        Callback = function() end,
    })
    return Window
end

-- ============================== INIT =======================================
local ok, err = pcall(function()
    getgenv().JJS_Start = startAll
    getgenv().JJS_Stop = stopAll
    getgenv().JJS_Double = doublePress3
    getgenv().JJS_State = function()
        return { running = S.running, tries = S.tries, doubles = S.doubles, procs = S.procs, delay = CONFIG.SecondPressDelay }
    end
    getgenv().JJS_SetDelay = function(v)
        CONFIG.SecondPressDelay = tonumber(v) or CONFIG.SecondPressDelay
        return CONFIG.SecondPressDelay
    end
    buildUI()
    startAll()
    print("[JJS] ready. RightShift เปิด/ปิดเมนู | JJS_State() / JJS_Stop() / JJS_Double()")
end)
if not ok then warn("[JJS Error]", err) end
