-- v1.4.0 – optimized

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local rayModule      = require(ReplicatedStorage:WaitForChild("Module"):WaitForChild("RayCast"))
local stdRaycastMod
pcall(function()
    stdRaycastMod = require(ReplicatedStorage:WaitForChild("Std"):WaitForChild("Raycast"))
end)

local originalRay     = rayModule.RayIgnoreNonCollideWithIgnoreList
local originalStdColl = stdRaycastMod and stdRaycastMod.collidable

local LocalPlayer      = Players.LocalPlayer
local MaxDist          = 600
local NPCCache         : {any} = {}
local LastNPCUpdate    : number = 0
local IsAimActive      : boolean = false
local IgnoreAttr       = "InvisibleToBullets"

local NPCKeywords = {
    ["NPC"]   = true,
    ["BOSS"]  = true,
    ["GUARD"] = true,
    ["MANSION"]=true,
}

local function isCollidable(part: BasePart?): boolean
    return part and part:IsA("BasePart") and part:GetAttribute(IgnoreAttr) ~= true
end

local function isNPC(model: Model): boolean
    if not model or not model:IsA("Model") then return false end
    if model:GetAttribute(IgnoreAttr) == true then return false end
    if not model:FindFirstChild("HumanoidRootPart") then return false end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    local nameUpper = string.upper(model.Name)
    for key,_ in pairs(NPCKeywords) do
        if string.find(nameUpper, key) then return true end
    end

    if model:GetAttribute("ActiveBoss") or
       model:GetAttribute("NPCDestObj")  or
       model:GetAttribute("MansionBossNPCDamage")
    then return true end

    local parent = model.Parent
    if parent and string.find(string.upper(parent.Name), "NPC") then return true end
    if parent and string.find(string.upper(parent.Name), "BOSS") then return true end

    return false
end

local function getNearestTarget(pos: Vector3)
    local nearest, dist = nil, MaxDist

    if tick() - LastNPCUpdate >= 0.3 then
        LastNPCUpdate = tick()
        NPCCache = {}
        local parts = Workspace:GetPartBoundsInRadius(pos, MaxDist)

        for _, part in ipairs(parts) do
            if isCollidable(part) then
                local model = part:FindFirstAncestorOfClass("Model")
                while model and not NPCCache[model] do
                    NPCCache[model] = true
                    if isNPC(model) then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - pos).Magnitude
                            if d <= MaxDist then
                                table.insert(NPCCache, {Object=model, HRP=hrp, Pos=hrp.Position})
                            end
                        end
                    end
                    model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
                end
            end
        end
    end

    for _, npc in ipairs(NPCCache) do
        local d = (npc.Pos - pos).Magnitude
        if d < dist then
            nearest, dist = {Type="NPC", Data=npc}, d
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team then
            local chr   = plr.Character
            local hrp   = chr and chr:FindFirstChild("HumanoidRootPart")
            local attr  = chr and chr:GetAttribute(IgnoreAttr)
            if hrp and not attr then
                local d = (hrp.Position - pos).Magnitude
                if d < dist then
                    nearest, dist = {Type="Player", Data=plr}, d
                end
            end
        end
    end

    return nearest
end

local function getNPCTargetPoint(npcData)
    local model  = npcData.Object
    local parts  = {"Head","UpperTorso","Torso"}
    for _, name in ipairs(parts) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local offset = Vector3.new(0, (name=="Head" and 0 or (name=="UpperTorso" and 1.5 or 2)),0)
            return part, part.Position + offset
        end
    end
    if npcData.HRP then
        return npcData.HRP, npcData.HRP.Position + Vector3.new(0,2.5,0)
    end
end

local function isVisible(fromPos:Vector3, toPos:Vector3, ignoreList:{Instance})
    local dir   = (toPos - fromPos).Unit
    local dist  = (fromPos - toPos).Magnitude
    local ray   = Ray.new(fromPos, dir * dist)

    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
    if not hit then return true end

    if hit:GetAttribute(IgnoreAttr) == true then
        table.insert(ignoreList, hit)
        return isVisible(fromPos, toPos, ignoreList)
    end
    return false
end

local function calculateAimOverride()
    local chr   = LocalPlayer.Character
    if not chr then return nil, nil end
    local hrp   = chr:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end

    local target = getNearestTarget(hrp.Position)
    if not target then return nil, nil end

    if target.Type == "NPC" then
        local aimPart, aimPos = getNPCTargetPoint(target.Data)
        if aimPart and isVisible(hrp.Position, aimPos, {chr, target.Data.Object}) then
            return aimPart, aimPos
        end
        return target.Data.HRP, target.Data.Pos + Vector3.new(0,2.5,0)

    else
        local plr   = target.Data
        local chrPlr= plr.Character
        if not chrPlr then return nil, nil end
        local head  = chrPlr:FindFirstChild("Head")
        if head and isVisible(hrp.Position, head.Position, {chr, chrPlr}) then
            return head, head.Position
        end
        local hrpPlr= chrPlr:FindFirstChild("HumanoidRootPart")
        if hrpPlr then
            return hrpPlr, hrpPlr.Position
        end
    end

    return nil, nil
end

local function activateAim()
    if IsAimActive then return end
    IsAimActive = true

    rayModule.RayIgnoreNonCollideWithIgnoreList = function(...)
        local res = {originalRay(...)}
        local src = tostring(getfenv(2).script)

        if src == "BulletEmitter" or src == "Taser" then
            local aimPart, aimPos = calculateAimOverride()
            if aimPart and aimPos then
                res[1] = aimPart
                res[2] = aimPos
            end
        end
        return unpack(res)
    end

    if stdRaycastMod then
        stdRaycastMod.collidable = function(origin, dir, range, params, collFunc)
            local aimPart, aimPos = calculateAimOverride()
            if aimPart and aimPos then
                return {
                    Instance  = aimPart,
                    Position  = aimPos,
                    Material  = Enum.Material.Plastic,
                    Normal    = Vector3.new(0,1,0),
                }
            end
            return originalStdColl(origin, dir, range, params, collFunc)
        end
    end
end

local function deactivateAim()
    if not IsAimActive then return end
    IsAimActive = false
    NPCCache = {}

    rayModule.RayIgnoreNonCollideWithIgnoreList = originalRay
    if stdRaycastMod and originalStdColl then
        stdRaycastMod.collidable = originalStdColl
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or input.KeyCode ~= Enum.KeyCode.X then return end
    if IsAimActive then deactivateAim() else activateAim() end
end)

UserInputService.WindowFocused:Connect(deactivateAim)

RunService.Heartbeat:Connect(function()
    if IsAimActive and not LocalPlayer.Character then deactivateAim() end
end)

-- v1.4.0 – optimized
