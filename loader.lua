-- =====================================================================
-- GLAXUS HUB | Universal Loader + Loading + Game Selector (v3 Mono)
-- File: loader.lua (วางไว้ที่ root ของโปรเจกต์ คู่กับโฟลเดอร์ Games/)
-- Type: Single-file | Status: Ready to run
-- ---------------------------------------------------------------------
-- วิธีใช้ (รันใน Executor แค่บรรทัดเดียว):
--
--   1) แบบไฟล์ local (เทสในเครื่องตัวเอง):
--      loadstring(readfile("loader.lua"))()
--
--   2) แบบลิงก์ GitHub (หลัง push ขึ้น repo แล้ว):
--      loadstring(game:HttpGet("https://raw.githubusercontent.com/kanrawee56/Glaxus_hub/main/loader.lua"))()
--
-- พฤติกรรม:
--   [Loading 2-3s] -> [Key Gate] -> [Auto-detect PlaceId]
--     - ใส่รหัสผิดเกิน MAX_ATTEMPTS -> ปิดสคริปต์ทิ้ง (+เตะออกถ้าเปิด KICK_ON_FAIL)
--     - ถ้าเจอเกมในลิสต์ + AUTO_LOAD = true -> โหลด main.lua ของแมพนั้นทันที
--     - ถ้าไม่เจอ / ตั้ง FORCE_MENU = true -> โชว์ UI เลือกเกม กดปุ่มไหนก็โหลดแมพนั้น
-- ---------------------------------------------------------------------
-- 🔒 เรื่องกันดูซอร์ส (อ่านก่อน!):
--   1) รหัสผ่านในไฟล์นี้กันได้แค่ "คนไม่มีรหัสใช้ไม่ได้" แต่กันคนแกะไฟล์ไม่ได้
--      เพราะใครเปิด loader.lua ก็เห็นรหัส -> ก่อนแจกต้องเอาไป obfuscate ก่อน
--      (Panda มี obfuscator ฟรีให้) แล้วแจกเฉพาะตัวที่ obfuscate แล้ว
--   2) ห้าม push โฟลเดอร์ Games/ ขึ้น public repo ถ้ากลัวโดนดูดสคริปต์
--   3) Panda service "glaxushub" สร้างแล้ว -> ต่อ loader snippet ที่ได้มาใน [2.2]
-- =====================================================================

-- =====================================================================
-- [1] KILLSWITCH (ล้าง instance เก่าก่อนรันใหม่)
-- =====================================================================
local G = getgenv()
if G.__EsaHub_Cleanup then
    pcall(G.__EsaHub_Cleanup)
end
G.__EsaHub_Cleanup = nil

-- =====================================================================
-- [2] CONFIG
-- =====================================================================
local BASE_URL = "https://raw.githubusercontent.com/kanrawee56/Glaxus_hub/main/"
-- ต้องลงท้ายด้วย "/" เสมอ ถ้ายังไม่ push ให้ปล่อย "" ไว้ (จะใช้โหมด readfile local อย่างเดียว)

local AUTO_LOAD = true -- ถ้า PlaceId ตรงกับเกมในลิสต์ ให้โหลดทันที ไม่ต้องกด
-- อยากบังคับโชว์เมนูทุกครั้ง (ไม่ auto): รัน getgenv().EsaHub_ForceMenu = true ก่อนโหลด

local LOADING_TIME = 2.8 -- วินาทีของหน้า loading

-- =====================================================================
-- [2.1] OWNER KEY (กุญแจฉุกเฉินเจ้าของใบเดียว — ที่เหลือ Panda จัดการหมด)
-- =====================================================================
local OWNER_KEY = "GLAXUS-CHANGE-ME" -- <<<<<< เปลี่ยนก่อนแจกทุกครั้ง
local MAX_ATTEMPTS = 5
local KICK_ON_FAIL = false
local KICK_MSG = "Invalid key."

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getHwid()
    if typeof(gethwid) == "function" then
        local ok, id = pcall(gethwid)
        if ok and id then
            return tostring(id)
        end
    end
    return nil
end

-- =====================================================================
-- [2.2] 💰 PANDA KEY SYSTEM (service: glaxushub)
-- วิธีต่อ: สร้าง service เสร็จ -> เอา loader snippet / service ID ที่ Panda ให้มา
-- ใส่ข้างล่าง แล้วตั้ง PANDA_ENABLED = true
-- =====================================================================
local PANDA_ENABLED = true -- <<<<<< true = จอรหัสตรวจคีย์กับ Panda
local PANDA_SERVICE_ID = "glaxushub" -- identifier จากแท็บ Hub Details (ของเราคือ glaxushub)
local PANDA_GETKEY_URL = "https://ads.pandauth.com/getkey/glaxushub" -- หน้าคีย์ตาม docs Panda (เติม ?hwid= ให้อัตโนมัติในโค้ด)

