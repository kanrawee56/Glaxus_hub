-- BloxStrike Silent v6-trigger (standalone)
-- วางใน executor รันได้เลย รันซ้ำได้ ล้างของเก่าให้เอง
-- ดีไซน์ใหม่: เลิกดัก Workspace:Raycast แล้ว (นั่นได้แค่ภาพ local)
-- เกมส่งไปเซิร์ฟเวอร์แค่ Origin+Direction (ดู ShootWeapon packet)
-- เซิร์ฟเวอร์ยิงจำลองเองจากทิศนั้น -> ต้องแก้ r.Direction ใน Bullet.create
-- ก่อนโดนใส่ packet ถึงจะมีดาเมจ
-- เป้า: Workspace.Characters.<ชื่อ> + เช็ค Dead/Health (ไม่มี Humanoid ในเกมนี้)
-- + TRIGGERBOT: เป้าเข้าวง FOV -> ลั่นเอง (ใช้ candidates เดียวกับ silent aim)

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local G                 = getgenv()

-- ============================================================
-- [ CLEANUP ] รันซ้ำได้ ล้างของเก่าก่อนเสมอ
-- ============================================================
if G.__SA_loop   then pcall(function() G.__SA_loop:Disconnect() end) end
if G.__SA_hbLoop then pcall(function() G.__SA_hbLoop:Disconnect() end) end
if G.__TB_loop   then pcall(function() G.__TB_loop:Disconnect() end) end
if G.__SA_circle then pcall(function() G.__SA_circle:Remove() end) end
if G.__ESP_objs  then pcall(function()
    for _, e in pairs(G.__ESP_objs) do
        if e.all then for _, o in ipairs(e.all) do pcall(function() o:Remove() end) end end
    end
end) end
if G.__SA_window then pcall(function() G.__SA_window:Destroy() end) end
if G.__SA_origNC then pcall(function() hookmetamethod(game, "__namecall", G.__SA_origNC) end) end
if G.__bulletWrap ~= nil or G.__bulletOrig ~= nil then
    pcall(function()
        local BM = require(ReplicatedStorage.Components.Weapon.Classes.Bullet)
        if G.__bulletOrig ~= nil then BM.create = G.__bulletOrig end
    end)
end
G.__SA_loop = nil ; G.__SA_hbLoop = nil ; G.__TB_loop = nil
G.__SA_circle = nil ; G.__SA_window = nil ; G.__SA_origNC = nil ; G.__ESP_objs = nil
G.__bulletWrap = nil ; G.__bulletOrig = nil ; G.__SA_getCandidates = nil

-- ============================================================
-- [ CONFIG ]
-- ============================================================
local Cfg = {
    Enabled      = true,
    FOV          = 300,
    TargetPart   = "Head", -- part หลักที่อยากได้ก่อน
    HitChance    = 100,
    ShowFOV      = true,
    TeamCheck    = true,
    TargetBots   = true, -- เล็งบอทด้วย (บอทไม่มีชื่อใน Players ต้องวนโมเดลโดยตรง)
    Wallbang     = true, -- ยิงทะลุกำแพง: เล็งตัวหลังกำแพงได้ (ติดแค่ไหนขึ้นกับค่าเจาะของปืน)
    Triggerbot   = true, -- เป้าเข้าวง FOV -> ลั่นเอง
    ReactionMs   = 0,    -- หน่วงก่อนลั่นไก (มิลลิวินาที) 0 = ทันทีที่เห็น
    TriggerPart  = "Any", -- "Any" | "Head" | "UpperTorso" | "HumanoidRootPart"
    TriggerMode  = "Spam", -- "Hold" (ปืนกลกดค้าง) | "Spam" (ปืนกึ่งอัตโนมัติ: คลิกย้ำเอง)
    SpamMs       = 50,   -- โหมด Spam: คลิกทุกกี่ ms
    ESP          = true, -- ESP ศัตรู
    ESPBox       = true, -- กรอบมุม
    ESPName      = true, -- ชื่อ + ระยะ
    ESPHealth    = true, -- แถบเลือด
    ESPMaxDist   = 600,  -- มองไกลสุดกี่ studs (เกินนี้ไม่วาด)
}
-- part สำรอง: หัวเล็ก/โดนบัง -> เอาลำตัวแทน (ยังติดดาเมจ ไม่เสียนัดฟรี)
local FALLBACK_PARTS = { "Head", "UpperTorso", "HumanoidRootPart" }
G.__SA_cfg = Cfg

