-- ==============================================================================
-- ESA MAIN (MIC UP - PlaceId: 6884319169)
-- Single-file All-in-One Social Suite:
-- [PROMPT] Auto-interact all ProximityPrompts + Teleport to spots
-- [TOOLS] Give all fun/danger tools via event_tool
-- [GRAB] GrabRequest spam + Auto-Accept grab
-- [TTS] Text-to-speech spam + broadcast + pitch
-- [BOOTH] Booth takeover helpers
-- [VISUALS] Player ESP (Highlight + Name + Distance)
-- [UI] WindUI (RightShift/Insert/RightControl)
-- ==============================================================================

-- ============================ [1] REVISION & KILLSWITCH =============================
getgenv().EsaRev_micup = ((getgenv().EsaRev_micup or 0) + 1)
local REV = getgenv().EsaRev_micup

for _, k in ipairs({
    "EsaConn_MenuToggle", "EsaConn_grab", "EsaConn_prompt", "EsaConn_tts",
    "EsaConn_esp", "EsaConn_char", "EsaConn_dance",
}) do
    if getgenv()[k] then
        pcall(function() getgenv()[k]:Disconnect() end)
        getgenv()[k] = nil
    end
end
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("EsaMouseUnlock") end)
if getgenv().EsaMicESPFolder then
    pcall(function() getgenv().EsaMicESPFolder:Destroy() end)
    getgenv().EsaMicESPFolder = nil
end

-- ============================ [2] CONFIG & DEFAULTS =============================
local ESA_CONFIG_FILE = "EsaMicUp/config.json"
local ESA_DEFAULTS = {
    EsaMicAutoPrompt = false,
    EsaMicPromptRange = 25,
    EsaMicESP = true,
    EsaMicESPMaxDist = 1500,
    EsaMicGrabSpam = false,
    EsaMicAutoAccept = true,
    EsaMicTTSSpam = false,
    EsaMicTTSText = "ESA MIC UP on top",
    EsaMicTTSPitch = 1,
    EsaMicSpamDelay = 3,
    EsaMicTarget = nil,
}
local function saveConfig()
    pcall(function()
        if typeof(writefile) == "function" then
            local d = {}
            for k, _ in pairs(ESA_DEFAULTS) do d[k] = getgenv()[k] end
            if typeof(json) == "table" then
                writefile(ESA_CONFIG_FILE, json.encode(d))
            end
        end
    end)
end
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
            getgenv()[k] = (saved and saved[k] ~= nil) and saved[k] or dflt
        end
    end
end
loadConfig()

-- ============================ [3] SERVICES & VARIABLES =============================
local LP = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local RSStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local function remote(name)
    return RSStorage:FindFirstChild(name)
end
local function notify(title, content, dur)
    pcall(function()
        local w = getgenv().EsaWindUI
        if w and w.Notify then
            w:Notify({ Title = tostring(title), Content = tostring(content), Duration = dur or 3, Icon = "zap" })
        else
            warn("[ESA] " .. tostring(title) .. ": " .. tostring(content))
        end
    end)
end

local TOOL_NAMES = { "fun_cloud", "fun_fast", "fun_gravity", "danger_pistol", "danger_gun", "danger_wind_force", "danger_dryer", "danger_poop" }
local SPOTS = { "boat", "middle", "club", "jail", "obby", "school", "spawn", "booth", "race", "tower", "restaurant", "fountain", "runway", "soccer", "campfire" }

local function getSpotCFrame(name)
    local map = workspace:FindFirstChild("map")
    if not map then return nil end
    local f = map:FindFirstChild(name)
    if not f then return nil end
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("BasePart") then return d.CFrame + Vector3.new(0, 4, 0) end
    end
    return nil
end
local function teleportTo(name)
    local cf = getSpotCFrame(name)
    if cf and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        LP.Character.HumanoidRootPart.CFrame = cf
        notify("Teleport", name)
    else
        warn("[ESA] spot not found: " .. tostring(name))
    end