local PUSL_LIB_URL = "https://secure.pandauth.com/pv4/lib" -- Panda-RBLX SDK (PUSL-V4, ตัวปัจจุบัน)
local PANDA_KEY_FILE = "glaxus_key.txt" -- จำคีย์ที่ผ่านแล้ว (รันรอบหน้าไม่ต้องกรอกใหม่)

local pusl = nil
local puslService = nil
local function getPUSL()
    if pusl and puslService == pandaService() then
        return pusl
    end
    local ok, src = pcall(function() return game:HttpGet(PUSL_LIB_URL) end)
    print("[Glaxus] lib fetch:", ok, type(src), src and #src or 0)
    if not ok or type(src) ~= "string" or #src < 100 then
        return nil
    end
    local ok2, lib = pcall(function() return loadstring(src)() end)
    print("[Glaxus] lib init:", ok2, type(lib))
    if not ok2 or type(lib) ~= "table" or type(lib.configure) ~= "function" then
        return nil
    end
    local ok3 = pcall(function()
        lib.configure({ serviceId = pandaService(), debug = false, kickOnDetect = false })
    end)
    print("[Glaxus] configure:", ok3)
    if not ok3 then
        return nil
    end
    pusl, puslService = lib, pandaService()
    return pusl
end

local function pandaService()
    if PANDA_SERVICE_ID ~= "" then
        return PANDA_SERVICE_ID
    end
    return "glaxushub"
end

-- ตรวจคีย์กับ Panda: "valid" / "invalid" / "transient:<reason>" / "error"
-- (มีแค่ INVALID_KEY = คีย์ผิดจริง ที่เหลือคือเน็ต/เรทลิมิต -> retry ไม่นับครั้ง)
local function pandaValidate(input)
    local api = getPUSL()
    if not api then
        return "error"
    end
    local final = "error"
    for attempt = 1, 4 do
        local ok, res = pcall(function() return api.validate(input) end)
        print("[Glaxus] validate try", attempt, ok, type(res), res and res.success, res and (res.reason or res.error))
        if ok and type(res) == "table" then
            if res.success then
                return "valid"
            end
            local reason = tostring(res.reason or res.error or "unknown")
            if reason == "INVALID_KEY" then
                return "invalid"
            end
            final = reason
        end
        if attempt < 4 then
            task.wait(attempt * 2)
        end
    end
    if final == "error" then
        return "error"
    end
    return "transient:" .. final
end

local function saveKey(input)
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(PANDA_KEY_FILE, input)
        end
    end)
end

local function loadSavedKey()
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local ok, has = pcall(function() return isfile(PANDA_KEY_FILE) end)
        if ok and has then
            local ok2, content = pcall(function() return readfile(PANDA_KEY_FILE) end)
            if ok2 and type(content) == "string" then
                content = trim(content)
                if #content > 3 then
                    return content
                end
            end
        end
    end
    return nil
end

local function checkPandaKey(input)
    if input == OWNER_KEY then
        return true, "owner"
    end
    local st = pandaValidate(input)
    if st == "valid" then
        saveKey(input) -- จำไว้ รอบหน้าเข้าเลยไม่ต้องกรอก
        return true, "panda"
    elseif st == "invalid" then
        return false, "Invalid, expired, or HWID-locked key"
    elseif st:sub(1, 10) == "transient:" then
        return false, "TRANSIENT:" .. st:sub(11)
    end
    return false, "TRANSIENT:network"
end

-- ลิงก์เอาคีย์ (ถาม SDK ก่อน ไม่ได้ค่อยใช้ลิงก์ตรง + แถม HWID)
local function pandaGetKeyLink()
    local api = getPUSL()
    if api and type(api.getKeyUrl) == "function" then
        local ok, link = pcall(function() return api.getKeyUrl() end)
        if ok and type(link) == "string" and #link > 8 then
            return link
        end
    end
    local base = PANDA_GETKEY_URL
    if base == "" then
        base = "https://ads.pandauth.com/getkey/glaxushub"
    end
    local id = getHwid()
    if id and #id > 0 then
        return base .. "?hwid=" .. id
    end
    return base
end

-- ตรวจคีย์ระบบเดียว: Panda (+กุญแจเจ้าของ)
local function verifyKey(input)
    if input == OWNER_KEY then
        return true, "owner"
    end
    return checkPandaKey(input)
end

local function activeGetKeyUrl()
    return pandaGetKeyLink()
end

