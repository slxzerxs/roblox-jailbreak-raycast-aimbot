-- v1.1.0
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local workspaceService = game:GetService("Workspace")
local runService = game:GetService("RunService")

local rayModule = require(
    game:GetService("ReplicatedStorage").Module.RayCast
)

getgenv().MaxDistance = 600
getgenv().OriginalRaycast =
    getgenv().OriginalRaycast
    or rayModule.RayIgnoreNonCollideWithIgnoreList

local isHoldingAimKey = false
local npcCache = {}
local lastNpcUpdate = 0

local function isNPC(model)
    if not model:IsA("Model") then
        return false
    end

    if not model:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local humanoid = model:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    local name = string.upper(model.Name)

    if string.find(name, "NPC") then return true end
    if string.find(name, "BOSS") then return true end
    if string.find(name, "GUARD") then return true end
    if string.find(name, "MANSION") then return true end

    if model:GetAttribute("ActiveBoss") then return true end
    if model:GetAttribute("NPCDestObj") then return true end
    if model:GetAttribute("MansionBossNPCDamage") then return true end

    local parent = model.Parent
    if parent then
        local parentName = string.upper(parent.Name)

        if string.find(parentName, "NPC") then return true end
        if string.find(parentName, "BOSS") then return true end
    end

    return false
end

local function findNearestNPC(rootPosition)
    local maxDistance = getgenv().MaxDistance
    local nearest = nil
    local nearestDistance = maxDistance

    local currentTime = tick()
    if currentTime - lastNpcUpdate >= 0.3 then
        lastNpcUpdate = currentTime
        npcCache = {}

        local checkedModels = {}
        local nearbyParts =
            workspaceService:GetPartBoundsInRadius(rootPosition, maxDistance)

        for _, part in ipairs(nearbyParts) do
            local model = part:FindFirstAncestorOfClass("Model")

            while model do
                if not checkedModels[model] then
                    checkedModels[model] = true

                    if isNPC(model) then
                        local rootPart =
                            model:FindFirstChild("HumanoidRootPart")

                        if rootPart then
                            local position = rootPart.Position
                            local distance =
                                (position - rootPosition).Magnitude

                            if distance <= maxDistance then
                                table.insert(npcCache, {
                                    Object = model,
                                    HRP = rootPart,
                                    Position = position,
                                    Name = model.Name
                                })
                            end
                        end
                    end
                end

                local parent = model.Parent
                model = parent
                    and parent:FindFirstAncestorOfClass("Model")
            end
        end
    end

    for _, npc in ipairs(npcCache) do
        local distance = (npc.Position - rootPosition).Magnitude

        if distance < nearestDistance then
            nearestDistance = distance
            nearest = npc
        end
    end

    return nearest
end

local function findNearestPlayer(rootPosition)
    local nearest = nil
    local nearestDistance = getgenv().MaxDistance

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Team ~= localPlayer.Team then
            local character = player.Character
            local rootPart = character
                and character:FindFirstChild("HumanoidRootPart")

            if rootPart then
                local distance = (rootPart.Position - rootPosition).Magnitude

                if distance < nearestDistance then
                    nearestDistance = distance
                    nearest = player
                end
            end
        end
    end

    return nearest
end

local function getAimTarget(npcData)
    if not npcData then
        return nil, nil
    end

    local model = npcData.Object
    local head = model:FindFirstChild("Head")

    if head and head:IsA("BasePart") and head.Parent then
        return head, head.Position
    end

    local torso = model:FindFirstChild("UpperTorso")
    if torso and torso:IsA("BasePart") and torso.Parent then
        return torso, torso.Position + Vector3.new(0, 1.5, 0)
    end

    torso = model:FindFirstChild("Torso")
    if torso and torso:IsA("BasePart") and torso.Parent then
        return torso, torso.Position + Vector3.new(0, 2, 0)
    end

    local rootPart = npcData.HRP
    if rootPart and rootPart.Parent then
        return rootPart, rootPart.Position + Vector3.new(0, 2.5, 0)
    end

    return nil, nil
end