-- ============================================================
-- [ STATS ]
-- ============================================================
local Stats = { createCalls = 0, redirected = 0, triggerPulls = 0 }
G.__silent = Stats

-- ============================================================
-- [ MODULES - แบบกันตาย: ไม่มีก็ยังทำงานด้วย hook ล้วนได้ ]
-- ============================================================
local BulletMod = nil
pcall(function()
    BulletMod = require(ReplicatedStorage.Components.Weapon.Classes.Bullet)
end)

-- executor มีปุ่มเม้าส์ไหม (triggerbot ใช้ mouse1press/release/click)
local HasMouseFn = typeof(mouse1press) == "function" and typeof(mouse1release) == "function"
local HasClickFn = typeof(mouse1click) == "function"

-- ============================================================
-- [ CHARACTER SOURCE ]
-- วนโมเดลใน Workspace.Characters โดยตรง (เจอทั้งผู้เล่น + บอท)
-- บอท (Bot=true) ไม่มีชื่อใน Players + มี Team อยู่บนตัวโมเดล
-- ============================================================
local function getCharsFolder()
    local f = Workspace:FindFirstChild("Characters")
    return f
end

-- ============================================================
-- [ ALIVE CHECK - จุดที่ v3/v4 พัง ]
-- โมเดลไม่มี Humanoid ใช้ Attribute แทน (ของจริง: Dead=false, Health=100)
-- ============================================================
local function aliveModel(model)
    if model == nil then return false end
    local okPar, inWs = pcall(function()
        return model:IsDescendantOf(Workspace)
    end)
    if not okPar or not inWs then return false end
    -- 1) Attribute หลักของเกม
    local okA, dead, hp = pcall(function()
        return model:GetAttribute("Dead"), model:GetAttribute("Health")
    end)
    if okA then
        if dead == true then return false end
        if typeof(hp) == "number" and hp <= 0 then return false end
        -- ถ้ามี attribute ครบก็ถือว่ารอด (กันเคส Health=nil ตอนเกิด)
        if dead == false then return true end
        if typeof(hp) == "number" and hp > 0 then return true end
    end
    -- 2) fallback เผื่อบางโมเดลมี Humanoid/ForceField
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum ~= nil then
        if hum.Health <= 0 then return false end
    end
    if model:FindFirstChildOfClass("ForceField") ~= nil then return false end
    return true
end

-- ============================================================
-- [ HELPERS ]
-- ============================================================
local function getCamera()
    return Workspace.CurrentCamera
end

-- จุดเล็งจริงของเม้าส์ (pointer lock อยู่กลางจอ = กลางจอ, ไม่ lock = ตำแหน่ง cursor)
local function getAimPoint()
    local cam = getCamera()
    if cam == nil then return nil end
    local ok, ml = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and typeof(ml) == "Vector2" then return ml end
    local vs = cam.ViewportSize
    return Vector2.new(vs.X * 0.5, vs.Y * 0.5)
end

-- ทีมของโมเดล: อ่านจากตัวโมเดลก่อน (บอทมี Team บนตัว) ไม่มีค่อยตามหาเจ้าของ
local function modelTeam(model)
    local team = nil
    pcall(function() team = model:GetAttribute("Team") end)
    if team ~= nil and team ~= "" then return team end
    local owner = nil
    pcall(function() owner = model:GetAttribute("PresentationOwnerUserId") end)
    local plr = nil
    if typeof(owner) == "number" then
        plr = Players:GetPlayerByUserId(owner)
    end
    if plr == nil then
        plr = Players:FindFirstChild(model.Name)
    end
    if plr ~= nil then
        pcall(function() team = plr:GetAttribute("Team") end)
    end
    return team
end