-- ลิสต์เกมทั้งหมด (ต้องตรงกับโฟลเดอร์ Games/<Folder>/Scripts/<File>)
local GAMES = {
    { name = "Warfare Tycoon",      placeId = 31490825,        folder = "WarfareTycoon_31490825",        file = "main.lua", icon = "WT" },
    { name = "Anime Battle Arena",  placeId = 1458767429,      folder = "ABA_1458767429",                file = "main.lua", icon = "AB" },
    { name = "MIC UP",              placeId = 6884319169,      folder = "MICUP_6884319169",              file = "main.lua", icon = "MU" },
    { name = "Cold War Vietnam",    placeId = 13687899540,     folder = "ColdWar_13687899540",           file = "main.lua", icon = "CW" },
    { name = "Jujutsu Shenanigans", placeId = 9391468976,      folder = "JujutsuShenanigans_9391468976", file = "main.lua", icon = "JS" },
    { name = "King Legacy",         placeId = 1451439645,      folder = "KingLegacy_1451439645",         file = "main.lua", icon = "KL" },
    { name = "BloxStrike",          placeId = 114234929420007, folder = "BloxStrike_114234929420007",    file = "Main.lua", icon = "BS" },
    { name = "Ride A Pet",          placeId = 124216119978534, folder = "Ride_A_Pet_124216119978534",    file = "main.lua", icon = "RP" },
    { name = "Slayer 2",            placeId = 136406881576517, folder = "Slayer_2_136406881576517",      file = "main.lua", icon = "S2" },
    { name = "Steal An Egg",        placeId = 107778070777162, folder = "Steal_An_Egg_107778070777162",  file = "main.lua", icon = "SE" },
}

-- =====================================================================
-- [3] SERVICES + THEME
-- =====================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local CURRENT_PLACE = game.PlaceId

local function findGame(pid)
    for _, g in ipairs(GAMES) do
        if g.placeId == pid then
            return g
        end
    end
    return nil
end

-- -- palette: monochrome ขาวดำ --
local C = {
    bg      = Color3.fromRGB(5, 5, 7),
    panel   = Color3.fromRGB(14, 14, 17),
    card    = Color3.fromRGB(24, 24, 29),
    cardHi  = Color3.fromRGB(38, 38, 45),
    line    = Color3.fromRGB(70, 70, 80),
    txt     = Color3.fromRGB(245, 245, 247),
    dim     = Color3.fromRGB(170, 170, 180),
    faint   = Color3.fromRGB(110, 110, 120),
    mint    = Color3.fromRGB(255, 255, 255), -- accent หลัก: ขาว
    cyan    = Color3.fromRGB(200, 200, 210), -- accent รอง: เงิน
    violet  = Color3.fromRGB(120, 120, 135), -- accent เสริม: เทา
    gold    = Color3.fromRGB(255, 255, 255),
    red     = Color3.fromRGB(150, 150, 160), -- error โทนเทา (คงธีมขาวดำ)
    green   = Color3.fromRGB(255, 255, 255),
}

local GRAD_MAIN = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 190, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 110, 125)),
})

-- =====================================================================
-- [3.1] UI HELPERS
-- =====================================================================
local hui = (typeof(gethui) == "function" and gethui())
    or (typeof(get_hidden_gui) == "function" and get_hidden_gui())
    or game:GetService("CoreGui")

local rootGui = Instance.new("ScreenGui")
rootGui.Name = "GlaxusHub"
rootGui.ResetOnSpawn = false
rootGui.IgnoreGuiInset = true
rootGui.DisplayOrder = 999
rootGui.Parent = hui

local conns = {}
local function addConn(c)
    table.insert(conns, c)
    return c
end

G.__EsaHub_Cleanup = function()
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
    pcall(function() rootGui:Destroy() end)
    G.__EsaHub_Cleanup = nil
end

-- factory: mk("TextLabel", {Text="hi", ...}, parent)
local function mk(className, props, parent)
    local o = Instance.new(className)
    props = props or {}
    local par = parent or props.Parent
    props.Parent = nil
    for k, v in pairs(props) do
        pcall(function() o[k] = v end)
    end
    o.Parent = par
    return o
end

local function corner(o, r)
    return mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end

local function stroke(o, color, thick, transp)
    return mk("UIStroke", {
        Color = color or C.line,
        Thickness = thick or 1,
        Transparency = transp == nil and 0.5 or transp,
    }, o)
end

local function grad(o, seq, rot)
    return mk("UIGradient", {
        Color = seq or GRAD_MAIN,
        Rotation = rot or 90,
    }, o)
end

