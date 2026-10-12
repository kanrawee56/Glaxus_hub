-- ==============================================================================
-- ESA MAIN (Anime Battle Arena - PlaceId: 1458767429)
-- Single-file All-in-One Pro Combat Suite:
-- [UNIVERSAL] AutoTiming: BlackFlashCheck auto response (H)
-- [TRADE]
-- [COMBAT] Auto M1 Combo Assist + Rapid Attack Trade
-- [GRABBLUE] Mob Grab / Gojo Blue: Ball Steer + Detonate + VictimTag + AimRing
-- [NANAMI] NanamiTiming: Ratio 0.7 auto-hit
-- [RESET] J = IY-style Instant Respawn & Teleport Back
-- [AIM] M2 Hold AimLock (Smooth Tracking + Velocity Lead) + TeamCheck
-- [VISUALS / ESP] 2D Box, DisplayName + Character Name, Health Bar, Blocking & Attacking Badges, Chams, BillboardGui
-- [UI] WindUI (RightShift): Universal / Trade / Combat / GrabBlue / Nanami / Aim / Reset
-- ==============================================================================

-- ============================ STATE =============================
getgenv().EsaRev_main = ((getgenv().EsaRev_main or 0) + 1)
local REV = getgenv().EsaRev_main

-- Clean previous instances and listeners
for _, k in ipairs({ "EsaRev_esaall", "EsaRev_m1trade", "EsaRev_resetTest", "EsaRev_s3track", "EsaRev_silent" }) do
    getgenv()[k] = ((getgenv()[k] or 0) + 1)
end

for _, k in ipairs({
    "EsaConn_all_bf", "EsaConn_all_pe", "EsaConn_all_j", "EsaConn_all_mbeg", "EsaConn_all_mend",
    "EsaConn_trade_key", "EsaConn_skill_unblock", "EsaConn_s3track", "EsaConn_s3key", "EsaConn_resetTest_j",
    "EsaConn_resetTest_added", "EsaConn_silent_key", "EsaConn_main_resetJ",
    "EsaConn_main_resetAdded", "EsaConn_aim_m2", "EsaConn_aim_m2end", "EsaConn_esp_render",
    "EsaConn_silent_fov", "EsaConn_blue_tap", "EsaConn_blue_mode_toggle", "EsaConn_gaara_hb", "EsaConn_raiden_child", "EsaConn_raiden_m1"
}) do
    if getgenv()[k] then
        pcall(function() getgenv()[k]:Disconnect() end)
        getgenv()[k] = nil
    end
end

if getgenv().EsaSilentCircle then
    pcall(function() getgenv().EsaSilentCircle:Remove() end)
    getgenv().EsaSilentCircle = nil
end

local LP  = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("RunService")
local TS  = game:GetService("TweenService")
local Input = LP:WaitForChild("Backpack"):WaitForChild("Input")

-- ============================ CONFIG ============================
local ESA_CONFIG_FILE = "EsaAba/config.json"
local ESA_DEFAULTS = {
    -- Universal & Combat
    EsaAutoTiming       = true,
    EsaAutoAwaken       = true,     -- Emergency Awakening on low HP (G)
    EsaAutoAwakenHp     = 25,       -- HP % threshold for auto-awaken
    EsaComboMacro       = false,    -- True combo one-key trigger (disabled to prevent M1 interference)
    EsaAntiWhiff        = false,    -- Auto-dash cancel on missed M1
    EsaAutoM1           = false,    -- Auto M1 removed
    EsaAutoM1Range      = 12,

    -- Satoru Gojo & Mob (Grab / Blue)
    EsaBlueAuto         = true,
    EsaBluePvp          = true,
    EsaBlueMouse        = true,
    EsaBlueTracer       = true,
    EsaBlueFov          = true,
    EsaBlueFovSize      = 140,
    EsaAimPreview       = true,
    EsaBlueAutoDetonate = true,
    EsaBlueCluster      = true,     -- Points Farm Mode: steer ball to densest crowd cluster, no FOV needed
    EsaBlueClusterRadius = 22,      -- Studs: enemies within this radius count as one crowd

    -- Deidara
    EsaDeidaraAuto      = true,     -- Steer clay birds & spiders directly into target
    EsaDeidaraDetonate  = true,     -- Auto detonate clay creatures on contact
    EsaDeidaraSpeed     = 95,       -- Clay homing speed boost

    -- Auto Counters (Diavolo / Aizen / Universal)
    EsaAutoCounter      = false,    -- Auto Counter disabled by default to prevent skill lockout
    EsaCounterRange     = 16,       -- Distance to trigger counter
    EsaCounterEpitaph   = true,     -- Diavolo Epitaph priority
    EsaCounterAizen     = true,     -- Aizen Kyoka Suigetsu priority

    -- Luffy (Gear 4)
    EsaLuffyCulverin    = true,     -- Culverin 360° Python homing punches

    -- Gilgamesh
    EsaGilgameshGate    = true,     -- Gate of Babylon 100% trajectory convergence

    -- Kira Yoshikage
    EsaKiraSHA          = true,     -- Sheer Heart Attack supersonic tracking
    EsaSHASpeed         = 130,      -- SHA speed multiplier

    -- Nanami
    EsaNanamiAuto       = true,

    -- Aoi Todo (Boogie Woogie)
    EsaTodoSwap         = true,     -- Auto Boogie Woogie swap on enemy attack/hazard
    EsaTodoAutoClap     = true,     -- Clap to reverse enemy positioning

    -- Trafalgar Law (Room & Shambles)
    EsaLawShambles      = true,     -- Auto Shambles pull target into melee range
    EsaLawAutoPull      = true,

    -- Minato Namikaze (Flying Raijin)
    EsaMinatoKunai      = true,     -- Kunai homing + instant backstab teleport
    EsaMinatoTeleport   = true,

    -- Coyote Starrk (Los Lobos)
    EsaStarrkWolves     = true,     -- Guided spirit wolves homing & contact detonate
    EsaStarrkSpeed      = 110,

    -- Kisuke Urahara (Portable Gigai)
    EsaUraharaGigai     = true,     -- Emergency decoy substitution combo breaker

    -- Chika Fujiwara (Dance Minigame)
    EsaChikaDance       = true,     -- 100% Perfect score auto-timing

    -- Ki Blast & Beam Users (Goku, Vegeta, Piccolo)
    EsaKiBlastAim       = true,     -- Energy volley 100% convergence silent aim

    -- Anti-Abilities (Itachi / Shinji / Kokushibo)
    EsaAntiGenjutsu     = true,     -- 100% Immune to Tsukuyomi / Gaze stuns (IsLookingAt)
    EsaAntiScreenFlip   = true,     -- 100% Immune to Shinji Sakanade screen inversion
    EsaKokushibo        = true,     -- 100% Moon Breathing timing
    EsaRhythmAuto       = true,     -- 100% Miku / Osu rhythm timing

    -- Reset
    EsaResetHideUI      = true,

    -- Gaara (Sand Geyser / Tsunami)
    EsaGaaraSteer       = true,     -- Steer Sand Geyser directly into cursor target
    EsaGaaraSpeed       = 110,      -- Sand Geyser speed boost

    -- Raiden (Blade Mode & Zandatsu)
    EsaRaidenAuto       = true,     -- Blade Mode Auto-Zandatsu precision slice
    EsaRaidenInstant    = false,    -- Instant cut on Blade Mode activation

    -- Universal Silent Aim
    EsaSilentAimEnabled = true,     -- Master Silent Aim for all characters & skills
    EsaSilentMode       = "Cursor",  -- Pure 2D screen distance to mouse cursor
    EsaSilentHitbox     = "HumanoidRootPart", -- "HumanoidRootPart", "Torso", "Head"
    EsaSilentPredict    = 0.12,     -- Lead velocity prediction
    EsaSilentFOV        = 350,      -- FOV radius in pixels
    EsaSilentShowFOV    = true,     -- Draw FOV circle
    EsaSilentLimitToFOV = true,     -- Strict FOV circle limit (never target behind/off-screen)
    EsaSilentNotify     = true,     -- Notification on silent hit
    EsaSilentMaxDist    = 1500,     -- Maximum distance in studs

    -- Aim
    EsaAimOn            = true,
    EsaTeamCheck        = true,
    EsaAimCircle        = true,
    EsaAimRadius        = 200,
    EsaAimPredict       = 0.15,
}

local function loadConfig()
    local saved = nil
    pcall(function()
        if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(ESA_CONFIG_FILE) then
            local raw = readfile(ESA_CONFIG_FILE)
            if typeof(json) == "table" and raw and raw ~= "" then
                saved = json.decode(raw)
            end
        end
    end)
    for k, dflt in pairs(ESA_DEFAULTS) do
        if getgenv()[k] == nil then
            local v = (saved and saved[k] ~= nil) and saved[k] or dflt
            if k == "EsaBlueFovSize" or k == "EsaBehindDist" or k == "EsaAimRadius" or k == "EsaESPMaxDist" then
                v = tonumber(v) or dflt
            end
            getgenv()[k] = v
        end
    end
    if saved then warn("[ESA] settings loaded from " .. ESA_CONFIG_FILE) end
end

local function saveConfig()
    pcall(function()
        if typeof(writefile) ~= "function" or typeof(json) ~= "table" then return end
        local t = {}
        for k, _ in pairs(ESA_DEFAULTS) do t[k] = getgenv()[k] end
        writefile(ESA_CONFIG_FILE, json.encode(t))
    end)
end

getgenv().EsaSaveConfig = saveConfig
loadConfig()

getgenv().EsaBlueDetonateDist = getgenv().EsaBlueDetonateDist or 14
getgenv().EsaGBFollow = false
getgenv().EsaGrabDbg = getgenv().EsaGrabDbg or {}
getgenv().EsaHidingDeath = false

-- Cleanup visuals from previous runs
pcall(function()
    local lz = workspace:FindFirstChild("EsaBlueLaser")
    if lz then lz:Destroy() end
end)
pcall(function()
    local pg0 = LP.PlayerGui
    if pg0 then
        for _, n in ipairs({ "EsaBlueTag", "EsaMacroState", "EsaBlueFov", "EsaCursorTag", "EsaLockHL" }) do
            local o = pg0:FindFirstChild(n)
            if o then o:Destroy() end
        end
    end
end)
if getgenv().EsaWindUIWindow then
    pcall(function() getgenv().EsaWindUIWindow:Destroy() end)
    getgenv().EsaWindUIWindow = nil
end

-- =====================================================================
-- [UNIVERSAL] AutoTiming: BlackFlashCheck auto response (H)
-- =====================================================================
local function manualBF(a1, a2)
    local cam = workspace.CurrentCamera
    local v1 = a1 - a2
    TS:Create(cam, TweenInfo.new(v1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {FieldOfView = 6}):Play()
    local early, window, hit = false, false, false
    local conn = UIS.InputBegan:Connect(function(io)
        if early then return end
        if io.UserInputType == Enum.UserInputType.MouseButton1
            or io.UserInputType == Enum.UserInputType.Touch
            or io.KeyCode == Enum.KeyCode.ButtonB then
            if not window then early = true else hit = true end
        end
    end)
    task.wait(v1)
    window = true
    if a2 <= 0 then
        cam.FieldOfView = 70
        task.spawn(function() task.wait(0.1) cam.FieldOfView = 70 end)
        conn:Disconnect()
        return false, true
    end
    TS:Create(cam, TweenInfo.new(a2), {FieldOfView = 70}):Play()
    task.wait(a2)
    cam.FieldOfView = 70
    task.spawn(function() task.wait(0.1) cam.FieldOfView = 70 end)
    conn:Disconnect()
    return hit, true
end

local function bfHook(a1, a2)
    if not getgenv().EsaAutoTiming then return manualBF(a1, a2) end
    local v1 = (tonumber(a1) or 0.3) - (tonumber(a2) or 0.15)
    if v1 > 0 then task.wait(v1) end
    if tonumber(a2) and a2 > 0 then task.wait(a2 * 0.3) end
    return true, true
end

local function ensureRemotesAndHooks()
    local rs = game:GetService("ReplicatedStorage")
    local bf = rs:FindFirstChild("BlackFlashCheck")
    if bf then pcall(function() bf.OnClientInvoke = bfHook end) end
    local kk = rs:FindFirstChild("KokushiboCheck")
    if kk then pcall(function() kk.OnClientInvoke = function() return (getgenv().EsaKokushibo ~= false) end end) end
    local mk = rs:FindFirstChild("MikuCheck")
    if mk then pcall(function() mk.OnClientInvoke = function() return (getgenv().EsaRhythmAuto ~= false) end end) end
    local osu = rs:FindFirstChild("OsuCheck")
    if osu then pcall(function() osu.OnClientInvoke = function() return (getgenv().EsaRhythmAuto ~= false) end end) end
    local nn = rs:FindFirstChild("NanamiCheck")
    if nn then pcall(function() nn.OnClientInvoke = function() return (getgenv().EsaNanamiAuto ~= false), nil, true end end) end

    -- Anti-Genjutsu / Tsukuyomi Immunity (Itachi / Aizen)
    local ila = rs:FindFirstChild("IsLookingAt")
    if ila then
        pcall(function()
            ila.OnClientInvoke = function(a1)
                if getgenv().EsaAntiGenjutsu then return false end
                pcall(function()
                    local cam = workspace.CurrentCamera
                    if cam and a1 then
                        return (CFrame.new(cam.CFrame.Position, a1).LookVector - cam.CFrame.LookVector).Magnitude < 0.5
                    end
                end)
                return false
            end
        end)
    end
end
ensureRemotesAndHooks()

getgenv().EsaConn_all_bf = UIS.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if io.KeyCode == Enum.KeyCode.H then
        getgenv().EsaAutoTiming = not getgenv().EsaAutoTiming
        saveConfig()
        warn("[AutoTiming] " .. (getgenv().EsaAutoTiming and "ON" or "OFF"))
    end
end)

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(2)
        ensureRemotesAndHooks()
        if getgenv().EsaAntiScreenFlip then
            pcall(function()
                local fc = game.Lighting:FindFirstChild("flipcolor")
                if fc and fc.Saturation < 0 then
                    fc.Saturation = 0
                end
            end)
        end
    end
end)

local function aimFriendlyFire()
    local ok, v = pcall(function()
        local vm = game.ReplicatedStorage:FindFirstChild("VipModifiers")
        return vm and vm:FindFirstChild("Friendly Fire") ~= nil
    end)
    return ok and v == true
end

local function aimIsTeammate(n)
    if not n then return false end
    if n.Name == "FRIENDLYDUMMY" or n:HasTag("FRIENDLYDUMMY") then return true end
    local ok, plr = pcall(function()
        return game.Players:GetPlayerFromCharacter(n) or game.Players:FindFirstChild(n.Name)
    end)
    if ok and plr and LP.Team and plr.Team == LP.Team then
        return not aimFriendlyFire()
    end
    return false
end