end
local function fireAllPrompts()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if REV ~= getgenv().EsaRev_micup then break end
        if d:IsA("ProximityPrompt") then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local pp = d.Parent and d.Parent:IsA("BasePart") and d.Parent or nil
            local dist = (pp and hrp) and (pp.Position - hrp.Position).Magnitude or 0
            if (not getgenv().EsaMicAutoPrompt) or (not pp) or dist <= (tonumber(getgenv().EsaMicPromptRange) or 25) then
                pcall(function()
                    if typeof(fireproximityprompt) == "function" then
                        fireproximityprompt(d)
                    else
                        d:InputHoldBegin()
                        task.wait(0.05)
                        d:InputHoldEnd()
                    end
                end)
                n = n + 1
            end
        end
    end
    return n
end
local function giveTool(toolName)
    local r = remote("event_tool")
    if not r then warn("[ESA] event_tool missing"); return end
    pcall(function() r:FireServer(toolName) end)
    pcall(function() r:FireServer({ Tool = toolName }) end)
    pcall(function() r:FireServer(LP, toolName) end)
end
local function giveAllTools()
    for _, t in ipairs(TOOL_NAMES) do giveTool(t) task.wait(0.15) end
    notify("Tools", "Requested all tools (check Backpack)")
end
local function sendTTS(text, broadcast)
    text = text or getgenv().EsaMicTTSText or "hello"
    pcall(function()
        local r1 = remote("event_text_to_speech_dialog")
        if r1 then r1:FireServer(text, tonumber(getgenv().EsaMicTTSPitch) or 1) end
    end)
    if broadcast then
        pcall(function()
            local r2 = remote("event_text_to_speech_dialog_broadcast")
            if r2 then r2:FireServer(text, tonumber(getgenv().EsaMicTTSPitch) or 1) end
        end)
    end
end
local function grabPlayer(plr)
    if not plr then return end
    pcall(function()
        local r = remote("GrabRequest")
        if r then r:FireServer(plr) end
    end)
    pcall(function()
        local r = remote("GrabRequest")
        if r then r:FireServer(plr.Name) end
    end)
    pcall(function()
        local r = remote("GrabRequest")
        if r then r:FireServer(plr.Character) end
    end)
end

-- Dance (local R15 emote animations, no server needed)
local DANCES = {
    { Name = "Dance 1", Id = 507771104 },
    { Name = "Dance 2", Id = 507777268 },
    { Name = "Dance 3", Id = 507772104 },
    { Name = "Wave", Id = 507759655 },
    { Name = "Cheer", Id = 507770453 },
    { Name = "Laugh", Id = 507770239 },
    { Name = "Custom 76636", Id = 76636280785091 },
}
local danceTrack = nil
local function stopDance()
    if danceTrack then pcall(function() danceTrack:Stop() end) danceTrack = nil end
end
local function playDance(id)
    stopDance()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then warn("[ESA] no Animator"); return end
    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. tostring(id)
    local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
    pcall(function() a:Destroy() end)
    if ok and tr then
        danceTrack = tr
        pcall(function() tr.Looped = true tr:Play() end)
        notify("Dance", "Playing " .. tostring(id))
    end
end
getgenv().EsaConn_dance = LP.CharacterAdded:Connect(function() danceTrack = nil end)

-- Auto-accept grab
getgenv().EsaConn_grab = LP.OnTeleport and nil or nil
pcall(function()
    local acc = remote("AcceptGrab")
    if acc and getgenv().EsaMicAutoAccept then
        -- hook Namecall-less: just listen via GetPropertyChangedSignal not possible; provide loop to accept pending grabs
        task.spawn(function()
            while REV == getgenv().EsaRev_micup do
                task.wait(1)
                if REV ~= getgenv().EsaRev_micup then break end
                if getgenv().EsaMicAutoAccept then
                    pcall(function() acc:FireServer(true) end)
                end
            end
        end)
    end
end)

-- TTS spam loop
task.spawn(function()
    while REV == getgenv().EsaRev_micup do
        task.wait(tonumber(getgenv().EsaMicSpamDelay) or 3)
        if REV ~= getgenv().EsaRev_micup then break end
        if getgenv().EsaMicTTSSpam then
            pcall(function() sendTTS(getgenv().EsaMicTTSText, true) end)
        end
    end
end)