-- การ์ดขอบ gradient: กรอบนอกไล่สี + ไส้ในสีเข้ม
local function panelCard(parent, size, pos, radius)
    radius = radius or 16
    local outer = mk("Frame", {
        Size = size, Position = pos,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, parent)
    corner(outer, radius)
    local g = grad(outer, GRAD_MAIN, 115)
    local inner = mk("Frame", {
        Size = UDim2.new(1, -3, 1, -3),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, outer)
    corner(inner, radius - 1)
    return outer, inner, g
end

-- pop-in animation (เด้งเข้า)
local function popIn(frame, dur)
    dur = dur or 0.35
    local sc = mk("UIScale", { Scale = 0.92 }, frame)
    TweenService:Create(sc, TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1,
    }):Play()
end

-- หมุน gradient วน (shimmer)
local function spinGrad(g, secs)
    secs = secs or 5
    task.spawn(function()
        while g.Parent do
            local tw = TweenService:Create(g, TweenInfo.new(secs, Enum.EasingStyle.Linear), { Rotation = 360 })
            tw:Play()
            tw.Completed:Wait()
            if g.Parent then
                g.Rotation = 0
            end
        end
    end)
end

-- สั่น (ใส่รหัสผิด)
local function shake(frame)
    local base = frame.Position
    task.spawn(function()
        for i = 1, 4 do
            local off = (i % 2 == 1) and 9 or -9
            TweenService:Create(frame, TweenInfo.new(0.05), {
                Position = base + UDim2.new(0, off, 0, 0),
            }):Play()
            task.wait(0.05)
        end
        TweenService:Create(frame, TweenInfo.new(0.08), { Position = base }):Play()
    end)
end

-- วงกลมเรืองแสงลอยพื้นหลัง
local function orb(parent, pos, size, color)
    local o = mk("Frame", {
        Size = size, Position = pos,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
    }, parent)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, o)
    task.spawn(function()
        local base = pos
        while o.Parent do
            local dir = math.random(2) == 1 and 30 or -30
            local tw = TweenService:Create(o, TweenInfo.new(4 + math.random() * 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Position = base + UDim2.new(0, dir, 0, -dir),
            })
            tw:Play()
            tw.Completed:Wait()
        end
    end)
    return o
end

-- =====================================================================
-- [4] LOADING SCREEN
-- =====================================================================
local loadingFrame = mk("Frame", {
    Name = "Loading",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
}, rootGui)

orb(loadingFrame, UDim2.new(0.22, 0, 0.28, 0), UDim2.new(0, 340, 0, 340), C.violet)
orb(loadingFrame, UDim2.new(0.8, 0, 0.72, 0), UDim2.new(0, 300, 0, 300), C.cyan)
orb(loadingFrame, UDim2.new(0.72, 0, 0.24, 0), UDim2.new(0, 180, 0, 180), C.mint)

local _, loadCard, loadGrad = panelCard(loadingFrame, UDim2.new(0, 430, 0, 330), UDim2.new(0.5, 0, 0.5, 0), 18)
spinGrad(loadGrad, 6)
popIn(loadCard and loadCard.Parent or loadingFrame)

-- โลโก้
local logo = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 52),
    Position = UDim2.new(0, 0, 0, 22),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 40,
    Text = "GLAXUS",
    TextColor3 = Color3.new(1, 1, 1),
}, loadCard)
grad(logo, GRAD_MAIN, 0)

mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 0, 72),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = "S C R I P T   H U B",
    TextColor3 = C.dim,
}, loadCard)

-- เส้นคั่น gradient
local divider = mk("Frame", {
    Size = UDim2.new(1, -80, 0, 2),
    Position = UDim2.new(0, 40, 0, 102),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, loadCard)
corner(divider, 2)
grad(divider, GRAD_MAIN, 0)

-- แถบโหลด
local barBg = mk("Frame", {
    Size = UDim2.new(1, -80, 0, 12),
    Position = UDim2.new(0, 40, 0, 132),
    BackgroundColor3 = Color3.fromRGB(30, 30, 37),
    BorderSizePixel = 0,
}, loadCard)
corner(barBg, 6)

local barFill = mk("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, barBg)
corner(barFill, 6)
local barGrad = grad(barFill, GRAD_MAIN, 0)
addConn(RunService.Heartbeat:Connect(function()
    if barFill.Parent then
        barGrad.Offset = Vector2.new((os.clock() * 0.35) % 1, 0)
    end
end))

local pctLabel = mk("TextLabel", {
    Size = UDim2.new(1, -80, 0, 22),
    Position = UDim2.new(0, 40, 0, 148),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextColor3 = C.txt,
    Text = "0%",
}, loadCard)

local statusLabel = mk("TextLabel", {
    Size = UDim2.new(1, -80, 0, 22),
    Position = UDim2.new(0, 40, 0, 172),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.dim,
    Text = "Starting...",
}, loadCard)

local tipLabel = mk("TextLabel", {
    Size = UDim2.new(1, -80, 0, 40),
    Position = UDim2.new(0, 40, 0, 200),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.faint,
    Text = "",
}, loadCard)

mk("TextLabel", {
    Size = UDim2.new(1, -80, 0, 18),
    Position = UDim2.new(0, 40, 1, -30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.faint,
    Text = "v3.2 DEBUG  •  PlaceId " .. tostring(CURRENT_PLACE),
}, loadCard)

local TIPS = {
    "Tip: press R-Shift to toggle the menu anytime",
    "Tip: keys are HWID locked and cannot be shared",
    "Tip: press GET KEY for a free key",
    "Glaxus Hub  •  10 Games Ready",
}

local function setStatus(t)
    statusLabel.Text = t
end

-- =====================================================================
-- [5] HUB UI (sidebar + การ์ดเกม)
-- =====================================================================
local detected = findGame(CURRENT_PLACE)

local hubOuter, hubFrame, hubGrad = panelCard(rootGui, UDim2.new(0, 640, 0, 520), UDim2.new(0.5, 0, 0.5, 0), 18)
hubOuter.Name = "Hub"
hubOuter.Visible = false
hubOuter.Active = true
hubOuter.Draggable = true
spinGrad(hubGrad, 8)

-- ซ้าย: sidebar
local side = mk("Frame", {
    Size = UDim2.new(0, 188, 1, -28),
    Position = UDim2.new(0, 14, 0, 14),
    BackgroundColor3 = Color3.fromRGB(9, 9, 12),
    BorderSizePixel = 0,
}, hubFrame)
corner(side, 12)
stroke(side, C.line, 1, 0.7)

-- โลโก้เล็ก
local logoTile = mk("Frame", {
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0, 14, 0, 14),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, side)
corner(logoTile, 12)
grad(logoTile, GRAD_MAIN, 115)
mk("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 24,
    TextColor3 = Color3.fromRGB(8, 8, 10),
    Text = "G",
}, logoTile)

mk("TextLabel", {
    Size = UDim2.new(1, -70, 0, 22),
    Position = UDim2.new(0, 64, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.txt,
    Text = "GLAXUS",
}, side)
mk("TextLabel", {
    Size = UDim2.new(1, -70, 0, 16),
    Position = UDim2.new(0, 64, 0, 36),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.faint,
    Text = "SCRIPT HUB v2.0",
}, side)

-- สถานะเกมปัจจุบัน
local hereBox = mk("Frame", {
    Size = UDim2.new(1, -28, 0, 64),
    Position = UDim2.new(0, 14, 0, 72),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, side)
corner(hereBox, 10)
stroke(hereBox, C.line, 1, 0.6)
mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 14),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.faint,
    Text = "YOU ARE IN",
}, hereBox)
local hereName = mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 20),
    Position = UDim2.new(0, 10, 0, 24),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextColor3 = detected and C.mint or C.gold,
    Text = detected and detected.name or "Unknown game",
}, hereBox)
mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 14),
    Position = UDim2.new(0, 10, 0, 44),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.faint,
    Text = tostring(CURRENT_PLACE),
}, hereBox)