-- โมเดลนี้ใช่ศัตรูไหม (เทียบกับทีมเรา)
local function isEnemyModel(model, myTeam, isDM)
    if not Cfg.TeamCheck or isDM then return true end
    local t = modelTeam(model)
    if t == nil or t == "" then
        -- ไม่รู้ทีม: บอทให้ยิงได้ (กันบอทศัตรูหลุด), คนไม่รู้ทีมข้ามไปก่อน
        local isBot = false
        pcall(function() isBot = model:GetAttribute("Bot") == true end)
        return isBot and Cfg.TargetBots
    end
    if myTeam == nil or myTeam == "" then return true end
    return t ~= myTeam
end

-- ============================================================
-- [ TRIGGERBOT - เป้าเข้าวง FOV -> ลั่นเอง ]
-- ใช้ candidates เดียวกับ silent aim (อ้างอิงตำแหน่งเม้าส์จริง)
-- มีเป้าในวง = กดยิงค้าง, เป้าหมด = ปล่อย
-- ============================================================
local getCandidates -- forward: ตัวจริงอยู่ด้านล่าง (trigger + wrap ใช้ร่วมกัน)
local tbHolding = false
local tbFirstSeen = 0
local tbLastSpam = 0

local function pressBtn()
    if tbHolding then return end
    local ok = pcall(function() mouse1press() end)
    if ok then
        tbHolding = true
        Stats.triggerPulls += 1
    end
end

local function releaseBtn()
    if not tbHolding then return end
    pcall(function() mouse1release() end)
    tbHolding = false
end

-- เป้าอยู่ในวง FOV ไหม (ใช้ candidates เดียวกับ silent aim, คืน part หรือ nil)
local function fovTarget()
    if type(getCandidates) ~= "function" then return nil end
    local ok, cands = pcall(getCandidates)
    if not ok or cands == nil then return nil end
    for _, c in ipairs(cands) do
        if c ~= nil and c.part ~= nil then
            if Cfg.TriggerPart == "Any" or c.part.Name == Cfg.TriggerPart then
                return c.part
            end
        end
    end
    return nil
end
G.__SA_centerTarget = fovTarget

local function triggerScan()
    if not (Cfg.Enabled and Cfg.Triggerbot and HasMouseFn) then
        if tbHolding then releaseBtn() end
        tbFirstSeen = 0
        return
    end
    local now = os.clock()
    local tgt = nil
    pcall(function() tgt = fovTarget() end)
    if tgt ~= nil then
        if tbFirstSeen == 0 then tbFirstSeen = now end
        if (now - tbFirstSeen) * 1000 >= Cfg.ReactionMs then
            if Cfg.TriggerMode == "Spam" and HasClickFn then
                -- ปืนกึ่งอัตโนมัติ: กดค้างนัดเดียวไม่พอ ต้องคลิกย้ำ
                if tbHolding then releaseBtn() end
                if (now - tbLastSpam) * 1000 >= Cfg.SpamMs then
                    tbLastSpam = now
                    local okC = pcall(function() mouse1click() end)
                    if okC then Stats.triggerPulls += 1 end
                end
            else
                pressBtn()
            end
        end
    else
        tbFirstSeen = 0
        if tbHolding then releaseBtn() end
    end
end