-- =====================================================================
-- [UNIVERSAL CURSOR TARGET ENGINE] Strictly Nearest to Mouse on Screen
-- =====================================================================
local function getUniversalCursorTarget(maxFov)
    local ok, resModel, resPos = pcall(function()
        local cam = workspace.CurrentCamera
        local c = LP.Character
        local myHrp = c and c:FindFirstChild("HumanoidRootPart")
        if not cam or not myHrp then return nil, nil end

        local live = workspace:FindFirstChild("Live")
        if not live then return nil, nil end

        local mousePos = UIS:GetMouseLocation()
        local fov = maxFov or (tonumber(getgenv().EsaSilentFOV) or 350)
        local hitboxName = getgenv().EsaSilentHitbox or "HumanoidRootPart"
        local predict = tonumber(getgenv().EsaSilentPredict) or 0.12

        local bestModel = nil
        local bestDist = math.huge

        for _, m in ipairs(live:GetChildren()) do
            if m ~= c and m.Name ~= LP.Name and not m:FindFirstChild("NoTarg") then
                if not (getgenv().EsaTeamCheck and aimIsTeammate(m)) then
                    local hrp = m:FindFirstChild("HumanoidRootPart")
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        local aimPart = m:FindFirstChild(hitboxName) or hrp
                        local screenPos, onScreen = cam:WorldToViewportPoint(aimPart.Position)
                        -- MUST BE IN FRONT OF CAMERA (Z > 0)
                        if screenPos.Z > 0 then
                            local sDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            -- STRICT SCREEN FOV CHECK: Never lock someone far off or behind!
                            if sDist <= fov and sDist < bestDist then
                                bestDist = sDist
                                bestModel = m
                            end
                        end
                    end
                end
            end
        end

        if bestModel then
            local hrp = bestModel:FindFirstChild("HumanoidRootPart")
            local aimPart = bestModel:FindFirstChild(hitboxName) or hrp
            if aimPart and hrp then
                local targetPos = aimPart.Position + (hrp.Velocity * predict)
                return bestModel, targetPos
            end
        end
        return nil, nil
    end)

    if ok and resModel and resPos then
        return resModel, resPos
    end
    return nil, nil
end

-- =====================================================================
-- [GRABBLUE & GAARA] Steer + Detonate (Mob: Grab / Gojo: Blue / Gaara: Geyser)
-- =====================================================================
local mobGrab = nil
local pinned = false

getgenv().EsaConn_all_pe = game.ReplicatedStorage.PEffect.OnClientEvent:Connect(function(a1, a2)
    if REV ~= getgenv().EsaRev_main then return end
    if a1 == "RemoteControlMobGrab" and a2 and a2.ball and a2.ball.Parent then
        pcall(function() a2.ball.Anchored = true end)
        local cam = workspace.CurrentCamera
        if cam and LP.Character and LP.Character:FindFirstChild("Humanoid") then
            pcall(function() cam.CameraSubject = LP.Character.Humanoid end)
        end
        mobGrab = {ball = a2.ball, bp = a2.bp, bg = a2.bg, speed = (a2.speedmodifier or 1) * 100, zeroed = false, detonated = false}
        warn("[GrabBlue] ball acquired, camera lock prevented")
    elseif a1 == "RemoteControlGeyser" and a2 and a2.geyser and a2.bv then
        local geyser = a2.geyser
        local bv = a2.bv
        task.spawn(function()
            local cam = workspace.CurrentCamera
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if cam and hum then
                pcall(function() cam.CameraSubject = hum end)
            end
            local speed = tonumber(getgenv().EsaGaaraSpeed) or 110
            warn("[Gaara] Sand Geyser captured! Camera freed, mouse steering active.")

            local hbConn
            hbConn = RS.Heartbeat:Connect(function()
                if REV ~= getgenv().EsaRev_main or not bv or not bv.Parent or geyser.Anchored then
                    if hbConn then hbConn:Disconnect() end
                    return
                end
                if cam and hum and cam.CameraSubject ~= hum then
                    pcall(function() cam.CameraSubject = hum end)
                end
                if not getgenv().EsaGaaraSteer then return end

                -- Universal Cursor Target only!
                local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
                local dest = tgtPos

                -- If looking away or no target in FOV, steer smoothly towards mouse.Hit.Position
                if not dest then
                    local mouse = LP:GetMouse()
                    if mouse and mouse.Hit then
                        dest = mouse.Hit.Position
                    end
                end

                if dest then
                    local dir = (dest - geyser.Position) * Vector3.new(1, 0, 1)
                    if dir.Magnitude > 1.5 then
                        bv.Velocity = dir.Unit * speed
                    else
                        bv.Velocity = Vector3.zero
                    end
                end
            end)
        end)
    end
end)

local function grabMoveName()
    local moves = LP.PlayerGui and LP.PlayerGui:FindFirstChild("HUD") and LP.PlayerGui.HUD:FindFirstChild("Moves")
    if moves then
        for _, b in ipairs(moves:GetChildren()) do
            if b:IsA("ImageButton") then
                local ok, mn = pcall(function() return b:GetAttribute("MoveName") end)
                if ok and mn then
                    local low = string.lower(tostring(mn))
                    if string.find(low, "grab") or string.find(low, "blue") then
                        return tostring(mn)
                    end
                end
            end
        end
        for _, b in ipairs(moves:GetChildren()) do
            if b:IsA("ImageButton") then
                local cov = b:FindFirstChild("DisableCover")
                if cov and cov.Visible then
                    local ok, mn = pcall(function() return b:GetAttribute("MoveName") end)
                    if ok and mn then return tostring(mn) end
                end
            end
        end
    end
    return "Grab"
end

local function grabMoveShort()
    local mn = string.lower(grabMoveName())
    if string.find(mn, "blue") then return "BLUE" end
    return "GRAB"
end

local function isPlayerModel(n)
    return game.Players:FindFirstChild(n.Name) ~= nil
end

local function ringTol(along)
    local diam = tonumber(getgenv().EsaBlueFovSize) or 140
    local vs, cfov = 800, math.rad(35)
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            vs = cam.ViewportSize.Y
            cfov = math.rad(cam.FieldOfView / 2)
        end
    end)
    local ang = math.atan((diam / 2) / ((vs / 2) / math.tan(cfov)))
    return math.clamp(math.tan(ang) * along, 4, 150)
end

local sLock, sPos, sMissT = nil, nil, 0
local aimOrigin, aimDir = nil, nil

local function refreshAim()
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local okm, mh = pcall(function() return LP:GetMouse().Hit end)
    if not okm or not mh then return false end
    local origin = cam.CFrame.Position
    local mv = mh.Position - origin
    if mv.Magnitude < 1 then return false end
    aimOrigin, aimDir = origin, mv / mv.Magnitude
    return true
end

local function lockValid(m)
    if typeof(m) ~= "Instance" then return false end
    if m.Parent == nil then return false end
    local h = m:FindFirstChild("Humanoid")
    local r = m:FindFirstChild("HumanoidRootPart")
    return h ~= nil and h.Health > 0 and r ~= nil
end

local function scoreModel(n)
    if n.Name == LP.Name or n:FindFirstChild("NoTarg") then return nil end
    if getgenv().EsaTeamCheck and aimIsTeammate(n) then return nil end
    local h = n:FindFirstChild("Humanoid")
    local r = n:FindFirstChild("HumanoidRootPart")
    local t = n:FindFirstChild("Torso")
    if not (h and h.Health > 0 and r and t and t.Transparency < 1) then return nil end
    local rel = r.Position - aimOrigin
    local along = rel:Dot(aimDir)
    if along <= 2 then return nil end
    local perp = (rel - aimDir * along).Magnitude
    if perp >= ringTol(along) then return nil end
    local s = perp * 40 + along * 0.02
    if isPlayerModel(n) then s = s - 100000 end
    return s
end

local function nextLock()
    if not refreshAim() then
        sLock, sPos, sMissT = nil, nil, 0
        return nil, nil
    end
    local tgt, tScore = nil, 1e9
    local live = workspace:FindFirstChild("Live")
    if live then
        for _, n in ipairs(live:GetChildren()) do
            local s = scoreModel(n)
            if s and s < tScore then tScore, tgt = s, n end
        end
    end
    if sLock ~= nil and lockValid(sLock) then
        local cs = scoreModel(sLock)
        if cs ~= nil and (tgt == nil or tgt == sLock or tScore >= cs * 0.9) then
            local hrp = sLock:FindFirstChild("HumanoidRootPart")
            if hrp then sPos, sMissT = hrp.Position, 0 return sLock, sPos end
        end
    end
    if tgt then
        local hrp = tgt:FindFirstChild("HumanoidRootPart")
        if hrp then
            sLock, sPos, sMissT = tgt, hrp.Position, 0
            return sLock, sPos
        end
    end
    if sLock ~= nil then
        if sMissT == 0 then sMissT = os.clock() end
        if os.clock() - sMissT < 0.15 then
            return sLock, sPos
        end
    end
    sLock, sPos, sMissT = nil, nil, 0
    return nil, nil
end

-- [BLUE CLUSTER] Points Farm Mode: densest crowd anywhere on map, no FOV needed
local function getBlueClusterTarget()
    local ok, resModel, resPos = pcall(function()
        local c = LP.Character
        if not c then return nil, nil end
        local live = workspace:FindFirstChild("Live")
        if not live then return nil, nil end
        local radius = tonumber(getgenv().EsaBlueClusterRadius) or 22
        local cands = {}
        for _, m in ipairs(live:GetChildren()) do
            if m ~= c and m.Name ~= LP.Name and not m:FindFirstChild("NoTarg") then
                if not (getgenv().EsaTeamCheck and aimIsTeammate(m)) then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    local hrp = m:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and hrp then
                        table.insert(cands, {model = m, pos = hrp.Position})
                    end
                end
            end
        end
        if #cands == 0 then return nil, nil end
        local myHrp = c:FindFirstChild("HumanoidRootPart")
        local myPos = myHrp and myHrp.Position or nil
        local best = nil
        for i = 1, #cands do
            local members, sx, sy, sz = {}, 0, 0, 0
            for j = 1, #cands do
                local d = cands[j].pos - cands[i].pos
                if d.X * d.X + d.Z * d.Z <= radius * radius then
                    table.insert(members, cands[j])
                    sx, sy, sz = sx + cands[j].pos.X, sy + cands[j].pos.Y, sz + cands[j].pos.Z
                end
            end
            local n = #members
            local centroid = Vector3.new(sx / n, sy / n, sz / n)
            local take = false
            if not best then take = true
            elseif n > best.n then take = true
            elseif n == best.n and myPos and (centroid - myPos).Magnitude < (best.pos - myPos).Magnitude then take = true end
            if take then best = {members = members, pos = centroid, n = n} end
        end
        if not best then return nil, nil end
        return best.members[1].model, best.pos
    end)
    if ok and resModel and resPos then
        return resModel, resPos
    end
    return nil, nil
end

local function restoreCam(hum)
    local cam = workspace.CurrentCamera
    if pinned then
        pinned = false
        pcall(function()
            cam.CameraType = Enum.CameraType.Custom
            if hum then cam.CameraSubject = hum end
        end)
    end
end

local function handleBoogieWoogie(a1, a2)
    local ok, res = pcall(function()
        local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
        if tgtModel then
            warn("[BoogieWoogie] Swapped with cursor target: " .. tgtModel.Name)
            pcall(function()
                if WindUI and WindUI.Notify then
                    WindUI:Notify({
                        Title = "Boogie Woogie 👏",
                        Content = "Swapped ▸ " .. tgtModel.Name,
                        Duration = 1.5,
                        Icon = "refresh-cw"
                    })
                end
            end)
            return tgtModel
        end
        local mouse = LP:GetMouse()
        local mt = mouse and mouse.Target
        local mc = mt and mt:FindFirstAncestorOfClass("Model")
        if mc and mc ~= LP.Character and mc:FindFirstChild("HumanoidRootPart") then return mc end
        return a1
    end)
    if ok and res then return res end
    return a1
end

local function handleShambles(a1, a2)
    local ok, res = pcall(function()
        local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
        if tgtModel then
            warn("[Shambles] Swapped with cursor target: " .. tgtModel.Name)
            pcall(function()
                if WindUI and WindUI.Notify then
                    WindUI:Notify({
                        Title = "Shambles 🔵",
                        Content = "Swapped ▸ " .. tgtModel.Name,
                        Duration = 1.5,
                        Icon = "refresh-cw"
                    })
                end
            end)
            return tgtModel
        end
        local mouse = LP:GetMouse()
        local mt = mouse and mouse.Target
        local mc = mt and mt:FindFirstAncestorOfClass("Model")
        if mc and mc ~= LP.Character and mc:FindFirstChild("HumanoidRootPart") then return mc end
        return a1
    end)
    if ok and res then return res end
    return a1
end

local function ensureHeroRemotes()
    local rs = game:GetService("ReplicatedStorage")
    local bw = rs:FindFirstChild("GetBoogieWoogieTarget")
    if bw then pcall(function() bw.OnClientInvoke = handleBoogieWoogie end) end
    local sh = rs:FindFirstChild("GetShamblesTarget")
    if sh then pcall(function() sh.OnClientInvoke = handleShambles end) end
    local isLook = rs:FindFirstChild("IsLookingAt")
    if isLook then pcall(function() isLook.OnClientInvoke = function() return true end end) end
end
ensureHeroRemotes()
task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(2)
        ensureHeroRemotes()
    end
end)

local function castMove(toolName, slot)
    pcall(function()
        local cam = workspace.CurrentCamera
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local mouse = LP:GetMouse()
        local pkt = {
            ToolName = tostring(toolName),
            range = tostring(slot or 1),
            air = (hrp and hrp.Velocity.Y > 5) or false,
            running = (hrp and hrp.Velocity.Magnitude > 20) or false,
            campos = cam and cam.CFrame.Position or Vector3.zero,
            camdir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1),
            mousehit = mouse and mouse.Hit or CFrame.new(),
            neutral = true,
            spacedown = false
        }
        Input:FireServer("UseMove", pkt)
    end)
end

-- =====================================================================
-- [UNIVERSAL SILENT AIM ENGINE]
-- =====================================================================
local silentFovCircle = nil
pcall(function()
    if Drawing and Drawing.new then
        silentFovCircle = Drawing.new("Circle")
        silentFovCircle.Thickness = 1.5
        silentFovCircle.NumSides = 48
        silentFovCircle.Radius = getgenv().EsaSilentFOV or 220
        silentFovCircle.Filled = false
        silentFovCircle.Color = Color3.fromRGB(0, 220, 255)
        silentFovCircle.Transparency = 0.8
        silentFovCircle.Visible = false
        getgenv().EsaSilentCircle = silentFovCircle
    end
end)

local function getSilentAimTarget(toolName)
    if not getgenv().EsaSilentAimEnabled then return nil, nil end
    return getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
end

