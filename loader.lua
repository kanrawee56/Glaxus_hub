-- =====================================================================
-- ESA-SLAYER HUB | Universal Loader + Loading + Game Selector
-- File: loader.lua (วางไว้ที่ root ของโปรเจกต์ คู่กับโฟลเดอร์ Games/)
-- Type: Single-file | Status: Ready to run
-- ---------------------------------------------------------------------
-- วิธีใช้ (รันใน Executor แค่บรรทัดเดียว):
--
--   1) แบบไฟล์ local (เทสในเครื่องตัวเอง):
--      loadstring(readfile("loader.lua"))()
--
--   2) แบบลิงก์ GitHub (หลัง push ขึ้น repo แล้ว):
--      loadstring(game:HttpGet("https://raw.githubusercontent.com/<USER>/<REPO>/main/loader.lua"))()
--
-- พฤติกรรม:
--   [Loading 2-3 วิ] -> [🔒 ใส่รหัส] -> [เช็ค PlaceId อัตโนมัติ]
--     - ใส่รหัสผิดเกิน MAX_ATTEMPTS -> ปิดสคริปต์ทิ้ง (+เตะออกถ้าเปิด KICK_ON_FAIL)
--     - ถ้าเจอเกมในลิสต์ + AUTO_LOAD = true -> โหลด main.lua ของแมพนั้นทันที
--     - ถ้าไม่เจอ / ตั้ง FORCE_MENU = true -> โชว์ UI เลือกเกม กดปุ่มไหนก็โหลดแมพนั้น
-- ---------------------------------------------------------------------
-- 🔒 เรื่องกันดูซอร์ส (อ่านก่อน!):
--   1) รหัสผ่านในไฟล์นี้กันได้แค่ "คนไม่มีรหัสใช้ไม่ได้" แต่กันคนแกะไฟล์ไม่ได้
--      เพราะใครเปิด loader.lua ก็เห็นรหัส -> ก่อนแจกต้องเอาไป obfuscate ก่อน
--      (เช่น Luraph / PSU Obfuscator) แล้วแจกเฉพาะตัวที่ obfuscate แล้ว
--   2) ห้าม push โฟลเดอร์ Games/ ขึ้น public repo ถ้ากลัวโดนดูดสคริปต์
--      (ทำ repo เป็น private หรือเก็บ main.lua ไว้ที่โฮสต์ตัวเอง)
--   3) กันจริงจังต้องใช้เซิร์ฟเวอร์ตรวจ key แล้วค่อยส่งซอร์สกลับมา
--      (เช่น Cloudflare Worker + KV) เพราะ GitHub raw ใครมีลิงก์ก็โหลดได้
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
local BASE_URL = "https://raw.githubusercontent.com/kanrawee56/Glaxus_hub/main/" -- <<<<<< ใส่ตรงนี้หลัง push ขึ้น GitHub เช่น "https://raw.githubusercontent.com/kanra/Esa-slayer/main/"
-- ต้องลงท้ายด้วย "/" เสมอ ถ้ายังไม่ push ให้ปล่อย "" ไว้ (จะใช้โหมด readfile local อย่างเดียว)

local AUTO_LOAD = true -- ถ้า PlaceId ตรงกับเกมในลิสต์ ให้โหลดทันที ไม่ต้องกด
-- อยากบังคับโชว์เมนูทุกครั้ง (ไม่ auto): รัน getgenv().EsaHub_ForceMenu = true ก่อนโหลด

local LOADING_TIME = 2.5 -- วินาทีของหน้า loading

-- =====================================================================
-- [2.1] 🔒 PASSWORD / KEY SYSTEM (ตั้งรหัสตรงนี้)
-- =====================================================================
local PASSWORD = "ESA-2026" -- <<<<<< เปลี่ยนรหัสของตัวเองตรงนี้
local MAX_ATTEMPTS = 5 -- ใส่ผิดเกินนี้ -> ปิดสคริปต์ทิ้ง
local KICK_ON_FAIL = false -- true = ใส่ผิดครบแล้วเตะออกจากเกมเลย, false = แค่ปิด UI
local KICK_MSG = "❌ Wrong key."