local function isVisible(fromPosition, toPosition, ignoreList)
    local direction = (toPosition - fromPosition).Unit
    local distance = (fromPosition - toPosition).Magnitude
    local ray = Ray.new(fromPosition, direction * distance)

    local hit = workspaceService:FindPartOnRayWithIgnoreList(ray, ignoreList)
    return not hit
end

local function getBestTarget(rootPosition)
    local npcTarget = findNearestNPC(rootPosition)
    local playerTarget = findNearestPlayer(rootPosition)

    if not npcTarget and not playerTarget then
        return nil, nil
    end

    if npcTarget and not playerTarget then
        return "npc", npcTarget
    end

    if playerTarget and not npcTarget then
        return "player", playerTarget
    end

    local npcDistance = (npcTarget.Position - rootPosition).Magnitude
    local playerCharacter = playerTarget.Character
    local playerRoot = playerCharacter
        and playerCharacter:FindFirstChild("HumanoidRootPart")
    local playerDistance = playerRoot
        and (playerRoot.Position - rootPosition).Magnitude
        or math.huge

    if npcDistance <= playerDistance then
        return "npc", npcTarget
    end

    return "player", playerTarget
end

local function handleNPCTarget(target)
    local aimPart, aimPosition = getAimTarget(target)

    if aimPart and aimPosition then
        local character = localPlayer.Character
        local rootPart = character
            and character:FindFirstChild("HumanoidRootPart")

        if rootPart then
            local ignoreList = { character, target.Object }

            if isVisible(rootPart.Position, aimPosition, ignoreList) then
                return aimPart, aimPosition
            end

            if target.HRP and target.HRP.Parent then
                local rootPosition = target.HRP.Position

                if isVisible(rootPart.Position, rootPosition, ignoreList) then
                    return target.HRP, rootPosition + Vector3.new(0, 0.5, 0)
                end
            end
        end
    end

    if target.HRP and target.HRP.Parent then
        return target.HRP, target.HRP.Position + Vector3.new(0, 2.5, 0)
    end

    return nil, nil
end

local function handlePlayerTarget(target)
    local character = target.Character
    local rootPart = character
        and character:FindFirstChild("HumanoidRootPart")

    if not rootPart then
        return nil, nil
    end

    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") and head.Parent then
        local localCharacter = localPlayer.Character
        local localRoot = localCharacter
            and localCharacter:FindFirstChild("HumanoidRootPart")

        if localRoot then
            local ignoreList = { localCharacter, character }

            if isVisible(localRoot.Position, head.Position, ignoreList) then
                return head, head.Position
            end
        end
    end

    return rootPart, rootPart.Position
end

local function startAim()
    if isHoldingAimKey then
        return
    end

    isHoldingAimKey = true

    rayModule.RayIgnoreNonCollideWithIgnoreList = function(...)
        local character = localPlayer.Character
        local rootPart = character
            and character:FindFirstChild("HumanoidRootPart")

        if not rootPart then
            return getgenv().OriginalRaycast(...)
        end

        local result = {
            getgenv().OriginalRaycast(...)
        }

        local sourceScript = tostring(getfenv(2).script)
        if sourceScript == "BulletEmitter" or sourceScript == "Taser" then
            local targetType, target = getBestTarget(rootPart.Position)

            if targetType == "npc" then
                local aimPart, aimPosition = handleNPCTarget(target)

                if aimPart and aimPosition then
                    result[1] = aimPart
                    result[2] = aimPosition
                end
            elseif targetType == "player" then
                local aimPart, aimPosition = handlePlayerTarget(target)

                if aimPart and aimPosition then
                    result[1] = aimPart
                    result[2] = aimPosition
                end
            end
        end

        return unpack(result)
    end
end

local function stopAim()
    if not isHoldingAimKey then
        return
    end

    isHoldingAimKey = false
    npcCache = {}
    rayModule.RayIgnoreNonCollideWithIgnoreList =
        getgenv().OriginalRaycast
end

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or input.KeyCode ~= Enum.KeyCode.X then
        return
    end

    if isHoldingAimKey then
        stopAim()
    else
        startAim()
    end
end)

userInputService.WindowFocused:Connect(function()
    if isHoldingAimKey then
        stopAim()
    end
end)

runService.Heartbeat:Connect(function()
    if isHoldingAimKey and not localPlayer.Character then
        stopAim()
    end
end)