pcall(function()
    if typeof(hookmetamethod) == "function" and typeof(newcclosure) == "function" then
        if getgenv()._EsaOldNamecall then return end
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = (typeof(getnamecallmethod) == "function" and getnamecallmethod()) or ""
            local args = {...}
            if not (typeof(checkcaller) == "function" and checkcaller()) and method == "FireServer" and typeof(self) == "Instance" and self.Name == "Input" and args[1] == "UseMove" then
                if getgenv().EsaSilentAimEnabled then
                    pcall(function()
                        local pkt = args[2]
                        if type(pkt) == "table" then
                            local tgtModel, tgtPos = getSilentAimTarget(pkt.ToolName)
                            if tgtModel and tgtPos then
                                pkt.targ = tgtModel
                                pkt.teamtarg = tgtModel
                                local cam = workspace.CurrentCamera
                                local origin = pkt.campos or (cam and cam.CFrame.Position) or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character.HumanoidRootPart.Position) or Vector3.zero
                                local dir = (tgtPos - origin)
                                if dir.Magnitude > 0 then
                                    pkt.camdir = dir.Unit
                                    pkt.mousehit = CFrame.new(tgtPos, tgtPos + dir.Unit)
                                end
                                -- (HRP facing snap removed: caused player warp/rubber-band; packet redirect only)
                                if getgenv().EsaSilentNotify then
                                    task.spawn(function()
                                        pcall(function()
                                            local name = tostring(pkt.ToolName or "Skill")
                                            local tName = tostring(tgtModel.Name)
                                            WindUI:Notify({
                                                Title = "Silent Aim Lock 🎯",
                                                Content = name .. " ▸ " .. tName,
                                                Duration = 1.5,
                                                Icon = "crosshair"
                                            })
                                        end)
                                    end)
                                end
                            end
                        end
                    end)
                end
            end
            if typeof(setnamecallmethod) == "function" then
                setnamecallmethod(method)
            end
            return oldNamecall(self, ...)
        end))
        getgenv()._EsaOldNamecall = oldNamecall
    end
end)

getgenv().EsaConn_silent_fov = RS.RenderStepped:Connect(function()
    if silentFovCircle then
        local show = getgenv().EsaSilentAimEnabled and getgenv().EsaSilentShowFOV and (getgenv().EsaSilentMode == "FOV")
        silentFovCircle.Visible = show
        if show then
            local mp = UIS:GetMouseLocation()
            silentFovCircle.Position = mp
            silentFovCircle.Radius = tonumber(getgenv().EsaSilentFOV) or 220
        end
    end
end)

local tagGui = Instance.new("BillboardGui")
tagGui.Name = "EsaBlueTag"
tagGui.ResetOnSpawn = false
tagGui.Size = UDim2.new(0, 170, 0, 30)
tagGui.StudsOffset = Vector3.new(0, 3.5, 0)
tagGui.AlwaysOnTop = true
tagGui.Enabled = false
tagGui.Parent = LP:WaitForChild("PlayerGui")
local tagLabel = Instance.new("TextLabel")
tagLabel.Size = UDim2.new(1, 0, 1, 0)
tagLabel.BackgroundTransparency = 1
tagLabel.Font = Enum.Font.GothamBold
tagLabel.TextSize = 18
tagLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
tagLabel.TextStrokeTransparency = 0.3
tagLabel.Text = ""
tagLabel.Parent = tagGui

local tagShownModel, tagShownText = nil, nil
local laserLine = nil
pcall(function()
    local old = getgenv().EsaBlueLaserLine
    if old then pcall(function() old:Remove() end) end
    getgenv().EsaBlueLaserLine = nil
    if typeof(Drawing) == "table" and typeof(Drawing.new) == "function" then
        laserLine = Drawing.new("Line")
        laserLine.Thickness = 1.5
        laserLine.Transparency = 0.9
        laserLine.Color = Color3.fromRGB(255, 60, 60)
        laserLine.Visible = false
        laserLine.ZIndex = 4
        getgenv().EsaBlueLaserLine = laserLine
    end
end)
local function setLaser(fromPos, toPos, color)
    if not laserLine then return end
    pcall(function()
        if not getgenv().EsaBlueTracer then laserLine.Visible = false return end
        local cam = workspace.CurrentCamera
        if not cam or typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then
            laserLine.Visible = false
            return
        end
        local fScreen, fOn = cam:WorldToViewportPoint(fromPos)
        local tScreen, tOn = cam:WorldToViewportPoint(toPos)
        if fOn and tOn and fScreen.Z > 0 and tScreen.Z > 0 then
            laserLine.From = Vector2.new(fScreen.X, fScreen.Y)
            laserLine.To = Vector2.new(tScreen.X, tScreen.Y)
            laserLine.Color = color or Color3.fromRGB(255, 60, 60)
            laserLine.Visible = true
        else
            laserLine.Visible = false
        end
    end)
end

local function setTag(model)
    pcall(function()
        if model and model.Parent and getgenv().EsaBlueTracer then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp then
                local txt = grabMoveShort() .. " ▸ " .. tostring(model.Name)
                if tagShownModel ~= model or tagShownText ~= txt then
                    tagGui.Adornee = hrp
                    tagLabel.Text = txt
                    tagShownModel, tagShownText = model, txt
                end
                if not tagGui.Enabled then tagGui.Enabled = true end
                return
            end
        end
        if tagGui.Enabled then tagGui.Enabled = false end
        tagShownModel, tagShownText = nil, nil
    end)
end

local function hideTracer()
    pcall(function()
        if tagGui.Enabled then tagGui.Enabled = false end
        tagShownModel, tagShownText = nil, nil
        if laserLine then laserLine.Visible = false end
    end)
end

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "EsaBlueFov"
fovGui.ResetOnSpawn = false
fovGui.DisplayOrder = 998
fovGui.IgnoreGuiInset = true
fovGui.Parent = LP:WaitForChild("PlayerGui")
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Size = UDim2.new(0, 140, 0, 140)
ring.BackgroundTransparency = 1
ring.Visible = false
ring.Parent = fovGui
local ringRound = Instance.new("UICorner")
ringRound.CornerRadius = UDim.new(1, 0)
ringRound.Parent = ring
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 2
ringStroke.Color = Color3.fromRGB(255, 255, 255)
ringStroke.Transparency = 0.3
ringStroke.Parent = ring

local function updateFov(locked)
    pcall(function()
        if not getgenv().EsaBlueFov then ring.Visible = false return end
        local ds = tonumber(getgenv().EsaBlueFovSize) or 140
        ring.Size = UDim2.new(0, ds, 0, ds)
        local mp = UIS:GetMouseLocation()
        ring.Position = UDim2.new(0, mp.X, 0, mp.Y)
        if locked then
            ringStroke.Color = Color3.fromRGB(255, 60, 60)
        else
            ringStroke.Color = Color3.fromRGB(255, 255, 255)
        end
        ring.Visible = true
    end)
end

local function hideFov()
    pcall(function() ring.Visible = false end)
end

local lockHL = Instance.new("Highlight")
lockHL.Name = "EsaLockHL"
lockHL.FillColor = Color3.fromRGB(255, 40, 40)
lockHL.FillTransparency = 0.85
lockHL.OutlineColor = Color3.fromRGB(255, 40, 40)
lockHL.OutlineTransparency = 0
lockHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
lockHL.Enabled = false
pcall(function() lockHL.Parent = LP:WaitForChild("PlayerGui") end)

local function setLockHL(model)
    pcall(function()
        if model and model.Parent and getgenv().EsaBlueTracer then
            if lockHL.Adornee ~= model then lockHL.Adornee = model end
            if not lockHL.Enabled then lockHL.Enabled = true end
        else
            if lockHL.Enabled then lockHL.Enabled = false end
            if lockHL.Adornee ~= nil then lockHL.Adornee = nil end
        end
    end)
end

local function fireDetonate(lockModel, tp)
    pcall(function()
        if typeof(mouse1click) == "function" then mouse1click() end
    end)
    pcall(function()
        local bp = LP:FindFirstChild("Backpack")
        local input = bp and bp:FindFirstChild("Input")
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local cam = workspace.CurrentCamera
        if not (input and hum and cam and tp) then return end
        local toolName = grabMoveName()
        local camPos = cam.CFrame.Position
        local dir = (tp - camPos)
        if dir.Magnitude < 1 then return end
        dir = dir / dir.Magnitude
        local pkt = {
            ToolName = toolName,
            range = "5",
            air = hum.FloorMaterial == Enum.Material.Air,
            running = hum.MoveDirection.Magnitude > 0,
            campos = camPos,
            camdir = dir,
            targ = lockModel,
            teamtarg = lockModel,
            mousehit = CFrame.new(tp, tp + dir),
            neutral = hum.MoveDirection.Magnitude <= 0,
            spacedown = false,
        }
        input:FireServer("UseMove", pkt)
        warn("[GrabBlue] detonate " .. toolName .. " vs " .. (lockModel and lockModel.Name or "mouse-point"))
    end)
end

-- Manual detonate on repeated key press or click (กดย้ำๆ ก็ระเบิด)
getgenv().EsaConn_blue_tap = UIS.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if REV ~= getgenv().EsaRev_main then return end
    local g = mobGrab
    if g and g.ball and g.ball.Parent and not g.detonated then
        local kc = io.KeyCode
        local it = io.UserInputType
        if kc == Enum.KeyCode.Three or kc == Enum.KeyCode.One or kc == Enum.KeyCode.Two or kc == Enum.KeyCode.Four or it == Enum.UserInputType.MouseButton1 then
            g.detonated = true
            local lockModel, tp = nextLock()
            local detPos = tp or (g.ball and g.ball.Position) or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character.HumanoidRootPart.Position)
            fireDetonate(lockModel, detPos)
            warn("[GrabBlue] Manual double-tap / click detonate triggered!")
        end
    end
end)

-- T = toggle Blue mode: NORMAL (cursor) <-> POINT (cluster)
getgenv().EsaConn_blue_mode_toggle = UIS.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if REV ~= getgenv().EsaRev_main then return end
    if io.KeyCode == Enum.KeyCode.T then
        getgenv().EsaBlueCluster = not getgenv().EsaBlueCluster
        saveConfig()
        warn("[BlueMode] " .. (getgenv().EsaBlueCluster and "POINT (cluster)" or "NORMAL (cursor)"))
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Blue Mode",
                Text = getgenv().EsaBlueCluster and "POINT: รวมกลุ่มทั้งแมพ" or "NORMAL: ล็อกเคอร์เซอร์",
                Duration = 1.5,
            })
        end)
    end
end)

local tagStable, tagStableT, tagMissT = nil, 0, 0
task.spawn(function()
    while REV == getgenv().EsaRev_main do
        local g = mobGrab
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local valid = getgenv().EsaBlueAuto and g and g.ball and g.ball.Parent and hum and hum.Health > 0
        if valid then
            if not g.zeroed and g.bp and g.bp.Parent then
                pcall(function() g.bp.MaxForce = Vector3.zero g.bp.P = 0 end)
                g.zeroed = true
            end
            local bp = g.ball.Position
            local lockModel, tp
            if getgenv().EsaBlueCluster then
                lockModel, tp = getBlueClusterTarget()
            else
                lockModel, tp = nextLock()
            end
            -- Sticky chase: once locked, keep following that model (with velocity lead)
            -- even if cursor slips off, so runners can't escape the ball
            if lockModel then
                g.chase = lockModel
            elseif g.chase and lockValid(g.chase) then
                local chrp = g.chase:FindFirstChild("HumanoidRootPart")
                if chrp then
                    lockModel = g.chase
                    tp = chrp.Position + chrp.Velocity * (tonumber(getgenv().EsaSilentPredict) or 0.12)
                else
                    g.chase = nil
                end
            else
                g.chase = nil
            end
            if tp then
                local d = (tp - bp)
                if d.Magnitude > 1 then
                    local mult = getgenv().EsaBlueSpeed or 0
                    local step = (mult and mult > 0) and math.min(d.Magnitude, (g.speed or 120) * (1/30) * mult) or d.Magnitude
                    pcall(function()
                        g.ball.CFrame = CFrame.new(bp + d.Unit * step) * (g.ball.CFrame - bp)
                    end)
                end
                setLaser(bp, tp, Color3.fromRGB(255, 60, 60))
                if tagStable ~= lockModel then tagStable, tagStableT = lockModel, os.clock() end
                tagMissT = 0
                if lockModel and os.clock() - tagStableT >= 0.05 then
                    setTag(lockModel)
                    setLockHL(lockModel)
                end
                if getgenv().EsaBlueAutoDetonate and not g.detonated and lockModel then
                    g.detonated = true
                    getgenv().EsaGrabDbg = {lock = lockModel.Name, fired = true}
                    fireDetonate(lockModel, tp)
                end
            else
                local firedProx = false
                if getgenv().EsaBlueAutoDetonate and not g.detonated then
                    pcall(function()
                        local live = workspace:FindFirstChild("Live")
                        local c = LP.Character
                        local proxR = tonumber(getgenv().EsaBlueDetonateDist) or 14
                        if live and c then
                            local best, bestD = nil, proxR
                            for _, n in ipairs(live:GetChildren()) do
                                if n ~= c and n.Name ~= LP.Name and not n:FindFirstChild("NoTarg") then
                                    if not (getgenv().EsaTeamCheck and aimIsTeammate(n)) then
                                        local h = n:FindFirstChildOfClass("Humanoid")
                                        local r = n:FindFirstChild("HumanoidRootPart")
                                        if h and h.Health > 0 and r then
                                            local dd = (r.Position - bp).Magnitude
                                            if dd < bestD then bestD, best = dd, n end
                                        end
                                    end
                                end
                            end
                            if best then
                                local er = best:FindFirstChild("HumanoidRootPart")
                                g.detonated = true
                                getgenv().EsaGrabDbg = {lock = best.Name, fired = true, prox = true}
                                fireDetonate(best, er.Position)
                                firedProx = true
                            end
                        end
                    end)
                end
                if not firedProx then
                    hideTracer()
                    setLockHL(nil)
                    tagStable, tagMissT = nil, 0
                end
            end
            task.wait()
        else
            hideTracer()
            setLockHL(nil)
            if mobGrab and not (mobGrab.ball and mobGrab.ball.Parent) then mobGrab = nil end
            if pinned then restoreCam(hum) end
            task.wait(0.12)
        end
    end
    local ch = LP.Character
    restoreCam(ch and ch:FindFirstChildOfClass("Humanoid"))
end)

task.spawn(function()
    local lockModel, tick = nil, 0
    local shownLocked, lastSeen, sameCount = false, false, 0
    while REV == getgenv().EsaRev_main do
        local g = mobGrab
        local grabbing = g and g.ball and g.ball.Parent
        if grabbing then
            updateFov(shownLocked)
            task.wait(0.03)
        elseif getgenv().EsaAimPreview then
            tick = tick + 1
            if tick % 2 == 0 then
                lockModel = nextLock()
            end
            hideTracer()
            local lockedNow = lockModel ~= nil
            if lockedNow == lastSeen then
                sameCount = sameCount + 1
            else
                sameCount, lastSeen = 1, lockedNow
            end
            if sameCount >= 2 then shownLocked = lockedNow end
            updateFov(shownLocked)
            task.wait(0.05)
        else
            hideFov()
            hideTracer()
            lockModel = nil
            shownLocked, lastSeen, sameCount = false, false, 0
            task.wait(0.2)
        end
    end
end)


-- =====================================================================
-- [TRADE] REMOVED (AutoBlock deleted per request; manual play only)
-- =====================================================================

-- [AUTO-M1 REMOVED] Pure manual M1 control restored without accidental swings or hold interruptions

-- =====================================================================
-- [NANAMI] NanamiTiming: Ratio 0.7 auto-hit
-- =====================================================================
local function nanamiHook(a1, a2, a3)
    if not getgenv().EsaNanamiAuto then
        local dur = tonumber(a2) or 1
        task.wait(dur)
        return false, nil, true
    end
    -- 100% Guaranteed 0.7 Ratio critical hit
    task.wait(0.05)
    return true, nil, true
end

