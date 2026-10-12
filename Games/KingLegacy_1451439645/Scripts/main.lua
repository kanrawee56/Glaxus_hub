-- ==================================================
-- King Legacy — Universal Silent Skill (Sea 1/2/3)
-- Map : King Legacy main (Universe 1451439645)
-- File: Games/KingLegacy_1451439645/Scripts/main.lua
-- Type: Single-file | Status: Ready to run
-- --------------------------------------------------
-- หลักการ v2 (แก้จากเทสจริง: executor _G กับเกม _G คนละตัว):
--  1) hook __namecall ดัก SkillAction:InvokeServer ที่เกมยิงเอง แล้วแก้
--     args[2].MouseHit เป็น CFrame เป้าก่อนส่งต่อ -> ทุกสกิลล็อกเอง
--  2) server ดึง aim เองผ่าน GetMTarget/RemoteClient
--     OnClientInvoke -> hook จุดนี้ให้คืนค่าเป้าเดียวกัน
-- เป้า = ใกล้เคอร์เซอร์ที่สุดบนจอ ในระยะ MaxDistance
-- ==================================================

-- ================= CONFIG =================
local CONFIG = {
    Enabled       = true,    -- เปิด silent ตั้งแต่รัน
    TargetMobs    = true,    -- เล็งมอน (Workspace.Monster.Mon/Boss)
    TargetPlayers = false,   -- เล็งผู้เล่นอื่น (เปิดเองถ้าจะใช้)
    MaxDistance   = 800,     -- ระยะสูงสุด (studs) จากตัวเรา
    FOVRadius     = 250,     -- รัศมีรอบเมาส์ (pixels)
    ShowFOV       = true,    -- วง FOV บนจอ
    ShowMarker    = true,    -- มาร์คแดงบนหัวเป้าที่เล็งอยู่
    StickyLock    = true,    -- ล็อกเป้าเดิมต่อจนตาย/หลุดระยะ ไม่สลับกลางคัน
    Theme         = "White", -- WindUI theme ตาม TODO
    ToggleKey     = Enum.KeyCode.RightShift,
}

-- ================= REFERENCES =================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ================= STATE =================
local STATE = {
    running     = true,
    currentTarget = nil, -- { model, hpp, name }
    forgedHit   = nil,   -- CFrame
    forgedPart  = nil,   -- Instance (ส่งคืนให้ GetMTarget)
    origGetMTarget   = nil,
    origRemoteClient = nil,
    hooksInstalled   = false,
}

-- ================= HELPERS =================
local function getCharacter()
    local c = LocalPlayer.Character
    if c then return c end
    return nil
end