-- ลิสต์รหัสออนไลน์ (optional): ไฟล์ .txt มีรหัสทีละบรรทัด เช่น pastebin raw / github gist raw
-- ใส่แล้วจะยอมรับรหัสในลิสต์ด้วย (เปลี่ยน/เพิ่มรหัสได้โดยไม่ต้องแจกไฟล์ใหม่)
-- ปล่อย "" ไว้ถ้าไม่ใช้
local KEY_LIST_URL = ""

-- ล็อก HWID (optional): true = รับเฉพาะเครื่องที่ gethwid ตรงกับ ALLOWED_HWIDS
local USE_HWID_LOCK = false
local ALLOWED_HWIDS = {
    -- "ใส่ hwid ตรงนี้",
}

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

local function checkHwid()
    if not USE_HWID_LOCK then
        return true
    end
    local id = getHwid()
    if not id then
        return false
    end
    for _, allow in ipairs(ALLOWED_HWIDS) do
        if trim(allow) == trim(id) then
            return true
        end
    end
    return false
end

local remoteKeys = nil -- cache ลิสต์รหัสออนไลน์
local function fetchRemoteKeys()
    if remoteKeys then
        return remoteKeys
    end
    remoteKeys = {}
    if type(KEY_LIST_URL) == "string" and #KEY_LIST_URL > 8 then
        local ok, body = pcall(function() return game:HttpGet(KEY_LIST_URL) end)
        if ok and type(body) == "string" then
            for line in (body .. "\n"):gmatch("([^\r\n]+)") do
                line = trim(line)
                if #line > 0 then
                    remoteKeys[line] = true
                end
            end
        end
    end
    return remoteKeys
end

local function checkKey(input)
    input = trim(input)
    if input == PASSWORD then
        return true
    end
    local keys = fetchRemoteKeys()
    if keys[input] then
        return true
    end
    return false
end

-- ลิสต์เกมทั้งหมด (ต้องตรงกับโฟลเดอร์ Games/<Folder>/Scripts/<File>)
local GAMES = {
    { name = "Warfare Tycoon",      placeId = 31490825,        folder = "WarfareTycoon_31490825",        file = "main.lua", icon = "🚁" },
    { name = "Anime Battle Arena",  placeId = 1458767429,      folder = "ABA_1458767429",                file = "main.lua", icon = "⚔️" },
    { name = "MIC UP",              placeId = 6884319169,      folder = "MICUP_6884319169",              file = "main.lua", icon = "🎤" },
    { name = "Cold War Vietnam",    placeId = 13687899540,     folder = "ColdWar_13687899540",           file = "main.lua", icon = "🔥" },
    { name = "Jujutsu Shenanigans", placeId = 9391468976,      folder = "JujutsuShenanigans_9391468976", file = "main.lua", icon = "👹" },
    { name = "King Legacy",         placeId = 1451439645,      folder = "KingLegacy_1451439645",         file = "main.lua", icon = "🌊" },
    { name = "BloxStrike",          placeId = 114234929420007, folder = "BloxStrike_114234929420007",    file = "Main.lua", icon = "🔫" },
    { name = "Ride A Pet",          placeId = 124216119978534, folder = "Ride_A_Pet_124216119978534",    file = "main.lua", icon = "🐾" },
    { name = "Slayer 2",            placeId = 136406881576517, folder = "Slayer_2_136406881576517",      file = "main.lua", icon = "🗡️" },
    { name = "Steal An Egg",        placeId = 107778070777162, folder = "Steal_An_Egg_107778070777162",  file = "main.lua", icon = "🥚" },
}

-- =====================================================================
-- [3] SERVICES
-- =====================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

-- =====================================================================
-- [4] ROOT GUI + CLEANUP
-- =====================================================================
local hui = (typeof(gethui) == "function" and gethui())
    or (typeof(get_hidden_gui) == "function" and get_hidden_gui())
    or game:GetService("CoreGui")

local rootGui = Instance.new("ScreenGui")
rootGui.Name = "EsaSlayerHub"
rootGui.ResetOnSpawn = false
rootGui.IgnoreGuiInset = true
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

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(0, 255, 170)
    s.Thickness = thick or 1
    s.Transparency = 0.6
    s.Parent = obj
    return s
end

-- =====================================================================
-- [5] LOADING SCREEN
-- =====================================================================
local loadingFrame = Instance.new("Frame")
loadingFrame.Name = "Loading"
loadingFrame.Size = UDim2.new(1, 0, 1, 0)
loadingFrame.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
loadingFrame.BorderSizePixel = 0
loadingFrame.Parent = rootGui