local function ensureNanamiHook()
    local n = game.ReplicatedStorage:FindFirstChild("NanamiCheck")
    if n then pcall(function() n.OnClientInvoke = nanamiHook end) end
end

ensureNanamiHook()
task.spawn(function()
    while REV == getgenv().EsaRev_main do task.wait(5) ensureNanamiHook() end
end)

-- =====================================================================
-- [DEIDARA] Clay Birds & Spiders Auto-Steer + Detonate
-- =====================================================================
local deidaraEntities = {}

local function isDeidaraClayName(name)
    local n = string.lower(tostring(name))
    return string.find(n, "bird") ~= nil
        or string.find(n, "bug") ~= nil
        or string.find(n, "spider") ~= nil
        or string.find(n, "c1") ~= nil
        or string.find(n, "c2") ~= nil
        or string.find(n, "c4") ~= nil
        or string.find(n, "clay") ~= nil
        or string.find(n, "karura") ~= nil
end

local function monitorClay(child)
    pcall(function()
        local myChar = LP.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        if isDeidaraClayName(child.Name) or child:IsA("BasePart") or child:IsA("Model") then
            task.wait(0.03)
            local pos = child:IsA("BasePart") and child.Position or (child:IsA("Model") and child:GetPivot().Position)
            if pos and (pos - myHrp.Position).Magnitude < 35 then
                table.insert(deidaraEntities, child)
            end
        end
    end)
end

workspace.ChildAdded:Connect(function(child)
    if REV ~= getgenv().EsaRev_main then return end
    if not getgenv().EsaDeidaraAuto then return end
    monitorClay(child)
end)

pcall(function()
    local th = workspace:FindFirstChild("Thrown")
    if th then
        th.ChildAdded:Connect(function(child)
            if REV ~= getgenv().EsaRev_main then return end
            if not getgenv().EsaDeidaraAuto then return end
            monitorClay(child)
        end)
    end
end)

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.05)
        if not getgenv().EsaDeidaraAuto or #deidaraEntities == 0 then
            task.wait(0.2)
            continue
        end
        pcall(function()
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end

            local targetModel, targetPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
            if not targetModel then return end
            local targetHrp = targetModel:FindFirstChild("HumanoidRootPart")
            if not targetHrp then return end

            local speed = tonumber(getgenv().EsaDeidaraSpeed) or 95

            for i = #deidaraEntities, 1, -1 do
                local entity = deidaraEntities[i]
                if not entity or not entity.Parent then
                    table.remove(deidaraEntities, i)
                else
                    local rootPart = entity:IsA("BasePart") and entity or (entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChildOfClass("BasePart"))
                    if rootPart then
                        local dir = (targetHrp.Position - rootPart.Position)
                        local dist = dir.Magnitude
                        if dist < 8 and getgenv().EsaDeidaraDetonate then
                            table.remove(deidaraEntities, i)
                        else
                            local bv = rootPart:FindFirstChildOfClass("BodyVelocity")
                            if bv then
                                bv.Velocity = dir.Unit * speed
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- [AUTO-COUNTER] Frame-1 Reaction (Diavolo, Aizen, Joseph, etc.)
-- =====================================================================
local counterLastUse = 0

local function getCounterMoveInfo()
    local moves = LP.PlayerGui and LP.PlayerGui:FindFirstChild("HUD") and LP.PlayerGui.HUD:FindFirstChild("Moves")
    if not moves then return nil, nil end
    local keywords = { "epitaph", "suigetsu", "kyoka", "your next line", "counter", "full counter", "gigai", "love is war", "barrier" }
    for _, btn in ipairs(moves:GetChildren()) do
        if btn:IsA("ImageButton") then
            local ok, mn = pcall(function() return btn:GetAttribute("MoveName") end)
            if ok and mn then
                local low = string.lower(tostring(mn))
                for _, kw in ipairs(keywords) do
                    if string.find(low, kw) then
                        local cov = btn:FindFirstChild("DisableCover")
                        local onCd = cov and cov.Visible
                        if not onCd then
                            return tostring(mn), tonumber(btn.Name) or 1
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        if not getgenv().EsaAutoCounter then
            task.wait(0.25)
            continue
        end
        if os.clock() - counterLastUse < 1.0 then
            task.wait(0.1)
            continue
        end
        local moveName, slot = getCounterMoveInfo()
        if not moveName then
            task.wait(0.5)
            continue
        end
        task.wait(0.03)
        pcall(function()
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp or myChar:HasTag("Attacking") then return end

            local live = workspace:FindFirstChild("Live")
            if not live then return end

            local maxDist = tonumber(getgenv().EsaCounterRange) or 16
            local attackerFound = false

            for _, enemy in ipairs(live:GetChildren()) do
                if enemy == myChar or enemy.Name == LP.Name then continue end
                if enemy:FindFirstChild("NoTarg") then continue end
                if getgenv().EsaTeamCheck and aimIsTeammate(enemy) then continue end

                local eHrp = enemy:FindFirstChild("HumanoidRootPart")
                local eHum = enemy:FindFirstChildOfClass("Humanoid")
                if eHrp and eHum and eHum.Health > 0 then
                    local dist = (eHrp.Position - myHrp.Position).Magnitude
                    if dist <= maxDist then
                        local isAttacking = enemy:HasTag("Attacking") or enemy:HasTag("M1")
                        if not isAttacking and eHum then
                            for _, tr in ipairs(eHum:GetPlayingAnimationTracks()) do
                                if tr.IsPlaying and (tr.Priority == Enum.AnimationPriority.Action or tr.Priority == Enum.AnimationPriority.Action2 or tr.Priority == Enum.AnimationPriority.Action3 or tr.Priority == Enum.AnimationPriority.Action4) then
                                    isAttacking = true
                                    break
                                end
                            end
                        end
                        if not isAttacking then
                            local busy = enemy:FindFirstChild("Busy")
                            if busy and busy:IsA("BoolValue") and busy.Value == true then
                                isAttacking = true
                            end
                        end
                        local facingMe = (myHrp.Position - eHrp.Position).Unit:Dot(eHrp.CFrame.LookVector) > 0.35
                        if isAttacking and facingMe then
                            attackerFound = true
                            break
                        end
                    end
                end
            end

            if attackerFound then
                counterLastUse = os.clock()
                castMove(moveName, slot)
                warn("[AutoCounter] Frame-1 triggered: " .. tostring(moveName))
            end
        end)
    end
end)

-- =====================================================================
-- [KIRA] Sheer Heart Attack (SHA) Supersonic Boost & Detonate
-- =====================================================================
local kiraSHAs = {}
workspace.ChildAdded:Connect(function(child)
    if REV ~= getgenv().EsaRev_main then return end
    if not getgenv().EsaKiraSHA then return end
    pcall(function()
        local n = string.lower(child.Name)
        if string.find(n, "heart attack") or string.find(n, "sha") then
            task.wait(0.04)
            table.insert(kiraSHAs, child)
        end
    end)
end)

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.05)
        if not getgenv().EsaKiraSHA or #kiraSHAs == 0 then
            task.wait(0.2)
            continue
        end
        pcall(function()
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end

            local live = workspace:FindFirstChild("Live")
            if not live then return end

            local speed = tonumber(getgenv().EsaSHASpeed) or 130
            for i = #kiraSHAs, 1, -1 do
                local obj = kiraSHAs[i]
                if not obj or not obj.Parent then
                    table.remove(kiraSHAs, i)
                else
                    local root = obj:IsA("BasePart") and obj or (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart"))
                    if root then
                        for _, enemy in ipairs(live:GetChildren()) do
                            if enemy == myChar or enemy.Name == LP.Name then continue end
                            local eHrp = enemy:FindFirstChild("HumanoidRootPart")
                            local eHum = enemy:FindFirstChildOfClass("Humanoid")
                            if eHrp and eHum and eHum.Health > 0 then
                                local dir = (eHrp.Position - root.Position)
                                local bv = root:FindFirstChildOfClass("BodyVelocity")
                                if bv then
                                    bv.Velocity = dir.Unit * speed
                                end
                                break
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- [UNIVERSAL COMBAT] Auto-Awakening (G) & One-Key Combo Macro (V)
-- =====================================================================
local autoAwakenCooldown = 0
task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.25)
        if not getgenv().EsaAutoAwaken then continue end
        if os.clock() - autoAwakenCooldown < 5 then continue end
        pcall(function()
            local myChar = LP.Character
            local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end

            local thresh = (tonumber(getgenv().EsaAutoAwakenHp) or 25) / 100
            if (hum.Health / math.max(hum.MaxHealth, 1)) <= thresh then
                local hasMode = myChar:FindFirstChild("Mode") ~= nil or myChar:GetAttribute("Mode") ~= nil
                if not hasMode then
                    autoAwakenCooldown = os.clock()
                    Input:FireServer("Awakening")
                    warn("[AutoAwaken] Emergency Burst triggered!")
                end
            end
        end)
    end
end)

-- [COMBO MACRO REMOVED] Removed mouse1click to preserve natural hold-to-attack

-- =====================================================================
-- [TODO AOI] Boogie Woogie (Clap / Swap Position)
-- =====================================================================
local todoLastClap = 0
local function getTodoMoveInfo()
    local moves = LP.PlayerGui and LP.PlayerGui:FindFirstChild("HUD") and LP.PlayerGui.HUD:FindFirstChild("Moves")
    if not moves then return nil, nil end
    for _, btn in ipairs(moves:GetChildren()) do
        if btn:IsA("ImageButton") then
            local ok, mn = pcall(function() return btn:GetAttribute("MoveName") end)
            if ok and mn then
                local low = string.lower(tostring(mn))
                if string.find(low, "boogie") or string.find(low, "swap") or string.find(low, "clap") then
                    local cov = btn:FindFirstChild("DisableCover")
                    local onCd = cov and cov.Visible
                    if not onCd then
                        return tostring(mn), tonumber(btn.Name) or 1
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Boogie Woogie auto-aim swap is seamlessly handled by GetBoogieWoogieTarget hook!
-- When the player casts Move 1 (Boogie Woogie), it automatically targets the enemy.

-- =====================================================================
-- [MINATO] Flying Raijin Kunai Homing & Teleport
-- =====================================================================
local minatoKunais = {}
workspace.ChildAdded:Connect(function(child)
    if REV ~= getgenv().EsaRev_main then return end
    if not getgenv().EsaMinatoKunai then return end
    pcall(function()
        local low = string.lower(child.Name)
        if string.find(low, "kunai") or string.find(low, "raijin") then
            task.wait(0.04)
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local pos = child:IsA("BasePart") and child.Position or (child:IsA("Model") and child:GetPivot().Position)
            if myHrp and pos and (pos - myHrp.Position).Magnitude < 30 then
                table.insert(minatoKunais, child)
            end
        end
    end)
end)

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.05)
        if not getgenv().EsaMinatoKunai or #minatoKunais == 0 then
            task.wait(0.2)
            continue
        end
        pcall(function()
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end

            local live = workspace:FindFirstChild("Live")
            if not live then return end

            local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
            if not tgtModel then return end
            local targetHrp = tgtModel:FindFirstChild("HumanoidRootPart")
            if not targetHrp then return end

            for i = #minatoKunais, 1, -1 do
                local kn = minatoKunais[i]
                if not kn or not kn.Parent then
                    table.remove(minatoKunais, i)
                else
                    local part = kn:IsA("BasePart") and kn or kn:FindFirstChildOfClass("BasePart")
                    if part then
                        local bv = part:FindFirstChildOfClass("BodyVelocity")
                        if bv then
                            bv.Velocity = (targetHrp.Position - part.Position).Unit * 120
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- [COYOTE STARRK] Los Lobos Spirit Wolves Homing & Detonate
-- =====================================================================
local starrkWolves = {}
workspace.ChildAdded:Connect(function(child)
    if REV ~= getgenv().EsaRev_main then return end
    if not getgenv().EsaStarrkWolves then return end
    pcall(function()
        local low = string.lower(child.Name)
        if string.find(low, "wolf") or string.find(low, "wolves") or string.find(low, "lobos") then
            task.wait(0.04)
            table.insert(starrkWolves, child)
        end
    end)
end)

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.05)
        if not getgenv().EsaStarrkWolves or #starrkWolves == 0 then
            task.wait(0.2)
            continue
        end
        pcall(function()
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end

            local live = workspace:FindFirstChild("Live")
            if not live then return end

            local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
            if not tgtModel then return end
            local targetHrp = tgtModel:FindFirstChild("HumanoidRootPart")
            if not targetHrp then return end

            local speed = tonumber(getgenv().EsaStarrkSpeed) or 110
            for i = #starrkWolves, 1, -1 do
                local w = starrkWolves[i]
                if not w or not w.Parent then
                    table.remove(starrkWolves, i)
                else
                    local root = w:IsA("BasePart") and w or (w:FindFirstChild("HumanoidRootPart") or w:FindFirstChildOfClass("BasePart"))
                    if root then
                        local dir = (targetHrp.Position - root.Position)
                        if dir.Magnitude < 8 then
                            table.remove(starrkWolves, i)
                        else
                            local bv = root:FindFirstChildOfClass("BodyVelocity")
                            if bv then
                                bv.Velocity = dir.Unit * speed
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- [URAHARA] Portable Gigai Emergency Combo Breaker
-- =====================================================================
local uraharaLastGigai = 0
task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.2)
        if not getgenv().EsaUraharaGigai then continue end
        if os.clock() - uraharaLastGigai < 2.0 then continue end
        local myChar = LP.Character
        if not myChar or not (myChar:HasTag("Stunned") or myChar:FindFirstChild("Stunned")) then continue end
        pcall(function()
            local moves = LP.PlayerGui and LP.PlayerGui:FindFirstChild("HUD") and LP.PlayerGui.HUD:FindFirstChild("Moves")
            if moves then
                for _, btn in ipairs(moves:GetChildren()) do
                    if btn:IsA("ImageButton") then
                        local ok, mn = pcall(function() return btn:GetAttribute("MoveName") end)
                        if ok and mn and string.find(string.lower(tostring(mn)), "gigai") then
                            local cov = btn:FindFirstChild("DisableCover")
                            if not (cov and cov.Visible) then
                                uraharaLastGigai = os.clock()
                                castMove(tostring(mn), tonumber(btn.Name) or 1)
                                warn("[Urahara] Portable Gigai Combo Breaker triggered!")
                                break
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- =====================================================================
-- [RAIDEN] Metal Gear Blade Mode & Precision Zandatsu Cut
-- =====================================================================
local function bindRaidenBladeMode(remote)
    if not (remote and remote:IsA("RemoteEvent") and remote.Name == "BladeRemote") then return end
    task.spawn(function()
        warn("[Raiden] Blade Mode detected! Activating Precision Zandatsu auto-aim.")
        local char = LP.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end

        -- Snap BladePreview in workspace.Thrown to cursor target
        local snapConn
        snapConn = RS.Heartbeat:Connect(function()
            if not (remote and remote.Parent) then
                if snapConn then snapConn:Disconnect() end
                return
            end
            if getgenv().EsaRaidenAuto then
                pcall(function()
                    local bp = workspace.Thrown:FindFirstChild("BladePreview")
                    if bp then
                        local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
                        if tgtModel and tgtPos then
                            bp.CFrame = CFrame.new(tgtPos) * CFrame.Angles(0, 0, math.rad(5))
                        end
                    end
                end)
            end
        end)

        -- If instant cut is enabled, slice immediately on target closest to cursor
        if getgenv().EsaRaidenInstant then
            task.wait(0.08)
            local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
            if tgtModel and tgtPos and remote.Parent then
                local eHrp = tgtModel:FindFirstChild("HumanoidRootPart")
                if eHrp then
                    local cutCF = CFrame.new(eHrp.Position) * CFrame.Angles(0, 0, math.rad(5))
                    pcall(function() remote:FireServer("Left", cutCF) end)
                    warn("[Raiden] Instant Zandatsu executed on: " .. tgtModel.Name)
                    return
                end
            end
        end

        -- Assisted cut on M1 click
        local m1Conn
        m1Conn = UIS.InputBegan:Connect(function(io, gpe)
            if gpe then return end
            if not getgenv().EsaRaidenAuto then return end
            if not (remote and remote.Parent) then
                if m1Conn then m1Conn:Disconnect() end
                return
            end
            if io.UserInputType == Enum.UserInputType.MouseButton1 or io.KeyCode == Enum.KeyCode.ButtonR2 then
                local tgtModel, tgtPos = getUniversalCursorTarget(getgenv().EsaSilentFOV or 350)
                if tgtModel and tgtPos and remote.Parent then
                    local eHrp = tgtModel:FindFirstChild("HumanoidRootPart")
                    if eHrp then
                        local cutCF = CFrame.new(eHrp.Position) * CFrame.Angles(0, 0, math.rad(5))
                        pcall(function() remote:FireServer("Left", cutCF) end)
                        warn("[Raiden] Assisted Zandatsu cut executed on: " .. tgtModel.Name)
                    end
                end
            end
        end)

        remote.Destroying:Connect(function()
            if snapConn then snapConn:Disconnect() end
            if m1Conn then m1Conn:Disconnect() end
        end)
    end)
end

local function checkRaidenChar(c)
    if not c then return end
    local rem = c:FindFirstChild("BladeRemote")
    if rem then bindRaidenBladeMode(rem) end
    c.ChildAdded:Connect(function(ch)
        if ch.Name == "BladeRemote" then
            bindRaidenBladeMode(ch)
        end
    end)
end

if LP.Character then checkRaidenChar(LP.Character) end
LP.CharacterAdded:Connect(function(c)
    if REV ~= getgenv().EsaRev_main then return end
    checkRaidenChar(c)
end)

-- =====================================================================
-- [RESET] J = IY-style Instant Respawn & Teleport Back
-- =====================================================================
local RESET_KEY = Enum.KeyCode.J
local RESET_TIMEOUT = 10
local RESET_RETURN_DELAY = 0.3
local RESET_HIDE_GUIS = { "HUD", "MainMenu", "ScreenGui", "EmptyScreenGui" }

local function resetHideDeathUI()
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, n in ipairs(RESET_HIDE_GUIS) do
            local g = pg:FindFirstChild(n)
            if g and g:IsA("LayerCollector") and g.Enabled then
                g.Enabled = false
            end
        end
        local hud = pg:FindFirstChild("HUD")
        if hud then
            for _, n in ipairs({ "Died", "Wait", "Wait2", "GameMessage" }) do
                local lb = hud:FindFirstChild(n)
                if lb and lb:IsA("TextLabel") and lb.Text ~= "" then
                    lb.Text = ""
                end
            end
        end
    end)