local function getHRP(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function isAlive(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- เก็บมอนทั้งหมดจาก Workspace.Monster.Mon + Boss (กันหลุดทีละกิ่ง)
local function eachMob(fn)
    local ok, monster = pcall(function()
        return workspace:FindFirstChild("Monster")
    end)
    if not ok or not monster then return end
    for _, folderName in ipairs({ "Mon", "Boss" }) do
        local folder = monster:FindFirstChild(folderName)
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:IsA("Model") then
                    fn(m)
                end
            end
        end
    end
end

-- เป้าล็อกแล้วต้องยังยิงได้: มีตัวตน + ยังเป็น + มี HRP + ไม่เกินระยะ
-- (ไม่สนว่าหลุดวง FOV ไปแล้ว — เกาะต่อจนตาย/หลุดระยะ = "อยู่ในวงก็อยู่ในวง")
local function lockValid(model, myHRP)
    if not model or not model.Parent then return false end
    -- ประเภทเป้าถูกปิดไว้ -> ปล่อยล็อกทันที
    if Players:GetPlayerFromCharacter(model) then
        if not CONFIG.TargetPlayers then return false end
    else
        if not CONFIG.TargetMobs then return false end
    end
    if not isAlive(model) then return false end
    local hpp = model:FindFirstChild("HumanoidRootPart")
    if not hpp then return false end
    if (hpp.Position - myHRP.Position).Magnitude > CONFIG.MaxDistance then
        return false
    end
    return true
end

-- หาเป้าที่ดีที่สุด: ใกล้เคอร์เซอร์บนจอ + ในระยะ + ยังเป็น
local function findBestTarget()
    local char = getCharacter()
    local myHRP = getHRP(char)
    local cam = workspace.CurrentCamera
    if not myHRP or not cam then return nil end

    local mousePos = UIS:GetMouseLocation()
    local best, bestScore = nil, CONFIG.FOVRadius

    local function consider(model, hpp)
        if model == char then return end
        if not isAlive(model) then return end
        local dist = (hpp.Position - myHRP.Position).Magnitude
        if dist > CONFIG.MaxDistance then return end
        local sp, onScreen = cam:WorldToViewportPoint(hpp.Position)
        if not onScreen then return end
        local d2 = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if d2 < bestScore then
            bestScore = d2
            best = { model = model, hrp = hpp, name = model.Name, dist = dist }
        end
    end

    if CONFIG.TargetMobs then
        eachMob(function(m)
            local hpp = m:FindFirstChild("HumanoidRootPart")
            if hpp then consider(m, hpp) end
        end)
    end

    if CONFIG.TargetPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hpp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hpp then consider(plr.Character, hpp) end
            end
        end
    end

    return best
end

-- ================= HOOKS =================
-- (A) __namecall: ดัก InvokeServer ที่เกมยิงเอง (not checkcaller)
--     ถ้าเป็น SkillAction + มีเป้า -> สลับ MouseHit เป็นของเป้า
-- (B) GetMTarget/RemoteClient OnClientInvoke: server ดึง aim เอง
--     ถ้ามีเป้า forged ให้คืนเป้า ไม่งั้นเรียกของเดิม
local function getRemotes()
    local ok, remotes = pcall(function()
        return game:GetService("ReplicatedStorage")
            :WaitForChild("Chest")
            :WaitForChild("Remotes")
            :WaitForChild("Functions")
    end)
    if ok then return remotes end
    return nil
end

local function installNamecall(skillRemote)
    local mt = getrawmetatable(game)
    if not mt or type(mt.__namecall) ~= "function" then
        warn("[SilentSkill] อ่าน __namecall ไม่ได้")
        return false
    end
    -- กันรันซ้ำ: คืนของเดิมก่อน แล้ว hook ใหม่ (ไม่ซ้อนกัน)
    if _G.__SilentOldNc then
        pcall(function()
            setreadonly(mt, false)
            mt.__namecall = _G.__SilentOldNc
            setreadonly(mt, true)
        end)
        _G.__SilentOldNc = nil
    end
    _G.__SilentOldNc = mt.__namecall
    local old = mt.__namecall
    _G.__SilentDbg = _G.__SilentDbg or { count = 0, lastSkill = "-", lastTarget = "-" }
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer"
            and self == skillRemote
            and not checkcaller()
        then
            local args = { ... }
            local data = args[2]
            if CONFIG.Enabled
                and STATE.forgedHit
                and type(data) == "table"
                and data.MouseHit ~= nil
            then
                data.MouseHit = STATE.forgedHit
                -- ดีบัก: นับครั้ง + จำท่า/เป่าล่าสุด (อ่านผ่าน eval ได้)
                _G.__SilentDbg.count = _G.__SilentDbg.count + 1
                _G.__SilentDbg.lastSkill = tostring(args[1])
                local ct = STATE.currentTarget
                _G.__SilentDbg.lastTarget = ct and (ct.name .. " (" .. math.floor(ct.dist) .. "m)") or "?"
                if data.Type == "Down" then
                    warn("[SilentSkill] ล็อก: " .. _G.__SilentDbg.lastSkill .. " -> " .. _G.__SilentDbg.lastTarget)
                end
            end
            return old(self, table.unpack(args))
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
    return true
end

local function removeNamecall()
    if not _G.__SilentOldNc then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = _G.__SilentOldNc
        setreadonly(mt, true)
    end)
    _G.__SilentOldNc = nil
end
local function installHooks()
    if STATE.hooksInstalled then return true end
    local remotes = getRemotes()
    if not remotes then
        warn("[SilentSkill] หา Remotes.Functions ไม่เจอ จะลองใหม่ทุกเฟรม")
        return false
    end

    -- (A) namecall hook ต้องมี SkillAction instance ก่อน
    local skill = remotes:FindFirstChild("SkillAction")
    if skill then
        if installNamecall(skill) then
            STATE.ncInstalled = true
        end
    end

    local gmt = remotes:FindFirstChild("GetMTarget")
    local rc  = remotes:FindFirstChild("RemoteClient")

    -- NOTE: executor นี้อ่าน .OnClientInvoke ไม่ได้ (อ่านแล้ว throw)
    -- ได้แค่เขียนทับเท่านั้น เลยไม่เก็บของเดิม แต่ fallback ด้วย
    -- Mouse.Hit/Mouse.Target สดซึ่งตรงกับของเดิมในโค้ดเกมพอดี
    if gmt and not STATE.gmtWrapped then
        STATE.gmtWrapped = true
        gmt.OnClientInvoke = function()
            if CONFIG.Enabled and STATE.forgedHit then
                return STATE.forgedHit, STATE.forgedPart
            end
            local mouse = LocalPlayer:GetMouse()
            return mouse.Hit, mouse.Target
        end
    end

    if rc and not STATE.rcWrapped then
        STATE.rcWrapped = true
        rc.OnClientInvoke = function()
            if CONFIG.Enabled and STATE.forgedHit then
                return STATE.forgedHit
            end
            return LocalPlayer:GetMouse().Hit
        end
    end

    STATE.hooksInstalled = (gmt ~= nil)
    return STATE.hooksInstalled
end

local function removeHooks()
    removeNamecall()
    -- คืน OnClientInvoke เป็นค่าปกติ (Mouse สด = พฤติกรรมเดิมของเกม)
    pcall(function()
        local remotes = game:GetService("ReplicatedStorage")
            .Chest.Remotes.Functions
        local gmt = remotes:FindFirstChild("GetMTarget")
        local rc  = remotes:FindFirstChild("RemoteClient")
        if gmt then
            gmt.OnClientInvoke = function()
                local mouse = LocalPlayer:GetMouse()
                return mouse.Hit, mouse.Target
            end
        end
        if rc then
            rc.OnClientInvoke = function()
                return LocalPlayer:GetMouse().Hit
            end
        end
    end)
    STATE.hooksInstalled = false
    STATE.gmtWrapped = false
    STATE.rcWrapped = false
end

-- ================= FOV CIRCLE =================
local fovCircle = nil
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Radius = CONFIG.FOVRadius
    fovCircle.Thickness = 1.5
    fovCircle.Filled = false
    fovCircle.Transparency = 0.8
    -- NOTE: ไม่ตั้ง NumSides (Real ใช้ Radius อย่างเดียว)
end)