-- ============================================================
-- [ BULLET.CREATE WRAP - หัวใจของ silent aim ]
-- เกมส่งไปเซิร์ฟเวอร์แค่ Origin+Direction (ShootWeapon packet)
-- เซิร์ฟเวอร์ยิงจำลองเอง -> ต้องบิด r.Direction ไปหาหัวตรงนี้
-- หลักฐาน: ReplicatedStorage.Components.Weapon ส่ง Bullets={Direction,Origin}
-- ============================================================
local function wrapBullet()
    if BulletMod == nil then return end
    if BulletMod.create == G.__bulletWrap then return end
    local orig = BulletMod.create
    if type(orig) ~= "function" then return end
    G.__bulletOrig = orig
    local function wrapped(self, a2, a3)
        local r = orig(self, a2, a3)
        Stats.createCalls += 1
        -- บิดทิศทั้งก้อนด้วย pcall: ห้าม error ออกไปเด็ดขาด ปืนต้องยิงออกเสมอ
        if r ~= nil and r.Origin ~= nil and r.Direction ~= nil
        and Cfg.Enabled and math.random(1, 100) <= Cfg.HitChance then
            pcall(function()
                if type(getCandidates) ~= "function" then return end
                local cands = getCandidates()
                local c = cands[1]
                if c == nil then return end
                local okPos, partPos = pcall(function() return c.part.Position end)
                if not okPos or typeof(partPos) ~= "Vector3" then return end
                local toT = partPos - r.Origin
                if toT.Magnitude < 0.5 then return end
                -- คงขนาด Direction เดิมไว้ (เซิร์ฟเวอร์คูณระยะต่อเอง)
                r.Direction = toT.Unit * r.Direction.Magnitude
                r.Distance = toT.Magnitude
                Stats.redirected += 1
            end)
        end
        return r
    end
    G.__bulletWrap = wrapped
    pcall(function() BulletMod.create = wrapped end)
end

-- ============================================================
-- [ CANDIDATES - เลือกเป้าฉลาด: โมเดลทุกตัวในเกมที่ใกล้เม้าส์ที่สุด ]
--  - วน Workspace.Characters ตรง ๆ (เจอทั้งผู้เล่นจริง + บอท)
--  - ข้ามศพ (Dead/Health) ทุกนัด ไม่ล็อกตัวเดิมที่ตายแล้ว
--  - อ้างอิงตำแหน่งเม้าส์จริง ไม่ใช่กลางจอเสมอไป
--  - คะแนน: ใกล้เม้าส์สุดได้ก่อน, หัวมาก่อนลำตัว, ระยะใกล้ช่วยตัดเสมอ
-- ============================================================
getCandidates = function()
    local cam = getCamera()
    if cam == nil then return {} end
    local folder = getCharsFolder()
    if folder == nil then return {} end
    local aimPt = getAimPoint()
    if aimPt == nil then return {} end

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer:GetAttribute("Team") end)
    local gm = nil
    pcall(function() gm = Workspace:GetAttribute("Gamemode") end)
    local isDM = (gm == "Deathmatch")

    local camPos = nil
    pcall(function() camPos = cam.CFrame.Position end)

    -- part หลักที่ผู้ใช้เลือกขึ้นก่อนเสมอ
    local order = { Cfg.TargetPart }
    for _, p in ipairs(FALLBACK_PARTS) do
        if p ~= Cfg.TargetPart then
            table.insert(order, p)
        end
    end

    local myName, myUid = LocalPlayer.Name, LocalPlayer.UserId
    local list = {}

    for _, model in ipairs(folder:GetChildren()) do
        if not model:IsA("Model") then continue end
        -- ข้ามตัวเอง (เช็คทั้งชื่อ + owner id กันชื่อซ้ำ)
        if model.Name == myName then continue end
        local isMe = false
        pcall(function()
            isMe = model:GetAttribute("PresentationOwnerUserId") == myUid
        end)
        if isMe then continue end
        -- ข้ามบอทถ้าปิดไว้
        if not Cfg.TargetBots then
            local isBot = false
            pcall(function() isBot = model:GetAttribute("Bot") == true end)
            if isBot then continue end
        end
        -- ข้ามศพ/เลือดหมด (เช็คทุกนัด -> ไม่ล็อกตัวเดิมที่ตายแล้ว)
        if not aliveModel(model) then continue end
        -- ข้ามเพื่อนร่วมทีม
        if not isEnemyModel(model, myTeam, isDM) then continue end

        for idx, pname in ipairs(order) do
            local part = model:FindFirstChild(pname)
            if part ~= nil and part:IsA("BasePart") then
                local okW, sp, onScreen = pcall(function()
                    return cam:WorldToViewportPoint(part.Position)
                end)
                if okW and onScreen then
                    local d2d = (Vector2.new(sp.X, sp.Y) - aimPt).Magnitude
                    if d2d <= Cfg.FOV then
                        local d3d = 0
                        if camPos ~= nil then
                            local okD, dd = pcall(function()
                                return (part.Position - camPos).Magnitude
                            end)
                            if okD and typeof(dd) == "number" then d3d = dd end
                        end
                        -- หัว (+0) มาก่อนลำตัว (+15/+30), ระยะใกล้ช่วยตัดเสมอ (+0.02/ม.)
                        table.insert(list, {
                            part  = part,
                            char  = model,
                            score = d2d + (idx - 1) * 15 + d3d * 0.02,
                        })
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.score < b.score end)
    return list