local loadCard = Instance.new("Frame")
loadCard.AnchorPoint = Vector2.new(0.5, 0.5)
loadCard.Position = UDim2.new(0.5, 0, 0.5, 0)
loadCard.Size = UDim2.new(0, 380, 0, 250)
loadCard.BackgroundColor3 = Color3.fromRGB(16, 20, 27)
loadCard.BorderSizePixel = 0
loadCard.Parent = loadingFrame
corner(loadCard, 14)
stroke(loadCard, Color3.fromRGB(0, 255, 170), 1)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 44)
titleLabel.Position = UDim2.new(0, 0, 0, 14)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 26
titleLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
titleLabel.Text = "ESA-SLAYER HUB"
titleLabel.Parent = loadCard

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -40, 0, 20)
subLabel.Position = UDim2.new(0, 20, 0, 58)
subLabel.BackgroundTransparency = 1
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 13
subLabel.TextColor3 = Color3.fromRGB(160, 175, 190)
subLabel.Text = "Universal Loader  •  10 Games Ready"
subLabel.Parent = loadCard

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -60, 0, 12)
barBg.Position = UDim2.new(0, 30, 0, 110)
barBg.BackgroundColor3 = Color3.fromRGB(28, 34, 44)
barBg.BorderSizePixel = 0
barBg.Parent = loadCard
corner(barBg, 6)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 170)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
corner(barFill, 6)

local pctLabel = Instance.new("TextLabel")
pctLabel.Size = UDim2.new(1, 0, 0, 20)
pctLabel.Position = UDim2.new(0, 0, 0, 128)
pctLabel.BackgroundTransparency = 1
pctLabel.Font = Enum.Font.GothamBold
pctLabel.TextSize = 13
pctLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
pctLabel.Text = "0%"
pctLabel.Parent = loadCard

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 44)
statusLabel.Position = UDim2.new(0, 20, 0, 152)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(140, 155, 170)
statusLabel.Text = "Starting..."
statusLabel.Parent = loadCard

local placeLabel = Instance.new("TextLabel")
placeLabel.Size = UDim2.new(1, -40, 0, 18)
placeLabel.Position = UDim2.new(0, 20, 0, 200)
placeLabel.BackgroundTransparency = 1
placeLabel.Font = Enum.Font.Code
placeLabel.TextSize = 11
placeLabel.TextColor3 = Color3.fromRGB(90, 105, 120)
placeLabel.Text = "PlaceId: " .. tostring(CURRENT_PLACE)
placeLabel.Parent = loadCard

local function setStatus(t)
    statusLabel.Text = t
end

-- =====================================================================
-- [6] HUB UI (หน้าเลือกเกม)
-- =====================================================================
local hubFrame = Instance.new("Frame")
hubFrame.Name = "Hub"
hubFrame.AnchorPoint = Vector2.new(0.5, 0.5)
hubFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
hubFrame.Size = UDim2.new(0, 460, 0, 540)
hubFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 25)
hubFrame.BorderSizePixel = 0
hubFrame.Visible = false
hubFrame.Active = true
hubFrame.Draggable = true
hubFrame.Parent = rootGui
corner(hubFrame, 14)
stroke(hubFrame, Color3.fromRGB(0, 255, 170), 1)

local hubTitle = Instance.new("TextLabel")
hubTitle.Size = UDim2.new(1, -60, 0, 34)
hubTitle.Position = UDim2.new(0, 18, 0, 12)
hubTitle.BackgroundTransparency = 1
hubTitle.Font = Enum.Font.GothamBlack
hubTitle.TextSize = 19
hubTitle.TextXAlignment = Enum.TextXAlignment.Left
hubTitle.TextColor3 = Color3.fromRGB(0, 255, 170)
hubTitle.Text = "⚔️ ESA-SLAYER HUB"
hubTitle.Parent = hubFrame

local hubSub = Instance.new("TextLabel")
hubSub.Size = UDim2.new(1, -60, 0, 18)
hubSub.Position = UDim2.new(0, 18, 0, 44)
hubSub.BackgroundTransparency = 1
hubSub.Font = Enum.Font.Gotham
hubSub.TextSize = 12
hubSub.TextXAlignment = Enum.TextXAlignment.Left
hubSub.TextColor3 = Color3.fromRGB(150, 165, 180)
hubSub.Parent = hubFrame