-- ================= TARGET MARKER (มาร์คแดงบนหัวเป้า) =================
-- Highlight กรอบแดงรอบตัว (AlwaysOnTop) + ป้ายชื่อ/ระยะเหนือหัว
if _G.__SilentMarkHL then
    pcall(function() _G.__SilentMarkHL:Destroy() end)
    _G.__SilentMarkHL = nil
end
if _G.__SilentMarkBG then
    pcall(function() _G.__SilentMarkBG:Destroy() end)
    _G.__SilentMarkBG = nil
end
local markHL, markBG, markLabel = nil, nil, nil
pcall(function()
    local cg = game:GetService("CoreGui")
    markHL = Instance.new("Highlight")
    markHL.Name = "SilentMark"
    markHL.OutlineColor = Color3.fromRGB(255, 40, 40)
    markHL.FillColor = Color3.fromRGB(255, 40, 40)
    markHL.FillTransparency = 0.85
    markHL.OutlineTransparency = 0
    markHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    markHL.Enabled = false
    markHL.Parent = cg
    _G.__SilentMarkHL = markHL

    markBG = Instance.new("BillboardGui")
    markBG.Name = "SilentMarkTag"
    markBG.Size = UDim2.fromOffset(200, 30)
    markBG.ExtentsOffsetWorldSpace = Vector3.new(0, 4, 0)
    markBG.AlwaysOnTop = true
    markBG.Enabled = false
    markLabel = Instance.new("TextLabel")
    markLabel.Size = UDim2.fromScale(1, 1)
    markLabel.BackgroundTransparency = 1
    markLabel.Font = Enum.Font.GothamBold
    markLabel.TextSize = 16
    markLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    markLabel.TextStrokeTransparency = 0.2
    markLabel.Text = ""
    markLabel.Parent = markBG
    markBG.Parent = cg
    _G.__SilentMarkBG = markBG
end)

local function updateMarker(target)
    local show = CONFIG.ShowMarker and target ~= nil
    if markHL then
        markHL.Enabled = show
        if target then
            markHL.Adornee = target.model
        end
    end
    if markBG then
        if show then
            markBG.Enabled = true
            markBG.Adornee = target.model:FindFirstChild("Head") or target.hrp
            markLabel.Text = "▼ " .. target.name
                .. " (" .. math.floor(target.dist) .. "m)"
        else
            markBG.Enabled = false
            markBG.Adornee = nil
        end
    end
end

-- กันรันซ้ำ: ตัด loop เก่า + ทำลาย window เก่าก่อน
if _G.__SilentSkillConn then
    pcall(function() _G.__SilentSkillConn:Disconnect() end)
    _G.__SilentSkillConn = nil
end
if _G.__SilentSkillWin then
    pcall(function() _G.__SilentSkillWin:Destroy() end)
    _G.__SilentSkillWin = nil
end