end

-- ============================================================
-- [ ESP - กรอบมุม + ชื่อ + เลือด ]
-- ไม่แลค: สร้างวัตถุครั้งเดียวแล้ว reuse (pool ต่อโมเดล),
-- อัปเดตแค่ทุก 4 เฟรม (~15Hz), ตัดตัวไกลทิ้งก่อนวาด
-- ============================================================
local ESPPool = {}
G.__ESP_objs = ESPPool

local function espNewLine()
    local l = Drawing.new("Line")
    l.Visible = false
    l.Thickness = 1.5
    l.Transparency = 0.9
    return l
end

local function espGet(model)
    local e = ESPPool[model]
    if e ~= nil then return e end
    e = { corners = {}, all = {} }
    for i = 1, 8 do
        e.corners[i] = espNewLine()
        table.insert(e.all, e.corners[i])
    end
    e.barBg = espNewLine()
    e.barBg.Color = Color3.fromRGB(0, 0, 0)
    e.barBg.Thickness = 3
    e.barFill = espNewLine()
    e.barFill.Thickness = 3
    table.insert(e.all, e.barBg)
    table.insert(e.all, e.barFill)
    local t = Drawing.new("Text")
    t.Visible = false
    t.Size = 13
    t.Center = true
    t.Outline = true
    t.Transparency = 0.9
    e.name = t
    table.insert(e.all, t)
    ESPPool[model] = e
    return e
end

local function espHide(e)
    for _, o in ipairs(e.all) do
        pcall(function() o.Visible = false end)
    end
end

local function espColorOf(model)
    local t = modelTeam(model)
    if t == "Counter-Terrorists" then return Color3.fromRGB(90, 175, 255) end
    if t == "Terrorists" then return Color3.fromRGB(255, 120, 60) end
    return Color3.fromRGB(255, 235, 90)
end

local function espDraw(e, x, y, w, h, color, label, hpFrac)
    -- กรอบมุม 4 มุม (มุมละ 2 เส้น = 8 เส้น)
    local cl = math.clamp(math.min(w, h) * 0.28, 4, 18)
    local x2, y2 = x + w, y + h
    local pts = {
        { Vector2.new(x, y), Vector2.new(x + cl, y) },
        { Vector2.new(x, y), Vector2.new(x, y + cl) },
        { Vector2.new(x2 - cl, y), Vector2.new(x2, y) },
        { Vector2.new(x2, y), Vector2.new(x2, y + cl) },
        { Vector2.new(x, y2 - cl), Vector2.new(x, y2) },
        { Vector2.new(x, y2), Vector2.new(x + cl, y2) },
        { Vector2.new(x2 - cl, y2), Vector2.new(x2, y2) },
        { Vector2.new(x2, y2 - cl), Vector2.new(x2, y2) },
    }
    for i, s in ipairs(pts) do
        local l = e.corners[i]
        l.From = s[1]
        l.To = s[2]
        l.Color = color
        l.Visible = Cfg.ESPBox
    end
    -- แถบเลือดข้างซ้ายกรอบ
    if Cfg.ESPHealth then
        e.barBg.From = Vector2.new(x - 5, y)
        e.barBg.To = Vector2.new(x - 5, y2)
        e.barBg.Visible = true
        local fy = y2 - h * hpFrac
        e.barFill.From = Vector2.new(x - 5, y2)
        e.barFill.To = Vector2.new(x - 5, fy)
        e.barFill.Color = Color3.fromRGB(math.floor(255 * (1 - hpFrac)), math.floor(255 * hpFrac), 40)
        e.barFill.Visible = true
    else
        e.barBg.Visible = false
        e.barFill.Visible = false
    end
    -- ชื่อเหนือกรอบ
    if Cfg.ESPName then
        e.name.Text = label
        e.name.Position = Vector2.new(x + w * 0.5, math.max(12, y - 16))
        e.name.Color = color
        e.name.Visible = true
    else
        e.name.Visible = false
    end