local detected = findGame(CURRENT_PLACE)
if detected then
    hubSub.Text = "✅ Detected: " .. detected.name .. "  (" .. tostring(CURRENT_PLACE) .. ")"
    hubSub.TextColor3 = Color3.fromRGB(0, 255, 170)
else
    hubSub.Text = "⚠️ PlaceId " .. tostring(CURRENT_PLACE) .. " ยังไม่มีสคริปต์ — เลือกเองได้เลย"
    hubSub.TextColor3 = Color3.fromRGB(255, 200, 80)
end

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Text = "X"
closeBtn.Parent = hubFrame
corner(closeBtn, 8)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -28, 1, -152)
scroll.Position = UDim2.new(0, 14, 0, 72)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = hubFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local hubStatus = Instance.new("TextLabel")
hubStatus.Size = UDim2.new(1, -28, 0, 40)
hubStatus.Position = UDim2.new(0, 14, 1, -66)
hubStatus.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
hubStatus.Font = Enum.Font.Gotham
hubStatus.TextSize = 12
hubStatus.TextWrapped = true
hubStatus.TextColor3 = Color3.fromRGB(160, 175, 190)
hubStatus.Text = "Ready — กดปุ่มเกมเพื่อโหลดสคริปต์"
hubStatus.Parent = hubFrame
corner(hubStatus, 8)

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -28, 0, 0)
autoBtn.Position = UDim2.new(0, 14, 1, 0)
autoBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 130)
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 14
autoBtn.TextColor3 = Color3.fromRGB(8, 12, 10)
autoBtn.Text = ""
autoBtn.Visible = false
autoBtn.Parent = hubFrame
corner(autoBtn, 8)

local function hubSay(t, isErr)
    hubStatus.Text = t
    hubStatus.TextColor3 = isErr and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(160, 175, 190)
end

-- =====================================================================
-- [6.5] 🔒 PASSWORD UI (จอใส่รหัส)
-- =====================================================================
local passFrame = Instance.new("Frame")
passFrame.Name = "Password"
passFrame.AnchorPoint = Vector2.new(0.5, 0.5)
passFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
passFrame.Size = UDim2.new(0, 340, 0, 230)
passFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 25)
passFrame.BorderSizePixel = 0
passFrame.Visible = false
passFrame.Active = true
passFrame.Draggable = true
passFrame.Parent = rootGui
corner(passFrame, 14)
stroke(passFrame, Color3.fromRGB(255, 200, 80), 1)

local passTitle = Instance.new("TextLabel")
passTitle.Size = UDim2.new(1, 0, 0, 36)
passTitle.Position = UDim2.new(0, 0, 0, 14)
passTitle.BackgroundTransparency = 1
passTitle.Font = Enum.Font.GothamBlack
passTitle.TextSize = 22
passTitle.TextColor3 = Color3.fromRGB(255, 200, 80)
passTitle.Text = "🔒 PRIVATE HUB"
passTitle.Parent = passFrame

local passSub = Instance.new("TextLabel")
passSub.Size = UDim2.new(1, -40, 0, 18)
passSub.Position = UDim2.new(0, 20, 0, 50)
passSub.BackgroundTransparency = 1
passSub.Font = Enum.Font.Gotham
passSub.TextSize = 12
passSub.TextColor3 = Color3.fromRGB(150, 165, 180)
passSub.Text = "กรอกรหัสเพื่อใช้งานสคริปต์"
passSub.Parent = passFrame

local passBox = Instance.new("TextBox")
passBox.Size = UDim2.new(1, -40, 0, 42)
passBox.Position = UDim2.new(0, 20, 0, 76)
passBox.BackgroundColor3 = Color3.fromRGB(24, 31, 42)
passBox.Font = Enum.Font.Code
passBox.TextSize = 16
passBox.TextColor3 = Color3.fromRGB(255, 255, 255)
passBox.PlaceholderText = "Enter key..."
passBox.PlaceholderColor3 = Color3.fromRGB(100, 115, 130)
passBox.Text = ""
passBox.ClearTextOnFocus = false
passBox.Parent = passFrame
corner(passBox, 8)

local passGo = Instance.new("TextButton")
passGo.Size = UDim2.new(1, -40, 0, 40)
passGo.Position = UDim2.new(0, 20, 0, 128)
passGo.BackgroundColor3 = Color3.fromRGB(0, 200, 130)
passGo.Font = Enum.Font.GothamBold
passGo.TextSize = 15
passGo.TextColor3 = Color3.fromRGB(8, 12, 10)
passGo.Text = "UNLOCK"
passGo.Parent = passFrame
corner(passGo, 8)