end

local function resetShowDeathUI()
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, n in ipairs(RESET_HIDE_GUIS) do
            local g = pg:FindFirstChild(n)
            if g and g:IsA("LayerCollector") and not g.Enabled then
                if n ~= "MainMenu" then
                    g.Enabled = true
                end
            end
        end
    end)
end

local function resetWatchChar(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    hum.Died:Connect(function()
        if REV ~= getgenv().EsaRev_main then return end
        if not getgenv().EsaResetHideUI or not getgenv().EsaHidingDeath then return end
        task.spawn(function()
            while getgenv().EsaHidingDeath and REV == getgenv().EsaRev_main do
                resetHideDeathUI()
                RS.Heartbeat:Wait()
            end
        end)
    end)
end

local function resetNow()
    if REV ~= getgenv().EsaRev_main then return "superseded" end
    local c = LP and LP.Character
    if not c then return "no-character" end
    if c:HasTag("Reseting") then
        warn("[Reset] blocked: already Reseting")
        return "blocked-reseting"
    end
    local savedCF = nil
    pcall(function()
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then savedCF = hrp.CFrame end
    end)
    getgenv().EsaHidingDeath = true
    if getgenv().EsaResetHideUI then resetHideDeathUI() end
    pcall(function() c:BreakJoints() end)
    local t0 = tick()
    local newChar = nil
    while tick() - t0 < RESET_TIMEOUT do
        if REV ~= getgenv().EsaRev_main then
            getgenv().EsaHidingDeath = false
            resetShowDeathUI()
            return "superseded"
        end
        local nc = LP.Character
        if nc and nc ~= c then
            local hh = nc:FindFirstChildOfClass("Humanoid")
            local nr = nc:FindFirstChild("HumanoidRootPart")
            if hh and hh.Health > 0 and nr then
                newChar = nc
                break
            end
        end
        task.wait(0.1)
    end
    getgenv().EsaHidingDeath = false
    resetShowDeathUI()
    if not newChar then
        warn("[Reset] server ไม่เกิดให้ ลองตอนไม่ได้ใช้ท่า/อันติ")
        return "no-respawn"
    end
    resetWatchChar(newChar)
    if savedCF then
        task.wait(RESET_RETURN_DELAY)
        pcall(function()
            local nr = newChar:WaitForChild("HumanoidRootPart", 5)
            if nr then nr.CFrame = savedCF end
        end)
    end
    warn("[Reset] done")
    return "reset-fired"
end
getgenv().EsaResetNow = resetNow

getgenv().EsaConn_main_resetJ = UIS.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if REV ~= getgenv().EsaRev_main then return end
    if io.KeyCode == RESET_KEY then
        task.spawn(function()
            local ok, r = pcall(resetNow)
            warn("[Reset] J ->", ok and tostring(r) or ("ERROR " .. tostring(r)))
        end)
    end
end)

getgenv().EsaConn_main_resetAdded = LP.CharacterAdded:Connect(function(char)
    if REV ~= getgenv().EsaRev_main then return end
    getgenv().EsaHidingDeath = false
    resetShowDeathUI()
    task.spawn(function() resetWatchChar(char) end)
end)
if LP.Character then
    task.spawn(function() resetWatchChar(LP.Character) end)
end

-- =====================================================================
-- [AIM] M2 Hold AimLock (Smooth Tracking + Velocity Lead)
-- =====================================================================
local aimHolding, aimSession = false, 0
local aimCircle = nil

local function aimRemoveCircle()
    pcall(function()
        if aimCircle then aimCircle:Remove() aimCircle = nil end
    end)
    pcall(function()
        local old = getgenv().EsaAimCircleObj
        if old then old:Remove() end
        getgenv().EsaAimCircleObj = nil
    end)
end
aimRemoveCircle()

local function aimMakeCircle()
    aimRemoveCircle()
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if not ok or not c then return end
    c.Radius = tonumber(getgenv().EsaAimRadius) or 200
    c.Filled = false
    c.Color = Color3.fromRGB(255, 0, 130)
    c.Visible = getgenv().EsaAimCircle ~= false
    c.Transparency = 0
    c.Thickness = 1
    local cam = workspace.CurrentCamera
    if cam then
        c.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
    aimCircle = c
    getgenv().EsaAimCircleObj = c
end
aimMakeCircle()

local function isPlayerModel(model)
    if not model then return false end
    local p = game.Players:GetPlayerFromCharacter(model) or game.Players:FindFirstChild(model.Name)
    return p ~= nil
end

local function aimIsTeammate(model)
    if not model then return false end
    if model.Name == "FRIENDLYDUMMY" then return true end
    local p = game.Players:GetPlayerFromCharacter(model) or game.Players:FindFirstChild(model.Name)
    if not p then return false end
    if p == LP then return true end

    local vipMod = workspace:FindFirstChild("VipModifiers")
    if vipMod and vipMod:FindFirstChild("FriendlyFire") and vipMod.FriendlyFire.Value == true then
        return false
    end

    if LP.Team ~= nil and p.Team ~= nil and LP.Team == p.Team then
        return true
    end
    return false
end

local function aimValid(n)
    if n.Name == LP.Name or n:FindFirstChild("NoTarg") then return false end
    if getgenv().EsaTeamCheck and aimIsTeammate(n) then return false end
    local h = n:FindFirstChild("Humanoid")
    local r = n:FindFirstChild("HumanoidRootPart")
    if not h or h.Health <= 0 or not r then return false end
    local plr = game.Players:GetPlayerFromCharacter(n) or game.Players:FindFirstChild(n.Name)
    if plr and not n:HasTag("Loaded") then return false end
    return true
end

local function aimFind(mouseXY)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local radius = tonumber(getgenv().EsaAimRadius) or 200
    local live = workspace:FindFirstChild("Live")
    if not live then return nil end
    local best, bestD = nil, math.huge
    for _, n in ipairs(live:GetChildren()) do
        if aimValid(n) then
            local r = n:FindFirstChild("HumanoidRootPart")
            local sp, vis = cam:WorldToViewportPoint(r.Position)
            if vis then
                local d = (Vector2.new(mouseXY.X, mouseXY.Y) - Vector2.new(sp.X, sp.Y)).Magnitude
                if d < bestD and d < radius then
                    bestD, best = d, n
                end
            end
        end
    end
    return best
end

local function aimMouseXY()
    local ok, m = pcall(function() return UIS:GetMouseLocation() end)
    if ok and m then return m end
    return Vector2.new(400, 300)
end

getgenv().EsaConn_aim_m2 = UIS.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if REV ~= getgenv().EsaRev_main then return end
    if io.UserInputType == Enum.UserInputType.MouseButton2 then
        if not getgenv().EsaAimOn then return end
        aimHolding = true
        aimSession = aimSession + 1
        local mySes = aimSession
        task.spawn(function()
            local tgt = nil
            while aimHolding and mySes == aimSession and REV == getgenv().EsaRev_main do
                if not getgenv().EsaAimOn then break end
                local cam = workspace.CurrentCamera
                if not cam then task.wait() continue end
                if not (tgt and tgt.Parent and aimValid(tgt)) then
                    tgt = aimFind(aimMouseXY())
                end
                if tgt and tgt.Parent then
                    local hrp = tgt:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local k = tonumber(getgenv().EsaAimPredict) or 0.15
                        local future = hrp.CFrame + (hrp.Velocity * k + Vector3.new(0, 0.1, 0))
                        pcall(function()
                            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, future.Position)
                        end)
                    end
                end
                task.wait()
            end
        end)
    end
end)

local _aimOldEnded = getgenv().EsaConn_aim_m2end
if _aimOldEnded then pcall(function() _aimOldEnded:Disconnect() end) end
getgenv().EsaConn_aim_m2end = UIS.InputEnded:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHolding = false
    end
end)

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(0.1)
        pcall(function()
            if not aimCircle then aimMakeCircle() return end
            aimCircle.Radius = tonumber(getgenv().EsaAimRadius) or 200
            aimCircle.Visible = getgenv().EsaAimCircle ~= false and getgenv().EsaAimOn ~= false
            aimCircle.Position = aimMouseXY()
        end)
    end
end)

-- =====================================================================
-- [VISUALS / ESP] REMOVED per request (render loop + helpers deleted)
-- =====================================================================
if getgenv().EsaConn_esp_render then pcall(function() getgenv().EsaConn_esp_render:Disconnect() end) getgenv().EsaConn_esp_render = nil end
-- =====================================================================
-- [UI] WindUI panel (RightShift) — 8 tabs by category
-- =====================================================================
if getgenv().EsaWindUIWindow then
    pcall(function() getgenv().EsaWindUIWindow:Destroy() end)
    getgenv().EsaWindUIWindow = nil
end

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "ESA | ABA PRO",
    Icon = "zap",
    Author = "Anime Battle Arena",
    Folder = "EsaAba",
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightShift,
})
getgenv().EsaWindUIWindow = Window

local function buildEsaUI()
    local UniversalTab   = Window:Tab({ Title = "ทั่วไป (Universal)", Icon = "globe", Desc = "ระบบแกนหลัก ต่อสู้ & คอมโบ & ไทมิ่ง" })
local DefenseTab     = Window:Tab({ Title = "เทรด & ป้องกัน", Icon = "shield-check", Desc = "บล็อกเฟรม 1 & สวนกลับ & กันสถานะ" })
local MobilityTab    = Window:Tab({ Title = "คอมแบท", Icon = "wind", Desc = "ต่อย M1" })
local JjkTab         = Window:Tab({ Title = "มหาเวทย์ (JJK)", Icon = "sparkles", Desc = "โกโจ, สุคุนะ/ยูจิ, โทโด, นานามิ" })
local NarutoOpTab    = Window:Tab({ Title = "นินจา & วันพีซ", Icon = "flame", Desc = "มินาโตะ, เดอิดาระ, ลอว์, ลูฟี่ G4" })
local BleachAnimeTab = Window:Tab({ Title = "บลีช & โจโจ้ & อื่นๆ", Icon = "swords", Desc = "โคคุชิโบะ, มิคุ/โอสุ, สตาร์ค, คิระ, กิลกาเมช, ดราก้อนบอล" })
local AimTab         = Window:Tab({ Title = "ไซเลนท์ & เอมล็อค", Icon = "crosshair", Desc = "Silent Aim สกิลล็อคเป้าเงียบ 100+ ตัว & M2 AimLock" })
local ResetTab       = Window:Tab({ Title = "เกิดใหม่ (Reset J)", Icon = "rotate-ccw", Desc = "ปุ่มเกิดใหม่ทันที & ซ่อนหน้าต่างตอนตาย" })

pcall(function() Window:SelectTab(1) end)

