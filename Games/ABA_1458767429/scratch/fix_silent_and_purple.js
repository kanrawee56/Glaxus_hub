const fs = require('fs');

const filePath = 'c:/Users/kanra/Downloads/Esa_Backup/Esa/Esa-slayer/Games/ABA_1458767429/Scripts/main.lua';
let content = fs.readFileSync(filePath, 'utf8');

// 1. Add EsaConn_purple_char to cleanup lists
content = content.replace(
    '"EsaConn_purple_thrown", "EsaConn_purple_ws", "EsaConn_purple_debris"',
    '"EsaConn_purple_thrown", "EsaConn_purple_ws", "EsaConn_purple_debris", "EsaConn_purple_char"'
);

// 2. Insert isLocalGojoAwakened definition right above __namecall hook
const namecallAnchor = `    if typeof(hookmetamethod) == "function" and typeof(newcclosure) == "function" then
        if getgenv()._EsaOldNamecall then return end
        local oldNamecall`;

const isAwakenedFunc = `local function isLocalGojoAwakened()
    local myChar = LP.Character
    if not myChar then return false end
    if myChar:FindFirstChild("Mode") ~= nil 
       or myChar:GetAttribute("Mode") == true 
       or myChar:FindFirstChild("Awakening") ~= nil 
       or myChar:FindFirstChild("Awakened") ~= nil then
        return true
    end
    local myPlr = LP
    if myPlr and (myPlr:FindFirstChild("Mode") or myPlr:GetAttribute("Mode") == true) then
        return true
    end
    for _, desc in ipairs(myChar:GetDescendants()) do
        if desc:IsA("StringValue") or desc:IsA("BoolValue") then
            local dname = desc.Name:lower()
            if dname == "mode" or dname == "awakening" or dname == "awakened" then
                if desc.Value == true or tostring(desc.Value) ~= "" then
                    return true
                end
            end
        end
    end
    return false
end

` + namecallAnchor;

content = content.replace(namecallAnchor, isAwakenedFunc);

// 3. Exclude Hollow Purple from Silent Aim in __namecall
const silentAimStart = `            if not (typeof(checkcaller) == "function" and checkcaller()) and method == "FireServer" and typeof(self) == "Instance" and self.Name == "Input" and args[1] == "UseMove" then
                if getgenv().EsaSilentAimEnabled then`;

const silentAimExclusion = `            if not (typeof(checkcaller) == "function" and checkcaller()) and method == "FireServer" and typeof(self) == "Instance" and self.Name == "Input" and args[1] == "UseMove" then
                local pkt = args[2]
                local tn = (type(pkt) == "table" and tostring(pkt.ToolName or ""):lower()) or ""
                local isPurple = tn:find("purple") or tn:find("hollow") or tn:find("murasaki") or (isLocalGojoAwakened() and (tn:find("2") or (pkt and tostring(pkt.range) == "2")))

                -- When Full Control Purple is enabled, do NOT let Silent Aim alter direction or aim down into the floor!
                if isPurple and getgenv().EsaPurpleControl then
                    return oldNamecall(self, ...)
                end

                if getgenv().EsaSilentAimEnabled then`;

content = content.replace(silentAimStart, silentAimExclusion);

// 4. In isRealHollowPurple: remove the premature "if isWeldedToLocalPlayer(part) then return false end"
content = content.replace(
    `local function isRealHollowPurple(part)
    if not part or not part:IsA("BasePart") then return false end
    if not isLocalGojoAwakened() then return false end
    if isWeldedToLocalPlayer(part) then return false end`,
    `local function isRealHollowPurple(part)
    if not part or not part:IsA("BasePart") then return false end
    if not isLocalGojoAwakened() then return false end`
);

// 5. Ensure CanCollide is false in handleHollowPurpleFullControl and add character child listener
const handleStart = `        if getgenv().EsaPurpleControl == false then
            _activePurpleBall = nil
            return
        end

        local speed = tonumber(getgenv().EsaPurpleSpeed) or 1200`;

const handleImproved = `        if getgenv().EsaPurpleControl == false then
            _activePurpleBall = nil
            return
        end

        -- Disable collision so ball never gets stuck on the ground or terrain
        pcall(function()
            ball.CanCollide = false
        end)

        local speed = tonumber(getgenv().EsaPurpleSpeed) or 1200`;

content = content.replace(handleStart, handleImproved);

// 6. Connect character tracking for Hollow Purple
const connWsEnd = `getgenv().EsaConn_purple_ws = workspace.ChildAdded:Connect(checkHollowPurpleCandidate)`;
const connWithChar = `getgenv().EsaConn_purple_ws = workspace.ChildAdded:Connect(checkHollowPurpleCandidate)

local function trackCharForPurple(char)
    if not char then return end
    if getgenv().EsaConn_purple_char then pcall(function() getgenv().EsaConn_purple_char:Disconnect() end) end
    getgenv().EsaConn_purple_char = char.ChildAdded:Connect(function(c)
        if isLocalGojoAwakened() then
            task.spawn(function() checkHollowPurpleCandidate(c) end)
        end
    end)
    for _, c in ipairs(char:GetChildren()) do
        if isLocalGojoAwakened() then
            task.spawn(function() checkHollowPurpleCandidate(c) end)
        end
    end
end
trackCharForPurple(LP.Character)
LP.CharacterAdded:Connect(trackCharForPurple)`;

content = content.replace(connWsEnd, connWithChar);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Successfully applied Silent Aim exclusion and Full Control capture fix!');