-- Grab spam loop (nearest cursor target)
task.spawn(function()
    while REV == getgenv().EsaRev_micup do
        task.wait(1.2)
        if REV ~= getgenv().EsaRev_micup then break end
        if getgenv().EsaMicGrabSpam then
            local best, bestD = nil, 350
            local mp = UIS:GetMouseLocation()
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p ~= LP and p.Character and p.Character:FindFirstChild("Head") then
                    local sp, on = Camera:WorldToViewportPoint(p.Character.Head.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                        if d < bestD then bestD = d; best = p end
                    end
                end
            end
            if best then grabPlayer(best) end
        end
    end
end)

-- Auto prompt loop
task.spawn(function()
    while REV == getgenv().EsaRev_micup do
        task.wait(2)
        if REV ~= getgenv().EsaRev_micup then break end
        if getgenv().EsaMicAutoPrompt then pcall(fireAllPrompts) end
    end
end)

-- ============================ [6] VISUALS & ESP =============================
local espFolder = Instance.new("Folder")
espFolder.Name = "EsaMicESP"
espFolder.Parent = game:GetService("CoreGui")
getgenv().EsaMicESPFolder = espFolder

local function ensureESP(plr)
    if plr == LP then return end
    local tag = espFolder:FindFirstChild(plr.Name)
    if tag then return tag end
    local ch = plr.Character
    if not ch or not ch:FindFirstChild("Head") then return nil end
    local bb = Instance.new("BillboardGui")
    bb.Name = plr.Name
    bb.Size = UDim2.new(0, 160, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder
    bb.Adornee = ch.Head
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.TextStrokeTransparency = 0.4
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamBold
    tl.Parent = bb
    local hl = Instance.new("Highlight")
    hl.Name = plr.Name .. "_HL"
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.Parent = espFolder
    pcall(function() hl.Adornee = ch end)
    return bb
end

getgenv().EsaConn_esp = RS.RenderStepped:Connect(function()
    if REV ~= getgenv().EsaRev_micup then return end
    if not getgenv().EsaMicESP then
        for _, v in ipairs(espFolder:GetChildren()) do v.Enabled = false end
        return
    end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, p in ipairs(game.Players:GetPlayers()) do
        pcall(function()
            if p == LP then return end
            local ch = p.Character
            if not ch or not ch:FindFirstChild("Head") or not ch:FindFirstChild("HumanoidRootPart") then return end
            local dist = hrp and (ch.HumanoidRootPart.Position - hrp.Position).Magnitude or 0
            if dist > (tonumber(getgenv().EsaMicESPMaxDist) or 1500) then return end
            local bb = ensureESP(p) or espFolder:FindFirstChild(p.Name)
            if bb and bb:IsA("BillboardGui") then
                bb.Enabled = true
                bb.Adornee = ch.Head
                local tl = bb:FindFirstChildOfClass("TextLabel")
                if tl then
                    tl.Text = p.DisplayName .. " (@" .. p.Name .. ")\n" .. math.floor(dist) .. "m"
                    tl.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end
            local hl = espFolder:FindFirstChild(p.Name .. "_HL")
            if hl and hl:IsA("Highlight") then
                hl.Adornee = ch
                hl.Enabled = true
            end
        end)
    end
    -- cleanup leavers
    for _, v in ipairs(espFolder:GetChildren()) do
        local nm = string.gsub(v.Name, "_HL$", "")
        if not game.Players:FindFirstChild(nm) then pcall(function() v:Destroy() end) end
    end
end)

local function purgeOldWindUI()
    if getgenv().EsaWindUIWindow then
        pcall(function() getgenv().EsaWindUIWindow:Destroy() end)
        getgenv().EsaWindUIWindow = nil
    end
    getgenv().EsaWindUILoaded = nil
    local targets = {}
    pcall(function() if typeof(gethui) == "function" then table.insert(targets, gethui()) end end)
    pcall(function() table.insert(targets, game:GetService("CoreGui")) end)
    pcall(function()
        local lp = game.Players.LocalPlayer
        if lp and lp:FindFirstChild("PlayerGui") then table.insert(targets, lp.PlayerGui) end
    end)
    for _, parent in ipairs(targets) do
        pcall(function()
            for _, child in ipairs(parent:GetChildren()) do
                local nl = string.lower(child.Name)
                if string.find(nl, "windui") then pcall(function() child:Destroy() end) end
            end
        end)
    end
    task.wait(0.12)
end

-- ============================ [7] USER INTERFACE (WindUI) =============================
local function fixWindUIDisplayOrder()
    local h = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    for _, name in ipairs({ "WindUI", "WindUI/Notifications", "WindUI/Dropdowns", "WindUI/Tooltips" }) do
        local g = h:FindFirstChild(name)
        if g and g:IsA("ScreenGui") then g.DisplayOrder = 999999 end
    end
end

local function isWindUIAlive()
    if not getgenv().EsaWindUIWindow then return false end
    local h = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local gui = h:FindFirstChild("WindUI") or game:GetService("CoreGui"):FindFirstChild("WindUI")
    if not gui then return false end
    local w = getgenv().EsaWindUIWindow
    if w.Destroyed then return false end
    return true
end

local uiAlreadyLoaded = isWindUIAlive() and (not getgenv().EsaForceReloadUI)
local Window = getgenv().EsaWindUIWindow
local WindUI = getgenv().EsaWindUI
local UI = getgenv().EsaUIToggles or {}

if uiAlreadyLoaded and Window then
    warn("[ESA-MICUP] UI already active - skipping duplicate.")
    fixWindUIDisplayOrder()
    if getgenv().EsaConn_MenuToggle then pcall(function() getgenv().EsaConn_MenuToggle:Disconnect() end) end
    getgenv().EsaConn_MenuToggle = UIS.InputBegan:Connect(function(io)
        if UIS:GetFocusedTextBox() ~= nil then return end
        if io.KeyCode == Enum.KeyCode.RightShift or io.KeyCode == Enum.KeyCode.Insert or io.KeyCode == Enum.KeyCode.RightControl then
            if Window then fixWindUIDisplayOrder() pcall(function() Window:Toggle() end) fixWindUIDisplayOrder() end
        end
    end)
else
    purgeOldWindUI()
    WindUI = (((typeof(isfile) == "function" and isfile("windui.lua")) and loadstring(readfile("windui.lua"))) or loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")))()
    getgenv().EsaWindUI = WindUI
    Window = WindUI:CreateWindow({
        Title = "ESA | MIC UP",
        Icon = "mic",
        Author = "MIC UP 6884319169",
        Folder = "EsaMicUp",
        Theme = "Dark",
        -- NOTE: built-in ToggleKey intentionally parked on CapsLock (practically never pressed in-game).
        -- EsaConn_MenuToggle below is the ONLY handler for RightShift/Insert/RightControl.
        -- Keeping RightShift in both places fires Window:Toggle() TWICE per keypress
        -- (built-in closes -> custom reopens instantly) = "กดซ่อนแล้วเด้งกลับ".
        ToggleKey = Enum.KeyCode.CapsLock,
    })
    getgenv().EsaWindUIWindow = Window
    getgenv().EsaWindUILoaded = true
    getgenv().EsaForceReloadUI = false
    fixWindUIDisplayOrder()
    if getgenv().EsaConn_MenuToggle then pcall(function() getgenv().EsaConn_MenuToggle:Disconnect() end) end
    getgenv().EsaConn_MenuToggle = UIS.InputBegan:Connect(function(io)
        if UIS:GetFocusedTextBox() ~= nil then return end
        if io.KeyCode == Enum.KeyCode.RightShift or io.KeyCode == Enum.KeyCode.Insert or io.KeyCode == Enum.KeyCode.RightControl then
            if Window then fixWindUIDisplayOrder() pcall(function() Window:Toggle() end) fixWindUIDisplayOrder() end
        end
    end)
    UI = {}
    getgenv().EsaUIToggles = UI

    UI.Main = Window:Tab({ Title = "Main", Icon = "home", Desc = "Prompts & teleports" })
    UI.Grab = Window:Tab({ Title = "Grab", Icon = "hand", Desc = "Grab spam & accept" })
    UI.Tools = Window:Tab({ Title = "Tools", Icon = "wrench", Desc = "Give fun/danger tools" })
    UI.TTS = Window:Tab({ Title = "TTS", Icon = "volume-2", Desc = "Text to speech spam" })
    UI.Dance = Window:Tab({ Title = "Dance", Icon = "music", Desc = "Emote dances" })
    UI.Visual = Window:Tab({ Title = "Visuals", Icon = "eye", Desc = "Player ESP" })
    pcall(function() Window:SelectTab(1) end)

    UI.Main:Toggle({ Title = "Auto Prompt (near)", Value = getgenv().EsaMicAutoPrompt, Callback = function(s) getgenv().EsaMicAutoPrompt = s; saveConfig() end })
    UI.Main:Button({ Title = "Fire All Prompts now", Callback = function() local n = fireAllPrompts() notify("Prompts", "Fired " .. tostring(n)) end })
    UI.Main:Dropdown({ Title = "Teleport to spot", Values = SPOTS, Value = "middle", Callback = function(v) teleportTo(v) end })
    for _, sp in ipairs(SPOTS) do
        UI.Main:Button({ Title = "TP: " .. sp, Callback = function() teleportTo(sp) end })
    end

    UI.Grab:Toggle({ Title = "Auto-Accept Grab", Value = getgenv().EsaMicAutoAccept, Callback = function(s) getgenv().EsaMicAutoAccept = s; saveConfig() end })
    UI.Grab:Toggle({ Title = "Grab Spam (near cursor)", Value = getgenv().EsaMicGrabSpam, Callback = function(s) getgenv().EsaMicGrabSpam = s; saveConfig() end })
    UI.Grab:Button({ Title = "Grab Nearest Player", Callback = function()
        local best, bd = nil, 1e9
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and hrp then
                local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if d < bd then bd = d; best = p end
            end
        end
        if best then grabPlayer(best) notify("Grab", best.Name) end
    end })
    UI.Grab:Button({ Title = "Accept Grab (FireServer true)", Callback = function() pcall(function() remote("AcceptGrab"):FireServer(true) end) end })

    UI.Tools:Button({ Title = "Give ALL Tools", Callback = giveAllTools })
    for _, t in ipairs(TOOL_NAMES) do
        UI.Tools:Button({ Title = "Get: " .. t, Callback = function() giveTool(t) end })
    end
    UI.Tools:Button({ Title = "Delete Tool (event_tool_delete)", Callback = function()
        local cur = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        pcall(function() remote("event_tool_delete"):FireServer(cur and cur.Name or "") end)
    end })

    UI.TTS:Toggle({ Title = "TTS Spam (broadcast)", Value = getgenv().EsaMicTTSSpam, Callback = function(s) getgenv().EsaMicTTSSpam = s; saveConfig() end })
    UI.TTS:Input({ Title = "TTS Text", Value = tostring(getgenv().EsaMicTTSText), Callback = function(v) getgenv().EsaMicTTSText = v; saveConfig() end })
    UI.TTS:Button({ Title = "Send TTS Once", Callback = function() sendTTS(getgenv().EsaMicTTSText, true) end })

    for _, d in ipairs(DANCES) do
        UI.Dance:Button({ Title = d.Name, Callback = function() playDance(d.Id) end })
    end
    UI.Dance:Button({ Title = "Stop Dance", Callback = stopDance })

    UI.Visual:Toggle({ Title = "Player ESP", Value = getgenv().EsaMicESP, Callback = function(s) getgenv().EsaMicESP = s; saveConfig() end })
    UI.Visual:Button({ Title = "Reload UI", Callback = function()
        getgenv().EsaForceReloadUI = true
        purgeOldWindUI()
    end })
end

-- ============================ [8] SHORTCUTS =============================
-- RightShift / Insert / RightControl handled above. No Modal floating button (preserve mouse lock).

warn("[ESA-MICUP] loaded. RightShift = menu.")
if not uiAlreadyLoaded then
    pcall(function()
        WindUI:Notify({ Title = "ESA | MIC UP", Content = "All social features loaded! RightShift = menu.", Duration = 5, Icon = "mic" })
    end)
    task.spawn(function() task.wait(0.3) fixWindUIDisplayOrder() pcall(function() if Window and Window.Closed then Window:Open() end end) fixWindUIDisplayOrder() end)
end