-- =====================================================================
-- [1. ทั่วไป (UNIVERSAL)]
-- =====================================================================
UniversalTab:Paragraph({
    Title = "ระบบส่วนกลาง (Universal Combat Suite)",
    Desc = "ระบบช่วยเหลือการต่อสู้พื้นฐานที่ใช้งานได้กับทุกตัวละครในเกม ABA: ไทมิ่งมินิเกม, ปลดปล่อยร่างตื่นพลังฉุกเฉิน และมาโครคอมโบ 4 ฮิต",
})
local tTiming = UniversalTab:Toggle({
    Title = "Auto-Timing (กดจังหวะมินิเกมอัตโนมัติ)",
    Desc = "ตอบสนองจังหวะกดเป๊ะทุกมินิเกมอัตโนมัติ เช่น Black Flash, ปราณจันทรา, โอสุ (กดปุ่ม H เพื่อเปิด/ปิดด่วน)",
    Icon = "timer",
    Value = getgenv().EsaAutoTiming,
    Callback = function(s) getgenv().EsaAutoTiming = s; saveConfig() end,
})
local tAwaken = UniversalTab:Toggle({
    Title = "Emergency Auto-Awaken (ตื่นพลังฉุกเฉิน G)",
    Desc = "กดปุ่ม G เพื่อตื่นพลัง (Awakening) ให้อัตโนมัติทันทีเมื่อเลือดต่ำกว่าเกณฑ์ ป้องกันการตายฟรี",
    Icon = "zap",
    Value = getgenv().EsaAutoAwaken,
    Callback = function(s) getgenv().EsaAutoAwaken = s; saveConfig() end,
})
UniversalTab:Slider({
    Title = "เกณฑ์เลือดตื่นพลัง (HP Threshold)",
    Desc = "กำหนดเปอร์เซ็นต์เลือดที่ต้องการให้ระบบกด G ตื่นพลังอัตโนมัติ",
    Value = { Min = 10, Max = 50, Default = getgenv().EsaAutoAwakenHp or 25 },
    Step = 5,
    Callback = function(v) getgenv().EsaAutoAwakenHp = v; saveConfig() end,
})
UniversalTab:Paragraph({
    Title = "ระบบต่อย M1 ควบคุมด้วยตนเอง (Manual Pure Attack)",
    Desc = "ถอดระบบจำลองการกดคลิกออกทั้งหมด ผู้เล่นสามารถคลิกซ้ายหรือคลิกค้างเพื่อต่อคอมโบได้อิสระ 100% ลื่นไหล ไม่หลุด",
})
UniversalTab:Button({
    Title = "ตรวจสอบตัวละครและสกิลปัจจุบัน",
    Desc = "แสดงชื่อตัวละครที่กำลังเล่นและรายชื่อสกิลทั้งหมดที่พร้อมใช้งานบนหน้าจอ",
    Icon = "info",
    Callback = function()
        local p = game.Players.LocalPlayer
        local ch = p.Character
        local cn = ch and ch:GetAttribute("SpawnChar") or "?"
        local mv = {}
        local moves = p.PlayerGui:FindFirstChild("HUD") and p.PlayerGui.HUD:FindFirstChild("Moves")
        if moves then
            for _, b in ipairs(moves:GetChildren()) do
                if b:IsA("ImageButton") then
                    local ok, mn = pcall(function() return b:GetAttribute("MoveName") end)
                    if ok and mn then table.insert(mv, b.Name .. ":" .. tostring(mn)) end
                end
            end
        end
        WindUI:Notify({ Title = "ตัวละคร: " .. tostring(cn), Content = table.concat(mv, " | "), Duration = 5, Icon = "user" })
    end,
})

-- =====================================================================
-- [2. เทรด & ป้องกัน (DEFENSE & COUNTERS)]
-- =====================================================================
DefenseTab:Paragraph({
    Title = "ระบบป้องกันขั้นสูง (Defense & Counter Assists)",
    Desc = "ป้องกันการสะกดจิต, ป้องกันจอพลิก, สลับร่างหนีสตัน และระบบกดสกิลเคาน์เตอร์อัตโนมัติ",
})
local tAntiGenjutsu = DefenseTab:Toggle({
    Title = "Anti-Genjutsu (ป้องกันการสะกดจิต / สึกุโยมิ)",
    Desc = "ฮุคระบบ IsLookingAt ส่งค่าหลบสายตา 100% ทำให้ไม่ติดสถานะสะกดจิต เช่น สึกุโยมิของอิทาจิ หรือการจ้องตาของไอเซ็น",
    Icon = "eye-off",
    Value = getgenv().EsaAntiGenjutsu,
    Callback = function(s) getgenv().EsaAntiGenjutsu = s; saveConfig() end,
})
local tAntiScreenFlip = DefenseTab:Toggle({
    Title = "Anti-ScreenFlip (ป้องกันจอพลิก / ควบคุมกลับด้าน)",
    Desc = "หักล้างเอฟเฟกต์ชิไคของชินจิ ฮิราโกะ จอจะไม่กลับหัวและปุ่มบังคับจะไม่สลับทิศทาง",
    Icon = "refresh-ccw",
    Value = getgenv().EsaAntiScreenFlip,
    Callback = function(s) getgenv().EsaAntiScreenFlip = s; saveConfig() end,
})
local tUraharaGigai = DefenseTab:Toggle({
    Title = "อุราฮาระ (Urahara Portable Gigai Breaker)",
    Desc = "กดใช้หุ่นฟางสลับร่างฉุกเฉินอัตโนมัติทันทีที่ตัวเราติดสถานะสตัน เพื่อหลุดออกจากคอมโบของศัตรู",
    Icon = "shield-alert",
    Value = getgenv().EsaUraharaGigai,
    Callback = function(s) getgenv().EsaUraharaGigai = s; saveConfig() end,
})

local CounterSec = DefenseTab:Section({ Title = "ระบบสกิลสวนกลับอัตโนมัติ (Auto-Counters)", Opened = true })
local tAutoCounter = CounterSec:Toggle({
    Title = "Master Auto-Counter (ระบบสกิลสวนกลับอัตโนมัติ)",
    Desc = "ตรวจจับการโจมตีระยะประชิดของศัตรู แล้วกดสกิลเคาน์เตอร์ของตัวละครทันทีในเฟรมแรก",
    Icon = "zap",
    Value = getgenv().EsaAutoCounter,
    Callback = function(s) getgenv().EsaAutoCounter = s; saveConfig() end,
})
CounterSec:Slider({
    Title = "ระยะตรวจจับเคาน์เตอร์ (studs)",
    Desc = "กำหนดระยะห่างของศัตรูที่จะทำให้ระบบกดสกิลสวนกลับทำงาน",
    Value = { Min = 8, Max = 25, Default = getgenv().EsaCounterRange or 16 },
    Step = 1,
    Callback = function(v) getgenv().EsaCounterRange = v; saveConfig() end,
})
local tEpitaph = CounterSec:Toggle({
    Title = "เดียโวโล่ (Diavolo Epitaph Priority)",
    Desc = "ให้ความสำคัญกับสกิลลบเวลา Epitaph ของเดียโวโล่เป็นอันดับแรกเมื่อศัตรูพุ่งเข้ามา",
    Icon = "skull",
    Value = getgenv().EsaCounterEpitaph,
    Callback = function(s) getgenv().EsaCounterEpitaph = s; saveConfig() end,
})
local tAizen = CounterSec:Toggle({
    Title = "ไอเซ็น (Aizen Kyoka Suigetsu)",
    Desc = "กดเคาน์เตอร์สะกดจิตของไอเซ็นอัตโนมัติเมื่อศัตรูใช้ท่าทำลายบล็อก",
    Icon = "eye",
    Value = getgenv().EsaCounterAizen,
    Callback = function(s) getgenv().EsaCounterAizen = s; saveConfig() end,
})

-- =====================================================================
-- [3. คอมแบท (MOBILITY & COMBAT)]
-- =====================================================================
MobilityTab:Paragraph({
    Title = "ระบบระยะประชิด (Combat Suite)",
    Desc = "ระบบช่วยชก M1",
})
local M1Sec = MobilityTab:Section({ Title = "ระบบควบคุมหมัด M1 (Manual Hold)", Opened = true })
M1Sec:Paragraph({
    Title = "อิสระการต่อสู้ 100% (Hold M1 Enabled)",
    Desc = "ถอดระบบ Auto M1 ออกทั้งหมด เพื่อให้สามารถคลิกซ้ายค้างเพื่อต่อคอมโบได้ลื่นไหล ไม่หลุด ไม่ถูกขัดจังหวะ และไม่มีการตีเองโดยไม่ตั้งใจ",
})

-- =====================================================================
-- [4. มหาเวทย์ (JUJUTSU KAISEN)]
-- =====================================================================
JjkTab:Paragraph({
    Title = "Jujutsu Kaisen Suite (มหาเวทย์ผนึกมาร)",
    Desc = "ระบบคำนวณและควบคุมวิถีไสยเวทเฉพาะตัว: โกโจ ซาโตรุ, สุคุนะ/ยูจิ, โทโด อาโออิ, นานามิ เคนโตะ",
})

-- โกโจ ซาโตรุ
local GojoSec = JjkTab:Section({ Title = "โกโจ ซาโตรุ (Satoru Gojo - มุราซากิ & อาโอะ)", Opened = true })
local tGrabSteer = GojoSec:Toggle({
    Title = "Auto Blue Steer (ลูกบอล Blue เลี้ยวตามเป้า)",
    Desc = "ควบคุมวิถีของลูกบอล Blue / Red ให้เลี้ยวโค้งไล่ล่าศัตรูอัตโนมัติแบบไร้ขีดจำกัดระยะทาง",
    Icon = "locate-fixed",
    Value = getgenv().EsaBlueAuto,
    Callback = function(s) getgenv().EsaBlueAuto = s; saveConfig() end,
})
local tDetonate = GojoSec:Toggle({
    Title = "Auto-Detonate (สั่งระเบิดทันทีเมื่อชนตัว)",
    Desc = "สั่งระเบิดพลังทันทีในเสี้ยววินาทีที่ลูกบอลสัมผัสตัวศัตรู การันตีการทำลายบล็อกและการติดดาเมจเต็ม",
    Icon = "bomb",
    Value = getgenv().EsaBlueAutoDetonate,
    Callback = function(s) getgenv().EsaBlueAutoDetonate = s; saveConfig() end,
})
local tTag = GojoSec:Toggle({
    Title = "Victim Tag & Tracer (ไฮไลท์เป้าหมายของลูกบอล)",
    Desc = "ตีกรอบสีแดงและแสดงชื่อของศัตรูที่ลูกบอลกำลังพุ่งเข้าใส่",
    Icon = "crosshair",
    Value = getgenv().EsaBlueTracer,
    Callback = function(s) getgenv().EsaBlueTracer = s; saveConfig() end,
})
local tRing = GojoSec:Toggle({
    Title = "Mouse Aim Ring (วงเล็งรอบเมาส์)",
    Desc = "แสดงวงกลมช่วยเล็งที่เมาส์ เปลี่ยนเป็นสีแดงเมื่อล็อคเป้าหมายสำเร็จ",
    Icon = "circle-dot",
    Value = getgenv().EsaBlueFov,
    Callback = function(s) getgenv().EsaBlueFov = s; saveConfig() end,
})
GojoSec:Slider({
    Title = "ขนาดวงเล็งเมาส์ (px)",
    Desc = "ปรับขนาดรัศมีในการค้นหาเป้าหมายรอบเมาส์",
    Value = { Min = 60, Max = 1000, Default = getgenv().EsaBlueFovSize or 140 },
    Step = 10,
    Callback = function(v) getgenv().EsaBlueFovSize = v; saveConfig() end,
})
local tPreview = GojoSec:Toggle({
    Title = "Aim Preview (พรีวิวเป้าหมายล่วงหน้า)",
    Desc = "แสดงเป้าหมายที่จะถูกล็อคตลอดเวลาแม้ยังไม่ได้กดปล่อยสกิล",
    Icon = "eye",
    Value = getgenv().EsaAimPreview,
    Callback = function(s) getgenv().EsaAimPreview = s; saveConfig() end,
})
local tCluster = GojoSec:Toggle({
    Title = "Points Cluster (รวบกลุ่มที่ยืนใกล้กัน)",
    Desc = "โหมดฟาร์มแต้ม: เลี้ยวบอลไปหากลุ่มคนที่ยืนใกล้กันหนาแน่นสุดทั้งแมพ ไม่ต้องอยู่ในวงเล็ง",
    Icon = "users",
    Value = getgenv().EsaBlueCluster,
    Callback = function(s) getgenv().EsaBlueCluster = s; saveConfig() end,
})
GojoSec:Slider({
    Title = "รัศมีนับกลุ่ม (studs)",
    Desc = "ศัตรูที่ห่างกันไม่เกินระยะนี้ถือว่าเป็นกลุ่มเดียวกัน",
    Value = { Min = 10, Max = 60, Default = getgenv().EsaBlueClusterRadius or 22 },
    Step = 2,
    Callback = function(v) getgenv().EsaBlueClusterRadius = v; saveConfig() end,
})

-- สุคุนะ & ยูจิ
local SukunaSec = JjkTab:Section({ Title = "สุคุนะ & ยูจิ (Sukuna & Yuji - ประกายทมิฬ)", Opened = false })
local tSukunaBF = SukunaSec:Toggle({
    Title = "100% Black Flash (ประกายทมิฬสมบูรณ์แบบ)",
    Desc = "ฮุคระบบ BlackFlashCheck ตอบกลับค่าเวลาเป๊ะระดับเฟรม ไม่พลาดการกดประกายทมิฬแม้แต่ครั้งเดียว",
    Icon = "sparkles",
    Value = getgenv().EsaAutoTiming,
    Callback = function(s) getgenv().EsaAutoTiming = s; saveConfig() end,
})

-- โทโด อาโออิ
local TodoSec = JjkTab:Section({ Title = "โทโด อาโออิ (Aoi Todo - บูกี้ วูกี้)", Opened = false })
local tTodoSwap = TodoSec:Toggle({
    Title = "Auto Boogie Woogie Swap (สลับตำแหน่งสวนกลับ)",
    Desc = "ปรบมือสลับตำแหน่งตัวเองกับศัตรูอัตโนมัติทันทีที่ศัตรูปล่อยสกิลอันตรายหรือพุ่งเข้ามา",
    Icon = "refresh-cw",
    Value = getgenv().EsaTodoSwap,
    Callback = function(s) getgenv().EsaTodoSwap = s; saveConfig() end,
})

-- นานามิ เคนโตะ
local NanamiSec = JjkTab:Section({ Title = "นานามิ เคนโตะ (Kento Nanami - อัตราส่วน 7:3)", Opened = false })
local tNanami = NanamiSec:Toggle({
    Title = "7:3 Ratio Critical Strike (ผ่าเส้นตายคริติคอล 100%)",
    Desc = "ฮุคระบบ NanamiCheck บังคับให้การโจมตีโดนจุดอ่อนอัตราส่วน 7:3 ติดคริติคอลรุนแรง 100% ทุกครั้ง",
    Icon = "timer",
    Value = getgenv().EsaNanamiAuto,
    Callback = function(s) getgenv().EsaNanamiAuto = s; saveConfig() end,
})

-- =====================================================================
-- [5. นินจา & วันพีซ (NARUTO & ONE PIECE)]
-- =====================================================================
NarutoOpTab:Paragraph({
    Title = "Shinobi & Pirate Suite (นินจาคาถา & โจรสลัด)",
    Desc = "ระบบควบคุมวิถีมีดคุไน สัตว์ดินเหนียวระเบิด และผลปีศาจ: มินาโตะ, เดอิดาระ, ลอว์, ลูฟี่ เกียร์ 4",
})

-- มินาโตะ
local MinatoSec = NarutoOpTab:Section({ Title = "มินาโตะ นามิคาเสะ (Minato - ประกายแสงสีทอง)", Opened = true })
local tMinatoKunai = MinatoSec:Toggle({
    Title = "Kunai Homing Tracking (มีดบินคุไนเลี้ยวตามเป้า)",
    Desc = "ปรับวิถีของคุไนเทพอัสนีให้โค้งเลี้ยวพุ่งเข้าใส่ศัตรูที่ใกล้ที่สุดอย่างแม่นยำ เพื่อเปิดทางเทเลพอร์ตแทงหลัง",
    Icon = "wind",
    Value = getgenv().EsaMinatoKunai,
    Callback = function(s) getgenv().EsaMinatoKunai = s; saveConfig() end,
})