-- ปุ่ม AUTO LOAD (sidebar)
local autoBtn = mk("TextButton", {
    Size = UDim2.new(1, -28, 0, 44),
    Position = UDim2.new(0, 14, 0, 148),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(8, 8, 10),
    Text = "▶  AUTO LOAD",
    Visible = false,
    AutoButtonColor = false,
}, side)
corner(autoBtn, 10)
grad(autoBtn, GRAD_MAIN, 90)

local sideNote = mk("TextLabel", {
    Size = UDim2.new(1, -28, 0, 60),
    Position = UDim2.new(0, 14, 1, -110),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.faint,
    Text = "R-Shift toggle menu\n10 games - HWID locked",
}, side)

local hubStatus = mk("TextLabel", {
    Size = UDim2.new(1, -28, 0, 34),
    Position = UDim2.new(0, 14, 1, -48),
    BackgroundColor3 = C.card,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextColor3 = C.dim,
    Text = "Ready — select a game",
}, side)
corner(hubStatus, 8)

-- ขวา: โซนเกม
local rightPane = mk("Frame", {
    Size = UDim2.new(1, -216, 1, -28),
    Position = UDim2.new(0, 202, 0, 14),
    BackgroundTransparency = 1,
}, hubFrame)

local topTitle = mk("TextLabel", {
    Size = UDim2.new(1, -44, 0, 26),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.txt,
    Text = "Select Game  ",
}, rightPane)
mk("TextLabel", {
    Size = UDim2.new(0, 44, 0, 20),
    Position = UDim2.new(0, 148, 0, 3),
    BackgroundColor3 = C.card,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = C.mint,
    Text = "10",
}, rightPane)

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -30, 0, 0),
    BackgroundColor3 = C.card,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.red,
    Text = "✕",
    AutoButtonColor = false,
}, rightPane)
corner(closeBtn, 8)

local scroll = mk("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -44),
    Position = UDim2.new(0, 0, 0, 38),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.cyan,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, rightPane)