-- ================= MAIN LOOP =================
-- ทุกเฟรม: หาเป้า -> เก็บ CFrame ไว้ให้ hooks ใช้
_G.__SilentSkillConn = RunService.RenderStepped:Connect(function()
    local ok, err = pcall(function()
    if not STATE.running then return end

    if not STATE.hooksInstalled then
        installHooks()
    end

    if fovCircle then
        fovCircle.Visible = CONFIG.ShowFOV
        fovCircle.Radius = CONFIG.FOVRadius
        local mp = UIS:GetMouseLocation()
        fovCircle.Position = mp
    end

    if not CONFIG.Enabled then
        STATE.currentTarget = nil
        STATE.lock = nil
        STATE.forgedHit = nil
        STATE.forgedPart = nil
        return
    end

    -- sticky: มีล็อกเดิมที่ยังยิงได้ -> เกาะตัวเดิม (ตามตำแหน่งสดทุกเฟรม)
    -- ไม่มี/หลุด -> หาเป้าใหม่ในวงแล้วล็อก
    local char = getCharacter()
    local myHRP = getHRP(char)
    local target = nil
    if myHRP then
        if CONFIG.StickyLock
            and STATE.lock
            and lockValid(STATE.lock, myHRP)
        then
            local hpp = STATE.lock:FindFirstChild("HumanoidRootPart")
            target = {
                model = STATE.lock,
                hrp = hpp,
                name = STATE.lock.Name,
                dist = (hpp.Position - myHRP.Position).Magnitude,
            }
        else
            STATE.lock = nil
            target = findBestTarget()
            if target then
                STATE.lock = target.model
            end
        end
    else
        STATE.lock = nil
    end
    STATE.currentTarget = target
    -- telemetry อ่านผ่าน eval: เห็นเป้าตอนนี้ไหม (ไม่ต้องกดปุ่ม)
    _G.__SilentDbg = _G.__SilentDbg or { count = 0, lastSkill = "-", lastTarget = "-" }
    if target then
        -- CFrame ล็อกกลางตัวเป้า __namecall hook จะสลับใส่แทนของจริง
        -- (เขียน _G.MouseHit ตรงๆ ไม่ได้ผล: executor _G กับเกม _G คนละตัว)
        local cf = CFrame.new(target.hrp.Position)
        STATE.forgedHit = cf
        STATE.forgedPart = target.hrp
        _G.__SilentDbg.hasTarget = true
        _G.__SilentDbg.lockedName = target.name .. " (" .. math.floor(target.dist) .. "m)"
    else
        STATE.forgedHit = nil
        STATE.forgedPart = nil
        -- ไม่มีเป้า: hook ปล่อยผ่าน ไม่แตะ args
        if _G.__SilentDbg then
            _G.__SilentDbg.hasTarget = false
            _G.__SilentDbg.lockedName = "-"
        end
    end
    -- มาร์คแดงตามเป้าที่ล็อกอยู่
    updateMarker(target)
    end)
    if not ok then
        --  throttle: เก็บ error ล่าสุดไว้ดูผ่าน eval (ไม่ warn ทุกเฟรมกันสแปม)
        _G.__SilentLoopErr = tostring(err)
    else
        _G.__SilentLoopErr = nil
    end
end)

-- ยิงเองแบบไม่ต้องกดปุ่ม: ใช้สกิลอะไรก็ได้ ชื่อตาม client modules
-- ตัวอย่าง: SilentFire("DF_IceIce_Z") | SilentFire("SW_Authentic Triple Katana_Z")
-- NOTE (เทสจริง): ต้องค้าง Down ~1.2 วิก่อน Up ไม่งั้น server ไม่นับดาเมจ
_G.SilentFire = function(skillName, holdTime)
    local target = STATE.currentTarget or findBestTarget()
    if not target then
        warn("[SilentSkill] ไม่มีเป้าในระยะ/FOV")
        return false
    end
    local cf = CFrame.new(target.hrp.Position)
    local remote = game:GetService("ReplicatedStorage")
        .Chest.Remotes.Functions:FindFirstChild("SkillAction")
    if not remote then
        warn("[SilentSkill] หา SkillAction ไม่เจอ")
        return false
    end
    local okDown = false
    pcall(function()
        remote:InvokeServer(skillName, { Type = "Down", MouseHit = cf })
        okDown = true
    end)
    task.wait(holdTime or 1.2)
    -- อัปเดตเป้าอีกรอบตอนปล่อย (มอนอาจขยับ)
    local t2 = findBestTarget()
    local cf2 = cf
    if t2 then cf2 = CFrame.new(t2.hrp.Position) end
    pcall(function()
        remote:InvokeServer(skillName, { Type = "Up", MouseHit = cf2 })
    end)
    return okDown