-- เดอิดาระ
local DeidaraSec = NarutoOpTab:Section({ Title = "เดอิดาระ (Deidara - ดินเหนียวระเบิด)", Opened = false })
local tDeidaraAuto = DeidaraSec:Toggle({
    Title = "Clay Creatures Auto-Steer (สัตว์ดินเหนียวเลี้ยวตามศัตรู)",
    Desc = "บังคับให้นกดินเหนียวและแมงมุม C1 พุ่งเลี้ยวเกาะติดศัตรู แม้ศัตรูจะกดแดชหลบก็ตาม",
    Icon = "wind",
    Value = getgenv().EsaDeidaraAuto,
    Callback = function(s) getgenv().EsaDeidaraAuto = s; saveConfig() end,
})
local tDeidaraDet = DeidaraSec:Toggle({
    Title = "Auto Contact Detonate (ระเบิดทันทีเมื่อถึงตัว)",
    Desc = "สั่งระเบิดดินเหนียวอัตโนมัติทันทีที่ชนโดนฮิตบ็อกซ์ของศัตรู ไม่เสียจังหวะดีเลย์",
    Icon = "bomb",
    Value = getgenv().EsaDeidaraDetonate,
    Callback = function(s) getgenv().EsaDeidaraDetonate = s; saveConfig() end,
})
DeidaraSec:Slider({
    Title = "ความเร็วในการพุ่งของดินเหนียว",
    Desc = "ปรับอัตราเร่งความเร็วของนกและแมงมุมดินเหนียว",
    Value = { Min = 50, Max = 250, Default = getgenv().EsaDeidaraSpeed or 95 },
    Step = 5,
    Callback = function(v) getgenv().EsaDeidaraSpeed = v; saveConfig() end,
})

-- ทราฟัลการ์ ลอว์
local LawSec = NarutoOpTab:Section({ Title = "ทราฟัลการ์ ลอว์ (Trafalgar Law - ผลโอเปะ โอเปะ)", Opened = false })
local tLawPull = LawSec:Toggle({
    Title = "Shambles Auto-Pull (สลับดึงศัตรูเข้ามาระยะต่อย)",
    Desc = "ใช้พลัง Shambles สลับดึงศัตรูเข้ามาในระยะประชิดทันทีภายใน Room เพื่อเริ่มคอมโบแบบกันไม่ได้",
    Icon = "locate",
    Value = getgenv().EsaLawShambles,
    Callback = function(s) getgenv().EsaLawShambles = s; saveConfig() end,
})

-- มังกี้ ดี ลูฟี่
local LuffySec = NarutoOpTab:Section({ Title = "มังกี้ ดี ลูฟี่ (Monkey D. Luffy - เกียร์ 4 สเนคแมน)", Opened = false })
local tCulverin = LuffySec:Toggle({
    Title = "Culverin 360° Curve Lock (หมัดงูเลี้ยวโค้ง 360 องศา)",
    Desc = "หักเหวิถีหมัด Culverin ของเกียร์ 4 ให้เลี้ยวโค้งอ้อมสิ่งกีดขวางพุ่งชนเป้าหมาย 100%",
    Icon = "flame",
    Value = getgenv().EsaLuffyCulverin,
    Callback = function(s) getgenv().EsaLuffyCulverin = s; saveConfig() end,
})

-- กาอาระ
local GaaraSec = NarutoOpTab:Section({ Title = "กาอาระ (Gaara - คลื่นทรายกลืนกิน Sand Tsunami)", Opened = true })
local tGaara = GaaraSec:Toggle({
    Title = "Auto Sand Geyser Steer (คลื่นทรายเลี้ยวตามเมาส์ 100%)",
    Desc = "ปลดล็อคมุมมองกล้องไม่ให้ติดไปกับทราย และบังคับให้คลื่นทรายเลี้ยวพุ่งเข้าหาศัตรูที่ใกล้เคอร์เซอร์เมาส์ที่สุด (หากหันกล้องไปทางอื่นหรือไม่มีศัตรู จะพุ่งตรงไปตามทิศทางที่เมาส์ชี้อย่างเป็นธรรมชาติ ไม่ล็อคคนข้างหลัง)",
    Icon = "wind",
    Value = getgenv().EsaGaaraSteer,
    Callback = function(s) getgenv().EsaGaaraSteer = s; saveConfig() end,
})
GaaraSec:Slider({
    Title = "ความเร็วคลื่นทราย (Sand Speed)",
    Desc = "ปรับความเร็วในการพุ่งของคลื่นทรายกาอาระ (ปกติของเกม 75)",
    Value = { Min = 75, Max = 160, Default = getgenv().EsaGaaraSpeed or 110 },
    Step = 5,
    Callback = function(v) getgenv().EsaGaaraSpeed = v; saveConfig() end,
})

-- =====================================================================
-- [6. บลีช & โจโจ้ & อื่นๆ (BLEACH, JOJO & LEGENDS)]
-- =====================================================================
BleachAnimeTab:Paragraph({
    Title = "Bleach, JoJo & Other Legends",
    Desc = "ระบบซัพพอร์ตจังหวะดาบ ดนตรี ฝูงวิญญาณระเบิด และการยิงบีมพลังงาน: โคคุชิโบะ, มิคุ/โอสุ, สตาร์ค, คิระ, กิลกาเมช, ดราก้อนบอล",
})

-- โคคุชิโบะ
local KokushiboSec = BleachAnimeTab:Section({ Title = "โคคุชิโบะ (Kokushibo - ปราณจันทรา)", Opened = true })
local tKokushibo = KokushiboSec:Toggle({
    Title = "100% Moon Breathing Rhythm (ปราณจันทราไร้ข้อผิดพลาด)",
    Desc = "ฮุค KokushiboCheck ส่งค่าความแม่นยำของจังหวะดาบปราณจันทรา 100% ออกคอมโบดาบได้เต็มสูบ",
    Icon = "swords",
    Value = getgenv().EsaKokushibo,
    Callback = function(s) getgenv().EsaKokushibo = s; saveConfig() end,
})

-- มิคุ & โอสุ
local RhythmSec = BleachAnimeTab:Section({ Title = "ฮัตสึเนะ มิคุ & โอสุ (Miku & Osu - มินิเกมกดจังหวะ)", Opened = false })
local tMikuOsu = RhythmSec:Toggle({
    Title = "100% Auto-Hit Rhythm Minigame (กดจังหวะเพลงเป๊ะทุกโน้ต)",
    Desc = "ฮุค MikuCheck และ OsuCheck ให้กดโดนโน้ตระดับ Perfect ทุกครั้งโดยไม่ต้องกดเอง",
    Icon = "music",
    Value = getgenv().EsaRhythmAuto,
    Callback = function(s) getgenv().EsaRhythmAuto = s; saveConfig() end,
})

-- โคโยเต้ สตาร์ค
local StarrkSec = BleachAnimeTab:Section({ Title = "โคโยเต้ สตาร์ค (Coyote Starrk - ลอส โลโบส)", Opened = false })
local tStarrkWolves = StarrkSec:Toggle({
    Title = "Los Lobos Spirit Wolves Homing (ฝูงหมาป่าวิญญาณไล่ล่า)",
    Desc = "บังคับให้ฝูงหมาป่าวิญญาณเลี้ยวไล่ล่าเป้าหมายอัตโนมัติและระเบิดทันทีเมื่อเข้าใกล้",
    Icon = "dog",
    Value = getgenv().EsaStarrkWolves,
    Callback = function(s) getgenv().EsaStarrkWolves = s; saveConfig() end,
})
StarrkSec:Slider({
    Title = "ความเร็วหมาป่าวิญญาณ",
    Desc = "ปรับความเร็วในการวิ่งไล่ของฝูงหมาป่า",
    Value = { Min = 80, Max = 250, Default = getgenv().EsaStarrkSpeed or 110 },
    Step = 5,
    Callback = function(v) getgenv().EsaStarrkSpeed = v; saveConfig() end,
})

-- คิระ โยชิคาเงะ
local KiraSec = BleachAnimeTab:Section({ Title = "คิระ โยชิคาเงะ (Kira Yoshikage - คิลเลอร์ ควีน)", Opened = false })
local tKiraSHA = KiraSec:Toggle({
    Title = "SHA Supersonic Tracking (เชียร์ฮาร์ทแอทแทคความเร็วเหนือเสียง)",
    Desc = "บูสต์ความเร็วของ Sheer Heart Attack ให้พุ่งเข้าใส่ศัตรูด้วยความเร็วสูงและระเบิดทันที",
    Icon = "skull",
    Value = getgenv().EsaKiraSHA,
    Callback = function(s) getgenv().EsaKiraSHA = s; saveConfig() end,
})
KiraSec:Slider({
    Title = "ความเร็ว Sheer Heart Attack",
    Desc = "ปรับความเร็วในการไล่ล่าของระเบิดอัตโนมัติ",
    Value = { Min = 80, Max = 300, Default = getgenv().EsaSHASpeed or 130 },
    Step = 10,
    Callback = function(v) getgenv().EsaSHASpeed = v; saveConfig() end,
})

-- กิลกาเมช
local GilgameshSec = BleachAnimeTab:Section({ Title = "กิลกาเมช (Gilgamesh - ราชาวีรชน)", Opened = false })
GilgameshSec:Paragraph({
    Title = "Gate of Babylon (ระบบล็อคเป้าแท้ของตัวเกม)",
    Desc = "ดาบและหอกของ Gilgamesh ในตัวเกม ABA มีระบบ Auto-Lock / Homing เข้าหาศัตรูจากตัวเกมโดยตรงอยู่แล้ว",
})

-- ไรเดน
local RaidenSec = BleachAnimeTab:Section({ Title = "ไรเดน (Raiden - เบลดโหมด Blade Mode & ซันดัตสึ)", Opened = true })
local tRaiden = RaidenSec:Toggle({
    Title = "Blade Mode Auto-Zandatsu (ฟันซันดัตสึล็อคเป้าตามเมาส์)",
    Desc = "เมื่อเข้าสู่ Blade Mode วิถีการฟันจะหันตัดตรงกลางลำตัวของศัตรูที่ใกล้เคอร์เซอร์เมาส์ที่สุดทันทีเมื่อคลิก M1 การันตีการฟันโดน 100%",
    Icon = "swords",
    Value = getgenv().EsaRaidenAuto,
    Callback = function(s) getgenv().EsaRaidenAuto = s; saveConfig() end,
})
local tRaidenInst = RaidenSec:Toggle({
    Title = "Instant Zandatsu Cut (ฟันตัดทันทีเมื่อเข้าโหมด)",
    Desc = "สั่งฟันผ่าศัตรูที่ใกล้เมาส์ทันทีที่เปิดใช้ Blade Mode โดยไม่ต้องรอกด M1",
    Icon = "zap",
    Value = getgenv().EsaRaidenInstant,
    Callback = function(s) getgenv().EsaRaidenInstant = s; saveConfig() end,
})

-- ดราก้อนบอล
local DragonBallSec = BleachAnimeTab:Section({ Title = "ดราก้อนบอล (Goku, Vegeta, Piccolo - ลำแสงพลัง)", Opened = false })
local tKiBlast = DragonBallSec:Toggle({
    Title = "Ki Blast & Beam Convergence (ล็อควิถีกระสุนพลังงาน)",
    Desc = "ล็อควิถีกระสุนพลังและลำแสงคลื่นเต่าให้พุ่งตรงเข้าหาเป้าหมายศัตรู 100%",
    Icon = "flame",
    Value = getgenv().EsaKiBlastAim,
    Callback = function(s) getgenv().EsaKiBlastAim = s; saveConfig() end,
})

-- =====================================================================
-- [7. ไซเลนท์ & เอมล็อค (UNIVERSAL SILENT AIM & AIMLOCK)]
-- =====================================================================
AimTab:Paragraph({
    Title = "Universal Silent Aim & AimLock Suite",
    Desc = "ระบบหักเหวิถีสกิลอัตโนมัติ (Silent Aim) ล็อคเป้าเข้าศัตรู 100% โดยไม่ต้องหันกล้องหรือเล็งเมาส์ รองรับทุกตัวละครในเกม ABA ที่มีสกิลยิงหรือสกิลเล็งเป้า",
})

local SilentSec = AimTab:Section({ Title = "Universal Silent Aim (สกิลล็อคเป้าเงียบ)", Opened = true })
local tSilent = SilentSec:Toggle({
    Title = "Silent Aim Master (เปิดใช้งาน Silent Aim)",
    Desc = "หักเหวิถีสกิลยิง, บีมพลัง, กระสุน, หมัดพุ่ง, และสกิลเล็งเป้าทั้งหมดเข้าหาศัตรูอัตโนมัติ 100% โดยที่มุมกล้องไม่ขยับ",
    Icon = "target",
    Value = getgenv().EsaSilentAimEnabled,
    Callback = function(s) getgenv().EsaSilentAimEnabled = s; saveConfig() end,
})
SilentSec:Paragraph({
    Title = "ระบบเลือกเป้าหมาย (Pure Cursor Screen Distance)",
    Desc = "คำนวณเป้าหมายจากศัตรูที่อยู่ใกล้เคอร์เซอร์เมาส์บนหน้าจอ 100% และต้องอยู่ในมุมมองกล้องด้านหน้าเท่านั้น (Z > 0) ป้องกันการหันกล้องไปทางอื่นแล้วสกิลล็อคศัตรูด้านหลังโดยไม่ตั้งใจ",
})
local tSilentLimitFOV = SilentSec:Toggle({
    Title = "จำกัดเฉพาะในวง FOV (Strict FOV Only)",
    Desc = "หากเปิด: จะล็อคเฉพาะศัตรูที่อยู่ในวงกลม FOV เท่านั้น / หากปิด: จะเล็งคนที่ใกล้เมาส์ที่สุดทั่วทั้งหน้าจอ",
    Icon = "shield-alert",
    Value = getgenv().EsaSilentLimitToFOV,
    Callback = function(s) getgenv().EsaSilentLimitToFOV = s; saveConfig() end,
})
SilentSec:Dropdown({
    Title = "ตำแหน่งที่ต้องการล็อค (Hitbox Priority)",
    Desc = "เลือกชิ้นส่วนร่างกายของศัตรูที่ต้องการให้สกิลพุ่งเข้าใส่",
    Values = { "HumanoidRootPart (กลางลำตัว)", "Torso (หน้าอก)", "Head (ศีรษะ)" },
    Value = getgenv().EsaSilentHitbox or "HumanoidRootPart (กลางลำตัว)",
    Callback = function(v)
        if string.find(v, "Head") then
            getgenv().EsaSilentHitbox = "Head"
        elseif string.find(v, "Torso") then
            getgenv().EsaSilentHitbox = "Torso"
        else
            getgenv().EsaSilentHitbox = "HumanoidRootPart"
        end
        saveConfig()
    end,
})
SilentSec:Slider({
    Title = "การคำนวณดักหน้าล่วงหน้า (Lead Prediction)",
    Desc = "คำนวณเวกเตอร์ความเร็วของศัตรู ยิ่งศัตรูเคลื่อนที่เร็ว สกิลจะยิงดักหน้าให้อัตโนมัติ",
    Value = { Min = 0, Max = 0.4, Default = getgenv().EsaSilentPredict or 0.12 },
    Step = 0.01,
    Callback = function(v) getgenv().EsaSilentPredict = v; saveConfig() end,
})
local tSilentShowFOV = SilentSec:Toggle({
    Title = "แสดงวงกลม Silent FOV (FOV Circle)",
    Desc = "วาดวงกลมสีฟ้าใสรอบเคอร์เซอร์เมาส์ แสดงขอบเขตที่ Silent Aim จะค้นหาศัตรู",
    Icon = "circle",
    Value = getgenv().EsaSilentShowFOV,
    Callback = function(s) getgenv().EsaSilentShowFOV = s; saveConfig() end,
})
SilentSec:Slider({
    Title = "ขนาดรัศมี Silent FOV (pixels)",
    Desc = "ปรับขนาดรัศมีพื้นที่ตรวจจับรอบเคอร์เซอร์เมาส์",
    Value = { Min = 60, Max = 600, Default = getgenv().EsaSilentFOV or 220 },
    Step = 10,
    Callback = function(v) getgenv().EsaSilentFOV = v; saveConfig() end,
})
SilentSec:Slider({
    Title = "ระยะตรวจจับสูงสุด (Max Distance studs)",
    Desc = "จำกัดระยะห่างสูงสุดระหว่างตัวเรากับศัตรูที่จะให้ Silent Aim ทำงาน",
    Value = { Min = 100, Max = 1500, Default = getgenv().EsaSilentMaxDist or 600 },
    Step = 50,
    Callback = function(v) getgenv().EsaSilentMaxDist = v; saveConfig() end,
})
local tSilentNotify = SilentSec:Toggle({
    Title = "แจ้งเตือนเมื่อสกิลล็อคเป้าสำเร็จ (Hit Cue)",
    Desc = "แสดงป้ายแจ้งเตือนชื่อสกิลและชื่อศัตรูที่ถูก Silent Aim ล็อคเป้า",
    Icon = "bell",
    Value = getgenv().EsaSilentNotify,
    Callback = function(s) getgenv().EsaSilentNotify = s; saveConfig() end,
})