end

-- project แบบกันหลุดขอบ: คืน nil ถ้าอยู่หลังกล้อง, ไม่งั้นคืนตำแหน่ง + บอกว่าอยู่ในจอไหม
local function espProj(cam, pos, vs)
    local relOk, rel = pcall(function() return cam.CFrame:PointToObjectSpace(pos) end)
    if not relOk or rel.Z >= 0 then return nil end -- หลังกล้อง
    local okW, sp = pcall(function() return cam:WorldToViewportPoint(pos) end)
    if not okW then return nil end
    local v2 = Vector2.new(sp.X, sp.Y)
    local on = v2.X >= 0 and v2.X <= vs.X and v2.Y >= 0 and v2.Y <= vs.Y
    return v2, on
end

local _espTick = 0
local function espUpdate()
    local cam = getCamera()
    if cam == nil then return end
    if not (Cfg.Enabled and Cfg.ESP) then
        for _, e in pairs(ESPPool) do espHide(e) end
        return
    end
    local folder = getCharsFolder()
    if folder == nil then return end
    local camPos = cam.CFrame.Position
    local myTeam = nil
    pcall(function() myTeam = LocalPlayer:GetAttribute("Team") end)
    local gm = nil
    pcall(function() gm = Workspace:GetAttribute("Gamemode") end)
    local isDM = (gm == "Deathmatch")
    local seen = {}
    for _, model in ipairs(folder:GetChildren()) do
        if not model:IsA("Model") then continue end
        if model.Name == LocalPlayer.Name then continue end
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp == nil or not hrp:IsA("BasePart") then continue end
        -- ตัดระยะก่อน (ถูกสุด) กันเสียเวลากับตัวไกล
        local dist = 0
        local okD, dd = pcall(function() return (hrp.Position - camPos).Magnitude end)
        if okD and typeof(dd) == "number" then dist = dd end
        if dist > Cfg.ESPMaxDist then continue end
        if not aliveModel(model) then continue end
        if not isEnemyModel(model, myTeam, isDM) then continue end
        local head = model:FindFirstChild("Head")
        local top3d
        if head ~= nil and head:IsA("BasePart") then
            top3d = head.Position + Vector3.new(0, 1, 0)
        else
            top3d = hrp.Position + Vector3.new(0, 3, 0)
        end
        local bot3d = hrp.Position - Vector3.new(0, 3.4, 0)
        local vs = cam.ViewportSize
        local tP, tOn = espProj(cam, top3d, vs)
        local bP, bOn = espProj(cam, bot3d, vs)
        if tP == nil or bP == nil then continue end -- หลังกล้อง
        if not tOn and not bOn then continue end -- หลุดจอทั้งตัว
        -- clamp ให้อยู่ในจอ: เห็นแค่หัวหรือแค่ขาก็ยังวาด
        local topY = math.clamp(tP.Y, 0, vs.Y)
        local botY = math.clamp(bP.Y, 0, vs.Y)
        local h = botY - topY
        if h < 8 or h > 2000 then continue end
        local w = h * 0.55
        local cx = (tP.X + bP.X) * 0.5
        if cx + w * 0.5 < -20 or cx - w * 0.5 > vs.X + 20 then continue end
        local bx = math.clamp(cx - w * 0.5, -20, vs.X + 20)
        local hp, maxhp = 100, 100
        pcall(function()
            local a, b = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
            if typeof(a) == "number" then hp = a end
            if typeof(b) == "number" and b > 0 then maxhp = b end
        end)
        local frac = math.clamp(hp / maxhp, 0, 1)
        local e = espGet(model)
        seen[model] = true
        espDraw(e, bx, topY, w, h, espColorOf(model),
            model.Name .. " [" .. math.floor(dist + 0.5) .. "m]", frac)
    end
    for model, e in pairs(ESPPool) do
        if not seen[model] then
            espHide(e)
            -- โมเดลหาย (ตาย/จบรอบ) -> ทิ้งวัตถุ กัน pool โตไม่หยุด
            local gone = false
            pcall(function() gone = model.Parent == nil end)
            if gone then
                for _, o in ipairs(e.all) do pcall(function() o:Remove() end) end
                ESPPool[model] = nil
            end
        end
    end
