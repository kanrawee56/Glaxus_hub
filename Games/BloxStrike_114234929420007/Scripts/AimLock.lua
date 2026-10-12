--FE Simple AimLock Script | Released Nov 2021 | Working.
-- + TeamCheck (BloxStrike: อ่าน Attribute Team บน Player) + สวิตช์ RightAlt
local Area = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local MyCharacter = LocalPlayer.Character
local MyRoot = MyCharacter and MyCharacter:FindFirstChild("HumanoidRootPart") or nil
local MyHumanoid = MyCharacter and MyCharacter:FindFirstChild("Humanoid") or nil
local Mouse = LocalPlayer:GetMouse()
local MyView = Area.CurrentCamera
local MyTeamColor = LocalPlayer.TeamColor
local HoldingM2 = false
local Active = false
local Lock = false
local Epitaph = .187 ---Note: The Bigger The Number, The More Prediction.
local HeadOffset = Vector3.new(0, .1, 0)

-- รันซ้ำได้: ล้างของเก่าก่อน (กันวงซ้อน + ลูปเก่าค้าง + connection ซ้อน)
local G = getgenv()
G.__AimLock_Gen = (G.__AimLock_Gen or 0) + 1
local MyGen = G.__AimLock_Gen
if G.__AimLock_Conn1 then pcall(function() G.__AimLock_Conn1:Disconnect() end) end
if G.__AimLock_Conn2 then pcall(function() G.__AimLock_Conn2:Disconnect() end) end
if G.__AimLock_Circle then pcall(function() G.__AimLock_Circle:Remove() end) end
pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
G.__AimLock_Conn1 = nil
G.__AimLock_Conn2 = nil
G.__AimLock_Circle = nil

_G.TeamCheck = true
_G.AimPart = "HumanoidRootPart"
_G.Sensitivity = 0
_G.CircleSides = 64
_G.CircleColor = Color3.fromRGB(255, 0, 130)
_G.CircleTransparency = 0
_G.CircleRadius = 200
_G.CircleFilled = false
_G.CircleVisible = true
_G.CircleThickness = 1

local FOVCircle = Drawing.new("Circle")
FOVCircle.Position = Vector2.new(MyView.ViewportSize.X / 2, MyView.ViewportSize.Y / 2)
FOVCircle.Radius = _G.CircleRadius
FOVCircle.Filled = _G.CircleFilled
FOVCircle.Color = _G.CircleColor
FOVCircle.Visible = _G.CircleVisible
FOVCircle.Transparency = _G.CircleTransparency
FOVCircle.NumSides = _G.CircleSides
FOVCircle.Thickness = _G.CircleThickness
G.__AimLock_Circle = FOVCircle

-- ทีมเดียวกันไหม (BloxStrike เก็บทีมใน Attribute ไม่ใช่ TeamColor)
local function SameTeam(a, b)
	if a == nil or b == nil then return false end
	local ta, tb = nil, nil
	pcall(function() ta = a:GetAttribute("Team") end)
	pcall(function() tb = b:GetAttribute("Team") end)
	if ta == nil or ta == "" or tb == nil or tb == "" then return false end
	return ta == tb
end

-- หาตัวละครของ v: Player.Character ก่อน ไม่ได้ค่อยหาใน Workspace.Characters
local function ResolveChar(v)
	local ch = v.Character
	if ch ~= nil and ch.Parent ~= nil then return ch end
	local folder = Area:FindFirstChild("Characters")
	if folder ~= nil then
		local m = folder:FindFirstChild(v.Name)
		if m ~= nil and m:IsA("Model") then return m end
	end
	return nil
end

local function CursorLock()
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
end
local function UnLockCursor()
	HoldingM2 = false Active = false Lock = false
	UIS.MouseBehavior = Enum.MouseBehavior.Default
end
function FindNearestPlayer()
	local dist = math.huge
	local Target = nil
	for _, v in pairs(Players:GetPlayers()) do
		if v == LocalPlayer then continue end
		if _G.TeamCheck and SameTeam(LocalPlayer, v) then continue end
		local TheirCharacter = ResolveChar(v)
		if TheirCharacter == nil then continue end
		local hum = TheirCharacter:FindFirstChildOfClass("Humanoid")
		local root = TheirCharacter:FindFirstChild("HumanoidRootPart")
		if hum == nil or root == nil or hum.Health <= 0 then continue end
		local aimPart = TheirCharacter:FindFirstChild(_G.AimPart) or root
		local CharacterRoot, Visible = MyView:WorldToViewportPoint(aimPart.Position)
		if Visible then
			local RealMag = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(CharacterRoot.X, CharacterRoot.Y)).Magnitude
			if RealMag < dist and RealMag < FOVCircle.Radius then
				dist = RealMag
				Target = TheirCharacter
			end
		end
	end
	return Target
end

G.__AimLock_Conn1 = UIS.InputBegan:Connect(function(Input, gpe)
	if gpe then return end
	-- RightAlt: สลับเปิด/ปิด TeamCheck อย่างเดียว (ไม่เกี่ยวกับล็อก)
	if Input.KeyCode == Enum.KeyCode.RightAlt then
		_G.TeamCheck = not _G.TeamCheck
		pcall(function()
			game.StarterGui:SetCore("SendNotification", {
				Title = "TeamCheck",
				Text = _G.TeamCheck and "ON - ข้ามเพื่อนร่วมทีม" or "OFF - ล็อกทุกคน",
				Duration = 2,
			})
		end)
		return
	end
	if Input.UserInputType == Enum.UserInputType.MouseButton2 then
		HoldingM2 = true
		Active = true
		Lock = true
		if Active then
        	local The_Enemy = FindNearestPlayer()
			while HoldingM2 do task.wait(.000001)
				if MyGen ~= G.__AimLock_Gen then break end -- โดนรันใหม่ทับ ให้ลูปเก่าตาย
				if Lock and The_Enemy ~= nil then
					local Future = The_Enemy.HumanoidRootPart.CFrame + (The_Enemy.HumanoidRootPart.Velocity * Epitaph + HeadOffset)
					MyView.CFrame = CFrame.lookAt(MyView.CFrame.Position, Future.Position)
					CursorLock()
				end
			end
		end
	end
end)
G.__AimLock_Conn2 = UIS.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton2 then
		UnLockCursor()
	end
end)
game.StarterGui:SetCore("SendNotification", {Title = "AimLock Loaded.", Text = "M2 = Lock | RightAlt = TeamCheck ON/OFF", Duration = 4,})