mk("UIGridLayout", {
    CellSize = UDim2.new(0, 200, 0, 92),
    CellPadding = UDim2.new(0, 10, 0, 10),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)

local function hubSay(t, isErr)
    hubStatus.Text = t
    hubStatus.TextColor3 = isErr and C.red or C.dim
end

-- =====================================================================
-- [6] KEY UI
-- =====================================================================
local passOuter, passFrame, passGrad = panelCard(rootGui, UDim2.new(0, 370, 0, 400), UDim2.new(0.5, 0, 0.5, 0), 18)
passOuter.Name = "Password"
passOuter.Visible = false
passOuter.Active = true
passOuter.Draggable = true
spinGrad(passGrad, 7)

-- วงแหวนล็อก
local lockRing = mk("Frame", {
    Size = UDim2.new(0, 64, 0, 64),
    Position = UDim2.new(0.5, 0, 0, 26),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, passFrame)
corner(lockRing, 32)
grad(lockRing, GRAD_MAIN, 115)
local lockIn = mk("Frame", {
    Size = UDim2.new(1, -6, 1, -6),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, lockRing)
corner(lockIn, 29)
mk("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 24,
    TextColor3 = Color3.fromRGB(8, 8, 10),
    Text = "G",
}, lockIn)

mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 28),
    Position = UDim2.new(0, 0, 0, 100),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 21,
    TextColor3 = C.txt,
    Text = "PRIVATE ACCESS",
}, passFrame)
mk("TextLabel", {
    Size = UDim2.new(1, -50, 0, 18),
    Position = UDim2.new(0, 25, 0, 128),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = C.dim,
    Text = "Enter your key to unlock Glaxus Hub",
}, passFrame)

local passBox = mk("TextBox", {
    Size = UDim2.new(1, -50, 0, 46),
    Position = UDim2.new(0, 25, 0, 156),
    BackgroundColor3 = Color3.fromRGB(10, 10, 14),
    Font = Enum.Font.Code,
    TextSize = 15,
    TextColor3 = C.txt,
    PlaceholderText = "GL-XXXX-XXXX-XXXX",
    PlaceholderColor3 = C.faint,
    Text = "",
    ClearTextOnFocus = false,
}, passFrame)
corner(passBox, 10)
stroke(passBox, C.line, 1, 0.4)

local passGo = mk("TextButton", {
    Size = UDim2.new(1, -50, 0, 44),
    Position = UDim2.new(0, 25, 0, 212),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextColor3 = Color3.fromRGB(8, 8, 10),
    Text = "UNLOCK",
    AutoButtonColor = false,
}, passFrame)
corner(passGo, 10)
grad(passGo, GRAD_MAIN, 90)

local getKeyBtn = mk("TextButton", {
    Size = UDim2.new(0.5, -30, 0, 36),
    Position = UDim2.new(0, 25, 0, 264),
    BackgroundColor3 = C.card,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.gold,
    Text = "GET KEY",
    AutoButtonColor = false,
}, passFrame)
corner(getKeyBtn, 10)
stroke(getKeyBtn, C.txt, 1, 0.55)

local pasteBtn = mk("TextButton", {
    Size = UDim2.new(0.5, -30, 0, 36),
    Position = UDim2.new(0.5, 5, 0, 264),
    BackgroundColor3 = C.card,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.txt,
    Text = "PASTE",
    AutoButtonColor = false,
}, passFrame)
corner(pasteBtn, 10)
stroke(pasteBtn, C.line, 1, 0.4)

pasteBtn.MouseButton1Click:Connect(function()
    local ok, clip = pcall(function()
        if typeof(getclipboard) == "function" then
            return getclipboard()
        end
        return nil
    end)
    if ok and type(clip) == "string" and #trim(clip) > 3 then
        passBox.Text = trim(clip)
        passHint.Text = "Pasted — press UNLOCK"
    else
        passHint.Text = "Clipboard empty — copy the key first"
    end
end)

local passInfo = mk("TextLabel", {
    Size = UDim2.new(1, -50, 0, 20),
    Position = UDim2.new(0, 25, 0, 306),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = C.red,
    Text = "",
}, passFrame)

local passHint = mk("TextLabel", {
    Size = UDim2.new(1, -50, 0, 18),
    Position = UDim2.new(0, 25, 0, 328),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = C.faint,
    Text = "No key yet? Press GET KEY and complete the steps",
}, passFrame)

-- hover ปุ่ม
local function hoverFx(btn, hoverBg)
    local orig = btn.BackgroundColor3
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hoverBg }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = orig }):Play()
    end)
end
hoverFx(getKeyBtn, C.cardHi)
hoverFx(pasteBtn, C.cardHi)

getKeyBtn.MouseButton1Click:Connect(function()
    local url = activeGetKeyUrl()
    if url ~= "" then
        local ok = pcall(function() setclipboard(url) end)
        passHint.Text = ok and "Link copied — paste it in your browser" or url
    else
        passHint.Text = "Contact admin on Discord for a key"
    end
end)

local attemptsLeft = MAX_ATTEMPTS
local unlocked = false

local function lockout()
    passInfo.Text = "Locked — too many attempts"
    task.wait(1)
    if KICK_ON_FAIL then
        pcall(function() LocalPlayer:Kick(KICK_MSG) end)
    end
    if G.__EsaHub_Cleanup then
        pcall(G.__EsaHub_Cleanup)
    end
end

local onUnlocked = function() end -- ตัวจริง assign ใน [9]