end

-- ============================================================
-- [ FOV CIRCLE ]
-- ============================================================
local circle        = Drawing.new("Circle")
circle.Color        = Color3.fromRGB(255, 80, 80)
circle.Thickness    = 1.5
circle.Filled       = false
circle.Transparency = 0.85
circle.Visible      = true
G.__SA_circle       = circle

G.__SA_loop = RunService.RenderStepped:Connect(function()
    local cam = getCamera()
    if cam then
        local aimPt = getAimPoint()
        if aimPt ~= nil then
            circle.Position = aimPt
        else
            local vs = cam.ViewportSize
            circle.Position = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
        end
        circle.Radius   = Cfg.FOV
        circle.Visible  = Cfg.Enabled and Cfg.ShowFOV
    else
        circle.Visible = false
    end
    -- ESP อัปเดตทุก 4 เฟรม (~15Hz) กันแลค
    _espTick += 1
    if _espTick >= 4 then
        _espTick = 0
        pcall(espUpdate)
    end
end)

-- ============================================================
-- [ ACTIVATE ] ห่อ Bullet.create ตอนนี้ (getCandidates พร้อมแล้ว)
-- ไม่ใช้ __namecall hook แล้ว: เซิร์ฟเวอร์ไม่เห็นผล raycast local
-- ============================================================
wrapBullet()
G.__SA_origNC = nil

-- ============================================================
-- [ HEARTBEAT: watchdog + triggerbot สแกนกลางจอ ]
-- ============================================================
local _watchTick = 0
G.__SA_hbLoop = RunService.Heartbeat:Connect(function()
    _watchTick += 1
    if _watchTick >= 300 then
        _watchTick = 0
        if BulletMod ~= nil and BulletMod.create ~= G.__bulletWrap then
            wrapBullet()
        end
    end
    -- triggerbot สแกนทุกเฟรม (ข้างใน throttle 30ms เอง)
    local ok = pcall(triggerScan)
    if not ok and tbHolding then
        pcall(releaseBtn)
    end
end)
-- เก็บ handle เดียวกันไว้ทั้งสองชื่อ กันสับสนตอน cleanup
G.__TB_loop = G.__SA_hbLoop

-- ============================================================
-- [ WINDUI - Theme White / RightShift ตามมาตรฐานโปรเจกต์ ]
-- ============================================================
local okUI, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()
end)