end

-- ================= UI (WindUI ตาม TODO) =================
-- ถ้า WindUI โหลดไม่ได้ สคริปต์ยังทำงานต่อแบบ headless ด้วยค่า CONFIG
task.spawn(function()
    local ok, WindUI = pcall(function()
        return loadstring(game:HttpGet(
            "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
        ))()
    end)
    if not ok or not WindUI then
        warn("[SilentSkill] โหลด WindUI ไม่ได้ ใช้ค่า CONFIG headless")
        return
    end
    local okWin, Window = pcall(function()
        return WindUI:CreateWindow({
            Title = "King Legacy — Silent Skill",
            Icon = "zap",
            Author = "Sea 1/2/3",
            Folder = "KingLegacySilent",
            Size = UDim2.fromOffset(520, 420),
            ToggleKey = CONFIG.ToggleKey,
            HideSearchBar = true,
        })
    end)
    if not okWin or not Window then
        warn("[SilentSkill] สร้าง WindUI window ไม่ได้: " .. tostring(Window))
        return
    end
    _G.__SilentSkillWin = Window
    -- Theme "White" ตาม TODO: WindUI ไม่มี built-in ต้อง AddTheme เอง
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
    local okUI, uiErr = pcall(function()
        local Tab = Window:Tab({ Title = "Silent" })
        Tab:Toggle({
            Title = "เปิด Silent Skill",
            Value = CONFIG.Enabled,
            Callback = function(v) CONFIG.Enabled = v end,
        })
        Tab:Toggle({
            Title = "เล็งมอน",
            Value = CONFIG.TargetMobs,
            Callback = function(v)
                CONFIG.TargetMobs = v
                if not v then STATE.lock = nil end
            end,
        })
        Tab:Toggle({
            Title = "เล็งผู้เล่น",
            Value = CONFIG.TargetPlayers,
            Callback = function(v)
                CONFIG.TargetPlayers = v
                if not v then STATE.lock = nil end
            end,
        })
        Tab:Toggle({
            Title = "ล็อกเป้าเดิม (sticky)",
            Value = CONFIG.StickyLock,
            Callback = function(v)
                CONFIG.StickyLock = v
                if not v then STATE.lock = nil end
            end,
        })
        Tab:Toggle({
            Title = "แสดงวง FOV",
            Value = CONFIG.ShowFOV,
            Callback = function(v) CONFIG.ShowFOV = v end,
        })
        Tab:Toggle({
            Title = "มาร์คแดงบนหัวเป้า",
            Value = CONFIG.ShowMarker,
            Callback = function(v) CONFIG.ShowMarker = v end,
        })
        Tab:Slider({
            Title = "ระยะสูงสุด (studs)",
            Value = { Min = 100, Max = 3000, Default = CONFIG.MaxDistance },
            Callback = function(v) CONFIG.MaxDistance = v end,
        })
        Tab:Slider({
            Title = "รัศมี FOV (px)",
            Value = { Min = 50, Max = 800, Default = CONFIG.FOVRadius },
            Callback = function(v) CONFIG.FOVRadius = v end,
        })
    end)
    if not okUI then
        warn("[SilentSkill] สร้าง UI elements ไม่ได้: " .. tostring(uiErr))
    end
    -- บังคับเปิดหน้าต่าง (กันกรณี lib สร้างมาแบบปิด)
    pcall(function() Window:Open() end)
    warn("[SilentSkill] เปิด WindUI แล้ว (RightShift เปิด/ปิด)")
end)

-- ================= CLEANUP =================
-- เรียก _G.SilentSkillStop() เพื่อหยุด + คืน hooks + ลบวง FOV
_G.SilentSkillStop = function()
    STATE.running = false
    STATE.lock = nil
    STATE.currentTarget = nil
    CONFIG.Enabled = false
    removeHooks()
    pcall(function() updateMarker(nil) end)
    if markHL then pcall(function() markHL:Destroy() end) end
    if markBG then pcall(function() markBG:Destroy() end) end
    _G.__SilentMarkHL = nil
    _G.__SilentMarkBG = nil
    if fovCircle then
        pcall(function() fovCircle:Remove() end)
        fovCircle = nil
    end
    warn("[SilentSkill] หยุดแล้ว คืน hooks แล้ว")
end

warn("[SilentSkill] รันแล้ว: กดสกิลตามปกติ เป้าในวง FOV จะโดนล็อกเอง | _G.SilentFire(name) ยิงตรง | _G.SilentSkillStop() หยุด")