local function tryUnlock()
    if unlocked then
        return
    end
    local input = trim(passBox.Text)
    passInfo.TextColor3 = C.dim
    passInfo.Text = "Verifying key..."
    local ok, info = verifyKey(input)
    if ok then
        unlocked = true
        passInfo.TextColor3 = C.mint
        passInfo.Text = "Access granted."
        TweenService:Create(passOuter, TweenInfo.new(0.25), {
            Position = passOuter.Position + UDim2.new(0, 0, 0, -12),
        }):Play()
        task.wait(0.45)
        passOuter.Visible = false
        onUnlocked()
        return
    else
        passInfo.TextColor3 = C.red
        local msg = tostring(info)
        if msg:sub(1, 10) == "TRANSIENT:" then
            -- เน็ต/เรทลิมิต: ไม่นับครั้ง ให้ลองใหม่ได้
            msg = "Busy (" .. msg:sub(11) .. ") — retry"
        else
            attemptsLeft = attemptsLeft - 1
            msg = msg .. " (" .. tostring(math.max(attemptsLeft, 0)) .. " left)"
        end
        passInfo.Text = msg
        shake(passOuter)
    end
    passBox.Text = ""
    if attemptsLeft <= 0 then
        lockout()
    end
end

passGo.MouseButton1Click:Connect(tryUnlock)
passBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        tryUnlock()
    end
end)

-- =====================================================================
-- [7] LOAD LOGIC (กดปุ่ม -> โหลด main.lua แมพนั้น)
-- =====================================================================
local function fetchSource(entry)
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local candidates = {
            "Games/" .. entry.folder .. "/Scripts/" .. entry.file,
            "Esa-slayer/Games/" .. entry.folder .. "/Scripts/" .. entry.file,
            "Esa_slayer/Games/" .. entry.folder .. "/Scripts/" .. entry.file,
        }
        for _, p in ipairs(candidates) do
            local ok, exists = pcall(function() return isfile(p) end)
            if ok and exists then
                local ok2, src = pcall(function() return readfile(p) end)
                if ok2 and type(src) == "string" and #src > 100 then
                    return src, ("file:" .. p)
                end
            end
        end
    end
    if type(BASE_URL) == "string" and #BASE_URL > 8 then
        local base = BASE_URL
        if string.sub(base, -1) ~= "/" then
            base = base .. "/"
        end
        local url = base .. "Games/" .. entry.folder .. "/Scripts/" .. entry.file
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and type(src) == "string" and #src > 100 then
            return src, url
        end
    end
    return nil, nil
end

local function closeHub()
    pcall(function()
        if G.__EsaHub_Cleanup then
            local c = G.__EsaHub_Cleanup
            G.__EsaHub_Cleanup = nil
            c()
        end
    end)
end

local loadingGame = false
local function loadGame(entry)
    if loadingGame then
        return
    end
    loadingGame = true
    hubSay("Loading " .. entry.name .. "...")

    task.spawn(function()
        local src, from = fetchSource(entry)
        if not src then
            hubSay("File not found: " .. entry.folder, true)
            hubOuter.Visible = true
            floatBtn.Visible = true
            loadingGame = false
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            hubSay("Syntax error: " .. tostring(err), true)
            hubOuter.Visible = true
            floatBtn.Visible = true
            loadingGame = false
            return
        end
        hubSay(entry.name .. " loaded")
        task.wait(0.4)
        closeHub()
        local ok, runErr = pcall(fn)
        if not ok then
            warn("[Glaxus] main error: " .. tostring(runErr))
        end
    end)
end

-- การ์ดเกม (grid)
for i, g in ipairs(GAMES) do
    local isCurrent = (g.placeId == CURRENT_PLACE)
    local card = mk("TextButton", {
        Name = "Game_" .. tostring(g.placeId),
        BackgroundColor3 = isCurrent and Color3.fromRGB(12, 48, 40) or C.card,
        Font = Enum.Font.GothamBold,
        TextSize = 1,
        Text = "",
        TextTransparency = 1,
        LayoutOrder = isCurrent and -1 or i,
        AutoButtonColor = false,
    }, scroll)
    corner(card, 12)
    local cardStroke = stroke(card, isCurrent and C.mint or C.line, 1, isCurrent and 0.25 or 0.6)

    local tile = mk("Frame", {
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, card)
    corner(tile, 10)
    grad(tile, GRAD_MAIN, 115)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(8, 8, 10),
        Text = g.icon,
    }, tile)

    mk("TextLabel", {
        Size = UDim2.new(1, -64, 0, 20),
        Position = UDim2.new(0, 56, 0, 12),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = C.txt,
        Text = g.name,
    }, card)

    mk("TextLabel", {
        Size = UDim2.new(1, -64, 0, 14),
        Position = UDim2.new(0, 56, 0, 34),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.faint,
        Text = tostring(g.placeId),
    }, card)

    mk("TextLabel", {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 10, 1, -22),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.faint,
        Text = "▸ " .. g.folder,
    }, card)

    local arrow = mk("TextLabel", {
        Size = UDim2.new(0, 20, 0, 24),
        Position = UDim2.new(1, -26, 0, 10),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        TextSize = 18,
        TextColor3 = isCurrent and C.mint or C.faint,
        Text = "›",
    }, card)

    if isCurrent then
        local badge = mk("Frame", {
            Size = UDim2.new(0, 86, 0, 18),
            Position = UDim2.new(1, -94, 1, -24),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, card)
        corner(badge, 9)
        grad(badge, GRAD_MAIN, 90)
        mk("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBlack,
            TextSize = 9,
            TextColor3 = Color3.fromRGB(8, 8, 10),
            Text = "● HERE",
        }, badge)
    end

    if not isCurrent then
        card.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = C.cardHi }):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.15), { Transparency = 0.15 }):Play()
            TweenService:Create(arrow, TweenInfo.new(0.15), { TextColor3 = C.mint }):Play()
        end)
        card.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.2), { BackgroundColor3 = C.card }):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.2), { Transparency = 0.6 }):Play()
            TweenService:Create(arrow, TweenInfo.new(0.2), { TextColor3 = C.faint }):Play()
        end)
    end

    local entry = g
    card.MouseButton1Click:Connect(function()
        loadGame(entry)
    end)