local SilentCharsSec = AimTab:Section({ Title = "รายชื่อตัวละคร & สกิลเด่นที่รองรับ Silent Aim", Opened = false })
SilentCharsSec:Paragraph({
    Title = "มหาเวทย์ (Jujutsu Kaisen)",
    Desc = "• โกโจ (Gojo): ไสยเวทหมุนตาม อาโอะ (Blue), อากะ (Red), มุราซากิ (Hollow Purple)\n• สุคุนะ (Sukuna): เฉือน (Cleave), ฟันผ่า (Dismantle), ศรเพลิง (Fire Arrow)\n• ยูจิ (Yuji): หมัดประกายทมิฬ (Divergent Fist)\n• เมกุมิ (Megumi): นกสายฟ้า (Nue Lightning), หมาป่าศักดิ์สิทธิ์",
})
SilentCharsSec:Paragraph({
    Title = "ดราก้อนบอล (Dragon Ball Z)",
    Desc = "• พิคโกโล่ (Piccolo): ลำแสงมารพิฆาต (Special Beam Cannon), คลื่นพลังมาร (Demon Wave), ระเบิดพลังนรก (Hellzone Grenade)\n• โกคู (Goku): พลังคลื่นเต่า (Kamehameha), บอลเกงกิ (Spirit Bomb)\n• เบจิต้า (Vegeta): ปืนใหญ่กาลิก (Galick Gun), บิ๊กแบงแอทแทค, ไฟนอลแฟลช\n• ทรังคซ์ (Trunks): เบิร์นนิ่งแอทแทค (Burning Attack)\n• เบจิตโต้ (Vegito): ดาบจิตวิญญาณ (Spirit Sword), ไฟนอลคาเมฮาเมฮา",
})
SilentCharsSec:Paragraph({
    Title = "นินจาคาถา (Naruto Shippuden)",
    Desc = "• มินาโตะ (Minato): มีดบินเทพอัสนี (Raijin Kunai), เทพอัสนีแทงหลัง\n• ซาสึเกะ (Sasuke): พันปักษา (Chidori), ลูกไฟยักษ์, เทวีสุริยา (Amaterasu), คิริน (Kirin)\n• อิทาจิ (Itachi): คาถาไฟลูกไฟยักษ์, เพลิงดำเทวีสุริยา\n• คาคาชิ (Kakashi): คัตคิริ (Raikiri), มังกรน้ำ\n• นารูโตะ (Naruto): กระสุนวงจักรดาวกระจาย (Rasenshuriken)\n• กาอาระ (Gaara): คลื่นทรายกลืนกิน (Sand Tsunami)\n• เพน (Pain): ข่ายเทพพิชิตฟ้า (Shinra Tensei), ดาราสวรรค์พิฆาต (Chibaku Tensei)",
})
SilentCharsSec:Paragraph({
    Title = "วันพีซ (One Piece)",
    Desc = "• ทราฟัลการ์ ลอว์ (Law): สลับร่าง (Shambles), มีดแกมมา (Gamma Knife), สั่งลอย (Tact)\n• ลูฟี่ เกียร์ 4 (Luffy G4): หมัดงูเลี้ยวโค้ง (Culverin Python), หมัดหมัดเพลิงแดง (Red Hawk)\n• เอส (Ace): หมัดอัคคี (Hiken), เสาเพลิงยักษ์ (Dai Enkai Entei)\n• โซโล (Zoro): เพลงดาบตัดคลื่นลม (Flying Dragon Blaze)\n• คิซารุ (Kizaru): ยาซาคานิ โนะ มางาทามะ (ลูกปรายแสง), ลูกเตะความเร็วแสง\n• เอเนลู (Enel): สายฟ้าราชันย์ (El Thor), บอลสายฟ้า (Raigo)",
})
SilentCharsSec:Paragraph({
    Title = "บลีช เทพมรณะ (Bleach)",
    Desc = "• อิจิโกะ (Ichigo): เก็ตสึกะ เทนโช (Getsuga Tenshou), มูเก็ตสึ (Mugetsu)\n• เบียคุยะ (Byakuya): เซ็มบงซากุระ คาเงโยชิ (Senbonzakura)\n• โคโยเต้ สตาร์ค (Starrk): เซโร่ เมตราเจตต้า (Cero Metralleta), ฝูงหมาป่าวิญญาณ\n• อุลคิโอร่า (Ulquiorra): เซโร่ ออสคิวรัส (Cero Oscuras), หอกอสุนีบาต (Lanza del Relampago)\n• ไอเซ็น (Aizen): ไรโคโฮ (Raikouhou), โลงศพดำ (Kurohitsugi)",
})
SilentCharsSec:Paragraph({
    Title = "ฮันเตอร์ & เฟท & โจโจ้ & อื่นๆ",
    Desc = "• ไรเดน (Raiden): เบลดโหมดตัดซันดัตสึ (Blade Mode Zandatsu) ล็อคจุดกึ่งกลางลำตัว\n• กิลกาเมช (Gilgamesh): ประตูคลังสมบัติ (Gate of Babylon), เอเนมา เอลิช\n• เซเบอร์ (Saber): ดาบศักดิ์สิทธิ์เอ็กซ์คาลิเบอร์ (Excalibur)\n• อาเชอร์ (Archer): คาลาดบอล์ก (Caladbolg), คลังศาสตราไร้สิ้นสุด\n• คิรัวร์ (Killua): สายฟ้าสวรรค์ (Thunderbolt), ก๊อดสปีด (Godspeed)\n• โจทาโร่ (Jotaro): สตาร์ฟิงเกอร์ (Star Finger ยืดนิ้วทะลวง)\n• ดีโอ (Dio): มีดบินหยุดเวลา, รถบดถนน (Road Roller)\n• ยูสุเกะ (Yusuke): กระสุนวิญญาณ (Spirit Gun)\n• บาคุโก & โทโดโรกิ (MHA): ระเบิดทำลายล้าง, เสาน้ำแข็ง & เปลวเพลิง",
})

local M2AimSec = AimTab:Section({ Title = "M2 Camera AimLock (ล็อคกล้องคลิกขวา)", Opened = false })
local tAim = M2AimSec:Toggle({
    Title = "M2 AimLock (คลิกขวาค้างเพื่อล็อคเป้า)",
    Desc = "กดคลิกขวาค้างเพื่อหันมุมกล้องติดตามศัตรูในวงเล็งตลอดเวลาแบบเรียลไทม์",
    Icon = "crosshair",
    Value = getgenv().EsaAimOn,
    Callback = function(s)
        getgenv().EsaAimOn = s; saveConfig()
        if not s then aimHolding = false end
    end,
})
local tTeam = M2AimSec:Toggle({
    Title = "Team Check (ไม่ล็อคเพื่อนร่วมทีม)",
    Desc = "ระบบจะไม่ล็อคเพื่อนร่วมทีมเดียวกัน เพื่อป้องกันการเล็งผิดพลาด",
    Icon = "shield-check",
    Value = getgenv().EsaTeamCheck,
    Callback = function(s) getgenv().EsaTeamCheck = s; saveConfig() end,
})
local tCircle = M2AimSec:Toggle({
    Title = "FOV Circle (แสดงวงกลมระยะเล็ง)",
    Desc = "แสดงวงกลมสีชมพูรอบเคอร์เซอร์เมาส์เพื่อบอกขอบเขตการล็อคเป้า",
    Icon = "circle",
    Value = getgenv().EsaAimCircle,
    Callback = function(s) getgenv().EsaAimCircle = s; saveConfig() end,
})
M2AimSec:Slider({
    Title = "รัศมีวงเล็ง (FOV Radius px)",
    Desc = "ปรับขนาดรัศมีในการล็อคเป้ารอบเคอร์เซอร์เมาส์",
    Value = { Min = 60, Max = 600, Default = getgenv().EsaAimRadius or 200 },
    Step = 10,
    Callback = function(v) getgenv().EsaAimRadius = v; saveConfig() end,
})
M2AimSec:Slider({
    Title = "การคำนวณวิถีล่วงหน้า (Prediction)",
    Desc = "คำนวณทิศทางการเคลื่อนที่ของศัตรูล่วงหน้า ยิ่งศัตรูวิ่งเร็วยิ่งต้องนำหน้า",
    Value = { Min = 0, Max = 0.5, Default = getgenv().EsaAimPredict or 0.15 },
    Step = 0.01,
    Callback = function(v) getgenv().EsaAimPredict = v; saveConfig() end,
})

-- =====================================================================
-- [9. เกิดใหม่ (RESET J)]
-- =====================================================================
ResetTab:Paragraph({
    Title = "Instant Respawn Suite (ระบบเกิดใหม่ทันที)",
    Desc = "ระบบเกิดใหม่ทันทีแบบ Infinite Yield ป้องกันการเสียเวลารอคูลดาวน์หน้าจอ",
})
ResetTab:Button({
    Title = "Reset ทันที (เกิดใหม่ทันที)",
    Desc = "รีเซ็ตตัวละครและวาปกลับจุดเดิมทันทีโดยไม่ต้องรอคูลดาวน์ (เหมือนกดปุ่ม J)",
    Icon = "rotate-ccw",
    Callback = function()
        task.spawn(function()
            local ok, r = pcall(resetNow)
            WindUI:Notify({
                Title = "Reset",
                Content = tostring(ok and r or ("ERROR " .. tostring(r))),
                Duration = 3,
                Icon = "info",
            })
        end)
    end,
})
local tResetHide = ResetTab:Toggle({
    Title = "ซ่อน UI ตอนตาย (Hide Death UI)",
    Desc = "ซ่อนข้อความตอนตายและเมนู Respawn เพื่อให้หน้าจอสะอาดตาและลื่นไหล",
    Icon = "eye-off",
    Value = getgenv().EsaResetHideUI,
    Callback = function(s) getgenv().EsaResetHideUI = s; saveConfig() end,
})

-- =====================================================================
-- [STATE SYNCHRONIZATION LOOP]
-- =====================================================================
local function syncToggle(tog, val)
    if tog and tog.Value ~= val then
        pcall(function() tog:Set(val) end)
    end
end

task.spawn(function()
    while REV == getgenv().EsaRev_main do
        task.wait(2.5)
        pcall(function()
            -- Universal
            syncToggle(tTiming, getgenv().EsaAutoTiming)
            syncToggle(tAwaken, getgenv().EsaAutoAwaken)
            -- Defense
            syncToggle(tAntiGenjutsu, getgenv().EsaAntiGenjutsu)
            syncToggle(tAntiScreenFlip, getgenv().EsaAntiScreenFlip)
            syncToggle(tUraharaGigai, getgenv().EsaUraharaGigai)
            syncToggle(tAutoCounter, getgenv().EsaAutoCounter)
            syncToggle(tEpitaph, getgenv().EsaCounterEpitaph)
            syncToggle(tAizen, getgenv().EsaCounterAizen)
            -- JJK
            syncToggle(tGrabSteer, getgenv().EsaBlueAuto)
            syncToggle(tDetonate, getgenv().EsaBlueAutoDetonate)
            syncToggle(tTag, getgenv().EsaBlueTracer)
            syncToggle(tRing, getgenv().EsaBlueFov)
            syncToggle(tPreview, getgenv().EsaAimPreview)
            syncToggle(tCluster, getgenv().EsaBlueCluster)
            syncToggle(tSukunaBF, getgenv().EsaAutoTiming)
            syncToggle(tTodoSwap, getgenv().EsaTodoSwap)
            syncToggle(tNanami, getgenv().EsaNanamiAuto)
            -- Naruto / OP
            syncToggle(tMinatoKunai, getgenv().EsaMinatoKunai)
            syncToggle(tDeidaraAuto, getgenv().EsaDeidaraAuto)
            syncToggle(tDeidaraDet, getgenv().EsaDeidaraDetonate)
            syncToggle(tLawPull, getgenv().EsaLawShambles)
            syncToggle(tCulverin, getgenv().EsaLuffyCulverin)
            -- Bleach / JoJo / Anime
            syncToggle(tKokushibo, getgenv().EsaKokushibo)
            syncToggle(tMikuOsu, getgenv().EsaRhythmAuto)
            syncToggle(tStarrkWolves, getgenv().EsaStarrkWolves)
            syncToggle(tKiraSHA, getgenv().EsaKiraSHA)
            syncToggle(tGate, getgenv().EsaGilgameshGate)
            syncToggle(tKiBlast, getgenv().EsaKiBlastAim)
            -- Universal Silent Aim
            syncToggle(tSilent, getgenv().EsaSilentAimEnabled)
            syncToggle(tSilentShowFOV, getgenv().EsaSilentShowFOV)
            syncToggle(tSilentNotify, getgenv().EsaSilentNotify)
            -- AimLock
            syncToggle(tAim, getgenv().EsaAimOn)
            syncToggle(tTeam, getgenv().EsaTeamCheck)
            syncToggle(tCircle, getgenv().EsaAimCircle)
            -- Reset
            syncToggle(tResetHide, getgenv().EsaResetHideUI)
        end)
    end
end)
end
pcall(buildEsaUI)

WindUI:Notify({
    Title = "ESA | ABA PRO",
    Content = "โหลดระบบครบทุกตัวละครสำเร็จแล้ว! กด RightShift เพื่อเปิด/ปิดเมนู",
    Duration = 5,
    Icon = "zap",
})

warn("[ESA-MAIN] ABA Pro Suite fully loaded. RightShift = menu.")