if okUI and WindUI ~= nil then
    pcall(function()
        local Window
        -- ลอง White ก่อนตามมาตรฐานโปรเจกต์ ถ้า WindUI เวอร์ชันนี้ไม่มี White ให้ตกไป Dark
        local okW = pcall(function()
            Window = WindUI:CreateWindow({
                Title     = "BloxStrike Silent",
                Icon      = "crosshair",
                Author    = "v6-trigger",
                Folder    = "BloxSilent",
                Size      = UDim2.fromOffset(440, 520),
                Theme     = "White",
                ToggleKey = Enum.KeyCode.RightShift,
            })
        end)
        if Window == nil then
            Window = WindUI:CreateWindow({
                Title     = "BloxStrike Silent",
                Icon      = "crosshair",
                Author    = "v6-trigger",
                Folder    = "BloxSilent",
                Size      = UDim2.fromOffset(440, 520),
                Theme     = "Dark",
                ToggleKey = Enum.KeyCode.RightShift,
            })
        end
        G.__SA_window = Window

    local Tab = Window:Tab({ Title = "Aim", Icon = "crosshair" })

    Tab:Toggle({
        Title    = "Enabled",
        Value    = true,
        Callback = function(s) Cfg.Enabled = s end,
    })
    Tab:Slider({
        Title    = "FOV px",
        Value    = { Min = 40, Max = 500, Default = 300 },
        Step     = 5,
        Callback = function(v) Cfg.FOV = v end,
    })
    Tab:Dropdown({
        Title    = "Target Part (หลัก)",
        Values   = { "Head", "UpperTorso", "HumanoidRootPart" },
        Value    = "Head",
        Callback = function(v) Cfg.TargetPart = v end,
    })
    Tab:Toggle({
        Title    = "Team Check",
        Value    = true,
        Callback = function(s) Cfg.TeamCheck = s end,
    })
    Tab:Toggle({
        Title    = "Target Bots",
        Value    = true,
        Callback = function(s) Cfg.TargetBots = s end,
    })
    Tab:Toggle({
        Title    = "Triggerbot (เข้า FOV=ยิงเอง)",
        Value    = true,
        Callback = function(s)
            Cfg.Triggerbot = s
            if not s then releaseBtn() end
        end,
    })
    Tab:Slider({
        Title    = "Reaction ms",
        Value    = { Min = 0, Max = 400, Default = 0 },
        Step     = 10,
        Callback = function(v) Cfg.ReactionMs = v end,
    })
    Tab:Dropdown({
        Title    = "Trigger Mode",
        Values   = { "Hold", "Spam" },
        Value    = "Spam",
        Callback = function(v)
            Cfg.TriggerMode = v
            if tbHolding then releaseBtn() end
        end,
    })
    Tab:Slider({
        Title    = "Spam ms (โหมด Spam)",
        Value    = { Min = 40, Max = 250, Default = 50 },
        Step     = 10,
        Callback = function(v) Cfg.SpamMs = v end,
    })
    Tab:Dropdown({
        Title    = "Trigger Part",
        Values   = { "Any", "Head", "UpperTorso", "HumanoidRootPart" },
        Value    = "Any",
        Callback = function(v) Cfg.TriggerPart = v end,
    })
    Tab:Slider({
        Title    = "Hit Chance %",
        Value    = { Min = 0, Max = 100, Default = 100 },
        Step     = 1,
        Callback = function(v) Cfg.HitChance = v end,
    })
    Tab:Toggle({
        Title    = "Show FOV circle",
        Value    = true,
        Callback = function(s) Cfg.ShowFOV = s end,
    })
    Tab:Button({
        Title    = "Stats",
        Callback = function()
            pcall(function()
                WindUI:Notify({
                    Title   = "Silent stats",
                    Content = ("shots=%d redir=%d pulls=%d")
                        :format(Stats.createCalls, Stats.redirected, Stats.triggerPulls),
                    Duration = 5,
                })
            end)
        end,
    })

    local ESPTab = Window:Tab({ Title = "ESP", Icon = "eye" })

    ESPTab:Toggle({
        Title    = "ESP",
        Value    = true,
        Callback = function(s) Cfg.ESP = s end,
    })
    ESPTab:Toggle({
        Title    = "Box (กรอบมุม)",
        Value    = true,
        Callback = function(s) Cfg.ESPBox = s end,
    })
    ESPTab:Toggle({
        Title    = "Name + ระยะ",
        Value    = true,
        Callback = function(s) Cfg.ESPName = s end,
    })
    ESPTab:Toggle({
        Title    = "แถบเลือด",
        Value    = true,
        Callback = function(s) Cfg.ESPHealth = s end,
    })
    ESPTab:Slider({
        Title    = "ระยะสูงสุด",
        Value    = { Min = 100, Max = 1500, Default = 600 },
        Step     = 50,
        Callback = function(v) Cfg.ESPMaxDist = v end,
    })
    end)
end

if not HasMouseFn then
    warn("[silent-aim] triggerbot ปิด: executor ไม่มี mouse1press/mouse1release (silent aim ยังทำงาน)")
    Cfg.Triggerbot = false
end

print(("[silent-aim] v6-trigger loaded | FOV=%d | trigger=%s(%s) reaction=%dms | esp=%s | hitChance=%d%%")
    :format(Cfg.FOV, tostring(Cfg.Triggerbot), Cfg.TriggerMode, Cfg.ReactionMs, tostring(Cfg.ESP), Cfg.HitChance))