end

-- ปุ่ม AUTO LOAD (โชว์เฉพาะตอนเข้าเกมที่รองรับ)
if detected then
    autoBtn.Visible = true
    autoBtn.Text = "▶  " .. string.upper(detected.name)
    local d = detected
    autoBtn.MouseButton1Click:Connect(function()
        loadGame(d)
    end)
else
    autoBtn.Visible = false
    sideNote.Position = UDim2.new(0, 14, 0, 148)
end

closeBtn.MouseButton1Click:Connect(function()
    if G.__EsaHub_Cleanup then
        pcall(G.__EsaHub_Cleanup)
    end
end)
hoverFx(closeBtn, Color3.fromRGB(55, 55, 62))

-- =====================================================================
-- [8] FLOATING TOGGLE (pill + จุดไฟกะพริบ)
-- =====================================================================
local floatBtn = mk("TextButton", {
    Name = "FloatingToggle",
    Size = UDim2.new(0, 148, 0, 40),
    Position = UDim2.new(0, 20, 0.45, 0),
    BackgroundColor3 = Color3.fromRGB(12, 12, 16),
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextColor3 = C.txt,
    Text = "   GLAXUS",
    Visible = false,
    Active = true,
    Draggable = true,
    AutoButtonColor = false,
}, rootGui)
corner(floatBtn, 20)
stroke(floatBtn, C.line, 1, 0.4)

local dot = mk("Frame", {
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(0, 14, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = C.mint,
    BorderSizePixel = 0,
}, floatBtn)
corner(dot, 6)
task.spawn(function()
    while dot.Parent do
        local tw = TweenService:Create(dot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.55,
        })
        tw:Play()
        tw.Completed:Wait()
        if not dot.Parent then
            break
        end
        local tw2 = TweenService:Create(dot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0,
        })
        tw2:Play()
        tw2.Completed:Wait()
    end
end)

floatBtn.MouseButton1Click:Connect(function()
    if not unlocked then
        return
    end
    hubOuter.Visible = not hubOuter.Visible
end)

addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if not unlocked then
            return
        end
        hubOuter.Visible = not hubOuter.Visible
    end
end))

-- =====================================================================
-- [9] RUN: Loading -> Password -> Auto-load / Hub
-- =====================================================================
task.spawn(function()
    local steps = {
        "Checking PlaceId...",
        "Loading game list (10)...",
        "Preparing interface...",
        "Ready",
    }
    local n = #steps
    local tipIdx = 0
    for i = 1, n do
        setStatus(steps[i])
        tipIdx = tipIdx + 1
        tipLabel.Text = TIPS[((tipIdx - 1) % #TIPS) + 1]
        local pct = math.floor((i / n) * 100)
        pctLabel.Text = tostring(pct) .. "%"
        TweenService:Create(barFill, TweenInfo.new(LOADING_TIME / n, Enum.EasingStyle.Quad), {
            Size = UDim2.new(i / n, 0, 1, 0),
        }):Play()
        task.wait(LOADING_TIME / n)
    end

    -- save-and-resume: เคยผ่านแล้ว ข้ามจอรหัสเลย
    if PANDA_ENABLED then
        setStatus("Checking saved key...")
        local saved = loadSavedKey()
        if saved and pandaValidate(saved) == "valid" then
            unlocked = true
            loadingFrame.Visible = false
            onUnlocked()
            return
        end
    end

    loadingFrame.Visible = false
    passOuter.Visible = true
    popIn(passOuter)
    pcall(function() passBox:CaptureFocus() end)
end)

onUnlocked = function()
    local forceMenu = G.EsaHub_ForceMenu == true
    local shouldAuto = AUTO_LOAD and (not forceMenu) and (detected ~= nil)

    if shouldAuto then
        loadGame(detected)
        return
    end

    hubOuter.Visible = true
    popIn(hubOuter)
    floatBtn.Visible = true
end