local passInfo = Instance.new("TextLabel")
passInfo.Size = UDim2.new(1, -40, 0, 20)
passInfo.Position = UDim2.new(0, 20, 0, 174)
passInfo.BackgroundTransparency = 1
passInfo.Font = Enum.Font.Gotham
passInfo.TextSize = 12
passInfo.TextColor3 = Color3.fromRGB(255, 120, 120)
passInfo.Text = ""
passInfo.Parent = passFrame

local attemptsLeft = MAX_ATTEMPTS
local unlocked = false

local function lockout()
    passInfo.Text = "❌ รหัสผิดครบแล้ว — ปิดสคริปต์"
    task.wait(1)
    if KICK_ON_FAIL then
        pcall(function() LocalPlayer:Kick(KICK_MSG) end)
    end
    if G.__EsaHub_Cleanup then
        pcall(G.__EsaHub_Cleanup)
    end
end

-- ประกาศไว้ก่อน ตัวจริง assign ใน [9] (หลัง loading เสร็จค่อยไปต่อ)
local onUnlocked = function() end

local function tryUnlock()
    if unlocked then
        return
    end
    local input = passBox.Text
    -- เช็ค HWID ก่อน (ถ้าเปิดใช้)
    if not checkHwid() then
        passInfo.Text = "❌ เครื่องนี้ไม่ได้รับอนุญาต (HWID)"
        attemptsLeft = attemptsLeft - 1
    elseif checkKey(input) then
        unlocked = true
        passInfo.TextColor3 = Color3.fromRGB(0, 255, 170)
        passInfo.Text = "✅ ถูกต้อง — กำลังเข้า..."
        task.wait(0.5)
        passFrame.Visible = false
        onUnlocked()
        return
    else
        attemptsLeft = attemptsLeft - 1
        passInfo.Text = "❌ รหัสผิด (เหลือ " .. tostring(math.max(attemptsLeft, 0)) .. " ครั้ง)"
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
    -- 1) ลองอ่านไฟล์ local ก่อน (สำหรับคนรันเทสในเครื่อง / Executor ที่รองรับ readfile)
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
    -- 2) โหลดจาก GitHub raw (ต้องตั้ง BASE_URL ก่อน)
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

local loadingGame = false
local function loadGame(entry)
    if loadingGame then
        return
    end
    loadingGame = true
    hubSay("⏳ Loading " .. entry.name .. " ...")
    setStatus("Loading " .. entry.name .. " ...")

    task.spawn(function()
        local src, from = fetchSource(entry)
        if not src then
            hubSay("❌ โหลดไม่ได้: ไม่เจอไฟล์ " .. entry.folder .. " (ตั้ง BASE_URL หรือวาง loader ไว้ข้างๆ โฟลเดอร์ Games)", true)
            loadingFrame.Visible = false
            hubFrame.Visible = true
            floatBtn.Visible = true
            loadingGame = false
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            hubSay("❌ Syntax error: " .. tostring(err), true)
            loadingFrame.Visible = false
            hubFrame.Visible = true
            floatBtn.Visible = true
            loadingGame = false
            return
        end
        hubSay("✅ Loaded " .. entry.name .. " (" .. tostring(from) .. ")")
        task.wait(0.4)
        -- ปิด Hub ก่อนรัน main (กัน UI ซ้อน) แต่เก็บ cleanup ไว้ให้ main ใช้ getgenv ของตัวเอง
        pcall(function()
            if G.__EsaHub_Cleanup then
                local c = G.__EsaHub_Cleanup
                G.__EsaHub_Cleanup = nil
                c()
            end
        end)
        local ok, runErr = pcall(fn)
        if not ok then
            warn("[EsaHub] main error: " .. tostring(runErr))
        end
    end)
end

-- สร้างปุ่มเกมทีละปุ่ม
for i, g in ipairs(GAMES) do
    local isCurrent = (g.placeId == CURRENT_PLACE)
    local btn = Instance.new("TextButton")
    btn.Name = "Game_" .. tostring(g.placeId)
    btn.Size = UDim2.new(1, -8, 0, 48)
    btn.BackgroundColor3 = isCurrent and Color3.fromRGB(0, 120, 85) or Color3.fromRGB(24, 31, 42)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = g.icon .. "  " .. g.name .. (isCurrent and "   ● YOU ARE HERE" or "")
    btn.LayoutOrder = isCurrent and -1 or i
    btn.Parent = scroll
    corner(btn, 10)
    if not isCurrent then
        stroke(btn, Color3.fromRGB(60, 75, 95), 1)
    end

    local pid = Instance.new("TextLabel")
    pid.Size = UDim2.new(1, -16, 0, 14)
    pid.Position = UDim2.new(0, 8, 1, -17)
    pid.BackgroundTransparency = 1
    pid.Font = Enum.Font.Code
    pid.TextSize = 10
    pid.TextXAlignment = Enum.TextXAlignment.Left
    pid.TextColor3 = Color3.fromRGB(120, 135, 150)
    pid.Text = tostring(g.placeId) .. "  •  " .. g.folder
    pid.Parent = btn

    local entry = g
    btn.MouseButton1Click:Connect(function()
        loadGame(entry)
    end)
end

-- ปุ่ม Auto-load (โชว์เฉพาะตอนเข้าเกมที่รองรับ)
if detected then
    autoBtn.Visible = true
    autoBtn.Size = UDim2.new(1, -28, 0, 34)
    autoBtn.Position = UDim2.new(0, 14, 1, -108)
    autoBtn.Text = "▶ AUTO LOAD: " .. string.upper(detected.name)
    scroll.Size = UDim2.new(1, -28, 1, -194)
    scroll.Position = UDim2.new(0, 14, 0, 72)
    hubStatus.Position = UDim2.new(0, 14, 1, -66)
    local d = detected
    autoBtn.MouseButton1Click:Connect(function()
        loadGame(d)
    end)
end

closeBtn.MouseButton1Click:Connect(function()
    if G.__EsaHub_Cleanup then
        pcall(G.__EsaHub_Cleanup)
    end
end)

-- =====================================================================
-- [8] FLOATING TOGGLE + RightShift (กันเมนูหาย ตาม Anti-Vanish standard)
-- =====================================================================
local floatBtn = Instance.new("TextButton")
floatBtn.Name = "FloatingToggle"
floatBtn.Size = UDim2.new(0, 130, 0, 36)
floatBtn.Position = UDim2.new(0, 20, 0.45, 0)
floatBtn.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 13
floatBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
floatBtn.Text = "⚔️ HUB [R-Shift]"
floatBtn.Visible = false
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Parent = rootGui
corner(floatBtn, 8)
stroke(floatBtn, Color3.fromRGB(0, 255, 170), 1)

floatBtn.MouseButton1Click:Connect(function()
    if not unlocked then
        return
    end
    hubFrame.Visible = not hubFrame.Visible
end)

addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if not unlocked then
            return
        end
        hubFrame.Visible = not hubFrame.Visible
    end
end))

-- =====================================================================
-- [9] RUN: Loading animation -> Auto-load / Show hub
-- =====================================================================
task.spawn(function()
    local steps = {
        "🔍 Checking PlaceId...",
        "📦 Loading game list (10)...",
        "🎨 Preparing UI...",
        "✨ Ready!",
    }
    local n = #steps
    for i = 1, n do
        setStatus(steps[i])
        local pct = math.floor((i / n) * 100)
        pctLabel.Text = tostring(pct) .. "%"
        TweenService:Create(barFill, TweenInfo.new(LOADING_TIME / n, Enum.EasingStyle.Quad), {
            Size = UDim2.new(i / n, 0, 1, 0),
        }):Play()
        task.wait(LOADING_TIME / n)
    end

    -- โหลดภาพเสร็จ -> เด้งจอรหัสก่อนเสมอ
    loadingFrame.Visible = false
    passFrame.Visible = true
    floatBtn.Visible = false
    pcall(function() passBox:CaptureFocus() end)
end)

-- ต่อหลังปลดล็อก: ค่อย auto-load / โชว์ hub
onUnlocked = function()
    local forceMenu = G.EsaHub_ForceMenu == true
    local shouldAuto = AUTO_LOAD and (not forceMenu) and (detected ~= nil)

    if shouldAuto then
        loadGame(detected)
        return
    end

    -- ไม่มี auto -> โชว์ hub
    hubFrame.Visible = true
    floatBtn.Visible = true
end
